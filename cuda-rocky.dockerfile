ARG VER=8

FROM nvidia/cuda:11.7.0-devel-rockylinux${VER} AS build

ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility,video

RUN yum group install -y "Development Tools" \
    && yum install -y curl libva-devel python3 \
    && yum install -y meson ninja-build --enablerepo=powertools \
    && rm -rf /var/cache/yum/* /var/cache/dnf/* \
    && yum clean all \
    && alternatives --set python /usr/bin/python3

WORKDIR /app
COPY ./build-ffmpeg /app/build-ffmpeg

RUN SKIPINSTALL=yes /app/build-ffmpeg --build --enable-gpl-and-non-free


FROM rockylinux:${VER}

ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility,video

# install va-driver
RUN yum install -y libva \
    && rm -rf /var/cache/yum/* \
    && yum clean all

# Copy libnpp
COPY --from=build /usr/local/cuda-11.7/targets/x86_64-linux/lib/libnppc.so.11 /lib64/libnppc.so.11
COPY --from=build /usr/local/cuda-11.7/targets/x86_64-linux/lib/libnppig.so.11 /lib64/libnppig.so.11
COPY --from=build /usr/local/cuda-11.7/targets/x86_64-linux/lib/libnppicc.so.11 /lib64/libnppicc.so.11
COPY --from=build /usr/local/cuda-11.7/targets/x86_64-linux/lib/libnppidei.so.11 /lib64/libnppidei.so.11
COPY --from=build /usr/local/cuda-11.7/targets/x86_64-linux/lib/libnppif.so.11 /lib64/libnppif.so.11

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