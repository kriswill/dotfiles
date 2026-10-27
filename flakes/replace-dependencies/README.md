# replace-dependencies

A patched copy of nixpkgs'
[`replaceDirectDependencies`](https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/replace-direct-dependencies.nix),
the function behind
[`replaceDependencies`](https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/replace-dependencies.nix)
and NixOS's `system.replaceDependencies`. Those let you swap a patched
library (say, a fixed brotli or openssl) into an already-built system without
recompiling everything that depends on it: they copy each dependent store path
and rewrite its references to the new library.

On a NixOS desktop, swapping brotli under ~600 store paths with the stock
function ran into three problems. This copy fixes all three, and it's a
drop-in: same arguments and calling convention. Its outputs differ from
stock only where these fixes apply.

| Problem with the stock function | What this copy does |
| --- | --- |
| A binary can hold a store path whose name half the compiler garbled (vector stores turned `…-gimp-3.2.6` into `…-gimp...;\|...`). The rewrite matches `hash-name`, so it misses that path, Nix still sees the intact hash as a reference, and the old dependency stays in the closure: 153 paths under GIMP did. | Also rewrites the bare hash when the old and new names match. This is [NixOS/nixpkgs#579409](https://github.com/NixOS/nixpkgs/pull/579409), unmerged as of 2026-10-26. |
| It rewrites a directory as a NAR stream (`nix-store --dump \| sed \| nix-store --restore`) and never re-sorts it. Renaming two sibling entries named after store paths can flip their order, and `--restore` then fails with `NAR directory is not sorted`. FHS roots and `system-path` have such entries (`share/gdb/auto-load/nix/store/<hash>-…`). Whether a build hits it depends on the new hashes, so it can break at any nixpkgs update. | Copies the directory and rewrites file contents, symlink targets and entry names on the filesystem. Nix sorts the entries itself when it registers the output. Single files and symlinks keep the stream. If a rename would land on an entry that already exists, the build fails, as the stream did, rather than moving one entry into the other. |
| Each rewritten path's deriver becomes the rewrite step, a `runCommandLocal` with only a name. Scanners that read `pname` and `version` from the deriver, like [nixploit](https://github.com/manic-systems/nixploit), see every rewritten package as unversioned: 479 packages, with 22,724 advisories landing in "unknown". | Declares the `pname`, `version` and, for Python packages, the `dontWrapPythonPrograms` PyPI marker that the name implies under nixpkgs' naming. See [Package identity](#package-identity). |

## Use

As a flake input:

```nix
inputs.replace-dependencies = {
  url = "github:<owner>/replace-dependencies"; # or a local path
  inputs.nixpkgs.follows = "nixpkgs";
};
```

On NixOS, import the module, which only adds the overlay, and keep using
`system.replaceDependencies` as usual:

```nix
{
  imports = [ inputs.replace-dependencies.nixosModules.default ];
  system.replaceDependencies.replacements = [
    { oldDependency = pkgs.brotli.lib; newDependency = patchedBrotli.lib; }
  ];
}
```

Elsewhere, apply `overlays.default`. It sets `pkgs.replaceDirectDependencies`,
and `pkgs.replaceDependencies` picks it up:

```nix
pkgs = import nixpkgs { overlays = [ inputs.replace-dependencies.overlays.default ]; };
safeFirefox = pkgs.replaceDependencies {
  drv = pkgs.firefox;
  replacements = [ { oldDependency = pkgs.libwebp; newDependency = patchedLibwebp; } ];
};
```

To use it only while a swap is needed, pick the value inside your own overlay
from the version you're replacing. An overlay's attribute names can't depend
on `prev`, or nixpkgs recurses:

```nix
(final: prev: {
  replaceDirectDependencies =
    if lib.versionOlder prev.brotli.version "1.2.1" then
      (inputs.replace-dependencies.overlays.default final prev).replaceDirectDependencies
    else
      prev.replaceDirectDependencies;
})
```

The usual `replaceDependencies` rules still apply: old and new must have
same-length names (`1.2.0` → `1.2.1` works), evaluation needs
import-from-derivation, and every dependent path gets a rewritten copy in the
store.

Rewriting on the filesystem is slower than the stream for big symlink trees.
Retargeting a symlink takes one `ln` process each, so they run in parallel
within the build's core budget (`NIX_BUILD_CORES`). On a 24-core machine a
directory of 40,000 symlinks and 20,000 files took 11 s, against 2 s for
stock. Rewriting ~600 store paths of a NixOS desktop took under a minute.

## Package identity

A rewrite step declares what its store path's name implies under nixpkgs'
naming:

- Output suffixes and the `-env`/`-wrapped` wrappers are stripped:
  `freetype-2.14.3-dev` becomes `freetype 2.14.3`. The output names come from
  a fixed list in the source (`bin`, `dev`, `lib`, `lib32`, `man`, `doc`,
  `info`, `static`, `modules`, `terminfo`, `py`, util-linux's `login` and
  `mount`, …), built from the outputs seen across a NixOS desktop's closure.
  An output missing from it keeps its suffix in the declared version.
- Interpreter prefixes are dropped from `pname`: `python3.14-aiohttp`,
  `perl5.42.3-GD`, `ruby3.4-pg`. Python packages also get the PyPI marker.
- webkitgtk's `+abi=<abi>` is dropped.
- Left undeclared, as their originals are: FHS, firmware and plugin wrappers
  (`-bwrap`, `-rootfs`, `-init`, `-profile`, `-extracted`, `-zstd`,
  `-only-plugins`), config files (a version ending in `.conf` and the like)
  and config or system paths (`dbus-1`, `graphics-drivers`, `etc-*`,
  `nixos-system-*`, `security-wrapper-*`).

These rules came from comparing `nixploit inventory` of a swapped NixOS system
with the same configuration without the swap: both ended up with 66
unversioned packages. They're heuristics, though, and a name can't carry
everything:

- **Patch lists and source URLs:** advisories nixpkgs already patched can
  show as affected for rewritten packages.
- **Ecosystem markers:** the crates.io, Go and npm markers, and the PyPI
  marker of Python applications (no `python3.x-` prefix), are lost. Those
  packages still match NVD, just not OSV's per-ecosystem advisories.
- **Renames:** a package whose name and pname differ shows under its name,
  e.g. `zfs` as `zfs-user`.

`checks.<system>.identity` holds the expected result for each rule.

## Checks

`nix flake check` builds one regression check per problem:

| Check | Stock function | This copy |
| --- | --- | --- |
| `reordered-entries` | fails: `NAR directory is not sorted` | entries renamed (including inside a renamed parent), absolute and relative-to-directory symlinks retargeted, contents rewritten, executable bit kept |
| `rename-collision` | fails: `NAR directory is not sorted` | fails with `… already exists` (checked with `testers.testBuildFailure`) |
| `garbled-name` | leaves the garbled path's old hash | rewrites both hashes |
| `identity` | declares nothing | expected `pname`/`version` for 35 names |

Each check also fails against a copy of the rewriter with just that fix
removed: without deepest-first renames, without `ln -n`, without the
collision guard, without the bare-hash rewrite. Built and passing on
x86_64-linux. aarch64-linux and aarch64-darwin evaluate but haven't been
built. The rewriter relies on GNU `find -printf`, `sed -z`,
`cp --preserve` and bash's `mapfile -d`, all of which nixpkgs' stdenv provides
on Darwin too. nixpkgs 26.11 dropped x86_64-darwin.

## Files

| File | Purpose |
| --- | --- |
| [`replace-direct-dependencies.nix`](replace-direct-dependencies.nix) | The patched function. nixpkgs' file as of 3ec6363 (2026-10-23), plus the three changes, each commented. |
| [`checks.nix`](checks.nix) | The regression checks above. |
| [`flake.nix`](flake.nix) | flake-parts flake: `overlays.default`, `nixosModules.default`, `checks`. |

## Retiring it

Every change here is a workaround for something nixpkgs could fix
upstream. Once nixpkgs' copy has all three, or you no longer use
`replaceDependencies`, drop the overlay and nothing else changes.
