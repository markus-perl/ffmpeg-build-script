#!/bin/bash

# HOMEPAGE: https://github.com/markus-perl/ffmpeg-build-script
# LICENSE: https://github.com/markus-perl/ffmpeg-build-script/blob/master/LICENSE

PROGNAME=$(basename "$0")
FFMPEG_VERSION=4.4
SCRIPT_VERSION=1.33
CWD=$(pwd)
PACKAGES="$CWD/packages"
WORKSPACE="$CWD/workspace"
CFLAGS="-I$WORKSPACE/include"
LDFLAGS="-L$WORKSPACE/lib"
LDEXEFLAGS=""
EXTRALIBS="-ldl -lpthread -lm -lz"
MACOS_M1=false
CONFIGURE_OPTIONS=()
NONFREE_AND_GPL=false
LATEST=false

# Check for Apple Silicon
if [[ ("$(uname -m)" == "arm64") && ("$OSTYPE" == "darwin"*) ]]; then
  # If arm64 AND darwin (macOS)
  export ARCH=arm64
  export MACOSX_DEPLOYMENT_TARGET=11.0
  MACOS_M1=true
fi

# Speed up the process
# Env Var NUMJOBS overrides automatic detection
if [[ -n "$NUMJOBS" ]]; then
  MJOBS="$NUMJOBS"
elif [[ -f /proc/cpuinfo ]]; then
  MJOBS=$(grep -c processor /proc/cpuinfo)
elif [[ "$OSTYPE" == "darwin"* ]]; then
  MJOBS=$(sysctl -n machdep.cpu.thread_count)
  CONFIGURE_OPTIONS=("--enable-videotoolbox")
  MACOS_LIBTOOL="$(which libtool)" # gnu libtool is installed in this script and need to avoid name conflict
else
  MJOBS=4
fi

make_dir() {
  remove_dir "$1"
  if ! mkdir "$1"; then
    printf "\n Failed to create dir %s" "$1"
    exit 1
  fi
}

remove_dir() {
  if [ -d "$1" ]; then
    rm -r "$1"
  fi
}

download() {
  # download url [filename[dirname]]

  DOWNLOAD_PATH="$PACKAGES"
  DOWNLOAD_FILE="${2:-"${1##*/}"}"

  if [[ "$DOWNLOAD_FILE" =~ tar. ]]; then
    TARGETDIR="${DOWNLOAD_FILE%.*}"
    TARGETDIR="${3:-"${TARGETDIR%.*}"}"
  else
    TARGETDIR="${3:-"${DOWNLOAD_FILE%.*}"}"
  fi

  if [ ! -f "$DOWNLOAD_PATH/$DOWNLOAD_FILE" ]; then
    echo "Downloading $1 as $DOWNLOAD_FILE"
    curl -L --silent -o "$DOWNLOAD_PATH/$DOWNLOAD_FILE" "$1"

    EXITCODE=$?
    if [ $EXITCODE -ne 0 ]; then
      echo ""
      echo "Failed to download $1. Exitcode $EXITCODE. Retrying in 10 seconds"
      sleep 10
      curl -L --silent -o "$DOWNLOAD_PATH/$DOWNLOAD_FILE" "$1"
    fi

    EXITCODE=$?
    if [ $EXITCODE -ne 0 ]; then
      echo ""
      echo "Failed to download $1. Exitcode $EXITCODE"
      exit 1
    fi

    echo "... Done"
  else
    echo "$DOWNLOAD_FILE has already downloaded."
  fi

  make_dir "$DOWNLOAD_PATH/$TARGETDIR"

  if [[ "$DOWNLOAD_FILE" == *"patch"* ]]; then
    return
  fi

  if [ -n "$3" ]; then
    if ! tar -xvf "$DOWNLOAD_PATH/$DOWNLOAD_FILE" -C "$DOWNLOAD_PATH/$TARGETDIR" 2>/dev/null >/dev/null; then
      echo "Failed to extract $DOWNLOAD_FILE"
      exit 1
    fi
  else
    if ! tar -xvf "$DOWNLOAD_PATH/$DOWNLOAD_FILE" -C "$DOWNLOAD_PATH/$TARGETDIR" --strip-components 1 2>/dev/null >/dev/null; then
      echo "Failed to extract $DOWNLOAD_FILE"
      exit 1
    fi
  fi

  echo "Extracted $DOWNLOAD_FILE"

  cd "$DOWNLOAD_PATH/$TARGETDIR" || (
    echo "Error has occurred."
    exit 1
  )
}

execute() {
  echo "$ $*"

  OUTPUT=$("$@" 2>&1)

  # shellcheck disable=SC2181
  if [ $? -ne 0 ]; then
    echo "$OUTPUT"
    echo ""
    echo "Failed to Execute $*" >&2
    exit 1
  fi
}

build() {
  echo ""
  echo "building $1 - version $2"
  echo "======================="

  if [ -f "$PACKAGES/$1.done" ]; then
    if grep -Fx "$2" "$PACKAGES/$1.done" >/dev/null; then
      echo "$1 version $2 already built. Remove $PACKAGES/$1.done lockfile to rebuild it."
      return 1
    elif $LATEST; then
      echo "$1 is outdated and will be rebuilt with latest version $2"
      return 0
    else
      echo "$1 is outdated, but will not be rebuilt. Pass in --latest to rebuild it or remove $PACKAGES/$1.done lockfile."
      return 1
    fi
  fi

  return 0
}

command_exists() {
  if ! [[ -x $(command -v "$1") ]]; then
    return 1
  fi

  return 0
}

library_exists() {
  if ! [[ -x $(pkg-config --exists --print-errors "$1" 2>&1 >/dev/null) ]]; then
    return 1
  fi

  return 0
}

build_done() {
  echo "$2" > "$PACKAGES/$1.done"
}

verify_binary_type() {
  if ! command_exists "file"; then
    return
  fi

  BINARY_TYPE=$(file "$WORKSPACE/bin/ffmpeg" | sed -n 's/^.*\:\ \(.*$\)/\1/p')
  echo ""
  case $BINARY_TYPE in
  "Mach-O 64-bit executable arm64")
    echo "Successfully built Apple Silicon (M1) for ${OSTYPE}: ${BINARY_TYPE}"
    ;;
  *)
    echo "Successfully built binary for ${OSTYPE}: ${BINARY_TYPE}"
    ;;
  esac
}

