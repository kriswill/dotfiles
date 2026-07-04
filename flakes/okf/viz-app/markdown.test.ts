// Characterization tests for the hand-rolled markdown renderer — written
// against the pre-refactor behavior; every case here is load-bearing for the
// detail panel.
import { describe, expect, test } from "bun:test";
import { createMd, esc } from "./markdown";

const ctx = {
  files: { "flakes/okf/viz.ts": {}, "modules/dev.nix": {}, "docs/svelt/manual.md": {} },
  byId: { "nvim/architecture": {}, "decisions/other": {} },
  dirs: { "flakes/ccglass": {} },
  repoUrl: "https://github.com/kriswill/dotfiles",
  commits: { abc1234: "abc1234def5678901234567890123456789012ab" },
};
const md = createMd(ctx);
const from = "decisions/foo"; // bundle-relative concept id

describe("esc", () => {
  test("escapes & < > \"", () => {
    expect(esc(`a & <b> "c"`)).toBe("a &amp; &lt;b&gt; &quot;c&quot;");
  });
});

describe("inline rendering", () => {
  test("code, bold, em", () => {
    expect(md.mdToHtml("has `code` **bold** *em* text", from)).toBe(
      "<p>has <code>code</code> <b>bold</b> <em>em</em> text</p>",
    );
  });

  test("verified commit-hash code span links out to GitHub by full oid", () => {
    expect(md.mdToHtml("landed in `abc1234` upstream", from)).toBe(
      '<p>landed in <code><a href="https://github.com/kriswill/dotfiles/commit/abc1234def5678901234567890123456789012ab"' +
        ' target="_blank" rel="noopener">abc1234</a></code> upstream</p>',
    );
  });

  test("unverified hex code span stays plain code", () => {
    expect(md.mdToHtml("nixpkgs rev `b5aa0fb`", from)).toBe("<p>nixpkgs rev <code>b5aa0fb</code></p>");
  });

  test("commit spans stay plain without a repoUrl", () => {
    const bare = createMd({ files: {}, byId: {}, commits: { abc1234: "abc1234def" } });
    expect(bare.mdToHtml("`abc1234`", from)).toBe("<p><code>abc1234</code></p>");
  });

  test("<https://…> autolink", () => {
    expect(md.mdToHtml("see <https://example.com/a?b=1>", from)).toBe(
      '<p>see <a href="https://example.com/a?b=1" target="_blank" rel="noopener">https://example.com/a?b=1</a></p>',
    );
  });

  test("concept link resolves to data-node", () => {
    expect(md.mdToHtml("[arch](../nvim/architecture.md)", from)).toBe(
      '<p><a href="#" data-node="nvim/architecture">arch</a></p>',
    );
  });

  test("concept links resolve under a non-default bundleDir (no hardcoded 'knowledge/' offsets)", () => {
    const kb = createMd({ ...ctx, bundleDir: "kb" });
    expect(kb.mdToHtml("[arch](../nvim/architecture.md)", from)).toBe(
      '<p><a href="#" data-node="nvim/architecture">arch</a></p>',
    );
    // Repo-file links resolve one level up from kb/<id>, not knowledge/<id>.
    expect(kb.mdToHtml("[viz](../../flakes/okf/viz.ts)", from)).toBe(
      '<p><a href="#" data-file="flakes/okf/viz.ts">viz</a></p>',
    );
  });

  test("repo-file link resolves to data-file", () => {
    expect(md.mdToHtml("[viz](../../flakes/okf/viz.ts)", from)).toBe(
      '<p><a href="#" data-file="flakes/okf/viz.ts">viz</a></p>',
    );
  });

  test("external link opens new tab", () => {
    expect(md.mdToHtml("[s](https://svelte.dev)", from)).toBe(
      '<p><a href="https://svelte.dev" target="_blank" rel="noopener">s</a></p>',
    );
  });

  test("unresolvable link degrades to title-only anchor", () => {
    expect(md.mdToHtml("[x](../nope.md)", from)).toBe('<p><a title="../nope.md">x</a></p>');
  });

  test("embedded-directory link resolves to data-dir (trailing slash dropped)", () => {
    expect(md.mdToHtml("[flake](../../flakes/ccglass/)", from)).toBe(
      '<p><a href="#" data-dir="flakes/ccglass">flake</a></p>',
    );
  });

  test("unembedded directory link degrades to title-only anchor", () => {
    expect(md.mdToHtml("[x](../../flakes/nope/)", from)).toBe('<p><a title="../../flakes/nope/">x</a></p>');
  });
});

