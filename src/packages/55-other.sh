# shellcheck shell=bash
##
## other library
##

build_libsdl() {
    # Keep this on SDL 2.x. ffplay is the only thing that links SDL, and ffmpeg 9.0 accepts
    # SDL2 only: ffplay_deps lists sdl2, and configure tests for "sdl2 >= 2.0.1 sdl2 < 3.0.0",
    # so an SDL3 build is ignored and no sdl2.pc is produced. ffplay is then silently skipped,
    # because configure just drops it from the program list instead of failing. The build still
    # reports success, but the docker images fail later when they copy the missing binary, and
    # a build host that happens to have its own SDL2 installed hides the problem entirely.
    if build "libsdl" "${VER_LIBSDL[0]}" "$MACOS_INTEL_BUILD_VARIANT"; then
        download "https://github.com/libsdl-org/SDL/releases/download/release-$CURRENT_PACKAGE_VERSION/SDL2-$CURRENT_PACKAGE_VERSION.tar.gz"
        SDL_CONFIGURE_OPTIONS=(--prefix="${WORKSPACE}" --disable-shared --enable-static)
        if $MACOS_INTEL; then
            SDL_CONFIGURE_OPTIONS+=(--disable-video-x11)
        fi
        execute ./configure "${SDL_CONFIGURE_OPTIONS[@]}"
        execute make -j "$MJOBS"
        execute make install

        build_done "libsdl" "$CURRENT_PACKAGE_VERSION" "$MACOS_INTEL_BUILD_VARIANT"
    fi
}

# Snappy is what the HAP encoder is built on: configure.3221 has hap_encoder_deps="libsnappy",
# so without this there is no hap/hap_alpha/hap_q encoder at all (decoding is unaffected).
# Not licence-gated: ffmpeg 9.0 lists libsnappy in the plain EXTERNAL_LIBRARY_LIST, not in
# EXTERNAL_LIBRARY_GPL_LIST, and snappy itself is BSD-3-Clause.
build_libsnappy() {
    if build "libsnappy" "${VER_LIBSNAPPY[0]}"; then
        # The tag archive is named after the bare tag ("1.2.2.tar.gz"), so the filename has to
        # be given explicitly or download() would derive a directory called "1.2".
        download "https://github.com/google/snappy/archive/refs/tags/$CURRENT_PACKAGE_VERSION.tar.gz" "snappy-$CURRENT_PACKAGE_VERSION.tar.gz"

        # SNAPPY_BUILD_TESTS and SNAPPY_BUILD_BENCHMARKS both default to ON and both pull in
        # third_party/googletest and third_party/benchmark, which are git submodules: the
        # release tarball contains only the empty third_party directories, so leaving either
        # on turns into a cmake configure error. SNAPPY_INSTALL defaults to ON and is spelled
        # out because it is the one option that must not drift - it is what installs
        # libsnappy.a and snappy-c.h, the two things ffmpeg's check needs.
        # BUILD_SHARED_LIBS already defaults to OFF here (snappy redeclares it), set anyway
        # so the static-only requirement does not depend on an upstream default.
        execute cmake -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DCMAKE_INSTALL_LIBDIR=lib \
            -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
            -DSNAPPY_BUILD_TESTS=OFF -DSNAPPY_BUILD_BENCHMARKS=OFF \
            -DSNAPPY_FUZZING_BUILD=OFF -DSNAPPY_INSTALL=ON \
            -B build/
        execute cmake --build build --target install -j "$MJOBS"

        # No .pc to patch, deliberately: snappy's install() rules cover the archive, four
        # headers and a cmake package config, and nothing else. That is fine here because
        # ffmpeg's check is `require libsnappy snappy-c.h snappy_compress -lsnappy -lstdc++`
        # (check_lib, not require_pkg_config), which supplies the C++ runtime itself - so the
        # .pc-Libs fixup used by build_libvpl and build_libplacebo has nothing to attach to
        # and is not needed. ffmpeg's hardcoded -lstdc++ is also correct on macOS: Apple's
        # toolchain resolves -lstdc++ onto libc++, verified by linking a C++ archive from a C
        # main with -lstdc++ (the result records /usr/lib/libc++.1.dylib).
        build_done "libsnappy" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libsnappy")
}

