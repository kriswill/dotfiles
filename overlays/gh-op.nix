# On Linux, wrap gh to source its token from 1Password at runtime (GH_TOKEN
# via `op read`), so ~/.config/gh/hosts.yml holds no plain-text token on
# nebula's unencrypted disk. This single wrapper covers every consumer: the
# CLI itself and git's `!gh auth git-credential` credential helper both
# resolve `gh` from PATH. `op` is deliberately invoked by bare name — on
# NixOS it must resolve to the setgid security wrapper (/run/wrappers/bin/op,
# group onepassword-cli) or desktop-app integration breaks.
#
# On darwin, pass gh through untouched (FileVault disks; hosts.yml is fine).
_final: prev: {
  gh =
    if prev.stdenv.isLinux then
      prev.symlinkJoin {
        name = "gh-op-${prev.gh.version}";
        paths = [ prev.gh ];
        inherit (prev.gh) meta;
        postBuild = ''
          rm $out/bin/gh
          cat > $out/bin/gh <<'EOF'
          #!/bin/sh
          # `gh auth login/logout/refresh` must see the real auth state
          # (gh refuses to log in while GH_TOKEN is set), so skip injection.
          case "$1 $2" in
            "auth login" | "auth logout" | "auth refresh") ;;
            *)
              if [ -z "''${GH_TOKEN-}" ]; then
                # ponytail: one op read per gh call (~0.5s, needs the 1Password
                # app unlocked); on failure fall through to hosts.yml behaviour
                GH_TOKEN=$(op read "op://Private/GitHub gh CLI token/credential" 2>/dev/null) \
                  && export GH_TOKEN
              fi
              ;;
          esac
          exec ${prev.gh}/bin/gh "$@"
          EOF
          chmod +x $out/bin/gh
        '';
      }
    else
      prev.gh;
}
