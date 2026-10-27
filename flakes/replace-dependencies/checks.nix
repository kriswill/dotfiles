# Regression checks for ./replace-direct-dependencies.nix, one per failure
# the stock rewriter has. The replacements are fake store paths: the rewriter
# only treats them as text, so nothing has to exist or be built for them.
{ pkgs, replaceDirectDependencies }:
let
  inherit (pkgs) lib runCommand;
  inherit (builtins) storeDir;

  # Sibling entries named after these sort 2s02… < vcz8…; rewritten, they
  # become zzzz… > 0000…, so their order flips. Old and new names match
  # ("gst"), which also enables the bare-hash rewrite.
  hashA = "2s02jqrz3hm5489cx08a02pcvfva6zxd";
  hashB = "vcz8srac2kcxrnb8pa5bzaazxm581i98";
  newHashA = "zzzzjqrz3hm5489cx08a02pcvfva6zxd";
  newHashB = "0000srac2kcxrnb8pa5bzaazxm581i98";
  replacements = [
    {
      oldDependency = "${storeDir}/${hashA}-gst";
      newDependency = "${storeDir}/${newHashA}-gst";
    }
    {
      oldDependency = "${storeDir}/${hashB}-gst";
      newDependency = "${storeDir}/${newHashB}-gst";
    }
  ];

  # Shaped like an FHS root's gdb auto-load tree, plus an entry renamed
  # inside a renamed parent, an absolute symlink, a relative symlink to a
  # directory (an `ln -s` without -n would create a link inside it instead),
  # and an executable holding a store path.
  tree = runCommand "replace-dependencies-tree" { } ''
    autoload=$out/share/gdb/auto-load${storeDir}
    mkdir -p $autoload/${hashA}-gst/lib $autoload/${hashA}-gst/${hashA}-gst $autoload/${hashB}-gst $out/bin
    touch $autoload/${hashA}-gst/lib/libgst-gdb.py $autoload/${hashA}-gst/${hashA}-gst/nested
    ln -s ${hashA}-gst $autoload/ldir
    printf 'x ${storeDir}/${hashA}-gst y\n' > $out/bin/tool
    chmod +x $out/bin/tool
    ln -s ${storeDir}/${hashB}-gst/lib $out/link
  '';

  # An entry already named what another entry is renamed to.
  collision = runCommand "replace-dependencies-collision" { } ''
    mkdir -p $out/d/${hashA}-gst $out/d/${newHashA}-gst
    touch $out/d/${hashA}-gst/a $out/d/${newHashA}-gst/b
  '';

  # A lone file (no directory to reorder) holding one intact store path and
  # one whose name half is garbled, the way a compiler's vector stores can
  # leave it.
  garbled = runCommand "replace-dependencies-garbled" { } ''
    printf '${storeDir}/${hashA}-gst\0garbled\0${storeDir}/${hashB}-g\001st' > $out
  '';

  rewrite =
    drv:
    replaceDirectDependencies {
      inherit drv replacements;
    };

  # The pname, version and PyPI marker the rewriter declares for a store path
  # of the given name, or "undeclared".
  identityOf =
    name:
    let
      drv = replaceDirectDependencies {
        drv = "${storeDir}/${hashA}-${name}";
        inherit replacements;
      };
    in
    if drv ? version then
      "${drv.pname} ${drv.version}${lib.optionalString (drv ? dontWrapPythonPrograms) " [PyPI]"}"
    else
      "undeclared";

  expectedIdentities = {
    "freetype-2.14.3-dev" = "freetype 2.14.3";
    "glibc-2.44-57-bin" = "glibc 2.44-57";
    "nodejs-slim-24.21.0-npm" = "nodejs-slim 24.21.0";
    "libreoffice-26.8.0.3-wrapped" = "libreoffice 26.8.0.3";
    "perl-5.42.3-env" = "perl 5.42.3";
    "python3.14-aiohttp-3.14.3" = "aiohttp 3.14.3 [PyPI]";
    "perl5.42.3-GD-2.86" = "GD 2.86";
    "ruby3.4-pg-1.7.0" = "pg 1.7.0";
    "webkitgtk-2.54.1+abi=4.1" = "webkitgtk 2.54.1";
    "util-linux-2.42.4-login" = "util-linux 2.42.4";
    "glibc-2.44-57-getent" = "glibc 2.44-57";
    "xgcc-16.2.0-libgcc" = "xgcc 16.2.0";
    "foot-1.24.0-terminfo" = "foot 1.24.0";
    "libxml2-2.15.1-py" = "libxml2 2.15.1";
    "linux-7.3-modules" = "linux 7.3";
    "zlib-1.3.2-static" = "zlib 1.3.2";
    "shadow-4.18.0-su" = "shadow 4.18.0";
    "chromium-156.0.8078.47-sandbox" = "chromium 156.0.8078.47";
    "nvidia-x11-580.95.05-lib32" = "nvidia-x11 580.95.05";
    "codebase-memory-mcp-0.8.1-nix" = "codebase-memory-mcp 0.8.1-nix";
    "qtwebengine-6.140.0-rc" = "qtwebengine 6.140.0-rc";
    "foo-1.0-rc1" = "foo 1.0-rc1";
    "foo-2.0-beta_1" = "foo 2.0-beta_1";
    "systemd-262" = "systemd 262";
    "dbus-1.16.2" = "dbus 1.16.2";
    "steam-1.0.0.87-fhsenv-rootfs" = "undeclared";
    "steam-1.0.0.87-bwrap" = "undeclared";
    "sof-firmware-2025.12.2-zstd" = "undeclared";
    "qtbase-6.12.0-only-plugins-qml" = "undeclared";
    "dbus-1" = "undeclared";
    "graphics-drivers-32bit" = "undeclared";
    "etc-sysctl.d-60-nixos.conf" = "undeclared";
    "fc-00-nixos-cache.conf" = "undeclared";
    "nixos-system-host-26.11.20261023.3ec6363" = "undeclared";
    "security-wrapper-ping-x86_64-unknown-linux-musl" = "undeclared";
  };
  identityMismatches = lib.filterAttrs (
    name: expected: identityOf name != expected
  ) expectedIdentities;
