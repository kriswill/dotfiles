# fastfetch, wrapped. It adds two things to nixpkgs' fastfetch:
#
#   - a logo chosen at build time: `--logo` beats config.jsonc's `source`, so
#     a host picks its image declaratively (the module's
#     `programs.fastfetch.logo`) while the logo type and render box stay in
#     the user's config.jsonc;
#   - a `kitten` shim, first on fastfetch's PATH and nobody else's, without
#     which the `kitty-icat` logo draws nothing in a herdr-core terminal
#     (./kitten-shim.sh has the why).
#
# symlinkJoin + wrapProgram, so the rest of the fastfetch package (man page,
# completions, presets) comes along untouched.
{
  lib,
  symlinkJoin,
  makeWrapper,
  fastfetch,
  callPackage,
  kitten-shim ? callPackage ./kitten-shim.nix { },
  logo ? null, # filename under ~/.config/fastfetch/; null leaves the logo to config.jsonc
  paddingTop ? 0, # blank rows above the logo (vertical centering for wide images)
}:
let
  flags = lib.concatStringsSep " " (
    lib.optional (logo != null) ''--logo "$HOME/.config/fastfetch/${logo}"''
    ++ lib.optional (logo != null || paddingTop != 0) "--logo-padding-top ${toString paddingTop}"
  );
in
symlinkJoin {
  name = if logo == null then "fastfetch-wrapped" else "fastfetch-${logo}";
  paths = [ fastfetch ];
  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/fastfetch \
      --prefix PATH : ${kitten-shim}/bin \
      --add-flags '${flags}'
  '';
  meta.mainProgram = "fastfetch";
}
