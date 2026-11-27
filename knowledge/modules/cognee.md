---
type: Darwin Module
title: Cognee
description: 'Cognee provides persistent agent memory through a native launchd API with optional PostgreSQL and a dashboard behind LAN HTTPS.'
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

`services.cognee.frontend.enable` adds a separate loopback dashboard job.
Caddy serves the UI and API on one HTTPS origin. Node route handlers reach
the backend directly over loopback, while browsers use the HTTPS origin
for API requests and authentication.

[k](../hosts/k.md) and [nebula](../hosts/nebula.md) import the sub-flake's
standalone `clientTrust` modules. They pin the same public CA by file hash.
Both use the system trust bundle, `k` also uses the System Keychain, and
`nebula` gets a managed [Helium](helium.md) policy for `mini.home.lan`.

The activation hook runs after SOPS installs runtime files and requests a
graceful Cognee restart when the dotenv contents change. A private digest
under `/var/run` lets unchanged activations leave the API running.

Each job logs to its own state directory. Launchd opens the files as the
service account, which can write there at first startup.

The [native hosting decision](../decisions/native-cognee-on-darwin.md)
covers boot ordering, the database credential, and the roles of launchd
and Nix. [Mini's configuration](mini-cognee.md) enables the API and LAN
dashboard.
The [sub-flake manual](../../flakes/cognee/README.md) has
configuration and operating instructions.[^launchd]

[^launchd]: nix-darwin configuration options.
[^cognee]: Cognee dataset permissions.
