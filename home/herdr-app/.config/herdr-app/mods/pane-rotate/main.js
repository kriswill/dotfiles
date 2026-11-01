// pane-rotate: flip the focused pane and a neighbour between side by side and
// stacked, without restarting either program. Bound to ctrl+space r in
// keys.json (`pane-rotate.rotate`); the app's port of the herdr TUI's
// home/herdr/.config/herdr/scripts/pane-rotate.ts.
//
// Split the focused pane the other way (a throwaway shell), swap the throwaway
// into the neighbour's slot, close it. The neighbour's terminal moves into the
// new orientation still running.
//
// It drives the app through `herdr-app do` rather than run(): each step needs
// the step before it to have happened, and the CLI answers with the new
// pane's id. Like vim-nav, the `personal` layout hosts it as an empty float,
// because key commands only reach a copy that's on screen.

import { View, div } from "gpui-kit";
import { exec, nextCommand, notify } from "herdr";

async function app(...args) {
  const r = await exec("herdr-app", args);
  let out = {};
  try {
    out = r.stdout.trim() ? JSON.parse(r.stdout) : {};
  } catch {
    // not JSON: report what it printed
  }
  if (r.code !== 0 || out.error) {
    throw new Error(out.error || r.stderr.trim() || r.stdout.trim() || `herdr-app ${args.join(" ")}: exit ${r.code}`);
  }
  return out;
}

const focusedPane = async () => (await app("status")).focused_pane;

async function rotate() {
  const p = await focusedPane();
  if (!p) throw new Error("no focused pane");

  // Find a neighbour by stepping focus each way and coming back.
  let dir = null;
  let q = null;
  for (const d of ["right", "down", "left", "up"]) {
    await app("do", "pane.go", "--direction", d);
    const now = await focusedPane();
    if (now && now !== p) {
      dir = d;
      q = now;
      await app("do", "pane.focus", "--pane", p);
      break;
    }
  }
  if (!q) throw new Error("needs at least two panes in this tab");

  const split = dir === "left" || dir === "right" ? "down" : "right";
  const made = await app("do", "pane.split", "--direction", split, "--pane", p);
  const t = made.pane;
  if (!t) throw new Error(`pane.split returned no pane: ${JSON.stringify(made)}`);
  try {
    // The throwaway sits beside p, so q is its neighbour the same way q was p's.
    await app("do", "pane.focus", "--pane", t);
    await app("do", "pane.swap", "--direction", dir);
  } finally {
    await app("do", "pane.close", "--pane", t);
    await app("do", "pane.focus", "--pane", p);
  }
}

export default class PaneRotate extends View {
  init(_props, cx) {
    cx.spawn(async (cx) => {
      for (;;) {
        const command = await nextCommand();
        if (command === "rotate") {
          try {
            await rotate();
          } catch (e) {
            notify({ title: "Rotate panes", body: String(e?.message ?? e), level: "error" });
          }
        }
        cx.notify();
      }
    });
  }

  render() {
    return div();
  }
}
