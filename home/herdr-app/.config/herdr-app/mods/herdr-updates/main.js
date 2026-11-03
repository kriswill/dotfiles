// herdr-updates: the update indicator at the right end of the tab bar (the
// personal layout's `herdr-updates` block), its hover card, and the way into
// the herdr-changelog pane.
//
// It only draws. What's installed, what upstream has released and which
// running processes are older than installed all come from
// `herdr-update-check --json`, the Nix side's own check (flakes/herdr, on
// PATH through services.herdr-update-check): installed means the configured
// programs.herdr-{cli,core,app} packages, a release is upstream past those,
// and "running" is a herdr server, core or window still on an older store
// path after a switch. The window adds what it knows of itself (updates():
// its own version and its core's), which the check can't read off a
// Finder-launched macOS window.
//
// The check runs at start, every 30 minutes, a few seconds after a system
// switch (/nix/var/nix/profiles changes) and from the card's ↻. The last
// result is kept in shared("herdr-updates"), so a restart shows it at once.
//
// One mod, two copies. The layout block (no props) draws the icon and runs
// the checks. The card is this mod again as a popup ({card: true}). They talk
// through "herdr-updates.<command>": the icon tells the card when the pointer
// leaves or comes back, the card tells the icon when it has closed.
//
// The arrow icon sits beside this file, but Herdr won't load an image whose
// path resolves outside ~/.config/herdr-app, and stow links it into the
// dotfiles repo. So the icon copy writes it to .icons/ (hidden: no reload) as
// a real file and draws from there, like ai-usage's logos.

import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import {
  exec,
  appHome,
  readTextFile,
  watchFolder,
  theme,
  run,
  props,
  shared,
  setShared,
  openOverlay,
  closeOverlay,
  nextCommand,
  updates,
  focused,
  panes,
} from "herdr";
import * as fs from "fs/promises";

const MIN = 60_000;
const KEY = "herdr-updates";
const CARD_W = 372;
const CHECKS = ["herdr-update-check", "/run/current-system/sw/bin/herdr-update-check"];
const ICON = "mods/herdr-updates/.icons/update.svg";
const CHECK_ICON = "mods/workspace-chrome/circle-check.svg";
const SPINNER = "mods/workspace-chrome/spinner.svg";

const PRODUCTS = {
  "herdr-app": { name: "Herdr", what: "desktop app" },
  "herdr-core": { name: "herdr-core", what: "hc, the terminal daemon" },
  "herdr-cli": { name: "herdr", what: "TUI, our fork" },
};
const ORDER = ["herdr-app", "herdr-core", "herdr-cli"];

// b is a strictly later X.Y.Z than a.
function newer(a, b) {
  const pa = String(a).split(".").map(Number);
  const pb = String(b).split(".").map(Number);
  for (let i = 0; i < 3; i++) {
    if ((pb[i] || 0) !== (pa[i] || 0)) return (pb[i] || 0) > (pa[i] || 0);
  }
  return false;
}

function ago(iso) {
  if (!iso) return "not yet";
  const m = Math.round((Date.now() - Date.parse(iso)) / MIN);
  if (!Number.isFinite(m)) return "";
  if (m < 1) return "just now";
  if (m < 60) return `${m}m ago`;
  const h = Math.round(m / 60);
  return h < 48 ? `${h}h ago` : `${Math.round(h / 24)}d ago`;
}

function self() {
  try {
    return updates();
  } catch {
    return null;
  }
}

// What's pending: the check's list, plus this window's own view of itself.
function pending(snap) {
  const data = snap?.data;
  const list = [...(data?.updates ?? [])];
  const u = self();
  const mine = (product, running, action) => {
    const installed = data?.installed?.[product];
    if (!installed || !running || !newer(running, installed)) return;
    if (list.some((i) => i.kind === "running" && i.product === product)) return;
    list.push({ kind: "running", product, from: running, to: installed, url: null, action });
  };
  mine("herdr-app", u?.app?.version, "quit and reopen Herdr (terminals keep running)");
  mine("herdr-core", u?.core?.version, "run 'hc server restart' (terminals keep running)");
  const rank = (i) => (i.kind === "release" ? 0 : 1) * 10 + ORDER.indexOf(i.product);
  return list.sort((a, b) => rank(a) - rank(b));
}

function tint(item, t) {
  return item.kind === "release" ? t.accent : t.ansi3;
}

