# shellcheck shell=bash
##
## video library
##

# The oldest meson that every package built here accepts. It is set by libplacebo,
# whose meson.build asks for >=0.63 - it uses the prefer_static built-in option, which
# is exactly the release that introduced it. Nothing else comes close: dav1d wants
# 0.54.0 and libvmaf 0.56.1. That gap matters because Ubuntu 22.04 - the base of
# cuda-ubuntu.dockerfile - packages meson 0.61.2, so "meson is installed" was not on
# its own a sufficient check and the CUDA build died in libplacebo's meson setup.
MESON_MIN_VERSION="0.63"

meson_version() {
    meson --version 2>/dev/null | head -n 1
}

meson_is_current() {
    if ! command_exists "meson"; then return 1; fi
    version_gte "$(meson_version)" "$MESON_MIN_VERSION"
}

# pip installs console scripts into the Python user base, which is ~/.local/bin on
# Linux and is not on PATH in a minimal image. Prepended rather than appended: when the
# distribution's own meson is the thing being replaced, /usr/bin/meson still exists, and
# a pip install that loses the PATH race would have been pointless.
add_python_user_bin_to_path() {
    local python_user_bin
    python_user_bin="$(python3 -m site --user-base 2>/dev/null)"
    if [ -n "$python_user_bin" ]; then
        export PATH="${python_user_bin}/bin:$PATH"
    else
        export PATH="$HOME/.local/bin:$PATH"
    fi
    # bash caches command lookups, so a newly shadowed meson would otherwise keep
    # resolving to the old path for the rest of the run.
    hash -r 2>/dev/null || true
}

# Every pip call in the bootstrap goes through here, for two reasons.
#
# It is never fatal. execute() exits 1 on any non-zero status, so routing pip through it
# aborted the whole build on PEP 668 distributions (Ubuntu 23.04+, Debian 12+), where pip
# refuses to touch the system Python with "error: externally-managed-environment". The
# advice printed just above the call - "try to install meson using your system package
# manager" - reads like a fallback but was unreachable, because the script had already
# exited by the time it would have mattered. Only hit when meson is not already present,
# which is why CI never saw it: the Dockerfiles apt-install meson first.
#
# And it retries with --break-system-packages, which is the flag PEP 668 added for exactly
# this case. Probed rather than assumed: it only exists in pip 23.0 and newer, and older
# pip errors out on the unknown option. Tried second, not first, so a virtualenv or a
# non-managed Python takes the plain path and nothing gets overridden that did not need it.
pip3_install() {
    if pip3 install "$@" --quiet --upgrade --no-cache-dir --disable-pip-version-check; then
        return 0
    fi
    if pip3 install --help 2>/dev/null | grep -q -- "--break-system-packages"; then
        echo "pip3 install $* failed; retrying with --break-system-packages."
        pip3 install "$@" --quiet --upgrade --no-cache-dir --disable-pip-version-check --break-system-packages && return 0
    fi
    echo "pip3 install $* failed. Continuing without it."
    return 1
}

