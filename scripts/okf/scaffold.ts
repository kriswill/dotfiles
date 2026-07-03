// Scaffold catalog concept stubs from the repo itself — the Nix analog of the
// OKF reference agent's metadata pass. Walks modules/, pkgs/, overlays/,
// flakes/, modules/hosts/ and the Neovim plugin specs, and writes one stub per
// component into knowledge/{modules,packages,hosts,nvim/plugins}/. Idempotent:
// existing docs are never overwritten (enrichment happens by hand or by
// agents), use --force to redo.

import { readdirSync, readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { join } from "node:path";
import { bundleRoot, fmToYaml, gitISO, repoRoot, titleFromSlug, type FM } from "./lib";

const FORCE = process.argv.includes("--force");
const repo = repoRoot();
const bundle = bundleRoot();
let written = 0, skipped = 0;

function emit(rel: string, fm: FM, body: string) {
  const abs = join(bundle, rel);
  if (existsSync(abs) && !FORCE) { skipped++; return; }
  mkdirSync(join(abs, ".."), { recursive: true });
  writeFileSync(abs, fmToYaml(fm) + "\n" + body.trim() + "\n");
  written++;
  console.log(`  + ${rel}`);
}

function read(rel: string): string {
  return readFileSync(join(repo, rel), "utf8");
}

/** Leading comment block at the top of a file, joined. */
function leadingCommentWith(src: string, marker: RegExp): string | null {
  const lines: string[] = [];
  for (const line of src.split("\n")) {
    const m = line.match(marker);
    if (m) lines.push(m[1]);
    else if (line.trim() === "") continue;
    else break;
  }
  const text = lines.join(" ").trim();
  return text || null;
}

/** Leading `# …` comment block at the top of a .nix file, joined. */
const leadingComment = (src: string) => leadingCommentWith(src, /^#\s?(.*)$/);

/** Leading `-- …` comment block at the top of a .lua file, joined. */
const leadingLuaComment = (src: string) => leadingCommentWith(src, /^--\s?(.*)$/);

function firstMatch(src: string, re: RegExp): string | null {
  const m = src.match(re);
  return m ? m[1] : null;
}

const clean = (s: string) => s.replace(/\s+/g, " ").trim();

/** Wrap bare URLs in angle brackets (MD034) for use in markdown bodies. */
const mdSafe = (s: string) => s.replace(/(^|[\s(])(https?:\/\/[^\s)>]+)/g, "$1<$2>");

function sentence(s: string): string {
  const t = clean(s);
  return /[.!?]$/.test(t) ? t : t + ".";
}

/** First sentence, for frontmatter descriptions (full text stays in the body). */
function firstSentence(s: string): string {
  const t = clean(s);
  const m = t.match(/^.*?[.!?](?=\s|$)/);
  return m ? m[0] : sentence(t);
}

const nixFiles = (dir: string) =>
  readdirSync(join(repo, dir))
    .filter((f) => !f.startsWith("_") && !f.startsWith("."))
    .sort();

// --- Darwin feature modules -> knowledge/modules/<name>.md ------------------
const moduleNames = new Set<string>();
console.log("darwin feature modules:");
for (const entry of nixFiles("modules/darwin")) {
  let name: string, srcRel: string;
  if (entry.endsWith(".nix")) {
    name = entry.replace(/\.nix$/, "");
    srcRel = `modules/darwin/${entry}`;
  } else if (existsSync(join(repo, "modules/darwin", entry, "default.nix"))) {
    name = entry;
    srcRel = `modules/darwin/${entry}/default.nix`;
  } else continue;
  moduleNames.add(name);

  const src = read(srcRel);
  const desc =
    firstMatch(src, /description\s*=\s*"([^"]+)"/) ??
    firstMatch(src, /mkEnableOption\s+"([^"]+)"/) ??
    leadingComment(src) ??
    `Darwin feature module '${name}'`;
  const option = firstMatch(src, /options\.([A-Za-z0-9_.-]+?)(?:\s*=|\.enable)/);
  const readme = existsSync(join(repo, `modules/darwin/${name}/README.md`))
    ? `modules/darwin/${name}/README.md`
    : null;
  const stow = existsSync(join(repo, "home", name)) ? `home/${name}/` : null;

  const lines = [
    mdSafe(sentence(desc)),
    "",
    "Follows the [module option pattern](../patterns/module-option-pattern.md), auto-discovered",
    "via the [Dendritic module layout](../patterns/dendritic-modules.md).",
    "",
    "## Source",
    "",
    `- Module: [\`${srcRel}\`](../../${srcRel})`,
  ];
  if (option) lines.push(`- Options under: \`${option}\``);
  if (stow) lines.push(`- Stow package: [\`${stow}\`](../../${stow}) — see the [stow tree pattern](../patterns/stow-tree.md)`);
  if (readme) lines.push(`- README: [\`${readme}\`](../../${readme})`);

  emit(`modules/${name}.md`, {
    type: "Darwin Module",
    title: titleFromSlug(name),
    description: firstSentence(desc),
    resource: srcRel,
    tags: ["darwin-module"],
    timestamp: gitISO(srcRel),
  }, lines.join("\n"));
}

