# shellcheck shell=bash
##
## HWaccel library
##

build_vulkan_headers() {
    if build "vulkan-headers" "${VER_VULKAN_HEADERS[0]}"; then
        download "https://github.com/KhronosGroup/Vulkan-Headers/archive/refs/tags/v$CURRENT_PACKAGE_VERSION.tar.gz" "Vulkan-Headers-$CURRENT_PACKAGE_VERSION.tar.gz"
        execute cmake -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -B build/
        cd build/ || exit
        execute make install
        build_done "vulkan-headers" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-vulkan")

    # NOTE: the ~25 *_vulkan filters, the ffv1_vulkan/prores_ks_vulkan encoders and the *_vulkan
    # hwaccels all carry "_deps=vulkan spirv_compiler", so they need a GLSL compiler on top of the
    # headers. There is no configure flag for it: with vulkan enabled, ffmpeg 9.0's configure walks
    # "for program in $glslc glslc glslang glslangValidator" and enables the internal
    # spirv_compiler feature for the first one it finds on PATH. The shaders are then translated to
    # SPIR-V at build time (.glsl -> .spv -> .spv.gz -> .spv.c -> .spv.o) and linked in, which is
    # why build_glslang below installs a host executable and links nothing into ffmpeg.
}

build_spirv_headers() {
    if build "spirv-headers" "${VER_SPIRV_HEADERS[0]}"; then
        download "https://github.com/KhronosGroup/SPIRV-Headers/archive/refs/tags/vulkan-sdk-$CURRENT_PACKAGE_VERSION.tar.gz" "SPIRV-Headers-$CURRENT_PACKAGE_VERSION.tar.gz"
        # Header-only: the install target just copies include/spirv/** into the prefix. The tests
        # pull in a C/C++ toolchain check we have no use for, so they stay off.
        execute cmake -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DSPIRV_HEADERS_ENABLE_TESTS=OFF -B build/
        execute cmake --build build --target install
        build_done "spirv-headers" "$CURRENT_PACKAGE_VERSION"
    fi

    # NOTE: no --enable- flag exists for this. configure probes
    # "spirv-headers/spirv.h" and then "spirv/unified1/spirv.h"; this install provides the latter,
    # which is what switches on swscale's SPIR-V backend. Missing headers are only a warning
    # ("spirv-headers not found, swscale SPIR-V backend unavailable"), so a failure here is silent
    # in the ffmpeg configure output - hence the explicit package instead of hoping for a system copy.
}

build_spirv_tools() {
    if build "spirv-tools" "${VER_SPIRV_TOOLS[0]}"; then
        download "https://github.com/KhronosGroup/SPIRV-Tools/archive/refs/tags/vulkan-sdk-$CURRENT_PACKAGE_VERSION.tar.gz" "SPIRV-Tools-$CURRENT_PACKAGE_VERSION.tar.gz"
        # Only built to give glslang its SPIR-V optimizer, which is what makes glslang's -Os/-Od
        # work - see build_glslang. SPIRV-Tools wants the SPIRV-Headers *source* tree rather than an
        # installed prefix, so this points at what build_spirv_headers above already extracted;
        # both are pinned to the same vulkan-sdk tag so the grammar tables match. The command line
        # tools and the test suite are not needed, and SPIRV_WERROR=OFF keeps a newer host compiler's
        # fresh warnings from turning into hard errors. Needs python3 to generate its tables.
        execute cmake -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DCMAKE_BUILD_TYPE=Release -DSPIRV-Headers_SOURCE_DIR="$PACKAGES/SPIRV-Headers-${VER_SPIRV_HEADERS[0]}" -DSPIRV_SKIP_TESTS=ON -DSPIRV_SKIP_EXECUTABLES=ON -DSPIRV_WERROR=OFF -DBUILD_SHARED_LIBS=OFF -B build/
        execute cmake --build build --target install -j "$MJOBS"
        build_done "spirv-tools" "$CURRENT_PACKAGE_VERSION"
    fi
}

