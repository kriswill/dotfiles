# modules

Catalog of darwin and NixOS feature modules, flake-parts plumbing modules,
and nebula's host-specific files. Stubs
are scaffolded from source by `bun flakes/okf/okf.ts scaffold`; enrich the
interesting ones by hand — scaffolding never overwrites an existing doc.

## Concepts

* [Alias En0](alias-en0.md) - Alias a local dev IP onto en0 (work host only).
* [Apple Container](apple-container.md) - apple-container ships its nix-darwin module with its sub-flake (./flakes/apple-container/darwin-module.nix); re-export it into the Dendritic module set so hosts pick it up like any in-tree modules/darwin/* module.
* [Cbissue](cbissue.md) - Codeberg (Forgejo) issue CLIs — cbissue opens issues, cbissues browses them; the API token is fetched at call time via 1Password `op read`, nothing secret is stored.
* [Claude Account Selector](claude-account-selector.md) - zsh wrapper that auto-selects a Claude Code account/profile by launch directory, with per-profile config-dir isolation.
* [Codebase Memory Mcp](codebase-memory-mcp.md) - codebase-memory-mcp ships its nix-darwin module in our kriswill/codebase-memory-mcp `nix` fork (nix/darwin/module.nix); re-export it into the Dendritic module set so hosts pick it up like any in-tree modules/darwin/* module.
* [Configuration](configuration.md) - Nebula's baseline system config — locale/timezone, snowglobe-lib profile toggles, NVIDIA production driver, GRUB dual-boot via os-prober, initrd emergency access, sops-decrypted SSH host keys, and the host's package/program selections.
* [Console Quiet](console-quiet.md) - Sets boot.consoleLogLevel = 3 so the benign AMD i2c_piix4 SMBus probe-NAK errors stop flashing over the ly greeter; journald still records everything.
* [Core](core.md) - The always-on darwin system baseline shared by every host — stateVersion, primary user, baseline packages, touch-ID sudo, fonts, shell enables, nix/nixpkgs settings.
* [Darwin](darwin.md) - Declares `configurations.darwin.<name>` and realises each into a `darwinConfigurations.<name>` flake output (plus a toplevel build check).
* [Determinate](determinate.md) - Determinate Nix replaces snowglobe-lib's Lix default: snowglobe sets nix.package at priority 1337 (setDefault); the determinate module's plain assignment wins — no fork, no mkForce.
* [Dev](dev.md) - Development shell (deadnix, statix, nixfmt-tree, just, okf) and formatter.
* [Diffnav](diffnav.md) - diffnav git diff pager.
* [Direnv Nom](direnv-nom.md) - Wraps nix-direnv's _nix() to pipe `use flake` build logs through nix-output-monitor, with an nvd closure diff after successful builds; wrapper text shared via lib/direnv-nom-wrapper.nix.
* [Direnv](direnv.md) - direnv + nix-direnv on both OSes; links nix-direnv's stdlib into ~/.config/direnv/lib so `use flake` works, with a filename that deliberately sorts before direnv-nom's wrapper.
* [Disko](disko.md) - Declarative disko layout for the NixOS NVMe — GPT with a 1M bios-boot partition, a 512M vfat ESP at /boot, and an unencrypted ext4 root filling the rest.
* [Dnsmasq](dnsmasq.md) - dnsmasq local DNS service.
* [Dotfiles Stow](dotfiles-stow.md) - Restows every home/ package into $HOME on each rebuild via the shared lib/stow-restow-script.nix builder — live-repo symlinks, self-healing, per-OS skip lists.
* [Fastfetch](fastfetch.md) - Kris' fastfetch.
* [Flake Parts](flake-parts.md) - Top-level flake-parts wiring for the Dendritic pattern.
* [Flatpak Repo User](flatpak-repo-user.md) - Masks snowglobe's system flatpak-repo service and replaces it with a per-user oneshot that registers Flathub in ~/.local/share/flatpak at login, gated on a DNS ExecCondition so offline logins skip cleanly.
* [Ghostty](ghostty.md) - Ghostty terminal — each OS installs it its own way and generates its half of the split config (`config-file = ?os.conf`); the shared config is stowed.
* [Git](git.md) - Installs the binaries the stow-managed git config invokes by bare name (git, gh, gh-config, git-lfs, difftastic, …); the config itself — including 1Password SSH signing — is stow, not nix.
* [Gpg](gpg.md) - gpg-agent on both OSes with enableSSHSupport deliberately false — 1Password owns SSH_AUTH_SOCK; gpg only backs `pass` and ad-hoc gpg use.
* [Gtk Dark](gtk-dark.md) - Forces GTK apps to Adwaita's dark variant via one session variable (GTK_THEME=Adwaita:dark) — a bare Hyprland session has no settings daemon to broadcast prefer-dark.
* [Hardware Configuration](hardware-configuration.md) - nixos-generate-config output in the two-line dendritic wrapper: initrd kernel modules, kvm-amd, x86_64-linux hostPlatform, and AMD microcode updates.
* [Helium](helium.md) - Helium browser — enables the upstream programs.helium module and declares a root-owned Chromium managed policy in /etc (privacy baseline, DuckDuckGo, force-installed extensions).
* [Homebrew](homebrew.md) - Kris' Homebrew stuff.
* [Htop](htop.md) - Kris' htop (system-level port of the old home-manager programs.htop).
* [Hyprland](hyprland.md) - Enables Hyprland directly (programs.hyprland + withUWSM) instead of snowglobe-lib.desktop.hyprland — dodging its force-enabled hyprlock/kitty/dolphin — and asserts the shared snowglobe desktop layer plus fuzzel formerly implied by niri.
* [Keyring](keyring.md) - snowglobe-lib installer key metadata (NOT GNOME Keyring) — user k's ssh-ed25519 public key and nebula's age recipient; do not remove.
* [Kitty](kitty.md) - Kris' kitty.
* [Libreoffice Paths](libreoffice-paths.md) - Moves LibreOffice's user-writable paths out of ~/.config/libreoffice into XDG data/state dirs by seeding both the modern and legacy path nodes into registrymodifications.xcu — idempotent, skip-if-running, subshell-confined.
* [Ly](ly.md) - Disables ly's F5/F6 brightness actions (and their hint-bar entries) by setting brightness_down_key/brightness_up_key to the literal "null" — ly itself is enabled by snowglobe's shared desktop layer.
* [Macos Defaults](macos-defaults.md) - Kris' macOS defaults.
* [Neovim](neovim.md) - Installs Neovim plus every LSP/linter/formatter binary on the global PATH; the Lua config itself is stow-deployed and documented in the nvim knowledge area.
* [Nh](nh.md) - nh (Nix Helper) plus the nrs/nrb/nrt rebuild helper executables (writeShellScriptBin, so they work in non-interactive shells and every shell alike).
* [Nixos](nixos.md) - Declares `configurations.nixos.<name>` and realises each into a `nixosConfigurations.<name>` flake output (plus a toplevel build check), building through snowglobe-lib's `mkNixosHost` so all the `snowglobe-lib.profiles.*` / `snowglobe-lib.desktop.*` machinery and the hardware wiring are still applied.
* [Node Runtime](node-runtime.md) - System-wide Node.js + Bun — infrastructure, not dev convenience: npx-launched MCP servers (Claude Code plugins) silently fail on NixOS without a node on PATH.
* [Oksh](oksh.md) - Kris' oksh.
* [Overlays](overlays.md) - Nixpkgs overlays, exposed as flake outputs and consumed by the host modules via `nixpkgs.overlays = builtins.attrValues config.flake.overlays`.
* [Packages](packages.md) - Custom package outputs (also surfaced into nix-darwin via ./overlays.nix).
* [Pass](pass.md) - Installs pass-xdg — a wrapper itself named `pass` that defaults PASSWORD_STORE_DIR to $XDG_DATA_HOME/password-store; never also install pkgs.pass or the two binaries collide.
* [Podman Desktop](podman-desktop.md) - Podman Desktop.
* [Qmd Sqlite](qmd-sqlite.md) - Custom sqlite with loadable-extension support, for sqlite-vec and qmd (system-level port of the sqliteWithExtensions package + linkSqliteForQmd activation that used to live in home-manager/core.nix).
* [Sops](sops.md) - sops-nix on macOS — universal machinery, inert until a host defines secrets.
* [Sudo 1password](sudo-1password.md) - sudo authentication via the 1Password SSH agent — pam_ssh_agent_auth installed as auth-sufficient on the sudo stack only, with the trusted key materialized via tmpfiles to pass StrictModes and gcr-ssh-agent disabled so the 1Password socket wins.
* [Tmux](tmux.md) - Installs tmux and generates plugins.conf — the one tmux file that must embed a /nix/store path (tmux-which-key's rtp); tmux.conf and which-key's config.yaml are stowed.
* [User Packages](user-packages.md) - Darwin feature module 'user-packages'.
* [Users K Helium](users-k-helium.md) - Installs pkgs.helium-config for user k — the snapshot/restore CLI that syncs Helium's user settings into config/helium/ without symlinking the live Chromium profile.
* [Users K Noctalia](users-k-noctalia.md) - Installs the Noctalia v5 desktop shell (native C++ Wayland binary) for user k plus its support tooling — ddcutil + i2c for DDC/CI monitor brightness, tomato, noctalia-config snapshots — and the upower/power-profiles-daemon/bluetooth services its widgets read.
* [Users K](users-k.md) - Defines user k — sops-managed password (neededForUsers), authorized SSH key from snowglobe's keyring, wheel/networkmanager/libvirtd groups, and pkgs.flatpak-user shadowing the system flatpak via PATH.
* [Windows Mount](windows-mount.md) - Permanent read-only ntfs-3g mount of the Windows NTFS partition (the other NVMe) at /mnt/windows — lazy systemd automount with nofail; read-only tolerates Fast-Startup-"dirty" volumes.
* [Yazi](yazi.md) - Kris' yazi.
* [Zk](zk.md) - Kris' zk.
* [Zsh](zsh.md) - Zsh with ZDOTDIR moved to ~/.config/zsh (exported from shellInit so it precedes .zshrc lookup), XDG history placement, starship-owned prompt, and the tools the stowed .zshrc calls by bare name.
