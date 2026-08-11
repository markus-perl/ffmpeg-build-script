# shellcheck shell=bash
##
## audio library
##

build_lv2() {
    if ! command_exists "python3"; then return; fi
    if ! command_exists "meson"; then return; fi

    if build "lv2" "${VER_LV2[0]}"; then
        download "https://lv2plug.in/spec/lv2-$CURRENT_PACKAGE_VERSION.tar.xz" "lv2-$CURRENT_PACKAGE_VERSION.tar.xz"
        execute meson build --prefix="${WORKSPACE}" --buildtype=release --default-library=static --libdir="${WORKSPACE}"/lib
        execute ninja -C build
        execute ninja -C build install
        build_done "lv2" "$CURRENT_PACKAGE_VERSION"
    fi
}

build_waflib() {
    if ! command_exists "python3"; then return; fi
    if ! command_exists "meson"; then return; fi

    if build "waflib" "${VER_WAFLIB[0]}"; then
        download "https://gitlab.com/drobilla/autowaf/-/archive/$CURRENT_PACKAGE_VERSION/autowaf-$CURRENT_PACKAGE_VERSION.tar.gz" "autowaf.tar.gz"
        build_done "waflib" "$CURRENT_PACKAGE_VERSION"
    fi
}

build_serd() {
    if ! command_exists "python3"; then return; fi
    if ! command_exists "meson"; then return; fi

    if build "serd" "${VER_SERD[0]}"; then
        download "https://gitlab.com/drobilla/serd/-/archive/v$CURRENT_PACKAGE_VERSION/serd-v$CURRENT_PACKAGE_VERSION.tar.gz" "serd-v$CURRENT_PACKAGE_VERSION.tar.gz"
        execute meson build --prefix="${WORKSPACE}" --buildtype=release --default-library=static --libdir="${WORKSPACE}"/lib
        execute ninja -C build
        execute ninja -C build install
        build_done "serd" "$CURRENT_PACKAGE_VERSION"
    fi
}

build_pcre() {
    if ! command_exists "python3"; then return; fi
    if ! command_exists "meson"; then return; fi

    if build "pcre" "${VER_PCRE[0]}"; then
        download "https://altushost-swe.dl.sourceforge.net/project/pcre/pcre/$CURRENT_PACKAGE_VERSION/pcre-$CURRENT_PACKAGE_VERSION.tar.gz" "pcre-$CURRENT_PACKAGE_VERSION.tar.gz"
        execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static
        execute make -j "$MJOBS"
        execute make install
        build_done "pcre" "$CURRENT_PACKAGE_VERSION"
    fi
}

build_zix() {
    if ! command_exists "python3"; then return; fi
    if ! command_exists "meson"; then return; fi

    if build "zix" "${VER_ZIX[0]}"; then
        download "https://gitlab.com/drobilla/zix/-/archive/v$CURRENT_PACKAGE_VERSION/zix-v$CURRENT_PACKAGE_VERSION.tar.gz" "zix-v$CURRENT_PACKAGE_VERSION.tar.gz"
        execute meson setup build --prefix="${WORKSPACE}" --buildtype=release --default-library=static --libdir="${WORKSPACE}"/lib
        cd build || exit
        execute meson configure -Dprefix="${WORKSPACE}" -Dlibdir="${WORKSPACE}"/lib
        execute meson compile
        execute meson install
        build_done "zix" "$CURRENT_PACKAGE_VERSION"
    fi
}

build_sord() {
    if ! command_exists "python3"; then return; fi
    if ! command_exists "meson"; then return; fi

    if build "sord" "${VER_SORD[0]}"; then
        download "https://gitlab.com/drobilla/sord/-/archive/v$CURRENT_PACKAGE_VERSION/sord-v$CURRENT_PACKAGE_VERSION.tar.gz" "sord-v$CURRENT_PACKAGE_VERSION.tar.gz"
        execute meson build --prefix="${WORKSPACE}" --buildtype=release --default-library=static --libdir="${WORKSPACE}"/lib
        execute ninja -C build
        execute ninja -C build install
        build_done "sord" "$CURRENT_PACKAGE_VERSION"
    fi
}

build_sratom() {
    if ! command_exists "python3"; then return; fi
    if ! command_exists "meson"; then return; fi

    if build "sratom" "${VER_SRATOM[0]}"; then
        download "https://gitlab.com/lv2/sratom/-/archive/v$CURRENT_PACKAGE_VERSION/sratom-v$CURRENT_PACKAGE_VERSION.tar.gz" "sratom-v$CURRENT_PACKAGE_VERSION.tar.gz"
        execute meson build --prefix="${WORKSPACE}" -Ddocs=disabled --buildtype=release --default-library=static --libdir="${WORKSPACE}"/lib
        execute ninja -C build
        execute ninja -C build install
        build_done "sratom" "$CURRENT_PACKAGE_VERSION"
    fi
}

build_lilv() {
    if ! command_exists "python3"; then return; fi
    if ! command_exists "meson"; then return; fi

    if build "lilv" "${VER_LILV[0]}"; then
        download "https://gitlab.com/lv2/lilv/-/archive/v$CURRENT_PACKAGE_VERSION/lilv-v$CURRENT_PACKAGE_VERSION.tar.gz" "lilv-v$CURRENT_PACKAGE_VERSION.tar.gz"
        execute meson build --prefix="${WORKSPACE}" -Ddocs=disabled --buildtype=release --default-library=static --libdir="${WORKSPACE}"/lib -Dcpp_std=c++11
        execute ninja -C build
        execute ninja -C build install
        build_done "lilv" "$CURRENT_PACKAGE_VERSION"
    fi
    CFLAGS+=" -I$WORKSPACE/include/lilv-0"

    CONFIGURE_OPTIONS+=("--enable-lv2")
}

build_ladspa() {
    # Unlike frei0r, ladspa is in the plain EXTERNAL_LIBRARY_LIST (configure line
    # 2076) with no license entry, so it is available in the default LGPL build and
    # is deliberately not gated on NONFREE_AND_GPL.

    # Same runtime story as frei0r: the ladspa filter dlopen()s plugin .so files
    # found via the LADSPA_PATH environment variable, and its dependency line is
    # ladspa_filter_deps="ladspa libdl". A fully static ffmpeg cannot dlopen, and
    # configure would register no ladspa filter at all, so skip the package rather
    # than ship a flag that buys nothing.
    if [ -n "$LDEXEFLAGS" ]; then return; fi

    if build "ladspa" "${VER_LADSPA[0]}"; then
        # ffmpeg 9.0's configure only does `require_headers "ladspa.h dlfcn.h"` (line
        # 7319), so as with frei0r nothing gets compiled or linked - the SDK's example
        # plugins and command line tools are of no use here and the header is enough.
        # dlfcn.h comes from the platform. No extra link flags are needed either:
        # there is no ladspa_extralibs in configure, only the generic
        # `check_lib libdl dlfcn.h "dlopen dlsym" || ... -ldl` probe at line 7290,
        # which on macOS is satisfied by libc alone, and this script's EXTRALIBS
        # already passes -ldl for the glibc case.
        download "https://www.ladspa.org/download/ladspa_sdk_$CURRENT_PACKAGE_VERSION.tgz" "ladspa_sdk-$CURRENT_PACKAGE_VERSION.tar.gz"
        execute cp -f src/ladspa.h "${WORKSPACE}"/include/ladspa.h
        build_done "ladspa" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-ladspa")
}

