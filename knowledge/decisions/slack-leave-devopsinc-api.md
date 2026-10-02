---
type: Decision
title: Leave Incident Channels Via The Slack API, Not UI Scripting
description: 'Replace the AppleScript that drove Slack.app''s Cmd+K switcher with a Web API CLI (users.conversations + conversations.leave) that finds the devopsinc-N channels itself, launched on demand from Spotlight through a nix-built app bundle.'
tags: [darwin, slack, automation]
status: stable
generated: { by: claude-code/2.1.287, at: 2026-10-02T17:18:13+00:00 }
sources:
  - id: slack-web-api-spec
    resource: https://github.com/slackapi/slack-api-specs/blob/master/web-api/slack_web_openapi_v2.json
    title: Slack Web API OpenAPI spec (users.conversations, conversations.leave)
  - id: nix-darwin-applications
    resource: https://github.com/lnl7/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/system/applications.nix
    title: nix-darwin applications module (systemPackages → /Applications/Nix Apps)
  - id: nixpkgs-write-darwin-bundle
    resource: https://github.com/NixOS/nixpkgs/blob/c5c4a43b0e8056328ec4529f735cabdb8f1942bb/pkgs/build-support/make-darwin-bundle/write-darwin-bundle.nix
    title: nixpkgs writeDarwinBundle (binary-wrapper bundle executables)
---

**Where:** [slack-leave-devopsinc package](../packages/slack-leave-devopsinc.md),
[slack-leave-devopsinc module](../modules/slack-leave-devopsinc.md).

## Context

A PagerDuty-triggered routine at work keeps adding Kris to Slack incident
channels named `devopsinc-<N>`. The existing fix was an AppleScript
(`osascript leave-devopsinc.applescript 1487 1489 …`) that drove Slack.app
with keystrokes: Cmd+K, type the name, Return, check the window title, then
`/leave`. It needed the channel numbers typed in by hand, Slack in the
foreground, Accessibility permission for whatever ran it, and tuned `delay`s;
the window-title guard was there because the quick switcher fuzzy-matches.
Kris wanted it triggerable on demand from Spotlight/Shortcuts, finding the
channels itself, on all Macs.

## Decision

- **Web API, not UI.** `users.conversations` (public + private, unarchived,
  cursor-paged) lists exactly the channels the user is in, and
  `conversations.leave` leaves by ID, so fuzzy matching, focus, delays and
  Accessibility all go away.[^slack-web-api-spec] Cost: a Slack **user**
  token (`xoxp-…`, scopes `channels:read`, `groups:read`, `channels:write`,
  `groups:write`) from a workspace app, which the workspace must allow.
- **Token in the login Keychain** (`security … -s slack-leave-devopsinc`),
  with `$SLACK_LEAVE_TOKEN` as an override. It's per-user, needs no
  rebuild, and an item created by `/usr/bin/security` is readable by it
  without a prompt, including from a Spotlight-launched process. Not sops:
  that's per-host, root-decrypted, and would put a work credential in the
  repo.
- **Spotlight via a nix-built `.app`**, not a Shortcuts.app shortcut, because
  shortcuts can't be declared reproducibly. The package ships
  `Applications/Leave devopsinc Channels.app` and the module puts it in
  `environment.systemPackages`, since nix-darwin copies only those apps into
  `/Applications/Nix Apps`, where Spotlight indexes them.[^nix-darwin-applications]
  The bundle executable is a `makeBinaryWrapper` (native Mach-O) adding
  `--notify`, following nixpkgs' `writeDarwinBundle`, rather than a bare
  script.[^nixpkgs-write-darwin-bundle] `LSUIElement` keeps it out of the
  Dock, and the outcome comes back as an `osascript` notification.
- **Keep the N >= 1000 guard** from the original script, so low-numbered
  `devopsinc-*` channels that aren't incident rooms are never touched.

## Consequences

One keystroke-free action leaves every current incident channel, whether or
not Slack is open. Watch for: a workspace that blocks user-token apps (then
this can't work and the UI script is the fallback); a private incident
channel where Kris is the last member, which fails with `last_member` and is
reported, not retried; and notifications appear under Script Editor's
notification settings, since `osascript` posts them.
Landed in commit `24be659`.

[^slack-web-api-spec]: Slack Web API OpenAPI spec (users.conversations, conversations.leave)
[^nix-darwin-applications]: nix-darwin applications module (systemPackages → /Applications/Nix Apps)
[^nixpkgs-write-darwin-bundle]: nixpkgs writeDarwinBundle (binary-wrapper bundle executables)
