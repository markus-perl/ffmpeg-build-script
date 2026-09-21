# shellcheck shell=bash
make_dir() {
    remove_dir "$1"
    if ! mkdir "$1"; then
        printf "\n Failed to create dir %s" "$1"
        exit 1
    fi
}

remove_dir() {
    if [ -d "$1" ]; then
        rm -rf "$1"
    fi
}

# The VER_ arrays live in src/10-versions.sh; these two map a build() package name
# onto one of its elements. The mapping is mechanical, so the name passed to build()
# and the array name must stay in sync or the checksum silently goes unchecked -
# --list-packages reports the ones that do not line up.
package_ver_var() {
    # package_ver_var <package-name> <index>
    # Maps a build() package name onto a reference to one element of its VER_
    # array: uppercase, non-alphanumerics become underscores. Element 0 is the
    # version, element 1 the SHA-256. Read the result with ${!ref}.
    PACKAGE_VER_VAR_NAME=$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')
    printf 'VER_%s[%s]' "${PACKAGE_VER_VAR_NAME//[^A-Z0-9]/_}" "$2"
}

package_sha_var() {
    # package_sha_var <package-name>
    # The checksum element, which is what download() verifies against.
    package_ver_var "$1" 1
}

verify_checksum() {
    # verify_checksum <file> <expected-sha256>
    # An empty expectation means the package is not pinned yet, so verification
    # is skipped and this is a no-op.
    if [ -z "$2" ]; then
        return 0
    fi

    if command_exists "sha256sum"; then
        ACTUAL_SHA=$(sha256sum "$1" | awk '{print $1}')
    elif command_exists "shasum"; then
        ACTUAL_SHA=$(shasum -a 256 "$1" | awk '{print $1}')
    else
        echo "Neither sha256sum nor shasum is available, cannot verify $1" >&2
        return 1
    fi

    if [ "$ACTUAL_SHA" != "$2" ]; then
        echo "Checksum mismatch for $1" >&2
        echo "  expected: $2" >&2
        echo "  actual:   $ACTUAL_SHA" >&2
        return 1
    fi

    return 0
}

latest_ffmpeg_version() {
    # latest_ffmpeg_version [major]
    # Prints the highest release version listed at https://ffmpeg.org/releases/,
    # or fails if the index cannot be fetched or contains nothing usable. With
    # [major] given (e.g. "9"), only releases whose first version component
    # matches it are considered - this is how the script resolves the latest
    # release of the major version it supports (see FFMPEG_MAJOR_VERSION in
    # 00-header.sh) instead of jumping to a newer, untested major version.
    #
    # That directory listing is the canonical release index and needs nothing but
    # curl, which the script already requires. The GitHub mirror is not usable for
    # this: it publishes no GitHub releases at all, so
    # /repos/FFmpeg/FFmpeg/releases/latest answers 404, and the tags API is
    # rate limited to 60 requests an hour per IP for unauthenticated callers.
    #
    # The regexp only accepts purely numeric versions, which drops the release
    # candidates and the pre-1.0 names ("ffmpeg-0.4.9-pre1") that also live in
    # that directory. Comparison goes through version_gte rather than "sort -V"
    # because BSD sort on macOS has no -V.
    LATEST_FILTER_MAJOR="$1"
    LATEST_INDEX=$(curl -L --fail --silent --connect-timeout 10 --max-time 20 https://ffmpeg.org/releases/) || return 1

    LATEST_FOUND=""
    while read -r LATEST_CANDIDATE; do
        [ -n "$LATEST_CANDIDATE" ] || continue
        if [ -n "$LATEST_FILTER_MAJOR" ] && [[ "$LATEST_CANDIDATE" != "$LATEST_FILTER_MAJOR".* ]]; then
            continue
        fi
        if [ -z "$LATEST_FOUND" ] || version_gte "$LATEST_CANDIDATE" "$LATEST_FOUND"; then
            LATEST_FOUND="$LATEST_CANDIDATE"
        fi
    done <<<"$(printf '%s\n' "$LATEST_INDEX" |
        grep -oE 'ffmpeg-[0-9]+(\.[0-9]+)*\.tar\.gz' |
        sed -e 's/^ffmpeg-//' -e 's/\.tar\.gz$//')"

    if [ -z "$LATEST_FOUND" ]; then
        return 1
    fi

    printf '%s' "$LATEST_FOUND"
}

