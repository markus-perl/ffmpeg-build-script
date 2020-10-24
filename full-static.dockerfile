FROM nvidia/cuda:11.1-devel-ubuntu20.04 AS build

ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility,video

RUN apt-get update \
    && apt-get -y --no-install-recommends install build-essential curl ca-certificates python3 \
    && apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* \
    && update-ca-certificates

WORKDIR /app
COPY ./build-ffmpeg /app/build-ffmpeg

RUN AUTOINSTALL=yes /app/build-ffmpeg --build --full-static
RUN ldd /app/workspace/bin/ffmpeg ; exit 0
RUN ldd /app/workspace/bin/ffprobe ; exit 0

FROM scratch

COPY --from=build /app/workspace/bin/ffmpeg /usr/bin/ffmpeg
COPY --from=build /app/workspace/bin/ffprobe /usr/bin/ffprobe

CMD         ["--help"]
ENTRYPOINT  ["/usr/bin/ffmpeg"]