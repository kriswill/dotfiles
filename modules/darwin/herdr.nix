# herdr on nix-darwin: the ./flakes/herdr umbrella's module
# (flakes/herdr/modules/darwin.nix), re-exported into the Dendritic module set,
# with everything herdr on every mac. It brings programs.herdr-cli (our fork's
# herdr, herdr-nav, python3 for the agent hooks — installed explicitly rather
# than relying on the Command Line Tools' /usr/bin/python3), programs.herdr-core
# (hc, upstream's signed macOS build), programs.herdr-app (upstream's signed
# Herdr.app, copied by nix-darwin into "/Applications/Nix Apps") and
# services.herdr-update-check (a launchd agent). The packages come from the
# umbrella, so no overlay is needed. NixOS twin: modules/nixos/herdr.nix, whose
# host-side enables live in modules/hosts/nebula/herdr.nix; the macs share one
# user and one setup, so theirs live here.
{ inputs, ... }:
{
  flake.modules.darwin.herdr = {
    imports = [ inputs.herdr.darwinModules.herdr ];
    programs.herdr-cli.enable = true;

    # Herdr and hc. Telemetry stays off (the module's default): on macOS that
    # is a settings.json key the module writes at activation, like the core
    # pin (/etc/herdr-core/hc). Config files are NOT declared here (the file
    # options stay null): the stow packages home/herdr-core and home/herdr-app
    # own them, shared with nebula, so they're versioned and the app's saves
    # write through into the repo. keys.json there binds ctrl/alt like the
    # Linux defaults, not macOS's cmd.
    programs.herdr-app.enable = true;
    programs.herdr-core.users = [ "k" ];

    # Daily at 10:00 (a launchd agent; a run missed asleep happens on wake):
    # one notification when upstream releases past our herdr fork (rebase
    # `custom`, retag, repoint flakes/herdr's herdr-cli input) or past
    # sources.json (bump with `bun flakes/herdr/update.ts`, then nrs), or when
    # a running herdr server or core is older than the installed build.
    services.herdr-update-check.enable = true;
  };
}
