# Image Buildah

This image is designed to be used to build other images via [Buildah](https://buildah.io/) within CI/CD pipelines. A key and unique, in my opinion, feature here is that the project has been configured with [Nix](https://nixos.wiki/) and [Nix Flakes](https://nixos.wiki/wiki/flakes). This has several key features:

1. The shell environment and binaries within the container is near identical to the shell Nix can provide locally.
2. The image is run from scratch.
    - This means the image is nearly as small as possible.
    - Security-wise, there are fewer binaries that are left in when compared to distros like Alpine or Debian based images.
3. As Nix flakes pin the exact versions, all binaries will stay at a constant, known state.
    - With Alpine or Debian based images, when updating or installing packages, this is not a given.
4. The commands run via the [Taskfile](../../Taskfile.yaml) will be the same locally as they are within CI/CD pipelines.
5. It allows for easily allow for different CPU architecture images and local dev.

## Getting Started

### Shell Env

As this project uses Nix, to gain access to all dependencies, run:

```bash
nix shell
```

### Building and Pushing the Image

To build, push and sign (via [Cosign](https://github.com/sigstore/cosign)) images run:

```bash
nix shell --command task publish TAG=$(git rev-parse --short HEAD) IMG_NAME=image-buildah PUSH_LATEST=true
```

This will push and sign images to the self-hosted [Harbor](../../storage/harbor/README.md) instance within the cluster.

***WARNING:*** The [Taskfile](../../Taskfile.yaml) used is tailored to the cluster and my preferences. Use it for inspiration only, as all the secrets and config will be different in some other cluster.

