// system-update-report — HTML page of what changed between two system
// generations (nvd diff) plus the flake-update commit that drove it.
//
//   system-update-report [-o out.html] [--repo DIR] [FROM] [TO]
//
// FROM defaults to /run/booted-system on NixOS, or the previous
// /nix/var/nix/profiles/system-N-link on darwin (no booted-system there).
// TO defaults to /run/current-system.
import { $ } from "bun";
import { readlinkSync, readdirSync, existsSync, mkdirSync } from "node:fs";
import { homedir, hostname } from "node:os";
import path from "node:path";

const args = process.argv.slice(2);
const opt = (flag: string) => { const i = args.indexOf(flag); return i >= 0 ? args.splice(i, 2)[1] : undefined; };
const repo = opt("--repo") ?? process.env.DOTFILES ?? path.join(homedir(), "src/dotfiles");
const outArg = opt("-o");
const date = new Date().toLocaleDateString("en-CA"); // local YYYY-MM-DD
const host = hostname().split(".")[0];
const out = outArg ?? path.join(homedir(), "Documents", `system-update-${host}-${date}.html`);

const PROFILES = "/nix/var/nix/profiles";
function previousGeneration(): string {
  const gens = readdirSync(PROFILES).map(f => /^system-(\d+)-link$/.exec(f)?.[1]).filter(Boolean).map(Number).sort((a, b) => a - b);
  const cur = Number(/system-(\d+)-link/.exec(readlinkSync(`${PROFILES}/system`))?.[1]);
  const prev = gens.filter(g => g < cur).at(-1);
  if (prev === undefined) throw new Error("no previous system generation to diff against");
  return `${PROFILES}/system-${prev}-link`;
}
const from = args[0] ?? (existsSync("/run/booted-system") ? "/run/booted-system" : previousGeneration());
const to = args[1] ?? "/run/current-system";
const resolve = (p: string) => { try { return readlinkSync(p); } catch { return p; } };

const esc = (s: string) => s.replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]!));

// --- nvd diff: [U*] #001 name  old -> new  (U/D/C have "->"; A/R a single version)
const nvd = (await $`nvd --color=always diff ${from} ${to}`.text()).trimEnd();
// ANSI SGR -> spans on the theme palette (see .ansi-* rules). Text is HTML-escaped here.
const strip = (s: string) => s.replace(/\x1b\[[\d;]*m/g, "");
const SGR: Record<string, string> = { "1": "b", "31": "red", "32": "green", "33": "yellow", "92": "green", "95": "magenta", "96": "cyan" };
function ansi(s: string): string {
  let out = "", open = false;
  for (const part of s.split(/(\x1b\[[\d;]*m)/)) {
    const m = /^\x1b\[([\d;]*)m$/.exec(part);
    if (!m) { out += esc(part); continue; }
    if (open) { out += "</span>"; open = false; }
    const cls = m[1].split(";").map(c => SGR[c]).filter(Boolean).map(c => "ansi-" + c);
    if (cls.length) { out += `<span class="${cls.join(" ")}">`; open = true; }
  }
  return out + (open ? "</span>" : "");
}
const A = "(?:\\x1b\\[[\\d;]*m)*";
const LINE = new RegExp(`^\\[${A}([UDCAR])${A}[.*+-]${A}\\]\\s+#\\d+\\s+${A}(\\S+)\\s*${A}\\s+(.*)$`);
const rows: Record<string, string[][]> = { U: [], D: [], C: [], A: [], R: [] };
for (const l of nvd.split("\n")) {
  const m = LINE.exec(l);
  if (!m) continue;
  const [, k, name, rest] = m;
  rows[k].push("UDC".includes(k) ? [strip(name), ...rest.split(" -> ")] : [strip(name), rest.trim()]);
}
const closure = strip(nvd).split("\n").find(l => l.startsWith("Closure size"))?.split(": ")[1] ?? "";

// --- latest commit touching flake.lock (however it was titled); its message
// carries the `• Updated/Added/Removed input` blocks that `nix flake update` writes.
const commit = (await $`git -C ${repo} log -1 --format=%h%n%ad%n%B --date=iso -- flake.lock`.text()).trimEnd();
const [sha = "", when = "", ...msgLines] = commit.split("\n");
const msg = msgLines.join("\n");
const subject = msgLines[0] ?? "";
const short = (u: string) => u.replace(/\?.*/, "").replace("https://", "");
const inputs: string[][] = [];
// Git wraps long lines in the message, so whitespace between tokens is free-form.
const ref = (follows: string, u: string, d: string) => `${follows}${short(u)} ${d}`.trim();
for (const m of msg.matchAll(/• Updated input\s*'([^']+)':\s*(follows )?'([^']*)'\s*(\([^)]*\))?\s*→\s*(follows )?'([^']*)'\s*(\([^)]*\))?/g)) {
  const [, n, fa = "", a, ad = "", fb = "", b, bd = ""] = m;
  inputs.push([n, ref(fa, a, ad), ref(fb, b, bd)]);
}
for (const m of msg.matchAll(/• (Added|Removed) input\s*'([^']+)':\s*(follows )?'([^']*)'\s*(\([^)]*\))?/g)) {
  const [, kind, n, f = "", u, d = ""] = m;
  inputs.push(kind === "Added" ? [n, "", ref(f, u, d)] : [n, ref(f, u, d), ""]);
}

