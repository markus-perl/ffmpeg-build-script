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
    echo "      --disable=NAME[,NAME...]   Do not build these libraries. Repeatable."
    echo "                                 --list-packages shows every name that can be disabled."
    echo "      --ffmpeg-version=VERSION   Build this FFmpeg release instead of the pinned $FFMPEG_VERSION."
    echo "                                 VERSION is a release number (e.g. 9.0.1), \"latest\","
    echo "                                 or \"snapshot\" for the current FFmpeg master."
    echo "                                 Release versions are looked up at https://ffmpeg.org/releases/."
    echo "                                 Only the pinned version is verified against a checksum"
    echo "                                 and tested against the library versions this script builds."
    echo "      --tls=BACKEND              TLS backend for https/tls/dtls: gnutls or openssl"
    echo "                                 Default: openssl with --enable-gpl-and-non-free, gnutls otherwise."
    echo "      --whisper=BACKEND          Build whisper.cpp for the af_whisper filter (speech to text)."
    echo "                                 BACKEND is cpu, metal (macOS), cuda (Linux, needs nvcc)"
    echo "                                 or vulkan (Linux, needs glslc and a Vulkan loader)."
    echo "                                 Off by default: exactly one backend is compiled in, so"
    echo "                                 it has to match the machine that runs the binary."
    echo "                                 Speech models are not shipped - af_whisper takes a"
    echo "                                 model=/path at runtime, see the README."
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
    --ffmpeg-version=*)
        FFMPEG_VERSION_REQUEST="${1#*=}"
        if [ "$FFMPEG_VERSION_REQUEST" = "latest" ]; then
            echo "Looking up the latest FFmpeg release on https://ffmpeg.org/releases/ ..."
            if ! FFMPEG_VERSION_REQUEST=$(latest_ffmpeg_version); then
                echo "Error: could not determine the latest FFmpeg release from https://ffmpeg.org/releases/." >&2
                echo "Pass an explicit version instead, e.g. --ffmpeg-version=$FFMPEG_VERSION." >&2
                exit 1
            fi
            echo "Latest FFmpeg release: $FFMPEG_VERSION_REQUEST"
        fi

        if [ "$FFMPEG_VERSION_REQUEST" != "snapshot" ] &&
            [[ ! "$FFMPEG_VERSION_REQUEST" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
            echo "Error: --ffmpeg-version accepts a release number such as 9.0.1, \"latest\" or \"snapshot\", not \"$FFMPEG_VERSION_REQUEST\"."
            exit 1
        fi

        if [ "$FFMPEG_VERSION_REQUEST" != "$FFMPEG_VERSION" ]; then
            FFMPEG_VERSION="$FFMPEG_VERSION_REQUEST"
            FFMPEG_UNPINNED=true
            # VER_FFMPEG[0] is what --list-packages prints, [1] is the checksum
            # download() verifies against. The checksum belongs to the pinned
            # tarball and to no other, and an empty one means "not pinned", which
            # is exactly what this is - see verify_checksum.
            # shellcheck disable=SC2034 # read indirectly by download(), see 10-versions.sh
            VER_FFMPEG[0]="$FFMPEG_VERSION"
            # shellcheck disable=SC2034 # read indirectly by download(), see 10-versions.sh
            VER_FFMPEG[1]=""

            # Fail here rather than after an hour of building dependencies: the
            # ffmpeg download is the very last step of the run.
            if ! curl -L --fail --silent --head -o /dev/null "$(ffmpeg_tarball_url "$FFMPEG_VERSION")"; then
                echo "Error: FFmpeg $FFMPEG_VERSION is not available at $(ffmpeg_tarball_url "$FFMPEG_VERSION")." >&2
                echo "Check https://ffmpeg.org/releases/ for release numbers, or use \"snapshot\"." >&2
                exit 1
            fi
        fi
        shift
        ;;
    --tls=*)
        TLS_BACKEND="${1#*=}"
        case $TLS_BACKEND in
        gnutls | openssl) ;;
        *)
            echo "Error: --tls accepts \"gnutls\" or \"openssl\", not \"$TLS_BACKEND\"."
            exit 1
            ;;
        esac
        shift
        ;;
    --whisper=*)
        # Same shape as --tls: one value, validated here so a typo costs a second
        # instead of an hour. The OS checks are part of the validation and not a
        # gate inside build_whisper, because the whole package is opt-in - asking
        # for a backend this host cannot build is a mistake worth reporting up
        # front, not something to silently skip.
        WHISPER_BACKEND="${1#*=}"
        case $WHISPER_BACKEND in
        cpu) ;;
        metal)
            if [[ ! "$OSTYPE" == "darwin"* ]]; then
                echo "Error: --whisper=metal is macOS only. Use cpu, cuda or vulkan here."
                exit 1
            fi
            ;;
        cuda | vulkan)
            if [[ ! "$OSTYPE" == "linux-gnu"* ]]; then
                echo "Error: --whisper=$WHISPER_BACKEND is Linux only. Use cpu, or metal on macOS."
                exit 1
            fi
            ;;
        *)
            echo "Error: --whisper accepts \"cpu\", \"metal\", \"cuda\" or \"vulkan\", not \"$WHISPER_BACKEND\"."
            exit 1
            ;;
        esac
        shift
        ;;
    --disable=*)
        # Split on commas so both --disable=a,b and --disable=a --disable=b work.
        # Validated in 90-build-order.sh, against the package list itself.
        DISABLE_ARG="${1#*=}"
        if [ -z "$DISABLE_ARG" ]; then
            echo "Error: --disable needs at least one name, e.g. --disable=rav1e."
            exit 1
        fi
        IFS=',' read -r -a DISABLE_ARG_NAMES <<<"$DISABLE_ARG"
        DISABLE_REQUESTS+=("${DISABLE_ARG_NAMES[@]}")
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

if $FFMPEG_UNPINNED; then
    echo ""
    echo "Note: building FFmpeg $FFMPEG_VERSION, which is not the version this script pins."
    echo "      Its tarball is downloaded from ffmpeg.org without a checksum check, and the"
    echo "      library versions below were neither chosen nor tested for it. If the build"
    echo "      fails, retry without --ffmpeg-version before reporting it."
    echo ""
fi

# Resolved here rather than in 20-globals.sh because it depends on an option that
# may appear anywhere on the command line. OpenSSL stays the default for
# --enable-gpl-and-non-free: libsrt and libssh are built against it there, and
# neither has ever been built any other way in this script.
if [ -z "$TLS_BACKEND" ]; then
    if $NONFREE_AND_GPL; then
        TLS_BACKEND="openssl"
    else
        TLS_BACKEND="gnutls"
    fi
fi
echo "TLS backend: $TLS_BACKEND"

# Two packages are built against the workspace OpenSSL and go away with it:
# libssh, whose cmake picks between OpenSSL, gcrypt and mbedTLS and has no GnuTLS
# backend at all, and libsrt, whose GnuTLS backend does not compile against the
# pinned nettle (see build_srt). Said once here rather than as a surprise in the
# build log an hour later, where their own guards report it.
if [ "$TLS_BACKEND" = "gnutls" ]; then
    echo "Note: libssh (sftp://) will be skipped - it needs OpenSSL."
    if $NONFREE_AND_GPL; then
        echo "Note: libsrt will be skipped - its encryption layer needs OpenSSL."
    fi
fi

if [ -n "$WHISPER_BACKEND" ]; then
    echo "whisper.cpp backend: $WHISPER_BACKEND"
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