# Not a package of its own: this bootstraps meson and ninja, which dav1d, the lv2
# stack and harfbuzz need. It keeps the build_ prefix so the dispatch loop below can
# call it like every other entry in PACKAGE_BUILD_ORDER.
build_meson_and_ninja() {
    if ! command_exists "python3"; then return; fi

    MESON_INSTALLED=false

    if command_exists "meson"; then
        if command_exists "ninja"; then
            MESON_INSTALLED=true
        fi
    fi

    if ! $MESON_INSTALLED; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if command_exists "brew"; then
                brew install python-setuptools meson ninja
                MESON_INSTALLED=true
            fi
        else
            if command_exists "pip3"; then
                echo "Try to install meson and ninja using pip3."
                echo "If you get an error (like externally-managed-environment), try to install meson using your system package manager"
                # meson and ninja can be installed via pip3
                pip3_install pip setuptools || true
                add_python_user_bin_to_path
                for r in meson ninja; do
                    if ! command_exists "${r}"; then
                        pip3_install "${r}" || true
                    fi
                done
                hash -r 2>/dev/null || true
                if command_exists "meson" && command_exists "ninja"; then
                    MESON_INSTALLED=true
                else
                    echo "meson/ninja are still missing. Install them with your system package manager; packages that need them will be skipped."
                fi
            else
                echo "Try to install meson using your system package manager to be able to compile ffmpeg with dav1d."
            fi
        fi
    fi

    # A second, separate question from the block above: that one only asks whether meson
    # exists at all, and a distribution meson that is too old passes it. Everything here
    # is deliberately non-fatal. The build already has a working meson, most packages are
    # happy with it, and the one that is not (build_libplacebo) checks the version itself
    # and skips - so a failed upgrade must cost libplacebo, not the whole run. That is not
    # hypothetical: pip refuses to touch the system Python on PEP 668 distributions
    # (externally-managed-environment), and the CUDA image has no pip3 at all.
    if command_exists "meson" && ! meson_is_current; then
        echo "meson $(meson_version) is older than ${MESON_MIN_VERSION}, which libplacebo requires."
        if [[ "$OSTYPE" == "darwin"* ]] && command_exists "brew"; then
            brew upgrade meson || true
            hash -r 2>/dev/null || true
        elif command_exists "pip3"; then
            echo "Trying to install a newer meson with pip3."
            add_python_user_bin_to_path
            pip3_install meson || true
            hash -r 2>/dev/null || true
        fi
        if meson_is_current; then
            echo "Now using meson $(meson_version)."
        else
            echo "Continuing with meson $(meson_version). Packages that need ${MESON_MIN_VERSION} or newer will be skipped."
        fi
    fi
}

build_dav1d() {
    if ! command_exists "python3"; then return; fi
    if ! command_exists "meson"; then return; fi

    if build "dav1d" "${VER_DAV1D[0]}"; then
        download "https://code.videolan.org/videolan/dav1d/-/archive/$CURRENT_PACKAGE_VERSION/dav1d-$CURRENT_PACKAGE_VERSION.tar.gz"
        make_dir build

        CFLAGSBACKUP=$CFLAGS
        if $MACOS_SILICON; then
            export CFLAGS="-arch arm64"
        fi

        execute meson build --prefix="${WORKSPACE}" --buildtype=release --default-library=static --libdir="${WORKSPACE}"/lib
        execute ninja -C build
        execute ninja -C build install

        if $MACOS_SILICON; then
            export CFLAGS=$CFLAGSBACKUP
        fi

        build_done "dav1d" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libdav1d")
}

build_svtav1() {
    if build "svtav1" "${VER_SVTAV1[0]}"; then
        download "https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/v$CURRENT_PACKAGE_VERSION/SVT-AV1-v$CURRENT_PACKAGE_VERSION.tar.gz" "svtav1-$CURRENT_PACKAGE_VERSION.tar.gz"
        cd "${PACKAGES}/svtav1-$CURRENT_PACKAGE_VERSION/Build/linux" || exit
        execute cmake -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DENABLE_SHARED=off -DBUILD_SHARED_LIBS=OFF ../.. -G"Unix Makefiles" -DCMAKE_BUILD_TYPE=Release
        execute make -j "$MJOBS"
        execute make install
        execute cp SvtAv1Enc.pc "${WORKSPACE}/lib/pkgconfig/"
        build_done "svtav1" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libsvtav1")
}

build_rav1e() {
    if ! command_exists "cargo"; then return; fi

    if build "rav1e" "${VER_RAV1E[0]}"; then
        echo "if you get the message 'cannot be built because it requires rustc x.xx or newer, try to run 'rustup update'"
        execute cargo install cargo-c
        download "https://github.com/xiph/rav1e/archive/refs/tags/v$CURRENT_PACKAGE_VERSION.tar.gz"
        execute cargo cinstall --prefix="${WORKSPACE}" --libdir=lib --library-type=staticlib --crt-static --release
        build_done "rav1e" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-librav1e")
}

