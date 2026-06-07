# overlays are functions which modify the existing nix package set used by your flake.
# you can use them to add, remove, or modify packages.
{ inputs }:
{
  # add your custom packages
  my-packages =
    final: prev:
    import ../packages {
      pkgs = final;
    };

  # snowglobe-lib hardcodes `alacritty.terminfo` into environment.systemPackages
  # (for ssh terminfo). Alacritty is otherwise removed on this system, so
  # neutralise its terminfo output to an empty dir to drop the leftover entirely.
  drop-alacritty-terminfo = final: prev: {
    alacritty = prev.alacritty // {
      terminfo = final.emptyDirectory;
    };
  };

  # example for installing rolling release of a popular project with a flake.nix
  # ghostty-git = inputs.ghostty.overlays.default;
}
