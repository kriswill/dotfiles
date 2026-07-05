// CLI for maintaining an OKF knowledge bundle. Run `okf help` for usage;
// workspace settings live in the repo-root okf.toml (see init). A wrapper
// may set OKF_PROG so usage shows the name the user actually typed.

import { c } from "./lib";

interface Cmd {
  file: string;
  args: string;
  brief: string; // one line, for the command table ({bundle}/{viz-out} substituted)
  summary: string; // full detail, for `okf help <cmd>`
  flags: [string, string][];
}

const commands: Record<string, Cmd> = {
  init: {
    file: "./init.ts",
    args: "[--dir=<dir>]",
    brief: "create a starter okf.toml + bundle skeleton here",
    summary: "Bootstrap an okf workspace in the current directory: a commented starter okf.toml (this directory becomes the workspace root) plus the bundle skeleton (<dir>/index.md with okf_version frontmatter, <dir>/log.md). Never overwrites — re-running on an initialized workspace is a no-op.",
    flags: [["--dir=<dir>", "bundle directory for the new workspace (default: knowledge)"]],
  },
  scaffold: {
    file: "./scaffold.ts",
    args: "[--force]",
    brief: "stub concept docs from the workspace sources",
    summary: "Run the workspace's scaffold hooks from okf.toml [scaffold]: a repo-owned script (dynamically imported with the ScaffoldContext API) and/or command (spawned with OKF_* env), then the declarative [[scaffold.collect]] entries (glob + templates). Idempotent: existing docs are never touched, so hand enrichment survives re-runs.",
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
    summary: "Check OKF v0.1 + profile conformance: frontmatter, required fields, reserved files, link style, dangling links. The profile policy comes from okf.toml [profile]. Exits 1 on errors.",
    flags: [["--strict", "treat warnings (missing recommended fields, dangling links) as errors"]],
  },
  viz: {
    file: "./viz.ts",
    args: "[--check] [--perf]",
    brief: "render the 3D graph at {viz-out}",
    summary: "Render the bundle as a self-contained interactive 3D graph at {viz-out} (gitignored) — a Svelte 5 viewer around Three.js glow spheres with bloom, orbit camera with fly-to, frozen generation-time layout. Referenced source files are embedded with syntax highlighting; resource paths and file links open an in-panel preview, referenced directories open a browsable listing of their tracked files, and revision citations verified against the workspace link out to the forge (vcs.commit-url-template). Workspace strings and settings (header/title, facet filters, type taxonomy and legend groups, embed cap, bundle dir) come from the optional okf.toml; without it the viewer builds with generic fallbacks. Build-phase timings print on every run; the page records startup marks on window.__okf.perf.",
    flags: [
      ["--check", "typecheck the viewer app (svelte-check) instead of building"],
      ["--perf", "after building, measure viewer startup in headless Chrome and print a timing table"],
    ],
  },
};

const prog = process.env.OKF_PROG ?? "bun okf.ts";

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

/** Fill {bundle}/{viz-out} from the workspace config (quiet: broken config
 *  must never break help). Loaded lazily — only the help paths pay for it. */
async function helpSubst(): Promise<(s: string) => string> {
  const { quietBundleInfo } = await import("./config-cli");
  const b = quietBundleInfo();
  const sub = (s: string) =>
    s.split("{viz-out}").join(`${b.dir}/${b.out}`).split("{bundle}").join(b.dir);
  (helpSubst as { profileDoc?: string | null }).profileDoc = b.profileDoc;
  return sub;
}

async function usage() {
  const sub = await helpSubst();
  const rows = Object.entries(commands).map(
    ([name, cmd]) =>
      `  ${c.cyan(name.padEnd(10))}${cmd.args ? sub(cmd.brief).padEnd(50) + c.yellow(cmd.args) : sub(cmd.brief)}`,
  );
  const profileDoc = (helpSubst as { profileDoc?: string | null }).profileDoc;
  console.log(
    [
      `${c.bold("okf")} ${c.dim("—")} maintain the ${c.cyan(sub("{bundle}/"))} OKF bundle`,
      "",
      `${c.bold("Usage:")} ${prog} ${c.cyan("<command>")} ${c.yellow("[flags]")}   ${c.dim(`· ${prog} help <command> for details`)}`,
      "",
      ...rows,
      "",
      `${c.bold("Loop:")}  ${c.cyan("scaffold && index")} ${c.dim("after adding components")} · ${c.cyan("validate")} ${c.dim("before committing")}`,
      `${c.bold("Config:")} okf.toml ${c.dim("at the workspace root (all sections optional; see the okf README)")}${
        profileDoc ? ` ${c.dim("·")} ${profileDoc}` : ""
      }`,
    ].join("\n"),
  );
}

async function commandHelp(name: string) {
  const sub = await helpSubst();
  const t = commands[name];
  console.log(`${c.bold("Usage:")} ${prog} ${c.cyan(name)} ${c.yellow(t.args)}\n\n${wrap(sub(t.summary), 0)}`);
  for (const [flag, desc] of t.flags) console.log(`\n  ${c.yellow(flag)}  ${desc}`);
}

const [cmd, ...rest] = process.argv.slice(2);

if (!cmd || cmd === "help" || cmd === "--help" || cmd === "-h") {
  const topic = cmd === "help" ? rest[0] : undefined;
  if (topic && commands[topic]) await commandHelp(topic);
  else await usage();
  process.exit(0);
}

if (!commands[cmd]) {
  console.error(`${c.red("error:")} unknown command ${c.bold(cmd)}\n`);
  await usage();
  process.exit(1);
}

if (rest.includes("--help") || rest.includes("-h")) {
  await commandHelp(cmd);
  process.exit(0);
}

// A declared "--flag=<x>" accepts any "--flag=…" spelling.
const matches = (spec: string, arg: string) =>
  spec.includes("=") ? arg.startsWith(spec.slice(0, spec.indexOf("=") + 1)) : spec === arg;
const unknownFlag = rest.find((a) => !commands[cmd].flags.some(([f]) => matches(f, a)));
if (unknownFlag) {
  console.error(`${c.red("error:")} unknown flag ${c.bold(unknownFlag)} for ${c.cyan(cmd)} — try ${prog} help ${cmd}`);
  process.exit(1);
}

await import(commands[cmd].file);
