# Kris' Nix Configuration

## MacOS - using nix-darwin

* Install Homebrew:

      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

* Install Determinate Nix Installer:

      curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --determinate

* Clone repo:

      mkdir -p ~/src/github/kriswill
      git clone https://github.com/kriswill/dotfiles ~/src/github/kriswill/dotfiles
      ln -s $(realpath ~/src/github/kriswill)/dotfiles $(realpath ~/src)/dotfiles
      cd $(realpath ~/src/dotfiles)
      git switch nix-darwin

* Move determinate's nix.conf out of the way:

      sudo mv /etc/nix/nix.conf /etc/nix/nix.conf.before-nix-darwin

* install (nix-darwin)

      cd ~/src/dotfiles
      nix --extra-experimental-features "nix-command flakes" run nix-darwin -- switch --flake .
