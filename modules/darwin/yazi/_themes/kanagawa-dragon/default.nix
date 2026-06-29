# Kanagawa-Dragon flavor for Yazi, generated from the shared palette.
#
# Both files yazi expects in a `<name>.yazi/` flavor dir — `flavor.toml`
# (the UI theme) and `tmtheme.xml` (the syntect tmTheme used for syntax/diff
# previews) — are produced here from `lib.kanagawa` so every color has a
# single source of truth (lib/kanagawa.nix). The dragon palette uses the
# `dragon*` entries; a few non-dragon accents (waveRed, carpYellow, …) match
# upstream rebelot/kanagawa.nvim.
#
# Attribution: ported from the MIT-licensed
# https://github.com/marcosvnmelo/kanagawa-dragon.yazi
{ lib, pkgs, ... }:
let
  k = lib.kanagawa;

  flavorAttrs = {
    mgr = {
      marker_copied = {
        fg = k.dragonGreen2;
        bg = k.dragonGreen2;
      };
      marker_cut = {
        fg = k.waveRed;
        bg = k.waveRed;
      };
      marker_marked = {
        fg = k.dragonPink;
        bg = k.dragonPink;
      };
      marker_selected = {
        fg = k.waveRed;
        bg = k.waveRed;
      };

      cwd = {
        fg = k.carpYellow;
      };
      hovered = {
        reversed = true;
      };
      preview_hovered = {
        reversed = true;
      };

      find_keyword = {
        fg = k.waveRed;
        bg = k.dragonBlack3;
      };
      find_position = { };

      count_copied = {
        fg = k.dragonBlack3;
        bg = k.dragonGreen2;
      };
      count_cut = {
        fg = k.dragonBlack3;
        bg = k.waveRed;
      };
      count_selected = {
        fg = k.dragonBlack3;
        bg = k.carpYellow;
      };

      border_symbol = "│";
      border_style = {
        fg = k.dragonWhite;
      };
    };

    mode = {
      normal_main = {
        fg = k.dragonBlack3;
        bg = k.dragonBlue2;
      };
      normal_alt = {
        fg = k.dragonBlue2;
        bg = k.dragonBlack0;
      };
      select_main = {
        fg = k.dragonBlack3;
        bg = k.dragonPink;
      };
      select_alt = {
        fg = k.dragonPink;
        bg = k.dragonBlack0;
      };
      unset_main = {
        fg = k.dragonBlack3;
        bg = k.carpYellow;
      };
      unset_alt = {
        fg = k.carpYellow;
        bg = k.dragonBlack0;
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
        fg = k.springBlue;
        bg = k.sumiInk0;
      };

      progress_label = {
        fg = k.dragonBlue2;
        bg = k.dragonBlack0;
        bold = true;
      };
      progress_normal = {
        fg = k.dragonBlack0;
        bg = k.dragonBlack3;
      };
      progress_error = {
        fg = k.dragonBlack0;
        bg = k.dragonBlack3;
      };

      perm_type = {
        fg = k.dragonGreen2;
      };
      perm_read = {
        fg = k.carpYellow;
      };
      perm_write = {
        fg = k.peachRed;
      };
      perm_exec = {
        fg = k.waveAqua2;
      };
      perm_sep = {
        fg = k.dragonPink;
      };
    };

    pick = {
      border = {
        fg = k.dragonAqua;
      };
      active = {
        fg = k.dragonPink;
        bold = true;
      };
      inactive = { };
    };

    input = {
      border = {
        fg = k.dragonAqua;
      };
      title = { };
      value = { };
      selected = {
        reversed = true;
      };
    };

    completion = {
      border = {
        fg = k.dragonAqua;
      };
      active = {
        reversed = true;
      };
      inactive = { };
    };

    tasks = {
      border = {
        fg = k.dragonAqua;
      };
      title = { };
      hovered = {
        fg = k.dragonPink;
      };
    };

    which = {
      cols = 2;
      separator = " - ";
      separator_style = {
        fg = k.dragonGray;
      };
      mask = {
        bg = k.sumiInk0;
      };
      rest = {
        fg = k.dragonGray;
      };
      cand = {
        fg = k.dragonBlue2;
      };
      desc = {
        fg = k.sumiInk6;
      };
    };

    help = {
      on = {
        fg = k.waveAqua2;
      };
      run = {
        fg = k.dragonPink;
      };
      desc = { };
      hovered = {
        reversed = true;
        bold = true;
      };
      footer = {
        fg = k.dragonBlack3;
        bg = k.dragonWhite;
      };
    };

    notify = {
      title_info = {
        fg = k.dragonGreen2;
      };
      title_warn = {
        fg = k.carpYellow;
      };
      title_error = {
        fg = k.peachRed;
      };
    };

    # Order matters — yazi applies the first matching rule.
    filetype.rules = [
      # images
      {
        mime = "image/*";
        fg = k.carpYellow;
      }
      # media
      {
        mime = "{audio,video}/*";
        fg = k.dragonPink;
      }
      # archives
      {
        mime = "application/{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}";
        fg = k.waveRed;
      }
      # documents
      {
        mime = "application/{pdf,doc,rtf,vnd.*}";
        fg = k.waveAqua1;
      }
      # broken links
      {
        url = "*";
        is = "orphan";
        fg = k.dragonRed;
      }
      # executables
      {
        url = "*";
        is = "exec";
        fg = k.autumnGreen;
      }
      # fallback
      {
        url = "*";
        fg = k.dragonWhite;
      }
      {
        url = "*/";
        fg = k.dragonBlue2;
      }
    ];

    tabs = {
      active = {
        reversed = true;
      };
      inactive = { };
    };
  };

  # tmTheme (syntect) — global colors plus per-scope rules. The first
  # `settings` entry holds the editor-wide colors; the rest are scoped.
  #
  # Syntax token colors mirror the kanagawa.nvim **wave** `syn` table (the
  # theme the user's neovim loads), so yazi's syntect previews match neovim's
  # treesitter highlighting rather than the upstream dragon tmtheme's choices.
  tmthemeAttrs = {
    name = "Kanagawa Dragon";
    settings = [
      {
        settings = {
          background = k.sumiInk3;
          caret = k.oldWhite;
          foreground = k.fujiWhite; # wave ui.fg
          invisibles = k.sumiInk6;
          lineHighlight = k.waveBlue2;
          selection = k.waveBlue2;
          findHighlight = k.waveBlue2;
          selectionBorder = k.dragonBlack2; # closest palette match to #222218
          gutterForeground = k.sumiInk6;
        };
      }
      {
        name = "Comment";
        scope = "comment";
        settings.foreground = k.fujiGray; # wave syn.comment
      }
      {
        name = "String";
        scope = "string";
        settings.foreground = k.springGreen; # wave syn.string
      }
      {
        name = "Number";
        scope = "constant.numeric";
        settings.foreground = k.sakuraPink; # wave syn.number
      }
      {
        name = "Built-in constant";
        scope = "constant.language";
        settings.foreground = k.surimiOrange; # wave syn.constant
      }
      {
        name = "User-defined constant";
        scope = "constant.character, constant.other";
        settings.foreground = k.surimiOrange; # wave syn.constant
      }
      {
        name = "Variable";
        scope = "variable";
        settings.foreground = k.fujiWhite; # wave syn.variable = fg
      }
      {
        name = "Ruby's @variable";
        scope = "variable.other.readwrite.instance";
        settings.foreground = k.fujiWhite;
      }
      {
        name = "String interpolation";
        scope = "constant.character.escaped, constant.character.escape, string source, string source.ruby";
        settings.foreground = k.springBlue; # wave syn.special1
      }
      {
        name = "Keyword";
        scope = "keyword";
        settings.foreground = k.oniViolet; # wave syn.keyword
      }
      {
        name = "Operator";
        scope = "keyword.operator";
        settings.foreground = k.boatYellow2; # wave syn.operator
      }
      {
        name = "Storage";
        scope = "storage";
        settings.foreground = k.oniViolet; # wave syn.keyword
      }
      {
        name = "Storage type";
        scope = "storage.type";
        settings.foreground = k.waveAqua2; # wave syn.type
      }
      {
        name = "Class name";
        scope = "entity.name.class";
        settings.foreground = k.waveAqua2; # wave syn.type
      }
      {
        name = "Inherited class";
        scope = "entity.other.inherited-class";
        settings.foreground = k.waveAqua2;
      }
      {
        name = "Function name";
        scope = "entity.name.function";
        settings.foreground = k.crystalBlue; # wave syn.fun
      }
      {
        name = "Function argument";
        scope = "variable.parameter";
        settings.foreground = k.oniViolet2; # wave syn.parameter
      }
      {
        name = "Tag name";
        scope = "entity.name.tag";
        settings.foreground = k.springBlue; # wave syn.special1
      }
      {
        name = "Tag attribute";
        scope = "entity.other.attribute-name";
        settings.foreground = k.carpYellow; # wave syn.identifier
      }
      {
        name = "Library function";
        scope = "support.function";
        settings.foreground = k.crystalBlue; # wave syn.fun
      }
      {
        name = "Library constant";
        scope = "support.constant";
        settings.foreground = k.surimiOrange; # wave syn.constant
      }
      {
        name = "Library class/type";
        scope = "support.type, support.class";
        settings.foreground = k.waveAqua2; # wave syn.type
      }
      {
        name = "Library variable";
        scope = "support.other.variable";
        settings.foreground = k.fujiWhite; # wave syn.variable = fg
      }
      {
        name = "Invalid";
        scope = "invalid";
        settings.foreground = k.peachRed; # wave syn.special3
      }
      {
        name = "Invalid deprecated";
        scope = "invalid.deprecated";
        settings.foreground = k.katanaGray; # wave syn.deprecated
      }
      {
        name = "JSON key";
        scope = "meta.structure.dictionary.json string.quoted.double.json";
        settings.foreground = k.carpYellow; # wave syn.identifier (@property)
      }
      {
        name = "diff.header";
        scope = "meta.diff, meta.diff.header";
        settings.foreground = k.springBlue; # wave syn.special1
      }
      {
        name = "diff.deleted";
        scope = "markup.deleted";
        settings.background = k.winterRed; # wave diff.delete
      }
      {
        name = "diff.inserted";
        scope = "markup.inserted";
        settings.background = k.winterGreen; # wave diff.add
      }
      {
        name = "diff.changed";
        scope = "markup.changed";
        settings.background = k.winterBlue; # wave diff.change
      }
      {
        scope = "constant.numeric.line-number.find-in-files - match";
        settings.foreground = k.sumiInk6;
      }
      {
        scope = "entity.name.filename";
        settings.foreground = k.oldWhite;
      }
      {
        scope = "message.error";
        settings.foreground = k.peachRed; # wave syn.special3
      }
      {
        name = "JSON Punctuation";
        scope = "punctuation.definition.string.begin.json - meta.structure.dictionary.value.json, punctuation.definition.string.end.json - meta.structure.dictionary.value.json";
        settings.foreground = k.springViolet2; # wave syn.punct
      }
      {
        name = "JSON Structure";
        scope = "meta.structure.dictionary.json string.quoted.double.json";
        settings.foreground = k.carpYellow; # wave syn.identifier (@property)
      }
      {
        name = "JSON value string";
        scope = "meta.structure.dictionary.value.json string.quoted.double.json";
        settings.foreground = k.springGreen; # wave syn.string
      }
      {
        name = "Escape Characters";
        scope = "constant.character.escape";
        settings.foreground = k.springBlue; # wave syn.special1
      }
      {
        name = "Regular Expressions";
        scope = "string.regexp";
        settings.foreground = k.boatYellow2; # wave syn.regex
      }
    ];
    uuid = "592FC036-6BB7-4676-A2F5-2894D48C8E33";
    colorSpaceName = "sRGB";
    semanticClass = "theme.dark.kanagawa-dragon";
  };

  tomlFile = (pkgs.formats.toml { }).generate "flavor.toml" flavorAttrs;
  xmlFile = pkgs.writeText "tmtheme.xml" (lib.generators.toPlist { escape = true; } tmthemeAttrs);
in
pkgs.runCommand "yazi-kanagawa-dragon-flavor" { } ''
  mkdir -p $out
  cp ${tomlFile} $out/flavor.toml
  cp ${xmlFile}  $out/tmtheme.xml
''
