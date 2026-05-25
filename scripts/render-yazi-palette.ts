#!/usr/bin/env bun
// render-yazi-palette — regenerate the kanagawa palette documentation image
// from the theme's nix-generated flavor files.
//
// The flavor is now produced entirely by nix (flavor.toml via pkgs.formats.toml,
// tmtheme.xml via lib.generators.toPlist), so this script builds the
// `yazi-kanagawa-flavor` package and reads `flavor.toml` / `tmtheme.xml` from
// its store output — the exact files yazi consumes.
//
// Color *names* come from `lib/kanagawa.nix` (the shared name→hex palette,
// read with `nix eval`); usage comes from the flavor.toml tables and tmtheme
// scopes — so the image stays correct as the theme changes.
//
// Writes: modules/home-manager/yazi/_themes/kanagawa/palette.png
//
// Deps: bun, nix, ImageMagick (`magick`), and a SauceCodePro Nerd Font in the
// Nix store. Run from anywhere: `bun scripts/render-yazi-palette.ts`.

import { spawnSync } from "bun";
import { join } from "node:path";

const REPO = join(import.meta.dir, "..");
const PALETTE_NIX = join(REPO, "lib/kanagawa.nix");
const OUT = join(
  REPO,
  "modules/home-manager/yazi/_themes/kanagawa/palette.png",
);

const BG = "#16161d";
const PANEL = "#181616";
const FG = "#c5c9c5";
const MUTED = "#a6a69c";

// --- shell helpers ----------------------------------------------------------

function sh(cmd: string): string {
  const r = spawnSync(["bash", "-lc", cmd]);
  return r.success ? r.stdout.toString().trim() : "";
}

function magick(args: string[]): void {
  const r = spawnSync(["magick", ...args]);
  if (!r.success) {
    throw new Error(`magick failed: ${args.join(" ")}\n${r.stderr.toString()}`);
  }
}

function montage(args: string[]): void {
  const r = spawnSync(["montage", ...args]);
  if (!r.success) {
    throw new Error(`montage failed: ${args.join(" ")}\n${r.stderr.toString()}`);
  }
}

function identifyWidth(path: string): number {
  return Number(sh(`magick identify -format '%w' ${JSON.stringify(path)}`));
}

// Build the flavor derivation and return its store path ($out holds
// flavor.toml + tmtheme.xml). Errors out loudly — an empty result here would
// otherwise produce a blank image.
function buildFlavor(): string {
  const out = sh(
    `nix build ${JSON.stringify(REPO)}#yazi-kanagawa-flavor --no-link --print-out-paths`,
  );
  const path = out.split("\n").filter(Boolean).pop();
  if (!path) {
    throw new Error(
      "nix build .#yazi-kanagawa-flavor produced no output path — is the flake evaluable?",
    );
  }
  return path;
}

// hex(lowercase) → kanagawa color name, from the shared palette. On the rare
// hex shared by several names, the alphabetically-first wins (dragon* sorts
// ahead of lotus*, which suits this dark flavor).
function loadNames(): Map<string, string> {
  const json = sh(`nix eval --json --file ${JSON.stringify(PALETTE_NIX)}`);
  if (!json) throw new Error(`nix eval failed for ${PALETTE_NIX}`);
  const map = new Map<string, string>();
  for (const [name, hex] of Object.entries(JSON.parse(json) as Record<string, string>)) {
    const h = hex.toLowerCase();
    if (!map.has(h)) map.set(h, name);
  }
  return map;
}

function findFont(style: "Regular" | "Bold"): string {
  const env = process.env[style === "Bold" ? "FONT_BOLD" : "FONT_REGULAR"];
  if (env) return env;
  const hit = sh(
    `ls -d /nix/store/*nerd-fonts-sauce-code-pro*/share/fonts/truetype/NerdFonts/SauceCodePro/SauceCodeProNerdFontMono-${style}.ttf 2>/dev/null | head -1`,
  );
  if (!hit) {
    throw new Error(
      `Could not find SauceCodePro ${style} in /nix/store. ` +
        `Set FONT_${style === "Bold" ? "BOLD" : "REGULAR"} to a .ttf path.`,
    );
  }
  return hit;
}

