// herdr-askpass: sudo asking for your password in any hc terminal, on any
// machine this window shows, opens the prompt here as a dialog.
//
// The other half is herdr-askpass (flakes/herdr/pkgs/herdr-askpass.sh), the
// SUDO_ASKPASS of an agent's environment. When sudo has no terminal to ask on
// (an agent's shell), it runs herdr-askpass, which starts a short-lived prompt
// terminal on that machine's core labelled herdr-askpass=1 and
// herdr-askpass.for=<the asking terminal>. herdr-core shows it to every Herdr
// window connected to that machine, so every copy of this mod sees it in
// terminals() and opens it as a modal dialog: a title bar (this mod again,
// {bar: true}) over the live terminal. You type the password into that
// terminal like any other keystrokes; it goes from there to sudo on a FIFO,
// never through this mod, a label or the screen (nothing is echoed).
//
// The dialog closes itself when the prompt terminal ends: Enter sends the
// password, Esc in the terminal cancels, and so does the bar's Cancel (it
// kills the prompt). Every window showing the machine opens one; answering in
// any of them ends the terminal, which closes the rest.
//
// The `personal` layout hosts the watcher as an empty float, like herdr-open:
// a copy runs only while its block is in the layout. Only a copy outside any
// overlay watches: the bar is this mod too, and a bar that watched would open
// a dialog per dialog. Roles come from props(), not init's argument (a bar
// given its role there watched as well). render() and a timer notice new
// prompts (a window that isn't drawn still asks); the timer opens them, so no
// host call runs in render.
//
// Which prompts have a dialog here: each dialog's bar beats in
// shared("herdr-askpass.shown") (prompt address -> ms) every second, and drops
// its entry when it closes. The watcher opens a dialog for a live prompt with
// no fresh beat, unless it opened one moments ago. So a reloaded watcher (a
// saved mod file, a layout switch) doesn't stack a second dialog, and a dialog
// closed while its prompt is still live (overlay.close) comes back. Beats go
// stale, so an entry left behind by a quit doesn't hide a prompt later.
//
// Races: terminals() can still list a prompt that just ended, and a dialog
// whose terminal is already gone never sees it end. So the watcher checks
// again just before opening, and the bar closes its own dialog after its
// terminal has been missing for two checks in a row (one could be a
// reconnect's gap).

import { View, div } from "gpui-kit";
import { h_flex } from "gpui-base";
import { terminals, props, shared, setShared, openOverlay, closeOverlay, hc, theme, playSound, checking } from "herdr";

const MARK = "herdr-askpass";
const SHOWN = "herdr-askpass.shown";
const TICK_MS = 250;
const HEARTBEAT_MS = 1000;
const STALE_MS = 3500; // a bar that hasn't beaten for this long is gone
const GRACE_MS = 2500; // from openOverlay until its bar's first beat
const BAR_CHECK_MS = 300;
const BAR_MISSES = 2;
const BAR_PX = 30;
const SIZE = { width: 720, height: 360 };

/** The machine a terminal address is on, or null for this one. */
function machineOf(address) {
  return address.includes("/") ? address.split("/")[0] : null;
}

function isLivePrompt(t) {
  return Boolean(t) && t.labels?.[MARK] === "1" && (!t.state || t.state === "live");
}

/** The prompt terminal at this address, while it is live. */
function livePrompt(address) {
  const t = terminals().find((x) => x.address === address);
  return isLivePrompt(t) ? t : null;
}

/** The asking terminal's address as this window names it. */
function askerOf(t) {
  const local = t.labels?.[`${MARK}.for`];
  if (!local) return null;
  const machine = machineOf(t.address);
  return machine ? `${machine}/${local}` : local;
}

/** Prompt address -> last beat (ms) of the dialog showing it in this window. */
function shownHere() {
  const s = shared(SHOWN);
  return s && typeof s === "object" ? s : {};
}

export default class HerdrAskpass extends View {
  init(_props, cx) {
    this.bar = props()?.bar === true;
    this.started = false;
    if (this.bar) {
      this.initBar(cx);
      return;
    }
    if (props()?.overlay || checking()) return; // in some other overlay: do nothing
    this.opened = new Map(); // prompt address -> when this copy opened a dialog for it
    this.queue = [];
    this.started = true;
    this.notice();
    cx.spawn(async (cx) => {
      for (;;) {
        await cx.sleep(TICK_MS);
        this.notice();
        while (this.queue.length) {
          try {
            this.show(this.queue.shift());
          } catch (e) {
            console.error(`herdr-askpass: ${e?.message ?? e}`);
          }
        }
      }
    });
  }

