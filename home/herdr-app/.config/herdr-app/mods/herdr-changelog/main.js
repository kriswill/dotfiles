// herdr-changelog: what changed between two versions of herdr, Herdr or
// herdr-core, as a pane. herdr-updates opens it to the right of the focused
// pane with props {product, from, to, kind, action}; it's saved with its tab
// like any mod pane, and reloads from upstream when it comes back.
//
// It reads the product's CHANGELOG.md at the `to` tag (raw.githubusercontent,
// then the default branch if that tag has none). All three repos keep
// Keep a Changelog sections, `## [X.Y.Z] - date` then `### New|Fixed|...`, so
// it keeps the sections in (from, to] and draws each as a card: version and
// date, any lead paragraph, then each group under a colored label, with the
// group's markdown rendered as is. Issue refs (#123, herdr-app#294) and
// @handles become links.

import { View, div } from "gpui-kit";
import { v_flex, h_flex, TextView } from "gpui-base";
import { exec, props, theme, window } from "herdr";

const PRODUCTS = {
  "herdr-app": { name: "Herdr", what: "the desktop app", repo: "herdr-app" },
  "herdr-core": { name: "herdr-core", what: "hc, the terminal daemon", repo: "herdr-core" },
  "herdr-cli": { name: "herdr", what: "the TUI, from our fork", repo: "herdr" },
};
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

// b is a strictly later X.Y.Z than a.
function newer(a, b) {
  const pa = String(a).split(".").map(Number);
  const pb = String(b).split(".").map(Number);
  for (let i = 0; i < 3; i++) {
    if ((pb[i] || 0) !== (pa[i] || 0)) return (pb[i] || 0) > (pa[i] || 0);
  }
  return false;
}