build_opencore() {
    if build "opencore" "${VER_OPENCORE[0]}"; then
        download "https://deac-ams.dl.sourceforge.net/project/opencore-amr/opencore-amr/opencore-amr-$CURRENT_PACKAGE_VERSION.tar.gz" "opencore-amr-$CURRENT_PACKAGE_VERSION.tar.gz"
        execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static
        execute make -j "$MJOBS"
        execute make install

        build_done "opencore" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libopencore_amrnb" "--enable-libopencore_amrwb")
}

build_lame() {
    if build "lame" "${VER_LAME[0]}"; then
        download "https://sourceforge.net/projects/lame/files/lame/$CURRENT_PACKAGE_VERSION/lame-$CURRENT_PACKAGE_VERSION.tar.gz/download?use_mirror=gigenet" "lame-$CURRENT_PACKAGE_VERSION.tar.gz"
        # FFmpeg only needs libmp3lame. LAME 4.0 enables an external mpg123
        # decoder and its command-line frontend by default; neither is needed.
        execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static --disable-decoder --disable-frontend
        execute make -j "$MJOBS"
        execute make install

        build_done "lame" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libmp3lame")
}

build_opus() {
    if build "opus" "${VER_OPUS[0]}"; then
        download "https://downloads.xiph.org/releases/opus/opus-$CURRENT_PACKAGE_VERSION.tar.gz"
        execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static
        execute make -j "$MJOBS"
        execute make install

        build_done "opus" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libopus")
}

build_libogg() {
    if build "libogg" "${VER_LIBOGG[0]}"; then
        download "https://ftp.osuosl.org/pub/xiph/releases/ogg/libogg-$CURRENT_PACKAGE_VERSION.tar.xz"
        execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static
        execute make -j "$MJOBS"
        execute make install
        build_done "libogg" "$CURRENT_PACKAGE_VERSION"
    fi
}

build_libvorbis() {
    if build "libvorbis" "${VER_LIBVORBIS[0]}"; then
        download "https://ftp.osuosl.org/pub/xiph/releases/vorbis/libvorbis-$CURRENT_PACKAGE_VERSION.tar.gz"
        apply_inline_patch configure.ac 's/-force_cpusubtype_ALL//g'
        execute ./autogen.sh --prefix="${WORKSPACE}"
        execute ./configure --prefix="${WORKSPACE}" --with-ogg-libraries="${WORKSPACE}"/lib --with-ogg-includes="${WORKSPACE}"/include/ --enable-static --disable-shared --disable-oggtest
        execute make -j "$MJOBS"
        execute make install

        build_done "libvorbis" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libvorbis")
}

build_libtheora() {
    if build "libtheora" "${VER_LIBTHEORA[0]}"; then
        download "https://ftp.osuosl.org/pub/xiph/releases/theora/libtheora-$CURRENT_PACKAGE_VERSION.tar.gz"
        execute ./configure --prefix="${WORKSPACE}" --with-ogg-libraries="${WORKSPACE}"/lib --with-ogg-includes="${WORKSPACE}"/include/ --with-vorbis-libraries="${WORKSPACE}"/lib --with-vorbis-includes="${WORKSPACE}"/include/ --enable-static --disable-shared --disable-oggtest --disable-vorbistest --disable-examples --disable-spec
        execute make -j "$MJOBS"
        execute make install

        build_done "libtheora" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libtheora")
}

build_fdk_aac() {
    if ! $NONFREE_AND_GPL; then return; fi

    if build "fdk_aac" "${VER_FDK_AAC[0]}"; then
        download "https://sourceforge.net/projects/opencore-amr/files/fdk-aac/fdk-aac-$CURRENT_PACKAGE_VERSION.tar.gz/download?use_mirror=gigenet" "fdk-aac-$CURRENT_PACKAGE_VERSION.tar.gz"
        execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static --enable-pic
        execute make -j "$MJOBS"
        execute make install

        build_done "fdk_aac" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libfdk-aac")
}

build_soxr() {
    if build "soxr" "${VER_SOXR[0]}"; then
        download "https://sourceforge.net/projects/soxr/files/soxr-$CURRENT_PACKAGE_VERSION-Source.tar.xz/download?use_mirror=gigenet" "soxr-$CURRENT_PACKAGE_VERSION.tar.xz"

        mkdir build || exit
        cd build || exit
        execute cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DBUILD_SHARED_LIBS:bool=off -DWITH_OPENMP:bool=off -DBUILD_TESTS:bool=off -Wno-dev ..
        execute make -j "$MJOBS"
        execute make install

        build_done "soxr" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libsoxr")
}

build_twolame() {
    # Deliberately not licence-gated. ffmpeg 9.0 lists libtwolame in the plain
    # EXTERNAL_LIBRARY_LIST (configure line 2137), not in EXTERNAL_LIBRARY_GPL_LIST, and
    # TwoLAME itself is LGPL-2.1 - so the default LGPL build is allowed to have it, and it
    # is the only MP2 encoder with a real psychoacoustic model that ffmpeg can reach
    # (the native mp2 encoder has none).
    if build "twolame" "${VER_TWOLAME[0]}"; then
        download "https://github.com/njh/twolame/releases/download/$CURRENT_PACKAGE_VERSION/twolame-$CURRENT_PACKAGE_VERSION.tar.gz"

        # --disable-sndfile: libsndfile is wanted only by the "twolame" command line
        # frontend, never by the library, and this script has no libsndfile of its own.
        # Without the flag configure probes for it, and on a developer machine that
        # happens to have libsndfile-dev it would build and install a frontend binary
        # into $WORKSPACE/bin that nothing here ever uses. Saying no keeps the outcome
        # identical on every machine.
        #
        # No pre_c23_cflag needed, unlike xvidcore: TwoLAME is old, but it does not use
        # "bool"/"true"/"false" as identifiers, and it compiles clean under GCC 15's
        # -std=gnu23 default (verified on ubuntu:26.04, gcc 15.2.0, __STDC_VERSION__
        # 202311L). Adding the flag would only hide that.
        execute ./configure --prefix="${WORKSPACE}" --enable-static --disable-shared --disable-sndfile
        execute make -j "$MJOBS"
        execute make install

        build_done "twolame" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libtwolame")

    # NOTE on the link test: ffmpeg checks libtwolame with `require`, not pkg-config
    # (configure line 7452), so the installed twolame.pc is never consulted and there is
    # nothing to patch there. libtwolame.a pulls in cos/pow/log10/lrintf, and unlike
    # libmp3lame's line the libtwolame line does not append $libm_extralibs - the probe
    # only links "-ltwolame". It still succeeds because test_ld appends $extralibs, and
    # this script already passes --extra-libs="-ldl -lpthread -lm -lz". Do not remove
    # -lm from EXTRALIBS.
}
build_libmysofa() {
    if build "libmysofa" "${VER_LIBMYSOFA[0]}"; then
        download "https://github.com/hoene/libmysofa/archive/refs/tags/v$CURRENT_PACKAGE_VERSION.tar.gz" "libmysofa-$CURRENT_PACKAGE_VERSION.tar.gz"

        # BUILD_TESTS defaults to ON and does find_package(CUnit REQUIRED), so leaving it alone
        # fails configure outright on any host without CUnit. It also guards the mysofa2json
        # tool, which is the only thing here that is not the library.
        #
        # BUILD_SHARED_LIBS and BUILD_STATIC_LIBS are separate options rather than the usual
        # single switch, and both default to ON. Only the static one is wanted; the shared
        # target additionally installs an import archive named mysofa_shared, which is dead
        # weight in a static workspace.
        #
        # CMAKE_PREFIX_PATH points FindZLIB at the static libz.a that build_zlib already
        # installed, so libmysofa does not read the SOFA files' compressed HDF5 chunks through
        # a system zlib. Same reason as build_libgme.
        execute cmake -DCMAKE_PREFIX_PATH="${WORKSPACE}" -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIBS=ON -DBUILD_TESTS=OFF -B build/
        execute cmake --build build --target install -j "$MJOBS"

        build_done "libmysofa" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libmysofa")
}

