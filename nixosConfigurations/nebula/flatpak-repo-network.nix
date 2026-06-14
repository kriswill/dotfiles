{
  # snowglobe-lib's desktop module defines a `flatpak-repo` oneshot that runs
  # `flatpak remote-add flathub …` at boot, but wires it only to
  # multi-user.target with no network ordering (see snowglobe
  # nixosModules/snowglobe-lib/desktop.nix). So it fires before NetworkManager
  # has DNS up and dies with "Could not resolve hostname dl.flathub.org",
  # leaving a failed unit (and a scary line on the greeter).
  #
  # These attrs merge into snowglobe's definition (systemd unit list options
  # concatenate), gating the unit on the network actually being online.
  # network-online.target is satisfied by NetworkManager-wait-online, which is
  # enabled by default whenever NetworkManager is on.
  systemd.services.flatpak-repo = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}
