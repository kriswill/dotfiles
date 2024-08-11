{ self
, inputs
, lib
, ...
}:

{
  default = lib.composeManyExtensions [
    inputs.nur.overlay
    (
      # attach nixpkgs-unstable to pkgs.unstable
      final: _prev: {
        unstable = import inputs.nixpkgs-unstable {
          inherit (final) system;
          config.allowUnfree = true;
        };
      }
    )
    (final: _prev: {
      trunk = import inputs.nixpkgs-trunk {
        inherit (final) system;
        config.allowUnfree = true;
      };
    })
    (_final: prev: {
      xdg-desktop-portal-gtk =
        (prev.xdg-desktop-portal-gtk.overrideAttrs {
          postInstall = ''
            sed -i 's/UseIn=gnome/UseIn=gnome;Hyprland;none+i3/' $out/share/xdg-desktop-portal/portals/gtk.portal
          '';
        })
        # resolves conflicting builds when Gnome is also enabled
        .override
          { buildPortalsInGnome = false; };
    })
    (_final: _prev: { wallpapers = import ../packages/shared/wallpapers.nix; })
    (_final: prev: { inherit (self.packages.${prev.system}) bibata-hyprcursor; })
    (_final: prev: { inherit (self.packages.${prev.system}) distro-grub-themes-nixos; })
  ];
}
