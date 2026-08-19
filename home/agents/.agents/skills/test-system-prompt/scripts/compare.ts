#!/usr/bin/env bun
// Diff two extracted system prompts and report what was LOST, not just what changed.
//
// The question that matters is never "what did I add" — you know that. It is
// "what did the harness silently drop to make room". Output styles, for example,
// delete the role line and the whole `# Session-specific guidance` section while
// appearing purely additive by size.
//
// Usage: bun compare.ts <baseline.txt> <candidate.txt>

import { readFileSync } from "fs";

const norm = (p: string) =>
  readFileSync(p, "utf8").split("\n").map((l) => l.trimEnd()).filter((l) => l.length > 0);

const [a, b] = [process.argv[2], process.argv[3]];
if (!a || !b) {
  console.error("usage: compare.ts <baseline.txt> <candidate.txt>");
  process.exit(2);
}

const base = norm(a);
const cand = norm(b);
const candSet = new Set(cand);
const baseSet = new Set(base);

const lost = base.filter((l) => !candSet.has(l));
const added = cand.filter((l) => !baseSet.has(l));
const heads = (ls: string[]) => ls.filter((l) => /^#{1,2} /.test(l));

const bytes = (p: string) => readFileSync(p, "utf8").length;
console.log(`baseline  ${base.length} lines, ${bytes(a)} bytes`);
console.log(`candidate ${cand.length} lines, ${bytes(b)} bytes`);
console.log(`delta     ${cand.length - base.length} lines, ${bytes(b) - bytes(a)} bytes\n`);

console.log(`## Sections lost (${heads(lost).length})`);
heads(lost).forEach((h) => console.log(`  - ${h}`));
console.log(`\n## Sections added (${heads(added).length})`);
heads(added).forEach((h) => console.log(`  + ${h}`));

const lostBody = lost.filter((l) => !/^#{1,2} /.test(l));
console.log(`\n## Instruction lines lost (${lostBody.length}) <- REVIEW EVERY ONE`);
lostBody.forEach((l) => console.log(`  - ${l}`));

console.log(`\n## Instruction lines added (${added.filter((l) => !/^#{1,2} /.test(l)).length})`);
console.log(`   (suppressed; read ${b} directly if needed)`);

// Non-zero exit when guidance disappeared, so a CI-ish loop can gate on it.
process.exit(lostBody.length > 0 ? 1 : 0);
