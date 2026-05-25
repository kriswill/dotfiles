# Reusable builder for a Yazi Kanagawa flavor. Produces the two files yazi
# expects in a `<name>.yazi/` flavor dir — `flavor.toml` (the UI theme) and
# `tmtheme.xml` (the syntect tmTheme used for syntax/diff previews) — from a
# semantic `theme` table (see lib/kanagawa/themes/*). Every color has a single
# source of truth (lib/kanagawa), so the four flavors share one layout and
# differ only by their palette.
#
# Attribution: layout originally ported from the MIT-licensed
# https://github.com/marcosvnmelo/kanagawa-dragon.yazi
{
  lib,
  pkgs,
  name, # flavor dir name, e.g. "kanagawa-kris"
  title, # tmTheme display name, e.g. "Kanagawa Kris"
  uuid, # stable tmTheme uuid (distinct per flavor)
  appearance ? "dark", # "dark" | "light" — tmTheme semanticClass only
  theme, # { editor, syn, diff, chrome } from lib.kanagawa.themes.<flavor>
}:
let
  c = theme.chrome;
  s = theme.syn;
  e = theme.editor;
  d = theme.diff;

  flavorAttrs = {
    mgr = {
      marker_copied = {
        fg = c.green;
        bg = c.green;
      };
      marker_cut = {
        fg = c.red;
        bg = c.red;
      };
      marker_marked = {
        fg = c.pink;
        bg = c.pink;
      };
      marker_selected = {
        fg = c.red;
        bg = c.red;
      };

      cwd = {
        fg = c.yellow;
      };
      hovered = {
        reversed = true;
      };
      preview_hovered = {
        reversed = true;
      };

      find_keyword = {
        fg = c.red;
        bg = c.on_accent;
      };
      find_position = { };

      count_copied = {
        fg = c.on_accent;
        bg = c.green;
      };
      count_cut = {
        fg = c.on_accent;
        bg = c.red;
      };
      count_selected = {
        fg = c.on_accent;
        bg = c.yellow;
      };

      border_symbol = "│";
      border_style = {
        inherit (c) fg;
      };
    };

    mode = {
      normal_main = {
        fg = c.on_accent;
        bg = c.accent;
      };
      normal_alt = {
        fg = c.accent;
        bg = c.bg_deep;
      };
      select_main = {
        fg = c.on_accent;
        bg = c.pink;
      };
      select_alt = {
        fg = c.pink;
        bg = c.bg_deep;
      };
      unset_main = {
        fg = c.on_accent;
        bg = c.yellow;
      };
      unset_alt = {
        fg = c.yellow;
        bg = c.bg_deep;
      };
    };

    status = {
      sep_left = {
        open = "";
        close = "";
      };
      sep_right = {
        open = "";
        close = "";
      };
      overall = {
        fg = c.blue;
        bg = c.status_bg;
      };

      progress_label = {
        fg = c.accent;
        bg = c.bg_deep;
        bold = true;
      };
      progress_normal = {
        fg = c.bg_deep;
        bg = c.on_accent;
      };
      progress_error = {
        fg = c.bg_deep;
        bg = c.on_accent;
      };

      perm_type = {
        fg = c.green;
      };
      perm_read = {
        fg = c.yellow;
      };
      perm_write = {
        fg = c.peach;
      };
      perm_exec = {
        fg = c.teal;
      };
      perm_sep = {
        fg = c.pink;
      };
    };

    pick = {
      border = {
        fg = c.border;
      };
      active = {
        fg = c.pink;
        bold = true;
      };
      inactive = { };
    };

    input = {
      border = {
        fg = c.border;
      };
      title = { };
      value = { };
      selected = {
        reversed = true;
      };
    };

    completion = {
      border = {
        fg = c.border;
      };
      active = {
        reversed = true;
      };
      inactive = { };
    };

    tasks = {
      border = {
        fg = c.border;
      };
      title = { };
      hovered = {
        fg = c.pink;
      };
    };

    which = {
      cols = 2;
      separator = " - ";
      separator_style = {
        fg = c.gray;
      };
      mask = {
        bg = c.status_bg;
      };
      rest = {
        fg = c.gray;
      };
      cand = {
        fg = c.accent;
      };
      desc = {
        fg = c.faint;
      };
    };

    help = {
      on = {
        fg = c.teal;
      };
      run = {
        fg = c.pink;
      };
      desc = { };
      hovered = {
        reversed = true;
        bold = true;
      };
      footer = {
        fg = c.on_accent;
        bg = c.fg;
      };
    };

    notify = {
      title_info = {
        fg = c.green;
      };
      title_warn = {
        fg = c.yellow;
      };
      title_error = {
        fg = c.peach;
      };
    };

    # Order matters — yazi applies the first matching rule.
    filetype.rules = [
      # images
      {
        mime = "image/*";
        fg = c.yellow;
      }
      # media
      {
        mime = "{audio,video}/*";
        fg = c.pink;
      }
      # archives
      {
        mime = "application/{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}";
        fg = c.red;
      }
      # documents
      {
        mime = "application/{pdf,doc,rtf,vnd.*}";
        fg = c.docs;
      }
      # broken links
      {
        url = "*";
        is = "orphan";
        fg = c.orphan;
      }
      # executables
      {
        url = "*";
        is = "exec";
        fg = c.exec;
      }
      # fallback
      {
        url = "*";
        inherit (c) fg;
      }
      {
        url = "*/";
        fg = c.accent;
      }
    ];

    tabs = {
      active = {
        reversed = true;
      };
      inactive = { };
    };
  };

  # tmTheme (syntect) — global editor colors plus per-scope rules. The first
  # `settings` entry holds the editor-wide colors; the rest are scoped. Syntax
  # token colors come from the flavor's `syn` table so yazi's syntect previews
  # match the matching kanagawa.nvim variant.
  tmthemeAttrs = {
    name = title;
    settings = [
      {
        settings = {
          inherit (e)
            background
            caret
            foreground
            invisibles
            lineHighlight
            selection
            findHighlight
            selectionBorder
            gutterForeground
            ;
        };
      }
      {
        name = "Comment";
        scope = "comment";
        settings.foreground = s.comment;
      }
      {
        name = "String";
        scope = "string";
        settings.foreground = s.string;
      }
      {
        name = "Number";
        scope = "constant.numeric";
        settings.foreground = s.number;
      }
      {
        name = "Built-in constant";
        scope = "constant.language";
        settings.foreground = s.constant;
      }
      {
        name = "User-defined constant";
        scope = "constant.character, constant.other";
        settings.foreground = s.constant;
      }
      {
        name = "Variable";
        scope = "variable";
        settings.foreground = s.variable;
      }
      {
        name = "Ruby's @variable";
        scope = "variable.other.readwrite.instance";
        settings.foreground = s.variable;
      }
      {
        name = "String interpolation";
        scope = "constant.character.escaped, constant.character.escape, string source, string source.ruby";
        settings.foreground = s.special1;
      }
      {
        name = "Keyword";
        scope = "keyword";
        settings.foreground = s.keyword;
      }
      {
        name = "Operator";
        scope = "keyword.operator";
        settings.foreground = s.operator;
      }
      {
        name = "Storage";
        scope = "storage";
        settings.foreground = s.keyword;
      }
      {
        name = "Storage type";
        scope = "storage.type";
        settings.foreground = s.type;
      }
      {
        name = "Class name";
        scope = "entity.name.class";
        settings.foreground = s.type;
      }
      {
        name = "Inherited class";
        scope = "entity.other.inherited-class";
        settings.foreground = s.type;
      }
      {
        name = "Function name";
        scope = "entity.name.function";
        settings.foreground = s.fun;
      }
      {
        name = "Function argument";
        scope = "variable.parameter";
        settings.foreground = s.parameter;
      }
      {
        name = "Tag name";
        scope = "entity.name.tag";
        settings.foreground = s.special1;
      }
      {
        name = "Tag attribute";
        scope = "entity.other.attribute-name";
        settings.foreground = s.identifier;
      }
      {
        name = "Library function";
        scope = "support.function";
        settings.foreground = s.fun;
      }
      {
        name = "Library constant";
        scope = "support.constant";
        settings.foreground = s.constant;
      }
      {
        name = "Library class/type";
        scope = "support.type, support.class";
        settings.foreground = s.type;
      }
      {
        name = "Library variable";
        scope = "support.other.variable";
        settings.foreground = s.variable;
      }
      {
        name = "Invalid";
        scope = "invalid";
        settings.foreground = s.special3;
      }
      {
        name = "Invalid deprecated";
        scope = "invalid.deprecated";
        settings.foreground = s.deprecated;
      }
      {
        name = "JSON key";
        scope = "meta.structure.dictionary.json string.quoted.double.json";
        settings.foreground = s.identifier;
      }
      {
        name = "diff.header";
        scope = "meta.diff, meta.diff.header";
        settings.foreground = s.special1;
      }
      {
        name = "diff.deleted";
        scope = "markup.deleted";
        settings.background = d.delete;
      }
      {
        name = "diff.inserted";
        scope = "markup.inserted";
        settings.background = d.add;
      }
      {
        name = "diff.changed";
        scope = "markup.changed";
        settings.background = d.change;
      }
      {
        scope = "constant.numeric.line-number.find-in-files - match";
        settings.foreground = e.gutterForeground;
      }
      {
        scope = "entity.name.filename";
        settings.foreground = e.caret;
      }
      {
        scope = "message.error";
        settings.foreground = s.special3;
      }
      {
        name = "JSON Punctuation";
        scope = "punctuation.definition.string.begin.json - meta.structure.dictionary.value.json, punctuation.definition.string.end.json - meta.structure.dictionary.value.json";
        settings.foreground = s.punct;
      }
      {
        name = "JSON Structure";
        scope = "meta.structure.dictionary.json string.quoted.double.json";
        settings.foreground = s.identifier;
      }
      {
        name = "JSON value string";
        scope = "meta.structure.dictionary.value.json string.quoted.double.json";
        settings.foreground = s.string;
      }
      {
        name = "Escape Characters";
        scope = "constant.character.escape";
        settings.foreground = s.special1;
      }
      {
        name = "Regular Expressions";
        scope = "string.regexp";
        settings.foreground = s.regex;
      }
    ];
    inherit uuid;
    colorSpaceName = "sRGB";
    semanticClass = "theme.${appearance}.${name}";
  };

  tomlFile = (pkgs.formats.toml { }).generate "flavor.toml" flavorAttrs;
  xmlFile = pkgs.writeText "tmtheme.xml" (lib.generators.toPlist { escape = true; } tmthemeAttrs);
in
pkgs.runCommand "yazi-${name}-flavor" { } ''
  mkdir -p $out
  cp ${tomlFile} $out/flavor.toml
  cp ${xmlFile}  $out/tmtheme.xml
''
