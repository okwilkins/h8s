{
  description = "Flake for workflow runner image creation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        buildah = pkgs.buildah.override { crun = null; };
        tools = [
          pkgs.pkgsStatic.busybox
          buildah
        ];
      in
      {
        devShells.default = pkgs.mkShellNoCC {
          buildInputs = tools;
        };
        packages.tools = pkgs.buildEnv {
          name = "tools";
          paths = tools;
          pathsToLink = [ "/bin" ];
        };
        packages.image-tools = pkgs.buildEnv {
          name = "image-tools";
          paths = tools ++ [
            pkgs.shadow
            pkgs.fuse-overlayfs
          ];
          pathsToLink = [ "/bin" ];
        };
        packages.rootfs-python = pkgs.python3Minimal;
        packages.setcap = pkgs.pkgsStatic.libcap.override { withGo = false; };
        defaultPackage = self.packages.${system}.tools;
      }
    );
}
