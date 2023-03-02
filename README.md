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
$ docker build --tag=ffmpeg:cuda-$DIST -f cuda-ubunu.dockerfile --build-arg .
```

Build an `export.dockerfile` that copies only what you need from the image you just built as follows. When running,
move the library in the lib to a location where the linker can find it or set the `LD_LIBRARY_PATH`. Since we have
matched the operating system and version, it should work well with dynamic links. If it doesn't work, edit
the `export.dockerfile` and copy the necessary libraries and try again.

```bash
$ docker build --output type=local,dest=build -f export.dockerfile --build-arg DIST=$DIST .
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
cargo not installed. rav1e encoder will not be available.

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
