{ lib, pkgs }:

{
  manager = {
    layout = [
      1
      3
      4
    ];
    linemode = "size";
    show_hidden = true;
    show_symlink = true;
    sort_by = "alphabetical";
    sort_dir_first = true;
    sort_reverse = false;
    sort_sensitive = false;
  };

  opener = {
    edit = [
      {
        run = ''nvim "$@"'';
        desc = "$EDITOR";
        block = true;
      }
    ];
    reveal = [
      {
        run = ''${lib.getExe pkgs.exiftool} "$1"; echo "Press <enter> to exit"; read _'';
        desc = "Show EXIF";
        block = true;
        for = "unix";
      }
      {
        run = ''open -R "$1"'';
        desc = "Reveal";
        for = "macos";
      }
    ];
    extract = [
      {
        desc = "Extract with atool";
        run = ''${lib.getExe pkgs.atool} --extract --each --subdir --quiet -- "$@"'';
        block = true;
      }
      {
        desc = "Extract here";
        run = ''${lib.getExe pkgs.unrar} "$1"'';
      }
    ];
  };
  open =
    let
      archiveExtensions = [
        "7z"
        "ace"
        "ar"
        "arc"
        "bz2"
        "cab"
        "cpio"
        "cpt"
        "deb"
        "dgc"
        "dmg"
        "gz"
        "iso"
        "jar"
        "msi"
        "pkg"
        "rar"
        "shar"
        "tar"
        "tgz"
        "xar"
        "xpi"
        "xz"
        "zip"
      ];

      generateArchiveRule = ext: {
        name = "*.${ext}";
        use = [
          "extract"
          "reveal"
        ];
      };

      archiveRules = map generateArchiveRule archiveExtensions;
    in
    {
      rules = archiveRules ++ [
        {
          name = "*.dmg";
          use = [
            "dmg"
            "reveal"
          ];
        }
        {
          name = "*/";
          use = [
            "edit"
            "open"
            "reveal"
          ];
        }
        {
          mime = "text/*";
          use = [
            "edit"
            "reveal"
          ];
        }
        {
          mime = "image/*";
          use = [
            "open"
            "reveal"
          ];
        }
        {
          mime = "video/*";
          use = [
            "play"
            "reveal"
          ];
        }
        {
          mime = "audio/*";
          use = [
            "play"
            "reveal"
          ];
        }
        {
          mime = "inode/x-empty";
          use = [
            "edit"
            "reveal"
          ];
        }
        {
          mime = "application/json";
          use = [
            "edit"
            "reveal"
          ];
        }
        {
          mime = "*/javascript";
          use = [
            "edit"
            "reveal"
          ];
        }
        {
          mime = "application/zip";
          use = [
            "extract"
            "reveal"
          ];
        }
        {
          mime = "application/gzip";
          use = [
            "extract"
            "reveal"
          ];
        }
        {
          mime = "application/x-tar";
          use = [
            "extract"
            "reveal"
          ];
        }
        {
          mime = "application/x-bzip";
          use = [
            "extract"
            "reveal"
          ];
        }
        {
          mime = "application/x-bzip2";
          use = [
            "extract"
            "reveal"
          ];
        }
        {
          mime = "application/x-7z-compressed";
          use = [
            "extract"
            "reveal"
          ];
        }
        {
          mime = "application/x-rar";
          use = [
            "extract"
            "reveal"
          ];
        }
        {
          mime = "application/xz";
          use = [
            "extract"
            "reveal"
          ];
        }
        {
          mime = "*";
          use = [
            "open"
            "reveal"
          ];
        }
      ];
    };

  preview = {
    tab_size = 2;
    max_width = 600;
    max_height = 900;
    cache_dir = "";
    image_filter = "triangle";
    image_quality = 75;
    sixel_fraction = 15;
    ueberzug_scale = 1;
    ueberzug_offset = [
      0
      0
      0
      0
    ];
  };

  tasks = {
    micro_workers = 10;
    macro_workers = 25;
    bizarre_retry = 5;
    image_alloc = 536870912; # 512MB
    image_bound = [
      0
      0
    ];
    suppress_preload = false;
  };

  plugin = {
    preloaders = [
      {
        name = "*";
        cond = "!mime";
        run = "mime";
        multi = true;
        prio = "high";
      }
      # Image
      {
        mime = "image/vnd.djvu";
        run = "noop";
      }
      {
        mime = "image/*";
        run = "image";
      }
      # Video
      {
        mime = "video/*";
        run = "video";
      }
      # PDF
      {
        mime = "application/pdf";
        run = "pdf";
      }
    ];

    previewers = [
      {
        name = "*.md";
        run = "glow";
      }
      {
        mime = "text/csv";
        run = "miller";
      }
      {
        name = "*/";
        run = "folder";
        sync = true;
      }
      # Code
      {
        mime = "text/*";
        run = "code";
      }
      {
        mime = "*/xml";
        run = "code";
      }
      {
        mime = "*/javascript";
        run = "code";
      }
      {
        mime = "*/x-wine-extension-ini";
        run = "code";
      }
      # JSON
      {
        mime = "application/json";
        run = "json";
      }
      # Image
      {
        mime = "image/vnd.djvu";
        run = "noop";
      }
      {
        mime = "image/*";
        run = "image";
      }
      # Video
      {
        mime = "video/*";
        run = "video";
      }
      # PDF
      {
        mime = "application/pdf";
        run = "pdf";
      }
      # Archive
      {
        mime = "application/zip";
        run = "ouch";
      }
      {
        mime = "application/gzip";
        run = "archive";
      }
      {
        mime = "application/x-tar";
        run = "ouch";
      }
      {
        mime = "application/x-bzip";
        run = "ouch";
      }
      {
        mime = "application/x-bzip2";
        run = "ouch";
      }
      {
        mime = "application/x-7z-compressed";
        run = "ouch";
      }
      {
        mime = "application/x-rar";
        run = "ouch";
      }
      {
        mime = "application/xz";
        run = "ouch";
      }
      # Fallback
      {
        name = "*";
        run = "file";
      }
    ];
  };
  input = {
    # cd
    cd_title = "Change directory:";
    cd_origin = "top-center";
    cd_offset = [
      0
      2
      50
      3
    ];

    # create
    create_title = "Create:";
    create_origin = "top-center";
    create_offset = [
      0
      2
      50
      3
    ];

    # rename
    rename_title = "Rename:";
    rename_origin = "hovered";
    rename_offset = [
      0
      1
      50
      3
    ];

    # trash
    trash_title = "Move {n} selected file{s} to trash? (y/N)";
    trash_origin = "top-center";
    trash_offset = [
      0
      2
      50
      3
    ];

    # delete
    delete_title = "Delete {n} selected file{s} permanently? (y/N)";
    delete_origin = "top-center";
    delete_offset = [
      0
      2
      50
      3
    ];

    # filter
    filter_title = "Filter:";
    filter_origin = "top-center";
    filter_offset = [
      0
      2
      50
      3
    ];

    # find
    find_title = [
      "Find next:"
      "Find previous:"
    ];
    find_origin = "top-center";
    find_offset = [
      0
      2
      50
      3
    ];

    # search
    search_title = "Search via {n}:";
    search_origin = "top-center";
    search_offset = [
      0
      2
      50
      3
    ];

    # shell
    shell_title = [
      "Shell:"
      "Shell (block):"
    ];
    shell_origin = "top-center";
    shell_offset = [
      0
      2
      50
      3
    ];

    # overwrite
    overwrite_title = "Overwrite an existing file? (y/N)";
    overwrite_origin = "top-center";
    overwrite_offset = [
      0
      2
      50
      3
    ];

    # quit
    quit_title = "{n} task{s} running, sure to quit? (y/N)";
    quit_origin = "top-center";
    quit_offset = [
      0
      2
      50
      3
    ];
  };

  select = {
    open_title = "Open with:";
    open_origin = "hovered";
    open_offset = [
      0
      1
      50
      7
    ];
  };

  which = {
    sort_by = "none";
    sort_sensitive = false;
    sort_reverse = false;
  };

  log = {
    enabled = false;
  };
}
