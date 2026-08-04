# Wraps fastfetch to force a logo from the stow tree via CLI flags (which
# beat config.jsonc's `source`), so each host picks its image declaratively
# through `programs.fastfetch.logo`. Shared by the fastfetch twins
# (modules/{darwin,nixos}/fastfetch.nix); same symlinkJoin+wrapProgram idiom
# as modules/darwin/diffnav.nix. Logo type and the render box still come from
# the stowed config.jsonc — see docs/fastfetch.md.
{
  pkgs,
  logo, # filename under ~/.config/fastfetch/ (stow package `fastfetch`)
  paddingTop ? 0, # blank rows above the logo (vertical centering for wide images)
}:
pkgs.symlinkJoin {
  name = "fastfetch-${logo}";
  paths = [ pkgs.fastfetch ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/fastfetch \
      --add-flags '--logo "$HOME/.config/fastfetch/${logo}" --logo-padding-top ${toString paddingTop}'
  '';
}