build_glslang() {
    if build "glslang" "${VER_GLSLANG[0]}"; then
        download "https://github.com/KhronosGroup/glslang/archive/refs/tags/$CURRENT_PACKAGE_VERSION.tar.gz" "glslang-$CURRENT_PACKAGE_VERSION.tar.gz"
        # This is a host build tool only - ffmpeg 9.0 links no glslang library, it just runs the
        # installed glslangValidator during "make". Hence:
        #   ENABLE_OPT=1        the SPIR-V optimizer is what implements glslang's -Os and -Od, and
        #                       configure appends -Os to GLSLCFLAGS for an --enable-small build (so
        #                       for this script's --small flag). Without it the probe still passes -
        #                       check_glslc compiles its test shader before the -Os is appended - and
        #                       the build then dies much later on the first .glsl. So the optimizer
        #                       is not optional here, it is what keeps --small working.
        #   ALLOW_EXTERNAL_..   without it glslang only accepts a SPIRV-Tools checkout vendored under
        #                       External/ by its update_glslang_sources.py, which needs network access
        #                       at build time. This makes it find_package() the copy that
        #                       build_spirv_tools installed into WORKSPACE instead. Upstream calls the
        #                       combination unsupported unless the commit matches known_good.json; it
        #                       does here, both packages are pinned to the same vulkan-sdk tag.
        #   ENABLE_HLSL=OFF     the HLSL front-end is deprecated upstream and warns during cmake;
        #                       ffmpeg only ever feeds it GLSL.
        #   GLSLANG_TESTS=OFF   the test suite additionally wants gtest.
        #   BUILD_EXTERNAL=OFF  do not descend into External/, which is empty in the release tarball.
        # The build needs python3, which the meson/ninja bootstrap already requires.
        execute cmake -DCMAKE_PREFIX_PATH="${WORKSPACE}" -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DCMAKE_BUILD_TYPE=Release -DENABLE_OPT=1 -DALLOW_EXTERNAL_SPIRV_TOOLS=ON -DENABLE_HLSL=OFF -DGLSLANG_TESTS=OFF -DBUILD_SHARED_LIBS=OFF -DBUILD_EXTERNAL=OFF -B build/
        execute cmake --build build --target install -j "$MJOBS"
        build_done "glslang" "$CURRENT_PACKAGE_VERSION"
    fi

    # NOTE: install puts "glslang" plus a "glslangValidator" symlink into $WORKSPACE/bin, which is
    # already at the front of PATH, so ffmpeg's configure probe finds it without any flag. The
    # static libs and headers it also installs are unused - ffmpeg 9.0 has no --enable-libglslang.
    # build_libplacebo below is the one consumer that does link them.
}

vendor_libplacebo_submodule() {
    # vendor_libplacebo_submodule <3rdparty-dir> <url> <sha256> <tarball-name>
    # Drops a pinned tarball into one of the empty 3rdparty/ submodule directories of the
    # libplacebo source tree the caller is currently sitting in. These are extra downloads inside a
    # single package, so they cannot go through download() - that one derives its checksum from
    # CURRENT_PACKAGE_NAME and would look up libplacebo's. Same reason build_vid_stab calls
    # download_with_retries directly for its patch.
    if ! download_with_retries "$2" "$PACKAGES/$4" "$3"; then
        echo "Failed to download $2" >&2
        exit 1
    fi

    execute tar -xf "$PACKAGES/$4" -C "3rdparty/$1" --strip-components 1
}

