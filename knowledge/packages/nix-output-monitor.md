---
type: Overlay
title: Nix Output Monitor
description: 'TEMPORARY — nom 2.2.0 rejects any internal-json activity or result type it doesn''t know, printing a ParseNixJSONMessageError line per event.'
resource: overlays/nix-output-monitor.nix
tags: [overlay]
generated: { by: okflight/0.4.0, at: 2026-10-01T15:30:05-07:00 }
---

TEMPORARY — nom 2.2.0 rejects any internal-json activity or result type it doesn't know, printing a ParseNixJSONMessageError line per event. Determinate Nix 3.23 tags its evaluation/source-copy spans (EvaluateFlakeDerivationOutput, CopySourcePath, BuildInstallables, …) with activity type 10113, so every `nom build` drowns in those errors; nix nightly adds activity 113 and result 109 the same way (maralorn/nix-output-monitor#309). Parse unknown activity types as nom's existing UnknownType, which it already ignores, and unknown result types as FileLinked, which nom parses but never consumes. Both become no-ops instead of errors. --replace-fail breaks the build once upstream reworks the parser — the cue to check whether a nom release handles this and DELETE this overlay (and its modules/overlays.nix line).

## Source

- Overlay: [`overlays/nix-output-monitor.nix`](../../overlays/nix-output-monitor.nix)
