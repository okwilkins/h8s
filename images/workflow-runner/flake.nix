{
  description = "Flake for workflow runner image creation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
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
        tools = [
          pkgs.bash
          pkgs.cosign
          pkgs.jq
          pkgs.go-task
          pkgs.buildah
        ];
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = tools;
        };

        packages.tools = pkgs.buildEnv {
          name = "tools";
          paths = tools;
        };

        defaultPackage = self.packages.${system}.tools;
      }
    );
}