build_x264() {
    if ! $NONFREE_AND_GPL; then return; fi

    if build "x264" "${VER_X264[0]}"; then
        download "https://code.videolan.org/videolan/x264/-/archive/$CURRENT_PACKAGE_VERSION/x264-$CURRENT_PACKAGE_VERSION.tar.gz" "x264-$CURRENT_PACKAGE_VERSION.tar.gz"
        cd "${PACKAGES}/x264-$CURRENT_PACKAGE_VERSION" || exit

        if [[ "$OSTYPE" == "linux-gnu" ]]; then
            execute ./configure --prefix="${WORKSPACE}" --enable-static --enable-pic CXXFLAGS="-fPIC ${CXXFLAGS}"
        else
            execute ./configure --prefix="${WORKSPACE}" --enable-static --enable-pic
        fi

        execute make -j "$MJOBS"
        execute make install
        execute make install-lib-static

        build_done "x264" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libx264")
}

build_x265() {
    if ! $NONFREE_AND_GPL; then return; fi

    if build "x265" "${VER_X265[0]}"; then
        download "https://bitbucket.org/multicoreware/x265_git/get/$X265_COMMIT.tar.gz" "x265-$CURRENT_PACKAGE_VERSION.tar.gz"

        if $MACOS_SILICON; then
            export CXXFLAGS="-DHAVE_NEON=1 ${CXXFLAGS}"
        fi

        # On AArch64, x265 turns its SIMD extensions on without ever asking whether the
        # compiler can target them. AARCH64_RUNTIME_CPU_DETECT defaults to ON
        # (source/CMakeLists.txt line 96) and that path force-sets CPU_HAS_SVE2 and friends
        # at line 342 with no probe at all. The one compile test it does run, at line 361,
        # only covers AARCH64_SVE_FLAG - nothing anywhere checks AARCH64_SVE2_FLAG, which is
        # "-march=armv9-a+i8mm+sve2", and armv9-a did not exist before GCC 12.
        #
        # So on Ubuntu 22.04's GCC 11 cmake succeeds and the build dies several minutes later
        # assembling the SVE2 kernels:
        #
        #   cc1: error: unknown value 'armv9-a+i8mm+sve2' for '-march'
        #
        # which is why aarch64 jammy could not build this script at all. CI never caught it
        # because the only 22.04 job is the CUDA one and that image is x86_64.
        #
        # Probe CMAKE_CXX_COMPILER, which is what actually assembles the .S files (line 1003),
        # and switch off whatever it cannot target. x265 already cascades a disabled extension
        # to the higher-order ones (line 413 onwards), so the flags need no ordering. With
        # run-time detection the only consequence is that those kernels are absent. Apple
        # clang accepts all of these, so this is a no-op on macOS.
        X265_ARCH_FLAGS=()
        if [[ "$(uname -m)" == "aarch64" || "$(uname -m)" == "arm64" ]]; then
            for x265_probe in \
                "ENABLE_NEON_DOTPROD=-march=armv8.2-a+dotprod" \
                "ENABLE_NEON_I8MM=-march=armv8.2-a+dotprod+i8mm" \
                "ENABLE_SVE=-march=armv8.2-a+dotprod+i8mm+sve" \
                "ENABLE_SVE2=-march=armv9-a+i8mm+sve2" \
                "ENABLE_SVE2_BITPERM=-march=armv9-a+i8mm+sve2-bitperm"; do
                x265_option="${x265_probe%%=*}"
                x265_flag="${x265_probe#*=}"
                if ! cxx_supports_flag "$x265_flag"; then
                    echo "x265: ${CXX:-c++} does not accept ${x265_flag}, so ${x265_option} is off."
                    X265_ARCH_FLAGS+=("-D${x265_option}=OFF")
                fi
            done
        fi

        # x265's bundled json11 uses uint8_t without including <cstdint>. libstdc++ pulled
        # that in transitively until GCC 15, which no longer does, so dynamicHDR10 fails to
        # compile on Ubuntu 26.04. Force the header in rather than patching vendored source.
        # This has to go through the environment: cmake seeds CMAKE_CXX_FLAGS from CXXFLAGS
        # and x265 appends its own -std=c++11 to it, whereas passing -DCMAKE_CXX_FLAGS on the
        # command line replaces that and the build then fails for want of C++11.
        X265_CXXFLAGS_BACKUP="$CXXFLAGS"
        export CXXFLAGS="-include cstdint ${CXXFLAGS}"

        # source/CMakeLists.txt selects the language standard from ENABLE_HDR10_PLUS: on for
        # gnu++11, off for gnu++98. The 8-bit pass below does not set it, and GCC 15's
        # libstdc++ headers refuse to compile as C++98 at all, so that pass fails on Ubuntu
        # 26.04. Build every pass as gnu++11, which the 10- and 12-bit ones already use.
        # add_definitions() puts the flag after CXXFLAGS on the command line, so it cannot be
        # overridden from the environment; the source has to say it.
        apply_inline_patch source/CMakeLists.txt 's/-std=gnu++98/-std=gnu++11/'

        cd build/linux || exit
        rm -rf 8bit 10bit 12bit 2>/dev/null
        mkdir -p 8bit 10bit 12bit
        cd 12bit || exit
        execute cmake ../../../source -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DENABLE_SHARED=OFF -DBUILD_SHARED_LIBS=OFF -DHIGH_BIT_DEPTH=ON -DENABLE_HDR10_PLUS=ON -DEXPORT_C_API=OFF -DENABLE_CLI=OFF -DMAIN12=ON "${X265_ARCH_FLAGS[@]}"
        execute make -j "$MJOBS"
        cd ../10bit || exit
        execute cmake ../../../source -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DENABLE_SHARED=OFF -DBUILD_SHARED_LIBS=OFF -DHIGH_BIT_DEPTH=ON -DENABLE_HDR10_PLUS=ON -DEXPORT_C_API=OFF -DENABLE_CLI=OFF "${X265_ARCH_FLAGS[@]}"
        execute make -j "$MJOBS"
        cd ../8bit || exit
        ln -sf ../10bit/libx265.a libx265_main10.a
        ln -sf ../12bit/libx265.a libx265_main12.a
        execute cmake ../../../source -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DENABLE_SHARED=OFF -DBUILD_SHARED_LIBS=OFF -DEXTRA_LIB="x265_main10.a;x265_main12.a;-ldl" -DEXTRA_LINK_FLAGS=-L. -DLINKED_10BIT=ON -DLINKED_12BIT=ON "${X265_ARCH_FLAGS[@]}"
        execute make -j "$MJOBS"

        mv libx265.a libx265_main.a

        if [[ "$OSTYPE" == "darwin"* ]]; then
            execute "${MACOS_LIBTOOL}" -static -o libx265.a libx265_main.a libx265_main10.a libx265_main12.a 2>/dev/null
        else
            execute ar -M <<'EOF'
CREATE libx265.a
ADDLIB libx265_main.a
ADDLIB libx265_main10.a
ADDLIB libx265_main12.a
SAVE
END
EOF
        fi

        execute make install

        export CXXFLAGS="$X265_CXXFLAGS_BACKUP"

        if [ -n "$LDEXEFLAGS" ]; then
            sed -i.backup 's/-lgcc_s/-lgcc_eh/g' "${WORKSPACE}/lib/pkgconfig/x265.pc" # The -i.backup is intended and required on MacOS: https://stackoverflow.com/questions/5694228/sed-in-place-flag-that-works-both-on-mac-bsd-and-linux
        fi

        build_done "x265" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libx265")
}

