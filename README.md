# Kris' Dotfiles

This is the configuration I currently use to manage my coding computers. Some of the other branches are used for NixOS gaming desktops and VMs.

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
(`scripts/okf/`), so it can never drift from what's committed.

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