  render(cx) {
    if (this.bar) return this.renderBar(cx);
    if (this.started) this.notice();
    else terminals(); // read it, so a new prompt renders this copy again
    return div();
  }

  /** Queues live prompts with no dialog here; forgets ones that ended. */
  notice() {
    const now = Date.now();
    const shown = shownHere();
    const live = new Set();
    for (const t of terminals()) {
      if (!isLivePrompt(t)) continue;
      live.add(t.address);
      if (now - (shown[t.address] ?? 0) < STALE_MS) continue; // a dialog here shows it
      if (now - (this.opened.get(t.address) ?? 0) < GRACE_MS) continue; // ours, its bar not up yet
      this.opened.set(t.address, now);
      this.queue.push({ address: t.address, asker: askerOf(t) });
    }
    for (const address of this.opened.keys()) if (!live.has(address)) this.opened.delete(address);
  }

  show({ address, asker }) {
    if (!livePrompt(address)) return; // it ended before its turn
    if (Date.now() - (shownHere()[address] ?? 0) < STALE_MS) return;
    openOverlay({
      kind: "dialog",
      modal: true,
      ...SIZE,
      layout: {
        type: "column",
        children: [
          {
            type: "block",
            size: { px: BAR_PX },
            content: { mod: MARK, props: { bar: true, terminal: address, asker, machine: machineOf(address) } },
          },
          { type: "block", content: { terminal: address } },
        ],
      },
    });
    // No pane.focus: a terminal in an overlay isn't a pane ("no such pane",
    // and a toast). The dialog takes the keyboard itself.
    playSound("blocked");
  }

  // ---- the bar: this mod again, at the top of a dialog ----------------------

  initBar(cx) {
    const { terminal, overlay } = props() ?? {};
    this.terminal = terminal;
    this.misses = 0;
    this.closed = false;
    this.beat();
    cx.timer.every(HEARTBEAT_MS, () => {
      if (!this.closed) this.beat();
    });
    // Close this dialog once its prompt is gone (answered, cancelled, timed
    // out, or ended before the dialog could attach to it).
    cx.timer.every(BAR_CHECK_MS, () => {
      if (this.closed || !overlay) return;
      this.misses = terminal && livePrompt(terminal) ? 0 : this.misses + 1;
      if (this.misses >= BAR_MISSES) this.closeDialog(overlay);
    });
  }

  /** Tells this window's watcher that the dialog for this prompt is still up. */
  beat() {
    if (!this.terminal) return;
    const now = Date.now();
    const next = {};
    for (const [address, at] of Object.entries(shownHere())) if (now - at < STALE_MS) next[address] = at;
    next[this.terminal] = now;
    setShared(SHOWN, next);
  }

  unbeat() {
    if (!this.terminal) return;
    const next = { ...shownHere() };
    if (!(this.terminal in next)) return;
    delete next[this.terminal];
    setShared(SHOWN, next);
  }

  closeDialog(overlay) {
    this.closed = true;
    closeOverlay(overlay);
  }

  // The dialog went. Dropping the entry lets the watcher reopen a prompt that
  // is still live (closed from outside: overlay.close). After Cancel the entry
  // stays and goes stale instead: terminals() can list the killed prompt a
  // moment longer, and a dialog must not flash back for it.
  async close() {
    if (this.bar && !this.cancelled) this.unbeat();
  }

  /** The dialog's title bar: where sudo runs, who asked, and Cancel. */
  renderBar() {
    const t = theme();
    const { terminal, asker, machine, overlay } = props() ?? {};
    const title = asker ? terminals().find((x) => x.address === asker)?.title : null;
    const who = asker ? `asked by ${asker}${title ? ` (${title})` : ""}` : "";
    return h_flex()
      .id("bar")
      .size_full()
      .px(12)
      .gap(10)
      .items_center()
      .justify_between()
      .bg(t.chrome)
      .text_size(13)
      .child(
        h_flex()
          .gap(8)
          .items_center()
          .min_w(0)
          .child(div().font_semibold().text_color(t.blocked).child(`sudo on ${machine ?? "this machine"}`))
          .child(div().truncate().text_color(t.muted).child(who)),
      )
      .child(
        div()
          .id("cancel")
          .px(10)
          .py(2)
          .rounded(4)
          .border(1)
          .border_color(t.border)
          .text_color(t.foreground)
          .hover((s) => s.bg(t.hover))
          .on_click((_e, cx) => {
            this.cancelled = true;
            cx.spawn(async () => {
              if (terminal) await hc(["kill", terminal]);
              if (overlay && !this.closed) this.closeDialog(overlay);
            });
          })
          .child("Cancel"),
      );
  }
}
