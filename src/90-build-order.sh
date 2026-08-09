# shellcheck shell=bash
##
## Build order
##
# The functions above are invoked in this order. They intentionally run in the
# current shell and not in a subshell: many of them mutate global state that
# later packages and the final FFmpeg configure depend on (CONFIGURE_OPTIONS,
# CFLAGS/LDFLAGS/CXXFLAGS, EXTRALIBS, PATH, the OPENSSL_* exports) and the
# working directory carries over from download() just like it did when these
# blocks were sequential top-level code. Isolating each package in a subshell
# would change behavior and is out of scope for this refactor.
PACKAGE_BUILD_ORDER=(
    ## build tools
    giflib
    pkg_config
    nasm
    zlib
    xz
    bzip2
    m4
    autoconf
    automake
    libtool
    # after automake: yasm is built from a commit archive and autogen.sh needs autotools
    yasm
    gettext
    openssl
    gmp
    nettle
    gnutls
    cmake

    ## video library
    meson_and_ninja
    dav1d
    svtav1
    rav1e
    x264
    x265
    openh264
    vvenc
    libvpx
    xvidcore
    vid_stab
    frei0r
    av1
    zimg
    libvmaf

    ## audio library
    lv2
    waflib
    serd
    pcre
    zix
    sord
    sratom
    lilv
    ladspa
    opencore
    lame
    opus
    libogg
    libvorbis
    libtheora
    fdk_aac
    soxr
    twolame
    libmysofa
    rubberband
    libopenmpt
    libgme
    chromaprint
    openal
    libpulse

    ## image library
    libpng
    lcms2
    libjxl
    libwebp
    openjpeg

    ## other library
    libsdl
    freetype2
    libsnappy
    libssh

    ## text shaping and subtitle library
    libxml2
    fribidi
    harfbuzz
    gperf
    fontconfig
    libunibreak
    libass
    vapoursynth
    avisynth
    srt
    zvbi

    ## optical media library
    libudfread
    libbluray

    ## zmq library
    libzmq

    ## HWaccel library
    vulkan_headers
    spirv_headers
    spirv_tools
    glslang
    libplacebo
    nv_codec
    vaapi
    libvpl
    amf
    opencl_headers
    opencl_icd_loader
)

##
## --disable
##
# Everything in PACKAGE_BUILD_ORDER can be turned off by name except the entries
# below: the tools that produce the workspace itself, and the TLS stack, which
# --tls selects instead. Inverting the list this way - protect a few, allow the
# rest - means a package added later is disableable without anyone remembering
# to register it, which is the right default for a script that is almost
# entirely optional codec libraries.
DISABLE_PROTECTED=" giflib pkg_config nasm yasm zlib xz bzip2 m4 autoconf automake libtool gettext cmake meson_and_ninja openssl gmp nettle gnutls "

# Group names. One name on the command line, several packages behind it, for the
# clusters where disabling a single member is never what anyone means.
disable_expand_group() {
    case $1 in
    lv2) echo "lv2 waflib serd pcre zix sord sratom lilv" ;;
    vulkan) echo "vulkan_headers spirv_headers spirv_tools glslang libplacebo" ;;
    opencl) echo "opencl_headers opencl_icd_loader" ;;
    bluray) echo "libudfread libbluray" ;;
    *) echo "$1" ;;
    esac
}

# Packages that fail to configure when the named one is missing, so that
# disabling a dependency takes its dependents with it instead of failing an hour
# later. Only relationships that are explicit in the build blocks above are
# listed: libtheora passes --with-ogg-libraries and --with-vorbis-libraries,
# libass passes --enable-fontconfig and --enable-libunibreak, fontconfig needs
# freetype and (on Linux) gperf, libjxl is built with JPEGXL_ENABLE_SKCMS=OFF so
# it uses lcms2. This is not a general dependency solver: a package with an
# undeclared dependency on another can still be disabled into a broken build.
disable_dependents_of() {
    case $1 in
    libogg) echo "libvorbis libtheora" ;;
    libvorbis) echo "libtheora" ;;
    freetype2) echo "fontconfig libass" ;;
    gperf) echo "fontconfig libass" ;;
    fontconfig | libunibreak | fribidi | harfbuzz) echo "libass" ;;
    lcms2) echo "libjxl" ;;
    *) echo "" ;;
    esac
}

