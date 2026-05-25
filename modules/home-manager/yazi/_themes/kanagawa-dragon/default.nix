{ lib, ... }:
lib.fileset.toSource {
  root = ./.;
  fileset = lib.fileset.difference ./. ./default.nix;
}