// Close any changelog pane in this tab, then split one in at the right edge:
// beside the tab's last pane (panes() lists a tab's panes left to right, top
// to bottom), or open a tab of it when there's nothing to split.
function openChangelog(item) {
  const f = focused();
  const here = panes().filter((p) => p.tab === f?.tab);
  for (const p of here.filter((p) => p.mod === "herdr-changelog")) run("pane.close", { pane: p.pane });
  const anchor = here.filter((p) => p.mod !== "herdr-changelog").at(-1);
  const spec = {
    mod: "herdr-changelog",
    props: { product: item.product, from: item.from, to: item.to, kind: item.kind, action: item.action ?? null },
  };
  if (anchor) run("pane.split", { direction: "right", pane: anchor.pane, ...spec });
  else run("tab.new", spec);
}

export default class HerdrUpdates extends View {
  init(_props, cx) {
    // props() reads whichever host call is running: take what this copy needs now.
    const p = props() ?? {};
    this.card = Boolean(p.card);
    this.sticky = Boolean(p.sticky);
    this.overlay = p.overlay ?? null;
    this.gen = 0;
    if (this.card) return this.initCard(cx);

    this.open = null; // the card's overlay id, while it's open
    this.over = false;
    this.closedAt = 0;
    this.bounds = null;
    this.running = false;
    this.icon = false;
    this.switchGen = 0; // debounces the post-switch check (this.gen: the hover delay)
    this.retry = false; // a retry after a failed check is pending

    this.syncIcon(cx);

    cx.spawn(async (cx) => {
      for (;;) {
        const c = await nextCommand();
        if (c === "refresh") this.check(cx);
        else if (c === "closed") {
          this.open = null;
          this.closedAt = Date.now();
        }
      }
    });

    // A switch replaces /nix/var/nix/profiles/system: look again once it's done.
    cx.spawn(async (cx) => {
      try {
        for (;;) {
          await watchFolder("/nix/var/nix/profiles");
          const gen = ++this.switchGen;
          cx.timer.after(5000, (cx) => gen === this.switchGen && this.check(cx));
        }
      } catch {
        // no profiles folder here: the half-hourly check still runs
      }
    });

    cx.timer.every(30 * MIN, (cx) => this.check(cx));
    this.check(cx);
  }

  // On a first install, stow links this folder's files one at a time during
  // the activation, so update.svg can be missing when main.js first loads:
  // check() tries again until the copy has worked.
  syncIcon(cx) {
    cx.spawn(async (cx) => {
      try {
        const dir = `${appHome()}/mods/herdr-updates`;
        const src = await readTextFile(`${dir}/update.svg`);
        await fs.mkdir(`${dir}/.icons`, { recursive: true });
        const dst = `${dir}/.icons/update.svg`;
        const have = (await fs.exists(dst)) ? await fs.readFile(dst, "utf8") : null;
        if (src && have !== src) await fs.writeFile(dst, src);
        this.icon = Boolean(src);
      } catch (e) {
        console.log(`herdr-updates: icon: ${e}`);
      }
      cx.notify();
    });
  }

  check(cx) {
    if (!this.icon) this.syncIcon(cx);
    if (this.running) return;
    this.running = true;
    setShared(KEY, { ...(shared(KEY) ?? {}), checking: true });
    cx.spawn(async (cx) => {
      let data = null;
      let error = "herdr-update-check isn't installed (services.herdr-update-check.enable)";
      for (const command of CHECKS) {
        try {
          const r = await exec(command, ["--json"]);
          if (r.code === 0) {
            data = JSON.parse(r.stdout);
            break;
          }
          // exit 2 is the usage error of a check from before --json
          error = r.code === 2 ? "herdr-update-check predates --json: rebuild (nrs)" : `herdr-update-check exited ${r.code}`;
        } catch (e) {
          if (e instanceof SyntaxError) error = "herdr-update-check printed something other than JSON";
        }
      }
      const prev = shared(KEY) ?? {};
      setShared(KEY, {
        data: data ?? prev.data ?? null,
        error: data ? null : error,
        checking: false,
        at: data ? new Date().toISOString() : (prev.at ?? null),
      });
      this.running = false;
      // A failure soon after a switch is often that switch still activating
      // (the old check on PATH): try again in two minutes, not thirty.
      if (!data && !this.retry) {
        this.retry = true;
        cx.timer.after(2 * MIN, (cx) => {
          this.retry = false;
          this.check(cx);
        });
      }
      cx.notify();
    });
  }

