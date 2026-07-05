// Bootstrap an okf workspace in the CURRENT DIRECTORY (which becomes the
// workspace root — discovery finds the okf.toml written here): a commented
// starter config plus the bundle skeleton (<dir>/index.md, <dir>/log.md).
// Strictly a bootstrapper: never overwrites; re-running is a no-op. Does not
// load the workspace context — init must work where none exists yet.

import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { basename, join } from "node:path";
import { c } from "./lib";

const dirArg = process.argv.find((a) => a.startsWith("--dir="))?.slice("--dir=".length);
const dir = (dirArg ?? "knowledge").replace(/\/+$/, "");
if (!dir || dir.startsWith("/") || dir.split("/").includes("..")) {
  console.error('init: --dir must be a non-empty relative path without ".."');
  process.exit(1);
}

const TOML = `# okf.toml — workspace settings for the okf CLI (all sections optional;
# this file's directory is the workspace root). Reference: the okf README.

[bundle]
dir = "${dir}" # OKF bundle root, workspace-relative
# out = "viz.html"               # viz output file, relative to the bundle dir

# [profile]                      # validation policy (defaults shown)
# required-fields = ["type"]
# recommended-fields = ["title", "description", "timestamp"]
# reserved-files = ["index.md", "log.md"]
# rooted-links = "error"         # "error" | "allow"
# repo-links = "check"           # "check" | "ignore" | "forbid"

# [vcs]
# provider = "auto"              # "auto" | "git" | "none" (no VCS: fs walk + mtime)
# ignore = ["dist/**"]           # none-provider ignore globs
# url = ""                       # repo web URL ("" = derive from the remote, any forge)
# commit-url-template = "{url}/commit/{hash}"   # GitLab: "{url}/-/commit/{hash}"

[display]
title = "OKF knowledge graph"    # <title> = "<name> — <title>"
# badge = "OKF viz"              # sidebar h1 suffix label
# name = ""                      # header name override ("" = derive owner/repo)
# date-format = "iso"            # "iso" | "us" | "international"
# about-html = """Help-bubble text (trusted HTML)."""

# [scaffold]                     # the workspace's metadata pass (okf scaffold)
# script = "scripts/okf-scaffold.ts"  # TS/JS module; default export gets the ScaffoldContext API
# command = ["python3", "tools/scaffold.py"]  # non-JS alternative (OKF_* env); exclusive with script
# [[scaffold.collect]]           # declarative tier: glob + templates
# glob = "src/**/*.py"
# type = "Module"
# output = "modules/{name}.md"
# comment = "#"                  # leading-comment marker for descriptions

# [taxonomy]                     # viz legend/palette
# types = ["Decision", "Module"] # palette slot order — append-only
# group-order = ["Knowledge"]
# [taxonomy.dir-groups]          # top-level bundle dir -> legend cluster
# decisions = "Knowledge"

# [facet.status]                 # 0..n filter lenses (viz)
# values = ["draft", "final"]
# frontmatter = "status"         # read a frontmatter key as the value
`;

const INDEX = `---
okf_version: '0.1'
---

# ${basename(dir)}

Describe this bundle here — the blurb above the first heading is
hand-maintained and survives \`okf index\` regeneration.
`;

const LOG = `# Log

## ${new Date().toISOString().slice(0, 10)}

- **Creation** — bundle initialized by \`okf init\`.
`;

const cwd = process.cwd();
const created: string[] = [];
const put = (rel: string, content: string) => {
  const abs = join(cwd, rel);
  if (existsSync(abs)) return;
  mkdirSync(join(abs, ".."), { recursive: true });
  writeFileSync(abs, content);
  created.push(rel);
  console.log(`  + ${rel}`);
};

put("okf.toml", TOML);
put(`${dir}/index.md`, INDEX);
put(`${dir}/log.md`, LOG);

if (!created.length) {
  console.log(`init: already initialized (okf.toml, ${dir}/index.md, ${dir}/log.md all exist) — nothing written`);
} else {
  const prog = process.env.OKF_PROG ?? "bun okf.ts";
  console.log(
    [
      "",
      `Workspace initialized at ${cwd}`,
      "",
      `Next steps:`,
      `  ${c.cyan(`${prog} validate`)}   ${c.dim("conformance + links (should already pass)")}`,
      `  ${c.cyan(`${prog} index`)}      ${c.dim("regenerate index.md listings as concepts appear")}`,
      `  ${c.cyan(`${prog} viz`)}        ${c.dim(`render the graph at ${dir}/viz.html`)}`,
      `  ${c.dim("wire your metadata pass via [scaffold] in okf.toml, then")} ${c.cyan(`${prog} scaffold`)}`,
    ].join("\n"),
  );
}