build_rubberband() {
    # librubberband is in ffmpeg 9.0's EXTERNAL_LIBRARY_GPL_LIST (configure line 2036), so
    # --enable-librubberband implies --enable-gpl and must stay behind this script's flag.
    if ! $NONFREE_AND_GPL; then return; fi

    # meson is Rubber Band's only supported build system upstream (the Makefile.* files under
    # otherbuilds/ are hand-maintained one-offs for Xcode/MSVC and do not install a .pc). Its
    # meson.build asks for >= 0.53.0, far below MESON_MIN_VERSION, so unlike libplacebo the
    # bare presence check is enough - see build_dav1d for the same guard.
    if ! command_exists "meson"; then return; fi

    if build "rubberband" "${VER_RUBBERBAND[0]}"; then
        download "https://github.com/breakfastquay/rubberband/archive/refs/tags/v$CURRENT_PACKAGE_VERSION.tar.gz" "rubberband-$CURRENT_PACKAGE_VERSION.tar.gz"

        # src/common/mathmisc.h declares roundUp()/roundUpDiv() in terms of an unqualified
        # size_t but includes nothing that defines one. It only gets away with that by
        # accident: its sole include is sysutils.h, whose platform block picks the
        # "#elif defined(__GNUC__)" branch under clang (line 74) and so skips the stdlib.h
        # that the other branches pull in, leaving <math.h> at the bottom as the only
        # thing that ever supplied size_t transitively. Xcode 26's libc++ stopped leaking
        # it from <math.h>, so mathmisc.cpp fails with "unknown type name 'size_t'" and
        # takes the whole ninja run with it. stddef.h rather than <cstddef> because the
        # uses are unqualified and only the C header is guaranteed to declare ::size_t.
        # The replacement carries a literal backslash-newline, which is the one form of
        # multi-line replacement both GNU and BSD sed accept.
        apply_inline_patch src/common/mathmisc.h 's|^#include "sysutils.h"|#include "sysutils.h"\
#include <stddef.h>|'

        # Rubber Band needs an FFT and a resampler, and both options default to "auto", which is
        # where a stray host package would otherwise change what gets built. Pinning them keeps
        # this to zero new dependencies:
        #   -Dfft=builtin       - the alternatives are kissfft (vendored), fftw, sleef, vdsp and
        #                         ipp. fftw is the one to avoid: FFTW is GPL-only, so it would
        #                         drag a GPL-only .pc requirement into rubberband.pc on any host
        #                         that happens to have libfftw3-dev, and it is a package we do
        #                         not build. "auto" resolves to vdsp on macOS, which is free
        #                         (Accelerate is part of the OS) but writes a bare
        #                         "-framework Accelerate" into rubberband.pc; forcing builtin
        #                         keeps the two platforms byte-identical and the .pc portable.
        #   -Dresampler=builtin - the alternatives are libsamplerate, speex, libspeexdsp and ipp.
        #                         libsamplerate and libspeexdsp are packages this script does not
        #                         build; the builtin BQResampler is what upstream's own "auto"
        #                         picks and is the only one that supports time-varying pitch
        #                         shift without libsamplerate.
        # The five feature options are all "auto" upstream and must be turned off explicitly, not
        # left to autodetection, for two different reasons:
        #   - ladspa and lv2 are the dangerous pair. This script builds LV2 and LADSPA earlier in
        #     the audio block, so ladspa.h and lv2.h ARE in $WORKSPACE/include by the time we get
        #     here, and rubberband's meson.build builds those two targets as shared_library() -
        #     a .so in a prefix that is supposed to be static-only, and dead weight in an ffmpeg
        #     build that never loads them.
        #   - vamp needs the Vamp plugin SDK, cmdline needs libsndfile and tests needs Boost;
        #     none of the three is built here, and none produces anything ffmpeg links against.
        #   - jni pulls in a whole Java language pack via add_languages().
        # --default-library=static is required because upstream's default_options sets
        # default_library=both, which would install librubberband.so alongside the archive.
        execute meson setup build --prefix="${WORKSPACE}" --libdir="${WORKSPACE}"/lib \
            --buildtype=release --default-library=static \
            -Dfft=builtin -Dresampler=builtin \
            -Djni=disabled -Dladspa=disabled -Dlv2=disabled -Dvamp=disabled \
            -Dcmdline=disabled -Dtests=disabled
        execute ninja -C build -j "$MJOBS"
        execute ninja -C build install

        # meson never links the static library, so pkg.generate() emits a rubberband.pc whose
        # Libs is nothing but "-L${libdir} -lrubberband". Two things are missing from it and
        # both break ffmpeg's configure link test on GNU ld:
        #
        #   -lm       src/common/FFT.cpp and the R2/R3 stretchers call log/pow/cos/sinf/lrint.
        #             Without it: "undefined reference to symbol 'log@@GLIBC_2.29' ...
        #             libm.so.6: DSO missing from command line".
        #   C++ rt    the entire library is C++ and ffmpeg links with $CC, so operator new/delete
        #             and __gxx_personality_v0 go unresolved.
        #
        # ffmpeg does pass a trailing -lstdc++ of its own (configure line 7434), which covers the
        # C++ runtime on Linux but never covers -lm and is hardcoded to -lstdc++, so it is wrong
        # for macOS/libc++ users of the installed .pc. Fix the .pc itself, as build_libplacebo
        # and build_libvpl do. Appended rather than prepended because GNU ld resolves archives
        # left to right and -lrubberband must be seen first.
        RUBBERBAND_CXX_LIB="-lstdc++"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            RUBBERBAND_CXX_LIB="-lc++"
        fi
        apply_inline_patch "${WORKSPACE}/lib/pkgconfig/rubberband.pc" "s|^\(Libs:.*\)|\1 ${RUBBERBAND_CXX_LIB}|"
        apply_inline_patch "${WORKSPACE}/lib/pkgconfig/rubberband.pc" "s|^\(Libs:.*\)|\1 -lm|"

        build_done "rubberband" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-librubberband")

    # NOTE: deliberately not gated on --full-static. Nothing here is dlopen()ed, the .pc pulls in
    # no shared-only library, and the fully static link was verified to work - see the transcript.
}
build_libopenmpt() {
    # Deliberately not licence-gated. ffmpeg 9.0 lists libopenmpt in the plain
    # EXTERNAL_LIBRARY_LIST (configure line 2111), not in EXTERNAL_LIBRARY_GPL_LIST, and
    # libopenmpt is BSD-3-Clause, so the default LGPL build may have it. It provides the
    # libopenmpt demuxer, i.e. tracker modules (MOD/S3M/XM/IT/MPTM and ~40 more).
    if build "libopenmpt" "${VER_LIBOPENMPT[0]}"; then
        # Upstream publishes three source variants per release. The autotools one is what
        # upstream recommends on Unix and the only one that generates libopenmpt.pc, which
        # ffmpeg's pkg-config-only check needs. Its directory and file name carry a
        # "+release.autotools" suffix, so the URL and the local name are given separately -
        # that keeps $PACKAGES/libopenmpt-<version>/ consistent with every other package.
        download "https://lib.openmpt.org/files/libopenmpt/src/libopenmpt-$CURRENT_PACKAGE_VERSION+release.autotools.tar.gz" "libopenmpt-$CURRENT_PACKAGE_VERSION.tar.gz"

        # Only the module *parser* is wanted here; everything that plays or writes audio is
        # openmpt123's business, and every optional dependency below would be a new package
        # this script does not build:
        #   --disable-openmpt123  the command line player - the sole consumer of
        #                         portaudio/pulseaudio/SDL2/sndfile/flac. With it off,
        #                         configure never even probes libpulse.
        #   --disable-examples    sample programs, not installed as anything useful
        #   --disable-tests       a full test suite plus its test module corpus
        #   --disable-doxygen-doc doxygen is not a dependency of this script
        #   --without-mpg123      would be a new package; it only decodes MP3-compressed
        #                         samples inside MO3/IT files, a rare corner
        #   --without-portaudio --without-portaudiocpp --without-sndfile --without-flac
        #                         belt and braces, so a developer machine that happens to
        #                         have them installed still produces the same library
        # zlib, ogg, vorbis and vorbisfile are deliberately left enabled: this script
        # already builds all four, they are found through PKG_CONFIG_PATH, and they are
        # what lets libopenmpt unpack MO3 containers and their Vorbis-compressed samples.
        # If they were missing configure would silently carry on without them, so the
        # PACKAGE_BUILD_ORDER position below is what actually guarantees they are used.
        #
        # CXXFLAGS is overridden because autoconf's default is "-g -O2" and libopenmpt is
        # a large, template-heavy C++ tree: the debug info alone makes libopenmpt.a 279 MB
        # instead of 9 MB, all of it thrown away at link time. ${CXXFLAGS} is kept on the
        # end so the -fPIC that --full-static adds is not lost.
        execute ./configure --prefix="${WORKSPACE}" --enable-static --disable-shared \
            --disable-openmpt123 --disable-examples --disable-tests --disable-doxygen-doc \
            --without-mpg123 --without-portaudio --without-portaudiocpp --without-sndfile \
            --without-flac CXXFLAGS="-O2 ${CXXFLAGS}"
        execute make -j "$MJOBS"
        execute make install

        build_done "libopenmpt" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libopenmpt")

    # NOTE: no C++ runtime fixup on libopenmpt.pc, unlike build_libvpl and build_libplacebo.
    # The generated .pc does have an empty Libs.private, but ffmpeg supplies the runtime
    # itself - configure line 7413 passes "-lstdc++" as an extra lib to require_pkg_config
    # and then appends it to libopenmpt_extralibs for the real link. It lands after
    # -lopenmpt on the command line, which is the order GNU ld needs. Verified both ways:
    # the link test passes as ffmpeg issues it, and fails with 7331 undefined references to
    # operator new / __cxa_* if -lstdc++ is removed. -lstdc++ is also fine on macOS - Apple
    # clang accepts it and resolves it to libc++ (checked on the macOS 26.5 SDK).
    #
    # NOTE: deliberately not gated on --full-static either. Nothing here is dlopen()ed, and
    # the .pc never mentions -lgcc_s, so a fully static link has nothing to work around.
}
# Game Music Emu, for the libgme demuxer (chiptune/console music: NSF, SPC, VGM, GBS, ...).
# Not licence-gated: ffmpeg 9.0 lists "libgme" in the plain EXTERNAL_LIBRARY_LIST (configure
# line 2092), not in EXTERNAL_LIBRARY_GPL_LIST. That holds only for the default emulator set,
# see the GME_YM2612_EMU note below. Placed after zlib, which it links for VGZ/compressed input.
build_libgme() {
    if build "libgme" "${VER_LIBGME[0]}"; then
        download "https://github.com/libgme/game-music-emu/releases/download/$CURRENT_PACKAGE_VERSION/libgme-$CURRENT_PACKAGE_VERSION-src.tar.gz" "libgme-$CURRENT_PACKAGE_VERSION.tar.gz"

        # GME_BUILD_SHARED has its own default (ON) and is only seeded from BUILD_SHARED_LIBS
        # when that variable is defined, so both are set - BUILD_SHARED_LIBS alone would still
        # produce a .so. GME_BUILD_STATIC is already ON but is named so an upstream default
        # flip cannot silently drop libgme.a.
        #
        # GME_BUILD_EXAMPLES defaults to ON for a top-level build and adds the player/ and
        # demo/ subdirectories; player/ wants SDL. They are EXCLUDE_FROM_ALL so "make install"
        # would not build them, but the *configure* step still runs their find_package calls,
        # so it is turned off outright. GME_BUILD_TESTING/BUILD_TESTING likewise - the tree
        # include()s CTest at top level. Nothing here uses Unrar; that support was dropped
        # upstream before 0.6.x, so there is no switch left to disable.
        #
        # GME_YM2612_EMU is pinned to its default rather than left implicit because it is the
        # licence-relevant knob: "Nuked" and "GENS" are LGPL-2.1+, "MAME" is GPL-2+. Keeping
        # Nuked is what lets this function stay outside the $NONFREE_AND_GPL gate.
        #
        # GME_ZLIB (default ON) is what enables the compressed containers (VGZ). CMAKE_PREFIX_PATH
        # points find_package(ZLIB) at the static libz.a build_zlib already installed, so this
        # does not pick up a system zlib.
        execute cmake -DCMAKE_PREFIX_PATH="${WORKSPACE}" -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DGME_BUILD_SHARED=OFF -DGME_BUILD_STATIC=ON -DGME_BUILD_EXAMPLES=OFF -DGME_BUILD_TESTING=OFF -DBUILD_TESTING=OFF -DGME_YM2612_EMU=Nuked -DGME_ZLIB=ON -B build/
        execute cmake --build build --target install -j "$MJOBS"

        # Unlike vpl.pc and libvmaf.pc, libgme.pc *does* carry the C++ runtime: gme/CMakeLists.txt
        # copies CMAKE_CXX_IMPLICIT_LINK_LIBRARIES verbatim into Libs.private, which on GCC gives
        # "-lstdc++ -lm -lgcc_s -lgcc -lc -lgcc_s -lgcc" (and -lc++ on AppleClang). So no runtime
        # has to be appended - but -lgcc_s has to come out. It only ever exists as a shared
        # libgcc_s.so, and build-ffmpeg passes --pkg-config-flags="--static" to ffmpeg's configure,
        # so Libs.private lands on every link line: under --full-static the link dies with
        # "cannot find -lgcc_s ... have you installed the static version of the gcc_s library ?".
        # Stripping it is safe in both modes - libgcc_s only provides the unwinder, and libgme is
        # compiled -fno-exceptions -fno-rtti by its own CMakeLists, so nothing in the archive
        # unwinds. Applied unconditionally; on macOS the pattern simply does not match.
        apply_inline_patch "${WORKSPACE}/lib/pkgconfig/libgme.pc" "s| -lgcc_s||g"

        build_done "libgme" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libgme")
}
# Audio fingerprinting, for the chromaprint muxer. Not licence-gated: ffmpeg 9.0 lists
# "chromaprint" in the plain EXTERNAL_LIBRARY_LIST (configure line 2072), not in
# EXTERNAL_LIBRARY_GPL_LIST or any of the nonfree/version3 lists, and chromaprint itself is
# LGPL-2.1-or-later. Note the ffmpeg switch is --enable-chromaprint, not --enable-libchromaprint.
build_chromaprint() {
    if build "chromaprint" "${VER_CHROMAPRINT[0]}"; then
        download "https://github.com/acoustid/chromaprint/archive/refs/tags/v$CURRENT_PACKAGE_VERSION.tar.gz" "chromaprint-$CURRENT_PACKAGE_VERSION.tar.gz"

        # FFT_LIB is pinned instead of left to autodetection, and this is the whole point of
        # the block. Chromaprint's CMakeLists offers avtx, avfft, fftw3, fftw3f, kissfft and
        # vdsp; with FFT_LIB unset it runs find_package(FFmpeg) and prefers *ffmpeg's own*
        # libavcodec/libavutil. That is circular here - chromaprint is built before ffmpeg -
        # and on a host that happens to have libavcodec-dev installed it would silently link
        # this static library against the *system* ffmpeg instead. fftw3 would be a new
        # package. kissfft is the only backend that needs nothing: chromaprint vendors it at
        # src/3rdparty/kissfft and cmake/modules/FindKissFFT.cmake looks nowhere else
        # (NO_DEFAULT_PATH on ${CMAKE_SOURCE_DIR}/src/3rdparty/kissfft), so it compiles
        # kiss_fft.c/kiss_fftr.c straight into libchromaprint.a.
        #
        # vdsp (Accelerate) would also need no package on macOS, but is deliberately not used:
        # nothing adds "-framework Accelerate" to libchromaprint.pc, so ffmpeg's link test
        # would fail there. kissfft keeps macOS and Linux on the identical code path.
        #
        # AUDIO_PROCESSOR_LIB is pinned to a non-"swresample" value for the same
        # host-contamination reason: left empty it links libswresample if a system one is
        # found. USE_INTERNAL_AVRESAMPLE stays at its default ON, which is the bundled
        # resampler (src/avresample/resample2.c) chromaprint_start/chromaprint_feed use to
        # get to 11025 Hz - so dropping swresample costs nothing.
        #
        # BUILD_TESTS defaults to ON and pulls in the vendored googletest tree; BUILD_TOOLS
        # (fpcalc) is off by default but is named explicitly so an upstream flip cannot drag
        # in its extra dependencies.
        execute cmake -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DBUILD_TOOLS=OFF -DBUILD_TESTS=OFF -DFFT_LIB=kissfft -DAUDIO_PROCESSOR_LIB=none -B build/
        execute cmake --build build --target install -j "$MJOBS"

        # libchromaprint.pc.cmake hardcodes "Libs: -L${libdir} -lchromaprint" and has no
        # Libs.private at all, so the archive's C++ runtime and libm references are invisible
        # to pkg-config. ffmpeg link-tests chromaprint_get_version with $CC (configure line
        # 7311) and would fail on undefined operator new / __cxa_* (the library is C++) and on
        # sincos/sqrt (vendored kissfft is C but calls libm) - reported only as the useless
        # "chromaprint not found". -lm is required as well as the runtime: ffmpeg keeps its
        # own -lm in libm_extralibs and adds it per-library, never globally, so this check does
        # not get one for free. Appended to the end of Libs, not prepended - GNU ld is one-pass
        # and the runtime has to sit to the right of the -lchromaprint that needs it. Same
        # fixup as build_libvmaf, build_libplacebo and vpl.pc.
        CHROMAPRINT_CXX_LIB="-lstdc++"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            CHROMAPRINT_CXX_LIB="-lc++"
        fi
        apply_inline_patch "${WORKSPACE}/lib/pkgconfig/libchromaprint.pc" "s|^\(Libs:.*\)|\1 ${CHROMAPRINT_CXX_LIB} -lm|"

        build_done "chromaprint" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-chromaprint")

    # NOTE: not gated on --full-static. libchromaprint.a is self-contained (kissfft is
    # compiled in, nothing is dlopen()ed) and the patched .pc names only -lstdc++ and -lm,
    # never -lgcc_s, so "gcc -static" resolves everything - verified in the container.
}

