# Apple's native macOS container CLI, mounted into hosts k + SOC. The
# nix-darwin module ships with the sub-flake
# (./flakes/apple-container/darwin-module.nix) and defaults
# services.apple-container.package to the sub-flake's own package, so no
# overlay or pkgs wiring is needed.
{ inputs, ... }:
let
  apple-container = {
    imports = [ inputs.apple-container.darwinModules.apple-container ];
    services.apple-container.enable = true;
  };
in
{
  configurations.darwin.k.module = apple-container;
  configurations.darwin.SOC-Kris-Williams.module = apple-container;
}
