---
type: Decision
title: Unfree Packages Are Deny-by-default
description: nixpkgs.config.allowUnfree is false; each unfree package needs an explicit allowUnfreePredicate entry in core.nix, making every exception reviewable.
resource: modules/darwin/core.nix
tags: [nixpkgs, licensing, policy]
timestamp: '2026-07-03T12:00:00-07:00'
---

**Status:** active. **Where:** [core](../modules/core.md).

## Context

`allowUnfree = true` is a blanket waiver — unfree software then enters the
closure silently via any dependency edge, and nothing in review flags it.

## Decision

`modules/darwin/core.nix` sets `nixpkgs.config.allowUnfree = false`
repo-wide. Permitting a specific unfree package means adding it to the
`allowUnfreePredicate` there — a one-line, greppable, code-reviewed exception.

**Amended 2026-07-03:** "repo-wide" now means darwin-class-wide — nebula's
unfree policy comes via snowglobe-lib profiles, so the darwin predicate list
enumerates only Mac closures.

## Consequences

- Every unfree package in the closure is enumerable from one file.
- A new unfree dependency fails evaluation loudly instead of slipping in —
  the fix is deliberate, not automatic (see the
  [add-package playbook](../playbooks/add-package.md)).
