{ pkgs, ... }:
{

  imports = [
    ./nvim
    ./zsh
  ];

  environment = {
    systemPackages =
      with pkgs.unstable;
      [
        bat # cat clone with wings.
        curl # a network utility to retrieve files from the Web
        dua # disk Usage Analyzer
        duf # disk usage utility
        eza # better ls
        fd # simple, fast and user-friendly alternative to find
        fzf # command-line fuzzy finder
        gh # github cli
        git # the stupid content tracker
        gnumake # old-shcool build tool
        hstr # bash and Zsh shell history suggest box
        htop # interactive process viewer
        hyperfine # benchmarks
        inxi # system information script
        lshw # list hardware
        lsof # list of open files
        ncdu # disk usage analyzer with an ncurses interface
        nix-info # display Nix system information
        nvd # nix package version diff tool
        pciutils # pci bus related utilities
        ripgrep # better grep
        sysz # systemd browsing tool
        tldr # short man pages
        usbutils # usb Device Utilities
        wget # network utility to retrieve files from the Web
        zoxide # cd with memory
        tcpdump # Network sniffer
        psmisc # killall, pstree, fuser, etc -- https://gitlab.com/psmisc/psmisc
      ]
      ++ (with pkgs.unstable.bat-extras; [
        batdiff # nice diffs
        batgrep # ripgrep with wings
        batman # man pages using bat
        batpipe # less preprocessor
      ]);
    extraInit = ''
      # No option to unset in NixOS
      unset SSH_ASKPASS
    '';
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs = {
    nh = {
      enable = true;
      # this doesn't work?
      # flake = "/home/k/src/github/kriswill/dotfiles";
      clean.enable = true;
      clean.extraArgs = "--keep-since 4d --keep 5";
    };
    mtr.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    dconf.enable = true;
    starship.enable = true;
    _1password.enable = true;
    _1password-gui.enable = true;
  };

  programs.less = {
    # Dealing with a large text file page by page, resulting in fast loading speeds.
    enable = true;
    lessopen = null;
  };
  environment.variables =
    let
      common = [
        "--RAW-CONTROL-CHARS" # Only allow colors.
        "--mouse"
        "--wheel-lines=5"
        "--LONG-PROMPT"
      ];
    in
    {
      PAGER = "less";
      # Don't use `programs.less.envVariables.LESS`, which will be override by `LESS` set by `man`.
      LESS = pkgs.lib.concatStringsSep " " common;
      SYSTEMD_LESS = pkgs.lib.concatStringsSep " " (
        common
        ++ [
          "--quit-if-one-screen"
          "--chop-long-lines"
          "--no-init" # Keep content after quit.
        ]
      );
    };
}
