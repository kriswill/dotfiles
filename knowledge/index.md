---
okf_version: '0.1'
---

# knowledge

Authored knowledge for this repository — architecture patterns, decision
records, operational playbooks, and a catalog of every module, package, and
host — structured as an
[Open Knowledge Format](https://github.com/GoogleCloudPlatform/knowledge-catalog/tree/main/okf)
v0.1 bundle. Conventions and tooling are documented in the
[OKF Profile](okf-profile.md). This bundle is the authored-rationale layer; it
complements [`AGENTS.md`](../AGENTS.md) (agent working instructions) and the
derived `.codebase-memory/` code graph.

## Concepts

* [OKF Profile](okf-profile.md) - This bundle's conventions on top of OKF v0.1 — required fields, link style, resource semantics, type registry, and tooling.

## Subdirectories

* [decisions](decisions/index.md) - Decision records — why the repository is the way it is.
* [hosts](hosts/index.md) - The machines this flake configures, and which feature modules each enables.
* [modules](modules/index.md) - Catalog of nix-darwin feature modules and flake-parts plumbing modules.
* [packages](packages/index.md) - Custom packages, nixpkgs overlays, and the self-contained sub-flakes the root flake consumes via relative-path inputs.
* [patterns](patterns/index.md) - Named architectural patterns this repository is built on.
* [playbooks](playbooks/index.md) - Operational how-tos for recurring tasks — rebuilds, adopting dotfiles, adding modules and packages, and keeping tooling up to date.