ffmpeg_tarball_url() {
    # ffmpeg_tarball_url <version>
    if [ "$1" = "snapshot" ]; then
        printf 'https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2'
        return
    fi

    # Every release, pinned or not, comes from the same place latest_ffmpeg_version
    # discovers it - ffmpeg.org publishes no GitHub releases, so there is no
    # GitHub tag archive to fall back to.
    printf 'https://ffmpeg.org/releases/ffmpeg-%s.tar.gz' "$1"
}

download_with_retries() {
    # download_with_retries <url> <output-path> [expected-sha256]
    # --fail makes curl report an HTTP error instead of saving the error page as
    # if it were the requested file. A checksum mismatch counts as a failed
    # attempt, so a truncated or tampered mirror response is retried.
    RETRY_COUNT=0

    # shellcheck disable=SC2086 # DOWNLOAD_MAX_RETRIES is an integer literal set in 20-globals.sh
    while [ $RETRY_COUNT -le $DOWNLOAD_MAX_RETRIES ]; do
        if [ $RETRY_COUNT -gt 0 ]; then
            echo "Retrying download (attempt $((RETRY_COUNT + 1))/$((DOWNLOAD_MAX_RETRIES + 1))) in 10 seconds..."
            sleep 10
        fi

        curl -L --fail --silent -o "$2" "$1"
        EXITCODE=$?

        if [ $EXITCODE -eq 0 ] && [ -s "$2" ]; then
            if verify_checksum "$2" "$3"; then
                return 0
            fi
            echo "Discarding $2 because it does not match its expected checksum."
            rm -f "$2"
        else
            echo "Failed to download $1 (Exitcode $EXITCODE or empty file)"
        fi

        RETRY_COUNT=$((RETRY_COUNT + 1))
    done

    return 1
}

apply_inline_patch() {
    # apply_inline_patch <file> <sed-expression>
    # In-place sed without -i, whose argument handling differs between GNU and
    # BSD sed. The expression is passed through untouched.
    if [ ! -f "$1" ]; then
        echo "Failed to patch $1: file not found" >&2
        exit 1
    fi

    if ! sed "$2" "$1" >"$1.patched"; then
        echo "Failed to patch $1 with sed expression: $2" >&2
        rm -f "$1.patched"
        exit 1
    fi

    rm -f "$1"
    mv "$1.patched" "$1"
}

