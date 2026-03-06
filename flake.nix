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
            export TF_VAR_project_root="$(git rev-parse --show-toplevel 2>/dev/null)"
            # TODO: Change this to just be infrastructure when refactoring everything together: i.e. move terraform into this project
            export TF_VAR_infra_root=$TF_VAR_project_root/infrastructure/bootstrap
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
