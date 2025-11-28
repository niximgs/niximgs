{
  lib,
  dockerTools,
  makeFontsConf,
  callPackage,
  google-lighthouse,
  chromium,
  noto-fonts,
  bashInteractive,
  coreutils,
}:

let
  pkg = google-lighthouse;

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
      chromium
      noto-fonts
      bashInteractive
      coreutils
    ];

    extraCommands = ''
      mkdir -p tmp
      chmod 1777 tmp

      mkdir -p etc
      echo "root:x:0:0:Root:/var/empty:/bin/sh" > etc/passwd
      echo "root:x:0:" > etc/group
    '';

    config = {
      Env = [
        "HOME=/tmp"
        "CHROME_PATH=${pkgExecutable}"
        "FONTCONFIG_FILE=${
          makeFontsConf {
            fontDirectories = [
              noto-fonts
            ];
          }
        }"
      ];

      Entrypoint = [
        pkgExecutable
        "--chrome-flags=\"--headless --no-sandbox --disable-dev-shm-usage --disable-gpu\""
      ];

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
