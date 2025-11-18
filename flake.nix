{
  description = "Tools for general use around h8s";

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
        tools = with pkgs; [
          kubectl
          kubernetes-helm
          talosctl
          argocd
          cilium-cli
          go-task
          jq
          opentofu
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
