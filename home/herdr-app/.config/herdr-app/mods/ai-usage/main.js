// ai-usage: the AI accounts' usage in the sidebar: Claude Max's plan limits,
// the Anthropic API's month-to-date cost, ChatGPT's Codex limits. Each account
// gets its logo, title, plan, a bar per limit and its $ where there is one.
//
// It only draws. The ai-usage daemon (pkgs/ai-usage/main.ts, a systemd user
// service / launchd agent) holds the credentials, paces the rate-limited
// endpoints and writes ~/.cache/ai-usage/usage.json; this watches that
// folder, so a new reading shows at once with no polling. Accounts and their
// labels live in ~/.config/ai-usage/config.json.
//
// Click an account to open its usage page; ↻ asks the daemon to refetch
// (it still waits a minute between tries, and honours a provider's
// retry-after). Narrowed to the sidebar rail, each account becomes its logo
// over a bar of its fullest limit.
//
// The logos sit beside this file, but Herdr won't load an image whose path
// resolves outside ~/.config/herdr-app, and stow links every one into the
// dotfiles repo. So init copies them into .logos/ (hidden: no reload) as
// real files and draws from there.

import { View, div, image, svg } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { exec, home, appHome, readTextFile, watchFolder, theme, window } from "herdr";
import * as fs from "fs/promises";

const MIN = 60_000;
const LOGOS = ["claude", "anthropic", "openai"];

// Copy each logo to a real file under .logos/, rewriting only on change.
async function syncLogos() {
  const dir = `${appHome()}/mods/ai-usage`;
  await fs.mkdir(`${dir}/.logos`, { recursive: true });
  for (const name of LOGOS) {
    const src = await readTextFile(`${dir}/${name}.svg`);
    if (!src) continue;
    const dst = `${dir}/.logos/${name}.svg`;
    const have = (await fs.exists(dst)) ? await fs.readFile(dst, "utf8") : null;
    if (have !== src) await fs.writeFile(dst, src);
  }
}

