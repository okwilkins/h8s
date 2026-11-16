{
  description = "Flake for the README badge updater image";

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
        tools = [ pkgs.python3 ];
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
        packages.image-tools = self.packages.${system}.tools;
        packages.rootfs-python = pkgs.python3Minimal;
        defaultPackage = self.packages.${system}.tools;
      }
    );
}