build_openh264() {
    # Deliberately not behind $NONFREE_AND_GPL, unlike x264/x265 right above:
    # ffmpeg 9.0 lists libopenh264 in the plain EXTERNAL_LIBRARY_LIST (configure
    # line 2109) and in none of the GPL/nonfree/version3 lists, because openh264 is
    # BSD-2-Clause. It is the only H.264 *encoder* the default LGPL build can get -
    # ffmpeg has a native H.264 decoder but no native encoder - so gating it would
    # leave that build without any way to produce H.264.
    if build "openh264" "${VER_OPENH264[0]}"; then
        download "https://github.com/cisco/openh264/archive/refs/tags/v$CURRENT_PACKAGE_VERSION.tar.gz" "openh264-$CURRENT_PACKAGE_VERSION.tar.gz"

        # The plain Makefile rather than the meson build: the "install-static" target
        # is the only one that builds *just* libopenh264.a - the default target and
        # meson both produce the shared library as well, which this script does not
        # want. It also installs the wels/ headers and generates openh264.pc from
        # openh264-static.pc.in with PREFIX substituted in, which is what ffmpeg's
        # require_pkg_config (configure line 7410) needs. That .pc carries the C++
        # runtime in Libs (not Libs.private) - "-lstdc++" everywhere plus
        # "-lpthread -lm" on Linux - so ffmpeg picks up the C++ dependency of this
        # C++ library by itself, and no --full-static fixup is needed here: unlike
        # x265.pc and srt.pc, this .pc never mentions -lgcc_s.
        #
        # x86 assembly is assembled with nasm (build/x86-common.mk sets ASM = nasm
        # unconditionally, yasm is not an option), which the build_nasm entry earlier
        # in PACKAGE_BUILD_ORDER has already installed into $WORKSPACE/bin - that is
        # on PATH, so it is found without pointing the Makefile at it. On arm64 the
        # NEON paths are .S files assembled by the C compiler and nasm is unused.
        execute make -j "$MJOBS" PREFIX="${WORKSPACE}" install-static

        build_done "openh264" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libopenh264")
}

