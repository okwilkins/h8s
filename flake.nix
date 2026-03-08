{
  description = "Tools for general use around h8s";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
          yq
          sshpass
          netcat
        ];
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = tools;
          shellHook = ''
            export PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
            export TF_VAR_project_root=$PROJECT_ROOT
            # TODO: Change this to just be infrastructure when refactoring everything together: i.e. move terraform into this project
            export INFRA_ROOT=$PROJECT_ROOT/infrastructure
            export TF_VAR_infra_root=$INFRA_ROOT
          '';
        };

        packages.tools = pkgs.buildEnv {
          name = "tools";
          paths = tools;
        };

        defaultPackage = self.packages.${system}.tools;
      }
    );
}