  // --- the icon

  hovered(h, cx) {
    this.over = h;
    const gen = ++this.gen;
    if (!h) {
      if (this.open) run("herdr-updates.leave");
      return;
    }
    if (this.open) {
      run("herdr-updates.stay");
      return;
    }
    cx.timer.after(220, () => {
      if (gen === this.gen && this.over && !this.open) this.openCard(false);
    });
  }

  toggle() {
    if (this.open) {
      closeOverlay(this.open);
      this.open = null;
    } else if (Date.now() - this.closedAt > 300) {
      // (a click outside the popup closed it a moment ago: that click was this one)
      this.openCard(true);
    }
  }

  openCard(sticky) {
    const b = this.bounds;
    const at = b ? { x: Math.max(8, Math.round(b.x + b.width - CARD_W)), y: Math.round(b.y + b.height + 6) } : "pointer";
    this.open = openOverlay({ mod: "herdr-updates", kind: "popup", width: CARD_W, props: { card: true, sticky }, at });
  }

  renderIcon(t) {
    const snap = shared(KEY);
    const list = pending(snap);
    const color = list.some((i) => i.kind === "release") ? t.accent : list.length ? t.ansi3 : t.dim;
    let glyph;
    if (!snap?.data && snap?.checking) glyph = svg(SPINNER).size(15).text_color(t.dim).spin(900);
    else if (list.length && this.icon) glyph = svg(ICON).size(17).text_color(color);
    else if (list.length) glyph = div().text_size(15).font_bold().text_color(color).child("↑");
    else glyph = svg(CHECK_ICON).size(16).text_color(snap?.error ? t.ansi1 : t.dim);

    return h_flex()
      .id("root")
      .size_full()
      .items_center()
      .justify_center()
      .child(
        div()
          .id("hu-button")
          .relative()
          .w(30)
          .h(30)
          .rounded(8)
          .flex()
          .items_center()
          .justify_center()
          .cursor_pointer()
          .hover((s) => s.bg(t.hover))
          .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
          .on_mouse_move((e) => {
            this.bounds = e.bounds;
          })
          .on_hover((h, cx) => this.hovered(h, cx))
          .on_click(() => this.toggle())
          .child(glyph)
          .when(list.length > 0, (el) =>
            el.child(
              div()
                .absolute()
                .top(1)
                .right(0)
                .min_w(13)
                .h(13)
                .px(3)
                .rounded(7)
                .bg(color)
                .flex()
                .items_center()
                .justify_center()
                .text_size(9)
                .font_bold()
                .text_color(t.background)
                .child(String(list.length)),
            ),
          ),
      );
  }

  // --- the card

  initCard(cx) {
    this.inside = false;
    this.iconOver = !this.sticky; // hover-opened: the pointer is on the icon
    cx.spawn(async (cx) => {
      for (;;) {
        const c = await nextCommand();
        if (c === "leave") {
          this.iconOver = false;
          this.maybeClose(cx);
        } else if (c === "stay") {
          this.iconOver = true;
          this.gen++;
        }
      }
    });
  }

  maybeClose(cx) {
    if (this.sticky) return;
    const gen = ++this.gen;
    cx.timer.after(300, () => {
      if (gen === this.gen && !this.inside && !this.iconOver) closeOverlay(this.overlay);
    });
  }

  async close() {
    if (this.card) run("herdr-updates.closed");
  }

