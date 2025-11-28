{
  lib,
  dockerTools,
  makeFontsConf,
  callPackage,
  shot-scraper,
  playwright-driver,
  noto-fonts,
  coreutils,
}:

let
  pkg = shot-scraper;

  pkgName = lib.getName pkg;
  pkgVersion = lib.getVersion pkg;
  pkgExecutable = lib.getExe pkg;

  withOCIAnnotationsFromNixpkgs = callPackage ../../lib/withOCIAnnotationsFromNixpkgs.nix { };
  withMetadataFromNixpkgs = callPackage ../../lib/withMetadataFromNixpkgs.nix { };

  image = dockerTools.buildLayeredImage {
    name = pkgName;
    tag = pkgVersion;

    contents = [
      pkg

      # Dependencies
      playwright-driver.browsers
      noto-fonts
      coreutils
    ];

    extraCommands = ''
      mkdir -p homeless-shelter
      chmod 1777 homeless-shelter
      mkdir -p tmp
      chmod 1777 tmp
    '';

    config = {
      Env = [
        "HOME=/homeless-shelter"

        "PLAYWRIGHT_BROWSERS_PATH=${playwright-driver.browsers}"
        "PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1"

        "FONTCONFIG_FILE=${
          makeFontsConf {
            fontDirectories = [
              noto-fonts
            ];
          }
        }"
      ];

      Entrypoint = [ pkgExecutable ];

      WorkingDir = "/mnt/local";

      Volumes = {
        "/mnt/local" = { };
      };

      Labels = withOCIAnnotationsFromNixpkgs pkg { };
    };
  };
in
withMetadataFromNixpkgs {
  inherit image pkg;
}
