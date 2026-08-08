# shellcheck shell=bash
##
## optical media library
##

# Not requested by anyone and not used by ffmpeg directly: this exists solely because
# libbluray cannot be built without it. libbluray's meson.build does a plain
# dependency('libudfread', version: '>= 1.2.0') with no fallback, so pkg-config has to find
# it. Upstream carries it as a git submodule (contrib/libudfread in .gitmodules) and the
# release tarball ships neither the submodule nor a meson wrap or subprojects/ directory -
# the comment above that dependency() line still promises a subproject that is not there. So
# it has to be its own pinned package, the same conclusion build_libplacebo reached about
# its vendored dependencies.
#
# 1.2.0 dropped autotools and is meson-only, which is why this looks nothing like the
# autotools packages around it.
# libbluray's only mandatory dependency, and a separate package because it cannot be
# anything else: see the comment on build_libudfread.
VER_LIBUDFREAD=("1.2.0" "bb477cbd4cfbfc7787d9d05b71ee5e70430f5cfebf1297497f7e83547958050f")
build_libudfread() {
    if ! command_exists "python3"; then return; fi
    if ! command_exists "meson"; then return; fi

    if build "libudfread" "${VER_LIBUDFREAD[0]}"; then
        download "https://download.videolan.org/pub/videolan/libudfread/libudfread-$CURRENT_PACKAGE_VERSION.tar.xz"
        # embed_udfread is left at false on purpose. Setting it would build a static library
        # and install nothing at all - no headers, no libudfread.pc - which is what upstream
        # wants when libbluray consumes it as a subproject, and exactly what must not happen
        # here, because pkg-config is how libbluray is going to find it.
        execute meson setup build --prefix="${WORKSPACE}" --libdir="${WORKSPACE}"/lib \
            --buildtype=release --default-library=static -Denable_examples=false
        execute ninja -C build -j "$MJOBS"
        execute ninja -C build install
        build_done "libudfread" "$CURRENT_PACKAGE_VERSION"
    fi
}

# Blu-ray playlist demuxing: the bluray: input protocol and the mpls/clpi handling behind it.
# Asked for in #128, #222 and #245.
#
# Placed here rather than in the image or video sections because of what it optionally links:
# freetype2 (build_freetype2), fontconfig (build_fontconfig) and libxml2 (build_libxml2) are
# all "auto" features in its meson_options.txt, so they have to be installed before this runs
# or text subtitles and disc metadata are silently dropped. All three are already built by
# the time the order reaches here.
#
# Not licence-gated: ffmpeg 9.0 lists libbluray in the plain EXTERNAL_LIBRARY_LIST, and
# libbluray itself is LGPL-2.1.
VER_LIBBLURAY=("1.5.0" "f676408e91a5d321abf8b8d4dfdae36205c297dab5c54c3ec519639025f474a2")
build_libbluray() {
    if ! command_exists "python3"; then return; fi
    if ! command_exists "meson"; then return; fi
    # libudfread is mandatory, so skip rather than fail if its build was skipped above.
    if ! library_exists "libudfread"; then
        echo "Skipping libbluray: libudfread is not available, and libbluray cannot build without it."
        return
    fi

    if build "libbluray" "${VER_LIBBLURAY[0]}"; then
        download "https://download.videolan.org/pub/videolan/libbluray/$CURRENT_PACKAGE_VERSION/libbluray-$CURRENT_PACKAGE_VERSION.tar.xz"
        # bdj_jar defaults to "auto" and would pull in a JDK to compile the BD-J Java stack,
        # which is only needed for disc menus - ffmpeg never uses them, and a Java toolchain
        # is not a dependency worth acquiring. enable_tools defaults to *true* and would
        # build the bd_info/bd_splice command line tools.
        execute meson setup build --prefix="${WORKSPACE}" --libdir="${WORKSPACE}"/lib \
            --buildtype=release --default-library=static \
            -Dbdj_jar=disabled -Denable_tools=false -Denable_examples=false \
            -Denable_devtools=false -Denable_docs=false
        execute ninja -C build -j "$MJOBS"
        execute ninja -C build install
        build_done "libbluray" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libbluray")
}
