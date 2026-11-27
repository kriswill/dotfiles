---
type: Decision
title: Run Cognee as native macOS services
description: 'A locked Python runtime and system launchd jobs let an Apple Silicon host serve shared agent memory before user login.'
tags: [cognee, launchd, postgres, darwin]
status: stable
generated: { by: codex/gpt-6, at: 2026-11-26T12:00:00-08:00 }
sources:
  - id: apple-launchd
    resource: https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html
    title: Apple launch daemon and agent lifecycle
  - id: environments
    resource: https://github.com/topoteretes/cognee/blob/v1.6.10/.env.template
    title: Cognee backend and resource settings
---

## Context

[Mini](../hosts/mini.md) can serve all LAN clients from one always-awake
host. Its 16 GB of memory makes the cost of a VM and concurrent ingestion
worth controlling.

## Decision

The [Cognee sub-flake](../packages/cognee.md) pins the Python closure.
The [darwin module](../modules/cognee.md) runs services in the system
launchd domain so they can start before a GUI login.[^apple-launchd]

Cognee can use its embedded stores. With managed PostgreSQL enabled,
the module starts a private cluster and provisions the vector extension
before serving requests. Per-dataset vector schemas live in one database,
while Ladybug and the data files remain in Cognee's state directory.
The PostgreSQL bootstrap uses a generated credential outside the Nix
store. Optional HTTPS uses a separate account for the proxy and its CA.

The optional dashboard uses a standalone Next.js build and its own
loopback launchd listener. Caddy presents the frontend and API on the same
HTTPS origin, so browser authentication uses Cognee's existing cookies.
The dashboard's server-side routes talk to the loopback API directly.

## Consequences

The API has one worker and defaults to small database pools and limited
GLiNER concurrency.[^environments] Backups need the database and file
state. Activation and Nix rollback change the executables and service
configuration, while durable memory follows its own backup and migration
lifecycle.

[^apple-launchd]: Apple's description of system daemon and user agent startup.
[^environments]: Cognee's tagged configuration template.
