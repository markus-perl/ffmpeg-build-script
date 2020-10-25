ARG DIST=ubuntu
ARG VER=20.04

FROM nvidia/cuda:11.1-devel-${DIST}${VER} AS build

ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility,video

RUN apt-get update \
    && apt-get -y --no-install-recommends install build-essential curl ca-certificates python3 \
    && apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* \
    && update-ca-certificates

WORKDIR /app
COPY ./build-ffmpeg /app/build-ffmpeg

RUN SKIPINSTALL=yes /app/build-ffmpeg --build


FROM ${DIST}:${VER}

# Copy libnpp
COPY --from=build /usr/local/cuda-11.1/targets/x86_64-linux/lib/libnppc.so.11 /lib/x86_64-linux-gnu/libnppc.so.11
COPY --from=build /usr/local/cuda-11.1/targets/x86_64-linux/lib/libnppig.so.11 /lib/x86_64-linux-gnu/libnppig.so.11
COPY --from=build /usr/local/cuda-11.1/targets/x86_64-linux/lib/libnppicc.so.11 /lib/x86_64-linux-gnu/libnppicc.so.11
COPY --from=build /usr/local/cuda-11.1/targets/x86_64-linux/lib/libnppidei.so.11 /lib/x86_64-linux-gnu/libnppidei.so.11

# Copy ffmpeg
COPY --from=build /app/workspace/bin/ffmpeg /usr/bin/ffmpeg
COPY --from=build /app/workspace/bin/ffprobe /usr/bin/ffprobe

RUN ldd /usr/bin/ffmpeg ; exit 0
RUN ldd /usr/bin/ffprobe ; exit 0

CMD         ["--help"]
ENTRYPOINT  ["/usr/bin/ffmpeg"]