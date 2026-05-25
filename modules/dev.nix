# Development shell and formatter.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      formatter = pkgs.nixfmt-tree;
      devShells.default = pkgs.mkShell {
        name = "dotfiles";
        packages = builtins.attrValues {
          inherit (pkgs)
            deadnix
            statix
            nixfmt-tree
            just
            ;
        };
        shellHook = ''
          PATH_add "$PWD/bin"
        '';
      };
    };
}
