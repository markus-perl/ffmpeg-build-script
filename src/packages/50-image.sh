# shellcheck shell=bash
##
## image library
##

VER_LIBPNG=("1.6.58" "8c9b05b675ca7301a458df2c2e46f26e1d41ff36b8863f8c33530bc58c2e6225")
build_libpng() {
    if build "libpng" "${VER_LIBPNG[0]}"; then
        download "https://sourceforge.net/projects/libpng/files/libpng16/$CURRENT_PACKAGE_VERSION/libpng-$CURRENT_PACKAGE_VERSION.tar.gz" "libpng-$CURRENT_PACKAGE_VERSION.tar.gz"
        export LDFLAGS="${LDFLAGS}"
        # shellcheck disable=SC2153 # CFLAGS, not a typo for CPPFLAGS; it is set in 20-globals.sh
        export CPPFLAGS="${CFLAGS}"
        execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static
        execute make -j "$MJOBS"
        execute make install
        build_done "libpng" "$CURRENT_PACKAGE_VERSION"
    fi
}

VER_LCMS2=("2.19.1" "bfc54f7bab59fbc921012014a8032e4cba4abd46db47d46b76416a8c0b2815c8")
build_lcms2() {
    if build "lcms2" "${VER_LCMS2[0]}"; then
        download "https://github.com/mm2/Little-CMS/releases/download/lcms$CURRENT_PACKAGE_VERSION/lcms2-$CURRENT_PACKAGE_VERSION.tar.gz"
        execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static
        execute make -j "$MJOBS"
        execute make install
        build_done "lcms2" "$CURRENT_PACKAGE_VERSION"
    fi
    # lcms2 is a libjxl dependency, but ffmpeg also uses it for ICC profile support
    # in the image decoders and for the iccdetect and iccgen filters.
    CONFIGURE_OPTIONS+=("--enable-lcms2")
}

VER_LIBJXL=("0.12.0" "03e9be69a30be4011f559da75328b6d7cea8ad921fabfbd551ce10bf45cdc992")
build_libjxl() {
    if build "libjxl" "${VER_LIBJXL[0]}"; then
        download "https://github.com/libjxl/libjxl/archive/refs/tags/v$CURRENT_PACKAGE_VERSION.tar.gz" "libjxl-$CURRENT_PACKAGE_VERSION.tar.gz"
        # currently needed to fix linking of static builds in non-C++ applications
        apply_inline_patch lib/threads/libjxl_threads.pc.in "s/-ljxl_threads/-ljxl_threads @JPEGXL_THREADS_PUBLIC_LIBS@/g"
        # shellcheck disable=SC1003,SC2016 # the $'\n' splice and ${PKGCONFIG_CXX_LIB} are for sed/cmake, not the shell
        apply_inline_patch lib/jxl_threads.cmake 's/set(JPEGXL_REQUIRES_TYPE "Requires")/set(JPEGXL_REQUIRES_TYPE "Requires")\'$'\n''  set(JPEGXL_THREADS_PUBLIC_LIBS "-lm ${PKGCONFIG_CXX_LIB}")/g'
        execute ./deps.sh
        execute cmake -DBUILD_SHARED_LIBS=OFF -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_INSTALL_BINDIR=bin -DCMAKE_INSTALL_INCLUDEDIR=include -DENABLE_SHARED=off -DENABLE_STATIC=ON -DCMAKE_BUILD_TYPE=Release -DJPEGXL_ENABLE_BENCHMARK=OFF -DJPEGXL_ENABLE_DOXYGEN=OFF -DJPEGXL_ENABLE_MANPAGES=OFF -DJPEGXL_ENABLE_JPEGLI_LIBJPEG=OFF -DJPEGXL_ENABLE_JPEGLI=ON -DJPEGXL_TEST_TOOLS=OFF -DJPEGXL_ENABLE_JNI=OFF -DBUILD_TESTING=OFF -DJPEGXL_ENABLE_SKCMS=OFF .
        execute make -j "$MJOBS"
        execute make install
        build_done "libjxl" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libjxl")
    EXTRALIBS="${EXTRALIBS} -llcms2"
}