# Placed after vulkan_headers/spirv_tools/glslang because it links all three: ffmpeg 9.0 has
# libplacebo_filter_deps="libplacebo vulkan" (configure line 4212), and libplacebo itself needs a
# GLSL compiler for its Vulkan backend, which is the glslang the three packages above produce.
build_libplacebo() {
    # meson is the only build system libplacebo has, and glsl_preproc (see below) needs python3.
    if ! command_exists "python3"; then return; fi
    if ! command_exists "meson"; then return; fi
    # Unlike every other meson package here, libplacebo needs a specific meson version -
    # see MESON_MIN_VERSION. build_meson_and_ninja has already tried to get one. Checked
    # here rather than left to meson so the outcome is a skipped optional filter with an
    # explanation, not "ERROR: Meson version is 0.61.2 but project requires >=0.63" three
    # quarters of the way through a forty minute build.
    if ! meson_is_current; then
        echo "Skipping libplacebo: it needs meson ${MESON_MIN_VERSION} or newer, and this is meson $(meson_version)."
        return
    fi

    if build "libplacebo" "${VER_LIBPLACEBO[0]}"; then
        download "https://github.com/haasn/libplacebo/archive/refs/tags/v$CURRENT_PACKAGE_VERSION.tar.gz" "libplacebo-$CURRENT_PACKAGE_VERSION.tar.gz"

        # libplacebo keeps six git submodules under 3rdparty/, and neither the GitHub tag archive
        # nor code.videolan.org publishes a tarball that bundles them, so the extracted tree has six
        # empty directories. There are no meson wraps at all (no subprojects/ directory), so nothing
        # is fetched during "meson setup" and the only question is which of the six actually matter:
        #
        #   jinja + markupsafe  needed unconditionally. tools/glsl_preproc/templates.py does a plain
        #                       "import jinja2", and meson puts 3rdparty/{jinja,markupsafe}/src on
        #                       PYTHONPATH for it. Both are pure Python, so extracting the source
        #                       tarball is the whole "build" - and it avoids a pip install, which
        #                       fails on PEP 668 distros.
        #   fast_float          src/convert.cc uses std::from_chars for floats and static_asserts if
        #                       <fast_float/fast_float.h> is missing. libc++ only grew that overload
        #                       very recently, so the header is vendored rather than gambled on.
        #   Vulkan-Headers      symlinked to what build_vulkan_headers already extracted instead of
        #                       downloaded again. src/vulkan/meson.build prefers 3rdparty over the
        #                       system headers and then forces registry/vk.xml from the same tree,
        #                       which is what keeps utils_gen.py's generated enum tables in sync with
        #                       the headers ffmpeg is compiled against. Same trick build_spirv_tools
        #                       uses with the SPIRV-Headers source tree.
        #   glad                only used by the OpenGL backend, which -Dopengl=disabled turns off.
        #                       That also removes the reason for the glad code generator, and with it
        #                       glad's own jinja2 dependency.
        #   nuklear             only used by the demo programs, which -Ddemos=false turns off.
        # jinja and markupsafe tag "X.Y.Z", fast_float tags "vX.Y.Z".
        vendor_libplacebo_submodule jinja \
            "https://github.com/pallets/jinja/archive/refs/tags/${VER_LIBPLACEBO_JINJA[0]}.tar.gz" \
            "${VER_LIBPLACEBO_JINJA[1]}" "libplacebo-jinja-${VER_LIBPLACEBO_JINJA[0]}.tar.gz"
        vendor_libplacebo_submodule markupsafe \
            "https://github.com/pallets/markupsafe/archive/refs/tags/${VER_LIBPLACEBO_MARKUPSAFE[0]}.tar.gz" \
            "${VER_LIBPLACEBO_MARKUPSAFE[1]}" "libplacebo-markupsafe-${VER_LIBPLACEBO_MARKUPSAFE[0]}.tar.gz"
        vendor_libplacebo_submodule fast_float \
            "https://github.com/fastfloat/fast_float/archive/refs/tags/v${VER_LIBPLACEBO_FAST_FLOAT[0]}.tar.gz" \
            "${VER_LIBPLACEBO_FAST_FLOAT[1]}" "libplacebo-fast_float-${VER_LIBPLACEBO_FAST_FLOAT[0]}.tar.gz"

        execute rmdir 3rdparty/Vulkan-Headers
        execute ln -s "$PACKAGES/Vulkan-Headers-${VER_VULKAN_HEADERS[0]}" 3rdparty/Vulkan-Headers

        # Upstream bug: src/glsl/meson.build passes the -Dvulkan-sdk lib directory as find_library's
        # "dirs" for SPIRV, MachineIndependent, OSDependent, GenericCodeGen and the two SPIRV-Tools,
        # but forgets it for glslang and glslang-default-resource-limits. A static find_library()
        # searches for the archive file itself and honours nothing but "dirs" - not -L, not
        # LIBRARY_PATH - so those two silently come out "not found". glslang 15 moved most of the
        # code out of libSPIRV.a (608 bytes here) into libglslang.a, and GetDefaultResources() has
        # always lived in glslang-default-resource-limits, so the resulting libplacebo.pc links
        # neither and ffmpeg dies with hundreds of undefined glslang:: symbols at LINK time - long
        # after its configure has happily accepted the package. Add the missing "dirs".
        apply_inline_patch src/glsl/meson.build "s|cxx.find_library('glslang-default-resource-limits', required: false)|cxx.find_library('glslang-default-resource-limits', required: false, static: get_option('prefer_static'), dirs: [get_option('vulkan-sdk') / 'lib'])|"
        apply_inline_patch src/glsl/meson.build "s|cxx.find_library('glslang', required: required, static: static)|cxx.find_library('glslang', required: required, static: static, dirs: vulkan_lib_dirs)|"

        # Second upstream bug, same list: it names SPIRV-Tools before SPIRV-Tools-opt, and meson
        # writes glslang_deps into libplacebo.pc in exactly that order. SPIRV-Tools-opt references
        # spvtools::SpirvTools, which lives in SPIRV-Tools, so with GNU ld - one pass, left to right,
        # an archive only satisfies references seen *before* it - the whole optimizer comes out
        # undefined and ffmpeg's require_pkg_config probe fails its link step. It reports only
        # "libplacebo >= 7.351.0 not found using pkg-config", which looks like a missing .pc rather
        # than a link error. Apple's ld64 resolves archives iteratively and does not care about the
        # order, which is why this is invisible on macOS. Swap the two, via a placeholder so that the
        # two single-line substitutions cannot collide.
        apply_inline_patch src/glsl/meson.build "s|'SPIRV-Tools-opt',|'SPIRV-Tools-opt-swapped',|; s|'SPIRV-Tools',|'SPIRV-Tools-opt',|; s|'SPIRV-Tools-opt-swapped',|'SPIRV-Tools',|"

        # -Dvulkan-sdk points the glslang lookup above at $WORKSPACE/lib; the -I is what lets it find
        # glslang/build_info.h, since CFLAGS is not exported for meson to pick up.
        # -Dvk-proc-addr=disabled matters on Linux: a host with libvulkan-dev installed would
        # otherwise put -lvulkan into libplacebo.pc, and there is no libvulkan.a to satisfy it in
        # this static link. ffmpeg's own Vulkan support dlopen()s the loader rather than linking it,
        # so this keeps the two consistent. The tradeoff is real though, and worth knowing:
        # vf_libplacebo has two init paths (vf_libplacebo.c init_vulkan). Given a Vulkan hwdevice it
        # calls pl_vulkan_import and passes ffmpeg's own hwctx->get_proc_addr, which works fine here.
        # With no hwdevice it calls pl_vulkan_create, which needs libplacebo to carry its own
        # vkGetInstanceProcAddr - that path fails with "libplacebo built without linking against this
        # function". So the filter must be used as
        #   ffmpeg -init_hw_device vulkan -vf libplacebo=...
        # and a bare "-vf libplacebo" will not initialise a device.
        # -Dshaderc=disabled because glslang is already built here; shaderc is upstream's preferred
        # backend and would win the "auto" race, but it vendors glslang + SPIRV-Tools + SPIRV-Headers
        # again and would be a fourth copy of the same code.
        # -Dxxhash / -Dlibdovi / -Dunwind are disabled rather than left on "auto" so the result does
        # not silently depend on what happens to be installed on the build host.
        execute meson setup build --prefix="${WORKSPACE}" --libdir="${WORKSPACE}"/lib --buildtype=release --default-library=static \
            -Dprefer_static=true -Ddemos=false -Dtests=false -Dbench=false \
            -Dvulkan=enabled -Dvk-proc-addr=disabled -Dvulkan-sdk="${WORKSPACE}" \
            -Dopengl=disabled -Dgl-proc-addr=disabled -Dd3d11=disabled \
            -Dglslang=enabled -Dshaderc=disabled -Dlcms=enabled \
            -Dlibdovi=disabled -Dunwind=disabled -Dxxhash=disabled \
            -Dc_args="-I${WORKSPACE}/include" -Dcpp_args="-I${WORKSPACE}/include"
        execute ninja -C build -j "$MJOBS"
        execute ninja -C build install

        # meson resolved the glslang libraries with find_library(), which yields absolute archive
        # paths, and writes them into Libs: verbatim - "/…/lib/libglslang.a" rather than "-lglslang".
        # That breaks ffmpeg's configure on any GNU ld platform. ffmpeg's test_ld splits the flags it
        # is given: entries starting with -l are appended AFTER the test object, everything else is
        # treated as a compiler flag and hoisted BEFORE it. So the absolute archive paths all end up
        # to the left of -lplacebo:
        #
        #   gcc … libglslang.a … libSPIRV-Tools.a -o test test.o -lplacebo -lm -lstdc++ …
        #
        # GNU ld is one-pass: at the point it reads libglslang.a nothing has referenced any glslang
        # symbol yet, so every member is discarded; -lplacebo then pulls in glsl_glslang.cc.o and its
        # references can no longer be satisfied. configure reports only the generic "libplacebo >=
        # 7.351.0 not found using pkg-config", which points at pkg-config rather than at the link.
        # Rewriting the archive paths into -l form keeps them on the right-hand side of the test
        # object and in their original relative order, which is also why the SPIRV-Tools-opt/
        # SPIRV-Tools swap above still matters. Invisible on macOS: ld64 resolves archives
        # iteratively, so it does not care where they sit or in what order.
        apply_inline_patch "${WORKSPACE}/lib/pkgconfig/libplacebo.pc" "s|${WORKSPACE}/lib/lib\([A-Za-z0-9_.+-]*\)\.a|-l\1|g"

        # libplacebo (convert.cc, glslang.cc) and all of glslang are C++, but meson never links the
        # static library, so it has no idea a C++ runtime is involved and generates a libplacebo.pc
        # without one. ffmpeg links with $CC, so operator new and __gxx_personality_v0 would go
        # unresolved when it pulls glsl_glslang.cc.o out of the archive. Appended to Libs rather than
        # prepended because GNU ld resolves archives left to right, and openh264.pc does the same.
        LIBPLACEBO_CXX_LIB="-lstdc++"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            LIBPLACEBO_CXX_LIB="-lc++"
        fi
        apply_inline_patch "${WORKSPACE}/lib/pkgconfig/libplacebo.pc" "s|^\(Libs:.*\)|\1 ${LIBPLACEBO_CXX_LIB}|"

        build_done "libplacebo" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libplacebo")

    # NOTE: deliberately not gated on --full-static. Unlike x265.pc and srt.pc the generated
    # libplacebo.pc never mentions -lgcc_s, and unlike frei0r/ladspa nothing here is dlopen()ed at
    # runtime, so a fully static link has nothing to work around.
}

