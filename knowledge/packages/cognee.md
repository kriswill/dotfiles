---
type: Sub-flake
title: Cognee
description: 'Cognee is a graph-backed agent memory service packaged here as a locked Apple Silicon Python runtime and a Next.js dashboard.'
resource: flakes/cognee
tags: [sub-flake, agent-memory, darwin]
generated: { by: codex/gpt-6, at: 2026-11-26T12:00:00-08:00 }
sources:
  - id: dependencies
    resource: https://github.com/topoteretes/cognee/blob/v1.6.11/pyproject.toml
    title: Cognee 1.6.11 dependency metadata
  - id: dashboard
    resource: https://github.com/topoteretes/cognee/tree/v1.6.11/cognee-frontend
    title: Cognee 1.6.11 frontend source
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

**Administration → Manage Users** is the instance's account administration:
create users, grant or remove superuser access, deactivate, set passwords,
issue and revoke API keys, edit per-dataset access, assign tenants and roles,
and delete. Its [admin router](../../flakes/cognee/admin_users.py) requires a
superuser's dashboard session cookie on every route, even if the service
allows anonymous access elsewhere, and refuses API keys and bearer tokens.
Changes also need a header only the dashboard sends, so another site cannot
submit one with the operator's cookie. The router refuses to demote,
deactivate or delete the caller, or the last superuser who can sign in. It
never returns password hashes or stored keys; a new key is returned once.
Setting a password ends that user's sessions, because Cognee binds each
token to the password hash. Changes go through Cognee's own user manager,
key, permission, tenant and role functions. API key management also requires
an authenticated user and cannot fall back to the built-in account.

No dashboard feature is a patch. Each is source under
`flakes/cognee/dashboard/<feature>/`, copied over the upstream tree at build
time and mounted by a few one-line edits to upstream files
([decision](../decisions/cognee-dashboard-source-overlays.md)):
`manage-users`, `api-keys` (the API Keys page and the agent setup dialogs
that create a key), `memory-reader` (the document reader above) and
`releases` (the release notes of the running version and of a newer stable
release, with an update link in the top bar). The build runs each feature's
tests. Two small patches remain for restyling upstream's own markup: the
sign-in form without pre-filled credentials, and a top bar that fits a
phone.

[^dependencies]: Cognee Python dependencies and platform support.
[^dashboard]: Cognee dashboard source and dependency lockfile.
