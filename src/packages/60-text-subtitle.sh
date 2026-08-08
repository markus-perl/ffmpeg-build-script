# shellcheck shell=bash
##
## text shaping and subtitle library
##

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
build_harfbuzz() {
    if ! command_exists "meson"; then return; fi

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
