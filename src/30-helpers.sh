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
    # Prints the highest release version listed at https://ffmpeg.org/releases/,
    # or fails if the index cannot be fetched or contains nothing usable.
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
    LATEST_INDEX=$(curl -L --fail --silent https://ffmpeg.org/releases/) || return 1

    LATEST_FOUND=""
    while read -r LATEST_CANDIDATE; do
        [ -n "$LATEST_CANDIDATE" ] || continue
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

    # The pinned version is fetched from the GitHub tag archive, which is what its
    # checksum in 10-versions.sh was taken from. Any other version comes from
    # ffmpeg.org, the same place --ffmpeg-version=latest discovers it, so that
    # "this version exists" means one thing rather than two.
    if $FFMPEG_UNPINNED; then
        printf 'https://ffmpeg.org/releases/ffmpeg-%s.tar.gz' "$1"
    else
        printf 'https://github.com/FFmpeg/FFmpeg/archive/refs/tags/n%s.tar.gz' "$1"
    fi
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

    DOWNLOAD_PATH="$PACKAGES"
    DOWNLOAD_FILE="${2:-"${1##*/}"}"

    if [[ "$DOWNLOAD_FILE" =~ tar. ]]; then
        TARGETDIR="${DOWNLOAD_FILE%.*}"
        TARGETDIR="${3:-"${TARGETDIR%.*}"}"
    else
        TARGETDIR="${3:-"${DOWNLOAD_FILE%.*}"}"
    fi

    # The expected checksum is keyed off the package currently being built, which
    # build() records in CURRENT_PACKAGE_NAME. An unset or empty checksum element
    # means the package is not pinned yet and verification is skipped.
    DOWNLOAD_SHA_VAR=$(package_sha_var "$CURRENT_PACKAGE_NAME")
    DOWNLOAD_SHA="${!DOWNLOAD_SHA_VAR}"

    if [ ! -f "$DOWNLOAD_PATH/$DOWNLOAD_FILE" ] || [ ! -s "$DOWNLOAD_PATH/$DOWNLOAD_FILE" ]; then
        echo "Downloading $1 as $DOWNLOAD_FILE"

        if ! download_with_retries "$1" "$DOWNLOAD_PATH/$DOWNLOAD_FILE" "$DOWNLOAD_SHA"; then
            echo "Failed to download $1 after $((DOWNLOAD_MAX_RETRIES + 1)) attempts."
            exit 1
        fi

        echo "... Done"
    else
        echo "$DOWNLOAD_FILE has already been downloaded and is not empty."
        # A cached file is never deleted automatically: it may be a deliberately
        # placed local copy, and removing it would also destroy the evidence.
        if ! verify_checksum "$DOWNLOAD_PATH/$DOWNLOAD_FILE" "$DOWNLOAD_SHA"; then
            echo "The cached file $DOWNLOAD_PATH/$DOWNLOAD_FILE is corrupt or does not match the pinned version." >&2
            echo "Delete it and run the build again to download it anew." >&2
            exit 1
        fi
    fi

    make_dir "$DOWNLOAD_PATH/$TARGETDIR"

    if [[ "$DOWNLOAD_FILE" == *"patch"* ]]; then
        return
    fi

    if [ -n "$3" ]; then
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

    # The lockfile records the version the package was built at, so a mismatch
    # means the pin in src/10-versions.sh moved since. That always rebuilds:
    # skipping it left the old library in workspace/, and FFmpeg was then linked
    # against a version the script no longer pins - a build that reported
    # success while shipping something nobody asked for.
    if [ -f "$PACKAGES/$1.done" ]; then
        if grep -Fx "$2" "$PACKAGES/$1.done" >/dev/null; then
            echo "$1 version $2 already built. Remove $PACKAGES/$1.done lockfile to rebuild it."
            return 1
        fi
        echo "$1 was built at a different version and will be rebuilt at $2"
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
    echo "$2" >"$PACKAGES/$1.done"
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

# Replace this checkout with the newest release. Deliberately does not build:
# the caller exits right afterwards, because half of the functions in this shell
# would then be the old ones while the tree on disk is the new one.
do_update() {
    UPDATE_REPO='https://github.com/markus-perl/ffmpeg-build-script'

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

    # "/releases/latest" redirects to "/releases/tag/<tag>", so the tag falls out
    # of the resolved URL. This is the same trick web-install.sh uses, and for
    # the same reason: api.github.com is rate limited to 60/hour per IP, which
    # breaks behind a shared address, and reading its answer would need jq.
    if ! UPDATE_TAG=$(curl -fsSL -o /dev/null --write-out '%{url_effective}' \
        "$UPDATE_REPO/releases/latest" | sed 's|.*/releases/tag/||'); then
        UPDATE_TAG=""
    fi

    case "$UPDATE_TAG" in
    v[0-9]*)
        if [ "$UPDATE_TAG" != "${UPDATE_TAG#*/}" ]; then
            UPDATE_TAG=""
        fi
        ;;
    *)
        UPDATE_TAG=""
        ;;
    esac

    if [ -z "$UPDATE_TAG" ]; then
        echo "Failed to resolve the latest release of $UPDATE_REPO" >&2
        return 1
    fi

    UPDATE_VERSION="${UPDATE_TAG#v}"

    if [ "$UPDATE_VERSION" = "$SCRIPT_VERSION" ]; then
        echo "Already up to date ($UPDATE_TAG)."
        return 0
    fi

    # SCRIPT_VERSION names the *next* release, so a tree built from master is
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

    trap 'rm -rf "$UPDATE_TMP"' EXIT

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
