# Pure builder for the stow restow/self-heal activation script, shared by
# modules/darwin/dotfiles-stow.nix and modules/nixos/dotfiles-stow.nix (lib/
# sits outside modules/ so import-tree doesn't treat this as a flake-parts
# module). The two OSes differ only in paths, the run-as-user command, and
# which stow packages they skip or fold — everything else (canonicalization,
# per-file self-heal, conflict-tolerant restow) must stay byte-identical, and
# one shared generator is what keeps a future fix from landing on only one OS.
#
# Args:
#   pkgs        — for coreutils/findutils/stow store paths
#   home        — the user's home dir (/Users/k | /home/k)
#   stowDir     — the live repo's home/ tree (never a ${./home} store copy)
#   skip        — stow packages belonging to the other OS (list of names)
#   skipReason  — label in the skip events ("linux-only" | "darwin-only")
#   runAsUser   — command prefix that runs the restow as the user, once
#                 (darwin: sudo -u <user> --set-home; nixos: setpriv + env HOME)
#   fold        — packages stowed WITHOUT --no-folding, so a directory that
#                 exists only in the package becomes one symlink. For apps
#                 that need their config DIRECTORY linked (Karabiner-Elements
#                 only detects changes when ~/.config/karabiner itself is the
#                 link). A real directory already at the target blocks this:
#                 stow reports a conflict until it is moved aside once.
{
  pkgs,
  home,
  stowDir,
  skip,
  skipReason,
  runAsUser,
  fold ? [ ],
}:
let
  skipPattern = builtins.concatStringsSep "|" skip;
  # The restow runs as the user in ONE process (nothing in it needs root), and
  # it avoids a process per stowed FILE. On a Mac, where fork+exec is slow,
  # per-link readlink/dirname/realpath subshells cost ~10 ms per file: 2.56 s
  # for 21 packages, 875 ms of it nvim's 77 files. (Not sudo: one `sudo -u` is
  # 0.03 s, and stow itself ~25 ms per package.) Links are now resolved with
  # one batched readlink + realpath per package, the clock is bash's
  # EPOCHREALTIME, and names come from parameter expansion.
  #
  # Output is an NDJSON event stream on stderr, one object per line. This runs
  # without a terminal (inside switch-to-configuration, under a systemd unit or
  # darwin-rebuild, and at every NixOS boot), so it can't draw progress itself;
  # a front-end that owns the terminal (nrs) renders the events, and the raw
  # lines stay readable in a captured log or the boot journal:
  #   {"stow":"begin","packages":N,"skipped":M}
  #   {"stow":"skip","pkg":P,"reason":R}
  #   {"stow":"heal","pkg":P,"link":L}           stale non-canonical link removed
  #   {"stow":"ok","pkg":P,"files":F,"ms":T}     plus "msg" if stow printed anything
  #   {"stow":"conflict","pkg":P,"ms":T,"msg":S} stow's own output; package skipped
  #   {"stow":"end","ok":N,"conflicts":C,"healed":H,"skipped":M,"ms":T}
  #   {"stow":"absent","dir":D}                  no stow tree yet
  #   {"stow":"failed","status":S}               the restow itself died (snippet)
  # (modules/nixos/dotfiles-stow.nix adds {"stow":"reload","what":"hyprland",…})
  # Strings are escaped in bash rather than with jq: no extra process per event
  # on every activation and boot.
  restow = pkgs.writeShellScript "dotfiles-restow" ''
    set -u
    json_str() { # json_str <text>: <text> as a JSON string literal
      local s="$1"
      s="''${s//\\/\\\\}"
      s="''${s//\"/\\\"}"
      s="''${s//$'\n'/\\n}"
      s="''${s//$'\t'/\\t}"
      s="''${s//$'\r'/\\r}"
      printf '"%s"' "$s"
    }
    # Milliseconds from bash's own clock into $ms: no `date` process.
    ms_now() { ms=$(( ''${EPOCHREALTIME/[.,]/} / 1000 )); }
    if [ ! -d "${stowDir}" ]; then
      printf '{"stow":"absent","dir":%s}\n' "$(json_str "${stowDir}")" >&2
      exit 0
    fi
    ms_now
    started=$ms
    fold_pkgs=" ${builtins.concatStringsSep " " fold} "
    # Canonical (symlink-resolved) stow dir. stow resolves --dir before
    # computing link targets, so the links it OWNS go through this path. A
    # link reaching the same file via a ~/src/dotfiles convenience symlink
    # (e.g. a hand-made `ln -s ../../src/dotfiles/...`) does NOT match, so stow
    # disowns it and skips the whole package — silently dropping any new file
    # in that package.
    canon="$(${pkgs.coreutils}/bin/realpath "${stowDir}")"
    # Auto-discover packages: every directory under home/ is one stow package,
    # so newly adopted apps are deployed on the next rebuild with no nix edit.
    # Classified up front so "begin" can carry the total for a progress
    # display; packages that belong to the other OS are skipped.
    todo=()
    skipped=()
    for pkgdir in "${stowDir}"/*/; do
      [ -d "$pkgdir" ] || continue
      pkg="''${pkgdir%/}"
      pkg="''${pkg##*/}"
      case "$pkg" in
        ${skipPattern}) skipped+=("$pkg") ;;
        *) todo+=("$pkg") ;;
      esac
    done
    printf '{"stow":"begin","packages":%d,"skipped":%d}\n' "''${#todo[@]}" "''${#skipped[@]}" >&2
    for pkg in "''${skipped[@]}"; do
      printf '{"stow":"skip","pkg":%s,"reason":%s}\n' "$(json_str "$pkg")" "$(json_str "${skipReason}")" >&2
    done
    ok=0
    conflicts=0
    healed=0
    for pkg in "''${todo[@]}"; do
      pkgdir="${stowDir}/$pkg"
      ms_now
      t0=$ms
      # Self-heal: drop any target symlink that IS one of this package's files
      # but reaches it through a symlinked (non-canonical) path, so the restow
      # below recreates it canonically instead of conflict-skipping the whole
      # package. A link is "stale" when it resolves (follow symlinks) into the
      # repo yet its textual target (NO symlink-follow) does not — i.e. it only
      # lands in-repo via the convenience symlink. Already-canonical links fail
      # the first test and are left untouched, so healthy packages see no churn.
      links=()
      files=0
      while IFS= read -r -d "" rel; do
        files=$((files + 1))
        if [ -L "${home}/$rel" ]; then links+=("${home}/$rel"); fi
      done < <(cd "$pkgdir" && ${pkgs.findutils}/bin/find . \( -type f -o -type l \) -printf '%P\0')
      if [ "''${#links[@]}" -gt 0 ]; then
        # Every link's raw target in one readlink. A link that vanished since
        # the -L test would shift the pairing, so fall back to one call each.
        mapfile -t -d "" raws < <(${pkgs.coreutils}/bin/readlink -z -- "''${links[@]}" 2>/dev/null)
        if [ "''${#raws[@]}" -ne "''${#links[@]}" ]; then
          raws=()
          for link in "''${links[@]}"; do
            raws+=("$(${pkgs.coreutils}/bin/readlink "$link" 2>/dev/null || true)")
          done
        fi
        # Resolve each target's TEXT (no symlink-follow), all in one realpath.
        # An absolute target is used as-is; a relative one is joined to the
        # link's own directory.
        cands=()
        for i in "''${!links[@]}"; do
          case "''${raws[i]}" in
            /*) cands+=("''${raws[i]}") ;;
            *) cands+=("''${links[i]%/*}/''${raws[i]}") ;;
          esac
        done
        mapfile -t -d "" textuals < <(${pkgs.coreutils}/bin/realpath -z -m --no-symlinks -- "''${cands[@]}")
        for i in "''${!links[@]}"; do
          case "''${textuals[i]:-}" in "$canon"/*) continue ;; esac # already canonical
          real="$(${pkgs.coreutils}/bin/readlink -f "''${links[i]}" 2>/dev/null || true)"
          case "$real" in
            "$canon"/*) # our file, wrong path
              rm -f "''${links[i]}"
              healed=$((healed + 1))
              printf '{"stow":"heal","pkg":%s,"link":%s}\n' "$(json_str "$pkg")" "$(json_str "''${links[i]}")" >&2
              ;;
          esac
        done
      fi
      # --no-folding keeps ~/.config/<app> a real dir (only files symlinked),
      # so app-generated siblings don't leak into the repo — except for the
      # `fold` packages, whose apps need the directory itself linked.
      # Tolerate per-package conflicts (report + continue) so one bad package
      # never fails the rebuild. --ignore: apps that canonicalize a stowed
      # file's path leak droppings NEXT TO the real files anyway — a sudo'd
      # fastfetch left a root-owned .cache/ inside home/fastfetch, unreadable
      # to the user, so this stow invocation errored and the package was
      # skipped on every restow. Ignore matching is by name, before stow ever
      # opens the dir, so unreadable droppings can't take the package down.
      # (Patterns full-match basenames.)
      folding=(--no-folding)
      case "$fold_pkgs" in *" $pkg "*) folding=() ;; esac
      if out="$(${pkgs.stow}/bin/stow \
             --dir="${stowDir}" --target="${home}" \
             --ignore='\.cache' --ignore='\.DS_Store' \
             "''${folding[@]}" --restow "$pkg" 2>&1)"; then
        ok=$((ok + 1))
        note=""
        if [ -n "$out" ]; then note=",\"msg\":$(json_str "$out")"; fi
        ms_now
        printf '{"stow":"ok","pkg":%s,"files":%d,"ms":%d%s}\n' \
          "$(json_str "$pkg")" "$files" "$((ms - t0))" "$note" >&2
      else
        conflicts=$((conflicts + 1))
        ms_now
        printf '{"stow":"conflict","pkg":%s,"ms":%d,"msg":%s}\n' \
          "$(json_str "$pkg")" "$((ms - t0))" "$(json_str "$out")" >&2
      fi
    done
    ms_now
    printf '{"stow":"end","ok":%d,"conflicts":%d,"healed":%d,"skipped":%d,"ms":%d}\n' \
      "$ok" "$conflicts" "$healed" "''${#skipped[@]}" "$((ms - started))" >&2
  '';
in
''
  # Activation snippets share one shell, so `exit`/`set -u` must be confined to
  # a subshell or they'd abort/alter the rest of activation. A restow that
  # dies is reported, never fatal to the activation.
  (
  ${runAsUser} ${restow} || printf '{"stow":"failed","status":%d}\n' "$?" >&2
  )
''
