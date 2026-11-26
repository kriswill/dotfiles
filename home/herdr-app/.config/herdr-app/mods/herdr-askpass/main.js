// herdr-askpass: sudo asking for your password in any hc terminal, on any
// machine this window shows, opens the prompt here as a dialog.
//
// The other half is herdr-askpass (flakes/herdr/pkgs/herdr-askpass.sh),
// SUDO_ASKPASS on every machine (programs.herdr-core.askpass). When sudo has
// no terminal to ask on (an agent's shell), it runs herdr-askpass, which
// starts a short-lived prompt terminal on that machine's core labelled
// herdr-askpass=1 and herdr-askpass.for=<the asking terminal>. herdr-core
// shows it to every Herdr window connected to that machine, so every copy of
// this mod sees it in terminals() and opens it as a modal dialog: a title bar
// (this mod again, {bar: true}) over the live terminal. You type the password
// into that terminal like any other keystrokes; it goes from there to sudo on
// a FIFO, never through this mod, a label or the screen (nothing is echoed).
//
// The dialog closes itself when the prompt terminal ends: Enter sends the
// password, Esc in the terminal cancels, and so does the bar's Cancel (it
// kills the prompt). Every window showing the machine opens one; answering in
// any of them ends the terminal, which closes the rest.
//
// The `personal` layout hosts the watcher as an empty float, like herdr-open:
// a copy runs only while its block is in the layout. Only a copy outside any
// overlay watches: the bar ({bar: true}, in the dialog) is this mod too, and a
// bar that watched would open a dialog per dialog. Roles come from props(),
// not init's argument (a bar given its role there watched as well). render() only
// notices new prompts; the loop started in init() opens them, so no host call
// runs in render.
//
// Races: terminals() can still list a prompt that just ended, and a dialog
// whose terminal is already gone never sees it end. So the watcher checks
// again just before opening, and the bar closes its own dialog once its
// terminal is no longer live.

import { View, div } from "gpui-kit";
import { h_flex } from "gpui-base";
import { terminals, props, openOverlay, closeOverlay, hc, theme, playSound, checking } from "herdr";

const MARK = "herdr-askpass";
const TICK_MS = 100;
const BAR_CHECK_MS = 300;
const BAR_PX = 30;
const SIZE = { width: 720, height: 360 };

/** The prompt terminal at this address, while it is live. */
function livePrompt(address) {
  const t = terminals().find((x) => x.address === address);
  return t && t.labels?.[MARK] === "1" && (!t.state || t.state === "live") ? t : null;
}

/** The machine a terminal address is on, or null for this one. */
function machineOf(address) {
  return address.includes("/") ? address.split("/")[0] : null;
}

/** The asking terminal's address as this window names it. */
function askerOf(t) {
  const local = t.labels?.[`${MARK}.for`];
  if (!local) return null;
  const machine = machineOf(t.address);
  return machine ? `${machine}/${local}` : local;
}

export default class HerdrAskpass extends View {
  init(_props, cx) {
    this.bar = props()?.bar === true;
    this.started = false;
    if (this.bar) {
      // Close this dialog once its prompt is gone (answered, cancelled, timed
      // out, or ended before the dialog could attach to it).
      cx.timer.every(BAR_CHECK_MS, () => {
        const { terminal, overlay } = props() ?? {};
        if (overlay && !this.closed && !(terminal && livePrompt(terminal))) {
          this.closed = true;
          closeOverlay(overlay);
        }
      });
      return;
    }
    if (props()?.overlay || checking()) return; // in some other overlay: do nothing
    this.open = new Map(); // prompt address -> overlay id (null until opened)
    this.queue = [];
    this.started = true;
    this.notice();
    cx.spawn(async (cx) => {
      for (;;) {
        await cx.sleep(TICK_MS);
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

  /** Queues prompts this copy hasn't opened; forgets ones that ended. */
  notice() {
    const live = new Set();
    for (const t of terminals()) {
      if (!livePrompt(t.address)) continue;
      live.add(t.address);
      if (this.open.has(t.address)) continue;
      this.open.set(t.address, null);
      this.queue.push({ address: t.address, asker: askerOf(t) });
    }
    for (const address of this.open.keys()) if (!live.has(address)) this.open.delete(address);
  }

  show({ address, asker }) {
    if (!this.open.has(address) || !livePrompt(address)) return; // it ended before its turn
    const id = openOverlay({
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
    this.open.set(address, id);
    playSound("blocked");
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
            cx.spawn(async () => {
              if (terminal) await hc(["kill", terminal]);
              if (overlay) closeOverlay(overlay);
            });
          })
          .child("Cancel"),
      );
  }
}
