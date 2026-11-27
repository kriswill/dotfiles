---
type: Sub-flake
title: Cognee
description: 'Cognee is a graph-backed agent memory service packaged here as a locked Apple Silicon Python runtime and a Next.js dashboard.'
resource: flakes/cognee
tags: [sub-flake, agent-memory, darwin]
generated: { by: codex/gpt-6, at: 2026-11-26T12:00:00-08:00 }
sources:
  - id: dependencies
    resource: https://github.com/topoteretes/cognee/blob/v1.6.10/pyproject.toml
    title: Cognee 1.6.10 dependency metadata
  - id: dashboard
    resource: https://github.com/topoteretes/cognee/tree/v1.6.10/cognee-frontend
    title: Cognee 1.6.10 frontend source
---

The [Cognee module](../modules/cognee.md) consumes the runtime directly.
The root also re-exports it as `packages.aarch64-darwin.cognee`.
The package uses uv2nix and a dedicated lockfile, following the
[Hermes packaging](hermes-agent.md) pattern.

The Ladybug release supplies a macOS 15 wheel. The derivation sets its
wheel selection target accordingly and includes GLiNER and PostgreSQL
dependencies in the immutable runtime. Model weights are cached
separately at runtime.[^dependencies] The
[native hosting decision](../decisions/native-cognee-on-darwin.md)
explains where mutable state lives.

`cognee-frontend` builds the matching Next.js standalone bundle from the
upstream npm lockfile. The build uses Nix-packaged Geist fonts, and the
runtime serves its assets directly from the store.[^dashboard]

[^dependencies]: Cognee Python dependencies and platform support.
[^dashboard]: Cognee dashboard source and dependency lockfile.