in
{
  # Stock: "NAR directory is not sorted". Here: renamed entries (a nested
  # one too), retargeted symlinks, rewritten contents, executable bit kept.
  reordered-entries =
    let
      out = rewrite tree;
    in
    runCommand "replace-dependencies-reordered-entries" { } ''
      set -euo pipefail
      autoload=${out}/share/gdb/auto-load${storeDir}
      test -f $autoload/${newHashA}-gst/lib/libgst-gdb.py
      test -f $autoload/${newHashA}-gst/${newHashA}-gst/nested
      test -d $autoload/${newHashB}-gst
      test ! -e $autoload/${hashA}-gst
      test ! -e $autoload/${hashB}-gst
      test ! -e $autoload/${newHashA}-gst/${hashA}-gst
      test "$(readlink $autoload/ldir)" = ${newHashA}-gst
      test -d $autoload/ldir/lib
      test "$(readlink ${out}/link)" = ${storeDir}/${newHashB}-gst/lib
      test -x ${out}/bin/tool
      grep -aqF ${storeDir}/${newHashA}-gst ${out}/bin/tool
      touch $out
    '';

  # Stock fails ("NAR directory is not sorted"); a bare `mv` would move the
  # old entry into the existing one and succeed. Must fail, and say why.
  rename-collision =
    runCommand "replace-dependencies-rename-collision"
      { failed = pkgs.testers.testBuildFailure (rewrite collision); }
      ''
        grep -F "already exists" $failed/testBuildFailure.log
        touch $out
      '';

  # Stock rewrites only the intact path and leaves the garbled one's hash,
  # and with it a reference to the old path. (`if`, not `!`: set -e ignores
  # a negated command.)
  garbled-name =
    let
      out = rewrite garbled;
    in
    runCommand "replace-dependencies-garbled-name" { } ''
      set -euo pipefail
      grep -aqF ${newHashA} ${out}
      grep -aqF ${newHashB} ${out}
      if grep -aqF -e ${hashA} -e ${hashB} ${out}; then
        echo "an old hash survived the rewrite" >&2
        exit 1
      fi
      touch $out
    '';

  identity =
    if identityMismatches == { } then
      runCommand "replace-dependencies-identity" { } "touch $out"
    else
      throw "replace-dependencies identity mismatches (name = got): ${
        builtins.toJSON (lib.mapAttrs (name: _: identityOf name) identityMismatches)
      }";
}
