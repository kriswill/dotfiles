# nixpkgs' pkgs/build-support/replace-direct-dependencies.nix (as of nixpkgs
# 3ec6363, 2026-10-23) with three changes. Drop-in: same arguments and
# calling convention (its outputs differ only by these fixes), so nixpkgs'
# replaceDependencies and NixOS's
# system.replaceDependencies use it unchanged once it replaces
# pkgs.replaceDirectDependencies (see ./flake.nix).
#  - NixOS/nixpkgs PR #579409 (head 51be811, unmerged as of 2026-10-26): when
#    the old and new names match, also rewrite the bare hash, because compilers
#    can garble the name half of a store path inside a binary (gimp's gimptool).
#  - Directories are copied and rewritten on the filesystem instead of
#    through `nix-store --dump | sed | nix-store --restore`. Renaming sibling
#    entries named after store paths could reorder them, and --restore then
#    failed with "NAR directory is not sorted" (an FHS root's
#    usr/share/gdb/auto-load/nix/store/<hash>-gstreamer-1.28.7, twice).
#  - Each rewrite derivation declares the pname, version and (for Python)
#    ecosystem marker that its name implies under nixpkgs' naming, so
#    vulnerability scanners that read them from a path's deriver (nixploit)
#    can still match advisories on rewritten paths.
{
  lib,
  runCommandLocal,
  nix,
}:

# Replace some direct dependencies of drv, not recursing into the dependency tree.
# You likely want to use replaceDependencies instead, unless you plan to implement your own recursion mechanism.
{
  drv,
  replacements ? [ ],
}:
let
  inherit (lib)
    isStringLike
    substring
    stringLength
    optionalString
    escapeShellArgs
    concatMap
    ;

  isNonCaStorePath =
    x:
    if isStringLike x then
      let
        str = toString x;
      in
      builtins.substring 0 1 str == "/" && (dirOf str == builtins.storeDir)
    else
      false;
in
if replacements == [ ] then
  drv
