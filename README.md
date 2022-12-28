build-ffmpeg
==========

The FFmpeg build script provides an easy way to build a **static** FFmpeg on **Linux** with optional **non-free and GPL codecs** (--enable-gpl-and-non-free, see https://ffmpeg.org/legal.html) included.


## Installation (Linux)

### From terminal run one of the below commands

#### With GPL and non-free: https://ffmpeg.org/legal.html

```
curl -sSL https://ff-nonf.optimizethis.net | bash

```
#### Without GPL and non-free: https://ffmpeg.org/legal.html 
```
curl -sSL https://ff-free.optimizethis.net | bash

```

This command downloads the build script and automatically starts the build process.

#### Common installation (macOS, Linux)

```bash
git clone 'https://github.com/slyfox1186/ffmpeg-build-script.git'
cd 'ffmpeg-build-script/scripts'
sudo bash build-ffmpeg --build --enable-gpl-and-non-free

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