// --- highlights: always-interesting names plus any major-version bump
const PINNED = new Set(["linux", "linux-firmware", "nvidia-open", "nvidia-x11", "hyprland", "aquamarine", "mesa", "grub", "determinate-nix", "nix", "chromium", "helium", "thunderbird", "nodejs", "rustc", "typescript", "neovim", "tmux", "zsh", "ghostty", "1password"]);
// Only dotted versions have a "major": date stamps, hashes and bare integers do not.
const major = (v: string) => strip(v).match(/^(\d+)\.\d+/)?.[1];
const hl = [...rows.U, ...rows.D].filter(([n, a, b]) => PINNED.has(n) || major(a) !== major(b));

// --- render
const table = (items: string[][], cols: string[]) =>
  `<table><thead><tr>${cols.map(c => `<th>${c}</th>`).join("")}</tr></thead><tbody>` +
  items.map(r => `<tr>${r.map((c, i) => `<td>${i ? `<code data-wrap>${ansi(c)}</code>` : esc(c)}</td>`).join("")}</tr>`).join("") +
  `</tbody></table>`;
// Token-level diff (split at / . - _ space parens), LCS so shared tokens stay
// plain; only tokens absent from the other side are highlighted.
const tok = (s: string) => s.split(/(?=[\/._ ()-])|(?<=[\/._ ()-])/);
function pair(a: string, b: string): string {
  const A = tok(a), B = tok(b);
  const L: number[][] = Array.from({ length: A.length + 1 }, () => new Array(B.length + 1).fill(0));
  for (let i = A.length - 1; i >= 0; i--) for (let j = B.length - 1; j >= 0; j--)
    L[i][j] = A[i] === B[j] ? L[i + 1][j + 1] + 1 : Math.max(L[i + 1][j], L[i][j + 1]);
  const keepA = new Set<number>(), keepB = new Set<number>();
  for (let i = 0, j = 0; i < A.length && j < B.length; )
    if (A[i] === B[j]) { keepA.add(i); keepB.add(j); i++; j++; }
    else if (L[i + 1][j] >= L[i][j + 1]) i++; else j++;
  const mark = (T: string[], keep: Set<number>, cls: string) =>
    T.map((t, i) => keep.has(i) ? esc(t) : `<span class="${cls}">${esc(t)}</span>`).join("");
  const side = (s: string, T: string[], keep: Set<number>, cls: string, empty: string) =>
    s ? `<code data-wrap>${mark(T, keep, cls)}</code>` : `<span class="muted">${empty}</span>`;
  return `${side(a, A, keepA, "ansi-red", "(new input)")}<br>${side(b, B, keepB, "ansi-green", "(input removed)")}`;
}
const inputTable = `<table><thead><tr><th>Input</th><th>From → To</th></tr></thead><tbody>` +
  inputs.map(([n, a, b]) => `<tr><td>${esc(n)}</td><td>${pair(a, b)}</td></tr>`).join("") + `</tbody></table>`;
const stat = (n: number, label: string, id: string) => `<a class="stat" href="#${id}"><b>${n}</b>${label}</a>`;
// Reboot note only when diffing the booted system and its kernel differs from TO's.
const kver = (p: string) => /-linux-([^/]+)\//.exec(resolve(`${p}/kernel`))?.[1] ?? "";
const kernel = from === "/run/booted-system" && kver(from) !== kver(to) ? [kver(from), kver(to)] : null;

// html-doc skill theme asset (the git-tracked copy under home/agents), path from package.nix.
const theme = await Bun.file(process.env.THEME_HTML ?? path.join(import.meta.dir, "theme.html")).text();
const frags = theme.split(/<!-- =+ -->\n<!-- FRAGMENT \d of 3.*?\n(?:<!--.*?-->\n)*<!-- =+ -->\n/).slice(1).map(s => s.trim());
if (frags.length !== 3) throw new Error(`theme.html: expected 3 fragments, found ${frags.length}`);
const [css, headJs, toggle] = frags;

