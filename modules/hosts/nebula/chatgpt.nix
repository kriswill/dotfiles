{
  # ChatGPT desktop app: ChatGPT and Codex in one Electron app, OpenAI's Linux
  # preview (since 2026-08). OpenAI ships only .deb/.rpm/Arch builds, each of
  # which adds OpenAI's signed package repo, and the app has no updater of its
  # own on Linux. nixpkgs' package unpacks the .deb, so new versions arrive
  # with the flake's nixpkgs bump (nixpkgs trails OpenAI by about a week).
  #
  # The app runs nixpkgs' `codex` (linked over its bundled copy), not the
  # standalone, self-updating CLI in ~/.local/bin. Both share ~/.codex.
  # `pkgs.chatgpt.override { codex = null; }` switches the app to the codex
  # OpenAI bundled with it.
  #
  # Native Wayland: the launcher adds --ozone-platform=wayland when
  # NIXOS_OZONE_WL is set, which snowglobe does. OpenAI calls native Wayland
  # experimental (window positioning, focus and shortcuts may misbehave).
  #
  # Its desktop entry also claims CSV and Office documents. Without explicit
  # defaults, .docx/.pptx would open in ChatGPT instead of LibreOffice, so
  # home/mimeapps/.config/mimeapps.list pins those types to LibreOffice.
  configurations.nixos.nebula.module =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.chatgpt ];

      # The launcher copies the bundled plugins to
      # ~/.cache/chatgpt/bundled-plugins-v2/<store hash>, a new copy for every
      # version. The package ships a user-tmpfiles rule that prunes the copies
      # no running app holds a lock on, but NixOS doesn't read packages'
      # share/user-tmpfiles.d. /etc/xdg is on the user manager's
      # XDG_CONFIG_DIRS, where `systemd-tmpfiles --user` (the daily
      # systemd-tmpfiles-clean.timer) finds it.
      environment.etc."xdg/user-tmpfiles.d/chatgpt.conf".source =
        "${pkgs.chatgpt}/share/user-tmpfiles.d/chatgpt.conf";
    };
}
