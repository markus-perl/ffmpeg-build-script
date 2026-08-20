# shellcheck shell=bash
##
## TLS/crypto stack
##
## ffmpeg's configure refuses to enable GnuTLS and OpenSSL at the same time
## ("GnuTLS and OpenSSL must not be enabled at the same time", configure line
## 4851), so exactly one crypto stack is built. That is why the next five
## functions come in two mirror-image groups, each gated on $TLS_BACKEND:
##
##   --tls=openssl  ->  gettext, openssl
##   --tls=gnutls   ->  gmp, nettle, gnutls
##
## $TLS_BACKEND defaults to openssl under --enable-gpl-and-non-free and to
## gnutls otherwise, which is the split this file used to hardcode. It is now a
## user choice (#178), because the licence argument for it was never absolute:
## OpenSSL has been Apache-2.0 since 3.0 and ffmpeg 9.0 does not list it in
## EXTERNAL_LIBRARY_NONFREE_LIST. What keeps OpenSSL the default on the
## non-free path is dependencies rather than licensing - libssh has no GnuTLS
## backend and libsrt has only ever been built against OpenSSL here.
##
## Neither backend is autodetected by ffmpeg: gnutls and openssl are both in
## EXTERNAL_LIBRARY_LIST, not EXTERNAL_AUTODETECT_LIBRARY_LIST, so a build that
## passes neither flag has no TLS at all and cannot open an https:// URL. That
## was the state of every LGPL Linux build until this file started passing
## --enable-gnutls; macOS was unaffected only because securetransport *is*
## autodetected.

# gettext is only needed on the non-free path, and not for OpenSSL itself: zvbi
# is the one package built from a plain GitHub archive with no pre-generated
# configure, so it runs ./autogen.sh, and its configure.ac calls
# AM_GNU_GETTEXT([external]) -- which requires autopoint from gettext. zvbi is
# non-free-gated, so gettext inherits the same gate. (Both were added together
# in 9c89658.)
build_gettext() {
    if ! $NONFREE_AND_GPL; then return; fi

    if build "gettext" "${VER_GETTEXT[0]}"; then
        download "https://ftp.gnu.org/gnu/gettext/gettext-$CURRENT_PACKAGE_VERSION.tar.gz"
        execute ./configure --prefix="${WORKSPACE}" --enable-static --disable-shared
        execute make -j "$MJOBS"
        execute make install
        build_done "gettext" "$CURRENT_PACKAGE_VERSION"
    fi
}

build_openssl() {
    if [ "$TLS_BACKEND" != "openssl" ]; then return; fi

    if build "openssl" "${VER_OPENSSL[0]}"; then
        download "https://github.com/openssl/openssl/archive/refs/tags/openssl-$CURRENT_PACKAGE_VERSION.tar.gz" "openssl-$CURRENT_PACKAGE_VERSION.tar.gz"
        execute ./Configure --prefix="${WORKSPACE}" --openssldir="${WORKSPACE}" --libdir="lib" --with-zlib-include="${WORKSPACE}"/include/ --with-zlib-lib="${WORKSPACE}"/lib no-shared zlib
        execute make -j "$MJOBS"
        execute make install_sw
        build_done "openssl" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-openssl")
}

# gmp and nettle exist only as GnuTLS dependencies, so they carry the inverse
# gate of build_openssl above: skipped whenever OpenSSL is the chosen backend.
build_gmp() {
    if [ "$TLS_BACKEND" != "gnutls" ]; then return; fi

    if build "gmp" "${VER_GMP[0]}" "$MACOS_INTEL_BUILD_VARIANT"; then
        download "https://ftp.gnu.org/gnu/gmp/gmp-$CURRENT_PACKAGE_VERSION.tar.xz"
        # GMP's compiler probe calls "void g(){}" with six arguments. C23 made an empty
        # parameter list mean (void), so GCC 15 rejects the call and configure concludes
        # there is no working compiler at all. See pre_c23_cflag. The standard goes on CC
        # rather than CFLAGS because GMP picks its own optimisation and ABI flags, and
        # setting CFLAGS discards that tuning.
        GMP_STD_FLAG="$(pre_c23_cflag)"
        GMP_CONFIGURE_OPTIONS=(--prefix="${WORKSPACE}" --disable-shared --enable-static)
        if $MACOS_INTEL; then
            # GMP's asm build is unreliable on the Intel macOS toolchain. Generic C
            # costs RSA/DH handshake speed but links. Never add --enable-fat next to
            # it: gmp's configure hard-errors on that combination.
            GMP_CONFIGURE_OPTIONS+=(--disable-assembly)
        fi
        if [ -n "$GMP_STD_FLAG" ]; then
            execute ./configure "${GMP_CONFIGURE_OPTIONS[@]}" CC="${CC:-gcc}$GMP_STD_FLAG"
        else
            execute ./configure "${GMP_CONFIGURE_OPTIONS[@]}"
        fi
        execute make -j "$MJOBS"
        execute make install
        build_done "gmp" "$CURRENT_PACKAGE_VERSION" "$MACOS_INTEL_BUILD_VARIANT"
    fi
}

