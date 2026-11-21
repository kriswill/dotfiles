{
  configurations.nixos.nebula.module = {
    programs = {
      # Herdr, the desktop app, and herdr-core (`hc`), from upstream's release
      # builds (./flakes/herdr, via modules/nixos/herdr.nix, which also installs
      # the herdr TUI everywhere). Telemetry stays off (the module's default).
      herdr-app.enable = true;
      herdr-core = {
        # Declares linger (the module's default), which hc would turn on by
        # itself anyway: the core and its terminals outlive logouts, and k's
        # user manager starts at boot (so herdr-update-check waits for a
        # notification daemon).
        users = [ "k" ];
        # BROWSER=herdr-open: a click on a link in Claude Code on nebula opens in
        # the browser of the machine whose Herdr window you clicked in, through
        # the herdr-open mod in home/herdr-app. Outside hc, plain xdg-open.
        browser.enable = true;
      };
      # herdr-md, a markdown viewer mod, and `mdh`, which opens a file in it and
      # highlights passages (for agents): upstream at a pinned commit with our
      # Linux patch, its figure renderer on bun (flakes/herdr/pkgs/herdr-md.nix).
      # Linked into ~/.config/herdr-app/mods/herdr-md; home/herdr-app's keys.json
      # binds ctrl-shift-m and ctrl-space m to a viewer in its file picker.
      # Mermaid diagrams are drawn by the helium on PATH.
      herdr-md.enable = true;
    };

    # Config files are NOT declared here (the module's file options stay
    # null): the stow packages home/herdr-core and home/herdr-app own them, so
    # they're versioned. The app's saves write through those symlinks into
    # the repo; capture new ones (keys.json, a custom layout or theme) with
    # `dots-adopt herdr-app .config/herdr-app/<file>`. settings.json alone is
    # per-OS, in home/herdr-app-linux (the macs' is home/herdr-app-darwin):
    # zoom suits each display, so the two no longer fight in git.

    # Daily: one notification when upstream releases past our herdr fork
    # (rebase `custom`, retag, repoint flakes/herdr's herdr-cli input) or past
    # sources.json (bump with `bun flakes/herdr/update.ts`, then nrs), or when
    # a running herdr server, core or window is older than the installed
    # build. After an nrs that bumped them, run `herdr-update-check` by hand
    # rather than wait for the timer. Replaces nebula's old fork-only
    # herdr-update-check unit (same unit name).
    services.herdr-update-check.enable = true;
  };
}
