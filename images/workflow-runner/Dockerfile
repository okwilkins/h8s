FROM harbor.okwilkins.dev/docker-hub-cache/nixos/nix:2.32.4

ENV NIX_CONFIG="experimental-features = nix-command flakes"

WORKDIR /workspace

COPY flake.nix flake.lock ./

RUN nix profile install .#dev-tools

# Create non-root user
RUN echo "nixuser:x:1000:1000:Nix User:/home/nixuser:/bin/sh" >> /etc/passwd && \
    echo "nixuser:x:1000:" >> /etc/group && \
    mkdir -p /home/nixuser && \
    chown -R 1000:1000 /workspace /home/nixuser

USER nixuser
ENV HOME=/home/nixuser
ENV PATH=/root/.nix-profile/bin:$PATH
