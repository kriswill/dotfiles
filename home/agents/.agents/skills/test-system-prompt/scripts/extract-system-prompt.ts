#!/usr/bin/env bun
// Extract the literal `system` field from a ccglass capture directory.
//
// ccglass v2 dedupes large request values into blobs/<xx>/<sha>.json and leaves
// a "sha256:<sha>" STRING in their place. It is not a {"$blob":...} object — a
// resolver that looks for an object key silently returns the 71-char stub and
// every diff comes out empty. That failure is quiet, so it is easy to conclude
// "no change" when nothing was ever read.
//
// Usage: bun extract-system-prompt.ts <capture-dir> <out.txt>

import { readdirSync, readFileSync, statSync, writeFileSync } from "fs";
import { join } from "path";

const root = process.argv[2];
const out = process.argv[3];
if (!root || !out) {
  console.error("usage: extract-system-prompt.ts <capture-dir> <out.txt>");
  process.exit(2);
}

const deref = (v: unknown): unknown => {
  if (typeof v === "string" && v.startsWith("sha256:")) {
    const sha = v.slice(7);
    return JSON.parse(readFileSync(join(root, "blobs", sha.slice(0, 2), `${sha}.json`), "utf8"));
  }
  return v;
};

// Captures live in <root>/<timestamp>/NNNN.json; blobs/ is a sibling, skip it.
const files = readdirSync(root)
  .flatMap((d) => {
    const p = join(root, d);
    return statSync(p).isDirectory() && d !== "blobs"
      ? readdirSync(p).map((f) => join(p, f))
      : [];
  })
  .filter((f) => f.endsWith(".json"));

// A run makes several requests (haiku title generation, quota pings). The real
// turn is the one with the longest system prompt.
let best = "";
for (const f of files) {
  const sys = deref(JSON.parse(readFileSync(f, "utf8"))?.request?.system);
  if (!sys) continue;
  const text = typeof sys === "string"
    ? sys
    : (sys as Array<{ text?: string }>).map((b) => b.text ?? "").join("\n");
  if (text.length > best.length) best = text;
}

if (!best) {
  console.error(`no system prompt found in ${root} — check the capture actually ran`);
  process.exit(1);
}
writeFileSync(out, best);
console.log(`${root.split("/").pop()}: ${best.length} chars -> ${out}`);