# H.266/VVC encoding (#179). FFmpeg 9.0 has a native VVC *decoder*, so only the encoder side
# is missing, and there is no --enable-libvvdec to pair with this. Not licence-gated: vvenc is
# BSD-3-Clause with a patent clause and ffmpeg lists libvvenc in the plain
# EXTERNAL_LIBRARY_LIST (configure line 2143).
build_vvenc() {
    if build "vvenc" "${VER_VVENC[0]}"; then
        download "https://github.com/fraunhoferhhi/vvenc/archive/refs/tags/v$CURRENT_PACKAGE_VERSION.tar.gz" "vvenc-$CURRENT_PACKAGE_VERSION.tar.gz"

        # VVENC_LIBRARY_ONLY skips vvencapp, vvencFFapp and the three test binaries, which are
        # the bulk of the build and none of which is installed anyway. BUILD_SHARED_LIBS is
        # already OFF upstream and VVENC_ENABLE_INSTALL already ON; both are spelled out
        # because they are the two defaults that would quietly change what this produces.
        #
        # Link-time optimisation is on by default for Release builds and is turned off here.
        # It would leave GCC IR rather than machine code in libvvenc.a, which then only links
        # if every consumer of the archive runs the LTO plugin - ffmpeg links with $CC, so
        # that mostly holds, but --full-static and a plain binutils ld are exactly where it
        # stops holding. No other package in this script ships LTO objects.
        execute cmake -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DCMAKE_INSTALL_LIBDIR=lib \
            -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
            -DVVENC_LIBRARY_ONLY=ON -DVVENC_ENABLE_INSTALL=ON \
            -DVVENC_ENABLE_LINK_TIME_OPT=OFF \
            -B build/
        execute cmake --build build --target install -j "$MJOBS"

        build_done "vvenc" "$CURRENT_PACKAGE_VERSION"
    fi
    # No .pc fixup: vvencInstall.cmake builds Libs.private from
    # CMAKE_CXX_IMPLICIT_LINK_LIBRARIES but already drops -lc and -lgcc_s from it, so the
    # installed libvvenc.pc declares just the C++ runtime (-lstdc++, or -lc++ on macOS) and
    # has none of the --full-static problem that x265.pc and srt.pc have.
    CONFIGURE_OPTIONS+=("--enable-libvvenc")
}

build_libvpx() {
    if build "libvpx" "${VER_LIBVPX[0]}"; then
        download "https://github.com/webmproject/libvpx/archive/refs/tags/v$CURRENT_PACKAGE_VERSION.tar.gz" "libvpx-$CURRENT_PACKAGE_VERSION.tar.gz"

        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "Applying Darwin patch"
            apply_inline_patch build/make/Makefile "s/,--version-script//g"
            apply_inline_patch build/make/Makefile "s/-Wl,--no-undefined -Wl,-soname/-Wl,-undefined,error -Wl,-install_name/g"
        fi

        execute ./configure --prefix="${WORKSPACE}" --disable-unit-tests --disable-shared --disable-examples --as=yasm --enable-vp9-highbitdepth
        execute make -j "$MJOBS"
        execute make install

        build_done "libvpx" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libvpx")
}

