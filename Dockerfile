FROM i386/debian:buster
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    coreutils qemu-user-static debootstrap dosfstools rsync xz-utils \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
VOLUME /source /workdir
WORKDIR /source
ENTRYPOINT ["bash"]

