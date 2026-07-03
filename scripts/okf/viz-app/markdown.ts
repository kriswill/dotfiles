// Minimal markdown renderer for concept bodies — headings, ul/ol with
// hard-wrap continuations, fences, pipe tables, inline code/bold/em/links,
// and autolinking of bare repo paths that resolve to embedded files.

export const esc = (s: unknown) =>
  String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]!);

export interface MdCtx {
  files: Record<string, unknown>;
  byId: Record<string, unknown>;
}

export function createMd({ files, byId }: MdCtx) {
  /** Resolve a relative link target against a repo-root-relative directory. */
  function resolveRel(dir: string[], target: string): string | null {
    if (/^[a-z][a-z0-9+.-]*:/.test(target) || target.startsWith("#")) return null;
    const base = [...dir];
    for (const part of target.split("#")[0].split("/")) {
      if (part === "" || part === ".") continue;
      if (part === "..") base.pop();
      else base.push(part);
    }
    return base.join("/");
  }

  /** Directory (repo-relative) a concept's links resolve against. */
  const conceptDir = (fromId: string) => ("knowledge/" + fromId).split("/").slice(0, -1);

  /** Concept id if a repo-relative path is a bundle document, else null. */
  const conceptOf = (p: string | null) =>
    p && p.startsWith("knowledge/") && p.endsWith(".md") && byId[p.slice(10, -3)] ? p.slice(10, -3) : null;

  function resolveMd(fromId: string, target: string): string | null {
    return conceptOf(resolveRel(conceptDir(fromId), target));
  }

  function resolveRepoFile(fromId: string, target: string): string | null {
    const p = resolveRel(conceptDir(fromId), target);
    return p && files[p] ? p : null;
  }

  /** Wrap bare repo-path mentions in file links; skips text inside anchors. */
  function autolinkPaths(html: string): string {
    let inA = 0;
    return html
      .split(/(<[^>]*>)/)
      .map((seg) => {
        if (seg.startsWith("<")) {
          if (/^<a[\s>]/i.test(seg)) inA++;
          else if (/^<\/a>/i.test(seg)) inA = Math.max(0, inA - 1);
          return seg;
        }
        if (inA) return seg;
        return seg.replace(
          /(^|[\s(])((?:\.\/)?(?:[\w.-]+\/)+[\w.-]+\.[A-Za-z0-9]{1,6})/g,
          (m, pre, p) => {
            const rel = p.replace(/^\.\//, "");
            return files[rel] ? `${pre}<a href="#" data-file="${rel}">${p}</a>` : m;
          },
        );
      })
      .join("");
  }

  const inlineRaw = (s: string, dir: string[]) =>
    esc(s)
      .replace(
        /&lt;(https?:\/\/(?:[^&\s]|&amp;)+)&gt;/g,
        '<a href="$1" target="_blank" rel="noopener">$1</a>',
      )
      .replace(/`([^`]+)`/g, "<code>$1</code>")
      .replace(/\*\*([^*]+)\*\*/g, "<b>$1</b>")
      .replace(/(?<![\w*])\*(\S(?:[^*\n]*\S)?)\*(?![\w*])/g, "<em>$1</em>")
      .replace(/(?<!!)\[([^\]]*)\]\(([^)\s]+)\)/g, (_m, txt, href) => {
        const p = resolveRel(dir, href);
        const nid = conceptOf(p);
        if (nid) return `<a href="#" data-node="${esc(nid)}">${txt}</a>`;
        if (p && files[p]) return `<a href="#" data-file="${esc(p)}">${txt}</a>`;
        if (/^https?:/.test(href)) return `<a href="${esc(href)}" target="_blank" rel="noopener">${txt}</a>`;
        return `<a title="${esc(href)}">${txt}</a>`;
      });

  function render(md: string, dir: string[]): string {
    const inline = (s: string) => autolinkPaths(inlineRaw(s, dir));
    const out: string[] = [];
    let inFence = false;
    let fence: string[] = [];
    let list: { type: string; items: string[] } | null = null;
    let para: string[] = [];
    let tbl: string[] = [];
    const flushList = () => {
      if (list) {
        out.push(`<${list.type}><li>${list.items.join("</li><li>")}</li></${list.type}>`);
        list = null;
      }
    };
    const flushPara = () => {
      if (para.length) {
        out.push(`<p>${para.join(" ")}</p>`);
        para = [];
      }
    };
    const splitRow = (line: string) =>
      line
        .trim()
        .replace(/^\|/, "")
        .replace(/\|$/, "")
        .split(/(?<!\\)\|/)
        .map((c) => c.trim().replace(/\\\|/g, "|"));
    const flushTable = () => {
      if (!tbl.length) return;
      const lines = tbl;
      tbl = [];
      const sep = lines.length > 1 ? splitRow(lines[1]) : null;
      if (!sep || !sep.every((c) => /^:?-+:?$/.test(c))) {
        // Not a real table (no delimiter row) — keep old paragraph behavior.
        for (const l of lines) para.push(inline(l));
        flushPara();
        return;
      }
      const align = sep.map((c) =>
        c.startsWith(":") && c.endsWith(":") ? "center" : c.endsWith(":") ? "right" : "",
      );
      const row = (tag: string, cells: string[]) =>
        cells
          .map((c, i) => `<${tag}${align[i] ? ` style="text-align:${align[i]}"` : ""}>${inline(c)}</${tag}>`)
          .join("");
      const head = `<thead><tr>${row("th", splitRow(lines[0]))}</tr></thead>`;
      const body = lines
        .slice(2)
        .map((l) => `<tr>${row("td", splitRow(l))}</tr>`)
        .join("");
      out.push(`<div class="tbl-wrap"><table>${head}${body ? `<tbody>${body}</tbody>` : ""}</table></div>`);
    };
    for (const line of md.split("\n")) {
      if (/^(```|~~~)/.test(line)) {
        flushTable();
        flushList();
        flushPara();
        if (inFence) {
          out.push(`<pre><code>${esc(fence.join("\n"))}</code></pre>`);
          fence = [];
        }
        inFence = !inFence;
        continue;
      }
      if (inFence) {
        fence.push(line);
        continue;
      }
      if (/^\s*\|/.test(line) && line.trim().length > 1) {
        flushList();
        flushPara();
        tbl.push(line);
        continue;
      }
      flushTable();
      const h = line.match(/^(#{1,4})\s+(.*)/);
      if (h) {
        flushList();
        flushPara();
        out.push(`<h3>${inline(h[2])}</h3>`);
        continue;
      }
      const ul = line.match(/^\s*[-*]\s+(.*)/);
      const ol = ul ? null : line.match(/^\s*\d+[.)]\s+(.*)/);
      if (ul || ol) {
        flushPara();
        const type = ul ? "ul" : "ol";
        if (list && list.type !== type) flushList();
        list = list || { type, items: [] };
        list.items.push(inline((ul || ol)![1]));
        continue;
      }
      if (list && /^\s{2,}\S/.test(line)) {
        list.items[list.items.length - 1] += " " + inline(line.trim());
        continue;
      }
      if (!line.trim()) {
        flushList();
        flushPara();
        continue;
      }
      flushList();
      para.push(inline(line));
    }
    flushTable();
    flushList();
    flushPara();
    if (inFence) out.push(`<pre><code>${esc(fence.join("\n"))}</code></pre>`);
    return out.join("");
  }

  /** Render a concept body; links resolve relative to the concept's id. */
  const mdToHtml = (md: string, fromId: string) => render(md, conceptDir(fromId));

  /** Render an embedded repo markdown file; links resolve relative to it. */
  const mdFileToHtml = (md: string, path: string) => render(md, path.split("/").slice(0, -1));

  return { mdToHtml, mdFileToHtml, autolinkPaths, resolveMd, resolveRepoFile };
}
