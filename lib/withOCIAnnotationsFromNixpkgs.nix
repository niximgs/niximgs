{
  lib,
  callPackage,
}:

pkg: overrides:

let
  withOCIAnnotations = callPackage ./withOCIAnnotations.nix { };

  defaults = {
    Title = lib.getName pkg;
    Description = pkg.meta.description or null;
    Version = lib.getVersion pkg;
    URL = pkg.meta.homepage or null;
    Source = pkg.meta.homepage or null;
    Documentation = pkg.meta.documentation or null;
    Licenses = pkg.meta.license.spdxId or null;

    Authors =
      if pkg.meta ? maintainers then
        lib.concatStringsSep ", " (map (m: m.name or m) pkg.meta.maintainers)
      else
        null;

    Vendor = "nixpkgs";
  };
in
withOCIAnnotations (defaults // overrides)
