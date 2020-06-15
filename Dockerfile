ARG CLEANUP="yes"
FROM ubuntu:20.04 AS base
ARG MAKE_DOCS="no"

RUN apt-get update \
    && apt-get -y --no-install-recommends install  build-essential curl g++ ca-certificates libz-dev \
    && apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* \
    && update-ca-certificates

WORKDIR /app
COPY ./build-ffmpeg /app/build-ffmpeg

RUN AUTOINSTALL=yes /app/build-ffmpeg --build
RUN cp /app/workspace/bin/ffmpeg /usr/bin/ffmpeg
RUN cp /app/workspace/bin/ffprobe /usr/bin/ffprobe

FROM base as cleanup-no
FROM base as cleanup-yes
RUN /app/build-ffmpeg --cleanup

FROM cleanup-${CLEANUP} AS final

CMD         ["--help"]
ENTRYPOINT  ["/usr/bin/ffmpeg"]
