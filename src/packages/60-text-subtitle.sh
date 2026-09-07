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

# harfbuzz dropped autotools, but it still ships a CMakeLists.txt next to its meson build, and
# cmake is built into the workspace unconditionally. That matters because harfbuzz is not
# optional: libass 0.17.5 requires it through PKG_CHECK_MODULES with no way to opt out
# (configure.ac:107), so skipping harfbuzz when meson was missing killed the whole build in
# libass configure instead of just losing complex-script shaping - see issue #268, a plain
# macOS box without Homebrew.
build_harfbuzz() {
    if build "harfbuzz" "${VER_HARFBUZZ[0]}"; then
        download "https://github.com/harfbuzz/harfbuzz/releases/download/$CURRENT_PACKAGE_VERSION/harfbuzz-$CURRENT_PACKAGE_VERSION.tar.xz"

        # download() extracts over the existing package directory, so a build/ tree left by an
        # earlier meson setup would still be there and cmake refuses to reuse it.
        execute rm -rf build

        # CoreText is off on purpose: cmake defaults HB_HAVE_CORETEXT to ON on Apple, which the
        # meson build never enabled. Nothing here shapes through it, and it only adds a
        # -framework ApplicationServices to harfbuzz.pc.
        execute cmake -DCMAKE_PREFIX_PATH="${WORKSPACE}" -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DCMAKE_INSTALL_LIBDIR=lib \
            -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DHB_HAVE_FREETYPE=ON -DHB_HAVE_CORETEXT=OFF \
            -DHB_HAVE_GLIB=OFF -DHB_HAVE_GOBJECT=OFF -DHB_HAVE_ICU=OFF -DHB_HAVE_INTROSPECTION=OFF \
            -DHB_BUILD_UTILS=OFF -B build/
        execute cmake --build build --target install -j "$MJOBS"
        build_done "harfbuzz" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libharfbuzz")
}

build_gperf() {
    # fontconfig generates fcgenericfamily.h with gperf, which is not shipped in the tarball.
    # macOS has gperf in /usr/bin, but a minimal Linux install usually does not, so build it here.
    if build "gperf" "${VER_GPERF[0]}"; then
        DOWNLOAD_SOURCES=(
            "https://ftp.gnu.org/gnu/gperf/gperf-$CURRENT_PACKAGE_VERSION.tar.gz"
            "https://ftpmirror.gnu.org/gnu/gperf/gperf-$CURRENT_PACKAGE_VERSION.tar.gz"
        )
        download "${DOWNLOAD_SOURCES[@]}"
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

# SRT's AES encryption needs a crypto library. Upstream's USE_ENCLIB defaults to
# "openssl-evp" and this builds against the workspace OpenSSL, so libsrt goes away under
# --tls=gnutls - a dependency guard of the same shape as build_libssh's, not a licence one.
#
# USE_ENCLIB=gnutls is a first-class upstream option and does configure cleanly against the
# workspace (it resolves "gnutls nettle" through pkg-config, CMakeLists.txt:372), but it does
# not compile: haicrypt/cryspr-gnutls.h typedefs CRYSPR_AESCTX to nettle's "struct aes_ctx",
# the legacy AES context that nettle 4.0 removed, so cryspr.c dies on an incomplete type.
# Verified against srt 1.5.6 and nettle 4.0, the two versions pinned here. Building OpenSSL
# anyway just for SRT would defeat the point of asking for GnuTLS, so SRT is skipped instead.
build_srt() {
    if ! $NONFREE_AND_GPL; then return; fi
    if [ "$TLS_BACKEND" != "openssl" ]; then
        echo "Skipping libsrt: its encryption layer needs OpenSSL, and --tls=$TLS_BACKEND was requested."
        return
    fi

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
