---
type: Darwin Module
title: Cognee on mini
description: 'Mini serves Cognee agent memory and its dashboard over LAN HTTPS, with local storage and OpenAI inference.'
resource: modules/hosts/mini/cognee.nix
tags: [darwin-module, host-specific]
generated: { by: codex/gpt-6, at: 2026-11-26T16:57:51-08:00 }
---

[Mini](../hosts/mini.md) serves the [Cognee dashboard and API](cognee.md)
at `https://mini.home.lan:8443`. The Caddy listener uses the wired LAN
address that `mini.home.lan` resolves to. Update the listener and DNS
together if the address changes. LAN clients need Caddy's public CA
certificate, available at the path in the [Cognee manual](../../flakes/cognee/README.md).

Cognee reads its OpenAI credential from [sops-nix](sops.md). Ingestion
sends document chunks for graph extraction. Generated recall sends the
retrieved context to the model. Cognee stores data and generates FastEmbed
vectors on `mini`.

The relational pool allows four persistent and four overflow connections.
The original four-connection total timed out during the first Codex memory
write while the dashboard was active. The expanded pool completed the
same synthetic ingestion with the embedded databases.

## Source

- Module: [`modules/hosts/mini/cognee.nix`](../../modules/hosts/mini/cognee.nix)
