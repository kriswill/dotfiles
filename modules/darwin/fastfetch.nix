{
  flake.modules.darwin.fastfetch =
    { pkgs, ... }:
    let
      hexley = pkgs.symlinkJoin {
        name = "hexley";
        paths = [ pkgs.fastfetch ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/fastfetch \
            --add-flags '--logo "$HOME/.config/fastfetch/hexley-nix.png" --logo-padding-top 3'
        '';
      };
    in
    {
      environment.systemPackages = [ hexley ];
    };
}
