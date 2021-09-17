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
other than Debian 10 and macOS 11.x, because I don't have the resources or time to maintain different systems.

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
export DOCKER_BUILDKIT=1

## Set the DIST (`ubuntu` or `centos`) and VER (ubuntu: `16.04` , `18.04`, `20.04` or centos: `7`, `8`) environment variables to select the preferred Docker base image.
$ export DIST=centos
$ export VER=8

## Start the build
$ docker build --tag=ffmpeg:cuda-$DIST -f cuda-$DIST.dockerfile --build-arg VER=$VER .
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

building yasm
=======================
Downloading https://github.com/yasm/yasm/releases/download/v1.3.0/yasm-1.3.0.tar.gz as yasm-1.3.0.tar.gz
... Done
Extracted yasm-1.3.0.tar.gz
$ ./configure --prefix=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace
$ make -j 12
$ make install

building nasm
=======================
Downloading https://www.nasm.us/pub/nasm/releasebuilds/2.15.05/nasm-2.15.05.tar.xz as nasm-2.15.05.tar.xz
... Done
Extracted nasm-2.15.05.tar.xz
$ ./configure --prefix=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace --disable-shared --enable-static
$ make -j 12
$ make install

building pkg-config
=======================
Downloading https://pkgconfig.freedesktop.org/releases/pkg-config-0.29.2.tar.gz as pkg-config-0.29.2.tar.gz
... Done
Extracted pkg-config-0.29.2.tar.gz
$ ./configure --silent --prefix=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace --with-pc-path=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace/lib/pkgconfig --with-internal-glib
$ make -j 12
$ make install

building zlib
=======================
Downloading https://www.zlib.net/zlib-1.2.11.tar.gz as zlib-1.2.11.tar.gz
... Done
Extracted zlib-1.2.11.tar.gz
$ ./configure --static --prefix=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace
$ make -j 12
$ make install

building openssl
=======================
Downloading https://www.openssl.org/source/openssl-1.1.1h.tar.gz as openssl-1.1.1h.tar.gz
... Done
Extracted openssl-1.1.1h.tar.gz
$ ./config --prefix=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace --openssldir=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace --with-zlib-include=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace/include/ --with-zlib-lib=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace/lib no-shared zlib
$ make -j 12
$ make install

building cmake
=======================
Downloading https://cmake.org/files/v3.18/cmake-3.18.4.tar.gz as cmake-3.18.4.tar.gz
... Done
Extracted cmake-3.18.4.tar.gz
$ ./configure --prefix=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace --system-zlib
$ make -j 12
$ make install

building x264
=======================
Downloading https://code.videolan.org/videolan/x264/-/archive/stable/x264-stable.tar.bz2 as x264-stable.tar.bz2
... Done
Extracted x264-stable.tar.bz2
$ ./configure --prefix=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace --enable-static --enable-pic
$ make -j 12
$ make install
$ make install-lib-static

building x265
=======================
Downloading https://github.com/videolan/x265/archive/Release_3.5.tar.gz as x265-3.5.tar.gz
... Done
Extracted x265-3.5.tar.gz
$ cmake -DCMAKE_INSTALL_PREFIX=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace -DENABLE_SHARED=off -DBUILD_SHARED_LIBS=OFF ../../source
$ make -j 12
$ make install

building libvpx
=======================
Downloading https://github.com/webmproject/libvpx/archive/v1.9.0.tar.gz as libvpx-1.9.0.tar.gz
... Done
Extracted libvpx-1.9.0.tar.gz
Applying Darwin patch
$ ./configure --prefix=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace --disable-unit-tests --disable-shared --as=yasm
$ make -j 12
$ make install

building xvidcore
=======================
Downloading https://downloads.xvid.com/downloads/xvidcore-1.3.7.tar.gz as xvidcore-1.3.7.tar.gz
... Done
Extracted xvidcore-1.3.7.tar.gz
$ ./configure --prefix=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace --disable-shared --enable-static
$ make -j 12
$ make install
$ rm /Volumes/Daten/dev/mac/ffmpeg-build-script/workspace/lib/libxvidcore.4.dylib

building vid_stab
=======================
Downloading https://github.com/georgmartius/vid.stab/archive/v1.1.0.tar.gz as vid.stab-1.1.0.tar.gz
... Done
Extracted vid.stab-1.1.0.tar.gz
$ cmake -DBUILD_SHARED_LIBS=OFF -DCMAKE_INSTALL_PREFIX=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace -DUSE_OMP=OFF -DENABLE_SHARED=off .
$ make
$ make install