# OpenAL Soft. ffmpeg 9.0 uses OpenAL for one thing only: the openal *input* device
# (openal_indev_deps="openal") for audio capture. There is no encoder, no filter and no
# outdev behind it. It sits in EXTERNAL_LIBRARY_LIST, not in EXTERNAL_LIBRARY_GPL_LIST, so
# it is deliberately not gated on $NONFREE_AND_GPL.
build_openal() {
    # Not built under --full-static. openal-soft never links its ALSA/PulseAudio/PipeWire
    # backend: with dlfcn.h present its ADD_BACKEND_LIBS macro expands to nothing and the
    # client library is dlopen()ed by soname on the first alcCaptureOpenDevice(). glibc
    # cannot dlopen() from a fully static binary - ld even warns about it - so the indev
    # would register and then fail to open any device. Same reasoning as build_vaapi and
    # build_libvpl.
    if [ -n "$LDEXEFLAGS" ]; then return; fi

    # On Linux, ALSA is the only backend here that can capture, and openal-soft compiles a
    # backend only when its headers are present at build time (find_package(ALSA)) - even
    # though it dlopen()s the library at run time. Without alsa/asoundlib.h the build
    # quietly produces a library whose backends are "OSS, WaveFile, Null", i.e. an openal
    # indev that cannot open a microphone on any current system. Probe for the development
    # package instead and skip, exactly as build_vaapi probes for libva. One ALSA backend
    # reaches every user: PulseAudio and PipeWire both provide an ALSA compatibility PCM.
    # macOS needs no probe - CoreAudio is always there.
    if [[ "$OSTYPE" == "linux-gnu" ]] && ! library_exists "alsa"; then return; fi

    if build "openal" "${VER_OPENAL[0]}"; then
        download "https://github.com/kcat/openal-soft/archive/refs/tags/$CURRENT_PACKAGE_VERSION.tar.gz" "openal-soft-$CURRENT_PACKAGE_VERSION.tar.gz"

        # Apple clang 17+ (and upstream clang 20+) support -Wfunction-effects, and
        # CMakeLists.txt promotes it to an error itself. coreaudio.cpp assigns two noexcept
        # lambdas to AudioUnit callback pointers and trips it, so the macOS build dies on
        # "attribute 'nonblocking' should not be added via type conversion". CXXFLAGS cannot
        # undo it - a target compile option is always appended after CMAKE_CXX_FLAGS - so
        # the -Werror= has to come out of the file. GCC does not know the warning, so this
        # matches nothing on Linux.
        apply_inline_patch "CMakeLists.txt" "s|-Werror=function-effects||"

        # CMakeLists.txt calls find_package(SDL3 QUIET) unconditionally at file scope, and
        # cmake searches its own install prefix - which is $WORKSPACE. A stale or partial
        # SDL3 package config left there turns that call into a fatal error even though the
        # SDL backends default to OFF, so the lookup is disabled outright.
        #
        # The PipeWire/PulseAudio/JACK/PortAudio backends are switched off explicitly rather
        # than left at their default ON: each one enables itself purely from whether its -dev
        # package happens to be installed on the build machine, which would make the contents
        # of the shipped binary depend on the build host. They would also be redundant - all
        # of them are reachable through the ALSA compatibility layer at run time.
        OPENAL_OPTIONS=("-DCMAKE_BUILD_TYPE=Release")
        if [[ "$OSTYPE" == "linux-gnu" ]]; then
            # The library_exists check above already established the headers are there;
            # this turns a find_package() miss into a build error rather than a silently
            # backend-less library.
            OPENAL_OPTIONS+=("-DALSOFT_REQUIRE_ALSA=ON")
        fi
        execute cmake -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DLIBTYPE=STATIC \
            -DCMAKE_DISABLE_FIND_PACKAGE_SDL3=ON \
            -DALSOFT_UTILS=OFF -DALSOFT_EXAMPLES=OFF -DALSOFT_TESTS=OFF \
            -DALSOFT_INSTALL_CONFIG=OFF -DALSOFT_INSTALL_HRTF_DATA=OFF \
            -DALSOFT_INSTALL_AMBDEC_PRESETS=OFF -DALSOFT_UPDATE_BUILD_VERSION=OFF \
            -DALSOFT_BACKEND_PIPEWIRE=OFF -DALSOFT_BACKEND_PULSEAUDIO=OFF \
            -DALSOFT_BACKEND_JACK=OFF -DALSOFT_BACKEND_PORTAUDIO=OFF \
            "${OPENAL_OPTIONS[@]}" -B build/
        execute cmake --build build --target install -j "$MJOBS"

        # openal-soft is C++ throughout, and its generated openal.pc lists -latomic -ldl -lm
        # in Libs.private but no C++ runtime: the LIBTYPE=STATIC branch of CMakeLists.txt
        # builds that string from ${LINKER_FLAGS} ${EXTRA_LIBS} ${MATH_LIB} only. ffmpeg
        # links with $CC, so configure's link test for alGetError dies on ~7000 undefined
        # operator new / std::__throw_* lines and reports nothing but "ERROR: openal not
        # found". Appended to Libs rather than Libs.private because GNU ld is one-pass and
        # the runtime has to sit to the right of the -lopenal that needs it - same fixup as
        # build_libplacebo and build_libvmaf.
        OPENAL_CXX_LIB="-lstdc++"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            OPENAL_CXX_LIB="-lc++"
        fi
        apply_inline_patch "${WORKSPACE}/lib/pkgconfig/openal.pc" "s|^\(Libs:.*\)|\1 ${OPENAL_CXX_LIB}|"

        build_done "openal" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-openal")

    # NOTE: nothing else is needed at configure time. At run time the openal indev calls
    # alcCaptureOpenDevice(), which dlopen()s libasound.so.2 from the user's machine; a
    # desktop without alsa-lib installed gets "Could not open device" from the indev but a
    # perfectly working binary otherwise.
}