cleanup() {
  remove_dir "$PACKAGES"
  remove_dir "$WORKSPACE"
  echo "Cleanup done."
  echo ""
}

usage() {
  echo "Usage: $PROGNAME [OPTIONS]"
  echo "Options:"
  echo "  -h, --help                     Display usage information"
  echo "      --version                  Display version information"
  echo "  -b, --build                    Starts the build process"
  echo "      --enable-gpl-and-non-free  Enable GPL and non-free codecs  - https://ffmpeg.org/legal.html"
  echo "  -c, --cleanup                  Remove all working dirs"
  echo "      --latest                   Build latest version of dependencies if newer available"
  echo "      --full-static              Build a full static FFmpeg binary (eg. glibc, pthreads etc...) **only Linux**"
  echo "                                 Note: Because of the NSS (Name Service Switch), glibc does not recommend static links."
  echo ""
}

echo "ffmpeg-build-script v$SCRIPT_VERSION"
echo "========================="
echo ""

while (($# > 0)); do
  case $1 in
  -h | --help)
    usage
    exit 0
    ;;
  --version)
    echo "$SCRIPT_VERSION"
    exit 0
    ;;
  -*)
    if [[ "$1" == "--build" || "$1" =~ '-b' ]]; then
      bflag='-b'
    fi
    if [[ "$1" == "--enable-gpl-and-non-free" ]]; then
      CONFIGURE_OPTIONS+=("--enable-nonfree")
      CONFIGURE_OPTIONS+=("--enable-gpl")
      NONFREE_AND_GPL=true
    fi
    if [[ "$1" == "--cleanup" || "$1" =~ '-c' && ! "$1" =~ '--' ]]; then
      cflag='-c'
      cleanup
    fi
    if [[ "$1" == "--full-static" ]]; then
      if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "Error: A full static binary can only be build on Linux."
        exit 1
      fi
      LDEXEFLAGS="-static"
    fi
    if [[ "$1" == "--latest" ]]; then
      LATEST=true
    fi
    shift
    ;;
  *)
    usage
    exit 1
    ;;
  esac
done

if [ -z "$bflag" ]; then
  if [ -z "$cflag" ]; then
    usage
    exit 1
  fi
  exit 0
fi

echo "Using $MJOBS make jobs simultaneously."

if $NONFREE_AND_GPL; then
echo "With GPL and non-free codecs"
fi

if [ -n "$LDEXEFLAGS" ]; then
  echo "Start the build in full static mode."
fi

mkdir -p "$PACKAGES"
mkdir -p "$WORKSPACE"

export PATH="${WORKSPACE}/bin:$PATH"
PKG_CONFIG_PATH="/usr/local/lib/x86_64-linux-gnu/pkgconfig:/usr/local/lib/pkgconfig"
PKG_CONFIG_PATH+=":/usr/local/share/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig:/usr/lib64/pkgconfig"
export PKG_CONFIG_PATH

if ! command_exists "make"; then
  echo "make not installed."
  exit 1
fi

if ! command_exists "g++"; then
  echo "g++ not installed."
  exit 1
fi

if ! command_exists "curl"; then
  echo "curl not installed."
  exit 1
fi

if ! command_exists "cargo"; then
  echo "cargo not installed. rav1e encoder will not be available."
fi

if ! command_exists "python3"; then
  echo "python3 command not found. Lv2 filter and dav1d decoder will not be available."
fi

##
## build tools
##

if build "giflib" "5.2.1"; then
  download "https://sourceforge.net/projects/giflib/files/giflib-5.2.1.tar.gz"
    if [[ "$OSTYPE" == "darwin"* ]]; then
      download "https://sourceforge.net/p/giflib/bugs/_discuss/thread/4e811ad29b/c323/attachment/Makefile.patch"
      execute patch "${PACKAGES}/giflib-5.2.1/Makefile" ${PACKAGES}/Makefile.patch""
    fi
  execute make -j $MJOBS
  execute make PREFIX="${WORKSPACE}" install
  build_done "giflib" "5.2.1"
