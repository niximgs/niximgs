{ lib }:

args@{
  Title ? null,
  Description ? null,
  URL ? null,
  Documentation ? null,
  Source ? null,
  Vendor ? null,
  Authors ? null,
  Version ? null,

  ...
}:

let
  ociAnnotationPrefix = "org.opencontainers.image.";
  ociAnnotationSuffix = suffix: lib.toLower suffix;

  # See: https://specs.opencontainers.org/image-spec/annotations/
  ociAnnotation =
    key: value:
    if value == null then { } else { "${ociAnnotationPrefix}${ociAnnotationSuffix key}" = value; };

  ociAnnotations = builtins.foldl' (
    accumulator: key: accumulator // ociAnnotation key args.${key}
  ) { } (builtins.attrNames args);
in
ociAnnotations
