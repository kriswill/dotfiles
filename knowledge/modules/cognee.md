---
type: Darwin Module
title: Cognee
description: 'Cognee provides persistent agent memory through a native launchd API with optional private PostgreSQL and LAN HTTPS.'
resource: modules/darwin/cognee.nix
tags: [darwin-module, agent-memory, launchd]
generated: { by: codex/gpt-6, at: 2026-11-26T12:00:00-08:00 }
sources:
  - id: launchd
    resource: https://nix-darwin.github.io/nix-darwin/manual/
    title: nix-darwin launchd options
  - id: cognee
    resource: https://docs.cognee.ai/setup-configuration/permissions
    title: Cognee permissions
---

The [Cognee sub-flake](../packages/cognee.md) supplies the module and
runtime. `services.cognee.enable` is opt-in. The API listens on loopback
with dataset access control. The optional Caddy job serves a specific LAN
address and blocks signup at the proxy. The host can still provision users
on loopback. HTTPS mode adds the `Secure` flag to the login cookie.[^cognee]

The activation hook runs after SOPS installs runtime files and requests a
graceful Cognee restart when the dotenv contents change. A private digest
under `/var/run` lets unchanged activations leave the API running.

The [native hosting decision](../decisions/native-cognee-on-darwin.md)
covers boot ordering, the database credential, and the roles of launchd
and Nix. [Mini](../hosts/mini.md) is the intended host for a shared
deployment. The [sub-flake manual](../../flakes/cognee/README.md) has
configuration and operating instructions.[^launchd]

[^launchd]: nix-darwin configuration options.
[^cognee]: Cognee dataset permissions.
