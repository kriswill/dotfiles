# Development shell and formatter.
{
  perSystem =
    { pkgs, inputs', ... }:
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
            # macOS codesigning without touching Keychain/ACLs — see
            # scripts/sign-launchd-agents.ts and
            # knowledge/decisions/nas-mount-codesigning.md
            rcodesign
            ;
          # `okf` on the dev-shell PATH (scaffold|index|validate|viz) — the
          # nix-built CLI from the okflight input (github:kriswill/okflight).
          # For live okf hacking, run a checkout directly
          # (`bun ~/src/okflight/okf.ts <cmd>`) or rebuild this shell with
          # `--override-input okf path:$HOME/src/okflight`.
          okf = inputs'.okf.packages.okf;
        };
        shellHook = ''
          # plain export: works under both direnv (use flake) and nix develop
          # (PATH_add is a direnv-only function)
          export PATH="$PWD/bin:$PATH"
        '';
      };
    };
}