building av1
=======================
Downloading https://aomedia.googlesource.com/aom/+archive/430d58446e1f71ec2283af0d6c1879bc7a3553dd.tar.gz as av1.tar.gz
... Done
Extracted av1.tar.gz
$ cmake -DENABLE_TESTS=0 -DCMAKE_INSTALL_PREFIX=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace -DCMAKE_INSTALL_LIBDIR=lib /Volumes/Daten/dev/mac/ffmpeg-build-script/packages/av1
$ make -j 12
$ make install

building opencore
=======================
Downloading https://deac-riga.dl.sourceforge.net/project/opencore-amr/opencore-amr/opencore-amr-0.1.5.tar.gz as opencore-amr-0.1.5.tar.gz
... Done
Extracted opencore-amr-0.1.5.tar.gz
$ ./configure --prefix=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace --disable-shared --enable-static
$ make -j 12
$ make install

building lame
=======================
Downloading https://netcologne.dl.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz as lame-3.100.tar.gz
... Done
Extracted lame-3.100.tar.gz
$ ./configure --prefix=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace --disable-shared --enable-static
$ make -j 12
$ make install

building opus
=======================
Downloading https://archive.mozilla.org/pub/opus/opus-1.3.1.tar.gz as opus-1.3.1.tar.gz
... Done
Extracted opus-1.3.1.tar.gz
$ ./configure --prefix=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace --disable-shared --enable-static
$ make -j 12
$ make install

building libogg
=======================
Downloading https://ftp.osuosl.org/pub/xiph/releases/ogg/libogg-1.3.3.tar.gz as libogg-1.3.3.tar.gz
... Done
Extracted libogg-1.3.3.tar.gz
$ ./configure --prefix=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace --disable-shared --enable-static
$ make -j 12
$ make install

building libvorbis
=======================
Downloading https://ftp.osuosl.org/pub/xiph/releases/vorbis/libvorbis-1.3.6.tar.gz as libvorbis-1.3.6.tar.gz
... Done
Extracted libvorbis-1.3.6.tar.gz
$ ./configure --prefix=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace --with-ogg-libraries=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace/lib --with-ogg-includes=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace/include/ --enable-static --disable-shared --disable-oggtest
$ make -j 12
$ make install

building libtheora
=======================
Downloading https://ftp.osuosl.org/pub/xiph/releases/theora/libtheora-1.1.1.tar.gz as libtheora-1.1.1.tar.gz
... Done
Extracted libtheora-1.1.1.tar.gz
$ ./configure --prefix=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace --with-ogg-libraries=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace/lib --with-ogg-includes=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace/include/ --with-vorbis-libraries=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace/lib --with-vorbis-includes=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace/include/ --enable-static --disable-shared --disable-oggtest --disable-vorbistest --disable-examples --disable-asm --disable-spec
$ make -j 12
$ make install

building fdk_aac
=======================
Downloading https://sourceforge.net/projects/opencore-amr/files/fdk-aac/fdk-aac-2.0.1.tar.gz/download?use_mirror=gigenet as fdk-aac-2.0.1.tar.gz
... Done
Extracted fdk-aac-2.0.1.tar.gz
$ ./configure --prefix=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace --disable-shared --enable-static
$ make -j 12
$ make install

building libwebp
=======================
Downloading https://github.com/webmproject/libwebp/archive/v1.1.0.tar.gz as libwebp-1.1.0.tar.gz
... Done
Extracted libwebp-1.1.0.tar.gz
$ cmake -DCMAKE_INSTALL_PREFIX=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_INSTALL_BINDIR=bin -DCMAKE_INSTALL_INCLUDEDIR=include -DENABLE_SHARED=OFF -DENABLE_STATIC=ON ../
$ make -j 12
$ make install

building libsdl
=======================
Downloading https://www.libsdl.org/release/SDL2-2.0.12.tar.gz as SDL2-2.0.12.tar.gz
... Done
Extracted SDL2-2.0.12.tar.gz
$ ./configure --prefix=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace --disable-shared --enable-static
$ make -j 12
$ make install

