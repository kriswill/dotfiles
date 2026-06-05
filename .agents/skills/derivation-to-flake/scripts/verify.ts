#!/usr/bin/env bun
// derivation-to-flake / verify — prove the extraction is correct end to end.
//
//   bun verify.ts <name> [--no-check]
//
// Runs the rote post-extraction checks:
//   1. the sub-flake builds standalone            (the package still works on its own)
//   2. the root re-exports + builds it via the input (consumption is wired)
//   3. drv parity note                            (follows vs the sub-flake's own lock)
//   4. nix flake check                            (the whole repo still evaluates/builds)
//   5. no stale references to the old in-tree path remain
// Exits non-zero if any hard check fails. Read-only (no repo mutation).
import { $ } from "bun";
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";

const args = process.argv.slice(2);
const name = args[0];
if (!name || name.startsWith("-")) {
  console.error("usage: bun verify.ts <name> [--no-check]");
  process.exit(1);
}
const noCheck = args.includes("--no-check");

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
const SUB = join(ROOT, "flakes", name);
const c = { grn: "\x1b[32m", ylw: "\x1b[33m", red: "\x1b[31m", b: "\x1b[1m", x: "\x1b[0m" };
const ok = (m: string) => console.log(`${c.grn}✓${c.x} ${m}`);
const bad = (m: string) => console.log(`${c.red}✗${c.x} ${m}`);
const hdr = (m: string) => console.log(`\n${c.b}== ${m} ==${c.x}`);
const base = (p: string) => p.replace(/.*\//, "");

if (!existsSync(join(SUB, "flake.nix"))) {
  bad(`no flakes/${name}/flake.nix — run scaffold.ts first`);
  process.exit(1);
}

let pass = true;
const system = (await $`nix eval --impure --raw --expr builtins.currentSystem`.text()).trim();
console.log(`repo: ${ROOT}\nsystem: ${system}`);

hdr(`sub-flake builds standalone — flakes/${name}#packages.${system}.${name}`);
let subDrv = "";
const subBuild = await $`nix build ${SUB}#packages.${system}.${name} --no-link`.nothrow().quiet();
if (subBuild.exitCode === 0) {
  subDrv = (await $`nix eval --raw ${SUB}#packages.${system}.${name}.drvPath`.nothrow().quiet()).stdout.toString().trim();
  ok(`standalone build OK  (${base(subDrv)})`);
} else {
  bad("standalone build failed");
  console.log(subBuild.stderr.toString().split("\n").slice(-12).join("\n"));
  pass = false;
}

hdr(`root consumes it — .#packages.${system}.${name}`);
const rootEval = await $`nix eval --raw .#packages.${system}.${name}.drvPath`.cwd(ROOT).nothrow().quiet();
if (rootEval.exitCode === 0) {
  const rootDrv = rootEval.stdout.toString().trim();
  ok(`root output resolves  (${base(rootDrv)})`);
  if (subDrv) {
    console.log(
      rootDrv === subDrv
        ? `  drv parity: root == standalone (the sub-flake lock resolves to the same nixpkgs as the root)`
        : `  note: root drv != standalone drv — expected when the sub-flake's own lock pins a different\n        nixpkgs than the root; \`follows\` makes the ROOT build against the ROOT's nixpkgs.`,
    );
  }
  const rb = await $`nix build .#packages.${system}.${name} --no-link`.cwd(ROOT).nothrow().quiet();
  if (rb.exitCode === 0) ok("root build OK"); else { bad("root build failed"); pass = false; }
} else {
  console.log(`  ${c.ylw}root does not expose .#packages.${system}.${name} yet — wire modules/packages.nix (see scaffold output)${c.x}`);
}

if (!noCheck) {
  hdr("nix flake check");
  const fc = await $`nix flake check`.cwd(ROOT).nothrow().quiet();
  if (fc.exitCode === 0) ok("flake check passed");
  else {
    bad("flake check failed");
    console.log((fc.stdout.toString() + fc.stderr.toString()).split("\n").slice(-15).join("\n"));
    pass = false;
  }
}

hdr("stale references to the old in-tree path");
const stale = await $`git -C ${ROOT} grep -nIE ${`pkgs/${name}|overlays/${name}`} -- . ":(exclude)flake.lock"`.nothrow().quiet();
const staleOut = stale.stdout.toString().trim();
if (staleOut) {
  bad("found stale references (repoint or remove):");
  console.log(staleOut);
  pass = false;
} else {
  ok(`no references to pkgs/${name} or overlays/${name}`);
}

console.log("");
if (pass) ok("all checks passed");
else { bad("some checks FAILED"); process.exit(1); }