download() {
    # download url [filename[dirname]]
    # download url1[|sha256] url2[|sha256] ... [filename[dirname]]
    DOWNLOAD_PATH="$PACKAGES"
    DOWNLOAD_URLS=()
    DOWNLOAD_SHAS=()
    DOWNLOAD_SHA_EXPLICIT=()
    DOWNLOAD_FILE=""
    DOWNLOAD_DIR=""

    for ARG in "$@"; do
        case "$ARG" in
        http://* | https://* | ftp://*)
            DOWNLOAD_URLS+=("${ARG%%|*}")
            if [[ "$ARG" == *"|"* ]]; then
                DOWNLOAD_SHAS+=("${ARG#*|}")
                DOWNLOAD_SHA_EXPLICIT+=(1)
            else
                DOWNLOAD_SHAS+=("")
                DOWNLOAD_SHA_EXPLICIT+=(0)
            fi
            ;;
        *)
            if [ -z "$DOWNLOAD_FILE" ]; then
                DOWNLOAD_FILE="$ARG"
            elif [ -z "$DOWNLOAD_DIR" ]; then
                DOWNLOAD_DIR="$ARG"
            fi
            ;;
        esac
    done

    if [ "${#DOWNLOAD_URLS[@]}" -eq 0 ]; then
        echo "No download URL supplied." >&2
        exit 1
    fi

    if [ -z "$DOWNLOAD_FILE" ]; then
        DOWNLOAD_FILE="${DOWNLOAD_URLS[0]##*/}"
    fi

    if [[ "$DOWNLOAD_FILE" =~ tar. ]]; then
        TARGETDIR="${DOWNLOAD_FILE%.*}"
        TARGETDIR="${DOWNLOAD_DIR:-"${TARGETDIR%.*}"}"
    else
        TARGETDIR="${DOWNLOAD_DIR:-"${DOWNLOAD_FILE%.*}"}"
    fi

    # A source-specific checksum takes precedence. Plain URLs use the package
    # checksum, which keeps the existing single-checksum API unchanged.
    DOWNLOAD_SHA_VAR=$(package_sha_var "$CURRENT_PACKAGE_NAME")
    DOWNLOAD_PACKAGE_SHA="${!DOWNLOAD_SHA_VAR}"

    DOWNLOAD_FILE_NEEDS_DOWNLOAD=0
    if [ -f "$DOWNLOAD_PATH/$DOWNLOAD_FILE" ] && [ -s "$DOWNLOAD_PATH/$DOWNLOAD_FILE" ]; then
        echo "$DOWNLOAD_FILE has already been downloaded and is not empty."
        # A cached file is never deleted automatically: it may be a deliberately
        # placed local copy, and removing it would also destroy the evidence.
        DOWNLOAD_CACHE_VALID=0
        DOWNLOAD_CACHE_SHA_AVAILABLE=0
        for DOWNLOAD_INDEX in "${!DOWNLOAD_URLS[@]}"; do
            if [ "${DOWNLOAD_SHA_EXPLICIT[$DOWNLOAD_INDEX]}" -eq 1 ]; then
                DOWNLOAD_SHA="${DOWNLOAD_SHAS[$DOWNLOAD_INDEX]}"
            else
                DOWNLOAD_SHA="$DOWNLOAD_PACKAGE_SHA"
            fi

            # An unpinned fallback source says nothing about whether a cached file matches the
            # pinned primary source, so it cannot make the cache "valid" by itself. Only an
            # actual checksum match counts; when no source has a checksum at all, fall back to
            # the historical "cached and non-empty is good enough" behaviour below.
            if [ -z "$DOWNLOAD_SHA" ]; then
                continue
            fi

            DOWNLOAD_CACHE_SHA_AVAILABLE=1
            if verify_checksum "$DOWNLOAD_PATH/$DOWNLOAD_FILE" "$DOWNLOAD_SHA"; then
                DOWNLOAD_CACHE_VALID=1
                break
            fi
        done
        if [ "$DOWNLOAD_CACHE_VALID" -ne 1 ] && [ "$DOWNLOAD_CACHE_SHA_AVAILABLE" -eq 0 ]; then
            DOWNLOAD_CACHE_VALID=1
        fi
        if [ "$DOWNLOAD_CACHE_VALID" -ne 1 ]; then
            echo "The cached file $DOWNLOAD_PATH/$DOWNLOAD_FILE is corrupt or does not match the pinned version." >&2
            echo "Delete it and run the build again to download it anew." >&2
            exit 1
        fi
    else
        DOWNLOAD_FILE_NEEDS_DOWNLOAD=1
    fi

    if [ "$DOWNLOAD_FILE_NEEDS_DOWNLOAD" -eq 1 ]; then
        DOWNLOAD_OK=0
        for DOWNLOAD_INDEX in "${!DOWNLOAD_URLS[@]}"; do
            DOWNLOAD_URL="${DOWNLOAD_URLS[$DOWNLOAD_INDEX]}"
            if [ "${DOWNLOAD_SHA_EXPLICIT[$DOWNLOAD_INDEX]}" -eq 1 ]; then
                DOWNLOAD_SHA="${DOWNLOAD_SHAS[$DOWNLOAD_INDEX]}"
            else
                DOWNLOAD_SHA="$DOWNLOAD_PACKAGE_SHA"
            fi
            echo "Downloading $DOWNLOAD_URL as $DOWNLOAD_FILE"
            if download_with_retries "$DOWNLOAD_URL" "$DOWNLOAD_PATH/$DOWNLOAD_FILE" "$DOWNLOAD_SHA"; then
                DOWNLOAD_OK=1
                echo "... Done"
                break
            fi

            echo "Failed to download $DOWNLOAD_URL after $((DOWNLOAD_MAX_RETRIES + 1)) attempts."
            rm -f "$DOWNLOAD_PATH/$DOWNLOAD_FILE"
        done

        if [ "$DOWNLOAD_OK" -ne 1 ]; then
            echo "Failed to download all configured sources for $DOWNLOAD_FILE."
            exit 1
        fi
    fi

    make_dir "$DOWNLOAD_PATH/$TARGETDIR"

    if [[ "$DOWNLOAD_FILE" == *"patch"* ]]; then
        return
    fi

    if [ -n "$DOWNLOAD_DIR" ]; then
        if ! tar -xvf "$DOWNLOAD_PATH/$DOWNLOAD_FILE" -C "$DOWNLOAD_PATH/$TARGETDIR" 2>/dev/null >/dev/null; then
            echo "Failed to extract $DOWNLOAD_FILE"
            exit 1
        fi
    else
        if ! tar -xvf "$DOWNLOAD_PATH/$DOWNLOAD_FILE" -C "$DOWNLOAD_PATH/$TARGETDIR" --strip-components 1 2>/dev/null >/dev/null; then
            echo "Failed to extract $DOWNLOAD_FILE"
            exit 1
        fi
    fi

    echo "Extracted $DOWNLOAD_FILE"

    cd "$DOWNLOAD_PATH/$TARGETDIR" || {
        echo "Failed to cd into $DOWNLOAD_PATH/$TARGETDIR"
        exit 1
    }
}