const FREG = findFont("Regular");
const FBOLD = findFont("Bold");

// --- color / text utilities -------------------------------------------------

function luminance(hex: string): number {
  const h = hex.replace("#", "").slice(0, 6);
  const r = parseInt(h.slice(0, 2), 16);
  const g = parseInt(h.slice(2, 4), 16);
  const b = parseInt(h.slice(4, 6), 16);
  return (299 * r + 587 * g + 114 * b) / 1000;
}

// Text colors that read on a given swatch background.
function textColors(bg: string): { main: string; sub: string } {
  return luminance(bg) > 140
    ? { main: "#0d0c0c", sub: "#16161d" }
    : { main: FG, sub: MUTED };
}

function truncate(s: string, n: number): string {
  return s.length <= n ? s : s.slice(0, n - 1) + "…";
}

// --- swatch + layout primitives ---------------------------------------------

const SWATCH_W = 560;
const SWATCH_H = 120;
const COLS = 3;
let tmpCounter = 0;
const TMP = sh("mktemp -d");
process.on("exit", () => sh(`rm -rf ${JSON.stringify(TMP)}`));

interface Swatch {
  bg: string;
  name: string;
  hex: string;
  sub: string;
}

function renderSwatch(s: Swatch): string {
  const { main, sub } = textColors(s.bg);
  const path = join(TMP, `s${tmpCounter++}.png`);
  magick([
    "-size",
    `${SWATCH_W}x${SWATCH_H}`,
    `xc:${s.bg}`,
    "-font",
    FBOLD,
    "-fill",
    main,
    "-gravity",
    "West",
    "-pointsize",
    "30",
    "-annotate",
    "+24-28",
    truncate(s.name, 28),
    "-font",
    FREG,
    "-pointsize",
    "26",
    "-annotate",
    "+24+2",
    s.hex,
    "-fill",
    sub,
    "-pointsize",
    "16",
    "-annotate",
    "+24+34",
    truncate(s.sub, 54),
    path,
  ]);
  return path;
}

function renderGrid(swatches: Swatch[]): string {
  const paths = swatches.map(renderSwatch);
  const path = join(TMP, `grid${tmpCounter++}.png`);
  // `-font` is required even though tiles carry no labels: montage initializes
  // a default font and aborts when fontconfig has no usable default.
  montage([
    "-font",
    FREG,
    ...paths,
    "-tile",
    `${COLS}x`,
    "-geometry",
    "+8+8",
    "-background",
    BG,
    path,
  ]);
  return path;
}

function header(text: string, width: number, sub = ""): string {
  const path = join(TMP, `h${tmpCounter++}.png`);
  const args = [
    "-size",
    `${width}x${sub ? 80 : 60}`,
    `xc:${PANEL}`,
    "-font",
    FBOLD,
    "-fill",
    FG,
    "-gravity",
    "West",
    "-pointsize",
    "28",
    "-annotate",
    `+24${sub ? "-12" : "+0"}`,
    text,
  ];
  if (sub) {
    args.push("-font", FREG, "-fill", MUTED, "-pointsize", "16", "-annotate", "+26+18", sub);
  }
  args.push(path);
  magick(args);
  return path;
}

// --- parse flavor.toml -------------------------------------------------------

