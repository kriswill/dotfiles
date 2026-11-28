---
type: Decision
title: Mirror OKF Bundle into a Read-Only Cognee Dataset
description: 'Committed knowledge/ OKF concept docs are mirrored one-way into a shared read-only Cognee dataset (dotfiles-knowledge) by a user LaunchAgent under k, so fleet agents and subagents can semantically query repo knowledge without mutating it or duplicating canonical docs into private memory.'
tags: [okf, cognee, ai-agent, mini]
status: stable
generated: { by: antigravity/gemini-4-neon, at: 2026-11-27T15:25:00-08:00 }
sources:
  - id: okf-profile
    resource: ../okf-profile.md
    title: 'OKF Profile (bundle conventions and tooling)'
  - id: cognee-readme
    resource: ../../flakes/cognee/README.md
    title: 'flakes/cognee/README.md (ACL isolation, API keys, and resource limits)'
---

**Where:** [Cognee on mini](../modules/mini-cognee.md),
[Hermes Agent (mini)](../modules/mini-hermes-agent.md),
[mini](../hosts/mini.md).

## Context

`knowledge/` holds nearly 300 curated OKF v0.2 concept docs in git.[^okf-profile]
Agents working directly inside the dotfiles checkout can search it locally with
`rg`, but agents working in other repositories, remote hosts (`k`, `nebula`), or
conceptual queries without a known slug had no shared semantic index — and
frequently risked repeating canonical repo facts inside private per-agent Cognee
datasets (`mini-antigravity`, `mini-hermes`, Codex, etc.).

Replacing OKF in git with Cognee would lose PR diffs, branch accuracy,
`okf validate`, and zero-cost exact lookup. Meanwhile, Cognee on `mini` runs
embedded databases with `DATABASE_MAX_LRU_CACHE_SIZE=2` and a 256 MiB Ladybug
buffer pool per graph on 16 GB RAM,[^cognee-readme] so ingesting the full bundle
blindly or allowing concurrent writes from multiple agents would cause stale
duplicates (`409` conflicts or ghost versions) and memory pressure.

## Decision

Keep `knowledge/` in git as the single source of truth and project it one-way
into a shared, **read-only** Cognee dataset (`dotfiles-knowledge`, UUID
`60eccd45-bd3c-5328-b532-c8c09bdc236a`):

- **Dedicated writer account, user LaunchAgent under `k`:** Non-admin account
  `dotfiles-sync@mini.home.lan` owns `dotfiles-knowledge`, with its `0600` API
  key at `~/.config/cognee/keys/dotfiles-sync` and dataset UUID at
  `~/.config/cognee/dotfiles-knowledge.id`. `modules/hosts/mini/okf-cognee-sync.nix`
  installs `okf-cognee-sync` (TypeScript on `bun`) and runs `launchd.user.agents.okf-cognee-sync`
  every 30 minutes (`Background`, `LowPriorityIO`). Running as `k` matches
  `mini-antigravity`'s key posture (protects against accidental Seatbelt reads;
  not a hard boundary against Hermes's `HC_SOCKET` delegation).
- **Committed `HEAD` only, simple sync path:** `okf-cognee-sync.ts` reads only
  committed blobs via `git ls-tree` / `git show HEAD`, skips generated `index.md`,
  chronological `log.md`, `_okflight/`, and `viz.html`, prepends
  `Source: knowledge/<relpath>`, rejects secret patterns, and exits immediately
  without HTTP calls when the manifest digest matches local state. Modified or
  removed docs are deleted (`DELETE /api/v1/datasets/{id}/data/{data_id}`),
  then new/modified docs upload sequentially in folder-grouped batches
  (`POST /api/v1/add`) followed by one `POST /api/v1/cognify`.
- **21-doc pilot first:** Default `--include` starts with `patterns`,
  `playbooks`, `hosts`, and `okf-profile.md` (21 docs, ~77 KB) so `/capacity`
  RSS and recall latency can be observed before widening to `decisions/` and
  component cards.
- **General-purpose agent read-only access and no-repetition:** Verified
  general-purpose agent principals (`mini-antigravity`, `hermes-mini`, and
  `codex-k-pilot` on `k` over `https://mini.home.lan:8443`) receive
  `read`-only grants on `dotfiles-knowledge` (`write`/`delete`/`share` false);
  project-specific principals remain isolated. Antigravity's `cognee-memory`
  MCP server keeps `remember` strictly pinned to `mini-antigravity`, adds
  `COGNEE_READ_DATASET_IDS` + `recall(..., scope?)` with chunk deduplication,
  and instructs agents never to copy canonical `knowledge/` facts into private
  datasets.

## Consequences

- Verified 2026-11-27 on `mini` and `k`:
  - All 21 pilot docs cognified across two gentle batches (Cognee RSS rose ~40
    MiB to ~1.04 GiB); repeat sync is a zero-HTTP no-op; `org.nixos.okf-cognee-sync`
    runs cleanly on its 30-minute LaunchAgent schedule (`runs = 1`, exit `0`).
  - Recipient-side `read=true, write/delete/share=false` verified for
    `mini-antigravity`, `hermes-mini`, and `codex-k-pilot`. Consumer writes
    return `403` (`POST /api/v1/add`) and `DELETE` returns `401` on `hermes-mini`.
  - Live recall retrieved `knowledge/playbooks/git-signing-agent-setup.md` via
    Antigravity `recall(scope="shared")` and via UUID-scoped recall from both
    `hermes-mini` and `codex-k-pilot`.
  - **Hermes auto-recall caveat:** In `cognee-integration-hermes-agent` 1.4.3,
    unscoped / `auto` recall returned only `mini-hermes` on the probe (default
    writes stay on `mini-hermes`), so Hermes currently needs UUID-scoped recall
    (`60eccd45-bd3c-5328-b532-c8c09bdc236a`) to query `dotfiles-knowledge`.
- Weekly OKF gardening (code-vs-doc drift audit and report-only Hermes cron)
  is intentionally deferred to v2 after observing v1's steady-state RAM and
  recall latency on `/capacity`.

[^okf-profile]: OKF Profile (bundle conventions and tooling)
[^cognee-readme]: flakes/cognee/README.md (ACL isolation, API keys, and resource limits)