print_flags() {
    echo "Flags: CFLAGS \"$CFLAGS\", CXXFLAGS \"$CXXFLAGS\", LDFLAGS \"$LDFLAGS\", LDEXEFLAGS \"$LDEXEFLAGS\""
}

execute() {

    if [[ "$1" == *configure* ]]; then
        print_flags
    fi

    echo "$ $*"

    OUTPUT=$("$@" 2>&1)

    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        echo "$OUTPUT"
        echo ""
        echo "Failed to Execute $*" >&2
        # shellcheck disable=SC2034 # read by report_failure() in this fragment
        LAST_FAILED_COMMAND="$*"
        exit 1
    fi
}

cmake() {
    if [[ "$1" == "--build" ]]; then
        command cmake "$@"
    else
        command cmake -DCMAKE_POLICY_VERSION_MINIMUM=3.5 "$@"
    fi
}

build() {
    echo ""
    echo "building $1 - version $2"
    echo "======================="
    CURRENT_PACKAGE_NAME=$1
    # shellcheck disable=SC2034 # read by download() callers in the package fragments
    CURRENT_PACKAGE_VERSION=$2

    # The optional variant covers configure changes that leave the upstream version
    # alone, such as the Intel macOS linker fixes.
    BUILD_LOCK_VERSION="$2"
    if [ -n "$3" ]; then
        BUILD_LOCK_VERSION+=" $3"
    fi

    # A mismatch always rebuilds: skipping it leaves the old library in workspace/,
    # and FFmpeg then links against something the script no longer requests.
    if [ -f "$PACKAGES/$1.done" ]; then
        if grep -Fx "$BUILD_LOCK_VERSION" "$PACKAGES/$1.done" >/dev/null; then
            echo "$1 version $2 already built. Remove $PACKAGES/$1.done lockfile to rebuild it."
            return 1
        fi
        echo "$1 was built with different inputs and will be rebuilt at $2"
    fi

    return 0
}

library_exists() {
    pkg-config --exists "$1"
}

# The compute capability of the installed NVIDIA GPU, in the two-digit form nvcc wants
# ("12.0" -> 120), or empty when it cannot be determined. Only the first GPU is looked at:
# ffmpeg cannot produce a multi-architecture CUDA build anyway.
nvidia_gpu_compute_capability() {
    if ! command_exists "nvidia-smi"; then
        return
    fi

    nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null |
        head -n 1 |
        sed -n 's/^ *\([0-9]\{1,\}\)\.\([0-9]\)[0-9]* *$/\1\2/p'
}