async function loadFlavor(
  flavorPath: string,
  names: Map<string, string>,
): Promise<Swatch[]> {
  const lines = (await Bun.file(flavorPath).text()).split("\n");

  // Usage: where each hex appears, kept in first-seen order so swatches group
  // by table. Labels are the dotted table path (e.g. `mgr.cwd`).
  const usage = new Map<string, string[]>();
  const add = (hex: string, where: string) => {
    hex = hex.toLowerCase();
    const arr = usage.get(hex) ?? [];
    if (!arr.includes(where)) arr.push(where);
    usage.set(hex, arr);
  };

  // A `[[filetype.rules]]` block spreads its fg/bg and its discriminator
  // (mime/is/url) across separate lines, so accumulate per block and flush on
  // the next header / EOF.
  let section = "";
  let ruleHexes: string[] = [];
  let ruleDisc = "";
  const flushRule = () => {
    for (const h of ruleHexes) {
      add(h, `filetype.rules${ruleDisc ? `:${truncate(ruleDisc, 16)}` : ""}`);
    }
    ruleHexes = [];
    ruleDisc = "";
  };

  for (const raw of lines) {
    const line = raw.trim();
    if (!line || line.startsWith("#")) continue;

    const header = line.match(/^\[\[?\s*([\w.]+)\s*\]\]?/);
    if (header) {
      flushRule();
      section = header[1];
      continue;
    }

    const hexes = [...line.matchAll(/#[0-9a-fA-F]{3,8}/g)].map((m) => m[0]);

    if (section === "filetype.rules") {
      ruleHexes.push(...hexes);
      // Prefer the most specific discriminator in the block (mime/is over url).
      const d = line.match(/^(mime|is|url)\s*=\s*"([^"]+)"/);
      if (d && (!ruleDisc || d[1] !== "url")) ruleDisc = d[2];
      continue;
    }

    for (const h of hexes) add(h, section);
  }
  flushRule();

  // One swatch per used hex, named from the shared palette.
  return [...usage.entries()].map(([hex, used]) => ({
    bg: hex,
    name: names.get(hex) ?? "(unnamed)",
    hex,
    sub:
      used.slice(0, 3).join(", ") +
      (used.length > 3 ? ` +${used.length - 3}` : ""),
  }));
}

// --- parse tmtheme.xml (minimal plist) --------------------------------------

type PVal = string | PVal[] | { [k: string]: PVal };

function parsePlist(xml: string): PVal {
  const decode = (s: string) =>
    s.replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">");
  // Note the self-closing forms (`<string/>`, `<dict/>`, …): tmtheme uses
  // `<string/>` for empty fontStyle values, and missing them desyncs the
  // token stream.
  const re =
    /<\/?(?:dict|array)>|<(?:dict|array)\/>|<key>[\s\S]*?<\/key>|<(?:string|integer|real)>[\s\S]*?<\/(?:string|integer|real)>|<(?:string|integer|real)\/>|<(?:true|false)\/>/g;
  type Tok =
    | { t: "open" | "close"; k: string }
    | { t: "key" | "scalar"; v: string };
  const toks: Tok[] = [];
  for (const m of xml.matchAll(re)) {
    const s = m[0];
    if (s === "<dict>") toks.push({ t: "open", k: "dict" });
    else if (s === "</dict>") toks.push({ t: "close", k: "dict" });
    else if (s === "<array>") toks.push({ t: "open", k: "array" });
    else if (s === "</array>") toks.push({ t: "close", k: "array" });
    else if (s === "<dict/>") toks.push({ t: "open", k: "dict" }, { t: "close", k: "dict" });
    else if (s === "<array/>") toks.push({ t: "open", k: "array" }, { t: "close", k: "array" });
    else if (s.startsWith("<key>")) toks.push({ t: "key", v: decode(s.slice(5, -6)) });
    else if (/^<(?:string|integer|real)\/>$/.test(s)) toks.push({ t: "scalar", v: "" });
    else if (s === "<true/>" || s === "<false/>") toks.push({ t: "scalar", v: s.slice(1, -2) });
    else toks.push({ t: "scalar", v: decode(s.replace(/^<\w+>/, "").replace(/<\/\w+>$/, "")) });
  }
  let p = 0;
  const value = (): PVal => {
    const tok = toks[p];
    if (tok.t === "open" && tok.k === "dict") {
      p++;
      const o: { [k: string]: PVal } = {};
      while (!(toks[p].t === "close" && (toks[p] as any).k === "dict")) {
        const key = (toks[p++] as any).v as string;
        o[key] = value();
      }
      p++;
      return o;
    }
    if (tok.t === "open" && tok.k === "array") {
      p++;
      const a: PVal[] = [];
      while (!(toks[p].t === "close" && (toks[p] as any).k === "array")) {
        a.push(value());
      }
      p++;
      return a;
    }
    p++;
    return (tok as any).v as string;
  };
  return value();
}

