FROM ubuntu:22.10 AS build

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update \
    && apt-get -y --no-install-recommends install build-essential curl ca-certificates libva-dev \
        python3 python-is-python3 ninja-build meson \
    && apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* \
    && update-ca-certificates

WORKDIR /app
COPY ./build-ffmpeg /app/build-ffmpeg

RUN SKIPINSTALL=yes /app/build-ffmpeg --build

FROM ubuntu:22.10

ENV DEBIAN_FRONTEND noninteractive

# install va-driver
RUN apt-get update \
    && apt-get -y install libva-drm2 \
    && apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

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
