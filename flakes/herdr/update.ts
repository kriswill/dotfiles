#!/usr/bin/env bun
// Refreshes ./sources.json from upstream's release manifests — the files
// upstream's own installers read (releases.herdr.dev/{core,app}/latest.json):
// each release's version and, per platform, its tarball URL and sha256.
// No GitHub releases exist for herdr-core or herdr-app; only git tags.
//
//   bun flakes/herdr/update.ts           write sources.json, print what moved
//   bun flakes/herdr/update.ts --check   change nothing; exit 10 if behind
//
// The relative-path input isn't hash-locked, so the next `nrs` picks up the
// new sources.json without a `nix flake update`. A manifest hash that doesn't
// match its tarball fails the fetchurl, loudly, at build time.

import { readFileSync, writeFileSync } from "node:fs";

const RELEASES = process.env.HERDR_RELEASES_URL ?? "https://releases.herdr.dev";
const FILE = `${import.meta.dir}/sources.json`;
// Upstream target name → Nix system, the same for both products (upstream
// also ships macos-x86_64 cores and windows builds, which no host here runs).
const TARGETS: Record<string, string> = {
  "linux-x86_64": "x86_64-linux",
  "linux-aarch64": "aarch64-linux",
  "macos-aarch64": "aarch64-darwin",
};
const SYSTEMS: Record<"herdr-core" | "herdr-app", Record<string, string>> = {
  "herdr-core": TARGETS,
  "herdr-app": TARGETS,
};

type Target = { url: string; sha256: string };
type Manifest = { version: string; core_min?: string; targets: Record<string, Target> };
type Source = { version: string; coreMin?: string; targets: Record<string, { url: string; hash: string }> };
type Sources = { "herdr-core": Source; "herdr-app": Source };

const VERSION = /^\d+\.\d+\.\d+$/;

async function manifest(product: "core" | "app"): Promise<Manifest> {
  const url = `${RELEASES}/${product}/latest.json`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${url}: HTTP ${res.status}`);
  const m = (await res.json()) as Manifest;
  if (!VERSION.test(m.version ?? "")) throw new Error(`${url}: unexpected version ${JSON.stringify(m.version)}`);
  return m;
}

function source(m: Manifest, product: keyof typeof SYSTEMS): Source {
  const targets: Source["targets"] = {};
  for (const [upstream, system] of Object.entries(SYSTEMS[product])) {
    const t = m.targets?.[upstream];
    if (!t) throw new Error(`${product} ${m.version}: no ${upstream} build in the manifest`);
    if (!/^[0-9a-f]{64}$/.test(t.sha256)) throw new Error(`${product} ${upstream}: bad sha256 ${t.sha256}`);
    targets[system] = { url: t.url, hash: `sha256-${Buffer.from(t.sha256, "hex").toString("base64")}` };
  }
  return { version: m.version, ...(m.core_min ? { coreMin: m.core_min } : {}), targets };
}

const cmp = (a: string, b: string) => {
  const [x, y] = [a, b].map((v) => v.split(".").map(Number));
  for (let i = 0; i < 3; i++) if (x[i] !== y[i]) return x[i] - y[i];
  return 0;
};

const check = process.argv.includes("--check");
const old = JSON.parse(readFileSync(FILE, "utf8")) as Partial<Sources>;
const [core, app] = await Promise.all([manifest("core"), manifest("app")]);
const next: Sources = { "herdr-core": source(core, "herdr-core"), "herdr-app": source(app, "herdr-app") };

// The app refuses a core older than its core_min; never pin such a pair.
const coreMin = next["herdr-app"].coreMin;
if (coreMin && cmp(next["herdr-core"].version, coreMin) < 0) {
  throw new Error(`herdr-app ${app.version} needs herdr-core >= ${coreMin}; the latest core is ${core.version}`);
}

let behind = false;
for (const name of ["herdr-core", "herdr-app"] as const) {
  const was = old[name]?.version ?? "(none)";
  const now = next[name].version;
  if (was === now) {
    console.log(`${name} ${now}: up to date`);
  } else {
    behind = true;
    console.log(`${name} ${was} -> ${now}`);
  }
}

const text = `${JSON.stringify(next, null, 2)}\n`;
if (check) process.exit(behind ? 10 : 0);
if (text !== readFileSync(FILE, "utf8")) {
  writeFileSync(FILE, text);
  console.log(`wrote ${FILE}`);
}
