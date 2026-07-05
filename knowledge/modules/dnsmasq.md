---
type: Darwin Module
title: Dnsmasq
description: dnsmasq — lightweight DNS forwarder/cache, configured here as a loopback-bound local resolver for custom hostnames like `p4c`.
resource: modules/darwin/dnsmasq.nix
tags: [darwin-module]
timestamp: '2026-07-04T00:00:00-07:00'
---

[dnsmasq](https://thekelleys.org.uk/dnsmasq/doc.html) is lightweight network
infrastructure software providing DNS forwarding/caching plus DHCP, router
advertisement, and network boot services, aimed at small networks and
resource-constrained hosts.

Mounted ungated on every darwin host (see the [host-mounted modules pattern](../patterns/host-mounted-modules.md)), auto-discovered
via the [Dendritic module layout](../patterns/dendritic-modules.md). Here it's
used purely as a local resolver, not a network-facing DHCP/DNS server:
nix-darwin's `services.dnsmasq` module binds it to `127.0.0.1` and statically
resolves `localhost` and `p4c` to `127.0.0.1`, with all other queries falling
through to normal upstream resolution.

## Source

- Module: [`modules/darwin/dnsmasq.nix`](../../modules/darwin/dnsmasq.nix)

## Citations

- [dnsmasq project homepage & docs](https://thekelleys.org.uk/dnsmasq/doc.html)
- [dnsmasq man page](https://thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html)
- [nix-darwin `services.dnsmasq` options (MyNixOS)](https://mynixos.com/nix-darwin/options/services.dnsmasq)