# Whether this nvcc can generate code for a compute capability. Asked by compiling an empty
# translation unit rather than by mapping toolkit versions to architectures, because the
# mapping changes with every CUDA release in both directions: old architectures get dropped
# and new ones added.
nvcc_supports_compute_capability() {
    NVCC_PROBE_DIR=$(mktemp -d)
    : >"$NVCC_PROBE_DIR/probe.cu"
    if nvcc -gencode "arch=compute_$1,code=sm_$1" -c "$NVCC_PROBE_DIR/probe.cu" \
        -o "$NVCC_PROBE_DIR/probe.o" >/dev/null 2>&1; then
        rm -rf "$NVCC_PROBE_DIR"
        return 0
    fi
    rm -rf "$NVCC_PROBE_DIR"
    return 1
}

# GCC 15, which Ubuntu 26.04 ships, defaults to -std=gnu23, where "bool", "true" and
# "false" became keywords. Several of the older packages here use them as struct members
# or enumeration constants, which C23 rejects outright rather than warning about. Build
# those as gnu17. Probed once and cached, because the answer cannot change during a run;
# compilers that predate the option leave it empty and already default to a usable
# standard. The leading space lets callers append this to an existing CFLAGS.
PRE_C23_CFLAG=""
PRE_C23_CFLAG_PROBED=false
pre_c23_cflag() {
    if ! $PRE_C23_CFLAG_PROBED; then
        PRE_C23_CFLAG_PROBED=true
        if echo 'int main(void) { return 0; }' | "${CC:-cc}" -std=gnu17 -x c - -o /dev/null >/dev/null 2>&1; then
            PRE_C23_CFLAG=" -std=gnu17"
        fi
    fi
    echo "$PRE_C23_CFLAG"
}

build_done() {
    if [ -n "$3" ]; then
        printf '%s %s\n' "$2" "$3" >"$PACKAGES/$1.done"
    else
        echo "$2" >"$PACKAGES/$1.done"
    fi
}

verify_binary_type() {
    if ! command_exists "file"; then
        return
    fi

    BINARY_TYPE=$(file "$WORKSPACE/bin/ffmpeg" | sed -n 's/^.*\:\ \(.*$\)/\1/p')
    echo ""
    case $BINARY_TYPE in
    "Mach-O 64-bit executable arm64")
        echo "Successfully built Apple Silicon for ${OSTYPE}: ${BINARY_TYPE}"
        ;;
    *)
        echo "Successfully built binary for ${OSTYPE}: ${BINARY_TYPE}"
        ;;
    esac
}

cleanup() {
    remove_dir "$PACKAGES"
    remove_dir "$WORKSPACE"
    echo "Cleanup done."
    echo ""
}

##
## Build log and failure report
##

# The state of the log mirror and of the exit handling. Written here and in
# start_build_logging(), read by stop_build_logging()/on_exit()/report_failure()
# in this fragment and by the trap lines in the entry point.
# shellcheck disable=SC2034 # read by report_failure() and stop_build_logging()
BUILD_LOG=""
# shellcheck disable=SC2034 # read by stop_build_logging()
BUILD_LOG_FIFO_DIR=""
# shellcheck disable=SC2034 # read by stop_build_logging()
BUILD_TEE_PID=""
# shellcheck disable=SC2034 # set by the entry point's INT/TERM traps, read by on_exit()
USER_INTERRUPTED=false
# shellcheck disable=SC2034 # appended by do_update(), read by on_exit()
EXIT_CLEANUP_DIRS=""

start_build_logging() {
    # Mirrors everything the script prints into $CWD/build.log while keeping it
    # on the terminal: tee holds both ends. A FIFO rather than process
    # substitution, so stop_build_logging() can drain it deterministically -
    # "exec > >(tee ...) 2>&1" can lose its last lines, because bash exits
    # without waiting for the tee behind the redirection and the failure report
    # would be exactly those last lines.
    BUILD_LOG="$CWD/build.log"
    BUILD_LOG_FIFO_DIR=$(mktemp -d) || return 0
    if ! mkfifo "$BUILD_LOG_FIFO_DIR/log.fifo"; then
        rm -rf "$BUILD_LOG_FIFO_DIR"
        BUILD_LOG_FIFO_DIR=""
        return 0
    fi
    tee "$BUILD_LOG" <"$BUILD_LOG_FIFO_DIR/log.fifo" &
    BUILD_TEE_PID=$!
    exec >"$BUILD_LOG_FIFO_DIR/log.fifo" 2>&1
}

