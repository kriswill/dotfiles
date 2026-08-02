# runtimes

The runtimes this repo provisions and leans on — one doc each covering what
it is, how it's wired here, and the contracts it imposes. This is the
execution layer beneath [languages/](../languages/index.md).

## Concepts

* [Bun Runtime](bun.md) - Bun — the single-binary, JavaScriptCore-based JS/TypeScript runtime, bundler, test runner, and package manager; this repo's default script runtime, provisioned per-OS and consumed in three distinct modes by okf, ccglass, and qmd.
* [Nix Runtime](nix.md) - The executable half of Nix — evaluator, immutable /nix/store, and privileged nix-daemon realising derivations; every host here runs Determinate Nix, chosen for the ≥2.26 relative-path locking the sub-flakes depend on.
