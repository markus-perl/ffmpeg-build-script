# shellcheck shell=bash
##
## build tools
##

VER_GIFLIB=("6.1.3" "b65b66b99f0424b93525f987386f22fc5efb9da2bfc92ad4a532249aaffbab0e")
build_giflib() {
    if build "giflib" "${VER_GIFLIB[0]}"; then
        download "https://sf-eu-introserv-1.dl.sourceforge.net/project/giflib/giflib-6.x/giflib-$CURRENT_PACKAGE_VERSION.tar.gz"
        cd "${PACKAGES}/giflib-$CURRENT_PACKAGE_VERSION" || exit
        # giflib 6.1.3's Darwin rule builds libutil.dylib without libgif.dylib,
        # although qprintf.c references GifErrorString from libgif.
        # shellcheck disable=SC2016 # $(CC) etc. are make variables, not shell expansions
        apply_inline_patch Makefile 's/$(CC) $(CFLAGS) -dynamiclib -current_version $(LIBVER) $(UOBJECTS) -o $(LIBUTILSO)/$(CC) $(CFLAGS) -dynamiclib -current_version $(LIBVER) $(UOBJECTS) $(LIBGIFSO) -o $(LIBUTILSO)/'
        #multicore build disabled for this library
        execute make
        # the default install target pulls in install-man and install-doc, and building
        # the docs fails if the tools needed are not installed. only install what ffmpeg needs.
        execute make PREFIX="${WORKSPACE}" install-bin install-include install-lib
        build_done "giflib" "$CURRENT_PACKAGE_VERSION"
    fi
}

VER_PKG_CONFIG=("0.29.2" "6fc69c01688c9458a57eb9a1664c9aba372ccda420a02bf4429fe610e7e7d591")
build_pkg_config() {
    if build "pkg-config" "${VER_PKG_CONFIG[0]}"; then
        download "https://pkgconfig.freedesktop.org/releases/pkg-config-$CURRENT_PACKAGE_VERSION.tar.gz"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            CFLAGS+=" -Wno-int-conversion" # pkg-config 0.29.2 has a warning that is treated as an error
            CFLAGS+=" -Wno-error=int-conversion"
            export CFLAGS
        fi
        # pkg-config 0.29.2 bundles a glib that uses "bool" as a struct member name, so
        # goption.c does not compile under C23. See pre_c23_cflag.
        execute ./configure --silent --prefix="${WORKSPACE}" --with-pc-path="${WORKSPACE}"/lib/pkgconfig --with-internal-glib CFLAGS="${CFLAGS}$(pre_c23_cflag)"
        execute make -j "$MJOBS"
        execute make install
        build_done "pkg-config" "$CURRENT_PACKAGE_VERSION"
    fi
}

# yasm is pinned to a master commit rather than a release: 1.3.0 is from 2019 and its
# libyasm/bitvect.h declares an enumeration constant named "false", which C23 rejects, so
# it does not build on GCC 15 (Ubuntu 26.04). Upstream guarded that on __STDC_VERSION__
# but has published no release since. A commit archive has no generated configure, so
# build_yasm bootstraps with autogen.sh and the entry sits after automake below.
VER_YASM=("09d1bc90ed53d0ec3e9b074f111058cbf262ed56" "5908256a2db37ca6f6b60025ee2a4a81a52ff8588e08776ce37c2551f00ab2e0")
build_yasm() {
    if build "yasm" "${VER_YASM[0]}"; then
        download "https://github.com/yasm/yasm/archive/$CURRENT_PACKAGE_VERSION.tar.gz" "yasm-$CURRENT_PACKAGE_VERSION.tar.gz"
        # A commit archive ships configure.ac but no configure, so generate the build
        # system first. autogen.sh needs aclocal, autoheader, automake and autoconf, which
        # is why yasm is ordered after automake; it runs configure itself and forwards
        # these arguments to it. re2c is vendored in tools/, so nothing else is needed.
        execute ./autogen.sh --prefix="${WORKSPACE}"

        # Generate the x86 instruction tables serially before the parallel build, or yasm
        # fails intermittently with "1: no keywords section found" from genperf.
        #
        # modules/arch/x86/Makefile.inc:16 declares one recipe with three outputs:
        #     x86insn_nasm.gperf x86insn_gas.gperf x86insns.c: gen_x86_insn.py
        #             $(PYTHON) gen_x86_insn.py
        # For a non-pattern rule GNU make treats that as three independent rules that each
        # run the recipe, so under -j it can start gen_x86_insn.py up to three times at once,
        # every copy writing the same three files. genperf then reads a .gperf that another
        # copy is still truncating and dies on the half-written file. It is timing-dependent,
        # so it passes far more often than it fails - which is exactly what makes it worth
        # pinning down rather than retrying.
        #
        # Asking for the three outputs explicitly costs a couple of redundant generator runs
        # and keeps the rest of the build parallel; -j1 on the whole package would serialise
        # the compile too. This is the only multi-output rule in the tree, so nothing else
        # needs the same treatment.
        execute make -j1 x86insn_nasm.gperf x86insn_gas.gperf x86insns.c
        execute make -j "$MJOBS"
        execute make install
        build_done "yasm" "$CURRENT_PACKAGE_VERSION"
    fi
}