building srt
=======================
Downloading https://github.com/Haivision/srt/archive/v1.4.1.tar.gz as srt-1.4.1.tar.gz
... Done
Extracted srt-1.4.1.tar.gz
$ cmake . -DCMAKE_INSTALL_PREFIX=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_INSTALL_BINDIR=bin -DCMAKE_INSTALL_INCLUDEDIR=include -DENABLE_SHARED=OFF -DENABLE_STATIC=ON -DENABLE_APPS=OFF -DUSE_STATIC_LIBSTDCXX=ON
$ make install

building ffmpeg
=======================
Downloading https://ffmpeg.org/releases/ffmpeg-4.3.1.tar.bz2 as ffmpeg-4.3.1.tar.bz2
... Done
Extracted ffmpeg-4.3.1.tar.bz2
install prefix            /Volumes/Daten/dev/mac/ffmpeg-build-script/workspace
source path               .
C compiler                gcc
C library
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
makeinfo enabled          yes
makeinfo supports HTML    no

External libraries:
appkit                  coreimage               libfdk_aac              libopencore_amrwb       libtheora               libvpx                  libx265                 sdl2
avfoundation            iconv                   libmp3lame              libopus                 libvidstab              libwebp                 libxvid                 zlib
bzlib                   libaom                  libopencore_amrnb       libsrt                  libvorbis               libx264                 openssl

External libraries providing hardware acceleration:
audiotoolbox            videotoolbox

Libraries:
avcodec                 avdevice                avfilter                avformat                avutil                  postproc                swresample              swscale

Programs:
ffmpeg                  ffplay                  ffprobe