stop_build_logging() {
    if [ -z "$BUILD_TEE_PID" ]; then
        return
    fi
    # Closing both fds ends tee's input, so waiting for it guarantees the log
    # holds everything up to and including what was printed just before this.
    exec >&- 2>&-
    wait "$BUILD_TEE_PID"
    rm -rf "$BUILD_LOG_FIFO_DIR"
    BUILD_TEE_PID=""
}

# One line naming the OS release, for the copy-paste block in report_failure().
os_display_name() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        printf 'macOS %s' "$(sw_vers -productVersion 2>/dev/null)"
    elif [ -r "/etc/os-release" ]; then
        sed -n 's/^PRETTY_NAME="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' /etc/os-release | head -n 1
    else
        uname -s
    fi
}

report_failure() {
    echo ""
    echo "========================================================================"
    echo "The build failed."
    if [ -n "$CURRENT_PACKAGE_NAME" ]; then
        echo "Package being built: $CURRENT_PACKAGE_NAME $CURRENT_PACKAGE_VERSION"
    fi
    if [ -n "$LAST_FAILED_COMMAND" ]; then
        echo "Failed step: $LAST_FAILED_COMMAND"
    fi
    echo ""
    echo "Please open an issue at https://github.com/markus-perl/ffmpeg-build-script/issues"
    echo "and include everything between the lines below plus the full build log:"
    echo "$BUILD_LOG"
    echo ""
    echo "-------------------- copy from here --------------------"
    echo "script:   ffmpeg-build-script v$SCRIPT_VERSION (FFmpeg $FFMPEG_VERSION)"
    echo "invoked:  $PROGNAME $INVOCATION_ARGS"
    echo "os:       $(os_display_name)"
    echo "kernel:   $(uname -sr)"
    echo "arch:     $(uname -m)"
    echo "compiler: $("${CC:-cc}" --version 2>/dev/null | head -n 1)"
    echo "jobs:     $MJOBS"
    if $NONFREE_AND_GPL; then
        echo "license:  GPL and non-free"
    else
        echo "license:  LGPL (default)"
    fi
    echo "tls:      $TLS_BACKEND"
    if [ -n "$WHISPER_BACKEND" ]; then
        echo "whisper:  $WHISPER_BACKEND"
    fi
    if [ -n "$LDEXEFLAGS" ]; then
        echo "mode:     full static"
    fi
    echo "--------------------- copy to here ---------------------"
}

# Single EXIT handler for every way the script can end: normal completion, a
# failed build step, Ctrl+C. The entry point installs it with "trap on_exit
# EXIT", so no fragment may set its own EXIT trap afterwards - it would replace
# this one, losing the .git restore and the log teardown. do_update() hands its
# temp dir to EXIT_CLEANUP_DIRS for the same reason.
on_exit() {
    EXIT_STATUS=$?
    # Restore .git even when the build fails and exits early; see 95-ffmpeg.sh.
    if [ -d "$CWD/.git.bak" ]; then
        mv "$CWD/.git.bak" "$CWD/.git"
    fi
    # shellcheck disable=SC2086 # deliberate word splitting over whitespace-separated dirs
    for EXIT_DIR in $EXIT_CLEANUP_DIRS; do
        rm -rf "$EXIT_DIR"
    done
    # The bug-report hint is only for genuine failures of a supported build: an
    # interrupted run was stopped deliberately, an explicit --ffmpeg-version
    # (snapshot, or a release outside FFMPEG_MAJOR_VERSION.x) is a combination the
    # pinned library versions were never tested against - 40-cli.sh already tells
    # those users to retry with the default version before reporting anything -
    # and SUPPRESS_FAILURE_REPORT covers an early exit whose cause 40-cli.sh
    # already identified as external (e.g. the default FFmpeg version lookup
    # failing because ffmpeg.org could not be reached). The default build itself
    # (the latest FFMPEG_MAJOR_VERSION.x release) is still a supported build even
    # though FFMPEG_UNPINNED is set for it too, so this checks
    # FFMPEG_VERSION_EXPLICIT instead.
    if [ "$EXIT_STATUS" -ne 0 ] && ! $USER_INTERRUPTED && ! $FFMPEG_VERSION_EXPLICIT && ! $SUPPRESS_FAILURE_REPORT; then
        report_failure
    fi
    stop_build_logging
    return "$EXIT_STATUS"
}

