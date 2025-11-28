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
        minimalUtils = pkgs.runCommand "minimal-utils" { } ''
          mkdir -p $out/bin
          ln -s ${pkgs.pkgsStatic.busybox}/bin/sh $out/bin/sh
          ln -s ${pkgs.pkgsStatic.busybox}/bin/rm $out/bin/rm
          ln -s ${pkgs.pkgsStatic.busybox}/bin/cat $out/bin/cat
          ln -s ${pkgs.pkgsStatic.busybox}/bin/echo $out/bin/echo
        '';
        minimalShadow = pkgs.runCommand "minimal-shadow" { } ''
          mkdir -p $out/bin
          ln -s ${pkgs.shadow}/bin/useradd $out/bin/useradd
          ln -s ${pkgs.shadow}/bin/groupadd $out/bin/groupadd
          ln -s ${pkgs.shadow}/bin/usermod $out/bin/usermod
        '';
        tools = [
          minimalUtils
          minimalShadow
          pkgs.gitMinimal
          pkgs.cosign
          pkgs.jq
          pkgs.go-task
          pkgs.buildah
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

        defaultPackage = self.packages.${system}.tools;
      }
    );
}