else
  let
    drvName =
      if isNonCaStorePath drv then
        # Reconstruct the name from the actual store path if available.
        substring 33 (stringLength (baseNameOf drv)) (baseNameOf drv)
      else if drv ? drvAttrs.name then
        # Try to get the name from the derivation arguments otherwise (for floating or deferred derivations).
        drv.drvAttrs.name
        + (
          let
            outputName = drv.outputName or "out";
          in
          optionalString (outputName != "out") "-${outputName}"
        )
      else
        throw "cannot reconstruct the derivation name from ${drv}";
    # nixploit takes a store path's package, version and ecosystem from its
    # deriver, which for a rewritten path is this derivation, so declare what
    # its name implies, following nixpkgs' naming:
    #  - outputs other than `out` (from a fixed list below), and the
    #    -env/-wrapped wrappers, put a suffix after the version; their
    #    originals declare the plain version;
    #  - language packages put an interpreter prefix before the pname
    #    (python3.14-aiohttp); Python ones also get dontWrapPythonPrograms,
    #    the marker nixploit reads as PyPI;
    #  - webkitgtk appends +abi=<abi> to its version.
    # Left undeclared, as their originals were: FHS, firmware and plugin
    # wrappers (-bwrap, -rootfs, -init, -profile, -extracted, -zstd,
    # qtbase's -only-plugins), config files (versions ending in .conf and
    # the like) and config or system paths (dbus-1, graphics-drivers, etc-*,
    # nixos-system-*, security-wrapper-*). Not
    # recoverable from a name: the crates.io/Go/npm markers of Rust, Go and
    # npm builds, Python applications' PyPI marker, and renames like zfs's
    # zfs-user output.
    # drvName carries the old path's string context, which these may not.
    plainName = builtins.unsafeDiscardStringContext drvName;
    parsed = builtins.parseDrvName plainName;
    # A fixed list: the output names seen across a NixOS desktop's closure.
    suffix = lib.findFirst (word: lib.hasSuffix "-${word}" parsed.version) null [
      "bin"
      "corepack"
      "debug"
      "dev"
      "devdoc"
      "doc"
      "env"
      "firmware"
      "getent"
      "info"
      "lastlog"
      "lib"
      "lib32"
      "libgcc"
      "login"
      "man"
      "modules"
      "mount"
      "npm"
      "py"
      "python"
      "qml"
      "sandbox"
      "static"
      "su"
      "swap"
      "terminfo"
      "wrapped"
    ];
    version = lib.head (
      lib.splitString "+abi=" (
        if suffix == null then parsed.version else lib.removeSuffix "-${suffix}" parsed.version
      )
    );
    language = builtins.match "((python|perl|ruby)[0-9.]+)-(.+)" parsed.name;
    lastWord = builtins.match ".*-([a-zA-Z]+)" version;
    declared =
      builtins.match "[0-9].*" version != null
      # Config files: fc-00-nixos-cache.conf, *.rules, *.preset.
      && builtins.match ".*[.][a-zA-Z]+" version == null
      && !(
        lastWord != null
        && builtins.elem (lib.toLower (builtins.head lastWord)) [
          "bwrap"
          "extracted"
          "init"
          "plugins"
          "profile"
          "rootfs"
          "zstd"
        ]
      )
      &&
        builtins.match "dbus-1|graphics-drivers.*|etc-.*|nixos-system-.*|security-wrapper-.*" plainName
        == null;
    identity = lib.optionalAttrs declared (
      {
        pname = if language == null then parsed.name else builtins.elemAt language 2;
        inherit version;
      }
      // lib.optionalAttrs (language != null && builtins.elemAt language 1 == "python") {
        dontWrapPythonPrograms = true;
      }
    );
  in
  runCommandLocal drvName ({ nativeBuildInputs = [ nix.out ]; } // identity) ''
    createRewriteScript() {
        while [ $# -ne 0 ]; do
            oldBasename="$(basename "$1")"
            newBasename="$(basename "$2")"
            shift 2
            if [ ''${#oldBasename} -ne ''${#newBasename} ]; then
                echo "cannot rewrite $oldBasename to $newBasename: length does not match" >&2
                exit 1
            fi
            echo "s|$oldBasename|$newBasename|g" >> rewrite.sed
            # If the name parts agree, we can also rewrite the old hash by the new.
            # Binaries sometimes contain the full string ("hash-name") only in
            # garbled form, but at least with the hash intact. For instance
            # this happens when compilers optimize string operations into
            # vector stores.
            if [ "''${oldBasename:32}" = "''${newBasename:32}" ]; then
                echo "s|''${oldBasename:0:32}|''${newBasename:0:32}|g" >> rewrite.sed
            else
                echo "''${oldBasename:0:32} $oldBasename" >> name-changing
            fi
        done
    }
    createRewriteScript ${
      escapeShellArgs (
        [
          drv
          (placeholder "out")
        ]
        ++ concatMap (
          { oldDependency, newDependency }:
          [
            oldDependency
            newDependency
          ]
        ) replacements
      )
    }
    export LC_ALL=C
    if [ -d ${drv} ] && [ ! -L ${drv} ]; then
        # Rewrite a directory on the filesystem, not as a NAR stream: renaming
        # entries named after store paths (gdb auto-load dirs in buildEnv and
        # FHS trees) can reorder siblings, and nix-store --restore rejects an
        # unsorted NAR. Nix sorts the entries itself when it registers $out.
        # Lists go through files, not process substitutions, so a failing
        # find or sed fails the build.
        cp -dR --preserve=mode ${drv} $out
        chmod -R u+w $out
        # File contents.
        find $out -type f -exec sed -i -f "$PWD/rewrite.sed" {} +
        # Symlink targets, all through one sed. ln runs once per changed link
        # (~1 ms each, and buildEnv trees hold tens of thousands), so in
        # parallel, within the build's core budget: replaceDependencies runs
        # many of these builds at once.
        find $out -type l -printf '%p\0%l\0' > links.lst
        mapfile -d "" -t links < links.lst
        for ((i = 1; i < ''${#links[@]}; i += 2)); do printf '%s\0' "''${links[i]}"; done > targets.lst
        sed -z -f rewrite.sed targets.lst > new-targets.lst
        mapfile -d "" -t targets < new-targets.lst
        if [ $((''${#targets[@]} * 2)) -ne ''${#links[@]} ]; then
            echo "symlink list and rewritten targets differ in length" >&2
            exit 1
        fi
        for ((i = 0; i < ''${#targets[@]}; i++)); do
            if [ "''${links[2 * i + 1]}" != "''${targets[i]}" ]; then
                printf '%s\0%s\0' "''${targets[i]}" "''${links[2 * i]}"
            fi
        done > relink.lst
        xargs -0 -r -n 2 -P "$NIX_BUILD_CORES" ln -sfn -- < relink.lst
        # Entry names, deepest first so a parent is renamed after its children.
        find $out -mindepth 1 -depth -print0 > paths.lst
        mapfile -d "" -t paths < paths.lst
        for p in "''${paths[@]}"; do printf '%s\0' "''${p##*/}"; done > names.lst
        sed -z -f rewrite.sed names.lst > new-names.lst
        mapfile -d "" -t names < new-names.lst
        if [ ''${#names[@]} -ne ''${#paths[@]} ]; then
            echo "entry list and rewritten names differ in length" >&2
            exit 1
        fi
        for i in "''${!paths[@]}"; do
            p=''${paths[i]}
            if [ "''${p##*/}" != "''${names[i]}" ]; then
                # mv onto an existing directory would move into it, and onto a
                # file would replace it; the NAR stream failed loudly here.
                dst=''${p%/*}/''${names[i]}
                if [ -e "$dst" ] || [ -L "$dst" ]; then
                    echo "cannot rename $p: $dst already exists" >&2
                    exit 1
                fi
                mv -T -- "$p" "$dst"
            fi
        done
    else
        nix-store --dump ${drv} | sed -f rewrite.sed | nix-store --restore $out
    fi
    if [ -e name-changing ]; then
        while read -r oldHash oldBasename; do
            if nix-store --dump $out | grep -aqF "$oldHash"; then
                echo "warning: $out still contains the hash of $oldBasename" >&2
            fi
        done < name-changing
    fi
  ''