  row(item, t, i) {
    const p = PRODUCTS[item.product] ?? { name: item.product, what: "" };
    const color = tint(item, t);
    const pill = (v, strong) =>
      div()
        .px(6)
        .py(1)
        .rounded(5)
        .bg(strong ? t.raised : t.surface)
        .border(1)
        .border_color(t.input)
        .text_size(11)
        .font_family("JetBrains Mono")
        .text_color(strong ? t.foreground : t.muted)
        .child(v);
    return v_flex()
      .id(`hu-item-${i}`)
      .gap(5)
      .px(14)
      .py(10)
      .when(i > 0, (el) => el.border_t(1).border_color(t.input))
      .child(
        h_flex()
          .gap(8)
          .items_center()
          .child(div().w(7).h(7).rounded(4).flex_none().bg(color))
          .child(div().flex_none().text_size(13).font_semibold().text_color(t.foreground).child(p.name))
          .child(div().flex_1().min_w(0).truncate().text_size(11).text_color(t.dim).child(p.what))
          .child(
            h_flex()
              .flex_none()
              .gap(5)
              .items_center()
              .child(pill(item.from, false))
              .child(div().text_size(11).text_color(t.dim).child("→"))
              .child(pill(item.to, true)),
          ),
      )
      .child(
        div()
          .pl(15)
          .text_size(11.5)
          .text_color(t.muted)
          .child(`${item.kind === "release" ? "New release" : "Restart to apply"} · ${item.action ?? ""}`),
      )
      .child(
        h_flex()
          .pl(15)
          .gap(4)
          .items_center()
          .child(
            div()
              .id(`hu-log-${i}`)
              .text_size(11.5)
              .font_medium()
              .text_color(t.accent)
              .cursor_pointer()
              .hover((s) => s.underline())
              .on_click(() => {
                openChangelog(item);
                closeOverlay(this.overlay);
              })
              .child(`What's new in ${item.to} ›`),
          ),
      );
  }

  renderCard(t) {
    const snap = shared(KEY);
    const list = pending(snap);
    const inst = snap?.data?.installed ?? {};
    const versions = ORDER.filter((k) => inst[k]).map((k) => `${PRODUCTS[k].name} ${inst[k]}`);
    const u = self();
    const unreachable = snap?.data && ORDER.some((k) => inst[k] && !snap.data.latest?.[k]);

    return v_flex()
      .id("root")
      .w_full()
      .bg(t.popover)
      .on_hover((h, cx) => {
        this.inside = h;
        if (h) this.gen++;
        else this.maybeClose(cx);
      })
      .child(
        h_flex()
          .px(14)
          .pt(12)
          .pb(10)
          .gap(8)
          .items_center()
          .border_b(1)
          .border_color(t.input)
          .child(div().flex_1().text_size(13).font_semibold().text_color(t.foreground).child("herdr updates"))
          .child(
            div()
              .text_size(11)
              .text_color(t.dim)
              .child(snap?.checking ? "checking…" : `checked ${ago(snap?.at)}`),
          )
          .child(
            div()
              .id("hu-refresh")
              .w(20)
              .h(20)
              .rounded(5)
              .flex()
              .items_center()
              .justify_center()
              .text_size(13)
              .text_color(t.dim)
              .cursor_pointer()
              .hover((s) => s.bg(t.hover).text_color(t.foreground))
              .on_click(() => run("herdr-updates.refresh"))
              .child(snap?.checking ? svg(SPINNER).size(12).text_color(t.working).spin(900) : "↻"),
          ),
      )
      .when(Boolean(snap?.error), (el) =>
        el.child(div().px(14).pt(10).text_size(11.5).text_color(t.ansi1).child(snap.error)),
      )
      .when(list.length === 0, (el) =>
        el.child(
          h_flex()
            .px(14)
            .py(14)
            .gap(8)
            .items_center()
            .child(svg(CHECK_ICON).size(15).text_color(t.done ?? t.ansi2))
            .child(
              div()
                .text_size(12.5)
                .text_color(t.foreground)
                .child(snap?.data ? "Everything is current." : "No check has finished yet."),
            ),
        ),
      )
      .children(list.map((item, i) => this.row(item, t, i)))
      .child(
        v_flex()
          .px(14)
          .py(9)
          .gap(2)
          .bg(t.surface)
          .border_t(1)
          .border_color(t.input)
          .child(
            div()
              .text_size(10.5)
              .text_color(t.dim)
              .child(versions.length ? `installed by nix: ${versions.join(" · ")}` : "nothing installed by nix"),
          )
          .when(Boolean(u?.app?.version), (el) =>
            el.child(
              div()
                .text_size(10.5)
                .text_color(t.dim)
                .child(`this window: Herdr ${u.app.version}${u.core?.version ? ` · core ${u.core.version}` : ""}`),
            ),
          )
          .when(Boolean(unreachable), (el) =>
            el.child(div().text_size(10.5).text_color(t.ansi3).child("upstream unreachable on the last check")),
          ),
      );
  }

  render(_cx) {
    const t = theme();
    return this.card ? this.renderCard(t) : this.renderIcon(t);
  }
}