# PulseAudio client library, for ffmpeg's pulse indev/outdev. Deliberately not built from
# source: upstream declares it with meson's shared_library() (src/pulse/meson.build:83), so
# --default-library=static is ignored and no libpulse.a is produced in any configuration -
# and vendoring a shared one into the throwaway workspace would only give the shipped binary
# a DT_NEEDED pointing at a directory that does not exist on the user's machine. Nothing
# would be gained either: libpulse is IPC glue that talks to a daemon on the machine running
# the binary, so the capability can never be baked in. Same situation, and therefore the same
# treatment, as build_vaapi below: probe the host for the development package and enable the
# flag only if it is installed. libpulse is in ffmpeg 9.0's plain EXTERNAL_LIBRARY_LIST and
# not in EXTERNAL_LIBRARY_GPL_LIST, so it is intentionally not gated on $NONFREE_AND_GPL.
build_libpulse() {
    if [[ ! "$OSTYPE" == "linux-gnu" ]]; then return; fi

    # Nothing to link against under --full-static: there is no libpulse.a on any system, and
    # ld says so outright ("have you installed the static version of the pulse library ?").
    if [ -n "$LDEXEFLAGS" ]; then return; fi

    # If the PulseAudio client SDK is installed, enable libpulse. The binary then carries a
    # DT_NEEDED for libpulse.so.0, which is the deliberate trade-off - as with vaapi and
    # libva.so.2 - and is why this is conditional rather than unconditional.
    if library_exists "libpulse"; then
        if build "libpulse" "${VER_LIBPULSE[0]}"; then
            # ffmpeg is configured with --pkg-config-flags=--static, so it also gets the
            # Libs.private of libpulse.pc: "-L${libdir}/pulseaudio -lpulsecommon-17.0". That
            # is a version-stamped *shared* helper installed outside the loader's search path
            # and reachable only through libpulse's own RUNPATH. Debian's GCC defaults to
            # --as-needed and drops it, but every toolchain that does not turns it into a
            # DT_NEEDED of the ffmpeg binary, which then refuses to start with
            # "libpulsecommon-17.0.so: cannot open shared object file". ffmpeg calls nothing
            # but the public pa_* API from libpulse.so.0, so a copy of the host's .pc with
            # Libs.private emptied goes into the workspace, which PKG_CONFIG_PATH searches
            # ahead of the system directories.
            execute cp "$(pkg-config --variable=pcfiledir libpulse)/libpulse.pc" "${WORKSPACE}/lib/pkgconfig/libpulse.pc"
            apply_inline_patch "${WORKSPACE}/lib/pkgconfig/libpulse.pc" "s|^Libs.private:.*|Libs.private:|"

            build_done "libpulse" "${VER_LIBPULSE[0]}"
        fi
        CONFIGURE_OPTIONS+=("--enable-libpulse")
    fi
}

