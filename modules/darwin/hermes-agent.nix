# Hermes Agent ships its nix-darwin module with its sub-flake
# (./flakes/hermes-agent/nix/darwinModules.nix: the NixOS module's twin, with
# the gateway as a launchd user agent and every Hermes process inside a
# deny-by-default Seatbelt sandbox); re-export it into the Dendritic module
# set. Inert until a host sets `services.hermes-agent.enable = true;` (mini
# does, in modules/hosts/mini/hermes-agent.nix). NixOS twin:
# modules/nixos/hermes-agent.nix.
{ inputs, ... }:
{
  flake.modules.darwin.hermes-agent = inputs.hermes-agent.darwinModules.default;
}
