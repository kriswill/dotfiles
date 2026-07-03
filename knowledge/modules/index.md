# modules

Catalog of nix-darwin feature modules and flake-parts plumbing modules. Stubs
are scaffolded from source by `bun scripts/okf/okf.ts scaffold`; enrich the
interesting ones by hand — scaffolding never overwrites an existing doc.

## Concepts

* [Alias En0](alias-en0.md) - Alias a local dev IP onto en0 (work host only).
* [Apple Container](apple-container.md) - apple-container ships its nix-darwin module with its sub-flake (./flakes/apple-container/darwin-module.nix); re-export it into the Dendritic module set so hosts pick it up like any in-tree modules/darwin/* module.
* [Claude Account Selector](claude-account-selector.md) - zsh wrapper that auto-selects a Claude Code account/profile by launch directory, with per-profile config-dir isolation.
* [Codebase Memory Mcp](codebase-memory-mcp.md) - codebase-memory-mcp ships its nix-darwin module in our kriswill/codebase-memory-mcp `nix` fork (nix/darwin/module.nix); re-export it into the Dendritic module set so hosts pick it up like any in-tree modules/darwin/* module.
* [Configuration](configuration.md) - Host-specific config 'configuration' for nebula.
* [Console Quiet](console-quiet.md) - Host-specific config 'console-quiet' for nebula.
* [Core](core.md) - The always-on darwin system baseline shared by every host — stateVersion, primary user, baseline packages, touch-ID sudo, fonts, shell enables, nix/nixpkgs settings.
* [Darwin](darwin.md) - Declares `configurations.darwin.<name>` and realises each into a `darwinConfigurations.<name>` flake output (plus a toplevel build check).
* [Dev](dev.md) - Development shell (deadnix, statix, nixfmt-tree, just, okf) and formatter.
* [Diffnav](diffnav.md) - diffnav git diff pager.
* [Direnv Nom](direnv-nom.md) - Wraps nix-direnv's _nix() to pipe `use flake` build logs through nix-output-monitor, with an nvd closure diff after successful builds.
* [Direnv](direnv.md) - Kris' direnv + nix-direnv.
* [Disko](disko.md) - Host-specific config 'disko' for nebula.
* [Dnsmasq](dnsmasq.md) - dnsmasq local DNS service.
* [Dotfiles Stow](dotfiles-stow.md) - stow-managed dotfiles deployment.
* [Fastfetch](fastfetch.md) - Kris' fastfetch.
* [Flake Parts](flake-parts.md) - Top-level flake-parts wiring for the Dendritic pattern.
* [Flatpak Repo User](flatpak-repo-user.md) - Host-specific config 'flatpak-repo-user' for nebula.
* [Ghostty](ghostty.md) - Ghostty terminal.
* [Git](git.md) - Kris' git.
* [Gpg](gpg.md) - GnuPG agent on macOS — the darwin twin of modules/nixos/gpg.nix.
* [Hardware Configuration](hardware-configuration.md) - DENDRITIC WRAPPER: the generated module body is held under `configurations.nixos.nebula.module` so this file is a valid flake-parts module (every `.nix` under modules/ is auto-imported as one).
* [Homebrew](homebrew.md) - Kris' Homebrew stuff.
* [Htop](htop.md) - Kris' htop (system-level port of the old home-manager programs.htop).
* [Hyprland](hyprland.md) - Host-specific config 'hyprland' for nebula.
* [Kitty](kitty.md) - Kris' kitty.
* [Ly](ly.md) - Host-specific config 'ly' for nebula.
* [Macos Defaults](macos-defaults.md) - Kris' macOS defaults.
* [Neovim](neovim.md) - Installs Neovim plus every LSP/linter/formatter binary on the global PATH; the Lua config itself is stow-deployed and documented in the nvim knowledge area.
* [Nh](nh.md) - nh (Nix Helper) plus the nrs/nrb/nrt rebuild helper executables (writeShellScriptBin, so they work in non-interactive shells and every shell alike).
* [Nixos](nixos.md) - Declares `configurations.nixos.<name>` and realises each into a `nixosConfigurations.<name>` flake output (plus a toplevel build check), building through snowglobe-lib's `mkNixosHost` so all the `snowglobe-lib.profiles.*` / `snowglobe-lib.desktop.*` machinery and the hardware wiring are still applied.
* [Oksh](oksh.md) - Kris' oksh.
* [Overlays](overlays.md) - Nixpkgs overlays, exposed as flake outputs and consumed by the host modules via `nixpkgs.overlays = builtins.attrValues config.flake.overlays`.
* [Packages](packages.md) - Custom package outputs (also surfaced into nix-darwin via ./overlays.nix).
* [Pass](pass.md) - Darwin feature module 'pass'.
* [Podman Desktop](podman-desktop.md) - Podman Desktop.
* [Qmd Sqlite](qmd-sqlite.md) - Custom sqlite with loadable-extension support, for sqlite-vec and qmd (system-level port of the sqliteWithExtensions package + linkSqliteForQmd activation that used to live in home-manager/core.nix).
* [Sops](sops.md) - sops-nix on macOS — universal machinery, inert until a host defines secrets.
* [Sudo 1password](sudo-1password.md) - Host-specific config 'sudo-1password' for nebula.
* [Tmux](tmux.md) - Kris' tmux.
* [User Packages](user-packages.md) - Darwin feature module 'user-packages'.
* [Windows Mount](windows-mount.md) - Host-specific config 'windows-mount' for nebula.
* [Yazi](yazi.md) - Kris' yazi.
* [Zk](zk.md) - Kris' zk.
* [Zsh](zsh.md) - Kris' zsh.
