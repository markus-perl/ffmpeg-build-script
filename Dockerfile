FROM ubuntu:20.04 AS build

RUN apt-get update \
    && apt-get -y --no-install-recommends install build-essential curl ca-certificates python3 \
    && apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* \
    && update-ca-certificates

WORKDIR /app
COPY ./build-ffmpeg /app/build-ffmpeg

RUN SKIPINSTALL=yes /app/build-ffmpeg --build

FROM ubuntu:20.04

COPY --from=build /app/workspace/bin/ffmpeg /usr/bin/ffmpeg
COPY --from=build /app/workspace/bin/ffprobe /usr/bin/ffprobe

RUN ldd /usr/bin/ffmpeg ; exit 0
RUN ldd /usr/bin/ffprobe ; exit 0

CMD         ["--help"]
ENTRYPOINT  ["/usr/bin/ffmpeg"]