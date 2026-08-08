# shellcheck shell=bash
##
## text shaping and subtitle library
##

VER_LIBXML2=("2.15.3" "78262a6e7ac170d6528ebfe2efccdf220191a5af6a6cd61ea4a9a9a5042c7a07")
build_libxml2() {
    # libxml2 is required by ffmpeg for the DASH and IMF demuxers, and is used here as
    # fontconfig's XML parser so that expat is not needed as well.
    if build "libxml2" "${VER_LIBXML2[0]}"; then
        # As with gnutls, the series directory is derived from the pinned version.
        download "https://download.gnome.org/sources/libxml2/${CURRENT_PACKAGE_VERSION%.*}/libxml2-$CURRENT_PACKAGE_VERSION.tar.xz"
        execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static --without-python --without-debug --without-docs
        execute make -j "$MJOBS"
        execute make install
        build_done "libxml2" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libxml2")
}

VER_FRIBIDI=("1.0.16" "1b1cde5b235d40479e91be2f0e88a309e3214c8ab470ec8a2744d82a5a9ea05c")
build_fribidi() {
    if build "fribidi" "${VER_FRIBIDI[0]}"; then
        download "https://github.com/fribidi/fribidi/releases/download/v$CURRENT_PACKAGE_VERSION/fribidi-$CURRENT_PACKAGE_VERSION.tar.xz"
        execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static --disable-debug --disable-deprecated
        execute make -j "$MJOBS"
        execute make install
        build_done "fribidi" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libfribidi")
}

# harfbuzz dropped autotools, so it can only be built when meson and ninja are available.
# Without it libass and drawtext still work, but complex scripts are not shaped.
VER_HARFBUZZ=("14.3.0" "16070d77cfc4ba1f1e7327e83bf9b3f55898081cabdb94e56a33e04fc8874eae")
build_harfbuzz() {
    if ! command_exists "meson"; then
        echo "meson is missing, skipping harfbuzz. Complex scripts will not be shaped."
        return
    fi

    if build "harfbuzz" "${VER_HARFBUZZ[0]}"; then
        download "https://github.com/harfbuzz/harfbuzz/releases/download/$CURRENT_PACKAGE_VERSION/harfbuzz-$CURRENT_PACKAGE_VERSION.tar.xz"
        execute meson setup build --prefix="${WORKSPACE}" --buildtype=release --default-library=static --libdir="${WORKSPACE}"/lib \
            -Dfreetype=enabled -Dglib=disabled -Dgobject=disabled -Dcairo=disabled -Dchafa=disabled -Dicu=disabled \
            -Dtests=disabled -Ddocs=disabled -Dbenchmark=disabled -Dutilities=disabled -Dintrospection=disabled
        execute ninja -C build
        execute ninja -C build install
        build_done "harfbuzz" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libharfbuzz")
}

VER_GPERF=("3.3" "fd87e0aba7e43ae054837afd6cd4db03a3f2693deb3619085e6ed9d8d9604ad8")
build_gperf() {
    # fontconfig generates fcgenericfamily.h with gperf, which is not shipped in the tarball.
    # macOS has gperf in /usr/bin, but a minimal Linux install usually does not, so build it here.
    if build "gperf" "${VER_GPERF[0]}"; then
        download "https://ftp.gnu.org/gnu/gperf/gperf-$CURRENT_PACKAGE_VERSION.tar.gz"
        execute ./configure --prefix="${WORKSPACE}"
        execute make -j "$MJOBS"
        execute make install
        build_done "gperf" "$CURRENT_PACKAGE_VERSION"
    fi
}

VER_FONTCONFIG=("2.18.3" "4f7b554a38cdf78c033f666c8871f3749e14a094f65a07f630c91ed0b43d35e3")
build_fontconfig() {
    # The fontconfig configuration is installed inside the workspace, so a relocated binary
    # falls back to fontconfig's built-in font directories.
    #
    # The fc-* tools are linked statically, so pkg-config has to resolve private dependencies
    # as well: freetype2.pc requires libbrotlidec, which in turn needs libbrotlicommon.
    if build "fontconfig" "${VER_FONTCONFIG[0]}"; then
        download "https://gitlab.freedesktop.org/api/v4/projects/890/packages/generic/fontconfig/$CURRENT_PACKAGE_VERSION/fontconfig-$CURRENT_PACKAGE_VERSION.tar.xz"
        execute ./configure PKG_CONFIG="pkg-config --static" --prefix="${WORKSPACE}" --disable-shared --enable-static --enable-libxml2 --disable-docs --disable-nls --disable-cache-build
        execute make -j "$MJOBS"
        execute make install
        build_done "fontconfig" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libfontconfig")
}

VER_LIBUNIBREAK=("7.0" "8c9a6e121736cd0d5c890ae3ae96f3f4010a19aa040f1dbded833a62a87717d3")
build_libunibreak() {
    # libass uses libunibreak for Unicode line breaking. Without it libass logs a warning on every
    # render and falls back to a simpler algorithm, which breaks CJK and Thai subtitles badly.
    if build "libunibreak" "${VER_LIBUNIBREAK[0]}"; then
        download "https://github.com/adah1972/libunibreak/releases/download/libunibreak_${CURRENT_PACKAGE_VERSION//./_}/libunibreak-$CURRENT_PACKAGE_VERSION.tar.gz"
        execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static
        execute make -j "$MJOBS"
        execute make install
        build_done "libunibreak" "$CURRENT_PACKAGE_VERSION"
    fi
}

