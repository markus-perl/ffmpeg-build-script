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

package_sha_var() {
    # package_sha_var <package-name>
    # Maps a build() package name onto a reference to the checksum element of its
    # VER_ array in the table at the top of this script: uppercase,
    # non-alphanumerics become underscores, element 1 is the SHA-256.
    PACKAGE_SHA_VAR_NAME=$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')
    printf 'VER_%s[1]' "${PACKAGE_SHA_VAR_NAME//[^A-Z0-9]/_}"
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

    if [ -f "$PACKAGES/$1.done" ]; then
        if grep -Fx "$2" "$PACKAGES/$1.done" >/dev/null; then
            echo "$1 version $2 already built. Remove $PACKAGES/$1.done lockfile to rebuild it."
            return 1
        elif $LATEST; then
            echo "$1 is outdated and will be rebuilt with latest version $2"
            return 0
        else
            echo "$1 is outdated, but will not be rebuilt. Pass in --latest to rebuild it or remove $PACKAGES/$1.done lockfile."
            return 1
        fi
    fi

    return 0
}

library_exists() {
    pkg-config --exists "$1"
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
