---
type: Decision
title: CI Builds Both Host Closures — No Signing Key, No Age Key, Ever
description: 'GitHub Actions builds darwinConfigurations.k.system (free arm64 macOS runner, public repo) and nebula''s NixOS toplevel on every PR, pushing both closures to the private FlakeHub Cache via OIDC, plus a weekly update-flake-lock PR via a fine-grained PAT. The load-bearing security property: builds never decrypt sops secrets and every flake input is a public fetch (okf went public 2026-07), so CI holds zero build credentials — the Developer ID signing key never touches GitHub, and the cache needs no key at all.'
tags: [ci, security, codesigning, cache]
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
- **CI holds zero build credentials (since 2026-07-11):** okf went public,
  so its input became `github:kriswill/okflight` and the read-only deploy
  key (`OKFLIGHT_DEPLOY_KEY` + `webfactory/ssh-agent` + known_hosts steps)
  was dropped from all three workflows (ci, update-flake-lock, pages —
  retire the secret and the okflight deploy key once this merges). **No
  signing key and no age key in CI ever**: a compromised workflow,
  malicious PR, or exfiltrated secret store cannot leak what was never
  there. Fork PRs now build fine; lacking `id-token`, they only lose the
  cache push. `FLAKE_UPDATE_PAT` (bump PRs) is the sole remaining secret.
- **Account-wide caching via a reusable workflow**
  (`.github/workflows/nix-build-cache.yml`, `workflow_call`): any
  kriswill/* repo gets Determinate Nix + FlakeHub cache CI with a one-job
  caller granting `id-token: write` — the cache is account-scoped, so no
  per-repo registration or secret exists. flake-explorer and okflight
  wired 2026-07-11 (okflight builds on both ubuntu and arm64 macOS because
  this flake consumes okf on x86_64-linux and aarch64-darwin).
- **`update-flake-lock.yml`** (weekly cron + dispatch):
  `DeterminateSystems/update-flake-lock@v28` opens the bump PR with a
  fine-grained PAT (`FLAKE_UPDATE_PAT`, this repo only, Contents R/W +
  Pull requests R/W) because events created with the default `GITHUB_TOKEN`
  never trigger other workflows — the PAT is what makes ci.yml run on the
  bump PR. Chosen over Dependabot's native nix support (April 2026)
  because Dependabot cannot bump the private git+ssh okf input or the
  FlakeHub `determinate` input.
- **FlakeHub Cache push (2026-07-11):** both jobs run
  `DeterminateSystems/flakehub-cache-action`, pushing every closure they
  build to the private FlakeHub cache (paid Determinate account) and
  pulling prior CI builds back. It replaced the darwin job's
  `magic-nix-cache-action` (~10 GiB GHA-cache backend). Auth is the job's
  OIDC JWT (`permissions: id-token: write`) — FlakeHub forbids ad-hoc push
  by design, so this workflow is the cache's only writer and there is no
  cache secret to leak; the no-new-credentials property above holds. Hosts
  consume with a one-time `determinate-nixd login` per machine (Determinate
  Nix auto-configures substituter, netrc, and trusted keys; pull verified
  on `k` 2026-07-11 via `nix store info --store https://cache.flakehub.com`).
- **Accepted cost:** hyprland/noctalia `follows` this flake's nixpkgs, so
  their upstream caches can never hit — every bump PR rebuilds them from
  source on the nebula job, once; the FlakeHub cache then serves that build
  to re-runs and to nebula itself.

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
- The `follows` rebuild cost moves off the machines: after a merged bump
  PR, nebula's `nrs` pulls source-built Hyprland/noctalia prebuilt from
  the FlakeHub cache instead of compiling locally; same for the custom
  packages on the darwin hosts (`k` — and `mini`/`SOC-Kris-Williams` for
  the store paths their closures share with `k`'s).
- First-run data (2026-07-10): `darwin-k` green in 41m8s fully uncached,
  and it DID fetch the private okf input (ssh-agent is required, not
  precautionary). `nixos-nebula` failed twice on **Codeberg 503/504
  fetching snowglobe-lib** — reproduced from a residential IP, i.e. a real
  Codeberg outage, and only the nebula eval forces that input (darwin
  never touches Codeberg). Mitigation was a retried `nix flake archive`
  step (~10 min backoff). **Resolved 2026-07-11:** the escalation happened
  — snowglobe-lib moved to the `github:kriswill/snowglobe-lib` fork
  (`16207cf`), every input is now GitHub or FlakeHub, and the retry step
  was removed.

## Citations

- [FlakeHub Cache: CI-only push, JWT auth, `determinate-nixd login` to pull](https://docs.determinate.systems/flakehub/cache/)
- [DeterminateSystems/flakehub-cache-action](https://github.com/DeterminateSystems/flakehub-cache-action)
- [GitHub: workflows are not triggered by GITHUB_TOKEN events](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow#triggering-a-workflow-from-a-workflow)
- [DeterminateSystems/update-flake-lock](https://github.com/DeterminateSystems/update-flake-lock)
- [webfactory/ssh-agent](https://github.com/webfactory/ssh-agent)
- [GitHub-hosted runners: standard runners are free for public repositories](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
- Decision context: the nas-mount codesigning record and the
  `docs/darwin-codesigning.md` manual — both land with PR #32; re-link
  here once it merges.