// --- Flake plumbing modules -> knowledge/modules/<name>.md ------------------
console.log("flake-parts plumbing modules:");
for (const entry of nixFiles("modules").filter((f) => f.endsWith(".nix"))) {
  const name = entry.replace(/\.nix$/, "");
  const srcRel = `modules/${entry}`;
  const src = read(srcRel);
  const desc = leadingComment(src) ?? `Flake-parts plumbing module '${name}'`;
  moduleNames.add(name);
  emit(`modules/${name}.md`, {
    type: "Flake-parts Module",
    title: titleFromSlug(name),
    description: firstSentence(desc),
    resource: srcRel,
    tags: ["flake-parts"],
    timestamp: gitISO(srcRel),
  }, [
    mdSafe(sentence(desc)),
    "",
    "Plumbing layer of the flake — see the [Dendritic module layout](../patterns/dendritic-modules.md).",
    "",
    "## Source",
    "",
    `- Module: [\`${srcRel}\`](../../${srcRel})`,
  ].join("\n"));
}

// --- Hosts -> knowledge/hosts/<name>.md --------------------------------------
console.log("hosts:");
for (const entry of nixFiles("modules/hosts").filter((f) => f.endsWith(".nix"))) {
  const name = entry.replace(/\.nix$/, "");
  const srcRel = `modules/hosts/${entry}`;
  const src = read(srcRel);
  const desc = leadingComment(src) ?? `Host configuration '${name}'`;
  const features = [...src.matchAll(/([A-Za-z0-9_-]+)\.enable\s*=\s*true/g)]
    .map((m) => m[1])
    .filter((f) => moduleNames.has(f));
  const featureLines = [...new Set(features)].sort().map((f) => `- [${f}](../modules/${f}.md)`);

  emit(`hosts/${name}.md`, {
    type: "Host",
    title: name,
    description: firstSentence(desc),
    resource: srcRel,
    tags: ["host"],
    timestamp: gitISO(srcRel),
  }, [
    mdSafe(sentence(desc)),
    "",
    "## Enabled features",
    "",
    ...(featureLines.length ? featureLines : ["- (defaults only)"]),
    "",
    "## Source",
    "",
    `- Host module: [\`${srcRel}\`](../../${srcRel})`,
  ].join("\n"));
}

// --- Custom packages -> knowledge/packages/<name>.md -------------------------
console.log("packages:");
const pkgNames = new Set<string>();
for (const entry of nixFiles("pkgs").filter((f) => f.endsWith(".nix"))) {
  const name = entry.replace(/\.nix$/, "");
  pkgNames.add(name);
  const srcRel = `pkgs/${entry}`;
  const src = read(srcRel);
  const desc =
    firstMatch(src, /description\s*=\s*"([^"]+)"/) ??
    leadingComment(src) ??
    `Custom Nix package '${name}'`;
  const version = firstMatch(src, /version\s*=\s*"([^"]+)"/);
  const overlay = existsSync(join(repo, `overlays/${name}.nix`)) ? `overlays/${name}.nix` : null;

  const lines = [
    mdSafe(sentence(desc)),
    "",
    `Added per the [add-package playbook](../playbooks/add-package.md).`,
    "",
    "## Source",
    "",
    `- Package: [\`${srcRel}\`](../../${srcRel})`,
  ];
  if (version) lines.push(`- Version at last scaffold: \`${version}\``);
  if (overlay)
    lines.push(`- Overlay: [\`${overlay}\`](../../${overlay}) — exposes/replaces \`pkgs.${name}\``);

  emit(`packages/${name}.md`, {
    type: "Nix Package",
    title: titleFromSlug(name),
    description: firstSentence(desc),
    resource: srcRel,
    tags: ["package"],
    timestamp: gitISO(srcRel),
  }, lines.join("\n"));
}

