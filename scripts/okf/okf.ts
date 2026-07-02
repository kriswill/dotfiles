// CLI for the knowledge/ OKF bundle. Run `okf help` (dev shell) or
// `bun scripts/okf/okf.ts help` for usage; conventions live in
// knowledge/okf-profile.md. The dev-shell wrapper (modules/dev.nix) sets
// OKF_PROG so usage shows the name you actually typed.

import { c } from "./lib";

interface Cmd {
  file: string;
  args: string;
  summary: string;
  flags: [string, string][];
}

const commands: Record<string, Cmd> = {
  scaffold: {
    file: "./scaffold.ts",
    args: "[--force]",
    summary: "Stub catalog docs (modules/hosts/packages) from the repo sources. Idempotent: existing docs are never touched, so hand enrichment survives re-runs.",
    flags: [["--force", "overwrite existing docs with fresh stubs (discards enrichment)"]],
  },
  index: {
    file: "./index-gen.ts",
    args: "",
    summary: "Regenerate every index.md listing (OKF progressive disclosure). The hand-written blurb above the first heading is preserved; listings are rebuilt.",
    flags: [],
  },
  validate: {
    file: "./validate.ts",
    args: "[--strict]",
    summary: "Check OKF v0.1 + profile conformance: frontmatter, required fields, reserved files, link style, dangling links. Exits 1 on errors.",
    flags: [["--strict", "treat warnings (missing recommended fields, dangling links) as errors"]],
  },
  viz: {
    file: "./viz.ts",
    args: "",
    summary: "Render the bundle as a self-contained interactive graph at knowledge/viz.html (gitignored) — nodes by type, edges from cross-links, backlink panel.",
    flags: [],
  },
};

const prog = process.env.OKF_PROG ?? "bun scripts/okf/okf.ts";

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
  const out: string[] = [
    `${c.bold("okf")} — maintain the ${c.cyan("knowledge/")} OKF bundle (patterns, decisions, playbooks, catalog)`,
    "",
    `${c.bold("Usage:")} ${prog} ${c.cyan("<command>")} ${c.yellow("[flags]")}`,
    "",
    c.bold("Commands:"),
  ];
  for (const [name, cmd] of Object.entries(commands)) {
    out.push(`  ${c.cyan(name.padEnd(9))}${c.yellow(cmd.args.padEnd(11))}${wrap(cmd.summary, 22)}`);
    for (const [flag, desc] of cmd.flags) out.push(`             ${c.yellow(flag.padEnd(9))} ${c.dim(wrap(desc, 23))}`);
    out.push("");
  }
  out.push(
    c.bold("Typical loop:"),
    `  ${c.dim("after adding a module/package/host:")}  ${prog} scaffold ${c.dim("&&")} ${prog} index`,
    `  ${c.dim("before committing bundle changes:  ")}  ${prog} validate`,
    "",
    c.bold("Docs:"),
    `  ${c.cyan("knowledge/okf-profile.md")}             ${c.dim("conventions: frontmatter, links, headings")}`,
    `  ${c.cyan(".claude/skills/knowledge-bundle/")}     ${c.dim("when to update what (maintenance procedure)")}`,
  );
  console.log(out.join("\n"));
}

const [cmd, ...rest] = process.argv.slice(2);

if (!cmd || cmd === "help" || cmd === "--help" || cmd === "-h") {
  const topic = cmd === "help" ? rest[0] : undefined;
  if (topic && commands[topic]) {
    const t = commands[topic];
    console.log(`${c.bold("Usage:")} ${prog} ${c.cyan(topic)} ${c.yellow(t.args)}\n\n${wrap(t.summary, 0)}`);
    for (const [flag, desc] of t.flags) console.log(`\n  ${c.yellow(flag)}  ${desc}`);
  } else usage();
  process.exit(0);
}

if (!commands[cmd]) {
  console.error(`${c.red("error:")} unknown command ${c.bold(cmd)}\n`);
  usage();
  process.exit(1);
}

if (rest.includes("--help") || rest.includes("-h")) {
  const t = commands[cmd];
  console.log(`${c.bold("Usage:")} ${prog} ${c.cyan(cmd)} ${c.yellow(t.args)}\n\n${wrap(t.summary, 0)}`);
  for (const [flag, desc] of t.flags) console.log(`\n  ${c.yellow(flag)}  ${desc}`);
  process.exit(0);
}

const unknownFlag = rest.find((a) => !commands[cmd].flags.some(([f]) => f === a));
if (unknownFlag) {
  console.error(`${c.red("error:")} unknown flag ${c.bold(unknownFlag)} for ${c.cyan(cmd)} — try ${prog} help ${cmd}`);
  process.exit(1);
}

await import(commands[cmd].file);
