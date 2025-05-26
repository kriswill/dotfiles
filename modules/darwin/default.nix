{ lib, ... }:
let
  programs = lib.autoImport ./programs;
in
{
  imports = programs;
}
