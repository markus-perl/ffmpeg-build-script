# shellcheck shell=bash
usage() {
    echo "Usage: $PROGNAME [OPTIONS]"
    echo "Options:"
    echo "  -h, --help                     Display usage information"
    echo "      --version                  Display version information"
    echo "      --update                   Update this script to the latest release and exit"
    echo "      --list-packages            List the packages in build order, with versions"
    echo "  -b, --build                    Starts the build process"
    echo "      --enable-gpl-and-non-free  Enable GPL and non-free codecs  - https://ffmpeg.org/legal.html"
    echo "      --disable-lv2              Disable LV2 libraries"
    echo "  -c, --cleanup                  Remove all working dirs"
    echo "      --small                    Prioritize small size over speed and usability; don't build manpages"
    echo "      --full-static              Build a full static FFmpeg binary (eg. glibc, pthreads etc...) **only Linux**"
    echo "                                 Note: Because of the NSS (Name Service Switch), glibc does not recommend static links."
    echo "      --skip-install             Don't install FFmpeg, FFprobe, and FFplay binaries to your system"
    echo "      --auto-install             Install FFmpeg, FFprobe, and FFplay binaries to your system"
    echo "                                 Note: Without --skip-install or --auto-install the script will prompt you to install."
    echo ""
}

echo "ffmpeg-build-script v$SCRIPT_VERSION"
echo "========================="
echo ""

while (($# > 0)); do
    case $1 in
    -h | --help)
        usage
        exit 0
        ;;
    --version)
        echo "$SCRIPT_VERSION"
        exit 0
        ;;
    --update)
        # Exits either way: the tree on disk no longer matches the functions
        # this shell already sourced, so nothing may run after a successful
        # update.
        do_update
        exit $?
        ;;
    --list-packages)
        # Only recorded here. The VER_ arrays live next to their build_
        # functions, which are sourced after this fragment, so the listing
        # itself happens in 90-build-order.sh once they exist.
        LIST_PACKAGES=true
        shift
        ;;
    -b | --build)
        bflag='-b'
        shift
        ;;
    --enable-gpl-and-non-free)
        CONFIGURE_OPTIONS+=("--enable-nonfree")
        CONFIGURE_OPTIONS+=("--enable-gpl")
        NONFREE_AND_GPL=true
        shift
        ;;
    --disable-lv2)
        # shellcheck disable=SC2034 # read by the LV2 gates in src/packages/
        DISABLE_LV2=true
        shift
        ;;
    -c | --cleanup)
        cflag='-c'
        shift
        ;;
    --full-static)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "Error: A full static binary can only be build on Linux."
            exit 1
        fi
        LDEXEFLAGS="-static -fPIC"
        CFLAGS+=" -fPIC"
        CXXFLAGS+=" -fPIC"
        shift
        ;;
    --small)
        CONFIGURE_OPTIONS+=("--enable-small" "--disable-doc")
        # shellcheck disable=SC2034 # read by the manpage install in 95-ffmpeg.sh
        MANPAGES=0
        shift
        ;;
    --skip-install)
        SKIPINSTALL=yes
        if [[ "$AUTOINSTALL" == "yes" ]]; then
            echo "Error: The option --skip-install cannot be used with --auto-install"
            exit 1
        fi
        shift
        ;;
    --auto-install)
        AUTOINSTALL=yes
        if [[ "$SKIPINSTALL" == "yes" ]]; then
            echo "Error: The option --auto-install cannot be used with --skip-install"
            exit 1
        fi
        shift
        ;;
    *)
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
done

# The cleanup is deferred until the whole command line has been parsed and
# validated, so a typo cannot trigger destructive work.
if [ -n "$cflag" ]; then
    cleanup
fi

if [ -z "$bflag" ] && ! $LIST_PACKAGES; then
    if [ -z "$cflag" ]; then
        usage
        exit 1
    fi
    exit 0
fi

# --list-packages is a query, so it stops here: nothing below is needed to
# print the list, and creating packages/ and workspace/ or demanding a
# compiler would be a surprising side effect. Returning rather than exiting
# hands control back to the entry point, which goes on to source the package
# fragments; 90-build-order.sh prints the list once their VER_ arrays exist.
# It takes precedence over --build.
if $LIST_PACKAGES; then
    return 0
fi

echo "Using $MJOBS make jobs simultaneously."

if $NONFREE_AND_GPL; then
    echo "With GPL and non-free codecs"
fi

if [ -n "$LDEXEFLAGS" ]; then
    echo "Start the build in full static mode."
fi

mkdir -p "$PACKAGES"
# Create the workspace subdirectories up front. CFLAGS and LDFLAGS point at
# include/ and lib/ from the very first package, and a -L pointing at a
# non-existent directory makes configure tests fail on newer toolchains.
# Without this the build order silently depends on whichever package happens
# to be built first creating them.
mkdir -p "$WORKSPACE" "$WORKSPACE"/lib/pkgconfig "$WORKSPACE"/include "$WORKSPACE"/bin

export PATH="${WORKSPACE}/bin:$PATH"

# The Debian/Ubuntu multiarch directory, e.g. x86_64-linux-gnu or aarch64-linux-gnu. This
# used to be hardcoded to x86_64-linux-gnu, which meant that on an arm64 Linux host none of
# the system .pc files were on the search path at all: build_pkg_config configures its own
# pkg-config with --with-pc-path pointing at the workspace, so PKG_CONFIG_PATH is the only
# way system packages are ever found. Every library this script probes for rather than
# builds - libva in build_vaapi, alsa in build_openal, libpulse in build_libpulse - silently
# failed its check and disabled itself on arm64, with no message. Ask the compiler rather
# than deriving it from uname: it is the same value dpkg-architecture reports, and it stays
# empty on distributions that do not use multiarch, where the plain /usr/lib entries below
# are what matches.
MULTIARCH_DIR="$("${CC:-cc}" -print-multiarch 2>/dev/null)"

PKG_CONFIG_PATH="$WORKSPACE/lib/pkgconfig"
if [ -n "$MULTIARCH_DIR" ]; then
    PKG_CONFIG_PATH+=":/usr/local/lib/${MULTIARCH_DIR}/pkgconfig:/usr/lib/${MULTIARCH_DIR}/pkgconfig"
fi
PKG_CONFIG_PATH+=":/usr/local/lib/pkgconfig:/usr/local/share/pkgconfig"
PKG_CONFIG_PATH+=":/usr/lib/pkgconfig:/usr/share/pkgconfig:/usr/lib64/pkgconfig"
export PKG_CONFIG_PATH

if ! command_exists "make"; then
    echo "make not installed."
    exit 1
fi

if ! command_exists "g++"; then
    echo "g++ not installed."
    exit 1
fi

if ! command_exists "curl"; then
    echo "curl not installed."
    exit 1
fi

if ! command_exists "cargo"; then
    echo "cargo not installed. rav1e encoder will not be available."
fi

if ! command_exists "python3"; then
    echo "python3 command not found. Lv2 filter and dav1d decoder will not be available."
fi
