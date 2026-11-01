{
  configurations.nixos.nebula.module = {
    # Herdr, the desktop app, and herdr-core (`hc`), from upstream's release
    # builds (./flakes/herdr, via modules/nixos/herdr.nix, which also installs
    # the herdr TUI everywhere). Telemetry stays off (the module's default).
    programs.herdr-app.enable = true;
    programs.herdr-core = {
      # Declares linger (the module's default), which hc would turn on by
      # itself anyway: the core and its terminals outlive logouts, and k's
      # user manager starts at boot (so herdr-update-check waits for a
      # notification daemon).
      users = [ "k" ];
    };
    # Config files are NOT declared here (the module's file options stay
    # null): the stow packages home/herdr-core and home/herdr-app own them, so
    # they're versioned. The app's saves write through those symlinks into
    # the repo; capture new ones (keys.json, a custom layout or theme) with
    # `dots-adopt herdr-app .config/herdr-app/<file>`.

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