build_nv_codec() {
    if [[ ! "$OSTYPE" == "linux-gnu" ]]; then return; fi

    if command_exists "nvcc"; then
        if build "nv-codec" "${VER_NV_CODEC[0]}"; then
            download "https://github.com/FFmpeg/nv-codec-headers/releases/download/n$CURRENT_PACKAGE_VERSION/nv-codec-headers-$CURRENT_PACKAGE_VERSION.tar.gz"
            execute make PREFIX="${WORKSPACE}"
            execute make PREFIX="${WORKSPACE}" install
            build_done "nv-codec" "$CURRENT_PACKAGE_VERSION"
        fi
        CFLAGS+=" -I/usr/local/cuda/include"
        LDFLAGS+=" -L/usr/local/cuda/lib64"
        CONFIGURE_OPTIONS+=("--enable-cuda-nvcc" "--enable-cuvid" "--enable-nvdec" "--enable-nvenc" "--enable-cuda-llvm" "--enable-ffnvcodec")

        # if [ -z "$LDEXEFLAGS" ]; then
        #   CONFIGURE_OPTIONS+=("--enable-libnpp") # Only libnpp cannot be statically linked.
        # fi

        if [ -z "$CUDA_COMPUTE_CAPABILITY" ]; then
            # Note that multi-architecture builds are not supported in ffmpeg
            # see https://patchwork.ffmpeg.org/comment/62905/
            # CUDA 13 dropped Maxwell/Pascal/Volta, so compute_52 no longer
            # compiles there; Turing (75) is the oldest arch it still accepts.
            NVCC_MAJOR_VERSION=$(nvcc --version | grep -oE 'release [0-9]+' | awk '{print $2}')
            if [ -n "$NVCC_MAJOR_VERSION" ] && [ "$NVCC_MAJOR_VERSION" -ge 13 ]; then
                CUDA_COMPUTE_CAPABILITY_FALLBACK=75
            else
                CUDA_COMPUTE_CAPABILITY_FALLBACK=52
            fi

            # Prefer the capability of the GPU actually in this machine over the fallback: a
            # fallback that predates the card leaves its newest hardware decoders unusable, which
            # is what kept av1_cuvid off Blackwell (compute_120). nvidia-smi reports it as "12.0",
            # and only from driver 418 on, so an empty or unparsable answer just falls through.
            CUDA_COMPUTE_CAPABILITY=$(nvidia_gpu_compute_capability)
            if [ -z "$CUDA_COMPUTE_CAPABILITY" ] || ! nvcc_supports_compute_capability "$CUDA_COMPUTE_CAPABILITY"; then
                # An unsupported card is either older than this CUDA toolkit (nvcc refuses the
                # arch) or newer than it (nvcc has never heard of it). Neither is fixable here,
                # so build the fallback and let the user override the variable.
                if [ -n "$CUDA_COMPUTE_CAPABILITY" ]; then
                    echo "nvcc does not support compute_$CUDA_COMPUTE_CAPABILITY; building for compute_$CUDA_COMPUTE_CAPABILITY_FALLBACK instead."
                    echo "Set CUDA_COMPUTE_CAPABILITY yourself, or install a CUDA toolkit that matches the GPU."
                fi
                CUDA_COMPUTE_CAPABILITY=$CUDA_COMPUTE_CAPABILITY_FALLBACK
            fi
            export CUDA_COMPUTE_CAPABILITY
        fi
        CONFIGURE_OPTIONS+=("--nvccflags=-gencode arch=compute_$CUDA_COMPUTE_CAPABILITY,code=sm_$CUDA_COMPUTE_CAPABILITY -O2")
    else
        CONFIGURE_OPTIONS+=("--disable-ffnvcodec")
    fi
}

