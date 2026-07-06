---
type: Reference
title: Bun Runtime
description: 'Bun — the single-binary, JavaScriptCore-based JS/TypeScript runtime, bundler, test runner, and package manager; this repo''s default script runtime, provisioned per-OS and consumed in three distinct modes by okf, ccglass, and qmd.'
tags: [bun, runtime]
timestamp: '2026-07-04T00:00:00-07:00'
---

[Bun](https://bun.sh) is a single-binary JavaScript/TypeScript toolkit: a
JavaScriptCore-based runtime that executes `.ts` directly as a drop-in
Node.js replacement, plus a package manager (`bun install`), bundler
(`bun build`), and test runner (`bun test`) in the same executable.

## How this repo uses it

**House rule: bun + [TypeScript](typescript-language.md) is the default
for repo tooling** — skill
drivers and helper scripts (`.claude/skills/patch-ccglass/driver.ts`,
`derivation-to-flake`'s inventory/scaffold/verify scripts) are bun-run TS,
preferred over bash or python.

**Provisioning is per-OS:** darwin installs bun (and `nodejs_24`) in the
primary user's packages via [user-packages](modules/user-packages.md);
NixOS installs it system-wide via [node-runtime](modules/node-runtime.md),
where it doubles as an `npx`-compatible runner. The [dev](modules/dev.md)
shell's `okf` wrapper carries its own bun in `runtimeInputs`, so the CLI
works before either host module is in play.

**Three consumption modes, each a different Bun feature:**

- **Run-from-source** — [okf](packages/okf.md): a `bun run --no-install`
  wrapper over vendored `node_modules` (fixed-output `bun install` keyed on
  `bun.lock`); `okf viz` bundles its Svelte viewer at CLI runtime with
  `Bun.build` + bun-plugin-svelte, and the viewer's tests run under
  `bun test`.
- **Compile-to-binary** — [ccglass](packages/ccglass.md): `bun build
  --compile` produces a standalone executable inside the nix build; the
  compile hazards to scan for on version bumps are catalogued in the
  [bump-ccglass playbook](playbooks/bump-ccglass.md).
- **Outside nix entirely** — qmd is `bun`-installed globally, which is why
  [qmd-sqlite](modules/qmd-sqlite.md) has to paper over its hardcoded
  Homebrew paths from the nix side.

## Citations

- [bun.sh](https://bun.sh) — official site
- [Bun documentation](https://bun.sh/docs)