describe("bare path autolinking", () => {
  test("bare embedded path becomes a data-file link", () => {
    expect(md.mdToHtml("see flakes/okf/viz.ts here", from)).toBe(
      '<p>see <a href="#" data-file="flakes/okf/viz.ts">flakes/okf/viz.ts</a> here</p>',
    );
  });

  test("path not in files stays plain", () => {
    expect(md.mdToHtml("see scripts/other/nope.ts here", from)).toBe("<p>see scripts/other/nope.ts here</p>");
  });

  test("text inside an existing anchor is not re-linked", () => {
    expect(md.mdToHtml("[flakes/okf/viz.ts](https://example.com)", from)).toBe(
      '<p><a href="https://example.com" target="_blank" rel="noopener">flakes/okf/viz.ts</a></p>',
    );
  });
});

describe("mdFileToHtml (embedded markdown files)", () => {
  const fromFile = "docs/svelt/learnings.md";

  test("relative links resolve against the file's own directory", () => {
    expect(md.mdFileToHtml("[manual](./manual.md)", fromFile)).toBe(
      '<p><a href="#" data-file="docs/svelt/manual.md">manual</a></p>',
    );
  });

  test("links into knowledge/ resolve to concepts", () => {
    expect(md.mdFileToHtml("[arch](../../knowledge/nvim/architecture.md)", fromFile)).toBe(
      '<p><a href="#" data-node="nvim/architecture">arch</a></p>',
    );
  });

  test("external links and unresolvable targets behave like concept bodies", () => {
    expect(md.mdFileToHtml("[s](https://svelte.dev)", fromFile)).toBe(
      '<p><a href="https://svelte.dev" target="_blank" rel="noopener">s</a></p>',
    );
    expect(md.mdFileToHtml("[x](./nope.md)", fromFile)).toBe('<p><a title="./nope.md">x</a></p>');
  });

  test("bare repo paths still autolink", () => {
    expect(md.mdFileToHtml("see flakes/okf/viz.ts here", fromFile)).toBe(
      '<p>see <a href="#" data-file="flakes/okf/viz.ts">flakes/okf/viz.ts</a> here</p>',
    );
  });
});

describe("pipe tables", () => {
  test("header, alignment, escaped pipe", () => {
    const src = ["| a | b | c |", "| --- | :---: | ---: |", "| 1 | 2 \\| x | 3 |"].join("\n");
    expect(md.mdToHtml(src, from)).toBe(
      '<div class="tbl-wrap"><table><thead><tr><th>a</th><th style="text-align:center">b</th>' +
        '<th style="text-align:right">c</th></tr></thead><tbody><tr><td>1</td>' +
        '<td style="text-align:center">2 | x</td><td style="text-align:right">3</td></tr></tbody></table></div>',
    );
  });

  test("pipe lines without a delimiter row fall back to paragraph", () => {
    expect(md.mdToHtml("| not | a table |", from)).toBe("<p>| not | a table |</p>");
  });
});

describe("blocks", () => {
  test("fenced code escapes content", () => {
    expect(md.mdToHtml("```\nconst a = <b> & c;\n```", from)).toBe(
      "<pre><code>const a = &lt;b&gt; &amp; c;</code></pre>",
    );
  });

  test("unclosed fence still flushes", () => {
    expect(md.mdToHtml("```\ndangling", from)).toBe("<pre><code>dangling</code></pre>");
  });

  test("headings render as h3", () => {
    expect(md.mdToHtml("## Context", from)).toBe("<h3>Context</h3>");
  });

  test("ul with hard-wrap continuation", () => {
    expect(md.mdToHtml("- first line\n  continues here\n- second", from)).toBe(
      "<ul><li>first line continues here</li><li>second</li></ul>",
    );
  });

  test("ol", () => {
    expect(md.mdToHtml("1. one\n2) two", from)).toBe("<ol><li>one</li><li>two</li></ol>");
  });

  test("adjacent paragraph lines merge", () => {
    expect(md.mdToHtml("line one\nline two\n\nnext para", from)).toBe("<p>line one line two</p><p>next para</p>");
  });
});