Enabled decoders:
aac                     adpcm_ima_wav           avrp                    dsicinvideo             gsm                     libopus                 msmpeg4v3               pcm_s32be               realtext                targa_y216              vqa
aac_at                  adpcm_ima_ws            avs                     dss_sp                  gsm_ms                  libvorbis               msrle                   pcm_s32le               rl2                     tdsc                    wavpack
aac_fixed               adpcm_ms                avui                    dst                     gsm_ms_at               libvpx_vp8              mss1                    pcm_s32le_planar        roq                     text                    wcmv
aac_latm                adpcm_mtaf              ayuv                    dvaudio                 h261                    libvpx_vp9              mss2                    pcm_s64be               roq_dpcm                theora                  webp
aasc                    adpcm_psx               bethsoftvid             dvbsub                  h263                    loco                    msvideo1                pcm_s64le               rpza                    thp                     webvtt
ac3                     adpcm_sbpro_2           bfi                     dvdsub                  h263i                   lscr                    mszh                    pcm_s8                  rscc                    tiertexseqvideo         wmalossless
ac3_at                  adpcm_sbpro_3           bink                    dvvideo                 h263p                   m101                    mts2                    pcm_s8_planar           rv10                    tiff                    wmapro
ac3_fixed               adpcm_sbpro_4           binkaudio_dct           dxa                     h264                    mace3                   mv30                    pcm_u16be               rv20                    tmv                     wmav1
acelp_kelvin            adpcm_swf               binkaudio_rdft          dxtory                  hap                     mace6                   mvc1                    pcm_u16le               rv30                    truehd                  wmav2
adpcm_4xm               adpcm_thp               bintext                 dxv                     hca                     magicyuv                mvc2                    pcm_u24be               rv40                    truemotion1             wmavoice
adpcm_adx               adpcm_thp_le            bitpacked               eac3                    hcom                    mdec                    mvdv                    pcm_u24le               s302m                   truemotion2             wmv1
adpcm_afc               adpcm_vima              bmp                     eac3_at                 hevc                    metasound               mvha                    pcm_u32be               sami                    truemotion2rt           wmv2
adpcm_agm               adpcm_xa                bmv_audio               eacmv                   hnm4_video              microdvd                mwsc                    pcm_u32le               sanm                    truespeech              wmv3
adpcm_aica              adpcm_yamaha            bmv_video               eamad                   hq_hqa                  mimic                   mxpeg                   pcm_u8                  sbc                     tscc                    wmv3image
adpcm_argo              adpcm_zork              brender_pix             eatgq                   hqx                     mjpeg                   nellymoser              pcm_vidc                scpr                    tscc2                   wnv1
adpcm_ct                agm                     c93                     eatgv                   huffyuv                 mjpegb                  notchlc                 pcx                     screenpresso            tta                     wrapped_avframe
adpcm_dtk               aic                     cavs                    eatqi                   hymt                    mlp                     nuv                     pfm                     sdx2_dpcm               twinvq                  ws_snd1
adpcm_ea                alac                    ccaption                eightbps                iac                     mmvideo                 on2avc                  pgm                     sgi                     txd                     xan_dpcm
adpcm_ea_maxis_xa       alac_at                 cdgraphics              eightsvx_exp            idcin                   motionpixels            opus                    pgmyuv                  sgirle                  ulti                    xan_wc3
adpcm_ea_r1             alias_pix               cdtoons                 eightsvx_fib            idf                     movtext                 paf_audio               pgssub                  sheervideo              utvideo                 xan_wc4
adpcm_ea_r2             als                     cdxl                    escape124               iff_ilbm                mp1                     paf_video               pictor                  shorten                 v210                    xbin
adpcm_ea_r3             amr_nb_at               cfhd                    escape130               ilbc                    mp1_at                  pam                     pixlet                  sipr                    v210x                   xbm
adpcm_ea_xas            amrnb                   cinepak                 evrc                    ilbc_at                 mp1float                pbm                     pjs                     siren                   v308                    xface
adpcm_g722              amrwb                   clearvideo              exr                     imc                     mp2                     pcm_alaw                png                     smackaud                v408                    xl
adpcm_g726              amv                     cljr                    ffv1                    imm4                    mp2_at                  pcm_alaw_at             ppm                     smacker                 v410                    xma1
adpcm_g726le            anm                     cllc                    ffvhuff                 imm5                    mp2float                pcm_bluray              prores                  smc                     vb                      xma2
adpcm_ima_alp           ansi                    comfortnoise            ffwavesynth             indeo2                  mp3                     pcm_dvd                 prosumer                smvjpeg                 vble                    xpm
adpcm_ima_amv           ape                     cook                    fic                     indeo3                  mp3_at                  pcm_f16le               psd                     snow                    vc1                     xsub
adpcm_ima_apc           apng                    cpia                    fits                    indeo4                  mp3adu                  pcm_f24le               ptx                     sol_dpcm                vc1image                xwd
adpcm_ima_apm           aptx                    cscd                    flac                    indeo5                  mp3adufloat             pcm_f32be               qcelp                   sonic                   vcr1                    y41p
adpcm_ima_cunning       aptx_hd                 cyuv                    flashsv                 interplay_acm           mp3float                pcm_f32le               qdm2                    sp5x                    vmdaudio                ylc
adpcm_ima_dat4          arbc                    dca                     flashsv2                interplay_dpcm          mp3on4                  pcm_f64be               qdm2_at                 speedhq                 vmdvideo                yop
adpcm_ima_dk3           ass                     dds                     flic                    interplay_video         mp3on4float             pcm_f64le               qdmc                    srgc                    vmnc                    yuv4
adpcm_ima_dk4           asv1                    derf_dpcm               flv                     jacosub                 mpc7                    pcm_lxf                 qdmc_at                 srt                     vorbis                  zero12v
adpcm_ima_ea_eacs       asv2                    dfa                     fmvc                    jpeg2000                mpc8                    pcm_mulaw               qdraw                   ssa                     vp3                     zerocodec
adpcm_ima_ea_sead       atrac1                  dirac                   fourxm                  jpegls                  mpeg1video              pcm_mulaw_at            qpeg                    stl                     vp4                     zlib
adpcm_ima_iss           atrac3                  dnxhd                   fraps                   jv                      mpeg2video              pcm_s16be               qtrle                   subrip                  vp5                     zmbv
adpcm_ima_mtf           atrac3al                dolby_e                 frwu                    kgv1                    mpeg4                   pcm_s16be_planar        r10k                    subviewer               vp6
adpcm_ima_oki           atrac3p                 dpx                     g2m                     kmvc                    mpegvideo               pcm_s16le               r210                    subviewer1              vp6a
adpcm_ima_qt            atrac3pal               dsd_lsbf                g723_1                  lagarith                mpl2                    pcm_s16le_planar        ra_144                  sunrast                 vp6f
adpcm_ima_qt_at         atrac9                  dsd_lsbf_planar         g729                    libaom_av1              msa1                    pcm_s24be               ra_288                  svq1                    vp7
adpcm_ima_rad           aura                    dsd_msbf                gdv                     libfdk_aac              mscc                    pcm_s24daud             ralf                    svq3                    vp8
adpcm_ima_smjpeg        aura2                   dsd_msbf_planar         gif                     libopencore_amrnb       msmpeg4v1               pcm_s24le               rasc                    tak                     vp9
adpcm_ima_ssi           avrn                    dsicinaudio             gremlin_dpcm            libopencore_amrwb       msmpeg4v2               pcm_s24le_planar        rawvideo                targa                   vplayer

