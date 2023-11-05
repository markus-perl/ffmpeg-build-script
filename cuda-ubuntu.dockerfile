ARG VER=22.04

FROM ubuntu:${VER} AS build

ARG CUDAVER=11.8.0-1

ENV DEBIAN_FRONTEND noninteractive
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility,video

RUN apt-get update \
    && apt-get -y --no-install-recommends install wget ca-certificates \
    && update-ca-certificates \
    && wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.0-1_all.deb \
    && dpkg -i cuda-keyring_1.0-1_all.deb \
    && apt-get update

RUN apt-get -y --no-install-recommends install build-essential curl libva-dev python3 python-is-python3 ninja-build meson \
    cuda="${CUDAVER}" \
    && apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*


WORKDIR /app
COPY ./build-ffmpeg-1 /app/build-ffmpeg-1
COPY ./build-ffmpeg-2 /app/build-ffmpeg-2


RUN SKIPINSTALL=yes /app/build-ffmpeg-1 --build --enable-gpl-and-non-free


ENTRYPOINT ["tail", "-f", "/dev/null"]
