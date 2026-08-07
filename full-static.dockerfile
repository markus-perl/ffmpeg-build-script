FROM ubuntu:24.04 AS build

ENV DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility,video

RUN apt-get update \
    && apt-get -y --no-install-recommends install build-essential curl ca-certificates python3 \
    python-is-python3 ninja-build meson git fonts-dejavu-core \
    && apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* \
    && update-ca-certificates

WORKDIR /app
COPY ./build-ffmpeg /app/build-ffmpeg

RUN AUTOINSTALL=yes /app/build-ffmpeg --build --full-static

# Check shared library
RUN ! ldd /app/workspace/bin/ffmpeg
RUN ! ldd /app/workspace/bin/ffprobe
RUN ! ldd /app/workspace/bin/ffplay

FROM scratch

ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility,video

# fontconfig is compiled to look for its configuration in the build workspace, which does not
# exist here, so point it at the copied configuration instead. Without this, drawtext cannot
# resolve fonts by name and libass falls back to a default font.
ENV FONTCONFIG_PATH=/etc/fonts
COPY --from=build /app/workspace/etc/fonts /etc/fonts
COPY --from=build /usr/share/fonts /usr/share/fonts

# Copy ffmpeg
COPY --from=build /app/workspace/bin/ffmpeg /ffmpeg
COPY --from=build /app/workspace/bin/ffprobe /ffprobe
COPY --from=build /app/workspace/bin/ffplay /ffplay

CMD         ["--help"]
ENTRYPOINT  ["/ffmpeg"]
