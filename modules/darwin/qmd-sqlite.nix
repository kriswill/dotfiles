# Custom sqlite with loadable-extension support, for sqlite-vec and qmd
# (system-level port of the sqliteWithExtensions package + linkSqliteForQmd
# activation that used to live in home-manager/core.nix).
#
# qmd (bun-installed, outside nix) hardcodes two Homebrew paths in its
# setCustomSQLite() call and ignores env vars. We point the Apple-Silicon path
# at this extension-enabled nix sqlite so qmd can dlopen it; we skip if a real
# Homebrew sqlite is already installed there.
{
  flake.modules.darwin.qmd-sqlite =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    let
      sqliteWithExtensions = pkgs.sqlite.overrideAttrs (old: {
        env = (old.env or { }) // {
          NIX_CFLAGS_COMPILE = (old.env.NIX_CFLAGS_COMPILE or "") + " -DSQLITE_ENABLE_LOAD_EXTENSION=1";
        };
      });
    in
    {
      config = lib.mkIf config.kriswill.enable {
        # modules/darwin/neovim.nix also puts a plain pkgs.sqlite in
        # environment.systemPackages; both expose bin/sqlite3 under the same
        # name, so without a priority the buildEnv would pick one by list order.
        # hiPrio makes the extension-enabled build win deterministically, so the
        # `sqlite3` on PATH can always load extensions (sqlite-vec, qmd) — the
        # behavior the old per-user home.packages sqlite gave.
        environment.systemPackages = [ (lib.hiPrio sqliteWithExtensions) ];

        # Order 1600: after dotfiles-stow (1500). Run as the user — /opt/homebrew
        # is user-owned on Apple Silicon, and the link shouldn't be root-owned.
        system.activationScripts.postActivation.text = lib.mkOrder 1600 ''
          /usr/bin/sudo -u k --set-home /bin/sh -c '
            brew_lib=/opt/homebrew/opt/sqlite/lib
            link=$brew_lib/libsqlite3.dylib
            target=${sqliteWithExtensions.out}/lib/libsqlite3.dylib
            if [ -e "$link" ] && [ ! -L "$link" ]; then
              echo "qmd-sqlite-link: $link is a real file (Homebrew install?), leaving alone" >&2
            else
              mkdir -p "$brew_lib"
              ln -sfn "$target" "$link"
            fi
          '
        '';
      };
    };
}
