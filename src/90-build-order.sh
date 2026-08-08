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

        printf '  %-22s %-28s %s\n' "$PACKAGE" "$LIST_VERSION" "$LIST_STATE"
    done
    echo ""
    echo "${#PACKAGE_BUILD_ORDER[@]} packages, then ffmpeg $FFMPEG_VERSION."
    exit 0
fi

for PACKAGE in "${PACKAGE_BUILD_ORDER[@]}"; do
    "build_${PACKAGE}"
done
