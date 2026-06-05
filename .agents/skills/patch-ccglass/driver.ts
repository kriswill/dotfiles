#!/usr/bin/env bun
// patch-ccglass driver — maintenance harness for the flakes/ccglass derivation.
//
//   bun driver.ts latest-tag          print the newest upstream git tag
//   bun driver.ts prepare [TAG]       clone TAG (default: latest), scan for bun-compile
//                                     hazards, and check whether fork.patch still applies
//   bun driver.ts regen-patch <CLONE> write `git -C <CLONE> diff` to flakes/ccglass/fork.patch
//   bun driver.ts verify              nix build the sub-flake + run version/MCP/dashboard checks
//   bun driver.ts all [TAG]           prepare, then verify (only if the patch applies)
//
// Exposed for aarch64-darwin, aarch64-linux, x86_64-linux; `verify` auto-detects the current system.
import { $ } from "bun";
import { resolve, join } from "node:path";
import { mkdtempSync, rmSync, mkdirSync } from "node:fs";
import { tmpdir } from "node:os";

const OWNER = "jianshuo";
const REPO = "ccglass";
const REPO_URL = `https://github.com/${OWNER}/${REPO}`;
const ROOT = resolve(import.meta.dir, "../../.."); // repo root from .claude/skills/patch-ccglass/
const FLAKE_DIR = join(ROOT, "flakes/ccglass"); // the standalone ccglass sub-flake
const FORK_PATCH = join(FLAKE_DIR, "fork.patch");
const WORK = join(tmpdir(), "patch-ccglass");
const SELF = ".claude/skills/patch-ccglass/driver.ts";

const c = { red: "\x1b[31m", grn: "\x1b[32m", ylw: "\x1b[33m", b: "\x1b[1m", x: "\x1b[0m" };
const ok = (m: string) => console.log(`${c.grn}✓${c.x} ${m}`);
const warn = (m: string) => console.log(`${c.ylw}!${c.x} ${m}`);
const err = (m: string) => console.log(`${c.red}✗${c.x} ${m}`);
const hdr = (m: string) => console.log(`\n${c.b}== ${m} ==${c.x}`);

const cmpSemver = (a: string, b: string) => {
  const pa = a.slice(1).split(".").map(Number);
  const pb = b.slice(1).split(".").map(Number);
  for (let i = 0; i < 3; i++) if (pa[i] !== pb[i]) return pa[i] - pb[i];
  return 0;
};

async function latestTag(): Promise<string> {
  const out = await $`git ls-remote --tags --refs ${REPO_URL}`.text();
  const tags = out
    .split("\n")
    .map((l) => l.split("refs/tags/")[1])
    .filter((t): t is string => !!t && /^v\d+\.\d+\.\d+$/.test(t))
    .sort(cmpSemver);
  if (!tags.length) throw new Error("no semver tags found upstream");
  return tags[tags.length - 1];
}

async function patchApplies(clone: string): Promise<boolean> {
  const r = await $`git -C ${clone} apply --check -p1 ${FORK_PATCH}`.nothrow().quiet();
  return r.exitCode === 0;
}