build_vaapi() {
    if [[ ! "$OSTYPE" == "linux-gnu" ]]; then return; fi

    # Vaapi doesn't work well with static links FFmpeg.
    if [ -z "$LDEXEFLAGS" ]; then
        # If the libva development SDK is installed, enable vaapi.
        if library_exists "libva"; then
            if build "vaapi" "${VER_VAAPI[0]}"; then
                build_done "vaapi" "${VER_VAAPI[0]}"
            fi
            CONFIGURE_OPTIONS+=("--enable-vaapi")
        fi
    fi
}

build_amf() {
    if [[ ! "$OSTYPE" == "linux-gnu" ]]; then return; fi

    if build "amf" "${VER_AMF[0]}"; then
        download "https://github.com/GPUOpen-LibrariesAndSDKs/AMF/archive/refs/tags/v$CURRENT_PACKAGE_VERSION.tar.gz" "AMF-$CURRENT_PACKAGE_VERSION.tar.gz" "AMF-$CURRENT_PACKAGE_VERSION"
        execute rm -rf "${WORKSPACE}/include/AMF"
        execute mkdir -p "${WORKSPACE}/include/AMF"
        execute cp -r "${PACKAGES}/AMF-$CURRENT_PACKAGE_VERSION/AMF-$CURRENT_PACKAGE_VERSION/amf/public/include/"* "${WORKSPACE}/include/AMF/"
        build_done "amf" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-amf")
}

