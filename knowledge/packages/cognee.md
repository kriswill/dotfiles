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
wheel selection target accordingly and includes FastEmbed and PostgreSQL
dependencies in the immutable runtime. The packaged graph extractor uses a
configured LLM; the optional offline GLiNER stack is excluded to avoid its
vulnerable Transformers dependency. Embedding model weights are cached
separately at runtime.[^dependencies] The
[native hosting decision](../decisions/native-cognee-on-darwin.md)
explains where mutable state lives.

`cognee-frontend` builds the matching Next.js standalone bundle from the
upstream npm lockfile. The build uses Nix-packaged Geist fonts, and the
runtime serves its assets directly from the store.[^dashboard]

On **Datasets**, select a dataset and click a memory, plain-text, or Markdown
title in the **Documents** column. The separate dataset detail page’s file
table opens the same reader. **Formatted** renders Markdown;
**Original** preserves the source text. Both use the signed-in reader’s
dataset access. Above 128 KiB the preview offers a full-text download.

[^dependencies]: Cognee Python dependencies and platform support.
[^dashboard]: Cognee dashboard source and dependency lockfile.
