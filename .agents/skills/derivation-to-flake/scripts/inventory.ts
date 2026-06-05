#!/usr/bin/env bun
// derivation-to-flake / inventory — discover an in-tree package and everything that consumes it.
//
//   bun inventory.ts <name>
//
// Read-only. Run from anywhere inside the target flake repo (walks up to flake.nix).
// Prints the package definition location, every reference to it, the likely edit
// targets, and the next command to run. Use this BEFORE scaffolding so you know
// exactly what will need repointing.
import { $ } from "bun";
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";

const name = process.argv[2];
if (!name || name.startsWith("-")) {
  console.error("usage: bun inventory.ts <name>");
  process.exit(1);
}

function findFlakeRoot(start = process.cwd()): string {
  let dir = start;
  for (;;) {
    if (existsSync(join(dir, "flake.nix"))) return dir;
    const parent = dirname(dir);
    if (parent === dir) {
      console.error(`no flake.nix found walking up from ${start}`);
      process.exit(1);
    }
    dir = parent;
  }
}

const ROOT = findFlakeRoot();
const c = { grn: "\x1b[32m", ylw: "\x1b[33m", b: "\x1b[1m", dim: "\x1b[2m", x: "\x1b[0m" };
const hdr = (m: string) => console.log(`\n${c.b}== ${m} ==${c.x}`);

console.log(`repo: ${ROOT}`);

hdr(`package definition for "${name}"`);
const candidates = [
  `pkgs/${name}.nix`,
  `pkgs/${name}/package.nix`,
  `pkgs/${name}/default.nix`,
  `flakes/${name}/flake.nix`,
];
let found = "";
for (const rel of candidates) {
  if (existsSync(join(ROOT, rel))) {
    console.log(`  ${c.grn}found${c.x} ${rel}`);
    found ||= rel;
  }
}
if (!found) console.log(`  ${c.ylw}none found (tried pkgs/${name}.nix, pkgs/${name}/) — check the name${c.x}`);
else if (found.startsWith("flakes/")) console.log(`  ${c.ylw}already a sub-flake — nothing to extract${c.x}`);

hdr(`references to "${name}" (consumers to repoint)`);
const refs = await $`git -C ${ROOT} grep -nI -w ${name} -- . ":(exclude)flake.lock"`.nothrow().quiet();
const refsOut = refs.stdout.toString().trim();
console.log(refsOut || "  (no references found)");

hdr("likely edit targets");
for (const f of ["flake.nix", "modules/packages.nix", "modules/overlays.nix", `overlays/${name}.nix`]) {
  if (!existsSync(join(ROOT, f))) continue;
  const hit = (await $`git -C ${ROOT} grep -nI -w ${name} -- ${f}`.nothrow().quiet()).stdout.toString().trim();
  console.log(`  • ${f}${hit ? ` ${c.dim}(mentions ${name})${c.x}` : ""}`);
}

hdr("next");
const here = ".claude/skills/derivation-to-flake/scripts";
console.log(`  bun ${here}/scaffold.ts ${name}   # create flakes/${name}/ from the in-tree package`);
console.log(`  …then repoint the consumers above, delete the in-tree copy, lock, and:`);
console.log(`  bun ${here}/verify.ts ${name}     # build + parity + flake check + stale-ref scan`);
