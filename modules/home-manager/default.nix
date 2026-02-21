{
  lib,
  config,
  pkgs,
  ...
}:
let
  # Custom sqlite with loadable extension support for sqlite-vec and qmd
  sqliteWithExtensions = pkgs.sqlite.overrideAttrs (old: {
    env = (old.env or { }) // {
      NIX_CFLAGS_COMPILE = (old.env.NIX_CFLAGS_COMPILE or "") + " -DSQLITE_ENABLE_LOAD_EXTENSION=1";
    };
  });
in
{
  imports = lib.autoImport ./.;
  options.kriswill.enable = lib.mkEnableOption "Kris' home module";
  config = lib.mkIf config.kriswill.enable {
    kriswill = {
      mkalias.enable = lib.mkDefault true;
      fastfetch.enable = lib.mkDefault true;
      # firefox.enable = lib.mkDefault false;
      # kitty.enable = lib.mkDefault false;
      neovim.enable = lib.mkDefault true;
      tmux.enable = lib.mkDefault true;
      ghostty.enable = lib.mkDefault true;
      karabiner.enable = lib.mkDefault true;
      # brave.enable = lib.mkDefault false;
      zsh.enable = lib.mkDefault true;
      git.enable = lib.mkDefault true;
      ssh.enable = lib.mkDefault true;
      starship.enable = lib.mkDefault true;
      yazi.enable = lib.mkDefault true;
      glow.enable = lib.mkDefault true;
      zk.enable = lib.mkDefault true;
      # vscode.enable = lib.mkDefault false;
    };
    home.packages = with pkgs; [
      age # encryption tool
      bun
      btop
      comma # https://github.com/nix-community/comma
      fd # file finding
      figlet # text to big fancy letters in ASCII
      go # an awesome language
      grc # generic text colorizer
      gnupg # signature verifier
      jq # json querying
      just # better make
      keycastr # keystroke visualizer
      kitten # kitty utilities (icat, diff, themes, etc.)
      localsend # share files with other devices on the local network
      # mactop
      ncdu # analyze disk usage
      nix-index # local database of nixpkgs
      nix-output-monitor # better visual output for nix builds
      nix-tree # analyze disk usage by nix packages
      nodejs_24
      ripgrep # fast grep replacement
      sqliteWithExtensions
      sqlite-vec
      tldr # simplified man pages
      tree # print directory trees
      uv # one python tool to rule them all!
      yamlfmt # format yaml
      # You can also create simple shell scripts directly inside your
      # configuration. For example, this adds a command 'my-hello' to your
      # environment:
      (writeShellScriptBin "my-hello" ''
        echo "Hello, ${config.home.username}!"
      '')
    ];
    home.sessionVariables =
      let
        neovim = "${lib.getExe pkgs.neovim}";
      in
      {
        EDITOR = neovim;
        VISUAL = neovim;
        MANPAGER = "${neovim} +Man!";
        BREW_PREFIX = "${sqliteWithExtensions.out}"; # qmd looks for ${BREW_PREFIX}/lib/libsqlite3.dylib
      };
    programs = {
      bat.enable = lib.mkDefault true;
      jq.enable = lib.mkDefault true;
      nix-index.enable = lib.mkDefault true;
      # obs-studio.enable = true; # not on mac
      lazygit.enable = lib.mkDefault true;
      rmpc.enable = lib.mkDefault true;

      hstr = {
        enable = lib.mkDefault true;
        enableZshIntegration = lib.mkDefault true;
      };

      direnv = {
        enable = lib.mkDefault true;
        nix-direnv.enable = lib.mkDefault true;
      };

      fzf = {
        enable = lib.mkDefault true;
        # enableZshIntegration = lib.mkDefault true;

        defaultCommand = "fd --type f";
        defaultOptions = [
          "--height 40%"
          "--prompt ⟫"
        ];

        changeDirWidgetCommand = "fd --type d";
        changeDirWidgetOptions = [
          "--preview 'tree -C {} | head -200'"
        ];
      };

      htop = {
        enable = lib.mkDefault true;
        settings = {
          sort_direction = true;
          sort_key = "PERCENT_CPU";
          show_program_path = false;
        };
      };

      zoxide = {
        enable = lib.mkDefault true;
        enableZshIntegration = true;
        options = [
          "--cmd"
          "j"
        ];
      };

    };
  };
}