Enabled encoders:
a64multi                alac_at                 dnxhd                   h263p                   libwebp_anim            msvideo1                pcm_s16le_planar        pcm_u32le               roq_dpcm                truehd                  xface
a64multi5               alias_pix               dpx                     h264_videotoolbox       libx264                 nellymoser              pcm_s24be               pcm_u8                  rv10                    tta                     xsub
aac                     amv                     dvbsub                  hevc_videotoolbox       libx264rgb              opus                    pcm_s24daud             pcm_vidc                rv20                    utvideo                 xwd
aac_at                  apng                    dvdsub                  huffyuv                 libx265                 pam                     pcm_s24le               pcx                     s302m                   v210                    y41p
ac3                     aptx                    dvvideo                 ilbc_at                 libxvid                 pbm                     pcm_s24le_planar        pgm                     sbc                     v308                    yuv4
ac3_fixed               aptx_hd                 eac3                    jpeg2000                ljpeg                   pcm_alaw                pcm_s32be               pgmyuv                  sgi                     v408                    zlib
adpcm_adx               ass                     ffv1                    jpegls                  magicyuv                pcm_alaw_at             pcm_s32le               png                     snow                    v410                    zmbv
adpcm_g722              asv1                    ffvhuff                 libaom_av1              mjpeg                   pcm_dvd                 pcm_s32le_planar        ppm                     sonic                   vc2
adpcm_g726              asv2                    fits                    libfdk_aac              mlp                     pcm_f32be               pcm_s64be               prores                  sonic_ls                vorbis
adpcm_g726le            avrp                    flac                    libmp3lame              movtext                 pcm_f32le               pcm_s64le               prores_aw               srt                     wavpack
adpcm_ima_qt            avui                    flashsv                 libopencore_amrnb       mp2                     pcm_f64be               pcm_s8                  prores_ks               ssa                     webvtt
adpcm_ima_ssi           ayuv                    flashsv2                libopus                 mp2fixed                pcm_f64le               pcm_s8_planar           qtrle                   subrip                  wmav1
adpcm_ima_wav           bmp                     flv                     libtheora               mpeg1video              pcm_mulaw               pcm_u16be               r10k                    sunrast                 wmav2
adpcm_ms                cinepak                 g723_1                  libvorbis               mpeg2video              pcm_mulaw_at            pcm_u16le               r210                    svq1                    wmv1
adpcm_swf               cljr                    gif                     libvpx_vp8              mpeg4                   pcm_s16be               pcm_u24be               ra_144                  targa                   wmv2
adpcm_yamaha            comfortnoise            h261                    libvpx_vp9              msmpeg4v2               pcm_s16be_planar        pcm_u24le               rawvideo                text                    wrapped_avframe
alac                    dca                     h263                    libwebp                 msmpeg4v3               pcm_s16le               pcm_u32be               roq                     tiff                    xbm

Enabled hwaccels:
h263_videotoolbox       h264_videotoolbox       hevc_videotoolbox       mpeg1_videotoolbox      mpeg2_videotoolbox      mpeg4_videotoolbox

Enabled parsers:
aac                     avs2                    dirac                   dvd_nav                 gif                     hevc                    mpegaudio               rv30                    vc1                     webp
aac_latm                bmp                     dnxhd                   dvdsub                  gsm                     jpeg2000                mpegvideo               rv40                    vorbis                  xma
ac3                     cavsvideo               dpx                     flac                    h261                    mjpeg                   opus                    sbc                     vp3
adx                     cook                    dvaudio                 g723_1                  h263                    mlp                     png                     sipr                    vp8
av1                     dca                     dvbsub                  g729                    h264                    mpeg4video              pnm                     tak                     vp9

