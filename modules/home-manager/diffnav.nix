{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib) kanagawa;
in
{
  options.kriswill.diffnav.enable = lib.mkEnableOption "diffnav git diff pager";

  config = lib.mkIf config.kriswill.diffnav.enable {
    home.packages = [ pkgs.diffnav ];

    programs.delta = {
      enable = true;
      enableGitIntegration = config.programs.git.enable;
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
        line-numbers-left-style = "${kanagawa.sumiInk4} dim";
        line-numbers-right-style = "${kanagawa.sumiInk2} dim";
        line-numbers-zero-style = "${kanagawa.sumiInk4} dim";
        line-numbers-plus-style = "${kanagawa.sumiInk4} dim";
        line-numbers-minus-style = "${kanagawa.sumiInk4} dim";

        # Diff colors — very subtle tints on sumiInk1
        plus-style = "syntax \"${kanagawa.diffAddBg}\"";
        plus-emph-style = "syntax \"${kanagawa.diffAddEmphBg}\"";
        minus-style = "syntax \"${kanagawa.diffRemoveBg}\"";
        minus-emph-style = "syntax \"${kanagawa.diffRemoveEmphBg}\"";

        # Hunk headers
        hunk-header-style = kanagawa.fujiGray;
        hunk-header-file-style = "${kanagawa.fujiGray} dim";
        hunk-header-line-number-style = kanagawa.waveBlue1;
        hunk-header-decoration-style = "${kanagawa.sumiInk2} ol ul";

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
}
