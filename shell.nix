# Dev shell for hacking on this flake. Single source of truth for both
# `nix-shell` (this file directly) and the flake's default devShell
# (`nix develop` / `.#devShells.<system>.default`, wired in
# modules/devshell.nix). Pin nixpkgs to the flake's pin when entered via the
# flake; falls back to <nixpkgs> for a bare `nix-shell`.
{
  pkgs ? import <nixpkgs> { },
}:
pkgs.mkShell {
  name = "dotfiles-nebula";

  packages = with pkgs; [
    # Nix tooling
    nixfmt-rfc-style # formatter used across the tree
    nil # Nix language server
    nix-output-monitor # nicer rebuild output (nom)

    # Secrets (sops-nix, nebula age key — see .sops.yaml)
    sops
    age
    ssh-to-age

    # Dotfiles management
    stow
    git
  ];

  shellHook = ''
    echo "dotfiles (nebula) dev shell — nixfmt-rfc-style, nil, sops, stow on PATH"
  '';
}
