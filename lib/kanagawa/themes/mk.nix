# Shared mapping from a Kanagawa flavor's semantic role tables (transcribed from
# kanagawa.nvim's lua/kanagawa/themes/*.lua) to the four sections the yazi flavor
# builder consumes:
#
#   editor  — tmTheme global editor colors (background, caret, selection, …)
#   syn     — tmTheme per-scope syntax foregrounds
#   diff    — tmTheme markup.{inserted,deleted,changed} backgrounds
#   chrome  — yazi UI element accents (mgr/mode/status/pick/which/… in flavor.toml)
#
# `ui`/`syn`/`vcs`/`diff`/`diag` are the kanagawa.nvim role tables for one flavor.
# The chrome mapping (which kanagawa role drives each yazi accent) is defined ONCE
# here and shared by the canonical wave/dragon/lotus flavors; kris overrides it.
{
  ui,
  syn,
  vcs,
  diff,
  diag,
}:
{
  editor = {
    background = ui.bg;
    foreground = ui.fg;
    caret = ui.fg_dim;
    invisibles = ui.nontext;
    lineHighlight = ui.bg_search;
    selection = ui.bg_search;
    findHighlight = ui.bg_search;
    selectionBorder = ui.bg_m1;
    gutterForeground = ui.nontext;
  };

  # kanagawa.nvim sets syn.variable = "none" (inherit fg); resolve to ui.fg here.
  syn = syn // {
    variable = ui.fg;
  };

  diff = { inherit (diff) add delete change; };

  chrome = {
    inherit (ui) fg; # borders' default, fallback file, help footer
    on_accent = ui.bg; # text drawn on a colored bg (counts, mode, find)
    bg_deep = ui.bg_m3; # deepest bg: alt mode, progress label
    status_bg = ui.bg_m3; # status bar / which-key mask
    accent = syn.fun; # primary accent: normal mode, dirs, which cand
    green = syn.string; # copy/created markers, info
    red = syn.special2; # cut/selected markers, archives
    pink = syn.number; # marked, select mode, media, tasks
    yellow = syn.identifier; # cwd, unset mode, images, warn, read perm
    blue = syn.special1; # status bar fg
    border = syn.type; # pick/input/completion/tasks borders
    teal = syn.type; # exec perm, help "on"
    peach = syn.special3; # write perm, error
    docs = diag.hint; # document filetype
    gray = ui.fg_dim; # which-key separator/rest
    faint = ui.nontext; # which-key desc, gutter find line-number
    orphan = syn.special2; # broken symlinks
    exec = vcs.added; # executable files
  };
}
