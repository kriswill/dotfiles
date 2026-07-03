# decisions

Decision records — why the repository is the way it is. Backfilled from
commit-message bodies and module READMEs; add a record whenever a non-obvious
choice is made (the commit body can then simply link here).

## Concepts

* [Apple container — Repackage and Wrap, Don't Build](apple-container-wrapper.md) - Apple's container CLI is repackaged from the signed .pkg (never built from source) and wrapped so its install root resolves to the store path where the plugins actually live.
* [Claude Profile Isolation Strategy](claude-profile-isolation.md) - The claude wrapper prefers each profile's own interactive login and uses the Keychain token only as a fallback; the desktop app is pinned via a launchd Aqua-domain setenv plus a shell scrub.
* [codebase-memory-mcp via Nix-aware Fork](codebase-memory-fork.md) - The codebase-memory MCP server is consumed from the kriswill fork's nix branch (Nix symbols + flake topology, PR #19 upstream) with its index artifact kept out of git for now.
* [Route All Linting and Formatting Through efm-langserver](efm-umbrella-formatting.md) - One umbrella LSP (efm) runs every CLI linter and formatter; format-on-save filters to efm only, so no two tools ever compete over a buffer.
* [Home-manager Retirement](home-manager-retirement.md) - home-manager was removed entirely — every config is now a darwin module plus the stow tree, one evaluation model instead of two.
* [Manage Neovim Plugins with Native vim.pack](native-vim-pack.md) - Drop lazy.nvim for Neovim 0.12's built-in vim.pack, recreating lazy-loading with a ~160-line dispatcher instead of a third-party plugin manager.
* [Podman From the Official Binary, Self-contained](podman-official-binary.md) - podman is packaged as a fixed-output derivation of the official darwin_arm64 release (nixpkgs' derivation is linux-only) with vfkit + gvproxy bundled into its own libexec.
* [Unfree Packages Are Deny-by-default](unfree-default-deny.md) - nixpkgs.config.allowUnfree is false; each unfree package needs an explicit allowUnfreePredicate entry in core.nix, making every exception reviewable.
* [Viz Viewer — Svelte 5 on the Pure-Bun One-Shot Pipeline](viz-svelte-rebuild.md) - Rebuild the okf viz viewer on Svelte 5 runes via bun-plugin-svelte inside the existing single Bun.build call, keeping the self-contained viz.html output and wrapping the imperative Three.js scene instead of rewriting it.