async function loadTmtheme(
  tmthemePath: string,
): Promise<{ global: Swatch[]; syntax: Swatch[] }> {
  const xml = await Bun.file(tmthemePath).text();
  const root = parsePlist(xml) as { [k: string]: PVal };
  const entries = root.settings as { [k: string]: PVal }[];

  // First entry (no scope) holds the global editor colors.
  const global: Swatch[] = [];
  const editor = (entries[0]?.settings as { [k: string]: string }) ?? {};
  const globalByHex = new Map<string, string[]>();
  for (const [key, hex] of Object.entries(editor)) {
    if (typeof hex !== "string" || !hex.startsWith("#")) continue;
    const arr = globalByHex.get(hex) ?? [];
    arr.push(key);
    globalByHex.set(hex, arr);
  }
  for (const [hex, keys] of globalByHex) {
    global.push({ bg: hex, name: keys[0], hex, sub: keys.join(" · ") });
  }

  // Remaining entries are scoped syntax styles; dedup by foreground color.
  const synByHex = new Map<
    string,
    { names: string[]; style: string }
  >();
  for (const e of entries.slice(1)) {
    const s = (e.settings as { [k: string]: string }) ?? {};
    const hex = s.foreground ?? s.background;
    if (!hex || !hex.startsWith("#")) continue;
    const cur = synByHex.get(hex) ?? { names: [], style: "" };
    const nm = (e.name as string) ?? (e.scope as string) ?? "?";
    if (!cur.names.includes(nm)) cur.names.push(nm);
    if (s.fontStyle) cur.style = s.fontStyle;
    synByHex.set(hex, cur);
  }
  const syntax: Swatch[] = [...synByHex.entries()].map(([hex, v]) => {
    const tag = v.style ? `[${v.style}] ` : "";
    return {
      bg: hex,
      name: v.names[0],
      hex,
      sub: tag + v.names.slice(1).join(", "),
    };
  });
  return { global, syntax };
}

// --- assemble ----------------------------------------------------------------

const store = buildFlavor();
const names = loadNames();
const flavor = await loadFlavor(join(store, "flavor.toml"), names);
const { global, syntax } = await loadTmtheme(join(store, "tmtheme.xml"));

const flavorGrid = renderGrid(flavor);
const W = identifyWidth(flavorGrid);
const globalGrid = renderGrid(global);
const syntaxGrid = renderGrid(syntax);

const title = (() => {
  const path = join(TMP, "title.png");
  magick([
    "-size",
    `${W}x110`,
    `xc:${BG}`,
    "-font",
    FBOLD,
    "-fill",
    FG,
    "-gravity",
    "West",
    "-pointsize",
    "42",
    "-annotate",
    "+28-12",
    "yazi theme — kanagawa",
    "-font",
    FREG,
    "-fill",
    MUTED,
    "-pointsize",
    "18",
    "-annotate",
    "+30+26",
    "_themes/kanagawa · regenerate with scripts/render-yazi-palette.ts",
    path,
  ]);
  return path;
})();

const pieces = [
  title,
  header(`UI theme · flavor.toml (${flavor.length} colors)`, W),
  flavorGrid,
  header(
    `Syntax · tmtheme.xml — editor (${global.length})`,
    W,
    "background, foreground, caret, selection & friends",
  ),
  globalGrid,
  header(`Syntax · tmtheme.xml — scopes (${syntax.length} unique colors)`, W),
  syntaxGrid,
];

magick([
  "-background",
  BG,
  ...pieces,
  "-append",
  "-bordercolor",
  BG,
  "-border",
  "16",
  OUT,
]);

const dims = sh(`magick identify -format '%wx%h' ${JSON.stringify(OUT)}`);
console.log(`wrote ${OUT} (${dims})`);
console.log(
  `  flavor: ${flavor.length} · tmtheme editor: ${global.length} · scopes: ${syntax.length}`,
);
