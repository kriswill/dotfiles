{
  flake.modules.nixos.xdg-open-journal =
    # PATH-shadowing xdg-open wrapper: snowglobe's xdg.portal.xdgOpenUsePortal
    # routes every open through gdbus, which prints the portal's reply tuple —
    # `(objectpath '/org/freedesktop/portal/desktop/request/…',)` — to stdout.
    # When stdout is a tty, divert it to the journal (with the invocation, so
    # `journalctl -t xdg-open` shows what was opened); non-tty callers keep
    # their stdout untouched. stderr stays on the terminal so real failures
    # are still visible. Wrapping gdbus itself would mean overlaying glib
    # (mass rebuild) and xdg-open pins gdbus by store path anyway.
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (lib.hiPrio (
          pkgs.writeShellScriptBin "xdg-open" ''
            if [ -t 1 ]; then
              exec > >(${pkgs.systemd}/bin/systemd-cat -t xdg-open)
              echo "xdg-open $*"
            fi
            exec ${pkgs.xdg-utils}/bin/xdg-open "$@"
          ''
        ))
      ];
    };
}
