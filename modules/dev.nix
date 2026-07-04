# Development shell and formatter.
{
  perSystem =
    { pkgs, ... }:
    let
      # `okf` on the dev-shell PATH (scaffold|index|validate|viz), wrapping the
      # working-tree copy in flakes/okf so edits are live without a rebuild.
      # The nix-built package (inputs.okf, re-exported in modules/packages.nix)
      # is for external consumption; here fast iteration wins.
      okf = pkgs.writeShellApplication {
        name = "okf";
        runtimeInputs = builtins.attrValues { inherit (pkgs) bun git; };
        text = ''
          root="$(git rev-parse --show-toplevel)"
          if [[ ! -f "$root/flakes/okf/okf.ts" ]]; then
            echo "okf: $root has no flakes/okf/okf.ts — run inside the dotfiles repo" >&2
            exit 1
          fi
          OKF_PROG=okf exec bun "$root/flakes/okf/okf.ts" "$@"
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
            # Nix tooling (from nebula's old shell.nix)
            nil
            nix-output-monitor
            # Secrets (sops-nix age keys — see .sops.yaml)
            sops
            age
            ssh-to-age
            # Dotfiles management
            stow
            ;
          inherit okf;
        };
        shellHook = ''
          # plain export: works under both direnv (use flake) and nix develop
          # (PATH_add is a direnv-only function)
          export PATH="$PWD/bin:$PATH"
        '';
      };
    };
}
