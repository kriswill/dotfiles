# Shell-agnostic plumbing under nebula's integrated Wayland desktop shell.
#
# Whichever shell is active — Dux Shell (dux-shell.nix, current) or Noctalia
# (noctalia.nix, disabled) — needs the same system pieces underneath, so they
# live here and switching shells stays a one-line toggle in each shell's
# module. Split out of noctalia.nix on 2026-11-03 when Dux replaced Noctalia.
{
  configurations.nixos.nebula.module =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      # Background daemons the shell widgets read (battery/power, bluetooth,
      # power profiles). networking.networkmanager is already on (k is in the
      # networkmanager group). Recommended by both shells' docs; harmless on
      # this desktop where battery is unused.
      services.upower.enable = true;
      services.power-profiles-daemon.enable = true;
      hardware.bluetooth.enable = true;

      # The shell owns org.freedesktop.Notifications; snowglobe's desktop module
      # enables swaync, which then crash-loops on "Could not acquire
      # notification name" (5k+ restarts by 2026-10-02).
      programs.swaync.enable = false;

      # Bare module names: libpam loads them from its own dir, so a lock
      # screen older than a glibc bump still unlocks. See docs/noctalia.md.
      # Dux Shell's default ("Auto") lock auth copies this login stack into
      # ~/.local/state/dms/pam/, so the fix carries over (docs/dux-shell.md).
      environment.etc."pam.d/login".source = lib.mkForce (
        pkgs.writeText "login.pam" (
          builtins.replaceStrings [ "${config.security.pam.package}/lib/security/" ] [ "" ]
            config.security.pam.services.login.text
        )
      );

      # DDC/CI for external-monitor brightness: nebula's DP monitors have no
      # kernel backlight, so brightness only works over the I2C bus. Loads the
      # i2c-dev module, creates the i2c group, and installs the udev rules that
      # group-own /dev/i2c-*; k joins the group (k also has per-session ACL
      # access, so the group is the durable fallback). Whether DDC/CI works over
      # the NVIDIA i2c buses is the real unknown — test with `ddcutil detect`.
      hardware.i2c.enable = true;
      users.users.k.extraGroups = [ "i2c" ];
      users.users.k.packages = [ pkgs.ddcutil ];
    };
}
