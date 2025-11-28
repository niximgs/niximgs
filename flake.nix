{
  description = "A Collection of Docker Images Built with Nix.";

  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-unstable";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    }:
    let
      supportedSystems = nixpkgs.lib.systems.flakeExposed;

      forAllSystems =
        function:
        nixpkgs.lib.genAttrs supportedSystems (
          system:
          function {
            pkgs = nixpkgs.legacyPackages.${system};
            inherit system;
          }
        );

      installNixPackages = pkgs: [
        pkgs.dive # Docker image explorer
        pkgs.nixd # Nix Language Server
        pkgs.nixfmt-rfc-style # Nix Formatter
      ];

      installNixFormatter = pkgs: pkgs.nixfmt-tree;
    in
    {
      formatter = forAllSystems ({ pkgs, ... }: installNixFormatter pkgs);

      devShells = forAllSystems (
        { pkgs, ... }:
        {
          default = pkgs.mkShellNoCC {
            packages = installNixPackages pkgs;
          };
        }
      );

      packages = forAllSystems (
        { pkgs, ... }:
        {
          default = pkgs.buildEnv {
            name = "profile";
            paths = installNixPackages pkgs;
          };

          google-lighthouse = pkgs.callPackage ./images/google-lighthouse { };
          magic-wormhole = pkgs.callPackage ./images/magic-wormhole { };
          shot-scraper = pkgs.callPackage ./images/shot-scraper { };
        }
      );

      apps = forAllSystems (
        { pkgs, system }:
        {
          "docker:push" = {
            type = "app";
            program =
              let
                packages = builtins.removeAttrs self.packages.${system} [ "default" ];

                packagesJSON = builtins.toJSON (
                  pkgs.lib.mapAttrsToList (attribute: pkg: {
                    attribute = attribute;
                    name = pkg.name;
                    version = pkg.version or "latest";
                  }) packages
                );
              in
              pkgs.lib.getExe (
                pkgs.writeShellApplication {
                  name = "docker-push";

                  runtimeInputs = [
                    pkgs.coreutils
                    pkgs.jq
                    pkgs.nix
                    pkgs.skopeo
                  ];

                  text = ''
                    oci_registry__verify_variables() {
                      echo "::group::Verifying Environment Variables"

                      for var in OCI_REGISTRY OCI_REGISTRY_REPOSITORY OCI_REGISTRY_USERNAME OCI_REGISTRY_PASSWORD; do
                        if [ -z "''${!var:-}" ]; then
                          echo >&2 "Error: Missing required environment variable '$var'."
                          exit 1
                        fi
                      done

                      echo "OCI_REGISTRY=''${OCI_REGISTRY:-}"
                      echo "OCI_REGISTRY_REPOSITORY=''${OCI_REGISTRY_REPOSITORY:-}"
                      echo "OCI_REGISTRY_USERNAME=''${OCI_REGISTRY_USERNAME:-}"
                      echo "OCI_REGISTRY_PASSWORD=******"

                      echo "::endgroup::"
                    }

                    oci_registry__login() {
                      echo "::group::Logging into OCI Registry: ''${OCI_REGISTRY:-}"

                      echo "''${OCI_REGISTRY_PASSWORD:-}" | skopeo login \
                        --username "''${OCI_REGISTRY_USERNAME:-}" \
                        --password-stdin \
                          "''${OCI_REGISTRY:-}"

                      echo "::endgroup::"
                    }

                    oci_registry__logout() {
                      echo "::group::Logging out of OCI Registry: ''${OCI_REGISTRY:-}"

                      skopeo logout "''${OCI_REGISTRY:-}"

                      echo "::endgroup::"
                    }

                    oci_registry__push() {
                      local package_json="$1"

                      local packageName
                      local packageVersion

                      packageName=$(echo "$package_json" | jq -r ".name")
                      packageVersion=$(echo "$package_json" | jq -r ".version")
                      packageAttribute=$(echo "$package_json" | jq -r ".attribute")

                      local targetImage="''${OCI_REGISTRY:-}/''${OCI_REGISTRY_REPOSITORY:-}/$packageName"

                      local targetImageWithVersion="$targetImage:$packageVersion"
                      local targetImageWithLatestVersion="$targetImage:latest"

                      if skopeo inspect "docker://$targetImageWithVersion" > /dev/null 2>&1; then
                        echo "::group::Skipping: $packageName:$packageVersion (Image Exists)"
                          
                          echo "$targetImageWithVersion already exists. Skipping..."

                        echo "::endgroup::"
                      else
                        echo "::group::Building: $packageName:$packageVersion"

                          local packagePath
                          packagePath=$(nix build ".#$packageAttribute" --print-out-paths --no-link);

                        echo "::endgroup::"

                        echo "::group::Pushing: $targetImageWithVersion"

                          skopeo copy \
                            "docker-archive:$packagePath" \
                            "docker://$targetImageWithVersion";

                        echo "::endgroup::"

                        echo "::group::Pushing: $targetImageWithLatestVersion"
                        
                          skopeo copy \
                            "docker://$targetImageWithVersion" \
                            "docker://$targetImageWithLatestVersion";

                        echo "::endgroup::"
                      fi
                    }

                    oci_registry__push_sequential() {
                      local packages_json="$1"

                      export -f oci_registry__push

                      echo "$packages_json" | jq -c '.[]' | while read -r package_json; do
                        oci_registry__push "$package_json"
                      done
                    }

                    main() {
                      oci_registry__verify_variables

                      oci_registry__login
                      oci_registry__push_sequential ${pkgs.lib.escapeShellArg packagesJSON}
                      oci_registry__logout
                    }

                    main
                  '';
                }
              );
          };
        }
      );
    };
}
