# shellcheck shell=bash
# This fragment exists to define the globals the later fragments read, and each
# fragment is linted on its own, so a global consumed elsewhere looks unused
# here. The SC2034 disables are per-assignment rather than file-wide on purpose:
# a blanket one would also hide a global that has become genuinely dead.
CWD=$(pwd)
# shellcheck disable=SC2034 # $PACKAGES is read by later fragments
PACKAGES="$CWD/packages"
WORKSPACE="$CWD/workspace"
# shellcheck disable=SC2034 # $CFLAGS is read by later fragments
CFLAGS="-I$WORKSPACE/include -Wno-int-conversion"
# shellcheck disable=SC2034 # $LDFLAGS is read by later fragments
LDFLAGS="-L$WORKSPACE/lib"
# shellcheck disable=SC2034 # $LDEXEFLAGS is read by later fragments
LDEXEFLAGS=""
# shellcheck disable=SC2034 # $EXTRALIBS is read by later fragments
EXTRALIBS="-ldl -lpthread -lm -lz"
MACOS_SILICON=false
CONFIGURE_OPTIONS=()
# shellcheck disable=SC2034 # $NONFREE_AND_GPL is read by later fragments
NONFREE_AND_GPL=false
# Names passed to --disable, as given on the command line. Group names are
# expanded to the packages behind them in 90-build-order.sh, which is the first
# point where PACKAGE_BUILD_ORDER exists to validate them against.
# shellcheck disable=SC2034 # $DISABLE_REQUESTS is read by later fragments
DISABLE_REQUESTS=()
# The TLS backend, "openssl" or "gnutls". Empty until the command line has been
# parsed: the default depends on --enable-gpl-and-non-free, which may appear
# after --tls, so it is resolved once at the end of 40-cli.sh rather than here.
# ffmpeg's configure refuses both at once ("GnuTLS and OpenSSL must not be
# enabled at the same time", configure line 4851), hence one variable and not
# two flags.
# shellcheck disable=SC2034 # $TLS_BACKEND is read by later fragments
TLS_BACKEND=""
# The ggml backend whisper.cpp is compiled for: "cpu", "metal", "cuda" or
# "vulkan". Empty means --whisper was not given, and then whisper.cpp is not
# built at all - it is opt-in because exactly one backend is compiled into the
# binary (see build_whisper) and only the user knows which one matches the
# machine the binary will run on.
# shellcheck disable=SC2034 # $WHISPER_BACKEND is read by later fragments
WHISPER_BACKEND=""
# shellcheck disable=SC2034 # $LIST_PACKAGES is read by later fragments
LIST_PACKAGES=false
# shellcheck disable=SC2034 # $MANPAGES is read by later fragments
MANPAGES=1
# shellcheck disable=SC2034 # $CURRENT_PACKAGE_NAME is read by later fragments
CURRENT_PACKAGE_NAME=""
# shellcheck disable=SC2034 # $CURRENT_PACKAGE_VERSION is read by later fragments
CURRENT_PACKAGE_VERSION=0
# shellcheck disable=SC2034 # $DOWNLOAD_MAX_RETRIES is read by later fragments
DOWNLOAD_MAX_RETRIES=2

# Version comparison function
# Returns: 0 if v1 >= v2, 1 otherwise
version_gte() {
    local ver1="$1"
    local ver2="$2"

    # Handle empty/invalid inputs
    if [[ -z "$ver1" || -z "$ver2" ]]; then
        return 1
    fi

    # Split versions into components
    local IFS='.'
    read -ra V1 <<<"$ver1"
    read -ra V2 <<<"$ver2"

    local max_len=${#V1[@]}
    [[ ${#V2[@]} -gt $max_len ]] && max_len=${#V2[@]}

    for ((i = 0; i < max_len; i++)); do
        local n1="${V1[i]:-0}"
        local n2="${V2[i]:-0}"

        # Strip pre-release suffixes for comparison (e.g., "a1", "rc1")
        n1="${n1%%[a-z]*}"
        n2="${n2%%[a-z]*}"

        # Compare numeric portions
        if ((n1 > n2)); then
            return 0
        elif ((n1 < n2)); then
            return 1
        fi

        # Handle suffixes (release candidates, pre-releases)
        if [[ "$n1" == *[a-z]* && "$n2" != *[a-z]* ]]; then
            return 1 # n1 has suffix, so it's less than stable n2
        elif [[ "$n2" == *[a-z]* && "$n1" != *[a-z]* ]]; then
            return 0 # n2 has suffix, so n1 is greater
        fi

        # Strip leading zeros and compare remaining parts
        n1="${n1#0}" || n1=0
        n2="${n2#0}" || n2=0
    done

    return 0 # Versions are equal or unknown
}

# Check if version meets minimum requirement (v >= min)
version_satisfies() {
    local current="$1"
    local minimum="$2"

    if ! version_gte "$current" "$minimum"; then
        return 1
    fi

    return 0
}

command_exists() {
    if ! [[ -x $(command -v "$1") ]]; then
        return 1
    fi

    return 0
}

# Does the C++ compiler accept this flag? Compiles an empty translation unit to find out.
# Written for -march feature flags, where "a compiler is installed" and "the compiler
# knows this architecture" are very different questions - see build_x265.
cxx_supports_flag() {
    printf 'int main(void) { return 0; }\n' |
        "${CXX:-c++}" "$1" -x c++ -c -o /dev/null - >/dev/null 2>&1
}

# Check for Apple Silicon
if [[ ("$(uname -m)" == "arm64") && ("$OSTYPE" == "darwin"*) ]]; then
    # If arm64 AND darwin (macOS)
    export ARCH=arm64
    export MACOSX_DEPLOYMENT_TARGET=11.0
    CXX=$(which clang++)
    export CXX
    # shellcheck disable=SC2034 # $MACOS_SILICON is read by later fragments
    MACOS_SILICON=true
    echo "Apple Silicon detected."

    # get macos version
    MACOS_VERSION=$(sw_vers -productVersion)
    echo "macOS Version: $MACOS_VERSION"

    if command_exists "clang++"; then
        echo "clang++ is installed. Version: $(clang++ --version | head -n 1)"
    else
        echo "clang++ is not installed. Please install Xcode."
        exit 1
    fi
fi

# Speed up the process
# Env Var NUMJOBS overrides automatic detection
if [[ -n "$NUMJOBS" ]]; then
    MJOBS="$NUMJOBS"
elif [[ -f /proc/cpuinfo ]]; then
    MJOBS=$(grep -c processor /proc/cpuinfo)
elif [[ "$OSTYPE" == "darwin"* ]]; then
    MJOBS=$(sysctl -n machdep.cpu.thread_count)
    # shellcheck disable=SC2034 # $CONFIGURE_OPTIONS is read by later fragments
    CONFIGURE_OPTIONS=("--enable-videotoolbox")
    # shellcheck disable=SC2034 # $MACOS_LIBTOOL is read by later fragments
    MACOS_LIBTOOL="$(which libtool)" # gnu libtool is installed in this script and need to avoid name conflict
else
    # shellcheck disable=SC2034 # $MJOBS is read by later fragments
    MJOBS=4
fi