# Is $1 an older version than $2? Used only to recognize a tree that is ahead of
# the newest release, so a wrong answer costs a warning and nothing else. Hosts
# whose sort has no -V fall back to "not older", which reduces the check to the
# plain equality test the caller already did.
version_lt() {
    if ! printf '1.0\n' | sort -V >/dev/null 2>&1; then
        return 1
    fi

    [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n 1)" = "$1" ]
}

# latest_script_release_tag
# Prints the tag ("vX.Y.Z") of the latest ffmpeg-build-script release on GitHub,
# or fails (nothing printed) if it cannot be resolved. Shared by do_update() and
# check_for_script_update() so the two never disagree on what "latest" means.
#
# "/releases/latest" redirects to "/releases/tag/<tag>", so the tag falls out of
# the resolved URL. This is the same trick web-install.sh uses, and for the same
# reason: api.github.com is rate limited to 60/hour per IP, which breaks behind
# a shared address, and reading its answer would need jq.
latest_script_release_tag() {
    LATEST_TAG=""
    if LATEST_TAG=$(curl -fsSL --connect-timeout 10 --max-time 20 -o /dev/null --write-out '%{url_effective}' \
        "$SCRIPT_REPO_URL/releases/latest" | sed 's|.*/releases/tag/||'); then
        case "$LATEST_TAG" in
        v[0-9]*)
            [ "$LATEST_TAG" = "${LATEST_TAG#*/}" ] || LATEST_TAG=""
            ;;
        *)
            LATEST_TAG=""
            ;;
        esac
    else
        LATEST_TAG=""
    fi

    [ -n "$LATEST_TAG" ] || return 1
    printf '%s' "$LATEST_TAG"
}

# Prints a one-time notice if a newer ffmpeg-build-script release exists, and
# how to get it. Called once at the start of a build. Never blocks or fails the
# build: a network hiccup here just means the notice is silently skipped.
check_for_script_update() {
    UPDATE_CHECK_TAG=$(latest_script_release_tag) || return 0
    UPDATE_CHECK_VERSION="${UPDATE_CHECK_TAG#v}"

    # version_gte rather than version_lt/sort -V: BSD sort on macOS has no -V,
    # which would make version_lt silently report "not older" and this would then
    # advertise a downgrade as the latest release whenever the local tree is
    # already ahead of the newest tag (SCRIPT_VERSION names the *next* release,
    # so a tree built from main routinely is).
    if version_gte "$SCRIPT_VERSION" "$UPDATE_CHECK_VERSION"; then
        return 0
    fi

    echo ""
    echo "A newer version of ffmpeg-build-script is available: $UPDATE_CHECK_TAG (you have v$SCRIPT_VERSION)."
    # shellcheck disable=SC2154 # $SCRIPT_DIR is exported by the ../build-ffmpeg entry point
    if [ -d "$SCRIPT_DIR/.git" ]; then
        echo "Update with: git pull"
    else
        echo "Update with: $PROGNAME --update"
    fi
    echo ""
}