// [{version, date, intro, groups: [{title, body}]}], newest first as written.
function parse(md) {
  const out = [];
  let section = null;
  let group = null;
  for (const line of md.replace(/<!--[\s\S]*?-->/g, "").split("\n")) {
    const v = line.match(/^##\s+\[?v?(\d+\.\d+\.\d+)\]?(?:\s*-\s*(.+?))?\s*$/);
    if (v) {
      section = { version: v[1], date: v[2] ?? "", intro: [], groups: [] };
      group = null;
      out.push(section);
      continue;
    }
    if (/^##\s/.test(line)) {
      section = null; // "Unreleased" and the like
      continue;
    }
    if (!section) continue;
    const g = line.match(/^###\s+(.+?)\s*$/);
    if (g) {
      group = { title: g[1], body: [] };
      section.groups.push(group);
      continue;
    }
    (group ? group.body : section.intro).push(line);
  }
  const tidy = (lines) => lines.join("\n").trim();
  for (const s of out) {
    s.intro = tidy(s.intro);
    for (const g of s.groups) g.body = tidy(g.body);
    s.groups = s.groups.filter((g) => g.body);
  }
  return out;
}

function linkify(md, repo) {
  return md
    .replace(
      /(^|[\s(;,])(herdr(?:-[a-z]+)?)#(\d+)\b/g,
      (_, pre, r, n) => `${pre}[${r}#${n}](https://github.com/herdrdev/${r}/issues/${n})`,
    )
    .replace(/(^|[\s(;,])#(\d+)\b/g, (_, pre, n) => `${pre}[#${n}](https://github.com/herdrdev/${repo}/issues/${n})`)
    .replace(/(^|[\s(,])@([A-Za-z0-9][A-Za-z0-9-]*)\b/g, (_, pre, u) => `${pre}[@${u}](https://github.com/${u})`);
}

function day(iso) {
  const m = String(iso).match(/^(\d{4})-(\d{2})-(\d{2})/);
  return m ? `${MONTHS[Number(m[2]) - 1]} ${Number(m[3])}, ${m[1]}` : String(iso);
}

function tone(title, t) {
  const k = title.toLowerCase();
  if (/secur/.test(k)) return t.ansi5;
  if (/remov|deprecat|break/.test(k)) return t.ansi1;
  if (/new|add|feature/.test(k)) return t.ansi2;
  if (/fix/.test(k)) return t.ansi4;
  if (/change|improv/.test(k)) return t.ansi3;
  return t.muted;
}

function browse(url) {
  exec(window()?.platform === "macos" ? "open" : "xdg-open", [url]).catch(() => {});
}

export default class HerdrChangelog extends View {
  init(_props, cx) {
    const p = props() ?? {};
    this.p = p;
    this.product = PRODUCTS[p.product];
    this.sections = null;
    this.error = null;
    this.ref = null;
    if (!this.product || !p.to) {
      this.error = "Nothing to show: this pane needs {product, from, to}.";
      return;
    }
    cx.spawn(async (cx) => {
      const { repo } = this.product;
      for (const ref of [`v${p.to}`, "HEAD"]) {
        try {
          const r = await fetch(`https://raw.githubusercontent.com/herdrdev/${repo}/${ref}/CHANGELOG.md`);
          if (!r.ok) {
            this.error = `CHANGELOG.md: HTTP ${r.status}`;
            continue;
          }
          const all = parse(await r.text());
          // No `from` (a current product, from the card's installed list): just `to`.
          this.sections = p.from
            ? all.filter((s) => newer(p.from, s.version) && !newer(p.to, s.version))
            : all.filter((s) => s.version === p.to);
          this.ref = ref;
          this.error = null;
          break;
        } catch (e) {
          this.error = `Couldn't fetch the changelog: ${e}`;
        }
      }
      cx.notify();
    });
  }

  url() {
    const repo = this.product?.repo ?? "herdr";
    return `https://github.com/herdrdev/${repo}/blob/${this.ref ?? `v${this.p.to}`}/CHANGELOG.md`;
  }

  header(t) {
    const p = this.p;
    const release = p.kind === "release";
    const pill = (v, strong) =>
      div()
        .px(7)
        .py(2)
        .rounded(6)
        .bg(strong ? t.raised : t.surface)
        .border(1)
        .border_color(t.input)
        .text_size(12)
        .font_family("JetBrains Mono")
        .text_color(strong ? t.foreground : t.muted)
        .child(v);
    return v_flex()
      .flex_none()
      .gap(10)
      .px(22)
      .pt(18)
      .pb(16)
      .border_b(1)
      .border_color(t.input)
      .child(
        h_flex()
          .gap(10)
          .items_center()
          .child(
            v_flex()
              .flex_1()
              .min_w(0)
              .gap(2)
              .child(div().text_size(18).font_semibold().text_color(t.foreground).child(`What's new in ${this.product?.name ?? "herdr"}`))
              .child(div().text_size(12).text_color(t.dim).child(this.product?.what ?? "")),
          )
          .child(
            div()
              .id("cl-github")
              .flex_none()
              .px(8)
              .py(4)
              .rounded(6)
              .text_size(11.5)
              .text_color(t.muted)
              .cursor_pointer()
              .hover((s) => s.bg(t.hover).text_color(t.foreground))
              .on_click(() => browse(this.url()))
              .child("GitHub ↗"),
          ),
      )
      .when(!p.from, (el) =>
        el.child(
          h_flex()
            .gap(7)
            .items_center()
            .child(pill(p.to, true))
            .child(div().text_size(11.5).text_color(t.dim).child("installed, current")),
        ),
      )
      .when(Boolean(p.from), (el) =>
        el.child(
          h_flex()
            .gap(7)
            .items_center()
            .child(pill(p.from, false))
            .child(div().text_size(12).text_color(t.dim).child("→"))
            .child(pill(p.to, true))
            .when(Boolean(p.kind), (el) =>
              el.child(
                div()
                  .ml(6)
                  .px(7)
                  .py(2)
                  .rounded(6)
                  .border(1)
                  .border_color(release ? t.accent : t.ansi3)
                  .text_size(11)
                  .text_color(release ? t.accent : t.ansi3)
                  .child(release ? "new release" : "installed · restart to apply"),
              ),
            ),
        ),
      )
      .when(Boolean(p.action), (el) => el.child(div().text_size(11.5).text_color(t.muted).child(`To apply: ${p.action}`)));
  }

  section(s, t, i) {
    const repo = this.product.repo;
    return v_flex()
      .id(`cl-v-${s.version}`)
      .gap(12)
      .p(16)
      .rounded(10)
      .bg(t.surface)
      .border(1)
      .border_color(t.input)
      .child(
        h_flex()
          .gap(10)
          .items_baseline()
          .child(div().text_size(16).font_semibold().text_color(t.foreground).child(s.version))
          .when(i === 0, (el) =>
            el.child(div().px(6).py(1).rounded(5).bg(t.selected).text_size(10.5).text_color(t.muted).child("latest")),
          )
          .child(div().flex_1())
          .when(Boolean(s.date), (el) => el.child(div().text_size(11.5).text_color(t.dim).child(day(s.date)))),
      )
      .when(Boolean(s.intro), (el) =>
        el.child(
          div()
            .text_size(12.5)
            .text_color(t.muted)
            .child(TextView.markdown(`cl-i-${s.version}`, linkify(s.intro, repo)).selectable(true)),
        ),
      )
      .children(
        s.groups.map((g, gi) =>
          v_flex()
            .gap(6)
            .child(
              h_flex()
                .gap(6)
                .items_center()
                .child(div().w(6).h(6).rounded(3).bg(tone(g.title, t)))
                .child(div().text_size(11).font_semibold().text_color(tone(g.title, t)).child(g.title.toUpperCase())),
            )
            .child(
              div()
                .pl(2)
                .text_size(12.5)
                .text_color(t.foreground)
                .child(TextView.markdown(`cl-g-${s.version}-${gi}`, linkify(g.body, repo)).selectable(true)),
            ),
        ),
      );
  }

  render(_cx) {
    const t = theme();
    let body;
    if (this.sections === null) {
      body = div()
        .p(22)
        .text_size(12.5)
        .text_color(this.error ? t.ansi1 : t.dim)
        .child(this.error ?? "Fetching the changelog…");
    } else if (this.sections.length === 0) {
      body = div()
        .p(22)
        .text_size(12.5)
        .text_color(t.dim)
        .child(
          this.p.from
            ? `The changelog has no entries after ${this.p.from} up to ${this.p.to}. GitHub ↗ has the whole file.`
            : `The changelog has no entry for ${this.p.to}. GitHub ↗ has the whole file.`,
        );
    } else {
      body = v_flex()
        .id("cl-body")
        .flex_1()
        .min_h(0)
        .px(18)
        .py(16)
        .gap(14)
        .overflow_y_scrollbar()
        .children(this.sections.map((s, i) => this.section(s, t, i)));
    }
    return v_flex()
      .id("root")
      .size_full()
      .min_h(0)
      .bg(t.background)
      .when(Boolean(this.product), (el) => el.child(this.header(t)))
      .child(body);
  }
}