Enabled demuxers:
aa                      ass                     dcstr                   fwse                    image2pipe              ircam                   mpc8                    pcm_f32le               redspark                sox                     vmd
aac                     ast                     derf                    g722                    image_bmp_pipe          iss                     mpegps                  pcm_f64be               rl2                     spdif                   vobsub
ac3                     au                      dfa                     g723_1                  image_dds_pipe          iv8                     mpegts                  pcm_f64le               rm                      srt                     voc
acm                     av1                     dhav                    g726                    image_dpx_pipe          ivf                     mpegtsraw               pcm_mulaw               roq                     stl                     vpk
act                     avi                     dirac                   g726le                  image_exr_pipe          ivr                     mpegvideo               pcm_s16be               rpl                     str                     vplayer
adf                     avr                     dnxhd                   g729                    image_gif_pipe          jacosub                 mpjpeg                  pcm_s16le               rsd                     subviewer               vqf
adp                     avs                     dsf                     gdv                     image_j2k_pipe          jv                      mpl2                    pcm_s24be               rso                     subviewer1              w64
ads                     avs2                    dsicin                  genh                    image_jpeg_pipe         kux                     mpsub                   pcm_s24le               rtp                     sup                     wav
adx                     bethsoftvid             dss                     gif                     image_jpegls_pipe       kvag                    msf                     pcm_s32be               rtsp                    svag                    wc3
aea                     bfi                     dts                     gsm                     image_pam_pipe          live_flv                msnwc_tcp               pcm_s32le               s337m                   swf                     webm_dash_manifest
afc                     bfstm                   dtshd                   gxf                     image_pbm_pipe          lmlm4                   mtaf                    pcm_s8                  sami                    tak                     webvtt
aiff                    bink                    dv                      h261                    image_pcx_pipe          loas                    mtv                     pcm_u16be               sap                     tedcaptions             wsaud
aix                     bintext                 dvbsub                  h263                    image_pgm_pipe          lrc                     musx                    pcm_u16le               sbc                     thp                     wsd
alp                     bit                     dvbtxt                  h264                    image_pgmyuv_pipe       lvf                     mv                      pcm_u24be               sbg                     threedostr              wsvqa
amr                     bmv                     dxa                     hca                     image_pictor_pipe       lxf                     mvi                     pcm_u24le               scc                     tiertexseq              wtv
amrnb                   boa                     ea                      hcom                    image_png_pipe          m4v                     mxf                     pcm_u32be               sdp                     tmv                     wv
amrwb                   brstm                   ea_cdata                hevc                    image_ppm_pipe          matroska                mxg                     pcm_u32le               sdr2                    truehd                  wve
anm                     c93                     eac3                    hls                     image_psd_pipe          mgsts                   nc                      pcm_u8                  sds                     tta                     xa
apc                     caf                     epaf                    hnm                     image_qdraw_pipe        microdvd                nistsphere              pcm_vidc                sdx                     tty                     xbin
ape                     cavsvideo               ffmetadata              ico                     image_sgi_pipe          mjpeg                   nsp                     pjs                     segafilm                txd                     xmv
apm                     cdg                     filmstrip               idcin                   image_sunrast_pipe      mjpeg_2000              nsv                     pmp                     ser                     ty                      xvag
apng                    cdxl                    fits                    idf                     image_svg_pipe          mlp                     nut                     pp_bnk                  shorten                 v210                    xwma
aptx                    cine                    flac                    iff                     image_tiff_pipe         mlv                     nuv                     pva                     siff                    v210x                   yop
aptx_hd                 codec2                  flic                    ifv                     image_webp_pipe         mm                      ogg                     pvf                     sln                     vag                     yuv4mpegpipe
aqtitle                 codec2raw               flv                     ilbc                    image_xpm_pipe          mmf                     oma                     qcp                     smacker                 vc1
argo_asf                concat                  fourxm                  image2                  image_xwd_pipe          mov                     paf                     r3d                     smjpeg                  vc1t
asf                     data                    frm                     image2_alias_pix        ingenient               mp3                     pcm_alaw                rawvideo                smush                   vividas
asf_o                   daud                    fsb                     image2_brender_pix      ipmovie                 mpc                     pcm_f32be               realtext                sol                     vivo

