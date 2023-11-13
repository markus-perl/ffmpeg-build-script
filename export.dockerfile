ARG DIST=ubuntu

FROM scratch

# Copy libnpp
COPY --from=ffmpeg:cuda-${DIST} /lib/x86_64-linux-gnu/libnppc.so /lib/libnppc.so
COPY --from=ffmpeg:cuda-${DIST} /lib/x86_64-linux-gnu/libnppig.so /lib/libnppig.so
COPY --from=ffmpeg:cuda-${DIST} /lib/x86_64-linux-gnu/libnppicc.so /lib/libnppicc.so
COPY --from=ffmpeg:cuda-${DIST} /lib/x86_64-linux-gnu/libnppidei.so /lib/libnppidei.so

# Copy ffmpeg
COPY --from=ffmpeg:cuda-${DIST} /usr/bin/ffmpeg /bin/ffmpeg
COPY --from=ffmpeg:cuda-${DIST} /usr/bin/ffprobe /bin/ffprobe
COPY --from=ffmpeg:cuda-${DIST} /usr/bin/ffplay /bin/ffplay