// --- Overlay-only entries (no pkgs/ counterpart) ------------------------------
for (const entry of nixFiles("overlays").filter((f) => f.endsWith(".nix"))) {
  const name = entry.replace(/\.nix$/, "");
  if (pkgNames.has(name)) continue;
  const srcRel = `overlays/${entry}`;
  const src = read(srcRel);
  const desc = leadingComment(src) ?? `Nixpkgs overlay '${name}'`;
  emit(`packages/${name}.md`, {
    type: "Overlay",
    title: titleFromSlug(name),
    description: firstSentence(desc),
    resource: srcRel,
    tags: ["overlay"],
    timestamp: gitISO(srcRel),
  }, [
    mdSafe(sentence(desc)),
    "",
    "## Source",
    "",
    `- Overlay: [\`${srcRel}\`](../../${srcRel})`,
  ].join("\n"));
}

// --- Sub-flakes -> knowledge/packages/<name>.md -------------------------------
console.log("sub-flakes:");
for (const entry of nixFiles("flakes")) {
  const flakeRel = `flakes/${entry}/flake.nix`;
  if (!existsSync(join(repo, flakeRel))) continue;
  const src = read(flakeRel);
  const desc = firstMatch(src, /description\s*=\s*"([^"]+)"/) ?? `Sub-flake '${entry}'`;
  const readme = existsSync(join(repo, `flakes/${entry}/README.md`))
    ? `flakes/${entry}/README.md`
    : null;
  const lines = [
    mdSafe(sentence(desc)),
    "",
    "Consumed by the root flake as a relative-path input — see the",
    "[sub-flake extraction pattern](../patterns/subflake-extraction.md).",
    "",
    "## Source",
    "",
    `- Flake: [\`flakes/${entry}/\`](../../flakes/${entry}/)`,
  ];
  if (readme) lines.push(`- README: [\`${readme}\`](../../${readme})`);
  emit(`packages/${entry}.md`, {
    type: "Sub-flake",
    title: entry,
    description: firstSentence(desc),
    resource: `flakes/${entry}/`,
    tags: ["sub-flake", "package"],
    timestamp: gitISO(`flakes/${entry}`),
  }, lines.join("\n"));
}

// --- Neovim plugins -> knowledge/nvim/plugins/<name>.md ----------------------
// Each spec file under lua/plugins/ (or dir with init.lua) is one plugin,
// dispatched by lua/config/pack.lua — see knowledge/nvim/architecture.md.
console.log("neovim plugins:");
const NVIM_PLUGINS = "home/nvim/.config/nvim/lua/plugins";
for (const entry of nixFiles(NVIM_PLUGINS)) {
  let name: string, srcRel: string, resource: string;
  if (entry.endsWith(".lua")) {
    name = entry.replace(/\.lua$/, "");
    srcRel = `${NVIM_PLUGINS}/${entry}`;
    resource = srcRel;
  } else if (existsSync(join(repo, NVIM_PLUGINS, entry, "init.lua"))) {
    name = entry;
    srcRel = `${NVIM_PLUGINS}/${entry}/init.lua`;
    resource = `${NVIM_PLUGINS}/${entry}/`;
  } else continue;

  const src = read(srcRel);
  const desc = leadingLuaComment(src) ?? `Neovim plugin '${name}'`;
  const trigger =
    firstMatch(src, /trigger\s*=\s*"(\w+)"/) ??
    firstMatch(src, /trigger\s*=\s*\{\s*(ft|cmd|keys)/) ??
    "now";
  const version =
    firstMatch(src, /version\s*=\s*"([^"]+)"/) ??
    firstMatch(src, /version\s*=\s*(vim\.version\.range\([^)]*\))/);
  const urls = [...new Set([...src.matchAll(/src\s*=\s*"([^"]+)"/g)].map((m) => m[1]))];

  const lines = [
    mdSafe(sentence(desc)),
    "",
    "Declared as a pack spec under `lua/plugins/` and dispatched by the",
    "[plugin architecture](../architecture.md) (trigger: `" + trigger + "`).",
    "",
    "## Source",
    "",
    `- Spec: [\`${resource}\`](../../../${resource})`,
  ];
  if (urls.length) lines.push(`- Upstream: <${urls[0]}>`);
  for (const dep of urls.slice(1)) lines.push(`- Bundled dep: <${dep}>`);
  if (version) lines.push(`- Version pin: \`${version}\``);

  emit(`nvim/plugins/${name}.md`, {
    type: "Neovim Plugin",
    title: titleFromSlug(name),
    description: firstSentence(desc),
    resource,
    tags: ["nvim-plugin"],
    timestamp: gitISO(srcRel),
  }, lines.join("\n"));
}

console.log(`\nscaffold: ${written} written, ${skipped} skipped (existing)${FORCE ? " [--force]" : ""}`);