# Intel Quick Sync Video. Placed after build_vaapi because that is the child device
# hwcontext_qsv.c picks on Linux - see the runtime note at the end of this function.
build_libvpl() {
    if [[ ! "$OSTYPE" == "linux-gnu" ]]; then return; fi

    # QSV is Intel-iGPU-only and upstream ships no Apple or ARM support: the dispatcher's
    # platform branch is _WIN32/__linux__ with nothing else, and the sources do not compile
    # on macOS at all. x86_64 is the only combination that means anything here.
    if [[ "$(uname -m)" != "x86_64" ]]; then return; fi

    # Not built under --full-static. The dispatcher does not implement any codec itself; it
    # dlopen()s a separately installed runtime (libmfx-gen.so, from intel/vpl-gpu-rt) at
    # MFXLoad() time - three call sites in mfx_dispatcher_vpl_loader.cpp and mfxloader.cpp,
    # with no link-time alternative. A fully static glibc binary cannot dlopen reliably, so
    # enabling it there would register every *_qsv codec and then fail at device init. Same
    # reasoning as build_vaapi above, which skips itself on the same condition.
    if [ -n "$LDEXEFLAGS" ]; then return; fi

    if build "libvpl" "${VER_LIBVPL[0]}"; then
        download "https://github.com/intel/libvpl/archive/refs/tags/v$CURRENT_PACKAGE_VERSION.tar.gz" "libvpl-$CURRENT_PACKAGE_VERSION.tar.gz"
        # INSTALL_DEV stays at its default ON - it is what installs vpl.pc, and ffmpeg's
        # check is pkg-config-only with no fallback, so turning it off would break the
        # detection outright. INSTALL_EXAMPLES defaults to ON and only copies example
        # *source* into share/vpl, so it is switched off. There is no dispatcher-only
        # toggle to set: the runtime lives in a different repository, and the command line
        # tools moved out to intel/libvpl-tools, so this tree is dispatcher plus headers.
        #
        # MFX_MODULES_DIR is the runtime search directory compiled into the dispatcher. It
        # defaults to this build's own libdir, i.e. the throwaway workspace, where no
        # runtime will ever be installed. Pointed at the distribution's multiarch libdir
        # instead so a system libmfx-gen is found without the user setting
        # ONEVPL_SEARCH_PATH or LD_LIBRARY_PATH.
        execute cmake -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF -DBUILD_EXAMPLES=OFF -DINSTALL_EXAMPLES=OFF -DMFX_MODULES_DIR=/usr/lib/x86_64-linux-gnu -B build/
        execute cmake --build build --target install -j "$MJOBS"

        # The dispatcher is entirely C++, but the generated vpl.pc lists neither -lstdc++
        # nor anything in Libs.private: libvpl/CMakeLists.txt builds its dependent-libs
        # string from a CXX_LIB variable that is never defined anywhere in the tree, so it
        # expands to nothing. Without this the very first thing to notice is ffmpeg's own
        # configure, which link-tests MFXLoad and dies with "libvpl >= 2.6 not found" on a
        # wall of undefined operator new / __cxa_* symbols. Appended to Libs rather than
        # Libs.private because the .pc has no Libs.private line to append to.
        apply_inline_patch "${WORKSPACE}/lib/pkgconfig/vpl.pc" "s|^\(Libs:.*\)|\1 -lstdc++|"

        build_done "libvpl" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libvpl")

    # NOTE: deliberately not paired with --enable-libmfx. ffmpeg 9.0 refuses both at once
    # ("ERROR: can not use libmfx and libvpl together"), and libmfx is the deprecated path -
    # its check is pinned to "libmfx >= 1.28 libmfx < 2.0" and it cannot do av1_qsv encode.
    # Passing --enable-libvpl sets ffmpeg's internal libmfx switch anyway, which is what the
    # h264_qsv/hevc_qsv/vpp_qsv components hang off, so nothing is lost.
    #
    # NOTE: nothing else is required at configure time - qsv_deps is just libmfx. At runtime
    # it is not standalone: hwcontext_qsv.c chooses its child device purely from compile-time
    # config and on a non-Windows build only CONFIG_VAAPI is left, so an actual QSV session
    # additionally needs the vaapi that build_vaapi enables (which in turn needs the libva
    # development headers present when this script runs) plus Intel's iHD driver installed on
    # the machine that runs the binary. Without those the codecs are registered but
    # av_hwdevice_ctx_create(QSV) returns ENOSYS.
}

