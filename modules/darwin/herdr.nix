# herdr on nix-darwin: the ./flakes/herdr umbrella's module
# (flakes/herdr/modules/darwin.nix), re-exported into the Dendritic module set,
# plus the herdr TUI on every mac. It brings programs.herdr-cli (our fork's
# herdr, herdr-nav, python3 for the agent hooks — installed explicitly rather
# than relying on the Command Line Tools' /usr/bin/python3),
# programs.herdr-core (hc; off unless a host turns it on), programs.herdr-app
# (Linux-only for now: asserts off here) and services.herdr-update-check (a
# launchd agent). The packages come from the umbrella, so no overlay is needed.
# NixOS twin: modules/nixos/herdr.nix.
{ inputs, ... }:
{
  flake.modules.darwin.herdr = {
    imports = [ inputs.herdr.darwinModules.herdr ];
    programs.herdr-cli.enable = true;
  };
}