build_xvidcore() {
    if ! $NONFREE_AND_GPL; then return; fi

    if build "xvidcore" "${VER_XVIDCORE[0]}"; then
        download "https://downloads.xvid.com/downloads/xvidcore-$CURRENT_PACKAGE_VERSION.tar.gz"
        cd build/generic || exit
        # src/encoder.h typedefs "bool", which C23 made a keyword. See pre_c23_cflag.
        XVID_STD_FLAG="$(pre_c23_cflag)"
        if [ -n "$XVID_STD_FLAG" ]; then
            execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static CFLAGS="-O2$XVID_STD_FLAG"
        else
            execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static
        fi
        execute make -j "$MJOBS"
        execute make install

        if [[ -f ${WORKSPACE}/lib/libxvidcore.4.dylib ]]; then
            execute rm "${WORKSPACE}/lib/libxvidcore.4.dylib"
        fi

        if [[ -f ${WORKSPACE}/lib/libxvidcore.so ]]; then
            execute rm "${WORKSPACE}"/lib/libxvidcore.so*
        fi

        build_done "xvidcore" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libxvid")
}

build_vid_stab() {
    if ! $NONFREE_AND_GPL; then return; fi

    if build "vid_stab" "${VER_VID_STAB[0]}"; then
        download "https://github.com/georgmartius/vid.stab/archive/v$CURRENT_PACKAGE_VERSION.tar.gz" "vid.stab-$CURRENT_PACKAGE_VERSION.tar.gz"

        if $MACOS_SILICON; then
            PATCH_URL="https://raw.githubusercontent.com/Homebrew/formula-patches/5bf1a0e0cfe666ee410305cece9c9c755641bfdf/libvidstab/fix_cmake_quoting.patch"
            PATCH_FILE="$PACKAGES/vid.stab-$CURRENT_PACKAGE_VERSION/fix_cmake_quoting.patch"

            if ! download_with_retries "$PATCH_URL" "$PATCH_FILE" "${VER_VID_STAB_PATCH[1]}"; then
                echo "Failed to download patch from $PATCH_URL"
                exit 1
            fi

            patch -p1 <fix_cmake_quoting.patch
        fi

        execute cmake -DBUILD_SHARED_LIBS=OFF -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DUSE_OMP=OFF -DENABLE_SHARED=off .
        execute make
        execute make install

        build_done "vid_stab" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libvidstab")
}

build_frei0r() {
    # frei0r is in ffmpeg 9.0's EXTERNAL_LIBRARY_GPL_LIST (configure line 2031), so
    # --enable-frei0r implies --enable-gpl and must stay behind this script's flag.
    if ! $NONFREE_AND_GPL; then return; fi

    # frei0r plugins are shared objects that the frei0r filters dlopen() at runtime
    # from ~/.frei0r-1/lib and the system frei0r-1 directories. A --full-static
    # ffmpeg cannot do that, and configure would drop the filters anyway: the
    # frei0r_filter/frei0r_src_filter both carry frei0r_deps_any="libdl LoadLibrary"
    # and neither resolves in a fully static link. Enabling it there would only add
    # a header requirement in exchange for filters that are never registered, so the
    # whole package is skipped instead.
    if [ -n "$LDEXEFLAGS" ]; then return; fi

    if build "frei0r" "${VER_FREI0R[0]}"; then
        download "https://github.com/dyne/frei0r/archive/refs/tags/v$CURRENT_PACKAGE_VERSION.tar.gz" "frei0r-$CURRENT_PACKAGE_VERSION.tar.gz"
        # Header-only on purpose: ffmpeg 9.0's configure does nothing but
        # `require_headers "frei0r.h"` (line 7315) - there is no frei0r library to
        # link, the plugins are loaded at runtime. So the upstream cmake build, which
        # would compile the entire GPL plugin collection, is skipped and only the API
        # header is installed. Note that frei0r.h itself carries no copyright or
        # license banner - upstream treats it purely as the API specification so that
        # hosts can include it - but that does not affect the gate above, since the
        # GPL classification is ffmpeg's, not the header's.
        execute cp -f include/frei0r.h "${WORKSPACE}"/include/frei0r.h
        build_done "frei0r" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-frei0r")
}