build_opencl_headers() {
    if [[ ! "$OSTYPE" == "linux-gnu" ]]; then return; fi

    if build "opencl-headers" "${VER_OPENCL_HEADERS[0]}"; then
        download "https://github.com/KhronosGroup/OpenCL-Headers/archive/refs/tags/v$CURRENT_PACKAGE_VERSION.tar.gz" "OpenCL-Headers-$CURRENT_PACKAGE_VERSION.tar.gz"
        execute cmake -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -B build/
        execute cmake --build build --target install
        build_done "opencl-headers" "$CURRENT_PACKAGE_VERSION"
    fi
}

build_opencl_icd_loader() {
    if [[ ! "$OSTYPE" == "linux-gnu" ]]; then return; fi

    if build "opencl-icd-loader" "${VER_OPENCL_ICD_LOADER[0]}"; then
        download "https://github.com/KhronosGroup/OpenCL-ICD-Loader/archive/refs/tags/v$CURRENT_PACKAGE_VERSION.tar.gz" "OpenCL-ICD-Loader-$CURRENT_PACKAGE_VERSION.tar.gz"
        # the test suite links the static, non-PIC libOpenCL.a into a shared module, which fails
        # to relocate. ffmpeg only needs the library, so do not build the tests at all.
        execute cmake -DCMAKE_PREFIX_PATH="${WORKSPACE}" -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DENABLE_SHARED=OFF -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DOPENCL_ICD_LOADER_BUILD_TESTING=OFF -B build/
        execute cmake --build build --target install
        build_done "opencl-icd-loader" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-opencl")
}
