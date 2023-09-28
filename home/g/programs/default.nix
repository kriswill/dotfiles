let
  etc = { pkgs, ... }: {
    programs = {
      bat.enable = true;
      ssh.enable = true;
      obs-studio.enable = true;
      direnv = {
        enable = true;
        nix-direnv.enable = true;
      };
      zoxide = {
        enable = true;
        enableZshIntegration = true;
        options = [ ];
      };
    };
  };
in
[
  #./dconf.nix
  etc
]
