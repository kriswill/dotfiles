# Kanagawa color palette for reuse across modules.
# Upstream: https://github.com/rebelot/kanagawa.nvim
#
# Custom colors (not from upstream) are marked with "custom".
{
  # Backgrounds (sumi ink)
  sumiInk0 = "#16161D";
  sumiInk1 = "#1F1F28";
  sumiInk2 = "#2A2A37";
  sumiInk3 = "#363646";
  sumiInk4 = "#54546D";

  # Foregrounds
  fujiWhite = "#DCD7BA";
  oldWhite = "#C8C093";
  fujiGray = "#727169";

  # Diff backgrounds (winter)
  winterGreen = "#2B3328";
  winterRed = "#43242B";
  winterBlue = "#252535";
  winterYellow = "#49443C";

  # Diff accents (autumn)
  autumnGreen = "#76946A";
  autumnRed = "#C34043";
  autumnYellow = "#DCA561";

  # Blues
  crystalBlue = "#7E9CD8";
  waveBlue1 = "#223249";
  waveBlue2 = "#2D4F67";

  # Custom colors — muted tints for diff backgrounds, derived from
  # sumiInk1 (#1F1F28) blended toward winterGreen/winterRed for subtlety.
  diffAddBg = "#222B26";
  diffAddEmphBg = "#2B3328";
  diffRemoveBg = "#2B2024";
  diffRemoveEmphBg = "#3A242B";
}
