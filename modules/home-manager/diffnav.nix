{
  flake.modules.homeManager.diffnav =
    {
      lib,
      config,
      ...
    }:
    let
      inherit (lib) kanagawa;
    in
    {
      options.kriswill.diffnav.enable = lib.mkEnableOption "diffnav git diff pager";

      config = lib.mkIf config.kriswill.diffnav.enable {
        # diffnav itself moved to the nix-darwin per-user profile (gated on
        # kriswill.diffnav.enable) — see modules/darwin/user-packages.nix.
        programs.delta = {
          enable = true;
          enableGitIntegration = false;
          options = {
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
        };

        programs.git.settings.pager = {
          diff = "diffnav";
          show = "diffnav";
        };
      };
    };
}
