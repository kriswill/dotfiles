# Development shell and formatter.
{
  perSystem =
    { pkgs, ... }:
    let
      # `okf` on the dev-shell PATH (scaffold|index|validate|viz). The tools
      # read and write the working tree, so resolve the checkout at call time
      # via git rather than baking a /nix/store copy of scripts/okf in.
      okf = pkgs.writeShellApplication {
        name = "okf";
        runtimeInputs = builtins.attrValues { inherit (pkgs) bun git; };
        text = ''
          root="$(git rev-parse --show-toplevel)"
          if [[ ! -f "$root/scripts/okf/okf.ts" ]]; then
            echo "okf: $root has no scripts/okf/okf.ts — run inside the dotfiles repo" >&2
            exit 1
          fi
          exec bun "$root/scripts/okf/okf.ts" "$@"
        '';
      };
    in
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
          inherit okf;
        };
        shellHook = ''
          PATH_add "$PWD/bin"
        '';
      };
    };
}
