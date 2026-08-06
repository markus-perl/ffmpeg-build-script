ARG CUDAVER=13.3.1
ARG UBUNTUVER=22.04
# cuda-samples tag to build deviceQuery from. Keep in sync with CUDAVER.
# Never track master: the layout changes between releases (v13.0 moved
# Samples/ to cpp/), which silently breaks the sparse-checkout below.
ARG CUDASAMPLESVER=v13.3

FROM nvidia/cuda:${CUDAVER}-devel-ubuntu${UBUNTUVER} AS build

ENV DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility,video

# Update package lists
RUN apt-get update
# Install required packages
RUN apt-get -y --no-install-recommends install build-essential curl ca-certificates libva-dev libva-drm2 cmake \
    python3 python-is-python3 ninja-build meson git curl
# Clean up package cache and temporary files
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* && find /var/log -type f -delete
# Update CA certificates
RUN update-ca-certificates


# Install NVIDIA CUDA samples to get deviceQuery
ARG CUDASAMPLESVER
RUN mkdir -p /code && \
    git clone --depth 1 --branch "$CUDASAMPLESVER" --filter=blob:none --sparse https://github.com/NVIDIA/cuda-samples.git /code/cuda-samples && \
    cd /code/cuda-samples && \
    git sparse-checkout set cpp/1_Utilities/deviceQuery Common cmake && \
    test -f cpp/1_Utilities/deviceQuery/CMakeLists.txt

# Build deviceQuery in its original location where it can find dependencies
WORKDIR /code/cuda-samples/cpp/1_Utilities/deviceQuery
RUN mkdir build && cd build && \
    cmake .. && \
    make -j$(nproc) && \
    cp deviceQuery /usr/local/bin/ && \
    cd /code && \
    rm -rf cuda-samples

WORKDIR /app

# Stage the NPP runtime libs for the release image. Copying the real SONAME
# files (libnppc.so.13, ...) keeps this independent of the CUDA version, unlike
# hardcoding /usr/local/cuda-<ver> and the .so.<major> suffix.
RUN mkdir -p /npp && cd /usr/local/cuda/targets/x86_64-linux/lib && \
    cp -a libnppc.so.* libnppig.so.* libnppicc.so.* libnppidei.so.* libnppif.so.* /npp/

COPY ./build-ffmpeg /app/build-ffmpeg

RUN CUDA_COMPUTE_CAPABILITY=$(deviceQuery | grep Capability | head -n 1 | awk 'END {print $NF}' | tr -d '.') SKIPINSTALL=yes /app/build-ffmpeg --build --enable-gpl-and-non-free && \
    rm -rf /app/packages/* /app/workspace/doc/* /app/workspace/lib/* /app/workspace/share/* /app/workspace/include/*

FROM ubuntu:${UBUNTUVER} AS release

ENV DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility,video

# install va-driver
RUN apt-get update \
    && apt-get -y install libva-drm2 \
    && apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

# Copy libnpp (staged in the build stage, so no CUDA version appears here)
COPY --from=build /npp/ /lib/x86_64-linux-gnu/

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
