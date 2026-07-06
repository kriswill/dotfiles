// Scaffold pass: Neovim plugins -> knowledge/nvim/plugins/<name>.md.
// Each spec file under lua/plugins/ (or dir with init.lua) is one plugin,
// dispatched by lua/config/pack.lua — see knowledge/nvim/architecture.md.

import type { ScaffoldContext } from "./scaffold-api";
import type { Repo } from "./lib";

export function scaffoldNvim(ctx: ScaffoldContext, repo: Repo): void {
  const { emit, titleFromSlug, sentence, firstSentence, mdSafe, firstMatch } = ctx;
  const gitISO = ctx.timestamp;

  /** Leading `-- …` comment block at the top of a .lua file, joined. */
  const leadingLuaComment = (src: string) => ctx.leadingComment(src, "--");

  console.log("neovim plugins:");
  const NVIM_PLUGINS = "home/nvim/.config/nvim/lua/plugins";
  for (const entry of repo.nixFiles(NVIM_PLUGINS)) {
    let name: string, srcRel: string, resource: string;
    if (entry.endsWith(".lua")) {
      name = entry.replace(/\.lua$/, "");
      srcRel = `${NVIM_PLUGINS}/${entry}`;
      resource = srcRel;
    } else if (repo.exists(`${NVIM_PLUGINS}/${entry}/init.lua`)) {
      name = entry;
      srcRel = `${NVIM_PLUGINS}/${entry}/init.lua`;
      resource = `${NVIM_PLUGINS}/${entry}/`;
    } else continue;

    const src = repo.read(srcRel);
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
}
