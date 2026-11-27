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

## Capacity monitoring

The hourly Hermes watchdog retains 180 days of numeric samples in
`$HERMES_HOME/state/cognee-capacity/history.sqlite`. The watchdog scripts and
schedules are managed in the live Hermes profile, not installed by this
module. Run `python3 $HERMES_HOME/scripts/cognee_capacity.py` for the weekly
review's input.
Host disk headroom, memory pressure, swap, load, API-account RSS/CPU and
health latency are distinct from Cognee's own growth. After `nrs`, the
`org.nixos.cognee-capacity` job publishes service-state bytes, document
and dataset counts, and recorded remember/recall activity for the trailing
hour at `/var/lib/cognee-capacity/latest.json`. It runs as the service user;
no document text, query, account identifier or API key is exported.

The forecast uses up to 28 days of daily medians and needs seven days with
at least 12 hourly samples each. Warn at 90 days to the disk reserve
(the larger of 10% or 20 GiB); escalate at 30 days. CPU, memory pressure
and latency warnings use sustained observations, not a linear RAM estimate.
Missing exporter data is unknown, not zero. On-host alerts cannot detect a
total host outage while it is happening.

Open `/capacity` on mini's existing Cognee HTTPS origin after signing in as the
human operator. Warnings and disk runway come first, then daily storage and
hourly operation-duration charts. Chart gaps are not interpolated; open
**Raw measurements** for exact readings and operation counts. Reload the page
to see the latest readings. Caddy routes `/capacity` and `/capacity/` to Bun
over a Unix socket, and Bun checks the session over Cognee's API socket.
When capacity is enabled, Caddy also uses the API socket for its HTTPS API
routes. Only the respective service accounts can replace the socket files;
if either listener is down, the request fails without a TCP fallback.
Cognee still uses one worker and retains its loopback TCP port for local
clients. On a fresh host, create `/var/lib/cognee-capacity-page/viewer.env`
(`k:_www`, `0640`) with
`CAPACITY_VIEWER` set to the operator's Cognee login email. Do not put this
allowlist or the operator's password in the repository. A separate publisher
copies the last 28 days of numeric history every five minutes, so the web
process does not need access to Hermes or Cognee databases. Discord delivery
is not configured.

## Release notes and updates

The dashboard's `/releases` page uses the version reported by the running
Cognee API's `/health`, not the version in the checkout. It fetches the
matching GitHub release notes and separately shows notes for GitHub's latest
stable release when its version is newer. The top-bar badge links to that
section. An unavailable check is not treated as up to date. The frontend
caches the upstream check for 15 minutes; no GitHub token or browser-side
GitHub request is needed. The badge does not install updates.

## Source

- Module: [`modules/hosts/mini/cognee.nix`](../../modules/hosts/mini/cognee.nix)
- Capacity UI: [`cognee-capacity-page.js`](../../modules/hosts/mini/cognee-capacity-page.js)
- Releases UI and endpoint: [`dashboard-releases.patch`](../../flakes/cognee/dashboard-releases.patch)
