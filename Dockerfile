FROM ubuntu:18.10

RUN apt-get update \
    && apt-get -y --no-install-recommends install  build-essential curl g++ ca-certificates libz-dev \
    && apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* \
    && update-ca-certificates

WORKDIR /app
COPY ./build-ffmpeg /app/build-ffmpeg

RUN AUTOINSTALL=yes /app/build-ffmpeg --build
RUN cp /app/workspace/bin/ffmpeg /usr/bin/ffmpeg
RUN cp /app/workspace/bin/ffprobe /usr/bin/ffprobe
RUN /app/build-ffmpeg --cleanup

CMD         ["--help"]
ENTRYPOINT  ["/usr/bin/ffmpeg"]