VER_NASM=("3.02" "87336eba53b4acfe917424ab5d500d2b0054d9f5148d35c2273ccf2cfb712f0d")
build_nasm() {
    if build "nasm" "${VER_NASM[0]}"; then
        download "https://www.nasm.us/pub/nasm/releasebuilds/$CURRENT_PACKAGE_VERSION/nasm-$CURRENT_PACKAGE_VERSION.tar.xz"
        execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static
        execute make -j "$MJOBS"
        execute make install
        build_done "nasm" "$CURRENT_PACKAGE_VERSION"
    fi
}

VER_ZLIB=("1.3.2" "bb329a0a2cd0274d05519d61c667c062e06990d72e125ee2dfa8de64f0119d16")
build_zlib() {
    if build "zlib" "${VER_ZLIB[0]}"; then
        download "https://github.com/madler/zlib/releases/download/v$CURRENT_PACKAGE_VERSION/zlib-$CURRENT_PACKAGE_VERSION.tar.gz"
        execute ./configure --static --prefix="${WORKSPACE}"
        execute make -j "$MJOBS"
        execute make install
        build_done "zlib" "$CURRENT_PACKAGE_VERSION"
    fi
}

# liblzma, built for the same reason zlib above is: ffmpeg lists lzma in
# EXTERNAL_AUTODETECT_LIBRARY_LIST (configure line 2018), so it is picked up from whatever
# the build host happens to provide and silently left out otherwise. That made the result
# depend on the machine rather than on this script - lzma.h is absent from a stock
# ubuntu:24.04 with build-essential, so every Docker and CI build had CONFIG_LZMA=0, and it
# was 0 on macOS too. Building it here turns "maybe" into "always".
#
# What it buys: LZMA-compressed TIFF decoding (libavcodec/tiff.c line 818). Small, but the
# point is reproducibility, not the format.
#
# Only liblzma is wanted, so every tool and script the package would otherwise install is
# switched off. The xz *binary* is a host prerequisite for unpacking .tar.xz sources and is
# deliberately not taken from here: this runs long after the first .tar.xz is extracted.
# xz, for liblzma. Note 5.6.0 and 5.6.1 carried the xz-utils backdoor (CVE-2024-3094);
# this is well past both, and the tarball is pinned by checksum like every other package.
VER_XZ=("5.8.3" "3d3a1b973af218114f4f889bbaa2f4c037deaae0c8e815eec381c3d546b974a0")
build_xz() {
    if build "xz" "${VER_XZ[0]}"; then
        download "https://github.com/tukaani-project/xz/releases/download/v$CURRENT_PACKAGE_VERSION/xz-$CURRENT_PACKAGE_VERSION.tar.gz"
        execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static \
            --disable-dependency-tracking --disable-doc --disable-nls --disable-scripts \
            --disable-xz --disable-xzdec --disable-lzmadec --disable-lzmainfo --disable-lzma-links
        execute make -j "$MJOBS"
        execute make install
        build_done "xz" "$CURRENT_PACKAGE_VERSION"
    fi
    # Passed explicitly rather than left to autodetection. configure line 8361 turns an
    # explicit request that cannot be satisfied into a hard error ("lzma requested but not
    # found"), which is the whole point: if the liblzma built above ever fails to be picked
    # up, the build says so instead of quietly producing a binary without it.
    CONFIGURE_OPTIONS+=("--enable-lzma")
}

