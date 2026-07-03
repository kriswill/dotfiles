# playbooks

Operational how-tos for recurring tasks — rebuilds, adopting dotfiles,
adding modules and packages, and keeping tooling up to date.

## Concepts

* [Add a Darwin Feature Module](add-module.md) - Create, register (automatic), and enable a new nix-darwin feature module.
* [Add a Custom Package](add-package.md) - Add a package under pkgs/ (or as a sub-flake), expose it via perSystem.packages and an overlay, and handle unfree licensing.
* [Adopt a Dotfile Into the Stow Tree](adopt-dotfile.md) - Capture an existing $HOME config into home/, or pull live edits of a tracked file back into the repo.
* [Bump ccglass](bump-ccglass.md) - Update the ccglass sub-flake for a new upstream release via the patch-ccglass skill.
* [Rebuild and Rollback](rebuild-and-rollback.md) - Apply, test-build, inspect, and roll back system generations.
* [Refresh the Codebase-memory Index](refresh-codebase-memory.md) - Bootstrap or refresh the code-graph index the codebase-memory MCP server keeps for this repo.
