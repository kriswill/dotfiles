# Patch Dux Shell (./dux-shell-tray-menu-coords.patch) so a tray icon's own
# context menu opens at the cursor when the bar sits on the bottom or right
# edge. Battle.net under Wine's Wayland driver showed it: its menu opened at
# the top of the monitor, a screen height away from the icon.
#
# A tray icon that exports no D-Bus menu (Wine's do not) draws the menu
# itself, and the bar asks for it with StatusNotifierItem.ContextMenu(x, y),
# in screen coordinates. The bar took them from mapToGlobal(), which puts a
# layer-shell window at its screen's origin: a Wayland client is never told
# where the compositor placed it. On a bottom bar y came out as the offset
# inside the 44 px bar. The patch adds the screen size minus the bar window's
# on those two edges. It covers the icons on the bar itself; the overflow
# popout and the island have their own callers, left as they are.
#
# The patch is cut against 2.1.0 and still applies to 2.1.1, nixpkgs' version
# since the 2026-11-10 lock update. It is applied by hand in postPatch, not through `patches`: the package
# builds from core/ (sourceRoot), and the QML lives beside it in
# ../quickshell, read-only until made writable. Only nebula builds dux-shell.
# Drop this once upstream fixes it.
_final: prev: {
  dux-shell = prev.dux-shell.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      chmod -R u+w ../quickshell
      patch -d .. -p1 < ${./dux-shell-tray-menu-coords.patch}
    '';
  });
}
