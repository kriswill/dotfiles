{
  # Keep the ASTRO MixAmp Pro (headset) as the default sink/source when a
  # suspend/resume renames it.
  #
  # On resume the Promontory 21 xHCI controllers reinit ("xHC error in resume,
  # USBSTS 0x411, Reinit") and the MixAmp can re-enumerate twice in a row. The
  # second card appears before the first is torn down, so WirePlumber's alsa
  # monitor deduplicates the device name — alsa_card.usb-Astro_…-00 → …-00.2 —
  # and every node name inherits it (alsa_output.usb-Astro_…-00.2.analog-stereo).
  # The configured default (and the default-nodes history in
  # ~/.local/state/wireplumber/default-nodes) stores the un-suffixed name, so
  # neither matches; selection falls through to the highest priority.session,
  # which was the motherboard Generic USB Audio pro-audio nodes (sink 1600 /
  # source 2600 vs MixAmp 1109 / 2100). Discord then captured from an empty
  # motherboard jack (2026-10-02).
  #
  # Raising the MixAmp nodes above those makes the fallback land on it whatever
  # its suffix. Priority only matters when the configured default is missing, so
  # explicit default choices still win. Live recovery without this rule:
  # `systemctl --user restart wireplumber` (recreates the nodes un-suffixed).
  configurations.nixos.nebula.module = {
    services.pipewire.wireplumber.extraConfig."51-astro-mixamp-priority" = {
      "monitor.alsa.rules" = [
        {
          matches = [
            { "node.name" = "~alsa_(input|output)\\.usb-Astro_Gaming_Inc\\._ASTRO_MixAmp_Pro-.*"; }
          ];
          actions.update-props."priority.session" = 3000;
        }
      ];
    };
  };
}