fi

if build "pkg-config" "0.29.2"; then
  download "https://pkgconfig.freedesktop.org/releases/pkg-config-0.29.2.tar.gz"
  execute ./configure --silent --prefix="${WORKSPACE}" --with-pc-path="${WORKSPACE}"/lib/pkgconfig --with-internal-glib
  execute make -j $MJOBS
  execute make install
  build_done "pkg-config" "0.29.2"
fi

if build "yasm" "1.3.0"; then
  download "https://github.com/yasm/yasm/releases/download/v1.3.0/yasm-1.3.0.tar.gz"
  execute ./configure --prefix="${WORKSPACE}"
  execute make -j $MJOBS
  execute make install
  build_done "yasm" "1.3.0"
fi

if build "nasm" "2.15.05"; then
  download "https://www.nasm.us/pub/nasm/releasebuilds/2.15.05/nasm-2.15.05.tar.xz"
  execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static
  execute make -j $MJOBS
  execute make install
  build_done "nasm" "2.15.05"
fi

if build "zlib" "1.2.11"; then
  download "https://www.zlib.net/zlib-1.2.11.tar.gz"
  execute ./configure --static --prefix="${WORKSPACE}"
  execute make -j $MJOBS
  execute make install
  build_done "zlib" "1.2.11"
fi

if build "m4" "1.4.19"; then
  download "https://ftp.gnu.org/gnu/m4/m4-1.4.19.tar.gz"
  execute ./configure --prefix="${WORKSPACE}"
  execute make -j $MJOBS
  execute make install
  build_done "m4" "1.4.19"
fi

if build "autoconf" "2.71"; then
  download "https://ftp.gnu.org/gnu/autoconf/autoconf-2.71.tar.gz"
  execute ./configure --prefix="${WORKSPACE}"
  execute make -j $MJOBS
  execute make install
  build_done "autoconf" "2.71"
fi

if build "automake" "1.16.4"; then
  download "https://ftp.gnu.org/gnu/automake/automake-1.16.4.tar.gz"
  execute ./configure --prefix="${WORKSPACE}"
  execute make -j $MJOBS
  execute make install
  build_done "automake" "1.16.4"
fi

if build "libtool" "2.4.6"; then
  download "https://ftpmirror.gnu.org/libtool/libtool-2.4.6.tar.gz"
  execute ./configure --prefix="${WORKSPACE}" --enable-static --disable-shared
  execute make -j $MJOBS
  execute make install
  build_done "libtool" "2.4.6"
fi

if $NONFREE_AND_GPL; then
  if build "openssl" "1.1.1l"; then
    download "https://www.openssl.org/source/openssl-1.1.1l.tar.gz"
    if $MACOS_M1; then
      sed -n 's/\(##### GNU Hurd\)/"darwin64-arm64-cc" => { \n    inherit_from     => [ "darwin-common", asm("aarch64_asm") ],\n    CFLAGS           => add("-Wall"),\n    cflags           => add("-arch arm64 "),\n    lib_cppflags     => add("-DL_ENDIAN"),\n    bn_ops           => "SIXTY_FOUR_BIT_LONG", \n    perlasm_scheme   => "macosx", \n}, \n\1/g' Configurations/10-main.conf
      execute ./configure --prefix="${WORKSPACE}" no-shared no-asm darwin64-arm64-cc
    else
      execute ./config --prefix="${WORKSPACE}" --openssldir="${WORKSPACE}" --with-zlib-include="${WORKSPACE}"/include/ --with-zlib-lib="${WORKSPACE}"/lib no-shared zlib
    fi
    execute make -j $MJOBS
    execute make install_sw
    build_done "openssl" "1.1.1l"
  fi
  CONFIGURE_OPTIONS+=("--enable-openssl")
fi

if build "cmake" "3.22.0"; then
  download "https://github.com/Kitware/CMake/releases/download/v3.22.0/cmake-3.22.0.tar.gz"
  execute ./configure --prefix="${WORKSPACE}" --parallel="${MJOBS}" -- -DCMAKE_USE_OPENSSL=OFF
  execute make -j $MJOBS
  execute make install
  build_done "cmake" "3.22.0"
fi

##
## video library
##

if command_exists "python3"; then
  # dav1d needs meson and ninja along with nasm to be built
  if command_exists "pip3"; then
    # meson and ninja can be installed via pip3
    execute pip3 install pip setuptools --quiet --upgrade --no-cache-dir --disable-pip-version-check
    for r in meson ninja; do
      if ! command_exists ${r}; then
        execute pip3 install ${r} --quiet --upgrade --no-cache-dir --disable-pip-version-check
      fi
    done
  fi
  if command_exists "meson"; then
    if build "dav1d" "0.9.2"; then
      download "https://code.videolan.org/videolan/dav1d/-/archive/0.9.2/dav1d-0.9.2.tar.gz"
      make_dir build
      execute meson build --prefix="${WORKSPACE}" --buildtype=release --default-library=static --libdir="${WORKSPACE}"/lib
      execute ninja -C build
      execute ninja -C build install
      build_done "dav1d" "0.9.2"
    fi
    CONFIGURE_OPTIONS+=("--enable-libdav1d")
  fi
