[![build test](https://github.com/markus-perl/ffmpeg-build-script/workflows/build%20test/badge.svg?branch=master)](https://github.com/markus-perl/ffmpeg-build-script/actions)

![FFmpeg build script](https://raw.github.com/markus-perl/ffmpeg-build-script/master/ffmpeg-build-script.png)


build-ffmpeg
==========

The FFmpeg build script provides an easy way to build a static FFmpeg on **OSX** and **Linux** with **non-free codecs** included.


[![How-To build FFmpeg on MacOS](https://img.youtube.com/vi/Z9p3mM757cM/0.jpg)](https://www.youtube.com/watch?v=Z9p3mM757cM "How-To build FFmpeg on OSX")

*Youtube: How-To build and install FFmpeg on MacOS*

## Disclaimer
Use this script at your own risk. I maintain this script in my spare time.
Please do not file bug reports for systems other than Debian 10 and macOS 10.15.x
because I don't have the resources and the time to maintain other systems.


## Supported Codecs
* `x264`: H.264 (MPEG-4 AVC)
* `x265`: H.265 Video Codec
* `aom`: AV1 Video Codec (Experimental and very slow!)
* `fdk_aac`: Fraunhofer FDK AAC Codec
* `xvidcore`: MPEG-4 video coding standard
* `VP8/VP9/webm`: VP8 / VP9 Video Codec for the WebM video file format
* `mp3`: MPEG-1 or MPEG-2 Audio Layer III
* `ogg`: Free, open container format
* `vorbis`: Lossy audio compression format
* `theora`: Free lossy video compression format
* `opus`: Lossy audio coding format
* `srt`: Secure Reliable Transport
* `nv-codec`: [NVIDIA's GPU accelerated video codecs](https://devblogs.nvidia.com/nvidia-ffmpeg-transcoding-guide/). Installation is triggered only if CUDA installation is detected, follow [these](#Cuda-installation) instructions for installation. Supported codecs in nvcodec:
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

## Continuos Integration
ffmpeg-build-script is rockstable. Every commit runs against Linux and MacOS with https://github.com/markus-perl/ffmpeg-build-script/actions just to make sure everything works as expected.

Requirements MacOS
------------

* XCode 10.x or greater

Requirements Linux
------------
* Debian >= Buster, Ubuntu => Focal Fossa, other Distributions might work too
* build-essentials installed:

```
# Debian and Ubuntu
$ sudo apt-get install build-essential curl g++

# Fedora
$ sudo dnf install @development-tools
```

Installation
------------

### Quick install and run

Open your command line and run (needs curl to be installed):

```bash
$ bash <(curl -s "https://raw.githubusercontent.com/markus-perl/ffmpeg-build-script/master/web-install.sh?v1")
```
This command downloads the build script and automatically starts the build process.

### Run with Docker

#### Default - Without CUDA
```bash
$ git clone https://github.com/markus-perl/ffmpeg-build-script.git
$ cd ffmpeg-build-script
$ sudo docker build --tag=ffmpeg .
$ docker run ffmpeg -i https://files.coconut.co.s3.amazonaws.com/test.mp4 -f webm -c:v libvpx -c:a libvorbis - > /tmp/test.mp4
```

#### With CUDA
```bash
$ git clone https://github.com/markus-perl/ffmpeg-build-script.git
$ cd ffmpeg-build-script
$ sudo docker build --tag=ffmpeg-cuda -f cuda-ubuntu.dockerfile .
$ sudo docker run --gpus all ffmpeg-cuda -hwaccel cuvid -c:v h264_cuvid -i https://files.coconut.co.s3.amazonaws.com/test.mp4 -c:v hevc_nvenc -vf scale_npp=-1:1080 - > /tmp/test.mp4
```

### Common installation

```bash
$ git clone https://github.com/markus-perl/ffmpeg-build-script.git
$ cd ffmpeg-build-script
$ ./build-ffmpeg --help
```

### Cuda installation

CUDA is a parallel computing platform developed by NVIDIA.
To be able to compile ffmpeg with CUDA support, you first need a compatible NVIDIA GPU.
- Ubuntu: To install the CUDA toolkit on Ubuntu, simply run "sudo apt install nvidia-cuda-toolkit"
- Other Linux distributions: Once you have the GPU and display driver installed, you can follow the
[official instructions](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html)
or [this blog](https://www.pugetsystems.com/labs/hpc/How-To-Install-CUDA-10-1-on-Ubuntu-19-04-1405/)
to setup the CUDA toolkit.

Usage
------

```bash
Usage: build-ffmpeg [OPTIONS]
Options:
  -h, --help          Display usage information
      --version       Display version information
  -b, --build         Starts the build process
  -c, --cleanup       Remove all working dirs
  -f, --full-static   Complete static build of ffmpeg (eg. glibc, pthreads etc...) **not recommend**
                      Note: Because of the NSS (Name Service Switch), glibc does not recommend static links.
```

## Notes of static link
- Because of the NSS (Name Service Switch), glibc does **not recommend** static links.
  See detail below: https://sourceware.org/glibc/wiki/FAQ#Even_statically_linked_programs_need_some_shared_libraries_which_is_not_acceptable_for_me.__What_can_I_do.3F

- The libnpp in the CUDA SDK cannot be statically linked.

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
Start the build in full static mode.

building yasm
=======================
yasm already built. Remove /Volumes/Daten/dev/mac/ffmpeg-build-script/packages/yasm.done lockfile to rebuild it.

building nasm
=======================
nasm already built. Remove /Volumes/Daten/dev/mac/ffmpeg-build-script/packages/nasm.done lockfile to rebuild it.

building pkg-config
=======================
pkg-config already built. Remove /Volumes/Daten/dev/mac/ffmpeg-build-script/packages/pkg-config.done lockfile to rebuild it.

building cmake
=======================
cmake already built. Remove /Volumes/Daten/dev/mac/ffmpeg-build-script/packages/cmake.done lockfile to rebuild it.

building x264
=======================
x264 already built. Remove /Volumes/Daten/dev/mac/ffmpeg-build-script/packages/x264.done lockfile to rebuild it.

building x265
=======================
Downloading https://github.com/videolan/x265/archive/Release_3.5.tar.gz
... Done
Extracted x265-3.5.tar.gz
$ cmake -DCMAKE_INSTALL_PREFIX:PATH=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace -DENABLE_SHARED:bool=off -DSTATIC_LINK_CRT:BOOL=ON -DENABLE_CLI:BOOL=OFF .
$ make -j 12
$ make install
sed: 1: "/Volumes/Daten/dev/mac/ ...": extra characters at the end of D command

building libvpx
=======================
Downloading https://github.com/webmproject/libvpx/archive/v1.9.0.tar.gz
... Done
Extracted libvpx-1.9.0.tar.gz
Applying Darwin patch
$ ./configure --prefix=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace --disable-unit-tests --disable-shared
$ make -j 12
$ make install

building xvidcore
=======================
Downloading https://downloads.xvid.com/downloads/xvidcore-1.3.7.tar.gz
... Done
Extracted xvidcore-1.3.7.tar.gz
$ ./configure --prefix=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace --disable-shared --enable-static
$ make -j 12
$ make install
$ rm /Volumes/Daten/dev/mac/ffmpeg-build-script/workspace/lib/libxvidcore.4.dylib

building vid_stab
=======================
Downloading https://github.com/georgmartius/vid.stab/archive/v1.1.0.tar.gz
... Done
Extracted vid.stab-1.1.0.tar.gz
$ cmake -DBUILD_SHARED_LIBS=OFF -DCMAKE_INSTALL_PREFIX:PATH=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace -DUSE_OMP=OFF -DENABLE_SHARED:bool=off .
$ make
$ make install

building av1
=======================
Downloading https://aomedia.googlesource.com/aom/+archive/430d58446e1f71ec2283af0d6c1879bc7a3553dd.tar.gz
... Done
Extracted av1.tar.gz
$ cmake -DENABLE_TESTS=0 -DCMAKE_INSTALL_PREFIX:PATH=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace /Volumes/Daten/dev/mac/ffmpeg-build-script/packages/av1
$ make -j 12
$ make install

building opencore
=======================
Downloading https://deac-riga.dl.sourceforge.net/project/opencore-amr/opencore-amr/opencore-amr-0.1.5.tar.gz
... Done
Extracted opencore-amr-0.1.5.tar.gz
$ ./configure --prefix=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace --disable-shared --enable-static
$ make -j 12
$ make install

building lame
=======================
Downloading https://netcologne.dl.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz
... Done
Extracted lame-3.100.tar.gz
$ ./configure --prefix=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace --disable-shared --enable-static
$ make -j 12
$ make install

building opus
=======================
Downloading https://archive.mozilla.org/pub/opus/opus-1.3.1.tar.gz
... Done
Extracted opus-1.3.1.tar.gz
$ ./configure --prefix=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace --disable-shared --enable-static
$ make -j 12
$ make install

building libogg
=======================
Downloading https://ftp.osuosl.org/pub/xiph/releases/ogg/libogg-1.3.3.tar.gz
... Done
Extracted libogg-1.3.3.tar.gz
$ ./configure --prefix=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace --disable-shared --enable-static
$ make -j 12
$ make install

building libvorbis
=======================
Downloading https://ftp.osuosl.org/pub/xiph/releases/vorbis/libvorbis-1.3.6.tar.gz
... Done
Extracted libvorbis-1.3.6.tar.gz
$ ./configure --prefix=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace --with-ogg-libraries=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace/lib --with-ogg-includes=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace/include/ --enable-static --disable-shared --disable-oggtest
$ make -j 12
$ make install

building libtheora
=======================
Downloading https://ftp.osuosl.org/pub/xiph/releases/theora/libtheora-1.1.1.tar.gz
... Done
Extracted libtheora-1.1.1.tar.gz
$ ./configure --prefix=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace --with-ogg-libraries=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace/lib --with-ogg-includes=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace/include/ --with-vorbis-libraries=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace/lib --with-vorbis-includes=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace/include/ --enable-static --disable-shared --disable-oggtest --disable-vorbistest --disable-examples --disable-asm --disable-spec
$ make -j 12
$ make install

building fdk_aac
=======================
Downloading https://sourceforge.net/projects/opencore-amr/files/fdk-aac/fdk-aac-2.0.1.tar.gz/download?use_mirror=gigenet
... Done
Extracted fdk-aac-2.0.1.tar.gz
$ ./configure --prefix=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace --disable-shared --enable-static
$ make -j 12
$ make install

building zlib
=======================
Downloading https://www.zlib.net/zlib-1.2.11.tar.gz
... Done
Extracted zlib-1.2.11.tar.gz
$ ./configure --static --prefix=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace
$ make -j 12
$ make install

building openssl
=======================
Downloading https://www.openssl.org/source/openssl-1.1.1h.tar.gz
... Done
Extracted openssl-1.1.1h.tar.gz
$ ./config --prefix=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace --openssldir=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace --with-zlib-include=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace/include/ --with-zlib-lib=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace/lib no-shared zlib
$ make -j 12
$ make install

building srt
=======================
Downloading https://github.com/Haivision/srt/archive/v1.4.1.tar.gz
... Done
Extracted srt-1.4.1.tar.gz
$ cmake . -DCMAKE_INSTALL_PREFIX:PATH=/Volumes/Daten/dev/mac/ffmpeg-build-script/workspace -DENABLE_SHARED=OFF -DENABLE_STATIC=ON -DENABLE_APPS=OFF -DUSE_STATIC_LIBSTDCXX=ON
$ make install

building ffmpeg
=======================
Downloading https://ffmpeg.org/releases/ffmpeg-4.3.1.tar.bz2
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
appkit                  coreimage               libfdk_aac              libopencore_amrwb       libtheora               libvpx                  libxvid
avfoundation            iconv                   libmp3lame              libopus                 libvidstab              libx264                 openssl
bzlib                   libaom                  libopencore_amrnb       libsrt                  libvorbis               libx265                 zlib

External libraries providing hardware acceleration:
audiotoolbox            videotoolbox

Libraries:
avcodec                 avdevice                avfilter                avformat                avutil                  postproc                swresample              swscale

Programs:
ffmpeg                  ffprobe

Enabled decoders:
aac                     adpcm_thp               cdgraphics              fic                     jv                      msrle                   pcm_u24le               sheervideo              vc1image
aac_at                  adpcm_thp_le            cdtoons                 fits                    kgv1                    mss1                    pcm_u32be               shorten                 vcr1
aac_fixed               adpcm_vima              cdxl                    flac                    kmvc                    mss2                    pcm_u32le               sipr                    vmdaudio
aac_latm                adpcm_xa                cfhd                    flashsv                 lagarith                msvideo1                pcm_u8                  siren                   vmdvideo
aasc                    adpcm_yamaha            cinepak                 flashsv2                libaom_av1              mszh                    pcm_vidc                smackaud                vmnc
ac3                     adpcm_zork              clearvideo              flic                    libfdk_aac              mts2                    pcx                     smacker                 vorbis
ac3_at                  agm                     cljr                    flv                     libopencore_amrnb       mv30                    pfm                     smc                     vp3
ac3_fixed               aic                     cllc                    fmvc                    libopencore_amrwb       mvc1                    pgm                     smvjpeg                 vp4
acelp_kelvin            alac                    comfortnoise            fourxm                  libopus                 mvc2                    pgmyuv                  snow                    vp5
adpcm_4xm               alac_at                 cook                    fraps                   libvorbis               mvdv                    pgssub                  sol_dpcm                vp6
adpcm_adx               alias_pix               cpia                    frwu                    libvpx_vp8              mvha                    pictor                  sonic                   vp6a
adpcm_afc               als                     cscd                    g2m                     libvpx_vp9              mwsc                    pixlet                  sp5x                    vp6f
adpcm_agm               amr_nb_at               cyuv                    g723_1                  loco                    mxpeg                   pjs                     speedhq                 vp7
adpcm_aica              amrnb                   dca                     g729                    lscr                    nellymoser              png                     srgc                    vp8
adpcm_argo              amrwb                   dds                     gdv                     m101                    notchlc                 ppm                     srt                     vp9
adpcm_ct                amv                     derf_dpcm               gif                     mace3                   nuv                     prores                  ssa                     vplayer
adpcm_dtk               anm                     dfa                     gremlin_dpcm            mace6                   on2avc                  prosumer                stl                     vqa
adpcm_ea                ansi                    dirac                   gsm                     magicyuv                opus                    psd                     subrip                  wavpack
adpcm_ea_maxis_xa       ape                     dnxhd                   gsm_ms                  mdec                    paf_audio               ptx                     subviewer               wcmv
adpcm_ea_r1             apng                    dolby_e                 gsm_ms_at               metasound               paf_video               qcelp                   subviewer1              webp
adpcm_ea_r2             aptx                    dpx                     h261                    microdvd                pam                     qdm2                    sunrast                 webvtt
adpcm_ea_r3             aptx_hd                 dsd_lsbf                h263                    mimic                   pbm                     qdm2_at                 svq1                    wmalossless
adpcm_ea_xas            arbc                    dsd_lsbf_planar         h263i                   mjpeg                   pcm_alaw                qdmc                    svq3                    wmapro
adpcm_g722              ass                     dsd_msbf                h263p                   mjpegb                  pcm_alaw_at             qdmc_at                 tak                     wmav1
adpcm_g726              asv1                    dsd_msbf_planar         h264                    mlp                     pcm_bluray              qdraw                   targa                   wmav2
adpcm_g726le            asv2                    dsicinaudio             hap                     mmvideo                 pcm_dvd                 qpeg                    targa_y216              wmavoice
adpcm_ima_alp           atrac1                  dsicinvideo             hca                     motionpixels            pcm_f16le               qtrle                   tdsc                    wmv1
adpcm_ima_amv           atrac3                  dss_sp                  hcom                    movtext                 pcm_f24le               r10k                    text                    wmv2
adpcm_ima_apc           atrac3al                dst                     hevc                    mp1                     pcm_f32be               r210                    theora                  wmv3
adpcm_ima_apm           atrac3p                 dvaudio                 hnm4_video              mp1_at                  pcm_f32le               ra_144                  thp                     wmv3image
adpcm_ima_cunning       atrac3pal               dvbsub                  hq_hqa                  mp1float                pcm_f64be               ra_288                  tiertexseqvideo         wnv1
adpcm_ima_dat4          atrac9                  dvdsub                  hqx                     mp2                     pcm_f64le               ralf                    tiff                    wrapped_avframe
adpcm_ima_dk3           aura                    dvvideo                 huffyuv                 mp2_at                  pcm_lxf                 rasc                    tmv                     ws_snd1
adpcm_ima_dk4           aura2                   dxa                     hymt                    mp2float                pcm_mulaw               rawvideo                truehd                  xan_dpcm
adpcm_ima_ea_eacs       avrn                    dxtory                  iac                     mp3                     pcm_mulaw_at            realtext                truemotion1             xan_wc3
adpcm_ima_ea_sead       avrp                    dxv                     idcin                   mp3_at                  pcm_s16be               rl2                     truemotion2             xan_wc4
adpcm_ima_iss           avs                     eac3                    idf                     mp3adu                  pcm_s16be_planar        roq                     truemotion2rt           xbin
adpcm_ima_mtf           avui                    eac3_at                 iff_ilbm                mp3adufloat             pcm_s16le               roq_dpcm                truespeech              xbm
adpcm_ima_oki           ayuv                    eacmv                   ilbc                    mp3float                pcm_s16le_planar        rpza                    tscc                    xface
adpcm_ima_qt            bethsoftvid             eamad                   ilbc_at                 mp3on4                  pcm_s24be               rscc                    tscc2                   xl
adpcm_ima_qt_at         bfi                     eatgq                   imc                     mp3on4float             pcm_s24daud             rv10                    tta                     xma1
adpcm_ima_rad           bink                    eatgv                   imm4                    mpc7                    pcm_s24le               rv20                    twinvq                  xma2
adpcm_ima_smjpeg        binkaudio_dct           eatqi                   imm5                    mpc8                    pcm_s24le_planar        rv30                    txd                     xpm
adpcm_ima_ssi           binkaudio_rdft          eightbps                indeo2                  mpeg1video              pcm_s32be               rv40                    ulti                    xsub
adpcm_ima_wav           bintext                 eightsvx_exp            indeo3                  mpeg2video              pcm_s32le               s302m                   utvideo                 xwd
adpcm_ima_ws            bitpacked               eightsvx_fib            indeo4                  mpeg4                   pcm_s32le_planar        sami                    v210                    y41p
adpcm_ms                bmp                     escape124               indeo5                  mpegvideo               pcm_s64be               sanm                    v210x                   ylc
adpcm_mtaf              bmv_audio               escape130               interplay_acm           mpl2                    pcm_s64le               sbc                     v308                    yop
adpcm_psx               bmv_video               evrc                    interplay_dpcm          msa1                    pcm_s8                  scpr                    v408                    yuv4
adpcm_sbpro_2           brender_pix             exr                     interplay_video         mscc                    pcm_s8_planar           screenpresso            v410                    zero12v
adpcm_sbpro_3           c93                     ffv1                    jacosub                 msmpeg4v1               pcm_u16be               sdx2_dpcm               vb                      zerocodec
adpcm_sbpro_4           cavs                    ffvhuff                 jpeg2000                msmpeg4v2               pcm_u16le               sgi                     vble                    zlib
adpcm_swf               ccaption                ffwavesynth             jpegls                  msmpeg4v3               pcm_u24be               sgirle                  vc1                     zmbv

Enabled encoders:
a64multi                apng                    ffv1                    libmp3lame              mpeg4                   pcm_s16le_planar        pcx                     snow                    wavpack
a64multi5               aptx                    ffvhuff                 libopencore_amrnb       msmpeg4v2               pcm_s24be               pgm                     sonic                   webvtt
aac                     aptx_hd                 fits                    libopus                 msmpeg4v3               pcm_s24daud             pgmyuv                  sonic_ls                wmav1
aac_at                  ass                     flac                    libtheora               msvideo1                pcm_s24le               png                     srt                     wmav2
ac3                     asv1                    flashsv                 libvorbis               nellymoser              pcm_s24le_planar        ppm                     ssa                     wmv1
ac3_fixed               asv2                    flashsv2                libvpx_vp8              opus                    pcm_s32be               prores                  subrip                  wmv2
adpcm_adx               avrp                    flv                     libvpx_vp9              pam                     pcm_s32le               prores_aw               sunrast                 wrapped_avframe
adpcm_g722              avui                    g723_1                  libx264                 pbm                     pcm_s32le_planar        prores_ks               svq1                    xbm
adpcm_g726              ayuv                    gif                     libx264rgb              pcm_alaw                pcm_s64be               qtrle                   targa                   xface
adpcm_g726le            bmp                     h261                    libx265                 pcm_alaw_at             pcm_s64le               r10k                    text                    xsub
adpcm_ima_qt            cinepak                 h263                    libxvid                 pcm_dvd                 pcm_s8                  r210                    tiff                    xwd
adpcm_ima_ssi           cljr                    h263p                   ljpeg                   pcm_f32be               pcm_s8_planar           ra_144                  truehd                  y41p
adpcm_ima_wav           comfortnoise            h264_videotoolbox       magicyuv                pcm_f32le               pcm_u16be               rawvideo                tta                     yuv4
adpcm_ms                dca                     hevc_videotoolbox       mjpeg                   pcm_f64be               pcm_u16le               roq                     utvideo                 zlib
adpcm_swf               dnxhd                   huffyuv                 mlp                     pcm_f64le               pcm_u24be               roq_dpcm                v210                    zmbv
adpcm_yamaha            dpx                     ilbc_at                 movtext                 pcm_mulaw               pcm_u24le               rv10                    v308
alac                    dvbsub                  jpeg2000                mp2                     pcm_mulaw_at            pcm_u32be               rv20                    v408
alac_at                 dvdsub                  jpegls                  mp2fixed                pcm_s16be               pcm_u32le               s302m                   v410
alias_pix               dvvideo                 libaom_av1              mpeg1video              pcm_s16be_planar        pcm_u8                  sbc                     vc2
amv                     eac3                    libfdk_aac              mpeg2video              pcm_s16le               pcm_vidc                sgi                     vorbis

Enabled hwaccels:
h263_videotoolbox       h264_videotoolbox       hevc_videotoolbox       mpeg1_videotoolbox      mpeg2_videotoolbox      mpeg4_videotoolbox

Enabled parsers:
aac                     bmp                     dpx                     g723_1                  h264                    mpegaudio               rv40                    vp3
aac_latm                cavsvideo               dvaudio                 g729                    hevc                    mpegvideo               sbc                     vp8
ac3                     cook                    dvbsub                  gif                     jpeg2000                opus                    sipr                    vp9
adx                     dca                     dvd_nav                 gsm                     mjpeg                   png                     tak                     webp
av1                     dirac                   dvdsub                  h261                    mlp                     pnm                     vc1                     xma
avs2                    dnxhd                   flac                    h263                    mpeg4video              rv30                    vorbis

Enabled demuxers:
aa                      avs                     dvbsub                  hnm                     image_xpm_pipe          mpegts                  pcm_s32be               scc                     ty
aac                     avs2                    dvbtxt                  ico                     image_xwd_pipe          mpegtsraw               pcm_s32le               sdp                     v210
ac3                     bethsoftvid             dxa                     idcin                   ingenient               mpegvideo               pcm_s8                  sdr2                    v210x
acm                     bfi                     ea                      idf                     ipmovie                 mpjpeg                  pcm_u16be               sds                     vag
act                     bfstm                   ea_cdata                iff                     ircam                   mpl2                    pcm_u16le               sdx                     vc1
adf                     bink                    eac3                    ifv                     iss                     mpsub                   pcm_u24be               segafilm                vc1t
adp                     bintext                 epaf                    ilbc                    iv8                     msf                     pcm_u24le               ser                     vividas
ads                     bit                     ffmetadata              image2                  ivf                     msnwc_tcp               pcm_u32be               shorten                 vivo
adx                     bmv                     filmstrip               image2_alias_pix        ivr                     mtaf                    pcm_u32le               siff                    vmd
aea                     boa                     fits                    image2_brender_pix      jacosub                 mtv                     pcm_u8                  sln                     vobsub
afc                     brstm                   flac                    image2pipe              jv                      musx                    pcm_vidc                smacker                 voc
aiff                    c93                     flic                    image_bmp_pipe          kux                     mv                      pjs                     smjpeg                  vpk
aix                     caf                     flv                     image_dds_pipe          kvag                    mvi                     pmp                     smush                   vplayer
alp                     cavsvideo               fourxm                  image_dpx_pipe          live_flv                mxf                     pp_bnk                  sol                     vqf
amr                     cdg                     frm                     image_exr_pipe          lmlm4                   mxg                     pva                     sox                     w64
amrnb                   cdxl                    fsb                     image_gif_pipe          loas                    nc                      pvf                     spdif                   wav
amrwb                   cine                    fwse                    image_j2k_pipe          lrc                     nistsphere              qcp                     srt                     wc3
anm                     codec2                  g722                    image_jpeg_pipe         lvf                     nsp                     r3d                     stl                     webm_dash_manifest
apc                     codec2raw               g723_1                  image_jpegls_pipe       lxf                     nsv                     rawvideo                str                     webvtt
ape                     concat                  g726                    image_pam_pipe          m4v                     nut                     realtext                subviewer               wsaud
apm                     data                    g726le                  image_pbm_pipe          matroska                nuv                     redspark                subviewer1              wsd
apng                    daud                    g729                    image_pcx_pipe          mgsts                   ogg                     rl2                     sup                     wsvqa
aptx                    dcstr                   gdv                     image_pgm_pipe          microdvd                oma                     rm                      svag                    wtv
aptx_hd                 derf                    genh                    image_pgmyuv_pipe       mjpeg                   paf                     roq                     swf                     wv
aqtitle                 dfa                     gif                     image_pictor_pipe       mjpeg_2000              pcm_alaw                rpl                     tak                     wve
argo_asf                dhav                    gsm                     image_png_pipe          mlp                     pcm_f32be               rsd                     tedcaptions             xa
asf                     dirac                   gxf                     image_ppm_pipe          mlv                     pcm_f32le               rso                     thp                     xbin
asf_o                   dnxhd                   h261                    image_psd_pipe          mm                      pcm_f64be               rtp                     threedostr              xmv
ass                     dsf                     h263                    image_qdraw_pipe        mmf                     pcm_f64le               rtsp                    tiertexseq              xvag
ast                     dsicin                  h264                    image_sgi_pipe          mov                     pcm_mulaw               s337m                   tmv                     xwma
au                      dss                     hca                     image_sunrast_pipe      mp3                     pcm_s16be               sami                    truehd                  yop
av1                     dts                     hcom                    image_svg_pipe          mpc                     pcm_s16le               sap                     tta                     yuv4mpegpipe
avi                     dtshd                   hevc                    image_tiff_pipe         mpc8                    pcm_s24be               sbc                     tty
avr                     dv                      hls                     image_webp_pipe         mpegps                  pcm_s24le               sbg                     txd

Enabled muxers:
a64                     cavsvideo               flv                     ilbc                    mmf                     oga                     pcm_u16le               segment                 vc1t
ac3                     codec2                  framecrc                image2                  mov                     ogg                     pcm_u24be               singlejpeg              voc
adts                    codec2raw               framehash               image2pipe              mp2                     ogv                     pcm_u24le               smjpeg                  w64
adx                     crc                     framemd5                ipod                    mp3                     oma                     pcm_u32be               smoothstreaming         wav
aiff                    dash                    g722                    ircam                   mp4                     opus                    pcm_u32le               sox                     webm
amr                     data                    g723_1                  ismv                    mpeg1system             pcm_alaw                pcm_u8                  spdif                   webm_chunk
apng                    daud                    g726                    ivf                     mpeg1vcd                pcm_f32be               pcm_vidc                spx                     webm_dash_manifest
aptx                    dirac                   g726le                  jacosub                 mpeg1video              pcm_f32le               psp                     srt                     webp
aptx_hd                 dnxhd                   gif                     kvag                    mpeg2dvd                pcm_f64be               rawvideo                stream_segment          webvtt
asf                     dts                     gsm                     latm                    mpeg2svcd               pcm_f64le               rm                      streamhash              wtv
asf_stream              dv                      gxf                     lrc                     mpeg2video              pcm_mulaw               roq                     sup                     wv
ass                     eac3                    h261                    m4v                     mpeg2vob                pcm_s16be               rso                     swf                     yuv4mpegpipe
ast                     f4v                     h263                    matroska                mpegts                  pcm_s16le               rtp                     tee
au                      ffmetadata              h264                    matroska_audio          mpjpeg                  pcm_s24be               rtp_mpegts              tg2
avi                     fifo                    hash                    md5                     mxf                     pcm_s24le               rtsp                    tgp
avm2                    fifo_test               hds                     microdvd                mxf_d10                 pcm_s32be               sap                     truehd
avs2                    filmstrip               hevc                    mjpeg                   mxf_opatom              pcm_s32le               sbc                     tta
bit                     fits                    hls                     mkvtimestamp_v2         null                    pcm_s8                  scc                     uncodedframecrc
caf                     flac                    ico                     mlp                     nut                     pcm_u16be               segafilm                vc1

Enabled protocols:
async                   data                    ftp                     httpproxy               md5                     prompeg                 rtmpt                   srtp                    tls
cache                   ffrtmpcrypt             gopher                  https                   mmsh                    rtmp                    rtmpte                  subfile                 udp
concat                  ffrtmphttp              hls                     icecast                 mmst                    rtmpe                   rtmpts                  tcp                     udplite
crypto                  file                    http                    libsrt                  pipe                    rtmps                   rtp                     tee                     unix

Enabled filters:
abench                  anequalizer             blend                   dedot                   framerate               lumakey                 perspective             showinfo                tile
abitscope               anlmdn                  bm3d                    deesser                 framestep               lut                     phase                   showpalette             tinterlace
acompressor             anlms                   boxblur                 deflate                 freezedetect            lut1d                   photosensitivity        showspatial             tlut2
acontrast               anoisesrc               bwdif                   deflicker               freezeframes            lut2                    pixdesctest             showspectrum            tmedian
acopy                   anull                   cas                     dejudder                fspp                    lut3d                   pixscope                showspectrumpic         tmix
acrossfade              anullsink               cellauto                delogo                  gblur                   lutrgb                  pp                      showvolume              tonemap
acrossover              anullsrc                channelmap              derain                  geq                     lutyuv                  pp7                     showwaves               tpad
acrusher                apad                    channelsplit            deshake                 gradfun                 mandelbrot              premultiply             showwavespic            transpose
acue                    aperms                  chorus                  despill                 gradients               maskedclamp             prewitt                 shuffleframes           treble
addroi                  aphasemeter             chromahold              detelecine              graphmonitor            maskedmax               pseudocolor             shuffleplanes           tremolo
adeclick                aphaser                 chromakey               dilation                greyedge                maskedmerge             psnr                    sidechaincompress       trim
adeclip                 apulsator               chromashift             displace                haas                    maskedmin               pullup                  sidechaingate           unpremultiply
adelay                  arealtime               ciescope                dnn_processing          haldclut                maskedthreshold         qp                      sidedata                unsharp
aderivative             aresample               codecview               doubleweave             haldclutsrc             maskfun                 random                  sierpinski              untile
adrawgraph              areverse                color                   drawbox                 hdcd                    mcdeint                 readeia608              signalstats             uspp
aecho                   arnndn                  colorbalance            drawgraph               headphone               mcompand                readvitc                signature               v360
aemphasis               aselect                 colorchannelmixer       drawgrid                hflip                   median                  realtime                silencedetect           vaguedenoiser
aeval                   asendcmd                colorhold               drmeter                 highpass                mergeplanes             remap                   silenceremove           vectorscope
aevalsrc                asetnsamples            colorkey                dynaudnorm              highshelf               mestimate               removegrain             sinc                    vflip
afade                   asetpts                 colorlevels             earwax                  hilbert                 metadata                removelogo              sine                    vfrdet
afftdn                  asetrate                colormatrix             ebur128                 histeq                  midequalizer            repeatfields            smartblur               vibrance
afftfilt                asettb                  colorspace              edgedetect              histogram               minterpolate            replaygain              smptebars               vibrato
afifo                   ashowinfo               compand                 elbg                    hqdn3d                  mix                     reverse                 smptehdbars             vidstabdetect
afir                    asidedata               compensationdelay       entropy                 hqx                     movie                   rgbashift               sobel                   vidstabtransform
afirsrc                 asoftclip               concat                  eq                      hstack                  mpdecimate              rgbtestsrc              spectrumsynth           vignette
aformat                 asplit                  convolution             equalizer               hue                     mptestsrc               roberts                 split                   vmafmotion
agate                   astats                  convolve                erosion                 hwdownload              negate                  rotate                  spp                     volume
agraphmonitor           astreamselect           copy                    extractplanes           hwmap                   nlmeans                 sab                     sr                      volumedetect
ahistogram              asubboost               coreimage               extrastereo             hwupload                nnedi                   scale                   ssim                    vstack
aiir                    atadenoise              coreimagesrc            fade                    hysteresis              noformat                scale2ref               stereo3d                w3fdif
aintegral               atempo                  cover_rect              fftdnoiz                idet                    noise                   scdet                   stereotools             waveform
ainterleave             atrim                   crop                    fftfilt                 il                      normalize               scroll                  stereowiden             weave
alimiter                avectorscope            cropdetect              field                   inflate                 null                    select                  streamselect            xbr
allpass                 avgblur                 crossfeed               fieldhint               interlace               nullsink                selectivecolor          super2xsai              xfade
allrgb                  axcorrelate             crystalizer             fieldmatch              interleave              nullsrc                 sendcmd                 superequalizer          xmedian
allyuv                  bandpass                cue                     fieldorder              join                    oscilloscope            separatefields          surround                xstack
aloop                   bandreject              curves                  fifo                    kerndeint               overlay                 setdar                  swaprect                yadif
alphaextract            bass                    datascope               fillborders             lagfun                  owdenoise               setfield                swapuv                  yaepblur
alphamerge              bbox                    dblur                   find_rect               lenscorrection          pad                     setparams               tblend                  yuvtestsrc
amerge                  bench                   dcshift                 firequalizer            life                    pal100bars              setpts                  telecine                zoompan
ametadata               bilateral               dctdnoiz                flanger                 limiter                 pal75bars               setrange                testsrc
amix                    biquad                  deband                  floodfill               loop                    palettegen              setsar                  testsrc2
amovie                  bitplanenoise           deblock                 format                  loudnorm                paletteuse              settb                   thistogram
amplify                 blackdetect             decimate                fps                     lowpass                 pan                     showcqt                 threshold
amultiply               blackframe              deconvolve              framepack               lowshelf                perms                   showfreqs               thumbnail

Enabled bsfs:
aac_adtstoasc           chomp                   extract_extradata       h264_redundant_pps      imx_dump_header         mp3_header_decompress   null                    remove_extradata        vp9_metadata
av1_frame_merge         dca_core                filter_units            hapqa_extract           mjpeg2jpeg              mpeg2_metadata          opus_metadata           text2movsub             vp9_raw_reorder
av1_frame_split         dump_extradata          h264_metadata           hevc_metadata           mjpega_dump_header      mpeg4_unpack_bframes    pcm_rechunk             trace_headers           vp9_superframe
av1_metadata            eac3_core               h264_mp4toannexb        hevc_mp4toannexb        mov2textsub             noise                   prores_metadata         truehd_core             vp9_superframe_split

Enabled indevs:
avfoundation            lavfi

Enabled outdevs:

License: nonfree and unredistributable
$ make -j 12
$ make install

Building done. The binary can be found here: /Users/me/dev/ffmpeg-build-script/workspace/bin/ffmpeg

Install the binary to your /usr/local/bin folder? [Y/n] y
Password:
Done. ffmpeg is now installed to your system.
```


Other Projects Of Mine
------------
- [Pushover CLI Client](https://github.com/markus-perl/pushover-cli)
- [Gender API](https://gender-api.com): [Genderize A Name](https://gender-api.com)
- [Gender API Client PHP](https://github.com/markus-perl/gender-api-client)
- [Gender API Client NPM](https://github.com/markus-perl/gender-api-client-npm)
- [Genderize Names](https://www.youtube.com/watch?v=2SLIAguaygo)
- [Genderize API](https://gender-api.io)
