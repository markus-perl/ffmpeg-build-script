# shellcheck shell=bash
##
## TLS/crypto stack
##
## ffmpeg's configure refuses to enable GnuTLS and OpenSSL at the same time
## ("GnuTLS and OpenSSL must not be enabled at the same time"), so exactly one
## crypto stack is built per license mode. That is why the next five functions
## come in two mirror-image groups, each gated on $NONFREE_AND_GPL:
##
##   --enable-gpl-and-non-free  ->  gettext, openssl
##   default (LGPL)             ->  gmp, nettle, gnutls
##
## OpenSSL is on the non-free side because its license has long been treated as
## GPL-incompatible, so a GPL ffmpeg linked against it is not redistributable --
## a build that already accepts --enable-gpl-and-non-free has given that up
## anyway. libsrt, also non-free-gated here, needs OpenSSL as its crypto
## backend. GnuTLS is LGPL and is therefore the default path, though see the
## caveat in build_gnutls: it is currently built but never enabled.

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
    if ! $NONFREE_AND_GPL; then return; fi

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
    if $NONFREE_AND_GPL; then return; fi

    if build "gmp" "${VER_GMP[0]}"; then
        download "https://ftp.gnu.org/gnu/gmp/gmp-$CURRENT_PACKAGE_VERSION.tar.xz"
        # GMP's compiler probe calls "void g(){}" with six arguments. C23 made an empty
        # parameter list mean (void), so GCC 15 rejects the call and configure concludes
        # there is no working compiler at all. See pre_c23_cflag. The standard goes on CC
        # rather than CFLAGS because GMP picks its own optimisation and ABI flags, and
        # setting CFLAGS discards that tuning.
        GMP_STD_FLAG="$(pre_c23_cflag)"
        if [ -n "$GMP_STD_FLAG" ]; then
            execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static CC="${CC:-gcc}$GMP_STD_FLAG"
        else
            execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static
        fi
        execute make -j "$MJOBS"
        execute make install
        build_done "gmp" "$CURRENT_PACKAGE_VERSION"
    fi
}

build_nettle() {
    if $NONFREE_AND_GPL; then return; fi

    if build "nettle" "${VER_NETTLE[0]}"; then
        download "https://ftp.gnu.org/gnu/nettle/nettle-$CURRENT_PACKAGE_VERSION.tar.gz"
        execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static --disable-openssl --disable-documentation --libdir="${WORKSPACE}"/lib CPPFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}"
        execute make -j "$MJOBS"
        execute make install
        build_done "nettle" "$CURRENT_PACKAGE_VERSION"
    fi
}

# Two oddities here, both dating from Nov 2022 and neither explained in the
# commits that introduced them (aea1ed7 "update", 3f61d36 "ubuntu update"):
#
#   1. The arm64 skip. GnuTLS was added without it (d7f9078) and the guard
#      appeared later as `if ! $MACOS_M1`, i.e. GnuTLS 3.6.16 would not build on
#      Apple Silicon. 3f61d36 rewrote the test in terms of $ARCH. Despite how it
#      reads, that did not widen the skip to every arm64 host: ARCH is assigned
#      in exactly one place, inside the "uname -m == arm64 AND darwin" branch
#      near the top, so on Linux it is never set at all. Linux/aarch64 reports
#      "aarch64" from uname -m, leaves ARCH empty, and does build GnuTLS -
#      confirmed in an aarch64 Docker build. So this is still the Apple-Silicon-
#      only skip it always was, just expressed less obviously.
#      Worth revisiting: the pinned version is now 3.8.x, not 3.6.16.
#   2. The commented-out CONFIGURE_OPTIONS below. Because of it, an LGPL build
#      compiles the whole gmp/nettle/gnutls chain and then does not pass
#      --enable-gnutls to ffmpeg, so the default build ends up with no TLS
#      backend at all (no https support) unless ffmpeg's configure autodetects
#      a system one. Re-enabling the flag means the arm64 skip above turns into
#      a hard difference in features between architectures, which is presumably
#      why it was commented out rather than fixed.
build_gnutls() {
    if $NONFREE_AND_GPL; then return; fi
    if [[ $ARCH == 'arm64' ]]; then return; fi

    if build "gnutls" "${VER_GNUTLS[0]}"; then
        # Upstream files the tarballs under a major.minor series directory, so that
        # part of the path is derived from the pinned version rather than repeated.
        download "https://www.gnupg.org/ftp/gcrypt/gnutls/v${CURRENT_PACKAGE_VERSION%.*}/gnutls-$CURRENT_PACKAGE_VERSION.tar.xz"
        execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static --disable-doc --disable-tools --disable-cxx --disable-tests --disable-gtk-doc-html --disable-libdane --disable-nls --enable-local-libopts --disable-guile --with-included-libtasn1 --with-included-unistring --without-p11-kit CPPFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}"
        execute make -j "$MJOBS"
        execute make install
        build_done "gnutls" "$CURRENT_PACKAGE_VERSION"
    fi
    # CONFIGURE_OPTIONS+=("--enable-gmp" "--enable-gnutls")
}
