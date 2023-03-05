[![build test](https://github.com/markus-perl/ffmpeg-build-script/workflows/build%20test/badge.svg?branch=master)](https://github.com/markus-perl/ffmpeg-build-script/actions)

![FFmpeg build script](https://raw.github.com/markus-perl/ffmpeg-build-script/master/ffmpeg-build-script.png)

### If you like the script, please "★" this project!

build-ffmpeg
==========

The FFmpeg build script provides an easy way to build a **static** FFmpeg on **macOS** and **Linux** with optional **non-free and GPL codecs** (--enable-gpl-and-non-free, see https://ffmpeg.org/legal.html) included.

[![How-To build FFmpeg on MacOS](https://img.youtube.com/vi/Z9p3mM757cM/0.jpg)](https://www.youtube.com/watch?v=Z9p3mM757cM "How-To build FFmpeg on OSX")

*Youtube: How-To build and install FFmpeg on macOS*

## Disclaimer And Data Privacy Notice

This script will download different packages with different licenses from various sources, which may track your usage.
These sources are out of control by the developers of this script. Also, this script can create a non-free and unredistributable binary.
By downloading and using this script, you are fully aware of this.

Use this script at your own risk. I maintain this script in my spare time. Please do not file bug reports for systems
other than Debian and macOS, because I don't have the resources or time to maintain different systems.

## Installation

### Quick install and run (macOS, Linux)

Open your command line and run (curl needs to be installed):

```bash

# Without GPL and non-free codes, see https://ffmpeg.org/legal.html 
$ bash <(curl -s "https://raw.githubusercontent.com/markus-perl/ffmpeg-build-script/master/web-install.sh?v1")

# With GPL and non-free codes, see https://ffmpeg.org/legal.html 
$ bash <(curl -s "https://raw.githubusercontent.com/markus-perl/ffmpeg-build-script/master/web-install-gpl-and-non-free.sh?v1")
```

This command downloads the build script and automatically starts the build process.

### Common installation (macOS, Linux)

```bash
$ git clone https://github.com/markus-perl/ffmpeg-build-script.git
$ cd ffmpeg-build-script
$ ./build-ffmpeg --build
```

## Supported Codecs

* `x264`: H.264 Video Codec (MPEG-4 AVC)
* `x265`: H.265 Video Codec (HEVC)
* `libsvtav1`: SVT-AV1 Encoder and Decoder
* `aom`: AV1 Video Codec (Experimental and very slow!)
* `librav1e`: rust based AV1 encoder (only available if [`cargo` is installed](https://doc.rust-lang.org/cargo/getting-started/installation.html)) 
* `libdav1d`: Fastest AV1 decoder developed by the VideoLAN and FFmpeg communities and sponsored by the AOMedia (only available if `meson` and `ninja` are installed)
* `fdk_aac`: Fraunhofer FDK AAC Codec
* `xvidcore`: MPEG-4 video coding standard
* `VP8/VP9/webm`: VP8 / VP9 Video Codec for the WebM video file format
* `mp3`: MPEG-1 or MPEG-2 Audio Layer III
* `ogg`: Free, open container format
* `vorbis`: Lossy audio compression format
* `theora`: Free lossy video compression format
* `opus`: Lossy audio coding format
* `srt`: Secure Reliable Transport
* `webp`: Image format both lossless and lossy

### HardwareAccel

* `nv-codec`: [NVIDIA's GPU accelerated video codecs](https://devblogs.nvidia.com/nvidia-ffmpeg-transcoding-guide/).
  These encoders/decoders will only be available if a CUDA installation was found while building the binary.
  Follow [these](#Cuda-installation) instructions for installation. Supported codecs in nvcodec:
    * Decoders
        * H264 `h264_cuvid`
        * H265 `hevc_cuvid`
        * Motion JPEG `mjpeg_cuvid`
        * MPEG1 video `mpeg1_cuvid`
        * MPEG2 video `mpeg2_cuvid`
        * MPEG4 part 2 video `mepg4_cuvid`
        * VC-1 `vc1_cuvid`
        * VP8 `vp8_cuvid`
        * VP9 `vp9_cuvid`
    * Encoders
        * H264 `nvenc_h264`
        * H265 `nvenc_hevc`
* `vaapi`: [Video Acceleration API](https://trac.ffmpeg.org/wiki/Hardware/VAAPI). These encoders/decoders will only be
  available if a libva driver installation was found while building the binary. Follow [these](#Vaapi-installation)
  instructions for installation. Supported codecs in vaapi:
    * Encoders
        * H264 `h264_vaapi`
        * H265 `hevc_vaapi`
        * Motion JPEG `mjpeg_vaapi`
        * MPEG2 video `mpeg2_vaapi`
        * VP8 `vp8_vaapi`
        * VP9 `vp9_vaapi`
* `AMF`: [AMD's Advanced Media Framework](https://github.com/GPUOpen-LibrariesAndSDKs/AMF). These encoders will only 
  be available if `amdgpu` drivers are detected in use on the system with `lspci -v`. 
    * Encoders
        * H264 `h264_amf` 


### Apple M1 (Apple Silicon) Support

The script also builds FFmpeg on a new MacBook with an Apple Silicon M1 processor.

### LV2 Plugin Support

If Python is available, the script will build a ffmpeg binary with lv2 plugin support.

## Continuous Integration

ffmpeg-build-script is very stable. Every commit runs against Linux and macOS
with https://github.com/markus-perl/ffmpeg-build-script/actions to make sure everything works as expected.

## Requirements

### macOS

* XCode 10.x or greater

### Linux

* Debian >= Buster, Ubuntu => Focal Fossa, other Distributions might work too
* Rocky Linux 8
* A development environment and curl is required

```bash
# Debian and Ubuntu
$ sudo apt install build-essential curl

# Fedora
$ sudo dnf install @development-tools curl
```

### Build in Docker (Linux)

With Docker, FFmpeg can be built reliably without altering the host system. Also, there is no need to have the CUDA SDK
installed outside of the Docker image.

##### Default

If you're running an operating system other than the one above, a completely static build may work. To build a full
statically linked binary inside Docker, just run the following command:

```bash
$ docker build --tag=ffmpeg:default --output type=local,dest=build -f Dockerfile .
```

##### CUDA
These builds are always built with the --enable-gpl-and-non-free switch, as CUDA is non-free. See https://ffmpeg.org/legal.html
```bash

## Start the build
$ docker build --tag=ffmpeg:cuda --output type=local,dest=build -f cuda-ubuntu.dockerfile .
```

Build an `export.dockerfile` that copies only what you need from the image you just built as follows. When running,
move the library in the lib to a location where the linker can find it or set the `LD_LIBRARY_PATH`. Since we have
matched the operating system and version, it should work well with dynamic links. If it doesn't work, edit
the `export.dockerfile` and copy the necessary libraries and try again.

```bash
$ docker build --output type=local,dest=build -f export.dockerfile .
$ ls build
bin lib
$ ls build/bin
ffmpeg ffprobe
$ ls build/lib
libnppc.so.11 libnppicc.so.11 libnppidei.so.11 libnppig.so.11
```

##### Full static version

If you're running an operating system other than the one above, a completely static build may work. To build a full
statically linked binary inside Docker, just run the following command:

```bash
$ sudo -E docker build --tag=ffmpeg:cuda-static --output type=local,dest=build -f full-static.dockerfile .
```

### Run with Docker (macOS, Linux)

You can also run the FFmpeg directly inside a Docker container.

#### Default - Without CUDA (macOS, Linux)

If CUDA is not required, a dockerized FFmpeg build can be executed with the following command:

```bash
$ sudo docker build --tag=ffmpeg .
$ sudo docker run ffmpeg -i https://files.coconut.co.s3.amazonaws.com/test.mp4 -f webm -c:v libvpx -c:a libvorbis - > test.mp4
```

#### With CUDA (Linux)

To use CUDA from inside the container, the installed Docker version must be >= 19.03. Install the driver
and `nvidia-docker2`
from [here](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html#installing-docker-ce).
You can then run FFmpeg inside Docker with GPU hardware acceleration enabled, as follows:

```bash
$ sudo docker build --tag=ffmpeg:cuda -f cuda-ubuntu.dockerfile .
$ sudo docker run --gpus all ffmpeg-cuda -hwaccel cuvid -c:v h264_cuvid -i https://files.coconut.co.s3.amazonaws.com/test.mp4 -c:v hevc_nvenc -vf scale_npp=-1:1080 - > test.mp4
```

### Common build (macOS, Linux)

If you want to enable CUDA, please refer to [these](#Cuda-installation) and install the SDK.

If you want to enable Vaapi, please refer to [these](#Vaapi-installation) and install the driver.

```bash
$ ./build-ffmpeg --build
```

## Cuda installation

CUDA is a parallel computing platform developed by NVIDIA. To be able to compile ffmpeg with CUDA support, you first
need a compatible NVIDIA GPU.

- Ubuntu: To install the CUDA toolkit on Ubuntu, run "sudo apt install nvidia-cuda-toolkit"
- Other Linux distributions: Once you have the GPU and display driver installed, you can follow the
  [official instructions](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html)
  or [this blog](https://www.pugetsystems.com/labs/hpc/How-To-Install-CUDA-10-1-on-Ubuntu-19-04-1405/)
  to setup the CUDA toolkit.

## Vaapi installation

You will need the libva driver, so please install it below.

```bash
# Debian and Ubuntu
$ sudo apt install libva-dev vainfo

# Fedora and CentOS
$ sudo dnf install libva-devel libva-intel-driver libva-utils
```

## AMF installation

To use the AMF encoder, you will need to be using the AMD GPU Pro drivers with OpenCL support.
Download the drivers from https://www.amd.com/en/support and install the appropriate opencl versions.

```bash
./amdgpu-pro-install -y --opencl=rocr,legacy
```

## Usage

```bash
Usage: build-ffmpeg [OPTIONS]
Options:
  -h, --help                     Display usage information
      --version                  Display version information
  -b, --build                    Starts the build process
      --enable-gpl-and-non-free  Enable non-free codecs  - https://ffmpeg.org/legal.html
      --latest                   Build latest version of dependencies if newer available
  -c, --cleanup                  Remove all working dirs
      --full-static              Complete static build of ffmpeg (eg. glibc, pthreads etc...) **only Linux**
                                 Note: Because of the NSS (Name Service Switch), glibc does not recommend static links.
```

## Notes of static link

- Because of the NSS (Name Service Switch), glibc does **not recommend** static links. See detail
  below: https://sourceware.org/glibc/wiki/FAQ#Even_statically_linked_programs_need_some_shared_libraries_which_is_not_acceptable_for_me.__What_can_I_do.3F

- The libnpp in the CUDA SDK cannot be statically linked.
- Vaapi cannot be statically linked.

Contact
-------

* Github: [http://www.github.com/markus-perl/](https://github.com/markus-perl/ffmpeg-build-script)

Tested on
---------

* MacOS 10.15
* Debian 10
* Ubuntu 20.04

Example
-------

```
./build-ffmpeg --build

ffmpeg-build-script v1.xx
=========================

Using 12 make jobs simultaneously.
With GPL and non-free codecs

building giflib - version 5.2.1
=======================
Downloading https://netcologne.dl.sourceforge.net/project/giflib/giflib-5.2.1.tar.gz as giflib-5.2.1.tar.gz
... Done
Extracted giflib-5.2.1.tar.gz
$ make
$ make PREFIX=/app/workspace install

building pkg-config - version 0.29.2
=======================
Downloading https://pkgconfig.freedesktop.org/releases/pkg-config-0.29.2.tar.gz as pkg-config-0.29.2.tar.gz
... Done
Extracted pkg-config-0.29.2.tar.gz
$ ./configure --silent --prefix=/app/workspace --with-pc-path=/app/workspace/lib/pkgconfig --with-internal-glib
$ make -j 2
$ make install

building yasm - version 1.3.0
=======================
Downloading https://github.com/yasm/yasm/releases/download/v1.3.0/yasm-1.3.0.tar.gz as yasm-1.3.0.tar.gz
... Done
Extracted yasm-1.3.0.tar.gz
$ ./configure --prefix=/app/workspace
$ make -j 2
$ make install

building nasm - version 2.16.01
=======================
Downloading https://www.nasm.us/pub/nasm/releasebuilds/2.16.01/nasm-2.16.01.tar.xz as nasm-2.16.01.tar.xz
... Done
Extracted nasm-2.16.01.tar.xz
$ ./configure --prefix=/app/workspace --disable-shared --enable-static
$ make -j 2
$ make install

building zlib - version 1.2.13
=======================
Downloading https://zlib.net/fossils/zlib-1.2.13.tar.gz as zlib-1.2.13.tar.gz
... Done
Extracted zlib-1.2.13.tar.gz
$ ./configure --static --prefix=/app/workspace
$ make -j 2
$ make install

building m4 - version 1.4.19
=======================
Downloading https://ftp.gnu.org/gnu/m4/m4-1.4.19.tar.gz as m4-1.4.19.tar.gz
... Done
Extracted m4-1.4.19.tar.gz
$ ./configure --prefix=/app/workspace
$ make -j 2
$ make install

building autoconf - version 2.71
=======================
Downloading https://ftp.gnu.org/gnu/autoconf/autoconf-2.71.tar.gz as autoconf-2.71.tar.gz
... Done
Extracted autoconf-2.71.tar.gz
$ ./configure --prefix=/app/workspace
$ make -j 2
$ make install

building automake - version 1.16.5
=======================
Downloading https://ftp.gnu.org/gnu/automake/automake-1.16.5.tar.gz as automake-1.16.5.tar.gz
... Done
Extracted automake-1.16.5.tar.gz
$ ./configure --prefix=/app/workspace
$ make -j 2
$ make install

building libtool - version 2.4.7
=======================
Downloading https://ftpmirror.gnu.org/libtool/libtool-2.4.7.tar.gz as libtool-2.4.7.tar.gz
... Done
Extracted libtool-2.4.7.tar.gz
$ ./configure --prefix=/app/workspace --enable-static --disable-shared
$ make -j 2
$ make install

building openssl - version 1.1.1t
=======================
Downloading https://www.openssl.org/source/openssl-1.1.1t.tar.gz as openssl-1.1.1t.tar.gz
... Done
Extracted openssl-1.1.1t.tar.gz
$ ./config --prefix=/app/workspace --openssldir=/app/workspace --with-zlib-include=/app/workspace/include/ --with-zlib-lib=/app/workspace/lib no-shared zlib
$ make -j 2
$ make install_sw

building cmake - version 3.25.1
=======================
Downloading https://github.com/Kitware/CMake/releases/download/v3.25.1/cmake-3.25.1.tar.gz as cmake-3.25.1.tar.gz
... Done
Extracted cmake-3.25.1.tar.gz
$ ./configure --prefix=/app/workspace --parallel=2 -- -DCMAKE_USE_OPENSSL=OFF
$ make -j 2
$ make install

building dav1d - version 1.1.0
=======================
Downloading https://code.videolan.org/videolan/dav1d/-/archive/1.0.0/dav1d-1.1.0.tar.gz as dav1d-1.1.0.tar.gz
... Done
Extracted dav1d-1.1.0.tar.gz
$ meson build --prefix=/app/workspace --buildtype=release --default-library=static --libdir=/app/workspace/lib
$ ninja -C build
$ ninja -C build install

building svtav1 - version 1.4.1
=======================
Downloading https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/v1.4.1/SVT-AV1-v1.4.1.tar.gz as svtav1-1.4.1.tar.gz
... Done
Extracted svtav1-1.4.1.tar.gz
$ cmake -DCMAKE_INSTALL_PREFIX=/app/workspace -DENABLE_SHARED=off -DBUILD_SHARED_LIBS=OFF ../.. -GUnix Makefiles -DCMAKE_BUILD_TYPE=Release
$ make -j 2
$ make install
$ cp SvtAv1Enc.pc /app/workspace/lib/pkgconfig/
$ cp SvtAv1Dec.pc /app/workspace/lib/pkgconfig/

building x264 - version 941cae6d
=======================
Downloading https://code.videolan.org/videolan/x264/-/archive/941cae6d1d6d6344c9a1d27440eaf2872b18ca9a/x264-941cae6d1d6d6344c9a1d27440eaf2872b18ca9a.tar.gz as x264-941cae6d.tar.gz
... Done
Extracted x264-941cae6d.tar.gz
$ ./configure --prefix=/app/workspace --enable-static --enable-pic CXXFLAGS=-fPIC 
$ make -j 2
$ make install
$ make install-lib-static

building x265 - version 3.5
=======================
Downloading https://github.com/videolan/x265/archive/Release_3.5.tar.gz as x265-3.5.tar.gz
... Done
Extracted x265-3.5.tar.gz
$ cmake ../../../source -DCMAKE_INSTALL_PREFIX=/app/workspace -DENABLE_SHARED=OFF -DBUILD_SHARED_LIBS=OFF -DHIGH_BIT_DEPTH=ON -DENABLE_HDR10_PLUS=ON -DEXPORT_C_API=OFF -DENABLE_CLI=OFF -DMAIN12=ON
$ make -j 2
$ cmake ../../../source -DCMAKE_INSTALL_PREFIX=/app/workspace -DENABLE_SHARED=OFF -DBUILD_SHARED_LIBS=OFF -DHIGH_BIT_DEPTH=ON -DENABLE_HDR10_PLUS=ON -DEXPORT_C_API=OFF -DENABLE_CLI=OFF
$ make -j 2
$ cmake ../../../source -DCMAKE_INSTALL_PREFIX=/app/workspace -DENABLE_SHARED=OFF -DBUILD_SHARED_LIBS=OFF -DEXTRA_LIB=x265_main10.a;x265_main12.a;-ldl -DEXTRA_LINK_FLAGS=-L. -DLINKED_10BIT=ON -DLINKED_12BIT=ON
$ make -j 2
$ ar -M
$ make install

building libvpx - version 1.13.0
=======================
Downloading https://github.com/webmproject/libvpx/archive/refs/tags/v1.13.0.tar.gz as libvpx-1.13.0.tar.gz
... Done
Extracted libvpx-1.13.0.tar.gz
$ ./configure --prefix=/app/workspace --disable-unit-tests --disable-shared --disable-examples --as=yasm --enable-vp9-highbitdepth
$ make -j 2
$ make install

building xvidcore - version 1.3.7
=======================
Downloading https://downloads.xvid.com/downloads/xvidcore-1.3.7.tar.gz as xvidcore-1.3.7.tar.gz
... Done
Extracted xvidcore-1.3.7.tar.gz
$ ./configure --prefix=/app/workspace --disable-shared --enable-static
$ make -j 2
$ make install
$ rm /app/workspace/lib/libxvidcore.so /app/workspace/lib/libxvidcore.so.4 /app/workspace/lib/libxvidcore.so.4.3

building vid_stab - version 1.1.0
=======================
Downloading https://github.com/georgmartius/vid.stab/archive/v1.1.0.tar.gz as vid.stab-1.1.0.tar.gz
... Done
Extracted vid.stab-1.1.0.tar.gz
$ cmake -DBUILD_SHARED_LIBS=OFF -DCMAKE_INSTALL_PREFIX=/app/workspace -DUSE_OMP=OFF -DENABLE_SHARED=off .
$ make
$ make install

building av1 - version bcfe6fb
=======================
Downloading https://aomedia.googlesource.com/aom/+archive/bcfe6fbfed315f83ee8a95465c654ee8078dbff9.tar.gz as av1.tar.gz
... Done
Extracted av1.tar.gz
$ cmake -DENABLE_TESTS=0 -DENABLE_EXAMPLES=0 -DCMAKE_INSTALL_PREFIX=/app/workspace -DCMAKE_INSTALL_LIBDIR=lib /app/packages/av1
$ make -j 2
$ make install

building zimg - version 3.0.4
=======================
Downloading https://github.com/sekrit-twc/zimg/archive/refs/tags/release-3.0.4.tar.gz as zimg-3.0.4.tar.gz
... Done
Extracted zimg-3.0.4.tar.gz
$ /app/workspace/bin/libtoolize -i -f -q
$ ./autogen.sh --prefix=/app/workspace
$ ./configure --prefix=/app/workspace --enable-static --disable-shared
$ make -j 2
$ make install

building lv2 - version 1.18.10
=======================
Downloading https://lv2plug.in/spec/lv2-1.18.10.tar.xz as lv2-1.18.10.tar.xz
... Done
Extracted lv2-1.18.10.tar.xz
$ meson build --prefix=/app/workspace --buildtype=release --default-library=static --libdir=/app/workspace/lib
$ ninja -C build
$ ninja -C build install

building waflib - version b600c92
=======================
Downloading https://gitlab.com/drobilla/autowaf/-/archive/b600c928b221a001faeab7bd92786d0b25714bc8/autowaf-b600c928b221a001faeab7bd92786d0b25714bc8.tar.gz as autowaf.tar.gz
... Done
Extracted autowaf.tar.gz

building serd - version 0.30.16
=======================
Downloading https://gitlab.com/drobilla/serd/-/archive/v0.30.16/serd-v0.30.16.tar.gz as serd-v0.30.16.tar.gz
... Done
Extracted serd-v0.30.16.tar.gz
$ meson build --prefix=/app/workspace --buildtype=release --default-library=static --libdir=/app/workspace/lib
$ ninja -C build
$ ninja -C build install

building pcre - version 8.45
=======================
Downloading https://altushost-swe.dl.sourceforge.net/project/pcre/pcre/8.45/pcre-8.45.tar.gz as pcre-8.45.tar.gz
... Done
Extracted pcre-8.45.tar.gz
$ ./configure --prefix=/app/workspace --disable-shared --enable-static
$ make -j 2
$ make install

building sord - version 0.16.14
=======================
Downloading https://gitlab.com/drobilla/sord/-/archive/v0.16.14/sord-v0.16.14.tar.gz as sord-v0.16.14.tar.gz
... Done
Extracted sord-v0.16.14.tar.gz
$ meson build --prefix=/app/workspace --buildtype=release --default-library=static --libdir=/app/workspace/lib
$ ninja -C build
$ ninja -C build install

building sratom - version 0.6.14
=======================
Downloading https://gitlab.com/lv2/sratom/-/archive/v0.6.14/sratom-v0.6.14.tar.gz as sratom-v0.6.14.tar.gz
... Done
Extracted sratom-v0.6.14.tar.gz
$ meson build --prefix=/app/workspace --buildtype=release --default-library=static --libdir=/app/workspace/lib
$ ninja -C build
$ ninja -C build install

building lilv - version 0.24.20
=======================
Downloading https://gitlab.com/lv2/lilv/-/archive/v0.24.20/lilv-v0.24.20.tar.gz as lilv-v0.24.20.tar.gz
... Done
Extracted lilv-v0.24.20.tar.gz
$ meson build --prefix=/app/workspace --buildtype=release --default-library=static --libdir=/app/workspace/lib
$ ninja -C build
$ ninja -C build install

building opencore - version 0.1.6
=======================
Downloading https://netactuate.dl.sourceforge.net/project/opencore-amr/opencore-amr/opencore-amr-0.1.6.tar.gz as opencore-amr-0.1.6.tar.gz
... Done
Extracted opencore-amr-0.1.6.tar.gz
$ ./configure --prefix=/app/workspace --disable-shared --enable-static
$ make -j 2
$ make install

building lame - version 3.100
=======================
Downloading https://sourceforge.net/projects/lame/files/lame/3.100/lame-3.100.tar.gz/download?use_mirror=gigenet as lame-3.100.tar.gz
... Done
Extracted lame-3.100.tar.gz
$ ./configure --prefix=/app/workspace --disable-shared --enable-static
$ make -j 2
$ make install

building opus - version 1.3.1
=======================
Downloading https://archive.mozilla.org/pub/opus/opus-1.3.1.tar.gz as opus-1.3.1.tar.gz
... Done
Extracted opus-1.3.1.tar.gz
$ ./configure --prefix=/app/workspace --disable-shared --enable-static
$ make -j 2
$ make install

building libogg - version 1.3.5
=======================
Downloading https://ftp.osuosl.org/pub/xiph/releases/ogg/libogg-1.3.5.tar.xz as libogg-1.3.5.tar.xz
... Done
Extracted libogg-1.3.5.tar.xz
$ ./configure --prefix=/app/workspace --disable-shared --enable-static
$ make -j 2
$ make install

building libvorbis - version 1.3.7
=======================
Downloading https://ftp.osuosl.org/pub/xiph/releases/vorbis/libvorbis-1.3.7.tar.gz as libvorbis-1.3.7.tar.gz
... Done
Extracted libvorbis-1.3.7.tar.gz
$ ./configure --prefix=/app/workspace --with-ogg-libraries=/app/workspace/lib --with-ogg-includes=/app/workspace/include/ --enable-static --disable-shared --disable-oggtest
$ make -j 2
$ make install

building libtheora - version 1.1.1
=======================
Downloading https://ftp.osuosl.org/pub/xiph/releases/theora/libtheora-1.1.1.tar.gz as libtheora-1.1.1.tar.gz
... Done
Extracted libtheora-1.1.1.tar.gz
$ ./configure --prefix=/app/workspace --with-ogg-libraries=/app/workspace/lib --with-ogg-includes=/app/workspace/include/ --with-vorbis-libraries=/app/workspace/lib --with-vorbis-includes=/app/workspace/include/ --enable-static --disable-shared --disable-oggtest --disable-vorbistest --disable-examples --disable-asm --disable-spec
$ make -j 2
$ make install

building fdk_aac - version 2.0.2
=======================
Downloading https://sourceforge.net/projects/opencore-amr/files/fdk-aac/fdk-aac-2.0.2.tar.gz/download?use_mirror=gigenet as fdk-aac-2.0.2.tar.gz
... Done
Extracted fdk-aac-2.0.2.tar.gz
$ ./configure --prefix=/app/workspace --disable-shared --enable-static --enable-pic
$ make -j 2
$ make install

building libtiff - version 4.5.0
=======================
Downloading https://download.osgeo.org/libtiff/tiff-4.5.0.tar.xz as tiff-4.5.0.tar.xz
... Done
Extracted tiff-4.5.0.tar.xz
$ ./configure --prefix=/app/workspace --disable-shared --enable-static --disable-dependency-tracking --disable-lzma --disable-webp --disable-zstd --without-x
$ make -j 2
$ make install

building libpng - version 1.6.39
=======================
Downloading https://gigenet.dl.sourceforge.net/project/libpng/libpng16/1.6.39/libpng-1.6.39.tar.gz as libpng-1.6.39.tar.gz
... Done
Extracted libpng-1.6.39.tar.gz
$ ./configure --prefix=/app/workspace --disable-shared --enable-static
$ make -j 2
$ make install

building libwebp - version 1.2.2
=======================
Downloading https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.2.2.tar.gz as libwebp-1.2.2.tar.gz
... Done
Extracted libwebp-1.2.2.tar.gz
$ ./configure --prefix=/app/workspace --disable-shared --enable-static --disable-dependency-tracking --disable-gl --with-zlib-include=/app/workspace/include/ --with-zlib-lib=/app/workspace/lib
$ cmake -DCMAKE_INSTALL_PREFIX=/app/workspace -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_INSTALL_BINDIR=bin -DCMAKE_INSTALL_INCLUDEDIR=include -DENABLE_SHARED=OFF -DENABLE_STATIC=ON ../
$ make -j 2
$ make install

building libsdl - version 2.26.3
=======================
Downloading https://www.libsdl.org/release/SDL2-2.26.3.tar.gz as SDL2-2.26.3.tar.gz
... Done
Extracted SDL2-2.26.3.tar.gz
$ ./configure --prefix=/app/workspace --disable-shared --enable-static
$ make -j 2
$ make install

building srt - version 1.5.1
=======================
Downloading https://github.com/Haivision/srt/archive/v1.5.1.tar.gz as srt-1.5.1.tar.gz
... Done
Extracted srt-1.5.1.tar.gz
$ cmake . -DCMAKE_INSTALL_PREFIX=/app/workspace -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_INSTALL_BINDIR=bin -DCMAKE_INSTALL_INCLUDEDIR=include -DENABLE_SHARED=OFF -DENABLE_STATIC=ON -DENABLE_APPS=OFF -DUSE_STATIC_LIBSTDCXX=ON
$ make install

building amf - version 1.4.29
=======================
Downloading https://github.com/GPUOpen-LibrariesAndSDKs/AMF/archive/refs/tags/v1.4.29.tar.gz as AMF-1.4.29.tar.gz
... Done
Extracted AMF-1.4.29.tar.gz
$ rm -rf /app/workspace/include/AMF
$ mkdir -p /app/workspace/include/AMF
$ cp -r /app/packages/AMF-1.4.29/AMF-1.4.29/amf/public/include/components /app/packages/AMF-1.4.29/AMF-1.4.29/amf/public/include/core /app/workspace/include/AMF/

building ffmpeg - version 6.0
=======================
Downloading https://github.com/FFmpeg/FFmpeg/archive/refs/heads/release/6.0.tar.gz as FFmpeg-release-6.0.tar.gz
... Done
Extracted FFmpeg-release-6.0.tar.gz
install prefix            /app/workspace
source path               .
C compiler                gcc
C library                 glibc
ARCH                      x86 (generic)
big-endian                no
runtime cpu detection     yes
standalone assembly       yes
x86 assembler             nasm
MMX enabled               yes
MMXEXT enabled            yes
3DNow! enabled            yes
3DNow! extended enabled   yes
SSE enabled               yes
SSSE3 enabled             yes
AESNI enabled             yes
AVX enabled               yes
AVX2 enabled              yes
AVX-512 enabled           yes
AVX-512ICL enabled        yes
XOP enabled               yes
FMA3 enabled              yes
FMA4 enabled              yes
i686 features enabled     yes
CMOV is fast              yes
EBX available             yes
EBP available             yes
debug symbols             no
strip symbols             yes
optimize for size         yes
optimizations             yes
static                    yes
shared                    no
postprocessing support    yes
network support           yes
threading support         pthreads
safe bitstream reader     yes
texi2html enabled         no
perl enabled              yes
pod2man enabled           yes
makeinfo enabled          no
makeinfo supports HTML    no
xmllint enabled           no

External libraries:
iconv                   libsrt                  libx265
libaom                  libsvtav1               libxvid
libdav1d                libtheora               libzimg
libfdk_aac              libvidstab              lv2
libmp3lame              libvorbis               openssl
libopencore_amrnb       libvpx                  sdl2
libopencore_amrwb       libwebp                 zlib
libopus                 libx264

External libraries providing hardware acceleration:
amf                     v4l2_m2m                vaapi

Libraries:
avcodec                 avformat                swresample
avdevice                avutil                  swscale
avfilter                postproc

Programs:
ffmpeg                  ffplay                  ffprobe

Enabled decoders:
aac                     flic                    pfm
aac_fixed               flv                     pgm
aac_latm                fmvc                    pgmyuv
aasc                    fourxm                  pgssub
ac3                     fraps                   pgx
ac3_fixed               frwu                    phm
acelp_kelvin            ftr                     photocd
adpcm_4xm               g2m                     pictor
adpcm_adx               g723_1                  pixlet
adpcm_afc               g729                    pjs
adpcm_agm               gdv                     png
adpcm_aica              gem                     ppm
adpcm_argo              gif                     prores
adpcm_ct                gremlin_dpcm            prosumer
adpcm_dtk               gsm                     psd
adpcm_ea                gsm_ms                  ptx
adpcm_ea_maxis_xa       h261                    qcelp
adpcm_ea_r1             h263                    qdm2
adpcm_ea_r2             h263_v4l2m2m            qdmc
adpcm_ea_r3             h263i                   qdraw
adpcm_ea_xas            h263p                   qoi
adpcm_g722              h264                    qpeg
adpcm_g726              h264_v4l2m2m            qtrle
adpcm_g726le            hap                     r10k
adpcm_ima_acorn         hca                     r210
adpcm_ima_alp           hcom                    ra_144
adpcm_ima_amv           hdr                     ra_288
adpcm_ima_apc           hevc                    ralf
adpcm_ima_apm           hevc_v4l2m2m            rasc
adpcm_ima_cunning       hnm4_video              rawvideo
adpcm_ima_dat4          hq_hqa                  realtext
adpcm_ima_dk3           hqx                     rka
adpcm_ima_dk4           huffyuv                 rl2
adpcm_ima_ea_eacs       hymt                    roq
adpcm_ima_ea_sead       iac                     roq_dpcm
adpcm_ima_iss           idcin                   rpza
adpcm_ima_moflex        idf                     rscc
adpcm_ima_mtf           iff_ilbm                rv10
adpcm_ima_oki           ilbc                    rv20
adpcm_ima_qt            imc                     rv30
adpcm_ima_rad           imm4                    rv40
adpcm_ima_smjpeg        imm5                    s302m
adpcm_ima_ssi           indeo2                  sami
adpcm_ima_wav           indeo3                  sanm
adpcm_ima_ws            indeo4                  sbc
adpcm_ms                indeo5                  scpr
adpcm_mtaf              interplay_acm           screenpresso
adpcm_psx               interplay_dpcm          sdx2_dpcm
adpcm_sbpro_2           interplay_video         sga
adpcm_sbpro_3           ipu                     sgi
adpcm_sbpro_4           jacosub                 sgirle
adpcm_swf               jpeg2000                sheervideo
adpcm_thp               jpegls                  shorten
adpcm_thp_le            jv                      simbiosis_imx
adpcm_vima              kgv1                    sipr
adpcm_xa                kmvc                    siren
adpcm_xmd               lagarith                smackaud
adpcm_yamaha            libaom_av1              smacker
adpcm_zork              libdav1d                smc
agm                     libfdk_aac              smvjpeg
aic                     libopencore_amrnb       snow
alac                    libopencore_amrwb       sol_dpcm
alias_pix               libopus                 sonic
als                     libvorbis               sp5x
amrnb                   libvpx_vp8              speedhq
amrwb                   libvpx_vp9              speex
amv                     loco                    srgc
anm                     lscr                    srt
ansi                    m101                    ssa
anull                   mace3                   stl
apac                    mace6                   subrip
ape                     magicyuv                subviewer
apng                    mdec                    subviewer1
aptx                    media100                sunrast
aptx_hd                 metasound               svq1
arbc                    microdvd                svq3
argo                    mimic                   tak
ass                     misc4                   targa
asv1                    mjpeg                   targa_y216
asv2                    mjpegb                  tdsc
atrac1                  mlp                     text
atrac3                  mmvideo                 theora
atrac3al                mobiclip                thp
atrac3p                 motionpixels            tiertexseqvideo
atrac3pal               movtext                 tiff
atrac9                  mp1                     tmv
aura                    mp1float                truehd
aura2                   mp2                     truemotion1
av1                     mp2float                truemotion2
avrn                    mp3                     truemotion2rt
avrp                    mp3adu                  truespeech
avs                     mp3adufloat             tscc
avui                    mp3float                tscc2
ayuv                    mp3on4                  tta
bethsoftvid             mp3on4float             twinvq
bfi                     mpc7                    txd
bink                    mpc8                    ulti
binkaudio_dct           mpeg1_v4l2m2m           utvideo
binkaudio_rdft          mpeg1video              v210
bintext                 mpeg2_v4l2m2m           v210x
bitpacked               mpeg2video              v308
bmp                     mpeg4                   v408
bmv_audio               mpeg4_v4l2m2m           v410
bmv_video               mpegvideo               vb
bonk                    mpl2                    vble
brender_pix             msa1                    vbn
c93                     mscc                    vc1
cavs                    msmpeg4v1               vc1_v4l2m2m
cbd2_dpcm               msmpeg4v2               vc1image
ccaption                msmpeg4v3               vcr1
cdgraphics              msnsiren                vmdaudio
cdtoons                 msp2                    vmdvideo
cdxl                    msrle                   vmnc
cfhd                    mss1                    vnull
cinepak                 mss2                    vorbis
clearvideo              msvideo1                vp3
cljr                    mszh                    vp4
cllc                    mts2                    vp5
comfortnoise            mv30                    vp6
cook                    mvc1                    vp6a
cpia                    mvc2                    vp6f
cri                     mvdv                    vp7
cscd                    mvha                    vp8
cyuv                    mwsc                    vp8_v4l2m2m
dca                     mxpeg                   vp9
dds                     nellymoser              vp9_v4l2m2m
derf_dpcm               notchlc                 vplayer
dfa                     nuv                     vqa
dfpwm                   on2avc                  vqc
dirac                   opus                    wady_dpcm
dnxhd                   paf_audio               wavarc
dolby_e                 paf_video               wavpack
dpx                     pam                     wbmp
dsd_lsbf                pbm                     wcmv
dsd_lsbf_planar         pcm_alaw                webp
dsd_msbf                pcm_bluray              webvtt
dsd_msbf_planar         pcm_dvd                 wmalossless
dsicinaudio             pcm_f16le               wmapro
dsicinvideo             pcm_f24le               wmav1
dss_sp                  pcm_f32be               wmav2
dst                     pcm_f32le               wmavoice
dvaudio                 pcm_f64be               wmv1
dvbsub                  pcm_f64le               wmv2
dvdsub                  pcm_lxf                 wmv3
dvvideo                 pcm_mulaw               wmv3image
dxa                     pcm_s16be               wnv1
dxtory                  pcm_s16be_planar        wrapped_avframe
dxv                     pcm_s16le               ws_snd1
eac3                    pcm_s16le_planar        xan_dpcm
eacmv                   pcm_s24be               xan_wc3
eamad                   pcm_s24daud             xan_wc4
eatgq                   pcm_s24le               xbin
eatgv                   pcm_s24le_planar        xbm
eatqi                   pcm_s32be               xface
eightbps                pcm_s32le               xl
eightsvx_exp            pcm_s32le_planar        xma1
eightsvx_fib            pcm_s64be               xma2
escape124               pcm_s64le               xpm
escape130               pcm_s8                  xsub
evrc                    pcm_s8_planar           xwd
exr                     pcm_sga                 y41p
fastaudio               pcm_u16be               ylc
ffv1                    pcm_u16le               yop
ffvhuff                 pcm_u24be               yuv4
ffwavesynth             pcm_u24le               zero12v
fic                     pcm_u32be               zerocodec
fits                    pcm_u32le               zlib
flac                    pcm_u8                  zmbv
flashsv                 pcm_vidc
flashsv2                pcx

Enabled encoders:
a64multi                huffyuv                 pcm_vidc
a64multi5               jpeg2000                pcx
aac                     jpegls                  pfm
ac3                     libaom_av1              pgm
ac3_fixed               libfdk_aac              pgmyuv
adpcm_adx               libmp3lame              phm
adpcm_argo              libopencore_amrnb       png
adpcm_g722              libopus                 ppm
adpcm_g726              libsvtav1               prores
adpcm_g726le            libtheora               prores_aw
adpcm_ima_alp           libvorbis               prores_ks
adpcm_ima_amv           libvpx_vp8              qoi
adpcm_ima_apm           libvpx_vp9              qtrle
adpcm_ima_qt            libwebp                 r10k
adpcm_ima_ssi           libwebp_anim            r210
adpcm_ima_wav           libx264                 ra_144
adpcm_ima_ws            libx264rgb              rawvideo
adpcm_ms                libx265                 roq
adpcm_swf               libxvid                 roq_dpcm
adpcm_yamaha            ljpeg                   rpza
alac                    magicyuv                rv10
alias_pix               mjpeg                   rv20
amv                     mjpeg_vaapi             s302m
anull                   mlp                     sbc
apng                    movtext                 sgi
aptx                    mp2                     smc
aptx_hd                 mp2fixed                snow
ass                     mpeg1video              sonic
asv1                    mpeg2_vaapi             sonic_ls
asv2                    mpeg2video              speedhq
av1_amf                 mpeg4                   srt
avrp                    mpeg4_v4l2m2m           ssa
avui                    msmpeg4v2               subrip
ayuv                    msmpeg4v3               sunrast
bitpacked               msvideo1                svq1
bmp                     nellymoser              targa
cfhd                    opus                    text
cinepak                 pam                     tiff
cljr                    pbm                     truehd
comfortnoise            pcm_alaw                tta
dca                     pcm_bluray              ttml
dfpwm                   pcm_dvd                 utvideo
dnxhd                   pcm_f32be               v210
dpx                     pcm_f32le               v308
dvbsub                  pcm_f64be               v408
dvdsub                  pcm_f64le               v410
dvvideo                 pcm_mulaw               vbn
eac3                    pcm_s16be               vc2
exr                     pcm_s16be_planar        vnull
ffv1                    pcm_s16le               vorbis
ffvhuff                 pcm_s16le_planar        vp8_v4l2m2m
fits                    pcm_s24be               vp8_vaapi
flac                    pcm_s24daud             vp9_vaapi
flashsv                 pcm_s24le               wavpack
flashsv2                pcm_s24le_planar        wbmp
flv                     pcm_s32be               webvtt
g723_1                  pcm_s32le               wmav1
gif                     pcm_s32le_planar        wmav2
h261                    pcm_s64be               wmv1
h263                    pcm_s64le               wmv2
h263_v4l2m2m            pcm_s8                  wrapped_avframe
h263p                   pcm_s8_planar           xbm
h264_amf                pcm_u16be               xface
h264_v4l2m2m            pcm_u16le               xsub
h264_vaapi              pcm_u24be               xwd
hdr                     pcm_u24le               y41p
hevc_amf                pcm_u32be               yuv4
hevc_v4l2m2m            pcm_u32le               zlib
hevc_vaapi              pcm_u8                  zmbv

Enabled hwaccels:
av1_vaapi               mjpeg_vaapi             vp8_vaapi
h263_vaapi              mpeg2_vaapi             vp9_vaapi
h264_vaapi              mpeg4_vaapi             wmv3_vaapi
hevc_vaapi              vc1_vaapi

Enabled parsers:
aac                     dvdsub                  opus
aac_latm                flac                    png
ac3                     ftr                     pnm
adx                     g723_1                  qoi
amr                     g729                    rv30
av1                     gif                     rv40
avs2                    gsm                     sbc
avs3                    h261                    sipr
bmp                     h263                    tak
cavsvideo               h264                    vc1
cook                    hdr                     vorbis
cri                     hevc                    vp3
dca                     ipu                     vp8
dirac                   jpeg2000                vp9
dnxhd                   misc4                   webp
dolby_e                 mjpeg                   xbm
dpx                     mlp                     xma
dvaudio                 mpeg4video              xwd
dvbsub                  mpegaudio
dvd_nav                 mpegvideo

Enabled demuxers:
aa                      idf                     pcm_s16be
aac                     iff                     pcm_s16le
aax                     ifv                     pcm_s24be
ac3                     ilbc                    pcm_s24le
ace                     image2                  pcm_s32be
acm                     image2_alias_pix        pcm_s32le
act                     image2_brender_pix      pcm_s8
adf                     image2pipe              pcm_u16be
adp                     image_bmp_pipe          pcm_u16le
ads                     image_cri_pipe          pcm_u24be
adx                     image_dds_pipe          pcm_u24le
aea                     image_dpx_pipe          pcm_u32be
afc                     image_exr_pipe          pcm_u32le
aiff                    image_gem_pipe          pcm_u8
aix                     image_gif_pipe          pcm_vidc
alp                     image_hdr_pipe          pjs
amr                     image_j2k_pipe          pmp
amrnb                   image_jpeg_pipe         pp_bnk
amrwb                   image_jpegls_pipe       pva
anm                     image_jpegxl_pipe       pvf
apac                    image_pam_pipe          qcp
apc                     image_pbm_pipe          r3d
ape                     image_pcx_pipe          rawvideo
apm                     image_pfm_pipe          realtext
apng                    image_pgm_pipe          redspark
aptx                    image_pgmyuv_pipe       rka
aptx_hd                 image_pgx_pipe          rl2
aqtitle                 image_phm_pipe          rm
argo_asf                image_photocd_pipe      roq
argo_brp                image_pictor_pipe       rpl
argo_cvg                image_png_pipe          rsd
asf                     image_ppm_pipe          rso
asf_o                   image_psd_pipe          rtp
ass                     image_qdraw_pipe        rtsp
ast                     image_qoi_pipe          s337m
au                      image_sgi_pipe          sami
av1                     image_sunrast_pipe      sap
avi                     image_svg_pipe          sbc
avr                     image_tiff_pipe         sbg
avs                     image_vbn_pipe          scc
avs2                    image_webp_pipe         scd
avs3                    image_xbm_pipe          sdns
bethsoftvid             image_xpm_pipe          sdp
bfi                     image_xwd_pipe          sdr2
bfstm                   ingenient               sds
bink                    ipmovie                 sdx
binka                   ipu                     segafilm
bintext                 ircam                   ser
bit                     iss                     sga
bitpacked               iv8                     shorten
bmv                     ivf                     siff
boa                     ivr                     simbiosis_imx
bonk                    jacosub                 sln
brstm                   jv                      smacker
c93                     kux                     smjpeg
caf                     kvag                    smush
cavsvideo               laf                     sol
cdg                     live_flv                sox
cdxl                    lmlm4                   spdif
cine                    loas                    srt
codec2                  lrc                     stl
codec2raw               luodat                  str
concat                  lvf                     subviewer
data                    lxf                     subviewer1
daud                    m4v                     sup
dcstr                   matroska                svag
derf                    mca                     svs
dfa                     mcc                     swf
dfpwm                   mgsts                   tak
dhav                    microdvd                tedcaptions
dirac                   mjpeg                   thp
dnxhd                   mjpeg_2000              threedostr
dsf                     mlp                     tiertexseq
dsicin                  mlv                     tmv
dss                     mm                      truehd
dts                     mmf                     tta
dtshd                   mods                    tty
dv                      moflex                  txd
dvbsub                  mov                     ty
dvbtxt                  mp3                     v210
dxa                     mpc                     v210x
ea                      mpc8                    vag
ea_cdata                mpegps                  vc1
eac3                    mpegts                  vc1t
epaf                    mpegtsraw               vividas
ffmetadata              mpegvideo               vivo
filmstrip               mpjpeg                  vmd
fits                    mpl2                    vobsub
flac                    mpsub                   voc
flic                    msf                     vpk
flv                     msnwc_tcp               vplayer
fourxm                  msp                     vqf
frm                     mtaf                    w64
fsb                     mtv                     wady
fwse                    musx                    wav
g722                    mv                      wavarc
g723_1                  mvi                     wc3
g726                    mxf                     webm_dash_manifest
g726le                  mxg                     webvtt
g729                    nc                      wsaud
gdv                     nistsphere              wsd
genh                    nsp                     wsvqa
gif                     nsv                     wtv
gsm                     nut                     wv
gxf                     nuv                     wve
h261                    obu                     xa
h263                    ogg                     xbin
h264                    oma                     xmd
hca                     paf                     xmv
hcom                    pcm_alaw                xvag
hevc                    pcm_f32be               xwma
hls                     pcm_f32le               yop
hnm                     pcm_f64be               yuv4mpegpipe
ico                     pcm_f64le
idcin                   pcm_mulaw

Enabled muxers:
a64                     h263                    pcm_s16le
ac3                     h264                    pcm_s24be
adts                    hash                    pcm_s24le
adx                     hds                     pcm_s32be
aiff                    hevc                    pcm_s32le
alp                     hls                     pcm_s8
amr                     ico                     pcm_u16be
amv                     ilbc                    pcm_u16le
apm                     image2                  pcm_u24be
apng                    image2pipe              pcm_u24le
aptx                    ipod                    pcm_u32be
aptx_hd                 ircam                   pcm_u32le
argo_asf                ismv                    pcm_u8
argo_cvg                ivf                     pcm_vidc
asf                     jacosub                 psp
asf_stream              kvag                    rawvideo
ass                     latm                    rm
ast                     lrc                     roq
au                      m4v                     rso
avi                     matroska                rtp
avif                    matroska_audio          rtp_mpegts
avm2                    md5                     rtsp
avs2                    microdvd                sap
avs3                    mjpeg                   sbc
bit                     mkvtimestamp_v2         scc
caf                     mlp                     segafilm
cavsvideo               mmf                     segment
codec2                  mov                     smjpeg
codec2raw               mp2                     smoothstreaming
crc                     mp3                     sox
dash                    mp4                     spdif
data                    mpeg1system             spx
daud                    mpeg1vcd                srt
dfpwm                   mpeg1video              stream_segment
dirac                   mpeg2dvd                streamhash
dnxhd                   mpeg2svcd               sup
dts                     mpeg2video              swf
dv                      mpeg2vob                tee
eac3                    mpegts                  tg2
f4v                     mpjpeg                  tgp
ffmetadata              mxf                     truehd
fifo                    mxf_d10                 tta
fifo_test               mxf_opatom              ttml
filmstrip               null                    uncodedframecrc
fits                    nut                     vc1
flac                    obu                     vc1t
flv                     oga                     voc
framecrc                ogg                     w64
framehash               ogv                     wav
framemd5                oma                     webm
g722                    opus                    webm_chunk
g723_1                  pcm_alaw                webm_dash_manifest
g726                    pcm_f32be               webp
g726le                  pcm_f32le               webvtt
gif                     pcm_f64be               wsaud
gsm                     pcm_f64le               wtv
gxf                     pcm_mulaw               wv
h261                    pcm_s16be               yuv4mpegpipe

Enabled protocols:
async                   http                    rtmps
cache                   httpproxy               rtmpt
concat                  https                   rtmpte
concatf                 icecast                 rtmpts
crypto                  ipfs_gateway            rtp
data                    ipns_gateway            srtp
fd                      libsrt                  subfile
ffrtmpcrypt             md5                     tcp
ffrtmphttp              mmsh                    tee
file                    mmst                    tls
ftp                     pipe                    udp
gopher                  prompeg                 udplite
gophers                 rtmp                    unix
hls                     rtmpe

Enabled filters:
a3dscope                datascope               pad
abench                  dblur                   pal100bars
abitscope               dcshift                 pal75bars
acompressor             dctdnoiz                palettegen
acontrast               deband                  paletteuse
acopy                   deblock                 pan
acrossfade              decimate                perms
acrossover              deconvolve              perspective
acrusher                dedot                   phase
acue                    deesser                 photosensitivity
addroi                  deflate                 pixdesctest
adeclick                deflicker               pixelize
adeclip                 deinterlace_vaapi       pixscope
adecorrelate            dejudder                pp
adelay                  delogo                  pp7
adenorm                 denoise_vaapi           premultiply
aderivative             derain                  prewitt
adrawgraph              deshake                 procamp_vaapi
adrc                    despill                 pseudocolor
adynamicequalizer       detelecine              psnr
adynamicsmooth          dialoguenhance          pullup
aecho                   dilation                qp
aemphasis               displace                random
aeval                   dnn_classify            readeia608
aevalsrc                dnn_detect              readvitc
aexciter                dnn_processing          realtime
afade                   doubleweave             remap
afdelaysrc              drawbox                 removegrain
afftdn                  drawgraph               removelogo
afftfilt                drawgrid                repeatfields
afifo                   drmeter                 replaygain
afir                    dynaudnorm              reverse
afirsrc                 earwax                  rgbashift
aformat                 ebur128                 rgbtestsrc
afreqshift              edgedetect              roberts
afwtdn                  elbg                    rotate
agate                   entropy                 sab
agraphmonitor           epx                     scale
ahistogram              eq                      scale2ref
aiir                    equalizer               scale_vaapi
aintegral               erosion                 scdet
ainterleave             estdif                  scharr
alatency                exposure                scroll
alimiter                extractplanes           segment
allpass                 extrastereo             select
allrgb                  fade                    selectivecolor
allyuv                  feedback                sendcmd
aloop                   fftdnoiz                separatefields
alphaextract            fftfilt                 setdar
alphamerge              field                   setfield
amerge                  fieldhint               setparams
ametadata               fieldmatch              setpts
amix                    fieldorder              setrange
amovie                  fifo                    setsar
amplify                 fillborders             settb
amultiply               find_rect               sharpness_vaapi
anequalizer             firequalizer            shear
anlmdn                  flanger                 showcqt
anlmf                   floodfill               showcwt
anlms                   format                  showfreqs
anoisesrc               fps                     showinfo
anull                   framepack               showpalette
anullsink               framerate               showspatial
anullsrc                framestep               showspectrum
apad                    freezedetect            showspectrumpic
aperms                  freezeframes            showvolume
aphasemeter             fspp                    showwaves
aphaser                 gblur                   showwavespic
aphaseshift             geq                     shuffleframes
apsyclip                gradfun                 shufflepixels
apulsator               gradients               shuffleplanes
arealtime               graphmonitor            sidechaincompress
aresample               grayworld               sidechaingate
areverse                greyedge                sidedata
arnndn                  guided                  sierpinski
asdr                    haas                    signalstats
asegment                haldclut                signature
aselect                 haldclutsrc             silencedetect
asendcmd                hdcd                    silenceremove
asetnsamples            headphone               sinc
asetpts                 hflip                   sine
asetrate                highpass                siti
asettb                  highshelf               smartblur
ashowinfo               hilbert                 smptebars
asidedata               histeq                  smptehdbars
asoftclip               histogram               sobel
aspectralstats          hqdn3d                  spectrumsynth
asplit                  hqx                     speechnorm
astats                  hstack                  split
astreamselect           hstack_vaapi            spp
asubboost               hsvhold                 sr
asubcut                 hsvkey                  ssim
asupercut               hue                     ssim360
asuperpass              huesaturation           stereo3d
asuperstop              hwdownload              stereotools
atadenoise              hwmap                   stereowiden
atempo                  hwupload                streamselect
atilt                   hysteresis              super2xsai
atrim                   identity                superequalizer
avectorscope            idet                    surround
avgblur                 il                      swaprect
avsynctest              inflate                 swapuv
axcorrelate             interlace               tblend
backgroundkey           interleave              telecine
bandpass                join                    testsrc
bandreject              kerndeint               testsrc2
bass                    kirsch                  thistogram
bbox                    lagfun                  threshold
bench                   latency                 thumbnail
bilateral               lenscorrection          tile
biquad                  life                    tiltshelf
bitplanenoise           limitdiff               tinterlace
blackdetect             limiter                 tlut2
blackframe              loop                    tmedian
blend                   loudnorm                tmidequalizer
blockdetect             lowpass                 tmix
blurdetect              lowshelf                tonemap
bm3d                    lumakey                 tonemap_vaapi
boxblur                 lut                     tpad
bwdif                   lut1d                   transpose
cas                     lut2                    transpose_vaapi
cellauto                lut3d                   treble
channelmap              lutrgb                  tremolo
channelsplit            lutyuv                  trim
chorus                  lv2                     unpremultiply
chromahold              mandelbrot              unsharp
chromakey               maskedclamp             untile
chromanr                maskedmax               v360
chromashift             maskedmerge             vaguedenoiser
ciescope                maskedmin               varblur
codecview               maskedthreshold         vectorscope
color                   maskfun                 vflip
colorbalance            mcompand                vfrdet
colorchannelmixer       median                  vibrance
colorchart              mergeplanes             vibrato
colorcontrast           mestimate               vidstabdetect
colorcorrect            metadata                vidstabtransform
colorhold               midequalizer            vif
colorize                minterpolate            vignette
colorkey                mix                     virtualbass
colorlevels             monochrome              vmafmotion
colormap                morpho                  volume
colormatrix             movie                   volumedetect
colorspace              mpdecimate              vstack
colorspectrum           mptestsrc               vstack_vaapi
colortemperature        msad                    w3fdif
compand                 multiply                waveform
compensationdelay       negate                  weave
concat                  nlmeans                 xbr
convolution             nnedi                   xcorrelate
convolve                noformat                xfade
copy                    noise                   xmedian
corr                    normalize               xstack
cover_rect              null                    xstack_vaapi
crop                    nullsink                yadif
cropdetect              nullsrc                 yaepblur
crossfeed               oscilloscope            yuvtestsrc
crystalizer             overlay                 zoompan
cue                     overlay_vaapi           zscale
curves                  owdenoise

Enabled bsfs:
aac_adtstoasc           h264_redundant_pps      opus_metadata
av1_frame_merge         hapqa_extract           pcm_rechunk
av1_frame_split         hevc_metadata           pgs_frame_merge
av1_metadata            hevc_mp4toannexb        prores_metadata
chomp                   imx_dump_header         remove_extradata
dca_core                media100_to_mjpegb      setts
dts2pts                 mjpeg2jpeg              text2movsub
dump_extradata          mjpega_dump_header      trace_headers
dv_error_marker         mov2textsub             truehd_core
eac3_core               mp3_header_decompress   vp9_metadata
extract_extradata       mpeg2_metadata          vp9_raw_reorder
filter_units            mpeg4_unpack_bframes    vp9_superframe
h264_metadata           noise                   vp9_superframe_split
h264_mp4toannexb        null

Enabled indevs:
fbdev                   oss
lavfi                   v4l2

Enabled outdevs:
fbdev                   sdl2
oss                     v4l2

License: nonfree and unredistributable
$ make -j 2
$ make install

Building done. The following binaries can be found here:
- ffmpeg: /app/workspace/bin/ffmpeg
- ffprobe: /app/workspace/bin/ffprobe
- ffplay: /app/workspace/bin/ffplay

Install these binaries to your /usr/local/bin folder? Existing binaries will be replaced. [Y/n] y
Password:
Done. FFmpeg is now installed to your system.
```

Other Projects Of Mine
------------

- [Pushover CLI Client](https://github.com/markus-perl/pushover-cli)
- [Gender API](https://gender-api.com): [Genderize A Name](https://gender-api.com)
- [Gender API Client PHP](https://github.com/markus-perl/gender-api-client)
- [Gender API Client NPM](https://github.com/markus-perl/gender-api-client-npm)
- [Genderize Names](https://www.youtube.com/watch?v=2SLIAguaygo)
- [Genderize API](https://gender-api.io)
