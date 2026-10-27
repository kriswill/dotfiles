# nixpkgs' pkgs/build-support/replace-direct-dependencies.nix with two changes:
#  - NixOS/nixpkgs PR #579409 (head 51be811, unmerged as of 2026-10-26): when
#    the old and new names match, also rewrite the bare hash, because compilers
#    can garble the name half of a store path inside a binary (gimp's gimptool).
#  - Ours: directories are copied and rewritten on the filesystem instead of
#    through `nix-store --dump | sed | nix-store --restore`. Renaming sibling
#    entries named after store paths could reorder them, and --restore then
#    failed with "NAR directory is not sorted" (battlenet-proton's FHS root,
#    usr/share/gdb/auto-load/nix/store/<hash>-gstreamer-1.28.7 twice).
# Used only by ./brotli-graft.nix (the `_` keeps import-tree from loading it);
# delete together with it.
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
  in
  runCommandLocal drvName { nativeBuildInputs = [ nix.out ]; } ''
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
        cp -dR --preserve=mode ${drv} $out
        chmod -R u+w $out
        # File contents.
        find $out -type f -exec sed -i -f "$PWD/rewrite.sed" {} +
        # Symlink targets, all through one sed.
        mapfile -d "" -t links < <(find $out -type l -printf '%p\0%l\0')
        mapfile -d "" -t targets < <(
            for ((i = 1; i < ''${#links[@]}; i += 2)); do printf '%s\0' "''${links[i]}"; done |
                sed -z -f rewrite.sed
        )
        for ((i = 0; i < ''${#targets[@]}; i++)); do
            if [ "''${links[2 * i + 1]}" != "''${targets[i]}" ]; then
                ln -sfn -- "''${targets[i]}" "''${links[2 * i]}"
            fi
        done
        # Entry names, deepest first so a parent is renamed after its children.
        mapfile -d "" -t paths < <(find $out -mindepth 1 -depth -print0)
        mapfile -d "" -t names < <(
            for p in "''${paths[@]}"; do printf '%s\0' "''${p##*/}"; done | sed -z -f rewrite.sed
        )
        for i in "''${!paths[@]}"; do
            p=''${paths[i]}
            if [ "''${p##*/}" != "''${names[i]}" ]; then
                mv -- "$p" "''${p%/*}/''${names[i]}"
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
