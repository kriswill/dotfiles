# Move LibreOffice's user-writable paths out of the config dir into the XDG
# data/state trees.
#
# By default LibreOffice roots Backup/Template/Gallery/AutoText/AutoCorrect/user
# dictionary at $(userurl) — i.e. inside the profile, ~/.config/libreoffice/4/
# user/<...> — so generated *data* ends up under ~/.config. This redirects each
# to the XDG-appropriate location while leaving the actual settings (the profile
# / registrymodifications.xcu) in ~/.config, where they belong.
#
# Getting Tools > Options > Paths to show ONLY the new location took reading the
# LibreOffice source (framework/source/services/pathsettings.cxx, cui/source/
# options/optpath.cxx). Findings that shape the overrides below:
#
#  * The dialog's "User Paths" column = UserPaths list + ";" + WritePath.
#  * PathSettings merges a *legacy* config node, org.openoffice.Office.Common/
#    Path/Current/<name>, on top of the modern org.openoffice.Office.Paths node
#    (impl_mergeOldUserPaths). That legacy node still ships $(userurl)/<name> as
#    a default, and the merge: for multi-paths PUSHES it into the UserPaths list
#    (→ the stale ~/.config entry); for single-paths (Backup) OVERWRITES
#    WritePath with it (→ Backup ignored the modern WritePath entirely).
#  * The merge skips a legacy value that equals WritePath, and PathSettings drops
#    WritePath from the UserPaths list. So the fix is: set the modern WritePath
#    AND the legacy Common/Path/Current/<name> to the same XDG url. Then the
#    legacy entry is skipped and UserPaths is empty → the row shows only WritePath.
#
# We seed both nodes into the user layer (registrymodifications.xcu) — the only
# writable config layer without wrapping the package — matching dotfiles-stow's
# "make the live home match the repo" idiom.
{ lib, pkgs, ... }:
let
  user = "k";
  home = "/home/k";
  profileDir = "${home}/.config/libreoffice/4/user";
  regmod = "${profileDir}/registrymodifications.xcu";

  ls = "${home}/.local/share/libreoffice";
  lst = "${home}/.local/state/libreoffice";

  # name -> { dir; single; legacy; newUserPaths }
  #   dir          target directory (backups are recovery *state*; rest are *data*)
  #   single       the legacy node stores a plain string, not a list (Backup only)
  #   legacy       the legacy Common/Path/Current/<name> default pins $(userurl)/
  #                <name>, so we must override it too (all but Dictionary, whose
  #                legacy default is internal-only and never showed ~/.config)
  #   newUserPaths the modern node also ships a UserPaths default to neutralise
  #                (Template only, on unix) — set it equal to WritePath so
  #                PathSettings drops it from the list
  paths = {
    Backup = { dir = "${lst}/backup"; single = true; legacy = true; newUserPaths = false; };
    AutoCorrect = { dir = "${ls}/autocorr"; single = false; legacy = true; newUserPaths = false; };
    AutoText = { dir = "${ls}/autotext"; single = false; legacy = true; newUserPaths = false; };
    Gallery = { dir = "${ls}/gallery"; single = false; legacy = true; newUserPaths = false; };
    Template = { dir = "${ls}/template"; single = false; legacy = true; newUserPaths = true; };
    Dictionary = { dir = "${ls}/wordbook"; single = false; legacy = false; newUserPaths = false; };
    # Graphic = the image open/save default dir (single-path); its legacy default
    # is $(userurl)/gallery, so override the legacy node too.
    Graphic = { dir = "${ls}/images"; single = true; legacy = true; newUserPaths = false; };
    # DocumentTheme's legacy default is internal-only ($(insturl)/themes), which
    # PathSettings purges from the user list — so only the modern WritePath needs it.
    DocumentTheme = { dir = "${ls}/themes"; single = false; legacy = false; newUserPaths = false; };
  };

  # Modern node: org.openoffice.Office.Paths/Paths/<name>. WritePath always;
  # UserPaths only where the modern default needs neutralising (== WritePath, so
  # PathSettings drops it from the displayed list).
  modernItem =
    name: v:
    let
      url = "file://${v.dir}";
      writeProp = ''<prop oor:name="WritePath" oor:op="fuse"><value>${url}</value></prop>'';
      userProp = lib.optionalString v.newUserPaths ''<prop oor:name="UserPaths" oor:op="fuse"><value><it>${url}</it></value></prop>'';
    in
    ''<item oor:path="/org.openoffice.Office.Paths/Paths/org.openoffice.Office.Paths:NamedPath['${name}']">${writeProp}${userProp}</item>'';

  # Legacy node: org.openoffice.Office.Common/Path/Current/<name>. Set equal to
  # WritePath so impl_mergeOldUserPaths skips it (string for single, list else).
  legacyItem =
    name: v:
    let
      url = "file://${v.dir}";
      val = if v.single then "<value>${url}</value>" else "<value><it>${url}</it></value>";
    in
    ''<item oor:path="/org.openoffice.Office.Common/Path/Current"><prop oor:name="${name}" oor:op="fuse">${val}</prop></item>'';

  items = lib.concatStringsSep "\n" (
    (lib.mapAttrsToList modernItem paths)
    ++ (lib.mapAttrsToList legacyItem (lib.filterAttrs (_: v: v.legacy) paths))
  );
  itemsFile = pkgs.writeText "libreoffice-xdg-paths.xml" items;

  # An oor:path LibreOffice preserves verbatim across rewrites — used as the
  # "already seeded" sentinel (a comment marker would be stripped on LO's first
  # normalize/save).
  sentinel = "NamedPath['Backup']";
