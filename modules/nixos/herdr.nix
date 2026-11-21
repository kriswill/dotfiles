# herdr on NixOS: the ./flakes/herdr umbrella's module
# (flakes/herdr/modules/nixos.nix), re-exported into the Dendritic module set,
# plus the herdr TUI everywhere. It brings programs.herdr-cli (our fork's
# herdr, herdr-nav, python3 for the agent hooks), programs.herdr-core and
# programs.herdr-app (Herdr's desktop app + hc), programs.herdr-md (a markdown
# viewer mod for the app) and services.herdr-update-check, all off unless a
# host turns them on, as nebula does in modules/hosts/nebula/herdr.nix. The
# packages come from the umbrella, so no overlay is needed.
# Darwin twin: modules/darwin/herdr.nix.
{ inputs, ... }:
{
  flake.modules.nixos.herdr = {
    imports = [ inputs.herdr.nixosModules.herdr ];
    programs.herdr-cli.enable = true;
  };
}
