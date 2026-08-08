FROM ubuntu:26.04 AS build

ENV DEBIAN_FRONTEND=noninteractive

# libasound2-dev and libpulse-dev are build-time probes, not vendored dependencies.
# build_openal compiles an ALSA backend only if alsa/asoundlib.h is present - without it
# openal-soft still builds, but with backends "OSS, WaveFile, Null", i.e. an openal indev
# that cannot open a microphone. build_libpulse does not build anything at all and only
# enables --enable-libpulse when libpulse.pc is on the host. Neither library is linked
# statically: openal dlopen()s libasound.so.2 and libpulse is a DT_NEEDED, so a container
# that wants to capture audio needs the matching runtime packages installed too.
RUN apt-get update \
    && apt-get -y --no-install-recommends install build-essential curl ca-certificates libva-dev \
        libasound2-dev libpulse-dev \
        python3 python-is-python3 ninja-build meson git curl fonts-dejavu-core \
    && apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* \
    && update-ca-certificates

WORKDIR /app
COPY ./build-ffmpeg /app/build-ffmpeg

RUN SKIPINSTALL=yes /app/build-ffmpeg --build

FROM ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive

# install va-driver, plus the runtime halves of the two audio device libraries.
# libpulse0 is not optional here: --enable-libpulse links libpulse.so.0 dynamically, so
# without it the binary does not start at all ("libpulse.so.0: cannot open shared object
# file"), not merely without pulse support. libasound2t64 is the ALSA runtime that
# openal-soft dlopen()s on the first alcCaptureOpenDevice(); missing it costs only the
# openal indev, which is why it is a separate concern from libpulse0.
RUN apt-get update \
    && apt-get -y install libva-drm2 libpulse0 libasound2t64 \
    && apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

# fontconfig is compiled to look for its configuration in the build workspace, which does not
# exist here, so point it at the copied configuration instead. Without this, drawtext cannot
# resolve fonts by name and libass falls back to a default font.
ENV FONTCONFIG_PATH=/etc/fonts
COPY --from=build /app/workspace/etc/fonts /etc/fonts
COPY --from=build /usr/share/fonts /usr/share/fonts

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