build_av1() {
    if build "av1" "${VER_AV1[0]}"; then
        download "https://aomedia.googlesource.com/aom/+archive/refs/tags/v$CURRENT_PACKAGE_VERSION.tar.gz" "av1-$CURRENT_PACKAGE_VERSION.tar.gz" "av1"
        make_dir "$PACKAGES"/aom_build
        cd "$PACKAGES"/aom_build || exit
        if $MACOS_SILICON; then
            execute cmake -DENABLE_TESTS=0 -DENABLE_EXAMPLES=0 -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DCMAKE_INSTALL_LIBDIR=lib -DCONFIG_RUNTIME_CPU_DETECT=0 "$PACKAGES"/av1
        else
            execute cmake -DENABLE_TESTS=0 -DENABLE_EXAMPLES=0 -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DCMAKE_INSTALL_LIBDIR=lib "$PACKAGES"/av1
        fi
        execute make -j "$MJOBS"
        execute make install

        build_done "av1" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libaom")
}

build_zimg() {
    if build "zimg" "${VER_ZIMG[0]}"; then
        download "https://github.com/sekrit-twc/zimg/archive/refs/tags/release-$CURRENT_PACKAGE_VERSION.tar.gz" "zimg-$CURRENT_PACKAGE_VERSION.tar.gz" "zimg"
        cd "zimg-release-$CURRENT_PACKAGE_VERSION" || exit
        execute "${WORKSPACE}/bin/libtoolize" -i -f -q
        execute ./autogen.sh --prefix="${WORKSPACE}"
        execute ./configure --prefix="${WORKSPACE}" --enable-static --disable-shared
        execute make -j "$MJOBS"
        execute make install
        build_done "zimg" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libzimg")
}