VER_LIBWEBP=("1.6.0" "e4ab7009bf0629fd11982d4c2aa83964cf244cffba7347ecd39019a9e38c4564")
build_libwebp() {
    if build "libwebp" "${VER_LIBWEBP[0]}"; then
        # libwebp can fail to compile on Ubuntu if these flags were left set to CFLAGS
        CPPFLAGS=
        download "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-$CURRENT_PACKAGE_VERSION.tar.gz" "libwebp-$CURRENT_PACKAGE_VERSION.tar.gz"
        make_dir build
        cd build || exit
        execute cmake -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_INSTALL_BINDIR=bin -DCMAKE_INSTALL_INCLUDEDIR=include -DENABLE_SHARED=OFF -DENABLE_STATIC=ON -DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF -DWEBP_BUILD_GIF2WEBP=OFF -DWEBP_BUILD_IMG2WEBP=OFF -DWEBP_BUILD_VWEBP=OFF ../
        execute make -j "$MJOBS"
        execute make install

        build_done "libwebp" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libwebp")
}

# Last in the image section: openjpeg is another still-image codec, and it is placed after
# libpng and lcms2 because its BUILD_CODEC executables would link both. Those are turned off
# here, so the position is only about keeping the section readable.
#
# Deliberately not behind $NONFREE_AND_GPL: ffmpeg 9.0 lists libopenjpeg in the plain
# EXTERNAL_LIBRARY_LIST (configure line 2110) and in none of the GPL/nonfree/version3 lists -
# openjpeg is BSD-2-Clause. It is the only JPEG 2000 *encoder* available: ffmpeg has a native j2k
# decoder but its native encoder is far weaker, so gating this would cost real functionality.
VER_OPENJPEG=("2.5.4" "a695fbe19c0165f295a8531b1e4e855cd94d0875d2f88ec4b61080677e27188a")
build_openjpeg() {
    if build "openjpeg" "${VER_OPENJPEG[0]}"; then
        download "https://github.com/uclouvain/openjpeg/archive/refs/tags/v$CURRENT_PACKAGE_VERSION.tar.gz" "openjpeg-$CURRENT_PACKAGE_VERSION.tar.gz"
        make_dir build
        cd build || exit

        # BUILD_CODEC builds opj_compress/opj_decompress and their png/tiff/lcms2 dependencies;
        # nothing here needs the command line tools. BUILD_SHARED_LIBS=OFF plus BUILD_STATIC_LIBS=ON
        # leaves just libopenjp2.a, and also decides which target the generated libopenjp2.pc
        # describes.
        execute cmake -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_INSTALL_BINDIR=bin -DCMAKE_INSTALL_INCLUDEDIR=include -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIBS=ON -DBUILD_CODEC=OFF -DBUILD_DOC=OFF -DBUILD_TESTING=OFF ../
        execute make -j "$MJOBS"
        execute make install

        build_done "openjpeg" "$CURRENT_PACKAGE_VERSION"
    fi

    # The pkg-config module is "libopenjp2", not "libopenjpeg" - that is the name ffmpeg's configure
    # asks for (line 7411), and the .pc file installed above matches it. No fixup is needed for the
    # header either: openjpeg installs it into include/openjpeg-2.5/, but libopenjp2.pc sets
    # "Cflags: -I${includedir}" with includedir already pointing at that versioned directory, so
    # ffmpeg's plain "#include <openjpeg.h>" resolves. The generated Libs is "-L${libdir} -lopenjp2"
    # with "Libs.private: -lm" - no absolute archive paths, and openjpeg is pure C, so no C++
    # runtime has to be spliced in the way libvmaf and libplacebo need.
    CONFIGURE_OPTIONS+=("--enable-libopenjpeg")
}
