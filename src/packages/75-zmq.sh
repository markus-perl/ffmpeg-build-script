# shellcheck shell=bash
##
## zmq library
##

build_libzmq() {
    if build "libzmq" "${VER_LIBZMQ[0]}"; then
        download "https://github.com/zeromq/libzmq/releases/download/v$CURRENT_PACKAGE_VERSION/zeromq-$CURRENT_PACKAGE_VERSION.tar.gz"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            export XML_CATALOG_FILES=/usr/local/etc/xml/catalog
        fi
        # --disable-ws is what keeps this archive from colliding with libssh. libzmq vendors a
        # SHA-1 implementation for the WebSocket handshake (external/sha1/sha1.c, pulled in by
        # the USE_BUILTIN_SHA1 conditional) whose sha1_init is a plain global symbol, and
        # libssh's md_crypto.c exports a global sha1_init of its own. Both land in the same
        # static link, and ffmpeg then fails to link at the very end of the build with
        # "multiple definition of `sha1_init'" on ffmpeg_g, ffprobe_g and ffplay_g alike -
        # long after both libraries have built and installed cleanly.
        #
        # Turning the transport off is the right fix rather than renaming a symbol in someone
        # else's archive: ws:// is a draft ZeroMQ feature (configure defaults --enable-ws to
        # the state of --enable-drafts), ffmpeg's zmq/azmq protocols and the zmq/azmq filters
        # only ever speak tcp:// and ipc://, and nothing here builds the gnutls or nss backends
        # that would be the alternative SHA-1 providers. Verified: sha1_init disappears from
        # libzmq.a with this flag and is present without it.
        execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static --disable-ws
        apply_inline_patch src/proxy.cpp "s/stats_proxy stats = {0}/stats_proxy stats = {{{0, 0}, {0, 0}}, {{0, 0}, {0, 0}}}/g"
        execute make -j "$MJOBS"
        execute make install
        build_done "libzmq" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libzmq")
}