# Replace this checkout with the newest release. Deliberately does not build:
# the caller exits right afterwards, because half of the functions in this shell
# would then be the old ones while the tree on disk is the new one.
do_update() {
    UPDATE_REPO="$SCRIPT_REPO_URL"

    for UPDATE_REQUIRED in curl tar sed; do
        if ! command_exists "$UPDATE_REQUIRED"; then
            echo "$UPDATE_REQUIRED not installed." >&2
            return 1
        fi
    done

    # shellcheck disable=SC2154 # $SCRIPT_DIR is exported by the ../build-ffmpeg entry point
    UPDATE_DIR="$SCRIPT_DIR"

    # A working tree is not ours to overwrite: dropping a release tarball on top
    # of it would throw away local commits, and git can do this properly anyway.
    if [ -d "$UPDATE_DIR/.git" ]; then
        echo "$UPDATE_DIR is a git checkout. Run 'git pull' there instead." >&2
        return 1
    fi

    if [ ! -w "$UPDATE_DIR" ]; then
        echo "$UPDATE_DIR is not writable." >&2
        echo "Update as the user that owns it, or rerun with sudo." >&2
        return 1
    fi

    if ! UPDATE_TAG=$(latest_script_release_tag); then
        echo "Failed to resolve the latest release of $UPDATE_REPO" >&2
        return 1
    fi

    UPDATE_VERSION="${UPDATE_TAG#v}"

    if [ "$UPDATE_VERSION" = "$SCRIPT_VERSION" ]; then
        echo "Already up to date ($UPDATE_TAG)."
        return 0
    fi

    # SCRIPT_VERSION names the *next* release, so a tree built from main is
    # routinely ahead of the newest tag. Updating then is a downgrade, which is
    # a legitimate thing to ask for - just worth saying out loud.
    if version_lt "$UPDATE_VERSION" "$SCRIPT_VERSION"; then
        echo "Warning: the latest release $UPDATE_TAG is older than this tree (v$SCRIPT_VERSION)."
    fi

    echo "Updating from v$SCRIPT_VERSION to $UPDATE_TAG"

    # Staged inside the tree being replaced so the final move is a rename within
    # one filesystem rather than a copy across two.
    if ! UPDATE_TMP=$(mktemp -d "$UPDATE_DIR/.update.XXXXXX"); then
        echo "Failed to create a temporary directory in $UPDATE_DIR" >&2
        return 1
    fi

    # Removed by on_exit() rather than through a trap of its own: setting an
    # EXIT trap here would replace the entry point's, losing the .git restore,
    # the failure report and the log teardown.
    # shellcheck disable=SC2034 # read by on_exit() in this fragment
    EXIT_CLEANUP_DIRS+=" $UPDATE_TMP"

    if ! curl -fsSL -o "$UPDATE_TMP/release.tar.gz" "$UPDATE_REPO/archive/refs/tags/$UPDATE_TAG.tar.gz"; then
        echo "Failed to download $UPDATE_REPO/archive/refs/tags/$UPDATE_TAG.tar.gz" >&2
        return 1
    fi

    # --strip-components=1 (GNU and BSD tar) drops the archive's top-level
    # directory, so the tree lands directly in the staging directory.
    if ! tar -xzf "$UPDATE_TMP/release.tar.gz" -C "$UPDATE_TMP" --strip-components=1; then
        echo "Failed to extract the release archive" >&2
        return 1
    fi

    # Nothing is destroyed before the download is known to be complete. A
    # truncated archive must leave the existing installation alone rather than
    # half-replace it.
    if [ ! -f "$UPDATE_TMP/build-ffmpeg" ] || [ ! -f "$UPDATE_TMP/src/00-header.sh" ]; then
        echo "The downloaded release is incomplete, keeping the current version." >&2
        return 1
    fi

    # src/ is replaced wholesale rather than overlaid: a fragment that the new
    # release renamed or dropped would otherwise stay behind, and the entry
    # point's source list is explicit precisely so such orphans stay inert.
    # packages/ and workspace/ are the user's build state and are never touched.
    rm -rf "$UPDATE_DIR/src"
    if ! mv "$UPDATE_TMP/src" "$UPDATE_DIR/src"; then
        echo "Failed to install the new src/ into $UPDATE_DIR" >&2
        return 1
    fi

    # Overwriting build-ffmpeg under a running shell is safe - it was read in
    # full at startup and is not consulted again - but the caller has to exit
    # right after this rather than go on to build, because the functions already
    # in memory are the old release's while src/ on disk is the new one.
    # The second pattern picks up the dotfiles; both are guarded with -e because
    # an unmatched glob expands to itself.
    rm -f "$UPDATE_TMP/release.tar.gz"
    for UPDATE_FILE in "$UPDATE_TMP"/* "$UPDATE_TMP"/.[!.]*; do
        if [ -e "$UPDATE_FILE" ]; then
            mv -f "$UPDATE_FILE" "$UPDATE_DIR/"
        fi
    done

    chmod +x "$UPDATE_DIR/build-ffmpeg"

    echo ""
    echo "Updated to $UPDATE_TAG."
    echo ""
    echo "Packages whose version changed will be rebuilt automatically on the next"
    echo "build. To start from a clean tree instead:"
    echo ""
    echo "  ./build-ffmpeg --cleanup --build"
    echo ""
}
