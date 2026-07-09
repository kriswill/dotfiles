# UniFi Dream Machine — LAN DNS & headless control

**Verified against:** UDM Pro Max at `192.168.0.1` (gateway + sole DNS server for `192.168.0.0/24`, DHCP domain `home.lan`), Network app **10.4.57** (confirmed via authenticated `unifi_get_system_info`, well past the 10.3.58 floor for the official `dns/policies` API); UNAS Pro 4 at `192.168.0.82`; scanned from macOS host `k` (en10). Checked 2026-07-09.

## LAN DNS architecture (as deployed)

Two independent naming systems run in parallel; they are **not** in conflict:

| System                    | Who answers                               | Name for the NAS                                                                  | Resolves to               |
| ------------------------- | ----------------------------------------- | --------------------------------------------------------------------------------- | ------------------------- |
| Unicast DNS (`home.lan`)  | UDM, from the client's reported hostname  | `home-unas-pro-4.home.lan`                                                        | `192.168.0.82`            |
| Unicast DNS (`home.lan`)  | UDM, client's "Local DNS Record" field    | `nas.home.lan` (added 2026-07-09)                                                 | `192.168.0.82`            |
| mDNS / Bonjour (`.local`) | The NAS itself (router not involved)      | host `unas-pro.local`, SMB service instance `UNAS-Pro._smb._tcp.local` (port 445) | `192.168.0.82` + ULA IPv6 |

