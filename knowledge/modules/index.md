# modules

Catalog of nix-darwin feature modules and flake-parts plumbing modules. Stubs
are scaffolded from source by `bun scripts/okf/okf.ts scaffold`; enrich the
interesting ones by hand — scaffolding never overwrites an existing doc.

## Concepts

* [Alias En0](alias-en0.md) - en0 local IP address alias - used for dev.
* [Apple Container](apple-container.md) - apple-container ships its nix-darwin module with its sub-flake (./flakes/apple-container/darwin-module.nix); re-export it into the Dendritic module set so hosts pick it up like any in-tree modules/darwin/* module.
* [Claude Account Selector](claude-account-selector.md) - zsh wrapper that auto-selects a Claude Code account/profile by launch directory, with per-profile config-dir isolation.
* [Codebase Memory Mcp](codebase-memory-mcp.md) - codebase-memory-mcp ships its nix-darwin module in our kriswill/codebase-memory-mcp `nix` fork (nix/darwin/module.nix); re-export it into the Dendritic module set so hosts pick it up like any in-tree modules/darwin/* module.
* [Core](core.md) - Kris' custom darwin modules.
* [Darwin](darwin.md) - Declares `configurations.darwin.<name>` and realises each into a `darwinConfigurations.<name>` flake output (plus a toplevel build check).
* [Dev](dev.md) - Development shell (deadnix, statix, nixfmt-tree, just, okf) and formatter.
* [Diffnav](diffnav.md) - diffnav git diff pager.
* [Direnv Nom](direnv-nom.md) - Closure diff tool: nvd (nh-style formatted output), native (nix store diff-closures), or none to disable.
* [Direnv](direnv.md) - Kris' direnv + nix-direnv.
* [Dnsmasq](dnsmasq.md) - dnsmasq local DNS service.
* [Dotfiles Stow](dotfiles-stow.md) - stow-managed dotfiles deployment.
* [Fastfetch](fastfetch.md) - Kris' fastfetch.
* [Flake Parts](flake-parts.md) - Top-level flake-parts wiring for the Dendritic pattern.
* [Ghostty](ghostty.md) - Ghostty terminal.
* [Git](git.md) - Kris' git.
* [Homebrew](homebrew.md) - Kris' Homebrew stuff.
* [Htop](htop.md) - Kris' htop (system-level port of the old home-manager programs.htop).
* [Kitty](kitty.md) - Kris' kitty.
* [Lib](lib.md) - Exposes the nixpkgs lib extended with this repo's pure helpers (`mkProgramOption`, `kanagawa`) as a top-level option, so both the darwin and home-manager evaluations can receive it via specialArgs / extraSpecialArgs.
* [Macos Defaults](macos-defaults.md) - Kris' macOS defaults.
* [Neovide](neovide.md) - Kris' neovide.
* [Neovim](neovim.md) - Installs Neovim plus every LSP/linter/formatter binary on the global PATH; the Lua config itself is stow-deployed and documented in the nvim knowledge area.
* [Nh](nh.md) - Nix Helper.
* [Oksh](oksh.md) - Kris' oksh.
* [Overlays](overlays.md) - Nixpkgs overlays, exposed as flake outputs and consumed by the host modules via `nixpkgs.overlays = builtins.attrValues config.flake.overlays`.
* [Packages](packages.md) - Custom package outputs (also surfaced into nix-darwin via ./overlays.nix).
* [Podman Desktop](podman-desktop.md) - Podman Desktop.
* [Qmd Sqlite](qmd-sqlite.md) - Custom sqlite with loadable-extension support, for sqlite-vec and qmd (system-level port of the sqliteWithExtensions package + linkSqliteForQmd activation that used to live in home-manager/core.nix).
* [Ssh](ssh.md) - Kris' ssh.
* [Tmux](tmux.md) - Kris' tmux.
* [User Packages](user-packages.md) - Darwin feature module 'user-packages'.
* [Yazi](yazi.md) - Kris' yazi.
* [Zk](zk.md) - Kris' zk.
* [Zsh](zsh.md) - Kris' zsh.
