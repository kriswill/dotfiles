# Kris' Dotfiles

This is the configuration I am currently using to setup my Apple laptops.  Some of the other branches are used for NixOS gaming desktops and VMs.

## MacOS

1. Install Homebrew:

      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

2. Install Determinate Nix Installer:

      curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --determinate

3. Clone repo:

      mkdir -p ~/src
      git clone https://github.com/kriswill/dotfiles ~/src/dotfiles
      cd ~/src/dotfiles

4. Move determinate's nix.conf out of the way:

      sudo mv /etc/nix/nix.conf /etc/nix/nix.conf.before-nix-darwin

5. Install (nix-darwin)

      nix --extra-experimental-features "nix-command flakes" run nix-darwin -- switch --flake .
