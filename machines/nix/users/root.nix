{ pkgs, ... }:

{
  users.users.root = {
    hashedPassword = "!"; # disable login for root

    shell = pkgs.zsh;
  };
}
