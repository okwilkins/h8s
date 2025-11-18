# H8s (Homernetes)

H8s is a home infrastructure project that combines the power of Kubernetes with the security-first approach of Talos OS.
This project provides a my setup, designed specifically for home labs and personal cloud environments.

## Getting Started

### CLI Tools

This repo uses [Nix Flakes](https://nixos.wiki/wiki/flakes) to install all dependencies to run all commands and scripts. To get started:

1. Exnable experimental-features. Read the Nix Flakes wiki for more information.
2. Run the following to drop into a shell with all dependencies:

```bash
nix shell
```

