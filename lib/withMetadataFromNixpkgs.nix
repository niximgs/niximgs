{ lib }:

{ image, pkg }:

image
// {
  name = lib.getName pkg;
  version = lib.getVersion pkg;

  meta = pkg.meta // image.meta;
}
