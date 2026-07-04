// CLI for the knowledge/ OKF bundle. Run `okf help` (dev shell) or
// `bun flakes/okf/okf.ts help` for usage; conventions live in
// knowledge/okf-profile.md. The dev-shell wrapper (modules/dev.nix) sets
// OKF_PROG so usage shows the name you actually typed.

import { c } from "./lib";

interface Cmd {
  file: string;
  args: string;
  brief: string; // one line, for the command table
  summary: string; // full detail, for `okf help <cmd>`
  flags: [string, string][];
}

const commands: Record<string, Cmd> = {
  scaffold: {
    file: "./scaffold.ts",
    args: "[--force]",
    brief: "stub catalog docs for new modules/packages/hosts/nvim-plugins",
    summary: "Stub catalog docs (modules/hosts/packages/nvim-plugins) from the repo sources. Idempotent: existing docs are never touched, so hand enrichment survives re-runs.",
    flags: [["--force", "overwrite existing docs with fresh stubs (discards enrichment)"]],
  },
  index: {
    file: "./index-gen.ts",
    args: "",
    brief: "regenerate index.md listings",
    summary: "Regenerate every index.md listing (OKF progressive disclosure). The hand-written blurb above the first heading is preserved; listings are rebuilt.",
    flags: [],
  },
  validate: {
    file: "./validate.ts",
    args: "[--strict]",
    brief: "check conformance + links; exit 1 on errors",
    summary: "Check OKF v0.1 + profile conformance: frontmatter, required fields, reserved files, link style, dangling links. Exits 1 on errors.",
    flags: [["--strict", "treat warnings (missing recommended fields, dangling links) as errors"]],
  },
  viz: {
    file: "./viz.ts",
    args: "[--check] [--perf]",
    brief: "render the 3D graph at knowledge/viz.html",
    summary: "Render the bundle as a self-contained interactive 3D graph at knowledge/viz.html (gitignored) — a Svelte 5 viewer around Three.js glow spheres with bloom, orbit camera with fly-to, frozen generation-time layout. Referenced source files are embedded with syntax highlighting; resource paths and file links open an in-panel preview, referenced directories (sub-flakes, stow packages) open a browsable listing of their tracked files, and commit-hash citations verified against the repo link out to GitHub. Repo-specific strings and settings (header/title, facet filters, type taxonomy and legend groups, embed cap, bundle dir) come from an optional okf-viz.toml at the repo root; without it the viewer builds with generic fallbacks. Build-phase timings print on every run; the page records startup marks on window.__okf.perf.",
    flags: [
      ["--check", "typecheck the viewer app (svelte-check) instead of building"],
      ["--perf", "after building, measure viewer startup in headless Chrome and print a timing table"],
    ],
  },
};

const prog = process.env.OKF_PROG ?? "bun flakes/okf/okf.ts";

function wrap(text: string, indent: number, width = 78): string {
  const words = text.split(" ");
  const lines: string[] = [];
  let line = "";
  for (const w of words) {
    if (line && indent + line.length + 1 + w.length > width) {
      lines.push(line);
      line = w;
    } else line = line ? `${line} ${w}` : w;
  }
  if (line) lines.push(line);
  return lines.join("\n" + " ".repeat(indent));
}

function usage() {
  const rows = Object.entries(commands).map(
    ([name, cmd]) =>
      `  ${c.cyan(name.padEnd(10))}${cmd.args ? cmd.brief.padEnd(50) + c.yellow(cmd.args) : cmd.brief}`,
  );
  console.log(
    [
      `${c.bold("okf")} ${c.dim("—")} maintain the ${c.cyan("knowledge/")} OKF bundle`,
      "",
      `${c.bold("Usage:")} ${prog} ${c.cyan("<command>")} ${c.yellow("[flags]")}   ${c.dim(`· ${prog} help <command> for details`)}`,
      "",
      ...rows,
      "",
      `${c.bold("Loop:")}  ${c.cyan("scaffold && index")} ${c.dim("after adding components")} · ${c.cyan("validate")} ${c.dim("before committing")}`,
      `${c.bold("Docs:")}  knowledge/okf-profile.md ${c.dim("·")} .claude/skills/knowledge-bundle/`,
    ].join("\n"),
  );
}

function commandHelp(name: string) {
  const t = commands[name];
  console.log(`${c.bold("Usage:")} ${prog} ${c.cyan(name)} ${c.yellow(t.args)}\n\n${wrap(t.summary, 0)}`);
  for (const [flag, desc] of t.flags) console.log(`\n  ${c.yellow(flag)}  ${desc}`);
}

const [cmd, ...rest] = process.argv.slice(2);

if (!cmd || cmd === "help" || cmd === "--help" || cmd === "-h") {
  const topic = cmd === "help" ? rest[0] : undefined;
  if (topic && commands[topic]) commandHelp(topic);
  else usage();
  process.exit(0);
}

if (!commands[cmd]) {
  console.error(`${c.red("error:")} unknown command ${c.bold(cmd)}\n`);
  usage();
  process.exit(1);
}

if (rest.includes("--help") || rest.includes("-h")) {
  commandHelp(cmd);
  process.exit(0);
}

const unknownFlag = rest.find((a) => !commands[cmd].flags.some(([f]) => f === a));
if (unknownFlag) {
  console.error(`${c.red("error:")} unknown flag ${c.bold(unknownFlag)} for ${c.cyan(cmd)} — try ${prog} help ${cmd}`);
  process.exit(1);
}

await import(commands[cmd].file);
