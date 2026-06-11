# apple-container ships its nix-darwin module with its sub-flake
# (./flakes/apple-container/darwin-module.nix); re-export it into the Dendritic
# module set so hosts pick it up like any in-tree modules/darwin/* module. The
# module defaults kriswill.apple-container.package to the sub-flake's own package,
# so no overlay or pkgs wiring is needed.
{ inputs, ... }:
{
  flake.modules.darwin.apple-container = inputs.apple-container.darwinModules.apple-container;
}
