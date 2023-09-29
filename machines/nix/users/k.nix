{ pkgs, ... }:

let
  username = "k";
in
{
  users.users."${username}" = {
    isNormalUser = true;
    description = "${username}";
    extraGroups = [ "wheel" "networkmanager" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBxqhXoAlCKYNwsB1YrszftURThiCI94oeR0W9EDhrLy"
    ];
    shell = pkgs.zsh;
    packages = with pkgs; [
      # firefox
      wezterm
      obsidian
    ];
  };

  programs = {
    _1password-gui.polkitPolicyOwners = [ "${username}" ];

    git = {
      enable = true;
      config = {
        user = {
          name  = "Kris Williams";
          email = "115474+kriswill@users.noreply.github.com";
        };
        # signingkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBxqhXoAlCKYNwsB1YrszftURThiCI94oeR0W9EDhrLy";
        # gpg.format = "ssh";
      };
    };
  };
}