# libbz2, for the same reproducibility reason as build_xz above - but this one was fixing an
# actual divergence rather than a uniform gap. bzlib is in the same
# EXTERNAL_AUTODETECT_LIBRARY_LIST (configure line 2011), and it resolved differently per
# platform: bzlib.h ships in the macOS SDK, so macOS builds had CONFIG_BZLIB=1, while a stock
# ubuntu:24.04 with build-essential has no bzlib.h and every Docker, CI and native Linux build
# came out with CONFIG_BZLIB=0. The same commit therefore produced a macOS binary that could
# read bzlib-compressed Matroska tracks and a Linux binary that could not, with no warning
# either way. ffmpeg agrees this matters: configure line 3958 is
# matroska_demuxer_suggest="bzlib zlib".
#
# Read by libavformat/matroskadec.c line 1774 (MATROSKA_TRACK_ENCODING_COMP_BZLIB).
#
# No configure script - bzip2 is a hand-written Makefile - and no pkg-config file either,
# which is fine because ffmpeg probes it with check_lib rather than pkg-config (line 7272).
# Only the archive and its header are installed: "make install" would additionally put four
# executables and their man pages into the workspace, and the default "all" target builds
# those plus runs the compression self-test. CC is passed explicitly because the Makefile
# hardcodes CC=gcc, which is not a safe assumption on macOS; CFLAGS is deliberately left
# alone, since overriding it on the command line would drop the Makefile's own $(BIGFILES)
# and with it -D_FILE_OFFSET_BITS=64.
# 1.0.8 is the last release from sourceware and has been current since 2019; the successor
# repository at gitlab.com/bzip2/bzip2 has never tagged one.
VER_BZIP2=("1.0.8" "ab5a03176ee106d3f0fa90e381da478ddae405918153cca248e682cd0c4a2269")
build_bzip2() {
    if build "bzip2" "${VER_BZIP2[0]}"; then
        download "https://sourceware.org/pub/bzip2/bzip2-$CURRENT_PACKAGE_VERSION.tar.gz"
        execute make -j "$MJOBS" libbz2.a CC="${CC:-cc}"
        # mkdir -p, not make_dir: make_dir removes the directory first, and by this point
        # zlib and pkg-config have already installed into both of these.
        execute mkdir -p "${WORKSPACE}/lib" "${WORKSPACE}/include"
        execute cp -f libbz2.a "${WORKSPACE}/lib/libbz2.a"
        execute cp -f bzlib.h "${WORKSPACE}/include/bzlib.h"
        build_done "bzip2" "$CURRENT_PACKAGE_VERSION"
    fi
    # Explicit for the same reason as --enable-lzma above: configure line 8361 makes an
    # unsatisfiable explicit request fatal, so a regression here is loud rather than silent.
    CONFIGURE_OPTIONS+=("--enable-bzlib")
}

VER_M4=("1.4.21" "38ae59f7a30bf9c108193cc5c25fbb06014f21e230c7ede2eff614f7b7c37ed8")
build_m4() {
    if build "m4" "${VER_M4[0]}"; then
        download "https://ftp.gnu.org/gnu/m4/m4-$CURRENT_PACKAGE_VERSION.tar.gz"
        execute ./configure --prefix="${WORKSPACE}"
        execute make -j "$MJOBS"
        execute make install
        build_done "m4" "$CURRENT_PACKAGE_VERSION"
    fi
}

VER_AUTOCONF=("2.73" "259ddfa3bddc799cfb81489cc0f17dfdf1bd6d1505dda53c0f45ff60d6a4f9a7")
build_autoconf() {
    if build "autoconf" "${VER_AUTOCONF[0]}"; then
        download "https://ftp.gnu.org/gnu/autoconf/autoconf-$CURRENT_PACKAGE_VERSION.tar.gz"
        execute ./configure --prefix="${WORKSPACE}"
        execute make -j "$MJOBS"
        execute make install
        build_done "autoconf" "$CURRENT_PACKAGE_VERSION"
    fi
}

VER_AUTOMAKE=("1.18.1" "63e585246d0fc8772dffdee0724f2f988146d1a3f1c756a3dc5cfbefa3c01915")
build_automake() {
    if build "automake" "${VER_AUTOMAKE[0]}"; then
        download "https://ftp.gnu.org/gnu/automake/automake-$CURRENT_PACKAGE_VERSION.tar.gz"
        execute ./configure --prefix="${WORKSPACE}"
        execute make -j "$MJOBS"
        execute make install
        build_done "automake" "$CURRENT_PACKAGE_VERSION"
    fi
}

VER_LIBTOOL=("2.6.2" "24adb3aa9ae035c70faba344af57d73215eb89281045af6c7ccd307751f8b0bf")
build_libtool() {
    if build "libtool" "${VER_LIBTOOL[0]}"; then
        download "https://ftp.gnu.org/gnu/libtool/libtool-$CURRENT_PACKAGE_VERSION.tar.gz"
        execute ./configure --prefix="${WORKSPACE}" --enable-static --disable-shared
        execute make -j "$MJOBS"
        execute make install
        build_done "libtool" "$CURRENT_PACKAGE_VERSION"
    fi
}
