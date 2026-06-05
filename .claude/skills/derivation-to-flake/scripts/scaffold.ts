#!/usr/bin/env bun
// derivation-to-flake / scaffold — turn an in-tree package into a standalone sub-flake.
//
//   bun scaffold.ts <name> [--from <path>] [--systems a,b,c] [--desc "..."]
//
// Creates flakes/<name>/ with a flake-parts flake.nix + the copied package files,
// git-adds them (REQUIRED — Nix won't see untracked sub-flake files), and runs
// `nix flake lock`. It deliberately does NOT delete the in-tree copy or edit the
// root flake: those are AST-level edits + consumer repointing that you do by hand,
// guided by the snippets this script prints. Run `verify.ts <name>` afterward.
import { $ } from "bun";
import { existsSync, mkdirSync, cpSync, statSync, readdirSync } from "node:fs";
import { dirname, join, relative } from "node:path";

const args = process.argv.slice(2);
const name = args[0];
if (!name || name.startsWith("-")) {
  console.error('usage: bun scaffold.ts <name> [--from <path>] [--systems a,b,c] [--desc "..."]');
  process.exit(1);
}
const opt = (flag: string) => {
  const i = args.indexOf(flag);
  return i >= 0 ? args[i + 1] : undefined;
};
const systems = (opt("--systems") || "aarch64-darwin,aarch64-linux,x86_64-linux")
  .split(",").map((s) => s.trim()).filter(Boolean);
const desc = opt("--desc") || `${name} — packaged as a standalone flake`;

function findFlakeRoot(start = process.cwd()): string {
  let dir = start;
  for (;;) {
    if (existsSync(join(dir, "flake.nix"))) return dir;
    const parent = dirname(dir);
    if (parent === dir) { console.error(`no flake.nix above ${start}`); process.exit(1); }
    dir = parent;
  }
}
const ROOT = findFlakeRoot();
const c = { grn: "\x1b[32m", ylw: "\x1b[33m", red: "\x1b[31m", b: "\x1b[1m", x: "\x1b[0m" };
const ok = (m: string) => console.log(`${c.grn}✓${c.x} ${m}`);
const hdr = (m: string) => console.log(`\n${c.b}== ${m} ==${c.x}`);

const dest = join(ROOT, "flakes", name);
if (existsSync(dest)) { console.error(`${c.red}✗${c.x} ${dest} already exists`); process.exit(1); }

// Resolve the source package (file or directory).
let from = opt("--from");
if (from && !from.startsWith("/")) from = join(ROOT, from);
if (!from) {
  for (const cand of [`pkgs/${name}.nix`, `pkgs/${name}`]) {
    if (existsSync(join(ROOT, cand))) { from = join(ROOT, cand); break; }
  }
}
if (!from || !existsSync(from)) {
  console.error(`${c.red}✗${c.x} no source found (tried pkgs/${name}.nix, pkgs/${name}/). Pass --from <path>.`);
  process.exit(1);
}
const fromRel = relative(ROOT, from);

mkdirSync(dest, { recursive: true });

// Copy the source. A bare <name>.nix becomes package.nix; a directory is copied
// verbatim (default.nix -> package.nix) so adjacent files (patches, README) come along.
if (statSync(from).isDirectory()) {
  for (const f of readdirSync(from)) {
    cpSync(join(from, f), join(dest, f === "default.nix" ? "package.nix" : f), { recursive: true });
  }
  ok(`copied ${fromRel}/ -> flakes/${name}/`);
} else {
  cpSync(from, join(dest, "package.nix"));
  ok(`copied ${fromRel} -> flakes/${name}/package.nix`);
}

// flake-parts flake.nix. `default = config.packages.<name>` reuses the same
// derivation (no double-eval). Systems default to darwin + the two common linux.
const sysList = systems.map((s) => `        "${s}"`).join("\n");
const flakeNix = `{
  description = "${desc}";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
${sysList}
      ];

      perSystem =
        { pkgs, config, ... }:
        {
          packages = {
            ${name} = pkgs.callPackage ./package.nix { };
            default = config.packages.${name};
          };
        };
    };
}
`;
await Bun.write(join(dest, "flake.nix"), flakeNix);
ok(`wrote flakes/${name}/flake.nix (systems: ${systems.join(", ")})`);

// Track + lock. Untracked files are invisible to Nix, so this must happen now.
await $`git -C ${ROOT} add flakes/${name}`.nothrow().quiet();
ok(`git add flakes/${name}  (sub-flake files must be tracked to be seen)`);
const lock = await $`nix flake lock ${dest}`.nothrow().quiet();
if (lock.exitCode === 0) {
  await $`git -C ${ROOT} add ${join("flakes", name, "flake.lock")}`.nothrow().quiet();
  ok("nix flake lock");
} else {
  console.log(`${c.ylw}! nix flake lock failed — run it manually:${c.x}\n${lock.stderr.toString().split("\n").slice(-8).join("\n")}`);
}

const overlayFile = existsSync(join(ROOT, `overlays/${name}.nix`)) ? `overlays/${name}.nix` : "";

hdr("now wire the ROOT flake (manual — these are AST edits)");
console.log(`1) flake.nix — add the relative-path input (extracting to a separate repo later
   is just swapping this url to "github:owner/${name}"):

     ${name} = {
       url = "./flakes/${name}";
       inputs.nixpkgs.follows = "nixpkgs";
       inputs.flake-parts.follows = "flake-parts";
     };

2) modules/packages.nix — re-export from the input instead of callPackage
   (perSystem needs the \`system\` arg):

     ${name} = inputs.${name}.packages.\${system}.${name};

   For systems outside the root \`systems\` list, re-export via flake.packages, e.g.:

     flake.packages = builtins.listToAttrs (map (system: {
       name = system;
       value.${name} = inputs.${name}.packages.\${system}.${name};
     }) [ "aarch64-linux" "x86_64-linux" ]);

3) modules/overlays.nix — if a host needs \`pkgs.${name}\`, define the overlay INLINE
   here (the module receives \`inputs\`; overlays are pure final/prev functions and
   cannot import inputs from a separate file):

     ${name} = _final: prev: {
       ${name} = inputs.${name}.packages.\${prev.stdenv.hostPlatform.system}.${name};
     };

4) remove the in-tree copy (and its old overlay) once consumers are repointed:

     git rm -r ${fromRel}${overlayFile ? ` ${overlayFile}` : ""}

5) nix flake lock                 # adds the ${name} input to the root flake.lock
6) bun .claude/skills/derivation-to-flake/scripts/verify.ts ${name}   # build + parity + flake check + stale-ref scan`);
