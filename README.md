# Kris' Dotfiles

One flake for all my machines: three Macs (`k`, `mini`, `SOC-Kris-Williams` —
[nix-darwin](https://github.com/lnl7/nix-darwin), Apple Silicon) and the
`nebula` NixOS desktop (AMD/NVIDIA, Wayland: [Hyprland](https://hyprland.org) +
[Noctalia](https://github.com/noctalia-dev/noctalia-shell), built on
[snowglobe-lib](https://codeberg.org/earthgman/snowglobe-lib)). Everything is
organised with the dendritic pattern ([flake-parts](https://flake.parts) +
[import-tree](https://github.com/vic/import-tree)): per-OS module classes
(`modules/darwin/`, `modules/nixos/`), a shared GNU Stow tree (`home/`) for the
cross-platform CLI configs (neovim, tmux, zsh, git, ghostty, starship, …), and
[sops-nix](https://github.com/Mic92/sops-nix) secrets on both OSes. The
formerly separate `nebula-snowglobe` branch was merged here; legacy NixOS
configs live on the old `nixos`/`legacy` branches.

## Knowledge

**Browse the knowledge graph: <https://kris.net/dotfiles/>** — an interactive
3D map of everything documented below, rebuilt from this repo on every push.
Search for a concept, orbit its neighborhood, and read the docs (and linked
source files) in place.

Repo knowledge lives in two places:

- [`AGENTS.md`](AGENTS.md) — conventions and working instructions for anyone
  (human or agent) making changes.
- [`knowledge/`](knowledge/index.md) — an
  [OKF](https://github.com/GoogleCloudPlatform/knowledge-catalog/tree/main/okf)
  bundle of architecture patterns, decision records, playbooks, and a catalog
  of every module, package, and host, cross-linked into a graph. It captures
  the *why* behind the config — the part you can't recover from the code
  alone. Start at the [index](knowledge/index.md).

The published site is the same bundle rendered by `okf viz`
(`flakes/okf/`), so it can never drift from what's committed.

## MacOS

1. Install Homebrew:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

2. Install Determinate Nix Installer:

```sh
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --determinate
```

3. Clone repo:

```sh
mkdir -p ~/src
git clone https://github.com/kriswill/dotfiles ~/src/dotfiles
cd ~/src/dotfiles
```

4. Move determinate's nix.conf out of the way:

```sh
sudo mv /etc/nix/nix.conf /etc/nix/nix.conf.before-nix-darwin
```

5. Install (nix-darwin)

```sh
nix --extra-experimental-features "nix-command flakes" run nix-darwin -- switch --flake .
```

## NixOS (nebula)

1. Boot the installer, partition with [disko](https://github.com/nix-community/disko)
   (`modules/hosts/nebula/disko.nix`), or start from an existing install.

2. Clone the repo (the host expects the checkout at
   `~/src/github/kriswill/dotfiles`, with convenience symlinks
   `~/src/dotfiles` → it and `/etc/nixos` → `~/src/dotfiles`):

```sh
mkdir -p ~/src/github/kriswill
git clone https://github.com/kriswill/dotfiles ~/src/github/kriswill/dotfiles
ln -s github/kriswill/dotfiles ~/src/dotfiles
```

3. Rebuild (cd first — nix's `--flake` does not follow a symlinked path):

```sh
cd ~/src/github/kriswill/dotfiles
sudo nixos-rebuild switch --flake .#nebula
```

Secrets are sops-nix encrypted per host (see `.sops.yaml`); nebula's age key
derives from its SSH host key. Day-to-day rebuilds: `nrs` / `nrb` / `nrt` on
both OSes (`nh darwin` / `nh os`).
