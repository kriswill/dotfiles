---
type: Decision
title: CI Builds Both Host Closures — No Signing Key, No Age Key, Ever
description: 'GitHub Actions builds darwinConfigurations.k.system (free arm64 macOS runner, public repo) and nebula''s NixOS toplevel on every PR, plus a weekly update-flake-lock PR via a fine-grained PAT. The load-bearing security property: builds never decrypt sops secrets, so CI''s only credential is the read-only okflight deploy key — the Developer ID signing key never touches GitHub.'
tags: [ci, security, codesigning]
timestamp: '2026-07-10T21:30:00Z'
---

**Status:** active. **Where:** `.github/workflows/ci.yml`,
`.github/workflows/update-flake-lock.yml`; signing context: the
nas-mount codesigning record (PR #32; re-link once it merges).

## Context

Automating nas-mount's Developer ID signing (the nas-mount codesigning
record, PR #32, 2026-07-10 update) raised
the follow-on wish: auto-build the flake's deployed systems in CI so flake
input bumps arrive as reviewed, build-tested PRs. The original sketch had CI
holding the age private key as a GitHub secret "so it can sign during
builds" — investigated and rejected: sops-nix decrypts at *activation* on
the host, never at build, so a system build needs no secrets at all. That
observation removed the entire hard part.

## Decision

- **`ci.yml`** (pull_request + push to main): `darwin-k` builds
  `.#darwinConfigurations.k.system` on `macos-latest` (arm64 — free and
  unlimited on public repos; the ~10× private-repo minute multiplier does
  not apply); `nixos-nebula` builds
  `.#nixosConfigurations.nebula.config.system.build.toplevel` on
  `ubuntu-latest` behind a `jlumbroso/free-disk-space` reclaim step
  (nebula's closure: gaming profile, nvidia, source-built Hyprland).
  Deliberately not `nix flake check` — that would build all three darwin
  hosts; the gate is the two machines actually deployed.
- **CI's only credential is `OKFLIGHT_DEPLOY_KEY`** (pre-existing read-only
  deploy key for the private `git+ssh` okf input, loaded via
  `webfactory/ssh-agent`; same secret pages.yml uses). **No signing key and
  no age key in CI ever**: a compromised workflow, malicious PR, or
  exfiltrated secret store cannot leak what was never there. Fork PRs get
  no secrets and simply fail on the okf fetch — acceptable for a personal
  repo.
- **`update-flake-lock.yml`** (weekly cron + dispatch):
  `DeterminateSystems/update-flake-lock@v28` opens the bump PR with a
  fine-grained PAT (`FLAKE_UPDATE_PAT`, this repo only, Contents R/W +
  Pull requests R/W) because events created with the default `GITHUB_TOKEN`
  never trigger other workflows — the PAT is what makes ci.yml run on the
  bump PR. Chosen over Dependabot's native nix support (April 2026)
  because Dependabot cannot bump the private git+ssh okf input or the
  FlakeHub `determinate` input.
- **Accepted cost:** hyprland/noctalia `follows` this flake's nixpkgs, so
  their upstream caches can never hit — every bump PR rebuilds them from
  source on the nebula job. `magic-nix-cache-action` (GHA cache, ~10 GiB)
  is included on the darwin job for the custom packages.

## Consequences

- Flake bumps arrive as PRs whose CI proves both deployed systems still
  build — the pre-`nrs` gate runs before anything lands on a machine.
- The signing story stays host-local: CI builds ship the store bundle with
  only the build-time ad-hoc signature; the Developer ID signature is
  applied at activation on `k` alone.
- Watch: nebula job wall-clock and disk high-water on the first runs (tune
  or drop the disk-reclaim step); the PAT's expiry (~1 year) needs a
  calendar note; `timeout-minutes` may need raising on uncached
  hyprland-bump PRs.

## Citations

- [GitHub: workflows are not triggered by GITHUB_TOKEN events](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow#triggering-a-workflow-from-a-workflow)
- [DeterminateSystems/update-flake-lock](https://github.com/DeterminateSystems/update-flake-lock)
- [webfactory/ssh-agent](https://github.com/webfactory/ssh-agent)
- [GitHub-hosted runners: standard runners are free for public repositories](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
- Decision context: the nas-mount codesigning record and the
  `docs/darwin-codesigning.md` manual — both land with PR #32; re-link
  here once it merges.
