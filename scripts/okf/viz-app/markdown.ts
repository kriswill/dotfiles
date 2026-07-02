// Minimal markdown renderer for concept bodies — headings, ul/ol with
// hard-wrap continuations, fences, inline code/bold/em/links, and
// autolinking of bare repo paths that resolve to embedded files.

export const esc = (s: unknown) =>
  String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]!);

export interface MdCtx {
  files: Record<string, unknown>;
  byId: Record<string, unknown>;
}

export function createMd({ files, byId }: MdCtx) {
  function resolveMd(fromId: string, target: string): string | null {
    if (/^[a-z][a-z0-9+.-]*:/.test(target) || target.startsWith("#")) return null;
    const base = fromId.split("/").slice(0, -1);
    for (const part of target.split("#")[0].split("/")) {
      if (part === "" || part === ".") continue;
      if (part === "..") base.pop();
      else base.push(part);
    }
    const p = base.join("/");
    return p.endsWith(".md") && byId[p.slice(0, -3)] ? p.slice(0, -3) : null;
  }

  function resolveRepoFile(fromId: string, target: string): string | null {
    if (/^[a-z][a-z0-9+.-]*:/.test(target) || target.startsWith("#")) return null;
    const base = ("knowledge/" + fromId).split("/").slice(0, -1);
    for (const part of target.split("#")[0].split("/")) {
      if (part === "" || part === ".") continue;
      if (part === "..") base.pop();
      else base.push(part);
    }
    const p = base.join("/");
    return files[p] ? p : null;
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

  const inlineRaw = (s: string, fromId: string) =>
    esc(s)
      .replace(/`([^`]+)`/g, "<code>$1</code>")
      .replace(/\*\*([^*]+)\*\*/g, "<b>$1</b>")
      .replace(/(?<![\w*])\*(\S(?:[^*\n]*\S)?)\*(?![\w*])/g, "<em>$1</em>")
      .replace(/(?<!!)\[([^\]]*)\]\(([^)\s]+)\)/g, (_m, txt, href) => {
        const nid = resolveMd(fromId, href);
        if (nid) return `<a href="#" data-node="${esc(nid)}">${txt}</a>`;
        const fp = resolveRepoFile(fromId, href);
        if (fp) return `<a href="#" data-file="${esc(fp)}">${txt}</a>`;
        if (/^https?:/.test(href)) return `<a href="${esc(href)}" target="_blank" rel="noopener">${txt}</a>`;
        return `<a title="${esc(href)}">${txt}</a>`;
      });

  function mdToHtml(md: string, fromId: string): string {
    const inline = (s: string) => autolinkPaths(inlineRaw(s, fromId));
    const out: string[] = [];
    let inFence = false;
    let fence: string[] = [];
    let list: { type: string; items: string[] } | null = null;
    let para: string[] = [];
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
    for (const line of md.split("\n")) {
      if (/^(```|~~~)/.test(line)) {
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
    flushList();
    flushPara();
    if (inFence) out.push(`<pre><code>${esc(fence.join("\n"))}</code></pre>`);
    return out.join("");
  }

  return { mdToHtml, autolinkPaths, resolveMd, resolveRepoFile };
}
