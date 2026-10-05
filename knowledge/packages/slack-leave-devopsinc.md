---
type: Nix Package
title: Slack Leave Devopsinc
description: 'Bash CLI (+ Spotlight app) that leaves every Slack `devopsinc-N` incident channel (N >= 1000) the PagerDuty routine auto-adds Kris to, via the Slack Web API with a Keychain-held user token.'
resource: pkgs/slack-leave-devopsinc.nix
tags: [package, darwin, slack]
generated: { by: claude-code/2.1.287, at: 2026-10-02T17:18:13+00:00 }
sources:
  - id: slack-web-api-spec
    resource: https://github.com/slackapi/slack-api-specs/blob/master/web-api/slack_web_openapi_v2.json
    title: Slack Web API OpenAPI spec (users.conversations, conversations.leave)
  - id: curl-retry
    resource: https://github.com/curl/curl/blob/master/docs/cmdline-opts/retry.md
    title: curl --retry (transient codes incl. 429, honours Retry-After)
  - id: nixpkgs-write-darwin-bundle
    resource: https://github.com/NixOS/nixpkgs/blob/c5c4a43b0e8056328ec4529f735cabdb8f1942bb/pkgs/build-support/make-darwin-bundle/write-darwin-bundle.nix
    title: nixpkgs writeDarwinBundle (binary-wrapper bundle executables)
---

`slack-leave-devopsinc [-n|--dry-run] [--notify]` pages through
`users.conversations` (public + private, unarchived), keeps names matching
`devopsinc-<digits>` with the number >= 1000, and calls `conversations.leave`
on each; one channel's failure (e.g. `last_member`) is reported and the rest
still run, with exit status 1 at the end.[^slack-web-api-spec] Rate limits are
left to `curl --retry 5`, which treats 429 as transient and waits out Slack's
`Retry-After`.[^curl-retry]

The implementation is plain bash in `pkgs/slack-leave-devopsinc.sh`, wrapped by
`writeShellApplication` (curl + jq pinned, ShellCheck at build) per the
`pkgs/` shell-tool convention. The token is a Slack **user** token (`xoxp-…`)
with `channels:read`, `groups:read`, `channels:write`, `groups:write`, read
from `$SLACK_LEAVE_TOKEN` or the login Keychain item `slack-leave-devopsinc`
(`/usr/bin/security`, the same Keychain idiom as
[claude-account-selector](../modules/claude-account-selector.md)'s
`claude-token-<name>`). Like [cbissue](cbissue.md), it reaches curl through
`printf | curl --config -`, never argv. One-time setup:

```sh
security add-generic-password -U -a "$USER" -s slack-leave-devopsinc -w   # paste the xoxp- token
```

The same derivation ships `Applications/Leave devopsinc Channels.app`: an
`LSUIElement` bundle whose `CFBundleExecutable` is a `makeBinaryWrapper`
around the CLI with `--notify`, the same native-wrapper choice nixpkgs'
`writeDarwinBundle` makes, so results surface as a macOS notification via
`/usr/bin/osascript`.[^nixpkgs-write-darwin-bundle] darwin-only
(`meta.platforms`, aarch64-darwin guard in `modules/packages.nix`); mounted by
the [slack-leave-devopsinc module](../modules/slack-leave-devopsinc.md). Why the
API rather than the original AppleScript UI driver:
[decision record](../decisions/slack-leave-devopsinc-api.md).

Added per the [add-package playbook](../playbooks/add-package.md).

## Source

- Package: [`pkgs/slack-leave-devopsinc.nix`](../../pkgs/slack-leave-devopsinc.nix)
- Script: [`pkgs/slack-leave-devopsinc.sh`](../../pkgs/slack-leave-devopsinc.sh)
- Overlay: [`overlays/slack-leave-devopsinc.nix`](../../overlays/slack-leave-devopsinc.nix) — exposes/replaces `pkgs.slack-leave-devopsinc`

[^slack-web-api-spec]: Slack Web API OpenAPI spec (users.conversations, conversations.leave)
[^curl-retry]: curl --retry (transient codes incl. 429, honours Retry-After)
[^nixpkgs-write-darwin-bundle]: nixpkgs writeDarwinBundle (binary-wrapper bundle executables)