fi

if ! $MACOS_M1; then
  if build "svtav1" "1a3e32b"; then
    execute rm -f "${PACKAGES}/SVT-AV1-master.tar.gz" "${PACKAGES}/svtav1-1a3e32b.tar.gz"
    # Last known working commit which passed CI Tests from HEAD branch
    download "https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/1a3e32b8fdc4abf5c093ee01dfa82803afc75fb4/SVT-AV1-1a3e32b8fdc4abf5c093ee01dfa82803afc75fb4.tar.gz" "svtav1-1a3e32b.tar.gz"
    cd "${PACKAGES}"/svtav1-1a3e32b/Build/linux || exit
    execute cmake -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DENABLE_SHARED=off -DBUILD_SHARED_LIBS=OFF ../.. -G"Unix Makefiles" -DCMAKE_BUILD_TYPE=Release
    execute make -j $MJOBS
    execute make install
    execute cp SvtAv1Enc.pc "${WORKSPACE}/lib/pkgconfig/"
    execute cp SvtAv1Dec.pc "${WORKSPACE}/lib/pkgconfig/"
    build_done "svtav1" "1a3e32b";
  fi
  CONFIGURE_OPTIONS+=("--enable-libsvtav1")
fi

if command_exists "cargo"; then
  if build "rav1e" "0.5.0-beta"; then
    execute cargo install cargo-c
    download "https://github.com/xiph/rav1e/archive/refs/tags/v0.5.0-beta.tar.gz"
    execute cargo cinstall --prefix="${WORKSPACE}" --library-type=staticlib --crt-static --release
    build_done "rav1e" "0.5.0-beta"
  fi
  CONFIGURE_OPTIONS+=("--enable-librav1e")
fi

if $NONFREE_AND_GPL; then

  if build "x264" "5db6aa6"; then
    download "https://code.videolan.org/videolan/x264/-/archive/5db6aa6cab1b146e07b60cc1736a01f21da01154/x264-5db6aa6cab1b146e07b60cc1736a01f21da01154.tar.gz" "x264-5db6aa6.tar.gz"
    cd "${PACKAGES}"/x264-5db6aa6 || exit

    if [[ "$OSTYPE" == "linux-gnu" ]]; then
      execute ./configure --prefix="${WORKSPACE}" --enable-static --enable-pic CXXFLAGS="-fPIC"
    else
      execute ./configure --prefix="${WORKSPACE}" --enable-static --enable-pic
    fi

    execute make -j $MJOBS
    execute make install
    execute make install-lib-static

    build_done "x264" "5db6aa6"
  fi
  CONFIGURE_OPTIONS+=("--enable-libx264")
fi

if $NONFREE_AND_GPL; then
  if build "x265" "3.5"; then
    download "https://github.com/videolan/x265/archive/Release_3.5.tar.gz" "x265-3.5.tar.gz" # This is actually 3.4 if looking at x265Version.txt
    cd build/linux || exit
    rm -rf 8bit 10bit 12bit 2>/dev/null
    mkdir -p 8bit 10bit 12bit
    cd 12bit || exit
    execute cmake ../../../source -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DENABLE_SHARED=OFF -DBUILD_SHARED_LIBS=OFF -DHIGH_BIT_DEPTH=ON -DENABLE_HDR10_PLUS=ON -DEXPORT_C_API=OFF -DENABLE_CLI=OFF -DMAIN12=ON
    execute make -j $MJOBS
    cd ../10bit || exit
    execute cmake ../../../source -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DENABLE_SHARED=OFF -DBUILD_SHARED_LIBS=OFF -DHIGH_BIT_DEPTH=ON -DENABLE_HDR10_PLUS=ON -DEXPORT_C_API=OFF -DENABLE_CLI=OFF
    execute make -j $MJOBS
    cd ../8bit || exit
    ln -sf ../10bit/libx265.a libx265_main10.a
    ln -sf ../12bit/libx265.a libx265_main12.a
    execute cmake ../../../source -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DENABLE_SHARED=OFF -DBUILD_SHARED_LIBS=OFF -DEXTRA_LIB="x265_main10.a;x265_main12.a;-ldl" -DEXTRA_LINK_FLAGS=-L. -DLINKED_10BIT=ON -DLINKED_12BIT=ON
    execute make -j $MJOBS

    mv libx265.a libx265_main.a

    if [[ "$OSTYPE" == "darwin"* ]]; then
      execute "${MACOS_LIBTOOL}" -static -o libx265.a libx265_main.a libx265_main10.a libx265_main12.a 2>/dev/null
    else
      execute ar -M <<EOF
CREATE libx265.a
ADDLIB libx265_main.a
ADDLIB libx265_main10.a
ADDLIB libx265_main12.a
SAVE
END
EOF
    fi

    execute make install

    if [ -n "$LDEXEFLAGS" ]; then
      sed -i.backup 's/-lgcc_s/-lgcc_eh/g' "${WORKSPACE}/lib/pkgconfig/x265.pc" # The -i.backup is intended and required on MacOS: https://stackoverflow.com/questions/5694228/sed-in-place-flag-that-works-both-on-mac-bsd-and-linux
    fi

    build_done "x265" "3.5"
  fi
  CONFIGURE_OPTIONS+=("--enable-libx265")
