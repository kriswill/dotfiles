# herdr on NixOS: the ./flakes/herdr umbrella's module
# (flakes/herdr/modules/nixos.nix), re-exported into the Dendritic module set,
# plus the herdr TUI everywhere. It brings programs.herdr-cli (our fork's
# herdr, herdr-nav, python3 for the agent hooks), programs.herdr-core and
# programs.herdr-app (Herdr's desktop app + hc; off unless a host turns them
# on, as nebula does in modules/hosts/nebula/herdr.nix) and
# services.herdr-update-check. The packages come from the umbrella, so no
# overlay is needed (pkgs.herdr is kept for hermes-agent; modules/overlays.nix).
# Darwin twin: modules/darwin/herdr.nix.
{ inputs, ... }:
{
  flake.modules.nixos.herdr = {
    imports = [ inputs.herdr.nixosModules.herdr ];
    programs.herdr-cli.enable = true;
  };
}
