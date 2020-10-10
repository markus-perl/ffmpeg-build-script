FROM nvidia/cuda:11.1-devel-ubuntu20.04 AS build

ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility,video

RUN apt-get update \
    && apt-get -y --no-install-recommends install build-essential curl ca-certificates libz-dev \
    && apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* \
    && update-ca-certificates

WORKDIR /app
COPY ./build-ffmpeg /app/build-ffmpeg

RUN SKIPINSTALL=yes /app/build-ffmpeg --build

FROM nvidia/cuda:11.1-runtime-ubuntu20.04

ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility,video

COPY --from=build /app/workspace/bin/ffmpeg /usr/bin/ffmpeg
COPY --from=build /app/workspace/bin/ffprobe /usr/bin/ffprobe

RUN ldd /usr/bin/ffmpeg
RUN ldd /usr/bin/ffprobe

CMD         ["--help"]
ENTRYPOINT  ["/usr/bin/ffmpeg"]