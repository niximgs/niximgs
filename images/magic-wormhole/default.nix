{
  lib,
  dockerTools,
  callPackage,
  magic-wormhole,
}:

let
  pkg = magic-wormhole;

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
    ];

    config = {
      Entrypoint = [ pkgExecutable ];
      Labels = withOCIAnnotationsFromNixpkgs pkg { };
    };
  };
in
withMetadataFromNixpkgs {
  inherit image pkg;
}