# whisper.cpp, for the af_whisper filter (speech recognition / subtitles). Not licence-gated:
# ffmpeg 9.0 lists "whisper" in the plain EXTERNAL_LIBRARY_LIST (configure line 2162), not in
# EXTERNAL_LIBRARY_GPL_LIST or any nonfree list, and whisper.cpp is MIT. ffmpeg's check is
# pkg-config-only and link-tests a symbol:
#   enabled whisper && require_pkg_config whisper "whisper >= 1.7.5" whisper.h \
#       whisper_init_from_file_with_params                      (configure line 7465)
# so whisper.pc has to describe a *complete* link line - see the fixup below.
#
# This function lives here with the other audio libraries, but its PACKAGE_BUILD_ORDER entry
# is the last one in the list: the vulkan backend needs the Vulkan headers that the HWaccel
# section installs into the workspace, and that section is built after this one. The fragment
# a build_ function lives in has no influence on when it runs - the dispatch loop calls it by
# name - so the entry moved rather than the code.
#
# No model is downloaded or installed. af_whisper takes model=/path/to/ggml-model.bin at
# runtime and the models range from ~75 MB to ~3 GB; shipping one would be both a licence
# question and a build this script has no business making.
build_whisper() {
    # Opt-in. Without --whisper the package is not built and --enable-whisper is never added,
    # because exactly one ggml backend ends up compiled into the binary and only the user
    # knows which one fits the target machine. ggml can load backends at runtime instead
    # (GGML_BACKEND_DL), which would make one binary work everywhere, but that path is
    # unavailable here: ggml/src/CMakeLists.txt line 188 is a hard
    # "FATAL_ERROR: GGML_BACKEND_DL requires BUILD_SHARED_LIBS" and everything this script
    # produces is static.
    if [ -z "$WHISPER_BACKEND" ]; then return; fi

    # The backend/OS combinations were already rejected in 40-cli.sh; what is checked here is
    # the toolchain, which is the same "optional on hosts lacking a tool" gate the rest of the
    # script uses - except that it aborts instead of skipping, since the user asked for this
    # backend by name.
    if [ "$WHISPER_BACKEND" = "cuda" ] && ! command_exists "nvcc"; then
        echo "Error: --whisper=cuda needs nvcc (the CUDA toolkit) and it is not on PATH."
        exit 1
    fi
    if [ "$WHISPER_BACKEND" = "vulkan" ] && ! command_exists "glslc"; then
        # ggml/src/ggml-vulkan/CMakeLists.txt line 9 is find_package(Vulkan COMPONENTS glslc
        # REQUIRED): it compiles its compute shaders with glslc, which comes from shaderc and
        # not from the glslang this script builds (glslang installs glslangValidator, which
        # ggml does not accept). find_package(Vulkan) also needs the loader library itself,
        # so a Vulkan SDK / libvulkan-dev has to be installed - build_vulkan_headers only
        # puts the headers in the workspace.
        echo "Error: --whisper=vulkan needs glslc and a Vulkan loader (install the Vulkan SDK"
        echo "       or libvulkan-dev + glslc). Only the Vulkan *headers* are built here."
        exit 1
    fi

    # The backend is part of the version handed to build(), so it lands in the lockfile and
    # switching --whisper=metal to --whisper=cpu rebuilds instead of silently keeping the
    # previous backend: the lockfile is compared verbatim, and the pinned version alone does
    # not change when only the backend does. The download URL uses VER_WHISPER directly rather
    # than $CURRENT_PACKAGE_VERSION for the same reason - that now carries the suffix. The
    # checksum is unaffected, download() looks it up by package name.
    WHISPER_VERSION="${VER_WHISPER[0]}"
    if build "whisper" "$WHISPER_VERSION-$WHISPER_BACKEND"; then
        download "https://github.com/ggml-org/whisper.cpp/archive/refs/tags/v$WHISPER_VERSION.tar.gz" "whisper-$WHISPER_VERSION.tar.gz"

        # A previous run with a different backend left its own libggml-*.a in the workspace,
        # and the .pc fixup below reads that directory back to build the link line. Clear them
        # first so a cpu build cannot inherit -lggml-metal and a pile of frameworks from the
        # metal build that came before it.
        execute rm -f "${WORKSPACE}"/lib/libggml*.a "${WORKSPACE}"/lib/pkgconfig/whisper.pc

        # download() extracts over the existing package directory without removing it, so the
        # build/ tree from the previous backend survives with its CMakeCache.txt. Re-running
        # cmake would inherit that cache: the -D options below are re-applied, but ggml's
        # derived state (which BLAS was found, which backends registered) is not necessarily
        # re-derived. Cheaper to start clean than to reason about which parts are sticky.
        execute rm -rf build

        # One backend, selected explicitly in both directions. GGML_METAL and GGML_BLAS
        # default to ON on Apple (ggml/CMakeLists.txt lines 96-98), so --whisper=cpu has to
        # turn them off to actually get the portable CPU build it promises; on Linux both
        # default to OFF and the assignments are no-ops.
        #
        # GGML_NATIVE is left at its default (ON for a non-cross build), which is -march=native
        # on x86: the binary is then tuned for the machine that built it. That matches what
        # the rest of this script does - x264, x265 and dav1d all build with runtime detection
        # off a native baseline - and a user who wants a portable binary is building the cpu
        # backend on the oldest machine anyway.
        WHISPER_CMAKE_BACKEND=("-DGGML_METAL=OFF" "-DGGML_BLAS=OFF" "-DGGML_CUDA=OFF" "-DGGML_VULKAN=OFF")
        case $WHISPER_BACKEND in
        cpu) ;;
        metal)
            # GGML_METAL_EMBED_LIBRARY compiles default.metallib into the archive instead of
            # installing it next to the library and looking it up by bundle path at runtime.
            # It defaults to the value of GGML_METAL, but is named here because a static
            # ffmpeg binary has no bundle to find the .metallib in - without it the backend
            # initialises and then fails on the first filter invocation.
            WHISPER_CMAKE_BACKEND=("-DGGML_METAL=ON" "-DGGML_METAL_EMBED_LIBRARY=ON" "-DGGML_BLAS=ON" "-DGGML_CUDA=OFF" "-DGGML_VULKAN=OFF")
            ;;
        cuda)
            WHISPER_CMAKE_BACKEND=("-DGGML_METAL=OFF" "-DGGML_BLAS=OFF" "-DGGML_CUDA=ON" "-DGGML_VULKAN=OFF")
            ;;
        vulkan)
            WHISPER_CMAKE_BACKEND=("-DGGML_METAL=OFF" "-DGGML_BLAS=OFF" "-DGGML_CUDA=OFF" "-DGGML_VULKAN=ON")
            ;;
        esac

        # WHISPER_BUILD_TESTS/EXAMPLES/SERVER default to ON for a standalone build and pull in
        # SDL2, a test corpus and an HTTP server; only libwhisper.a and whisper.pc are wanted.
        # CMAKE_PREFIX_PATH points find_package at the workspace so the Vulkan headers built
        # here are the ones used.
        execute cmake -DCMAKE_PREFIX_PATH="${WORKSPACE}" -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_EXAMPLES=OFF -DWHISPER_BUILD_SERVER=OFF "${WHISPER_CMAKE_BACKEND[@]}" -B build/
        execute cmake --build build --target install -j "$MJOBS"

        # cmake/whisper.pc.in hardcodes "Libs: -L${libdir} -lggml  -lggml-base -lwhisper" and
        # has no Libs.private - a fixed string that mentions neither the backend archives nor
        # the C++ runtime nor the frameworks, whatever was actually built. A static build
        # installs one archive per backend (libggml-cpu.a, libggml-blas.a, libggml-metal.a,
        # ...), so ffmpeg's link test above fails on undefined ggml_backend_load_best and
        # std::__1::* symbols and reports only the useless "whisper not found". Same class of
        # fixup as libchromaprint.pc, libvmaf.pc, libplacebo.pc and vpl.pc.
        #
        # The archive list is read back from what the install actually produced rather than
        # derived from $WHISPER_BACKEND: ggml decides for itself which backends to build
        # (enabling GGML_VULKAN also builds ggml-cpu, and a future release may split an
        # archive out), and a hardcoded guess would silently go stale.
        #
        # Link order matters - GNU ld is one-pass, so a library has to sit to the left of
        # nothing it needs: libwhisper calls the ggml registry, the registry (libggml.a) calls
        # the backends, the backends call ggml-cpu's shared helpers, and everything bottoms
        # out in ggml-base.
        WHISPER_LIBS="-lwhisper"
        if [ -f "${WORKSPACE}/lib/libggml.a" ]; then
            WHISPER_LIBS+=" -lggml"
        fi
        for WHISPER_ARCHIVE in "${WORKSPACE}"/lib/libggml-*.a; do
            case "$WHISPER_ARCHIVE" in
            # ggml-cpu and ggml-base are emitted after the loop, in that order.
            *"libggml-cpu.a" | *"libggml-base.a") continue ;;
            # No match at all: bash leaves the pattern itself in the variable.
            *"*"*) continue ;;
            esac
            WHISPER_ARCHIVE="${WHISPER_ARCHIVE##*/}"
            WHISPER_ARCHIVE="${WHISPER_ARCHIVE#lib}"
            WHISPER_LIBS+=" -l${WHISPER_ARCHIVE%.a}"
        done
        if [ -f "${WORKSPACE}/lib/libggml-cpu.a" ]; then
            WHISPER_LIBS+=" -lggml-cpu"
        fi
        if [ -f "${WORKSPACE}/lib/libggml-base.a" ]; then
            WHISPER_LIBS+=" -lggml-base"
        fi

        # Everything the archives reference but no .pc mentions. The C++ runtime is required
        # in every configuration - whisper.cpp and all of ggml are C++ - and ffmpeg link-tests
        # with $CC, which does not add one.
        if [[ "$OSTYPE" == "darwin"* ]]; then
            WHISPER_LIBS+=" -lc++"
        else
            WHISPER_LIBS+=" -lstdc++"
        fi
        # Per-backend system libraries, again keyed on the archive that was installed rather
        # than on the requested backend:
        #   ggml-metal  links Foundation, Metal and MetalKit (ggml/src/ggml-metal/CMakeLists.txt)
        #   ggml-blas   links ${BLAS_LIBRARIES}, which on Apple is the Accelerate framework;
        #               GGML_BLAS is only ever enabled above on macOS, so no Linux BLAS
        #               (-lopenblas and friends) has to be guessed at here
        #   ggml-cpu    also links Accelerate on Apple, independently of GGML_BLAS: the
        #               separate GGML_ACCELERATE option (default ON) makes it call vDSP_*
        #               (ggml/src/ggml-cpu/CMakeLists.txt lines 60-69). Without this the
        #               --whisper=cpu link fails on _vDSP_vadd and friends even though no
        #               BLAS backend was built at all
        #   ggml-cuda   links CUDA::cudart, CUDA::cublas and the driver stub CUDA::cuda_driver
        #               (ggml/src/ggml-cuda/CMakeLists.txt lines 176-182). /usr/local/cuda is
        #               the same location build_nv_codec assumes
        #   ggml-vulkan links Vulkan::Vulkan, i.e. the loader
        if [ -f "${WORKSPACE}/lib/libggml-metal.a" ]; then
            WHISPER_LIBS+=" -framework Foundation -framework Metal -framework MetalKit"
        fi
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if [ -f "${WORKSPACE}/lib/libggml-blas.a" ] || [ -f "${WORKSPACE}/lib/libggml-cpu.a" ]; then
                WHISPER_LIBS+=" -framework Accelerate"
            fi
        fi
        if [ -f "${WORKSPACE}/lib/libggml-cuda.a" ]; then
            WHISPER_LIBS+=" -L/usr/local/cuda/lib64 -L/usr/local/cuda/lib64/stubs -lcudart -lcublas -lcuda"
        fi
        if [ -f "${WORKSPACE}/lib/libggml-vulkan.a" ]; then
            WHISPER_LIBS+=" -lvulkan"
        fi

        # Replace the whole Libs: line rather than appending to it: the hardcoded one has the
        # archives in the wrong order for a one-pass linker, so the -lggml it already contains
        # would still be resolved before the backends were seen.
        apply_inline_patch "${WORKSPACE}/lib/pkgconfig/whisper.pc" "s|^Libs:.*|Libs: -L\${libdir} ${WHISPER_LIBS}|"

        build_done "whisper" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-whisper")
}
