{ inputs, ... }:
{
  claude-code = import ./claude-code.nix;
  nh = inputs.nh.overlays.default;
  # kitty = import ./kitty.nix;
}
