# Kris' diffnav (system-level port of the old home-manager module).
#
# diffnav is git's diff/show pager (set under [pager] in the stow-managed
# ~/.config/git/config — see home/git). diffnav bundles and PATH-prepends its
# OWN delta for rendering, so it never uses the delta installed here — its diff
# styling is delta's stock default both before and after this migration.
#
# What this module installs is a delta for *direct* `delta` CLI use, wrapped
# with the kanagawa theme. The old home-manager programs.delta set
# enableGitIntegration = false with a non-empty `options` block; home-manager
# therefore never wrote a [delta] section into the git config, but it DID put a
# `delta` wrapped with `--config <kanagawa options>` on PATH (its finalPackage).
# We reproduce that wrapped binary so an ad-hoc `delta foo bar` keeps the theme.
{
  flake.modules.darwin.diffnav =
    { lib, pkgs, ... }:
    let
      inherit (lib) kanagawa;
      # The old programs.delta.options, verbatim, rendered to a git-config-format
      # file that delta reads via --config (delta keys live under [delta]).
      deltaOptions = {
        syntax-theme = "ansi";
        dark = true;
        tabs = 2;

        # File headers
        file-style = "omit";
        file-decoration-style = "none";

        # Line numbers
        line-numbers = true;
        line-numbers-left-format = "{nm:>4} ";
        line-numbers-right-format = "│ {np:>4} ";
        line-numbers-left-style = "${kanagawa.sumiInk6} dim";
        line-numbers-right-style = "${kanagawa.sumiInk4} dim";
        line-numbers-zero-style = "${kanagawa.sumiInk6} dim";
        line-numbers-plus-style = "${kanagawa.sumiInk6} dim";
        line-numbers-minus-style = "${kanagawa.sumiInk6} dim";

        # Diff colors — very subtle tints on sumiInk3
        plus-style = "syntax \"${kanagawa.diffAddBg}\"";
        plus-emph-style = "syntax \"${kanagawa.diffAddEmphBg}\"";
        minus-style = "syntax \"${kanagawa.diffRemoveBg}\"";
        minus-emph-style = "syntax \"${kanagawa.diffRemoveEmphBg}\"";

        # Hunk headers
        hunk-header-style = kanagawa.fujiGray;
        hunk-header-file-style = "${kanagawa.fujiGray} dim";
        hunk-header-line-number-style = kanagawa.waveBlue1;
        hunk-header-decoration-style = "${kanagawa.sumiInk4} ol ul";

        # Wrapping
        wrap-left-symbol = " ";
        wrap-right-symbol = " ";
        wrap-right-prefix-symbol = " ";

        # Navigation — side-by-side and navigate are controlled by diffnav
      };
      deltaConfig = pkgs.writeText "delta-kanagawa.gitconfig" (
        lib.generators.toGitINI { delta = deltaOptions; }
      );
      themedDelta = pkgs.symlinkJoin {
        name = "delta-kanagawa";
        paths = [ pkgs.delta ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/delta --add-flags "--config ${deltaConfig}"
        '';
      };
    in
    {
      environment.systemPackages = [ themedDelta ];
    };
}
