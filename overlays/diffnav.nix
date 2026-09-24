_final: prev: {
  # diffnav hard-codes its diff-pane footer pill (the "100% (13/13)" scroll
  # indicator) as ANSI 7 text on an ANSI 8 background. Our kanagawabones
  # palette lifts 8 to a light gray (#a6a69c), leaving 7 (#c8c093) nearly
  # unreadable on it (~1.3:1). diffnav exposes no theme config, so flip the
  # pill's text to ANSI 0 (#2d2c2c, ~6:1) — still palette-driven.
  diffnav = prev.diffnav.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace pkg/ui/panes/diffviewer/diffviewer.go \
        --replace-fail 'Foreground(lipgloss.White).' 'Foreground(lipgloss.Black).'
    '';
  });
}