in
{
  # Pre-create the XDG target dirs (owned by the user) so LibreOffice can write
  # to them even on a switch where the seed step is skipped.
  systemd.tmpfiles.rules = map (p: "d ${p.dir} 0755 ${user} users - -") (lib.attrValues paths);

  system.activationScripts.libreofficePaths = {
    deps = [ "users" ]; # run after user k exists
    text = ''
      set -u
      regmod="${regmod}"

      # LibreOffice rewrites registrymodifications.xcu from memory on exit, so
      # seeding while it runs would be clobbered — skip (tolerant, like stow).
      if ${pkgs.procps}/bin/pgrep -x soffice.bin >/dev/null 2>&1; then
        echo "libreoffice-paths: soffice.bin running, skipping seed" >&2
        exit 0
      fi

      # Already seeded? (survives LO's normalize/rewrite)
      if [ -e "$regmod" ] && ${pkgs.gnugrep}/bin/grep -qF "${sentinel}" "$regmod"; then
        exit 0
      fi

      if [ ! -e "$regmod" ]; then
        # Fresh profile (LO never launched): create a minimal valid file.
        ${pkgs.coreutils}/bin/install -d -o ${user} -g users -m 0700 "${profileDir}"
        {
          echo '<?xml version="1.0" encoding="UTF-8"?>'
          echo '<oor:items xmlns:oor="http://openoffice.org/2001/registry" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
          ${pkgs.coreutils}/bin/cat ${itemsFile}
          echo '</oor:items>'
        } > "$regmod"
        ${pkgs.coreutils}/bin/chown ${user}:users "$regmod"
        echo "libreoffice-paths: created $regmod with XDG paths" >&2
        exit 0
      fi

      # Existing file without our entries: insert them before </oor:items>.
      if ${pkgs.gawk}/bin/awk -v f=${itemsFile} '
            /<\/oor:items>/ && !done { while ((getline l < f) > 0) print l; done = 1 }
            { print }
          ' "$regmod" > "$regmod.xdgtmp"; then
        ${pkgs.coreutils}/bin/mv "$regmod.xdgtmp" "$regmod"
        ${pkgs.coreutils}/bin/chown ${user}:users "$regmod"
        echo "libreoffice-paths: seeded XDG paths into $regmod" >&2
      else
        ${pkgs.coreutils}/bin/rm -f "$regmod.xdgtmp"
        echo "libreoffice-paths: WARNING failed to seed, left $regmod unchanged" >&2
      fi
    '';
  };
}