function until(iso) {
  if (!iso) return "";
  const ms = Date.parse(iso) - Date.now();
  if (!Number.isFinite(ms)) return "";
  if (ms <= 0) return "now";
  const m = Math.round(ms / MIN);
  if (m < 60) return `${m}m`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ${m % 60}m`;
  return `${Math.floor(h / 24)}d ${h % 24}h`;
}

function ago(iso) {
  if (!iso) return "never";
  const m = Math.round((Date.now() - Date.parse(iso)) / MIN);
  if (m < 1) return "just now";
  if (m < 60) return `${m}m ago`;
  const h = Math.round(m / 60);
  return h < 48 ? `${h}h ago` : `${Math.round(h / 24)}d ago`;
}

function when(iso) {
  const d = new Date(iso);
  return Number.isFinite(d.getTime())
    ? d.toLocaleString([], { weekday: "short", month: "short", day: "numeric", hour: "numeric", minute: "2-digit" })
    : "";
}

export default class AiUsage extends View {
  init(_props, cx) {
    this.snap = null;
    this.problem = null; // why there's nothing to show
    this.collector = "ai-usage";
    this.width = 268;
    this.refreshing = false;
    this.watching = false;
    this.dir = `${home()}/.cache/ai-usage`;
    this.logos = false; // drawn only once copied: a failed load would stick

    cx.spawn(async (cx) => {
      try {
        await syncLogos();
        this.logos = true;
      } catch (e) {
        console.log(`ai-usage: logos: ${e}`);
      }
      cx.notify();
    });

    cx.spawn(async (cx) => {
      this.problem = "The ai-usage collector isn't installed on this machine.";
      for (const command of ["ai-usage", `${home()}/.local/bin/ai-usage`]) {
        try {
          const r = await exec(command, ["path"]);
          if (r.code !== 0 || !r.stdout.trim()) continue;
          this.collector = command;
          this.dir = r.stdout.trim();
          this.problem = null;
          break;
        } catch {}
      }
      await this.load(cx);
      // Reload on every change in the folder; if it isn't there yet (no
      // daemon run so far), the minute timer below polls instead.
      try {
        for (;;) {
          this.watching = true;
          await watchFolder(this.dir);
          await this.load(cx);
        }
      } catch {
        this.watching = false;
      }
    });

    // "4d 23h" and "updated 3m ago" move by the minute.
    cx.timer.every(MIN, (cx) => (this.watching ? cx.notify() : this.load(cx)));
  }

  async load(cx) {
    const text = await readTextFile(`${this.dir}/usage.json`);
    if (text) {
      try {
        this.snap = JSON.parse(text);
      } catch {
        // mid-write: keep the last good snapshot
      }
    } else if (!this.problem) {
      this.problem = "No readings yet. Is the ai-usage service running?";
    }
    cx.notify();
  }

  refresh(cx) {
    if (this.refreshing) return;
    this.refreshing = true;
    cx.notify();
    cx.spawn(async (cx) => {
      try {
        const result = await exec(this.collector, ["refresh"]);
        this.problem = result.code === 0 ? null : "Usage refresh failed; check the ai-usage service.";
      } catch {
        this.problem = "Cannot run ai-usage; install the collector and reload this mod.";
      }
      this.refreshing = false;
      await this.load(cx);
    });
  }

  open(a) {
    if (!a.url) return;
    exec(window()?.platform === "macos" ? "open" : "xdg-open", [a.url]).catch(() => {});
  }

  logo(a, size, t) {
    if (!this.logos || !LOGOS.includes(a.logo)) return div().w(size).h(size).flex_none();
    const path = `mods/ai-usage/.logos/${a.logo}.svg`;
    return a.tint ? svg(path).size(size).flex_none().text_color(t.foreground) : image(path).w(size).h(size).flex_none();
  }

  barColor(a, m, t) {
    return m.severity === "critical" ? t.ansi1 : m.severity === "warning" ? t.ansi3 : a.color;
  }

  bar(a, m, t, height = 5) {
    const pct = Math.max(0, Math.min(100, m.percent ?? 0));
    return div()
      .h(height)
      .w_full()
      .flex_none()
      .rounded(height)
      .bg(t.border)
      .overflow_hidden()
      .child(div().h_full().rounded(height).bg(this.barColor(a, m, t)).w(`${pct > 0 ? Math.max(pct, 2) : 0}%`));
  }

  meter(a, m, t) {
    const reset = until(m.resetsAt);
    return v_flex()
      .id(`au-${a.id}-${m.id}`)
      .gap(4)
      .when(Boolean(m.resetsAt), (el) => el.tooltip(`Resets ${when(m.resetsAt)}`))
      .child(
        h_flex()
          .gap(6)
          .items_center()
          .text_size(11.5)
          .child(div().flex_1().min_w(0).truncate().text_color(t.muted).child(m.label))
          .when(Boolean(reset), (el) => el.child(div().flex_none().text_size(10.5).text_color(t.dim).child(reset)))
          .child(div().flex_none().text_color(t.foreground).child(m.value)),
      )
      .when(m.percent !== null && m.percent !== undefined, (el) => el.child(this.bar(a, m, t)));
  }

  card(a, t) {
    const old = a.fetchedAt && Date.now() - Date.parse(a.fetchedAt) > 30 * MIN;
    const tone = a.status === "error" ? t.blocked : a.status === "stale" || a.status === "setup" ? t.ansi3 : t.dim;
    return v_flex()
      .id(`au-${a.id}`)
      .gap(8)
      .p(10)
      .rounded(8)
      .bg(t.surface)
      .border(1)
      .border_color(t.border)
      .when(Boolean(a.url), (el) =>
        el.cursor_pointer().hover((s) => s.border_color(t.input)).on_click(() => this.open(a)),
      )
      .tooltip([a.fetchedAt && `Updated ${ago(a.fetchedAt)}`, a.url && "Click for the usage page"].filter(Boolean).join(" · ") || a.title)
      .child(
        h_flex()
          .gap(9)
          .items_center()
          .child(this.logo(a, 20, t))
          .child(
            v_flex()
              .flex_1()
              .min_w(0)
              .child(div().truncate().text_size(13).font_semibold().text_color(t.foreground).child(a.title))
              .when(Boolean(a.subtitle), (el) => el.child(div().truncate().text_size(11).text_color(t.dim).child(a.subtitle))),
          )
          .when(Boolean(a.price), (el) => el.child(div().flex_none().text_size(11).text_color(t.muted).child(a.price))),
      )
      .children(a.meters.filter((m) => m.percent !== null && m.percent !== undefined).map((m) => this.meter(a, m, t)))
      .when(a.status !== "ok" && Boolean(a.message), (el) => el.child(div().text_size(11).text_color(tone).child(a.message)))
      .when(Boolean(old) && !a.message, (el) => el.child(div().text_size(10.5).text_color(t.dim).child(`updated ${ago(a.fetchedAt)}`)));
  }

  // The rail: logo over a short bar of the fullest limit.
  chip(a, t) {
    const bars = a.meters.filter((m) => m.percent !== null && m.percent !== undefined);
    const top = bars.reduce((x, m) => (!x || m.percent > x.percent ? m : x), null);
    const lines = [a.title, ...bars.map((m) => `${m.label}: ${m.value}`), a.status !== "ok" && a.message].filter(Boolean);
    return v_flex()
      .id(`au-${a.id}`)
      .items_center()
      .gap(5)
      .py(6)
      .rounded(6)
      .hover((s) => s.bg(t.hover))
      .tooltip(lines.join("\n"))
      .on_click(() => this.open(a))
      .child(this.logo(a, 18, t))
      .child(div().w(24).child(top ? this.bar(a, top, t, 3) : div().h(3)));
  }

  render(cx) {
    const t = theme();
    const accounts = this.snap?.accounts ?? [];
    const rail = this.width < 160;

    return v_flex()
      .id("root")
      .on_size_change((size, cx) => {
        if (Math.round(size.width) !== Math.round(this.width)) {
          this.width = size.width;
          cx.notify();
        }
      })
      .size_full()
      .min_h(0)
      .bg(t.chrome)
      .border_t(1)
      .border_color(t.border)
      .when(!rail, (el) =>
        el.child(
          h_flex()
            .px(16)
            .h(41)
            .pt(14)
            .pb(5)
            .flex_none()
            .items_center()
            .justify_between()
            .child(div().text_size(11.5).font_medium().text_color(t.dim).child("AI usage"))
            .child(
              div()
                .id("au-refresh")
                .w(18)
                .h(18)
                .flex()
                .items_center()
                .justify_center()
                .text_size(13)
                .text_color(t.dim)
                .hover((s) => s.text_color(t.foreground))
                .tooltip(this.refreshing ? "Refreshing…" : "Refresh now")
                .on_click((_e, cx) => this.refresh(cx))
                .child(
                  this.refreshing
                    ? svg("mods/workspace-chrome/spinner.svg").size(12).text_color(t.working).spin(900)
                    : "↻",
                ),
            ),
        ),
      )
      .when(Boolean(this.problem) || accounts.length === 0, (el) =>
        el.when(!rail, (el) =>
          el.child(div().px(16).text_size(12).text_color(t.dim).child(this.problem ?? "Loading…")),
        ),
      )
      .child(
        v_flex()
          .id("au-list")
          .flex_1()
          .min_h(0)
          .px(rail ? 4 : 10)
          .pb(10)
          .gap(rail ? 6 : 8)
          .overflow_y_scrollbar()
          .children(accounts.map((a) => (rail ? this.chip(a, t) : this.card(a, t)))),
      );
  }
}