fi

if build "libvpx" "1.10.0"; then
  download "https://github.com/webmproject/libvpx/archive/refs/tags/v1.10.0.tar.gz" "libvpx-1.10.0.tar.gz"

  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Applying Darwin patch"
    sed "s/,--version-script//g" build/make/Makefile >build/make/Makefile.patched
    sed "s/-Wl,--no-undefined -Wl,-soname/-Wl,-undefined,error -Wl,-install_name/g" build/make/Makefile.patched >build/make/Makefile
  fi

  execute ./configure --prefix="${WORKSPACE}" --disable-unit-tests --disable-shared --as=yasm --enable-vp9-highbitdepth
  execute make -j $MJOBS
  execute make install

  build_done "libvpx" "1.10.0"
fi
CONFIGURE_OPTIONS+=("--enable-libvpx")

if $NONFREE_AND_GPL; then
  if build "xvidcore" "1.3.7"; then
    download "https://downloads.xvid.com/downloads/xvidcore-1.3.7.tar.gz"
    cd build/generic || exit
    execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static
    execute make -j $MJOBS
    execute make install

    if [[ -f ${WORKSPACE}/lib/libxvidcore.4.dylib ]]; then
      execute rm "${WORKSPACE}/lib/libxvidcore.4.dylib"
    fi

    if [[ -f ${WORKSPACE}/lib/libxvidcore.so ]]; then
      execute rm "${WORKSPACE}"/lib/libxvidcore.so*
    fi

    build_done "xvidcore" "1.3.7"
  fi
  CONFIGURE_OPTIONS+=("--enable-libxvid")
fi

if $NONFREE_AND_GPL; then
  if build "vid_stab" "1.1.0"; then
    download "https://github.com/georgmartius/vid.stab/archive/v1.1.0.tar.gz" "vid.stab-1.1.0.tar.gz"

    if $MACOS_M1; then
      curl -s -o "$PACKAGES/vid.stab-1.1.0/fix_cmake_quoting.patch" https://raw.githubusercontent.com/Homebrew/formula-patches/5bf1a0e0cfe666ee410305cece9c9c755641bfdf/libvidstab/fix_cmake_quoting.patch
      patch -p1 <fix_cmake_quoting.patch
    fi

    execute cmake -DBUILD_SHARED_LIBS=OFF -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DUSE_OMP=OFF -DENABLE_SHARED=off .
    execute make
    execute make install

    build_done "vid_stab" "1.1.0"
  fi
  CONFIGURE_OPTIONS+=("--enable-libvidstab")
fi

if build "av1" "ae2be80"; then
  # libaom ae2be80 == v3.1.2
  download "https://aomedia.googlesource.com/aom/+archive/ae2be8030200925895fa6e98bd274ffdb595cbf6.tar.gz" "av1.tar.gz" "av1"
  make_dir "$PACKAGES"/aom_build
  cd "$PACKAGES"/aom_build || exit
  if $MACOS_M1; then
    execute cmake -DENABLE_TESTS=0 -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DCMAKE_INSTALL_LIBDIR=lib -DCONFIG_RUNTIME_CPU_DETECT=0 "$PACKAGES"/av1
  else
    execute cmake -DENABLE_TESTS=0 -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DCMAKE_INSTALL_LIBDIR=lib "$PACKAGES"/av1
  fi
  execute make -j $MJOBS
  execute make install

  build_done "av1" "ae2be80"
fi
CONFIGURE_OPTIONS+=("--enable-libaom")

if build "zimg" "3.0.3"; then
  download "https://github.com/sekrit-twc/zimg/archive/refs/tags/release-3.0.3.tar.gz" "zimg-3.0.3.tar.gz" "zimg"
  cd zimg-release-3.0.3 || exit
  execute "${WORKSPACE}/bin/libtoolize" -i -f -q
  execute ./autogen.sh --prefix="${WORKSPACE}"
  execute ./configure --prefix="${WORKSPACE}" --enable-static --disable-shared
  execute make -j $MJOBS
  execute make install
  build_done "zimg" "3.0.3"
fi
CONFIGURE_OPTIONS+=("--enable-libzimg")

##
## audio library
##

