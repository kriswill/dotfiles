# Give GUI apps the nix PATH. launchd starts Dock/Finder-launched apps with
# the bare /usr/bin:/bin:/usr/sbin:/sbin, so anything they shell out to (gh
# for Claude Code desktop's CI monitoring, git for editors) is invisible when
# it lives only in a nix profile. Setting the user-domain launchd PATH at
# activation fixes every GUI app at once; apps must be relaunched to see it.
# Companion shim: home/zsh/.zshrc feeds the same PATH to apps that probe
# ~/.zshrc instead of trusting their inherited environment.
{
  flake.modules.darwin.gui-path =
    { config, ... }:
    {
      # A list value is joined with colons by the option itself.
      launchd.user.envVariables.PATH = [
        "/Users/${config.system.primaryUser}/.nix-profile/bin"
        "/etc/profiles/per-user/${config.system.primaryUser}/bin"
        "/run/current-system/sw/bin"
        "/nix/var/nix/profiles/default/bin"
        "/usr/local/bin"
        "/usr/bin"
        "/bin"
        "/usr/sbin"
        "/sbin"
      ];
    };
}
