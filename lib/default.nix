# Pure helpers merged onto nixpkgs lib (see modules/darwin.nix). Kept outside
# ./modules so import-tree does not treat it as a flake-parts module.
{
  kanagawa = import ./kanagawa.nix;
}
