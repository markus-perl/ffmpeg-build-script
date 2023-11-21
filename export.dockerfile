ARG DIST=ubuntu

FROM scratch

# Copy libnpp
COPY --from=ffmpeg:cuda-${DIST} /lib/x86_64-linux-gnu/libnppc.so.12 /lib/libnppc.so.12
COPY --from=ffmpeg:cuda-${DIST} /lib/x86_64-linux-gnu/libnppig.so.12 /lib/libnppig.so.12
COPY --from=ffmpeg:cuda-${DIST} /lib/x86_64-linux-gnu/libnppicc.so.12 /lib/libnppicc.so.12
COPY --from=ffmpeg:cuda-${DIST} /lib/x86_64-linux-gnu/libnppidei.so.12 /lib/libnppidei.so.12

# Copy ffmpeg
COPY --from=ffmpeg:cuda-${DIST} /usr/bin/ffmpeg /bin/ffmpeg
COPY --from=ffmpeg:cuda-${DIST} /usr/bin/ffprobe /bin/ffprobe
COPY --from=ffmpeg:cuda-${DIST} /usr/bin/ffplay /bin/ffplay