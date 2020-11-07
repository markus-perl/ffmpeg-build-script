FROM ubuntu:20.04 AS build

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update \
    && apt-get -y --no-install-recommends install build-essential curl ca-certificates libva-dev \
    && apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* \
    && update-ca-certificates

WORKDIR /app
COPY ./build-ffmpeg /app/build-ffmpeg

RUN SKIPINSTALL=yes /app/build-ffmpeg --build

FROM ubuntu:20.04

ENV DEBIAN_FRONTEND noninteractive

# install va-driver
RUN apt-get update \
    && apt-get -y install libva-drm2 \
    && apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

COPY --from=build /app/workspace/bin/ffmpeg /usr/bin/ffmpeg
COPY --from=build /app/workspace/bin/ffprobe /usr/bin/ffprobe

RUN ldd /usr/bin/ffmpeg ; exit 0
RUN ldd /usr/bin/ffprobe ; exit 0

CMD         ["--help"]
ENTRYPOINT  ["/usr/bin/ffmpeg"]