build_nettle() {
    if [ "$TLS_BACKEND" != "gnutls" ]; then return; fi

    if build "nettle" "${VER_NETTLE[0]}"; then
        download "https://ftp.gnu.org/gnu/nettle/nettle-$CURRENT_PACKAGE_VERSION.tar.gz"
        execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static --disable-openssl --disable-documentation --libdir="${WORKSPACE}"/lib CPPFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}"
        execute make -j "$MJOBS"
        execute make install
        build_done "nettle" "$CURRENT_PACKAGE_VERSION"
    fi
}

# Both of this function's long-standing oddities date from Nov 2022 and neither
# was explained in the commits that introduced them (aea1ed7 "update", 3f61d36
# "ubuntu update"). They are gone now; the history is worth keeping because both
# were load-bearing.
#
#   1. The arm64 skip, `if [[ $ARCH == 'arm64' ]]; then return; fi`. GnuTLS was
#      added without it (d7f9078) and the guard appeared later as
#      `if ! $MACOS_M1`, i.e. GnuTLS 3.6.16 would not build on Apple Silicon.
#      3f61d36 rewrote the test in terms of $ARCH, which despite how it reads
#      never widened it beyond macOS: ARCH is assigned in exactly one place,
#      inside the "uname -m == arm64 AND darwin" branch, so Linux/aarch64
#      reports "aarch64", leaves ARCH empty and always did build GnuTLS.
#      Removed because the pinned version is 3.8.x, not 3.6.16, and it builds:
#      verified by configuring, compiling and installing 3.8.13 on macOS 15
#      arm64 with these exact options, after which `pkg-config --static --libs
#      gnutls` resolves to -lgnutls -lgmp -lhogweed -lnettle plus the Security
#      and CoreFoundation frameworks.
#   2. The commented-out CONFIGURE_OPTIONS at the end. Because of it, an LGPL
#      build compiled the whole gmp/nettle/gnutls chain and then never passed
#      --enable-gnutls, so it shipped with no TLS backend at all - see the note
#      at the top of this file about neither backend being autodetected. The
#      arm64 skip is presumably why: re-enabling the flag while it was in place
#      would have turned it into a hard feature difference between
#      architectures. With the skip gone the flag can go back.
build_gnutls() {
    if [ "$TLS_BACKEND" != "gnutls" ]; then return; fi

    if build "gnutls" "${VER_GNUTLS[0]}" "$MACOS_INTEL_BUILD_VARIANT"; then
        # Upstream files the tarballs under a major.minor series directory, so that
        # part of the path is derived from the pinned version rather than repeated.
        download "https://www.gnupg.org/ftp/gcrypt/gnutls/v${CURRENT_PACKAGE_VERSION%.*}/gnutls-$CURRENT_PACKAGE_VERSION.tar.xz"
        GNUTLS_CONFIGURE_OPTIONS=(--prefix="${WORKSPACE}" --disable-shared --enable-static --disable-doc --disable-tools --disable-cxx --disable-tests --disable-gtk-doc-html --disable-libdane --disable-nls --enable-local-libopts --disable-guile --with-included-libtasn1 --with-included-unistring --without-p11-kit)
        if $MACOS_INTEL; then
            # libidn2 and zstd are Homebrew dylibs on Intel macOS and would leak host
            # libraries into this static build. Cost: no IDNA hostnames, no certificate
            # compression. Verify the names against gnutls' configure when touching
            # them - autoconf only warns on an unknown --without-*, so a typo passes.
            GNUTLS_CONFIGURE_OPTIONS+=(--without-idn --without-zstd)
        fi
        execute ./configure "${GNUTLS_CONFIGURE_OPTIONS[@]}" CPPFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}"
        execute make -j "$MJOBS"
        execute make install
        build_done "gnutls" "$CURRENT_PACKAGE_VERSION" "$MACOS_INTEL_BUILD_VARIANT"
    fi
    # --enable-gmp is deliberately not passed alongside. It is a separate ffmpeg
    # feature (bignum arithmetic for the ffrtmpcrypt protocol, configure line
    # 4074) rather than part of the TLS stack, it is in
    # EXTERNAL_LIBRARY_VERSION3_LIST so it would force --enable-version3, and
    # GnuTLS links libgmp either way through its own .pc.
    CONFIGURE_OPTIONS+=("--enable-gnutls")
}
