# iv — command-line image viewer using terminal graphics (kitty/sixel).
# Derivation in pkgs/iv.nix, exposed as pkgs.iv via the iv overlay.
{
  flake.modules.darwin.iv = { pkgs, ... }: { environment.systemPackages = [ pkgs.iv ]; };
}
