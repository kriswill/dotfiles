# TEMPORARY — nom 2.2.0 rejects any internal-json activity or result type it
# doesn't know, printing a ParseNixJSONMessageError line per event. Determinate
# Nix 3.23 tags its evaluation/source-copy spans (EvaluateFlakeDerivationOutput,
# CopySourcePath, BuildInstallables, …) with activity type 10113, so every
# `nom build` drowns in those errors; nix nightly adds activity 113 and result
# 109 the same way (maralorn/nix-output-monitor#309).
#
# Parse unknown activity types as nom's existing UnknownType, which it already
# ignores, and unknown result types as FileLinked, which nom parses but never
# consumes. Both become no-ops instead of errors.
#
# --replace-fail breaks the build once upstream reworks the parser — the cue to
# check whether a nom release handles this and DELETE this overlay (and its
# modules/overlays.nix line).
_final: prev: {
  nix-output-monitor = prev.nix-output-monitor.override {
    extraComposeFunctions = [
      (prev.haskell.lib.compose.overrideCabal (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace lib/NOM/Parser/JSON.hs \
            --replace-fail 'other -> fail ("invalid activity type: " <> show other)' \
              '_ -> pure UnknownType' \
            --replace-fail 'other -> fail ("invalid activity result type: " <> show other)' \
              '_ -> pure (FileLinked 0 0)'
        '';
      }))
    ];
  };
}
