# apple-container ships its nix-darwin module with its sub-flake
# (./flakes/apple-container/darwin-module.nix); re-export it into the Dendritic
# module set so hosts pick it up like any in-tree modules/darwin/* module. The
# module defaults services.apple-container.package to the sub-flake's own
# package, so no overlay or pkgs wiring is needed. Enable per host with
# `services.apple-container.enable = true;`.
{ inputs, ... }:
{
  flake.modules.darwin.apple-container = inputs.apple-container.darwinModules.apple-container;
}