VER_LIBASS=("0.17.5" "2dca25c0e0c837ddf00b52011b3f82cac1e4ddd3ad018227806b0c2288864acc")
build_libass() {
    if build "libass" "${VER_LIBASS[0]}"; then
        download "https://github.com/libass/libass/releases/download/$CURRENT_PACKAGE_VERSION/libass-$CURRENT_PACKAGE_VERSION.tar.xz"
        execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static --enable-fontconfig --enable-libunibreak --disable-test --disable-profile --disable-fuzz
        execute make -j "$MJOBS"
        execute make install
        build_done "libass" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libass")
}

VER_VAPOURSYNTH=("78" "cbd5aa49d43a9e5061c5ea4b03a682322065f3d9b8870c36bfb8afa0f635e066")
build_vapoursynth() {
    if build "VapourSynth" "${VER_VAPOURSYNTH[0]}"; then
        # VapourSynth library is loaded dynamically by ffmpeg if a VapourSynth script is opened
        # no need to build it at compile team, only headers need to be installed
        download "https://github.com/vapoursynth/vapoursynth/archive/R$CURRENT_PACKAGE_VERSION.tar.gz"
        execute mkdir -p "${WORKSPACE}/include/vapoursynth"
        execute cp -r "include/." "${WORKSPACE}/include/vapoursynth/"
        build_done "VapourSynth" "$CURRENT_PACKAGE_VERSION"
    fi

    CONFIGURE_OPTIONS+=("--enable-vapoursynth")
}

VER_AVISYNTH=("3.7.5" "2533fafe5b5a8eb9f14d84d89541252a5efd0839ef62b8ae98f40b9f34b3f3d5")
build_avisynth() {
    if ! $NONFREE_AND_GPL; then return; fi

    # AviSynth+ is loaded dynamically by ffmpeg if an AviSynth script is opened,
    # so only the headers need to be installed. ffmpeg requires 3.7.3 or newer and
    # looks for avisynth/avisynth_c.h and avisynth/avs/version.h.
    if build "avisynth" "${VER_AVISYNTH[0]}"; then
        download "https://github.com/AviSynth/AviSynthPlus/archive/refs/tags/v$CURRENT_PACKAGE_VERSION.tar.gz" "AviSynthPlus-$CURRENT_PACKAGE_VERSION.tar.gz"
        execute cmake -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DHEADERS_ONLY=ON -B build/
        # VersionGen generates avs/version.h and avs/arch.h, which the install step
        # expects but which are not part of the default target.
        execute cmake --build build/ --target VersionGen
        execute cmake --build build/ --target install
        build_done "avisynth" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-avisynth")
}

VER_SRT=("1.5.6" "2c4980c2c4cfd142d21b829d939dc51db9c6628af5967fff62fd7290769569c7")
build_srt() {
    if ! $NONFREE_AND_GPL; then return; fi

    if build "srt" "${VER_SRT[0]}"; then
        download "https://github.com/Haivision/srt/archive/v$CURRENT_PACKAGE_VERSION.tar.gz" "srt-$CURRENT_PACKAGE_VERSION.tar.gz"
        export OPENSSL_ROOT_DIR="${WORKSPACE}"
        export OPENSSL_LIB_DIR="${WORKSPACE}"/lib
        export OPENSSL_INCLUDE_DIR="${WORKSPACE}"/include/
        execute cmake . -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_INSTALL_BINDIR=bin -DCMAKE_INSTALL_INCLUDEDIR=include -DENABLE_SHARED=OFF -DENABLE_STATIC=ON -DENABLE_APPS=OFF -DUSE_STATIC_LIBSTDCXX=ON
        execute make -j "$MJOBS"
        execute make install

        if [ -n "$LDEXEFLAGS" ]; then
            sed -i.backup 's/-lgcc_s/-lgcc_eh/g' "${WORKSPACE}"/lib/pkgconfig/srt.pc # The -i.backup is intended and required on MacOS: https://stackoverflow.com/questions/5694228/sed-in-place-flag-that-works-both-on-mac-bsd-and-linux
        fi

        build_done "srt" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libsrt")
}

VER_ZVBI=("0.2.44" "bca620ab670328ad732d161e4ce8d9d9fc832533cb7440e98c50e112b805ac5e")
build_zvbi() {
    if ! $NONFREE_AND_GPL; then return; fi

    if build "zvbi" "${VER_ZVBI[0]}"; then
        download "https://github.com/zapping-vbi/zvbi/archive/refs/tags/v$CURRENT_PACKAGE_VERSION.tar.gz" "zvbi-$CURRENT_PACKAGE_VERSION.tar.gz"
        execute ./autogen.sh --prefix="${WORKSPACE}"
        execute ./configure CFLAGS="-I${WORKSPACE}/include/libpng16 ${CFLAGS}" --prefix="${WORKSPACE}" --enable-static --disable-shared
        execute make -j "$MJOBS"
        execute make install
        build_done "zvbi" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libzvbi")
}