async function prepare(tagArg?: string): Promise<{ clone: string; tag: string; applies: boolean }> {
  const tag = tagArg || (await latestTag());
  const clone = join(WORK, tag);

  hdr(`clone ${REPO}@${tag}`);
  rmSync(clone, { recursive: true, force: true });
  mkdirSync(WORK, { recursive: true });
  await $`git -c advice.detachedHead=false clone --quiet --depth 1 --branch ${tag} ${REPO_URL} ${clone}`;
  ok(`cloned to ${clone}`);

  hdr("bun-compile hazards (script-relative disk reads `--compile` cannot embed)");
  console.log("Confirm fork.patch still neutralizes each. A NEW match the patch ignores → extend the patch.");
  const src = join(clone, "src");
  const scan = async (label: string, pattern: string) => {
    console.log(`\n${c.b}-- ${label} --${c.x}`);
    const r = await $`grep -rnE ${pattern} ${src}`.nothrow().quiet();
    const t = r.stdout.toString().trim();
    console.log(t || `${c.ylw}(no match — upstream changed shape; re-check this hazard)${c.x}`);
  };
  await scan("version read at module load (must be hardcoded)", String.raw`readFileSync.*package\.json`);
  await scan("web/ served from a computed path (must be embedded)", String.raw`"\.\.",[[:space:]]*"web"|WEB_DIR`);
  await scan("MCP subprocess spawn (must use the __mcp__ sentinel)", String.raw`process\.execPath|mcp\.js`);
  await scan("other import.meta/__dirname reads (review for new hazards)", String.raw`fileURLToPath\(import\.meta\.url\)|import\.meta\.dir`);

  hdr("does flakes/ccglass/fork.patch still apply?");
  const applies = await patchApplies(clone);
  if (applies) {
    ok(`fork.patch applies cleanly to ${tag}`);
    console.log(`Next:  bun ${SELF} verify`);
  } else {
    err(`fork.patch does NOT apply to ${tag}`);
    const r = await $`git -C ${clone} apply --check -p1 ${FORK_PATCH}`.nothrow().quiet();
    console.log(r.stderr.toString().trim());
    const v = tag.slice(1);
    console.log(
      [
        "",
        "Re-author (see SKILL.md → 'Re-authoring the patch'):",
        `  1) cd ${clone}`,
        "  2) re-apply the 3 edits by hand against the new source",
        `  3) bun ${SELF} regen-patch ${clone}`,
        `  4) set the hardcoded VERSION in fork.patch to "${v}"`,
        `  5) bump 'version' in flakes/ccglass/package.nix to "${v}"`,
        `  6) bun ${SELF} verify   # fill the two hashes when it reports a mismatch`,
      ].join("\n"),
    );
  }
  console.log(`CLONE=${clone}`);
  return { clone, tag, applies };
}

async function regenPatch(clone?: string) {
  if (!clone) throw new Error(`usage: bun ${SELF} regen-patch <CLONE_DIR>`);
  const diff = await $`git -C ${clone} diff`.text();
  if (!diff.trim()) {
    err("clone has no changes — refusing to write an empty fork.patch");
    process.exit(1);
  }
  await Bun.write(FORK_PATCH, diff);
  ok(`wrote ${FORK_PATCH} (${diff.split("\n").length} lines)`);
}

// Read `stream` until `marker` appears or `ms` elapses (then kill the child).
async function readUntil(
  proc: Bun.Subprocess,
  stream: ReadableStream<Uint8Array>,
  marker: string,
  ms: number,
): Promise<string> {
  const timer = setTimeout(() => proc.kill(), ms);
  let buf = "";
  const dec = new TextDecoder();
  for await (const chunk of stream) {
    buf += dec.decode(chunk);
    if (buf.includes(marker)) break;
  }
  clearTimeout(timer);
  return buf;
}

async function checkMcp(bin: string): Promise<boolean> {
  const proc = Bun.spawn([bin, "__mcp__"], { stdin: "pipe", stdout: "pipe", stderr: "ignore" });
  const msgs = [
    { jsonrpc: "2.0", id: 1, method: "initialize", params: { protocolVersion: "2024-11-05", capabilities: {}, clientInfo: { name: "t", version: "1" } } },
    { jsonrpc: "2.0", method: "notifications/initialized" },
    { jsonrpc: "2.0", id: 2, method: "tools/list" },
  ];
  for (const m of msgs) proc.stdin.write(JSON.stringify(m) + "\n");
  await proc.stdin.flush();
  const out = await readUntil(proc, proc.stdout as ReadableStream<Uint8Array>, '"id":2', 5000);
  proc.kill();
  const line = out.split("\n").find((l) => l.includes('"id":2'));
  try {
    const names: string[] = JSON.parse(line!).result.tools.map((t: { name: string }) => t.name);
    console.log("  tools: " + names.join(", "));
    return names.length > 0;
  } catch {
    err("  no tools/list response from `ccglass __mcp__`");
    return false;
  }
}