const html = `<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>${host} update ${date}</title>
<style>
${css}
  body { font: 15px/1.5 system-ui, sans-serif; max-width: 62rem; margin: 0 auto; padding: 2rem 1.25rem 4rem; }
  h1 { font-size: 1.7rem; margin-bottom: .25rem; }
  h2, details { scroll-margin-top: 1rem; }
  h2 { font-size: 1.2rem; border-bottom: 1px solid var(--rule); padding-bottom: .25rem; margin-top: 2.25rem; }
  .lede, .muted { color: var(--muted); }
  code { font-family: ui-monospace, monospace; font-size: .88em; background: var(--code-bg); padding: .1em .35em; border-radius: 4px; white-space: nowrap; -webkit-box-decoration-break: clone; box-decoration-break: clone; }
  code[data-wrap] { white-space: normal; overflow-wrap: anywhere; }
  table { border-collapse: collapse; width: 100%; margin: .75rem 0; }
  th, td { text-align: left; padding: .35rem .6rem; border-bottom: 1px solid var(--rule); vertical-align: top; overflow-wrap: break-word; }
  th { color: var(--muted); font-weight: 600; font-size: .85rem; }
  table.gen th { width: 6rem; }
  .stats { display: flex; flex-wrap: wrap; gap: .75rem; margin: 1.25rem 0; }
  .stats .stat { text-decoration: none; display: block; }
  .stats .stat:hover { border-color: var(--accent); }
  .stats .stat { flex: 1 1 8rem; background: var(--code-bg); border: 1px solid var(--rule); border-radius: 8px; padding: .75rem; color: var(--muted); font-size: .85rem; }
  .stats b { display: block; font-size: 1.6rem; color: var(--ink); }
  .note.warn { background: var(--warn-bg); border-left: 4px solid var(--warn-border); padding: .6rem .9rem; border-radius: 4px; }
  .ansi-b { font-weight: 700; } .ansi-red { color: var(--danger-border); } .ansi-green { color: var(--ok-border); }
  .ansi-yellow { color: var(--warn-border); } .ansi-magenta { color: var(--config-fg); } .ansi-cyan { color: var(--manual-fg); }
  details { margin-top: 2rem; } summary { cursor: pointer; font-weight: 600; }
</style>
${headJs}
</head><body>
${toggle}
<h1>${host} system update, ${date}</h1>
<p class="lede">What changed between <code>${esc(from)}</code> and <code>${esc(to)}</code>${sha ? `, driven by commit <code>${esc(sha)}</code> (<em>${esc(subject)}</em>, ${esc(when)})` : ""}.</p>
<div class="stats">${stat(rows.U.length, "upgraded", "upgraded")}${stat(rows.D.length, "downgraded", "downgraded")}${stat(rows.A.length, "added", "added")}${stat(rows.R.length, "removed", "removed")}${stat(rows.C.length, "rebuilt / multi-version", "rebuilt")}${stat(inputs.length, "flake inputs bumped", "inputs")}</div>
<table class="gen"><tr><th>From</th><td><code data-wrap>${esc(resolve(from))}</code></td></tr>
<tr><th>To</th><td><code data-wrap>${esc(resolve(to))}</code></td></tr>
<tr><th>Closure</th><td>${esc(closure)}</td></tr></table>
${kernel ? `<p class="note warn"><b>Reboot needed:</b> kernel ${esc(kernel[0])} → ${esc(kernel[1])} is only picked up on the next boot.</p>` : ""}
<h2>Highlights</h2><p class="muted">Pinned packages plus every major-version bump.</p>
${table(hl, ["Package", "From", "To"])}
<h2 id="inputs">Flake inputs updated</h2>
${inputTable}
<h2 id="upgraded">All upgraded packages</h2>
${table(rows.U, ["Package", "From", "To"])}
<h2 id="downgraded">Downgraded</h2>
${table(rows.D, ["Package", "From", "To"])}
<h2 id="added">Added</h2>
${table(rows.A, ["Package", "Version"])}
<h2 id="removed">Removed</h2>
${table(rows.R, ["Package", "Version"])}
<details id="rebuilt"><summary>Rebuilt or multi-version changes (${rows.C.length})</summary>${table(rows.C, ["Package", "From", "To"])}</details>
<script>
  // A #rebuilt link must open the <details> it points at.
  function openTarget() { var t = document.querySelector(location.hash || "#none"); if (t && t.tagName === "DETAILS") { t.open = true; t.scrollIntoView(); } }
  addEventListener("hashchange", openTarget); addEventListener("load", openTarget);
</script>
</body></html>
`;
mkdirSync(path.dirname(out), { recursive: true });
await Bun.write(out, html);
console.log(`${out}  upgraded=${rows.U.length} downgraded=${rows.D.length} added=${rows.A.length} removed=${rows.R.length} inputs=${inputs.length}`);