if command_exists "python3"; then

  if build "lv2" "1.18.2"; then
    download "https://lv2plug.in/spec/lv2-1.18.2.tar.bz2" "lv2-1.18.2.tar.bz2"
    execute ./waf configure --prefix="${WORKSPACE}" --lv2-user
    execute ./waf
    execute ./waf install

    build_done "lv2" "1.18.2"
  fi
  if build "waflib" "b600c92"; then
    download "https://gitlab.com/drobilla/autowaf/-/archive/b600c928b221a001faeab7bd92786d0b25714bc8/autowaf-b600c928b221a001faeab7bd92786d0b25714bc8.tar.gz" "autowaf.tar.gz"
    build_done "waflib" "b600c92"
  fi
  if build "serd" "0.30.10"; then
    download "https://gitlab.com/drobilla/serd/-/archive/v0.30.10/serd-v0.30.10.tar.gz" "serd-v0.30.10.tar.gz"
    execute cp -r "${PACKAGES}"/autowaf/* "${PACKAGES}/serd-v0.30.10/waflib/"
    execute ./waf configure --prefix="${WORKSPACE}" --static --no-shared --no-posix
    execute ./waf
    execute ./waf install
    build_done "serd" "0.30.10"
  fi
  if build "pcre" "8.45"; then
    download "https://altushost-swe.dl.sourceforge.net/project/pcre/pcre/8.45/pcre-8.45.tar.gz" "pcre-8.45.tar.gz"
    execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static
    execute make -j $MJOBS
    execute make install

    build_done "pcre" "8.45"
  fi
  if build "sord" "0.16.8"; then
    download "https://gitlab.com/drobilla/sord/-/archive/v0.16.8/sord-v0.16.8.tar.gz" "sord-v0.16.8.tar.gz"
    execute cp -r "${PACKAGES}"/autowaf/* "${PACKAGES}/sord-v0.16.8/waflib/"
    execute ./waf configure --prefix="${WORKSPACE}" CFLAGS="${CFLAGS}" --static --no-shared --no-utils
    execute ./waf CFLAGS="${CFLAGS}"
    execute ./waf install

    build_done "sord" "0.16.8"
  fi
  if build "sratom" "0.6.8"; then
    download "https://gitlab.com/lv2/sratom/-/archive/v0.6.8/sratom-v0.6.8.tar.gz" "sratom-v0.6.8.tar.gz"
    execute cp -r "${PACKAGES}"/autowaf/* "${PACKAGES}/sratom-v0.6.8/waflib/"
    execute ./waf configure --prefix="${WORKSPACE}" --static --no-shared
    execute ./waf
    execute ./waf install

    build_done "sratom" "0.6.8"
  fi
  if build "lilv" "0.24.12"; then
    download "https://gitlab.com/lv2/lilv/-/archive/v0.24.12/lilv-v0.24.12.tar.gz" "lilv-v0.24.12.tar.gz"
    execute cp -r "${PACKAGES}"/autowaf/* "${PACKAGES}/lilv-v0.24.12/waflib/"
    execute ./waf configure --prefix="${WORKSPACE}" --static --no-shared --no-utils
    execute ./waf
    execute ./waf install
    build_done "lilv" "0.24.12"
  fi
  CFLAGS+=" -I$WORKSPACE/include/lilv-0"

  CONFIGURE_OPTIONS+=("--enable-lv2")

fi

if build "opencore" "0.1.5"; then
  download "https://sourceforge.net/projects/opencore-amr/files/opencore-amr/opencore-amr-0.1.5.tar.gz/download?use_mirror=gigenet" "opencore-amr-0.1.5.tar.gz"
  execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static
  execute make -j $MJOBS
  execute make install

  build_done "opencore" "0.1.5"
fi
CONFIGURE_OPTIONS+=("--enable-libopencore_amrnb" "--enable-libopencore_amrwb")

if build "lame" "3.100"; then
  download "https://sourceforge.net/projects/lame/files/lame/3.100/lame-3.100.tar.gz/download?use_mirror=gigenet" "lame-3.100.tar.gz"
  execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static
  execute make -j $MJOBS
  execute make install

  build_done "lame" "3.100"
fi
CONFIGURE_OPTIONS+=("--enable-libmp3lame")

if build "opus" "1.3.1"; then
  download "https://archive.mozilla.org/pub/opus/opus-1.3.1.tar.gz"
  execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static
  execute make -j $MJOBS
  execute make install

  build_done "opus" "1.3.1"
fi
CONFIGURE_OPTIONS+=("--enable-libopus")

if build "libogg" "1.3.3"; then
  download "https://ftp.osuosl.org/pub/xiph/releases/ogg/libogg-1.3.3.tar.gz"
  execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static
  execute make -j $MJOBS
  execute make install
  build_done "libogg" "1.3.3"
fi

if build "libvorbis" "1.3.6"; then
  download "https://ftp.osuosl.org/pub/xiph/releases/vorbis/libvorbis-1.3.6.tar.gz"
  execute ./configure --prefix="${WORKSPACE}" --with-ogg-libraries="${WORKSPACE}"/lib --with-ogg-includes="${WORKSPACE}"/include/ --enable-static --disable-shared --disable-oggtest
  execute make -j $MJOBS
  execute make install

  build_done "libvorbis" "1.3.6"
fi
CONFIGURE_OPTIONS+=("--enable-libvorbis")

if build "libtheora" "1.1.1"; then
  download "https://ftp.osuosl.org/pub/xiph/releases/theora/libtheora-1.1.1.tar.gz"
  sed "s/-fforce-addr//g" configure >configure.patched
  chmod +x configure.patched
  mv configure.patched configure
  execute ./configure --prefix="${WORKSPACE}" --with-ogg-libraries="${WORKSPACE}"/lib --with-ogg-includes="${WORKSPACE}"/include/ --with-vorbis-libraries="${WORKSPACE}"/lib --with-vorbis-includes="${WORKSPACE}"/include/ --enable-static --disable-shared --disable-oggtest --disable-vorbistest --disable-examples --disable-asm --disable-spec
  execute make -j $MJOBS
  execute make install

  build_done "libtheora" "1.1.1"
fi
CONFIGURE_OPTIONS+=("--enable-libtheora")

if $NONFREE_AND_GPL; then
  if build "fdk_aac" "2.0.2"; then
    download "https://sourceforge.net/projects/opencore-amr/files/fdk-aac/fdk-aac-2.0.2.tar.gz/download?use_mirror=gigenet" "fdk-aac-2.0.2.tar.gz"
    execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static --enable-pic
    execute make -j $MJOBS
    execute make install

    build_done "fdk_aac" "2.0.2"
  fi
  CONFIGURE_OPTIONS+=("--enable-libfdk-aac")
fi

##
## image library
##

if build "libtiff" "4.2.0"; then
  download "https://download.osgeo.org/libtiff/tiff-4.2.0.tar.gz"
  execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static --disable-dependency-tracking --disable-lzma --disable-webp --disable-zstd --without-x
  execute make -j $MJOBS
  execute make install
  build_done "libtiff" "4.2.0"
fi
if build "libpng" "1.6.37"; then
  download "https://sourceforge.net/projects/libpng/files/libpng16/1.6.37/libpng-1.6.37.tar.gz/download?use_mirror=gigenet" "libpng-1.6.37.tar.gz"
  export LDFLAGS="${LDFLAGS}"
  export CPPFLAGS="${CFLAGS}"
  execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static
  execute make -j $MJOBS
  execute make install
  build_done "libpng" "1.6.37"
fi

## does not compile on monterey -> _PrintGifError
if [[ "$OSTYPE" != "darwin"* ]]; then
  if build "libwebp" "1.2.1"; then
    # libwebp can fail to compile on Ubuntu if these flags were left set to CFLAGS
    CPPFLAGS=
    download "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.2.1.tar.gz" "libwebp-1.2.1.tar.gz"
    execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static --disable-dependency-tracking --disable-gl --with-zlib-include="${WORKSPACE}"/include/ --with-zlib-lib="${WORKSPACE}"/lib
    make_dir build
    cd build || exit
    execute cmake -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_INSTALL_BINDIR=bin -DCMAKE_INSTALL_INCLUDEDIR=include -DENABLE_SHARED=OFF -DENABLE_STATIC=ON ../
    execute make -j $MJOBS
    execute make install

    build_done "libwebp" "1.2.1"
  fi
  CONFIGURE_OPTIONS+=("--enable-libwebp")
fi
##
## other library
##

if build "libsdl" "2.0.14"; then
  download "https://www.libsdl.org/release/SDL2-2.0.14.tar.gz"
  execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static
  execute make -j $MJOBS
  execute make install

  build_done "libsdl" "2.0.14"
fi

if $NONFREE_AND_GPL; then
  if build "srt" "1.4.3"; then
    download "https://github.com/Haivision/srt/archive/v1.4.3.tar.gz" "srt-1.4.3.tar.gz"
    export OPENSSL_ROOT_DIR="${WORKSPACE}"
    export OPENSSL_LIB_DIR="${WORKSPACE}"/lib
    export OPENSSL_INCLUDE_DIR="${WORKSPACE}"/include/
    execute cmake . -DCMAKE_INSTALL_PREFIX="${WORKSPACE}" -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_INSTALL_BINDIR=bin -DCMAKE_INSTALL_INCLUDEDIR=include -DENABLE_SHARED=OFF -DENABLE_STATIC=ON -DENABLE_APPS=OFF -DUSE_STATIC_LIBSTDCXX=ON
    execute make install

    if [ -n "$LDEXEFLAGS" ]; then
      sed -i.backup 's/-lgcc_s/-lgcc_eh/g' "${WORKSPACE}"/lib/pkgconfig/srt.pc # The -i.backup is intended and required on MacOS: https://stackoverflow.com/questions/5694228/sed-in-place-flag-that-works-both-on-mac-bsd-and-linux
    fi

    build_done "srt" "1.4.3"
  fi
  CONFIGURE_OPTIONS+=("--enable-libsrt")
fi

##
## HWaccel library
##

if [[ "$OSTYPE" == "linux-gnu" ]]; then
  if command_exists "nvcc"; then
    if build "nv-codec" "11.1.5.0"; then
      download "https://github.com/FFmpeg/nv-codec-headers/releases/download/n11.1.5.0/nv-codec-headers-11.1.5.0.tar.gz"
      execute make PREFIX="${WORKSPACE}"
      execute make install PREFIX="${WORKSPACE}"
      build_done "nv-codec" "11.1.5.0"
    fi
    CFLAGS+=" -I/usr/local/cuda/include"
    LDFLAGS+=" -L/usr/local/cuda/lib64"
    CONFIGURE_OPTIONS+=("--enable-cuda-nvcc" "--enable-cuvid" "--enable-nvenc" "--enable-cuda-llvm")

    if [ -z "$LDEXEFLAGS" ]; then
      CONFIGURE_OPTIONS+=("--enable-libnpp") # Only libnpp cannot be statically linked.
    fi

    # https://arnon.dk/matching-sm-architectures-arch-and-gencode-for-various-nvidia-cards/
    CONFIGURE_OPTIONS+=("--nvccflags=-gencode arch=compute_52,code=sm_52")
  fi

  # Vaapi doesn't work well with static links FFmpeg.
  if [ -z "$LDEXEFLAGS" ]; then
    # If the libva development SDK is installed, enable vaapi.
    if library_exists "libva"; then
      if build "vaapi" "1"; then
        build_done "vaapi" "1"
      fi
      CONFIGURE_OPTIONS+=("--enable-vaapi")
    fi
  fi

  if build "amf" "1.4.21.0"; then
    download "https://github.com/GPUOpen-LibrariesAndSDKs/AMF/archive/refs/tags/v.1.4.21.tar.gz" "AMF-1.4.21.tar.gz" "AMF-1.4.21"
    execute rm -rf "${WORKSPACE}/include/AMF"
    execute mkdir -p "${WORKSPACE}/include/AMF"
    execute cp -r "${PACKAGES}"/AMF-1.4.21/AMF-v.1.4.21/amf/public/include/* "${WORKSPACE}/include/AMF/"
    build_done "amf" "1.4.21.0"
  fi
  CONFIGURE_OPTIONS+=("--enable-amf")
fi

##
## FFmpeg
##

EXTRA_VERSION=""
if [[ "$OSTYPE" == "darwin"* ]]; then
  EXTRA_VERSION="${FFMPEG_VERSION}"
fi

build "ffmpeg" "$FFMPEG_VERSION"
download "https://github.com/FFmpeg/FFmpeg/archive/refs/heads/release/$FFMPEG_VERSION.tar.gz" "FFmpeg-release-$FFMPEG_VERSION.tar.gz"
# shellcheck disable=SC2086
./configure "${CONFIGURE_OPTIONS[@]}" \
  --disable-debug \
  --disable-doc \
  --disable-shared \
  --enable-pthreads \
  --enable-static \
  --enable-small \
  --enable-version3 \
  --extra-cflags="${CFLAGS}" \
  --extra-ldexeflags="${LDEXEFLAGS}" \
  --extra-ldflags="${LDFLAGS}" \
  --extra-libs="${EXTRALIBS}" \
  --pkgconfigdir="$WORKSPACE/lib/pkgconfig" \
  --pkg-config-flags="--static" \
  --prefix="${WORKSPACE}" \
  --extra-version="${EXTRA_VERSION}"

execute make -j $MJOBS
execute make install

INSTALL_FOLDER="/usr/bin"
if [[ "$OSTYPE" == "darwin"* ]]; then
  INSTALL_FOLDER="/usr/local/bin"
fi

verify_binary_type

echo ""
echo "Building done. The following binaries can be found here:"
echo "- ffmpeg: $WORKSPACE/bin/ffmpeg"
echo "- ffprobe: $WORKSPACE/bin/ffprobe"
echo "- ffplay: $WORKSPACE/bin/ffplay"
echo ""

if [[ "$AUTOINSTALL" == "yes" ]]; then
  if command_exists "sudo"; then
    sudo cp "$WORKSPACE/bin/ffmpeg" "$INSTALL_FOLDER/ffmpeg"
    sudo cp "$WORKSPACE/bin/ffprobe" "$INSTALL_FOLDER/ffprobe"
    sudo cp "$WORKSPACE/bin/ffplay" "$INSTALL_FOLDER/ffplay"
    echo "Done. FFmpeg is now installed to your system."
  else
    cp "$WORKSPACE/bin/ffmpeg" "$INSTALL_FOLDER/ffmpeg"
    cp "$WORKSPACE/bin/ffprobe" "$INSTALL_FOLDER/ffprobe"
    cp "$WORKSPACE/bin/ffplay" "$INSTALL_FOLDER/ffplay"
    echo "Done. FFmpeg is now installed to your system."
  fi
elif [[ ! "$SKIPINSTALL" == "yes" ]]; then
  read -r -p "Install these binaries to your $INSTALL_FOLDER folder? Existing binaries will be replaced. [Y/n] " response
  case $response in
  [yY][eE][sS] | [yY])
    if command_exists "sudo"; then
      sudo cp "$WORKSPACE/bin/ffmpeg" "$INSTALL_FOLDER/ffmpeg"
      sudo cp "$WORKSPACE/bin/ffprobe" "$INSTALL_FOLDER/ffprobe"
      sudo cp "$WORKSPACE/bin/ffplay" "$INSTALL_FOLDER/ffplay"
    else
      cp "$WORKSPACE/bin/ffmpeg" "$INSTALL_FOLDER/ffmpeg"
      cp "$WORKSPACE/bin/ffprobe" "$INSTALL_FOLDER/ffprobe"
      cp "$WORKSPACE/bin/ffplay" "$INSTALL_FOLDER/ffplay"
    fi
    echo "Done. FFmpeg is now installed to your system."
    ;;
  esac
fi

exit 0