Enabled muxers:
a64                     avm2                    eac3                    g726le                  ipod                    mlp                     mxf                     pcm_mulaw               pcm_vidc                smjpeg                  uncodedframecrc
ac3                     avs2                    f4v                     gif                     ircam                   mmf                     mxf_d10                 pcm_s16be               psp                     smoothstreaming         vc1
adts                    bit                     ffmetadata              gsm                     ismv                    mov                     mxf_opatom              pcm_s16le               rawvideo                sox                     vc1t
adx                     caf                     fifo                    gxf                     ivf                     mp2                     null                    pcm_s24be               rm                      spdif                   voc
aiff                    cavsvideo               fifo_test               h261                    jacosub                 mp3                     nut                     pcm_s24le               roq                     spx                     w64
amr                     codec2                  filmstrip               h263                    kvag                    mp4                     oga                     pcm_s32be               rso                     srt                     wav
apng                    codec2raw               fits                    h264                    latm                    mpeg1system             ogg                     pcm_s32le               rtp                     stream_segment          webm
aptx                    crc                     flac                    hash                    lrc                     mpeg1vcd                ogv                     pcm_s8                  rtp_mpegts              streamhash              webm_chunk
aptx_hd                 dash                    flv                     hds                     m4v                     mpeg1video              oma                     pcm_u16be               rtsp                    sup                     webm_dash_manifest
asf                     data                    framecrc                hevc                    matroska                mpeg2dvd                opus                    pcm_u16le               sap                     swf                     webp
asf_stream              daud                    framehash               hls                     matroska_audio          mpeg2svcd               pcm_alaw                pcm_u24be               sbc                     tee                     webvtt
ass                     dirac                   framemd5                ico                     md5                     mpeg2video              pcm_f32be               pcm_u24le               scc                     tg2                     wtv
ast                     dnxhd                   g722                    ilbc                    microdvd                mpeg2vob                pcm_f32le               pcm_u32be               segafilm                tgp                     wv
au                      dts                     g723_1                  image2                  mjpeg                   mpegts                  pcm_f64be               pcm_u32le               segment                 truehd                  yuv4mpegpipe
avi                     dv                      g726                    image2pipe              mkvtimestamp_v2         mpjpeg                  pcm_f64le               pcm_u8                  singlejpeg              tta

Enabled protocols:
async                   data                    ftp                     httpproxy               md5                     prompeg                 rtmpt                   srtp                    tls
cache                   ffrtmpcrypt             gopher                  https                   mmsh                    rtmp                    rtmpte                  subfile                 udp
concat                  ffrtmphttp              hls                     icecast                 mmst                    rtmpe                   rtmpts                  tcp                     udplite
crypto                  file                    http                    libsrt                  pipe                    rtmps                   rtp                     tee                     unix