async function checkDashboard(bin: string): Promise<boolean> {
  const home = mkdtempSync(join(tmpdir(), "ccglass-home-"));
  // ccglass prints its `dashboard: http://127.0.0.1:<port>` banner to stderr.
  const proc = Bun.spawn([bin, "run", "--no-open", "--", "sleep", "15"], {
    cwd: home,
    env: { ...process.env, HOME: home },
    stdout: "ignore",
    stderr: "pipe",
  });
  const banner = await readUntil(proc, proc.stderr as ReadableStream<Uint8Array>, "127.0.0.1:", 12000);
  const port = banner.match(/127\.0\.0\.1:(\d+)/)?.[1];
  if (!port) {
    err("  dashboard never printed a port");
    proc.kill();
    rmSync(home, { recursive: true, force: true });
    return false;
  }
  const base = `http://127.0.0.1:${port}`;
  const probe = async (path: string) => {
    try {
      const r = await fetch(base + path);
      const n = (await r.arrayBuffer()).byteLength;
      return { status: r.status, n };
    } catch (e) {
      return { status: 0, n: 0 };
    }
  };
  let pass = true;
  for (const path of ["/", "/app.js", "/style.css", "/stream.css", "/theme.js"]) {
    const { status, n } = await probe(path);
    const good = status === 200;
    pass &&= good;
    console.log(`  ${path.padEnd(13)} -> ${status} (${n} bytes)${good ? "" : "  <-- expected 200"}`);
  }
  const { status } = await probe("/nope.js");
  pass &&= status === 404;
  console.log(`  ${"/nope.js".padEnd(13)} -> ${status} (expected 404)`);
  proc.kill();
  rmSync(home, { recursive: true, force: true });
  return pass;
}

async function verify() {
  const system = (await $`nix eval --impure --raw --expr builtins.currentSystem`.text()).trim();
  const attr = `${FLAKE_DIR}#packages.${system}.ccglass`;
  hdr(`nix build ${attr}`);
  const outLink = join(WORK, "result");
  const build = await $`nix build ${attr} --out-link ${outLink}`.nothrow().quiet();
  if (build.exitCode !== 0) {
    const log = build.stdout.toString() + build.stderr.toString();
    err("build failed");
    const mism = [
      ...log.matchAll(/hash mismatch in fixed-output derivation '([^']+)':\s*\n\s*specified: (\S+)\s*\n\s*got:\s*(\S+)/g),
    ];
    if (mism.length) {
      hdr("hash mismatch — update flakes/ccglass/package.nix, then re-run verify:");
      for (const [, drv, spec, got] of mism) {
        const field = drv.includes("npm-deps") ? "npmDepsHash" : "src.hash";
        console.log(`  set ${field} = "${got}";   (was ${spec})`);
      }
    } else {
      console.log(log.split("\n").slice(-30).join("\n"));
    }
    process.exit(1);
  }
  ok("build succeeded");
  const bin = join(outLink, "bin/ccglass");

  let pass = true;
  hdr("ccglass --version (Edit A — must not crash at launch)");
  const v = await $`${bin} --version`.nothrow();
  pass &&= v.exitCode === 0;

  hdr("MCP stdio server (Edits B/C)");
  pass &&= await checkMcp(bin);

  hdr("dashboard embedded assets (Edit D)");
  pass &&= await checkDashboard(bin);

  console.log("");
  if (!pass) {
    err("some checks FAILED");
    process.exit(1);
  }
  ok("all checks passed");
}

const usage = `patch-ccglass driver
  bun ${SELF} latest-tag
  bun ${SELF} prepare [TAG]
  bun ${SELF} regen-patch <CLONE_DIR>
  bun ${SELF} verify
  bun ${SELF} all [TAG]`;

const [cmd, arg] = process.argv.slice(2);
switch (cmd) {
  case "latest-tag":
    console.log(await latestTag());
    break;
  case "prepare":
    await prepare(arg);
    break;
  case "regen-patch":
    await regenPatch(arg);
    break;
  case "verify":
    await verify();
    break;
  case "all": {
    const { applies } = await prepare(arg);
    if (applies) await verify();
    else warn("skipping verify — patch does not apply; re-author it first");
    break;
  }
  default:
    console.log(usage);
    process.exit(1);
}