- Clients get exactly one DNS server via DHCP (the UDM) with search domain `home.lan`.
- The NAS web UI URL uses the DNS name; **macOS SMB mounts ride Bonjour** — Finder's sidebar/Network browser discovers via mDNS, so mounts (including Time Machine) reference `//k@UNAS-Pro._smb._tcp.local/...`. That is why SMB appears to "use a different DNS": it isn't DNS at all.
- The mDNS hostname (`unas-pro`) and the client's reported hostname (`home-unas-pro-4`) simply differ.
- Reverse lookups are odd by design: PTR for `192.168.0.82` from the UDM returns a UniFi device-identity record (`…id.ui.direct`), not a `home.lan` name. Harmless.
- Leave Time Machine on the Bonjour name — that is how it rediscovers its destination.
- **Unicast `home.lan` names for a client actually come from *two independent, coexisting* mechanisms — not one:**
  1. **Auto-derived from the client's raw `hostname` field** (`unifi_get_client_details` → `hostname: "Home-UNAS-Pro-4"`, `hostname_source: "ubios"`) → `home-unas-pro-4.home.lan`. This is what was already there; it is **not** controlled by the "Local DNS Record" feature and is not removed by changing it.
  2. **The per-client "Local DNS Record" feature** (`local_dns_record_enabled` + `local_dns_record` fields on the client object, UniFi Network 7.2+; MCP tool `unifi_set_client_ip_settings`) → an *additional* name, one per client, that resolves alongside whatever mechanism 1 produced. We set this to `nas.home.lan` on 2026-07-09 (see below) — it did not replace `home-unas-pro-4.home.lan`; both now resolve.
  - **The static-DNS record set is separate again** — confirmed empty via `unifi_list_dns_records` before we touched anything. It manages a third, independent list (the DNS API / DNSControl / this MCP server's `create/update/delete_dns_record`) that doesn't see or shadow either of the above. Creating a static A record for an IP that already has a Local DNS Record (mechanism 2) enabled is rejected outright: `api.err.StaticDnsOverlapsWithDeviceLocalDns`.
  - To fully replace `home-unas-pro-4.home.lan` you'd have to change the client's raw `hostname`, a different and untested action — not something we've done.

## Mounting via `nas.home.lan` (SMB) — tested 2026-07-09

`mount_smbfs -N //k@nas.home.lan/Personal-Drive <mountpoint>` (the `-N` flag uses keychain-only auth, no interactive prompt — required for anything non-interactive, including a launchd agent) failed with **`File exists`** while the existing Bonjour-based mount (`//k@UNAS-Pro._smb._tcp.local/Personal-Drive`) was still active — **not a DNS or auth problem**. macOS's SMB client recognizes both hostnames as the *same negotiated server identity* (they resolve to the same box) and refuses a second concurrent mount of the same share. Confirmed the mechanism by unmounting the Bonjour-based mount first (`diskutil unmount /Volumes/Personal-Drive`) and retrying: `nas.home.lan` mounted cleanly, browsed correctly, and reported real capacity (3.7T / 155G used). The `-N` keychain lookup also succeeded with no prior credential entry made under that literal hostname — another sign macOS keys the keychain match off the server's canonical identity, not the connect string.

Practical upshot: **you can have `nas.home.lan` *or* the Bonjour name mounted, never both at once.** Kris now mounts permanently at `~/nas` via `nas.home.lan` (module below); Time Machine stays on the Bonjour destination as before (unaffected — separate share, separate mount).

**Persistent auto-mount:** `modules/darwin/nas-mount.nix` (`flake.modules.darwin.nas-mount`, gated behind `services.nas-mount.enable`, flipped on for host `k`) — a `launchd.user.agents.nas-mount` job, `RunAtLoad` + `StartInterval = 300` (retries every 5 min in case the NAS/network wasn't up yet at login), running an idempotent `mkdir -p ~/nas && mount_smbfs -N ... ~/nas` guarded by a `mount | grep` check so re-runs are harmless.

## Scan toolkit (macOS)

```sh
scutil --dns | head -12                        # resolver list + search domain
ipconfig getsummary en10 | grep -iE 'domain|server_id|router'   # DHCP-provided DNS
dig +short <name> @192.168.0.1                 # ask the UDM directly
dig +short -x <ip> @192.168.0.1                # reverse
dscacheutil -q host -a name <host>.local       # one-shot mDNS resolve
mount | grep -i smb; smbutil statshares -a     # what names SMB actually mounted via
dns-sd -B _smb._tcp local.                     # browse SMB advertisements (runs forever)
dns-sd -L "UNAS-Pro" _smb._tcp local.          # resolve one service instance (runs forever)
```

`dns-sd` never exits — wrap it: `timeout 4 dns-sd …` (coreutils, in the dev shell) or `perl -e 'alarm 4; exec @ARGV' dns-sd …`.

## Talking to the UDM without the UI

All three doors verified live on this UDM 2026-07-09 (API paths return 401 = present-behind-auth, not 404; SSH port open).

### 1. Official local Network API — the one to build on

- Base: `https://192.168.0.1/proxy/network/integration/v1/...`, header `X-API-KEY`. Versioned reference: <https://developer.ui.com/network/>.
- Key creation is a **one-time UI step**: Settings → Admins & Users → admin → Create API Key. After that, everything is curl-able.
- DNS management is in the official API on recent 10.x releases:
  `/integration/v1/sites/{siteId}/dns/policies/*` — full CRUD on A/AAAA/CNAME/MX/TXT/SRV.

```sh
curl -sk -H "X-API-KEY: $KEY" https://192.168.0.1/proxy/network/integration/v1/sites
```

### 2. Legacy controller API — broadest coverage, unsupported

- `/proxy/network/api/s/<site>/...` (stats, `rest/*` config) and `/proxy/network/v2/api/site/<site>/static-dns` (pre-10.x static DNS records). Cookie login with a local admin account. Everything the UI can do lives somewhere here, but endpoints occasionally shuffle between releases.

### 3. SSH — read-only forensics

- `ssh root@192.168.0.1` (port 22 open on this UDM). Inspect the *generated* dnsmasq config under `/run/dnsmasq.conf.d/` to see what the DNS server actually serves. **Do not edit** — the controller regenerates these files on every provision. APIs are the write path.

### Remote access

- **Preferred:** UDM's built-in WireGuard VPN server, then hit the local API as if at home — full surface, no exposed ports. - Cloud [Site Manager API](https://help.ui.com/hc/en-us/articles/30076656117655-Getting-Started-with-the-Official-UniFi-API) (`api.ui.com`, account-level API key): good for fleet/health auditing, thinner on config control.

## UNAS Pro 4 — a separate local API (UniFi Drive)

**This is a different API surface from everything above** — it runs on the NAS itself (`192.168.0.82`), not proxied through the UDM, and belongs to the "UniFi Drive" application (the NAS-hosting counterpart to Network/Protect/Access), not the Network API. Confirmed live 2026-07-09 by probing the NAS directly:

```
/api/auth/login                          → 401 (exists, needs POST)
/api/system                              → 200  ← unauthenticated!
/proxy/drive/api/v2/storage               → 401 (exists)
/proxy/drive/api/v2/systems/network-io    → 401 (exists)
/proxy/drive/api/v2/systems/fan-control   → 401 (exists)
```

`GET /api/system` returns **200 with no auth** and leaks minor device-identity metadata (MAC, model, `direct-connect` domain, cloud/SSO status). Not a real vulnerability — standard UniFi OS console-discovery behavior for onboarding — but worth knowing it's there unauthenticated:

```sh
curl -sk https://192.168.0.82/api/system   # {"hardware":{"shortname":"UNASPRO4"},"mac":"A89C6C04DA4B", ...}
```

**No official developer documentation exists** for this API (unlike Network's `developer.ui.com/network`) — Ubiquiti has not published a UniFi Drive API reference. **No MCP support exists either**: confirmed by reading `sirkirby/unifi-mcp`'s actual repo tree (`plugins/` contains only `unifi-network`, `unifi-access`, `unifi-protect` — no drive/UNAS package). In the Network MCP the NAS only ever shows up as a generic network *client* (hostname/IP/MAC) — no storage, snapshot, or fan tools.

The best available documentation is a well-built, actively maintained, MIT-licensed **reverse-engineered** client: **[memphi2/ha-unifi-drive](https://github.com/memphi2/ha-unifi-drive)** (Home Assistant integration). Endpoint paths below were pulled directly from its source (`custom_components/unifi_unas/const.py` + `snapshot_paths.py`), not the README:

| Purpose | Method + Path |
|---|---|
| Login | `POST /api/auth/login` → sets `TOKEN` cookie |
| System identity/status | `GET /api/system` |
| Storage/pool/drive health | `GET /proxy/drive/api/v2/storage` |
| Network throughput | `GET /proxy/drive/api/v2/systems/network-io` |
| Fan control (read/write) | `GET /proxy/drive/api/v2/systems/fan-control` |
| Backup tasks | `GET /proxy/drive/api/v2/remote-backup/tasks`, `POST .../run-task/{task_id}` |
| Snapshot settings | `GET/POST /proxy/drive/api/v1/systems/snapshot`, `/proxy/drive/api/v1/snapshot-settings/{personal,shared}/{target_id}` |
| Snapshot listings | `GET /proxy/drive/api/v1/snapshots/{personal,shared}/{target_id or shared_drive_name}` |
| Firmware/app update | `POST /api/firmware/update`, `POST /api/applications/drive/update` |
| Power control | `POST /api/system/poweroff`, `POST /api/system/reboot` |

Auth model (from `api_auth.py`/`api_transport.py`): **session-cookie login** (`POST /api/auth/login` with username/password → `TOKEN` cookie, refreshed via `X-CSRF-Token` echoed from the `x-csrf-token`/`x-updated-csrf-token` response headers on each request) **or an API key** via an `X-API-Key` header — API-key mode is only used when no username/password is configured; if both are present, session-cookie auth wins. Tested by the integration author against UNAS2 (UniFi OS 5.1.8–5.1.19) and **UNAS4 (5.1.16)** — the latter is this exact NAS's reported firmware.

## OSS ecosystem (surveyed 2026-07-09)

- [sirkirby/unifi-mcp](https://github.com/sirkirby/unifi-mcp) — MCP servers for Network (181 tools, stable) / Protect / Access; MIT, Python; Claude Code plugin (`/plugin marketplace add sirkirby/unifi-mcp`, then per-server `/reload-plugins`). All mutations are preview-then-confirm — the right safety model for autonomous agents. **Auth caveat:** primary auth is local admin **username+password** (`UNIFI_NETWORK_HOST/USERNAME/PASSWORD` env vars, set via `/unifi-network:unifi-network-setup`) — its API-key mode is explicitly experimental, read-only, and covers only a tool subset, so it does not fully substitute for the official `X-API-KEY` path above. Mutations are further permission-gated per category (`UNIFI_POLICY_NETWORK_<CATEGORY>_<ACTION>=true`); devices/clients/networks/WLANs/VPN servers/routes default off, deletes always default off.
  - **Installed and verified working 2026-07-09** against this UDM (`unifi_get_system_info`, `unifi_get_network_health`, `unifi_list_dns_records` all returned live data). Setup writes credentials into `.claude/settings.local.json` via `scripts/set-env.sh` — run that script yourself in your own terminal rather than pasting a password through chat, since the harness would persist it in the session transcript.
  - **Gotcha:** a password containing shell-special characters can get mangled if pasted into a `set-env.sh` invocation without careful quoting — a 403 on `/api/auth/login` with otherwise-correct credentials is the symptom; re-run with the password properly quoted (or single-quoted) before suspecting the account itself.
  - Tool access is lazy-loaded behind three meta-tools: `unifi_tool_index` (discover, supports `category`/`search` filters), `unifi_execute` (call one), `unifi_batch` (call many in parallel, poll via `unifi_batch_status`). DNS tools live under `category: "dns"` — `list/get/create/update/delete_dns_record`.
  - **⚠️ Safety-contract violation found (2026-07-09):** calling `unifi_create_dns_record` for an A record whose IP already has a client "Local DNS Record" enabled returned `{"success": false, "error": "...StaticDnsOverlapsWithDeviceLocalDns"}` — **but the underlying UDM call had already mutated the client's `local_dns_record` field to the requested key before the conflict check rejected the static-record half.** A call reporting failure was not a no-op. Always re-read state (`unifi_get_client_details`, `unifi_list_dns_records`) after *any* mutation call that errors, not just after ones that report success, before trusting nothing changed. We resolved it by explicitly re-running the correct tool (`unifi_set_client_ip_settings`) with `confirm=true` so there was a clean, intentional record of the final state — its own preview correctly showed `current == proposed` once we knew what to target.
- [DNSControl UniFi provider](https://docs.dnscontrol.org/provider/unifi) — declarative DNS-as-code with `preview`/`push` (built-in audit diff). Speaks *both* DNS APIs and auto-detects: official `dns/policies` on 10.1+, legacy `static-dns` fallback on 8.x/9.x.
- [kashalls/external-dns-unifi-webhook](https://github.com/kashalls/external-dns-unifi-webhook)
  — Kubernetes ExternalDNS → UniFi records; compact Go reference for the DNS endpoints if replicating.
- [filipowm/terraform-provider-unifi](https://github.com/filipowm/terraform-provider-unifi)
  — the actively maintained fork of the archived
  [paultyng provider](https://github.com/paultyng/terraform-provider-unifi)
  ([ubiquiti-community's](https://registry.terraform.io/providers/ubiquiti-community/unifi/latest)
  is the conservative drop-in fork). `terraform plan` = audit primitive; its `go-unifi` client is the best Go building block.
- Python: `aiounifi` (what Home Assistant uses), `pyunifi`.
- [memphi2/ha-unifi-drive](https://github.com/memphi2/ha-unifi-drive) — the only real client for the UNAS/UniFi Drive local API (see above); Home Assistant custom component, MIT, Python. Not a general-purpose CLI/MCP, but its source is the closest thing to a spec this API has.

**Plan of record for audit + autonomous control:** DNS records under DNSControl (git-tracked zone, `dnscontrol preview` as drift audit — fits this repo); sirkirby/unifi-mcp as the agent layer for everything else. If rolling our own instead: the official API is just HTTPS + `X-API-KEY` + JSON, so a thin bun/TypeScript CLI + MCP wrapper over `/integration/v1` (legacy `v2/static-dns` fallback) is a small, durable project.

## Learned behaviours & workarounds

- **(2026-07-09) "SMB uses a different DNS" was Bonjour, not DNS.** Finder mounts via mDNS service discovery (`UNAS-Pro._smb._tcp.local`); the `home.lan` name never enters the SMB path. Check `mount | grep smb` before chasing DNS records.
- **(2026-07-09) UDM reverse PTR returns `…id.ui.direct`, not `home.lan`.** UniFi's internal device identity — expected, not a misconfiguration.
- **(2026-07-09) Can't fingerprint the Network version unauthenticated.** `/proxy/network/status` (which used to leak the version) now returns 401 on this firmware. Confirmed instead via an authenticated MCP call: **10.4.57**.
- **(2026-07-09) 401-vs-404 probing works for API surface discovery.** Auth is checked before routing existence on `integration/v1`, legacy `api/s/*`, and `v2/.../static-dns` — a 401 confirms the endpoint family exists without credentials.
- **(2026-07-09) The API key bootstrap is the only unavoidable UI touch.** Everything downstream (audit, records, agents) is headless once one key is minted.
- **(2026-07-09) Zero static DNS records exist on this controller — every `home.lan` name resolvable today (including the NAS's) is DHCP-lease-derived, not manually configured.** Don't assume a resolvable `home.lan` name implies a static-DNS entry to edit/audit; check `unifi_list_dns_records` (or the `dns/policies`/`static-dns` API) directly.
- **(2026-07-09) A UniFi local-admin password with shell-special characters breaks naive shell quoting in setup one-liners, producing a 403 on `/api/auth/login`** that looks identical to a bad-account-type or 2FA-blocked login. Rule out quoting before treating it as a credentials/account-type problem.
- **(2026-07-09) A "reported failure" mutation can still write.** `unifi_create_dns_record` returned `success: false` for a conflicting A record, yet had already changed the conflicting client's `local_dns_record` field server-side. Don't treat a non-`success` mutation response as guaranteed no-op — re-check live state.
- **(2026-07-09) A client can carry two independent `home.lan` names simultaneously**: one auto-derived from its raw reported `hostname`, one from the optional per-client "Local DNS Record" field. Setting the latter does not replace or remove the former.
- **(2026-07-09) The NAS's local API is a distinct surface from the Network API — don't assume UDM API coverage extends to it.** UniFi Drive/UNAS has its own unpublished local API on the NAS host itself; neither the official Network `integration/v1` API nor sirkirby/unifi-mcp reach it. Verified by reading the plugin repo's actual file tree, not its docs.
- **(2026-07-09) `GET /api/system` on the NAS is unauthenticated** and returns MAC/model/direct-connect-domain/SSO-status. Minor recon-only leak, standard UniFi OS onboarding-discovery behavior — not something we changed or need to fix.

## Sources

- Live scan of this LAN 2026-07-09: `scutil --dns`, `ipconfig getsummary`, `dig @192.168.0.1`, `dscacheutil`, `smbutil statshares -a`, `dns-sd`, endpoint probes with `curl -sk`, `nc -z 192.168.0.1 22`.
- [Official UniFi API getting started](https://help.ui.com/hc/en-us/articles/30076656117655-Getting-Started-with-the-Official-UniFi-API), [UniFi Network API reference](https://developer.ui.com/network/v10.1.84/gettingstarted), [UniFi DNS records & local hostnames](https://help.ui.com/hc/en-us/articles/15179064940439-UniFi-DNS-Records-and-Local-Hostnames)
- [DNSControl UniFi provider docs](https://docs.dnscontrol.org/provider/unifi) (API auto-detection, record types, flat-zone limitation).
- UNAS Pro 4 API endpoints: read directly from [memphi2/ha-unifi-drive](https://github.com/memphi2/ha-unifi-drive) source (`const.py`, `api_auth.py`, `api_transport.py`, `snapshot_paths.py`) 2026-07-09, then confirmed live against `192.168.0.82` with `curl -sk`. `sirkirby/unifi-mcp` repo tree checked via `gh api repos/sirkirby/unifi-mcp/contents/plugins` to confirm no drive/UNAS plugin exists.