# Last in the video section because nothing else depends on it: libvmaf is a quality *metric*, not a
# codec - it backs the vmaf filter, which scores a distorted stream against a reference. It only
# needs to come after build_meson_and_ninja (its sole build system) and after build_nasm, which the
# build-tools section has already installed for its x86 cpuid.asm.
#
# Deliberately not behind $NONFREE_AND_GPL: ffmpeg 9.0 lists libvmaf in the plain
# EXTERNAL_LIBRARY_LIST (configure line 2140) and in none of the GPL/nonfree/version3 lists - Netflix
# releases it under BSD-2-Clause-Patent.
build_libvmaf() {
    # python3 is needed twice over: meson itself is a Python program, and the xxd shim below is
    # Python. Mirrors build_dav1d/build_libplacebo, which skip themselves the same way.
    if ! command_exists "python3"; then return; fi
    if ! command_exists "meson"; then return; fi

    if build "libvmaf" "${VER_LIBVMAF[0]}"; then
        download "https://github.com/Netflix/vmaf/archive/refs/tags/v$CURRENT_PACKAGE_VERSION.tar.gz" "vmaf-$CURRENT_PACKAGE_VERSION.tar.gz"

        # The default VMAF models ship as JSON under model/ and are *compiled into* the library:
        # libvmaf/src/meson.build runs "xxd -i -n src_<file>" over each one and links the resulting
        # arrays, which is what makes vmaf_model_load(&m, &cfg, "vmaf_v0.6.1") work with nothing on
        # disk. ffmpeg needs exactly that - vf_libvmaf's "model" option defaults to
        # "version=vmaf_v0.6.1" (vf_libvmaf.c line 78) and resolves it through vmaf_model_load - so
        # the models must not be left out. But meson only does "find_program('xxd', required:
        # false)": with no xxd the models are silently dropped, the library still builds, ffmpeg
        # still configures, and the filter only fails at runtime. That is exactly the kind of
        # failure this script should not ship, and xxd is not a dependency worth adding to the
        # documented prerequisites - ubuntu:24.04 has no xxd, and the project Dockerfile does not
        # install one. So supply a shim covering the two invocations meson makes: the
        # "xxd -n test" capability probe, and "xxd -i -n <symbol> <in> <out>". Names are sanitised
        # the same way real xxd does it, because model.c declares the symbols as
        # src_vmaf_v0_6_1_json - dots turned into underscores.
        if ! command_exists "xxd"; then
            # mkdir -p, not make_dir: make_dir removes the directory first, and $WORKSPACE/bin is
            # where pkg-config, nasm and cmake already live.
            execute mkdir -p "${WORKSPACE}/bin"
            # A heredoc cannot be routed through execute(), so the write is checked inline.
            if ! cat >"${WORKSPACE}/bin/xxd" <<'XXD_SHIM'; then
#!/usr/bin/env python3
import re
import sys

name = None
files = []
args = sys.argv[1:]
i = 0
while i < len(args):
    if args[i] == '-n':
        name = args[i + 1]
        i += 2
    elif args[i].startswith('-'):
        i += 1
    else:
        files.append(args[i])
        i += 1

# This shim implements exactly the two calls meson makes and nothing else. It stays in
# $WORKSPACE/bin, which is on PATH for the rest of the run, so anything it does not understand
# must fail loudly rather than succeed quietly and hand back an empty file.
if len(files) == 0:
    # "xxd -n test": the capability probe, which only wants a zero exit status.
    sys.exit(0)
if len(files) != 2:
    sys.stderr.write(
        'xxd shim (ffmpeg-build-script): only "xxd -i -n <symbol> <in> <out>" is supported, '
        'got: %s\n' % ' '.join(sys.argv[1:])
    )
    sys.exit(1)

with open(files[0], 'rb') as fh:
    data = fh.read()

symbol = re.sub(r'[^0-9A-Za-z_]', '_', name if name else files[0])
octets = ['0x%02x' % b for b in bytearray(data)]
rows = [', '.join(octets[j:j + 12]) for j in range(0, len(octets), 12)]

with open(files[1], 'w') as fh:
    fh.write('unsigned char %s[] = {\n' % symbol)
    if rows:
        fh.write('  ' + ',\n  '.join(rows) + '\n')
    fh.write('};\n')
    fh.write('unsigned int %s_len = %d;\n' % (symbol, len(octets)))
XXD_SHIM
                echo "Failed to write the xxd shim to ${WORKSPACE}/bin/xxd" >&2
                exit 1
            fi
            execute chmod +x "${WORKSPACE}/bin/xxd"
        fi

        # The meson project lives in libvmaf/, not at the top of the repository.
        cd libvmaf || exit

        # enable_float pulls in the legacy floating-point feature extractors, which only add the
        # vmaf_float_* model variants ffmpeg never asks for by default; the fixed-point path is the
        # one upstream recommends. enable_tools would build the "vmaf" CLI and enable_docs wants
        # doxygen - neither is of any use to ffmpeg.
        execute meson setup build --prefix="${WORKSPACE}" --libdir="${WORKSPACE}"/lib --buildtype=release --default-library=static \
            -Denable_tests=false -Denable_docs=false -Denable_tools=false \
            -Denable_float=false -Dbuilt_in_models=true
        execute ninja -C build -j "$MJOBS"
        execute ninja -C build install

        # libvmaf bundles libsvm (src/libsvm/svm.cpp) and compiles it into libvmaf.a, so the archive
        # references operator new, __cxa_throw and friends. meson never links the static library, so
        # it does not notice and generates a libvmaf.pc without a C++ runtime; ffmpeg links with $CC
        # and those symbols would go unresolved in require_pkg_config's link step (configure line
        # 7458), which reports only the misleading "libvmaf not found using pkg-config". Appended to
        # the end of Libs, not prepended: GNU ld is one-pass, so the runtime has to sit to the right
        # of the -lvmaf that needs it. Same fixup as build_libplacebo and openh264.pc.
        LIBVMAF_CXX_LIB="-lstdc++"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            LIBVMAF_CXX_LIB="-lc++"
        fi
        apply_inline_patch "${WORKSPACE}/lib/pkgconfig/libvmaf.pc" "s|^\(Libs:.*\)|\1 ${LIBVMAF_CXX_LIB}|"

        build_done "libvmaf" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libvmaf")

    # NOTE: deliberately not gated on --full-static, for the same reason as libplacebo. The generated
    # libvmaf.pc never mentions -lgcc_s, and the models are inside the archive rather than dlopen()ed
    # or read from disk, so a fully static link has nothing to work around.
}
