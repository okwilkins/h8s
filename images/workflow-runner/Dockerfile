ARG USER=buildah
ARG UID=1000
ARG GID=1000

FROM harbor.okwilkins.dev/docker-hub-cache/nixos/nix:2.32.4 AS builder

ARG USER
ARG UID
ARG GID

ENV NIX_CONFIG="experimental-features = nix-command flakes"

WORKDIR /tmp/build
COPY flake.nix flake.lock ./

RUN nix \
    --option filter-syscalls false \
    build .

RUN mkdir /tmp/nix-store-closure
RUN cp -R $(nix-store -qR result/) /tmp/nix-store-closure

RUN mkdir -p /tmp/etc
RUN echo "${USER}:x:${UID}:${GID}:${USER} container user:/home/${USER}:/bin/bash" > /tmp/etc/passwd
RUN echo "${USER}:x:${GID}:" > /tmp/etc/group

# Create buildah storage configuration
# This tells buildah where to store container data when running rootless
RUN mkdir -p /tmp/home/${USER}/.config/containers
RUN echo '[storage]' > /tmp/home/${USER}/.config/containers/storage.conf && \
    echo 'driver = "vfs"' >> /tmp/home/${USER}/.config/containers/storage.conf && \
    echo 'runroot = "/home/${USER}/.local/share/containers/storage-run"' >> /tmp/home/${USER}/.config/containers/storage.conf && \
    echo 'graphroot = "/home/${USER}/.local/share/containers/storage"' >> /tmp/home/${USER}/.config/containers/storage.conf

# Create the directories buildah will use for storage
RUN mkdir -p /tmp/home/${USER}/.local/share/containers/storage-run && \
    mkdir -p /tmp/home/${USER}/.local/share/containers/storage


FROM scratch

ARG USER
ARG UID
ARG GID

WORKDIR /workspace
ENV PATH="/workspace/bin"
ENV BUILDAH_ISOLATION=chroot
ENV XDG_RUNTIME_DIR=/home/${USER}/.local/share/containers/storage-run

COPY --from=builder /tmp/etc/passwd /etc/passwd
COPY --from=builder /tmp/etc/group /etc/group
COPY --from=builder --chown=${UID}:${GID} /tmp/home/${USER} /home/${USER}

COPY --from=builder /tmp/nix-store-closure /nix/store
COPY --from=builder /tmp/build/result /workspace

USER ${UID}:${GID}

CMD ["/workspace/bin/bash"]

