ARG VER=20.04

FROM nvidia/cuda:11.4.2-devel-ubuntu${VER} AS build

ENV DEBIAN_FRONTEND noninteractive
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility,video

RUN apt-get update \
    && apt-get -y --no-install-recommends install build-essential curl ca-certificates libva-dev python3 python-is-python3 ninja-build meson \
    && apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* \
    && update-ca-certificates

WORKDIR /app
COPY ./build-ffmpeg /app/build-ffmpeg

RUN SKIPINSTALL=yes /app/build-ffmpeg --build --enable-gpl-and-non-free


FROM ubuntu:${VER}

ENV DEBIAN_FRONTEND noninteractive
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility,video

# install va-driver
RUN apt-get update \
    && apt-get -y install libva-drm2 \
    && apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

# Copy libnpp
COPY --from=build /usr/local/cuda-11.4/targets/x86_64-linux/lib/libnppc.so.11 /lib/x86_64-linux-gnu/libnppc.so.11
COPY --from=build /usr/local/cuda-11.4/targets/x86_64-linux/lib/libnppig.so.11 /lib/x86_64-linux-gnu/libnppig.so.11
COPY --from=build /usr/local/cuda-11.4/targets/x86_64-linux/lib/libnppicc.so.11 /lib/x86_64-linux-gnu/libnppicc.so.11
COPY --from=build /usr/local/cuda-11.4/targets/x86_64-linux/lib/libnppidei.so.11 /lib/x86_64-linux-gnu/libnppidei.so.11

# Copy ffmpeg
COPY --from=build /app/workspace/bin/ffmpeg /usr/bin/ffmpeg
COPY --from=build /app/workspace/bin/ffprobe /usr/bin/ffprobe
COPY --from=build /app/workspace/bin/ffplay /usr/bin/ffplay

# Check shared library
RUN ldd /usr/bin/ffmpeg
RUN ldd /usr/bin/ffprobe
RUN ldd /usr/bin/ffplay

CMD         ["--help"]
ENTRYPOINT  ["/usr/bin/ffmpeg"]