# libssh provides the sftp:// protocol. Not licence-gated: ffmpeg 9.0 lists libssh in the
# plain EXTERNAL_LIBRARY_LIST, not in EXTERNAL_LIBRARY_GPL_LIST, and libssh itself is
# LGPL-2.1. The $NONFREE_AND_GPL-shaped guard below is a *dependency* guard, not a licence
# one - see the comment on it.
#
# ffmpeg's check is pkg-config-only with no fallback:
#   require_pkg_config libssh "libssh >= 0.6.0" libssh/sftp.h sftp_init
# so a working libssh.pc is as much a deliverable here as libssh.a is.
build_libssh() {
    # libssh needs a crypto backend and the only one this script can offer is the OpenSSL it
    # builds into the workspace - and build_openssl returns early unless the build is
    # --enable-gpl-and-non-free. Test for the artefact rather than for $NONFREE_AND_GPL so
    # this keeps working if openssl is ever ungated, and test the file rather than
    # library_exists "libcrypto": PKG_CONFIG_PATH also contains the system directories, so a
    # distro libcrypto.pc would be a false positive and cmake would then link libssh against
    # a shared system OpenSSL, which a static build cannot use.
    if [ ! -f "${WORKSPACE}/lib/libcrypto.a" ]; then
        echo "Skipping libssh: no static OpenSSL in the workspace, and libssh needs a crypto backend."
        return
    fi

    if build "libssh" "${VER_LIBSSH[0]}"; then
        # Upstream files the tarballs under a major.minor series directory, so that part of
        # the path is derived from the pinned version - same idiom as build_gnutls.
        download "https://www.libssh.org/files/${CURRENT_PACKAGE_VERSION%.*}/libssh-$CURRENT_PACKAGE_VERSION.tar.xz"

        # BUILD_SHARED_LIBS=OFF is the *only* correct way to get a static libssh here, and
        # the option that looks right is a trap. libssh's src/CMakeLists.txt defines a second
        # target "ssh-static" behind BUILD_STATIC_LIB, but that block (0.12.2, lines 447-490)
        # carries no install() rule at all - the archive is left in the build tree. The single
        # install(TARGETS ssh ... ARCHIVE DESTINATION ...) belongs to the "ssh" target, which
        # is what BUILD_SHARED_LIBS=OFF turns into a static library. BUILD_STATIC_LIB is also
        # force-enabled by any of the *_TESTING options, so it exists purely to give the test
        # suite something to link against.
        #
        # OPENSSL_ROOT_DIR + OPENSSL_USE_STATIC_LIBS pin FindOpenSSL to the workspace build
        # (find_package(OpenSSL 1.1.1 REQUIRED) in CMakeLists.txt would otherwise happily take
        # a system libssl.so). WITH_GCRYPT/WITH_MBEDTLS are OFF by default, but are spelled out
        # because they are what selects the backend: libssh's CMakeLists.txt only falls through
        # to find_package(OpenSSL) when both are off.
        #
        # Everything else is dead weight for an sftp:// client and is switched off explicitly
        # because all of these default to ON: SERVER (the SSH server half), ZLIB (compression
        # is negotiated off by default and libssh does not put -lz into its .pc, so keeping it
        # would only add an undeclared link dependency), GSSAPI (would opportunistically link
        # the host's krb5), PCAP (packet-capture debug output), NACL (a second curve25519
        # implementation), EXAMPLES, and SYMBOL_VERSIONING (a --version-script linker flag that
        # means nothing for an archive). SFTP is what ffmpeg uses and stays on.
        execute cmake -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DCMAKE_INSTALL_LIBDIR=lib \
            -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
            -DOPENSSL_ROOT_DIR="${WORKSPACE}" -DOPENSSL_USE_STATIC_LIBS=TRUE \
            -DWITH_GCRYPT=OFF -DWITH_MBEDTLS=OFF \
            -DWITH_SFTP=ON -DWITH_SERVER=OFF -DWITH_ZLIB=OFF -DWITH_GSSAPI=OFF \
            -DWITH_PCAP=OFF -DWITH_NACL=OFF -DWITH_EXAMPLES=OFF -DWITH_SYMBOL_VERSIONING=OFF \
            -DUNIT_TESTING=OFF -DCLIENT_TESTING=OFF -DSERVER_TESTING=OFF \
            -B build/
        execute cmake --build build --target install -j "$MJOBS"

        # libssh.pc.cmake hardcodes "Libs: -L${libdir} -lssh" and only ever fills
        # Requires.private from GSSAPI, so the crypto backend is never declared. That is
        # invisible for a shared libssh (libssh.so records its own NEEDED entries) and fatal
        # for this one: ffmpeg runs pkg-config with --static and link-tests sftp_init, which
        # dies on a wall of undefined BN_new/BN_bin2bn/EVP_* from libcrypto. Requires.private
        # rather than a literal -lcrypto so that OpenSSL's own private libs (-ldl -pthread)
        # come along too - libcrypto.pc is in the same workspace, installed by build_openssl.
        apply_inline_patch "${WORKSPACE}/lib/pkgconfig/libssh.pc" "s|^Requires.private:.*|Requires.private: libcrypto|"

        build_done "libssh" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libssh")
}

# --with-harfbuzz=no is not optional. FreeType and harfbuzz depend on each other, and this
# script builds FreeType first, so harfbuzz is not in the workspace yet when configure runs.
# Left to autodetect, FreeType picks up a *system* harfbuzz instead: libfreetype.a then carries
# hb_shape references from its autofit module and freetype2.pc gains Requires.private: harfbuzz,
# which forms a pkg-config cycle with the workspace harfbuzz.pc built later (that one requires
# freetype2). ffmpeg's --enable-libharfbuzz link test flattens the cycle into an order where
# libfreetype.a lands after libharfbuzz.a, hb_shape stays unresolved, and configure reports the
# misleading "ERROR: harfbuzz not found using pkg-config" (issue #266).
#
# The only thing given up is harfbuzz-assisted auto-hinting inside FreeType. Text shaping for
# libass and drawtext comes from libharfbuzz itself and is unaffected.
build_freetype2() {
    if build "FreeType2" "${VER_FREETYPE2[0]}"; then
        download "https://downloads.sourceforge.net/freetype/freetype-$CURRENT_PACKAGE_VERSION.tar.xz"
        execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static --with-harfbuzz=no
        execute make -j "$MJOBS"
        execute make install
        build_done "FreeType2" "$CURRENT_PACKAGE_VERSION"
    fi

    CONFIGURE_OPTIONS+=("--enable-libfreetype")
}