# --list-packages. Derives the version and checksum through the same helper
# download() uses, so a package whose VER_ array name has drifted out of sync
# with the name passed to build() shows up here as "MISSING" instead of being
# silently downloaded unverified.
if $LIST_PACKAGES; then
    # Packages that fetch no tarball of their own and so carry no VER_ array:
    # meson and ninja come from pip3. Listed explicitly rather than excusing
    # every absent array, so that a name which has genuinely drifted out of
    # sync still reports as MISSING.
    PACKAGES_WITHOUT_TARBALL=" meson_and_ninja "

    echo "Packages in build order:"
    echo ""
    for PACKAGE in "${PACKAGE_BUILD_ORDER[@]}"; do
        LIST_VERSION_REF=$(package_ver_var "$PACKAGE" 0)
        LIST_SHA_REF=$(package_ver_var "$PACKAGE" 1)
        LIST_VERSION="${!LIST_VERSION_REF}"
        LIST_SHA="${!LIST_SHA_REF}"

        case "$PACKAGES_WITHOUT_TARBALL" in
        *" $PACKAGE "*)
            printf '  %-22s %-28s %s\n' "$PACKAGE" "-" "no tarball"
            continue
            ;;
        esac

        if [ -z "$LIST_VERSION" ]; then
            LIST_STATE="MISSING - no ${LIST_VERSION_REF%%[*} array"
            LIST_VERSION="?"
        elif [ -z "$LIST_SHA" ]; then
            LIST_STATE="not pinned"
        else
            LIST_STATE="pinned"
        fi

        case "$DISABLE_PROTECTED" in
        *" $PACKAGE "*) LIST_STATE="$LIST_STATE, always built" ;;
        esac

        printf '  %-22s %-28s %s\n' "$PACKAGE" "$LIST_VERSION" "$LIST_STATE"
    done
    echo ""
    echo "${#PACKAGE_BUILD_ORDER[@]} packages, then ffmpeg $FFMPEG_VERSION."
    echo ""
    echo "Every name above can be passed to --disable except those marked"
    echo "\"always built\". Group names: lv2, vulkan, opencl, bluray."
    exit 0
fi

# Expand groups, follow dependents to a fixed point, and reject anything that is
# not a package. Runs before the build loop rather than during it so that a typo
# costs a second instead of an hour.
DISABLED_PACKAGES=" "
if [ ${#DISABLE_REQUESTS[@]} -gt 0 ]; then
    DISABLE_QUEUE=()
    for DISABLE_NAME in "${DISABLE_REQUESTS[@]}"; do
        # shellcheck disable=SC2207 # deliberate word splitting: groups expand to several names
        DISABLE_QUEUE+=($(disable_expand_group "$DISABLE_NAME"))

        case " ${PACKAGE_BUILD_ORDER[*]} " in
        *" $DISABLE_NAME "*) ;;
        *)
            if [ "$(disable_expand_group "$DISABLE_NAME")" = "$DISABLE_NAME" ]; then
                echo "Error: --disable=$DISABLE_NAME is not a package. Run --list-packages for the names."
                exit 1
            fi
            ;;
        esac

        case "$DISABLE_PROTECTED" in
        *" $DISABLE_NAME "*)
            echo "Error: $DISABLE_NAME cannot be disabled - the build itself needs it."
            if [ "$DISABLE_NAME" = "openssl" ] || [ "$DISABLE_NAME" = "gnutls" ]; then
                echo "Use --tls to choose the other backend instead."
            fi
            exit 1
            ;;
        esac
    done

    while [ ${#DISABLE_QUEUE[@]} -gt 0 ]; do
        DISABLE_NAME="${DISABLE_QUEUE[0]}"
        DISABLE_QUEUE=("${DISABLE_QUEUE[@]:1}")

        case "$DISABLED_PACKAGES" in
        *" $DISABLE_NAME "*) continue ;;
        esac
        DISABLED_PACKAGES+="$DISABLE_NAME "

        for DISABLE_DEPENDENT in $(disable_dependents_of "$DISABLE_NAME"); do
            # Already disabled, or already queued by another package that needs
            # it - libtheora is reachable from both libogg and libvorbis, and
            # saying so twice reads like two different problems.
            case "$DISABLED_PACKAGES" in
            *" $DISABLE_DEPENDENT "*) continue ;;
            esac
            case " ${DISABLE_QUEUE[*]} " in
            *" $DISABLE_DEPENDENT "*) continue ;;
            esac
            echo "Note: $DISABLE_DEPENDENT is disabled too - it does not build without $DISABLE_NAME."
            DISABLE_QUEUE+=("$DISABLE_DEPENDENT")
        done
    done

    echo "Disabled:$DISABLED_PACKAGES"
fi

for PACKAGE in "${PACKAGE_BUILD_ORDER[@]}"; do
    case "$DISABLED_PACKAGES" in
    *" $PACKAGE "*) continue ;;
    esac
    "build_${PACKAGE}"
done
