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
          ln -s ${pkgs.pkgsStatic.busybox}/bin/grep $out/bin/grep
        '';
        minimalShadow = pkgs.runCommand "minimal-shadow" { } ''
          mkdir -p $out/bin
          ln -s ${pkgs.shadow}/bin/useradd $out/bin/useradd
          ln -s ${pkgs.shadow}/bin/groupadd $out/bin/groupadd
          ln -s ${pkgs.shadow}/bin/usermod $out/bin/usermod
        '';
        fakeGit = pkgs.runCommand "fake-git" { } ''
          mkdir -p $out/bin

          # Create the script file
          cat > $out/bin/git <<'EOF'
          #!/bin/sh
          # Function to find the .git directory by walking up
          find_git_dir() {
            local dir="."
            while [ "$dir" != "/" ]; do
              if [ -d "$dir/.git" ]; then
                echo "$dir/.git"
                return 0
              fi
              dir=$(dirname $(readlink -f "$dir"))
            done
            return 1
          }

          if [ "$1" = "rev-parse" ] && [ "$2" = "--short" ] && [ "$3" = "HEAD" ]; then
            GIT_DIR=$(find_git_dir)

            if [ -z "$GIT_DIR" ]; then
              echo "fatal: not a git repository"
              exit 128
            fi

            head_content=$(cat "$GIT_DIR/HEAD")

            # Check if we are in detached HEAD state (head_content is just the hash)
            if echo "$head_content" | grep -q "^ref:"; then
               ref_path=$(echo "$head_content" | cut -d' ' -f2)

               if [ -f "$GIT_DIR/$ref_path" ]; then
                 # Loose ref
                 full_hash=$(cat "$GIT_DIR/$ref_path")
               elif [ -f "$GIT_DIR/packed-refs" ]; then
                 # Packed ref
                 full_hash=$(grep "$ref_path" "$GIT_DIR/packed-refs" | cut -d' ' -f1)
               else
                 echo "fatal: ref $ref_path not found"
                 exit 128
               fi
            else
               full_hash="$head_content"
            fi

            echo "$full_hash" | head -c 7
          else
            echo "Error: This fake git only supports 'rev-parse --short HEAD'"
            exit 1
          fi
          EOF
          chmod +x $out/bin/git
        '';
        tools = [
          minimalUtils
          minimalShadow
          fakeGit
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