Enabled filters:
abench                  alphaextract            atadenoise              colorspace              doubleweave             gblur                   loudnorm                nullsrc                 rotate                  sinc                    trim
abitscope               alphamerge              atempo                  compand                 drawbox                 geq                     lowpass                 oscilloscope            sab                     sine                    unpremultiply
acompressor             amerge                  atrim                   compensationdelay       drawgraph               gradfun                 lowshelf                overlay                 scale                   smartblur               unsharp
acontrast               ametadata               avectorscope            concat                  drawgrid                gradients               lumakey                 owdenoise               scale2ref               smptebars               untile
acopy                   amix                    avgblur                 convolution             drmeter                 graphmonitor            lut                     pad                     scdet                   smptehdbars             uspp
acrossfade              amovie                  axcorrelate             convolve                dynaudnorm              greyedge                lut1d                   pal100bars              scroll                  sobel                   v360
acrossover              amplify                 bandpass                copy                    earwax                  haas                    lut2                    pal75bars               select                  spectrumsynth           vaguedenoiser
acrusher                amultiply               bandreject              coreimage               ebur128                 haldclut                lut3d                   palettegen              selectivecolor          split                   vectorscope
acue                    anequalizer             bass                    coreimagesrc            edgedetect              haldclutsrc             lutrgb                  paletteuse              sendcmd                 spp                     vflip
addroi                  anlmdn                  bbox                    cover_rect              elbg                    hdcd                    lutyuv                  pan                     separatefields          sr                      vfrdet
adeclick                anlms                   bench                   crop                    entropy                 headphone               mandelbrot              perms                   setdar                  ssim                    vibrance
adeclip                 anoisesrc               bilateral               cropdetect              eq                      hflip                   maskedclamp             perspective             setfield                stereo3d                vibrato
adelay                  anull                   biquad                  crossfeed               equalizer               highpass                maskedmax               phase                   setparams               stereotools             vidstabdetect
aderivative             anullsink               bitplanenoise           crystalizer             erosion                 highshelf               maskedmerge             photosensitivity        setpts                  stereowiden             vidstabtransform
adrawgraph              anullsrc                blackdetect             cue                     extractplanes           hilbert                 maskedmin               pixdesctest             setrange                streamselect            vignette
aecho                   apad                    blackframe              curves                  extrastereo             histeq                  maskedthreshold         pixscope                setsar                  super2xsai              vmafmotion
aemphasis               aperms                  blend                   datascope               fade                    histogram               maskfun                 pp                      settb                   superequalizer          volume
aeval                   aphasemeter             bm3d                    dblur                   fftdnoiz                hqdn3d                  mcdeint                 pp7                     showcqt                 surround                volumedetect
aevalsrc                aphaser                 boxblur                 dcshift                 fftfilt                 hqx                     mcompand                premultiply             showfreqs               swaprect                vstack
afade                   apulsator               bwdif                   dctdnoiz                field                   hstack                  median                  prewitt                 showinfo                swapuv                  w3fdif
afftdn                  arealtime               cas                     deband                  fieldhint               hue                     mergeplanes             pseudocolor             showpalette             tblend                  waveform
afftfilt                aresample               cellauto                deblock                 fieldmatch              hwdownload              mestimate               psnr                    showspatial             telecine                weave
afifo                   areverse                channelmap              decimate                fieldorder              hwmap                   metadata                pullup                  showspectrum            testsrc                 xbr
afir                    arnndn                  channelsplit            deconvolve              fifo                    hwupload                midequalizer            qp                      showspectrumpic         testsrc2                xfade
afirsrc                 aselect                 chorus                  dedot                   fillborders             hysteresis              minterpolate            random                  showvolume              thistogram              xmedian
aformat                 asendcmd                chromahold              deesser                 find_rect               idet                    mix                     readeia608              showwaves               threshold               xstack
agate                   asetnsamples            chromakey               deflate                 firequalizer            il                      movie                   readvitc                showwavespic            thumbnail               yadif
agraphmonitor           asetpts                 chromashift             deflicker               flanger                 inflate                 mpdecimate              realtime                shuffleframes           tile                    yaepblur
ahistogram              asetrate                ciescope                dejudder                floodfill               interlace               mptestsrc               remap                   shuffleplanes           tinterlace              yuvtestsrc
aiir                    asettb                  codecview               delogo                  format                  interleave              negate                  removegrain             sidechaincompress       tlut2                   zoompan
aintegral               ashowinfo               color                   derain                  fps                     join                    nlmeans                 removelogo              sidechaingate           tmedian
ainterleave             asidedata               colorbalance            deshake                 framepack               kerndeint               nnedi                   repeatfields            sidedata                tmix
alimiter                asoftclip               colorchannelmixer       despill                 framerate               lagfun                  noformat                replaygain              sierpinski              tonemap
allpass                 asplit                  colorhold               detelecine              framestep               lenscorrection          noise                   reverse                 signalstats             tpad
allrgb                  astats                  colorkey                dilation                freezedetect            life                    normalize               rgbashift               signature               transpose
allyuv                  astreamselect           colorlevels             displace                freezeframes            limiter                 null                    rgbtestsrc              silencedetect           treble
aloop                   asubboost               colormatrix             dnn_processing          fspp                    loop                    nullsink                roberts                 silenceremove           tremolo

Enabled bsfs:
aac_adtstoasc           chomp                   extract_extradata       h264_redundant_pps      imx_dump_header         mp3_header_decompress   null                    remove_extradata        vp9_metadata
av1_frame_merge         dca_core                filter_units            hapqa_extract           mjpeg2jpeg              mpeg2_metadata          opus_metadata           text2movsub             vp9_raw_reorder
av1_frame_split         dump_extradata          h264_metadata           hevc_metadata           mjpega_dump_header      mpeg4_unpack_bframes    pcm_rechunk             trace_headers           vp9_superframe
av1_metadata            eac3_core               h264_mp4toannexb        hevc_mp4toannexb        mov2textsub             noise                   prores_metadata         truehd_core             vp9_superframe_split

Enabled indevs:
avfoundation            lavfi

Enabled outdevs:
sdl2

License: non-free and unredistributable
$ make -j 12
$ make install

Building done. The following binaries can be found here:
- ffmpeg: /Volumes/Daten/dev/mac/ffmpeg-build-script/workspace/bin/ffmpeg
- ffprobe: /Volumes/Daten/dev/mac/ffmpeg-build-script/workspace/bin/ffprobe
- ffplay: /Volumes/Daten/dev/mac/ffmpeg-build-script/workspace/bin/ffplay

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
