ARG VER=8

FROM nvidia/cuda:11.6.0-devel-centos${VER} AS build

ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility,video


# Fix EOL Mirror issue
RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-Linux-*
# Pick one of these mirrors that works. vault.centos.org was giving me timeout issues
# RUN sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-Linux-*
# RUN sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://linuxsoft.cern.ch/centos-vault/|g' /etc/yum.repos.d/CentOS-Linux-*
# RUN sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://archive.kernel.org/centos-vault/|g' /etc/yum.repos.d/CentOS-Linux-*
RUN sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://mirror.nsc.liu.se/centos-store|g' /etc/yum.repos.d/CentOS-Linux-*

# upgrade to Rocky Linux 8
RUN dnf install -y ncurses \
 && dnf clean all \
 && rm -rf /var/cache/dnf \
 && rm -rf /var/cache/yum \
 && dnf install -y dnf-plugins-core \
 && dnf -y update
 
WORKDIR /opt/conversion_to_rocky
RUN curl -O https://raw.githubusercontent.com/rocky-linux/rocky-tools/main/migrate2rocky/migrate2rocky.sh && \
    chmod +x migrate2rocky.sh && \
    bash migrate2rocky.sh  -r


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
COPY --from=build /usr/local/cuda-11.6/targets/x86_64-linux/lib/libnppc.so.11 /lib64/libnppc.so.11
COPY --from=build /usr/local/cuda-11.6/targets/x86_64-linux/lib/libnppig.so.11 /lib64/libnppig.so.11
COPY --from=build /usr/local/cuda-11.6/targets/x86_64-linux/lib/libnppicc.so.11 /lib64/libnppicc.so.11
COPY --from=build /usr/local/cuda-11.6/targets/x86_64-linux/lib/libnppidei.so.11 /lib64/libnppidei.so.11
COPY --from=build /usr/local/cuda-11.6/targets/x86_64-linux/lib/libnppif.so.11 /lib64/libnppif.so.11

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