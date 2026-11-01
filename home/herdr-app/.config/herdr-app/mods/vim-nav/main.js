// vim-nav: tmux-style, vim-aware ctrl+h/j/k/l between Herdr panes.
//
// keys.json binds ctrl-h/j/k/l to `vim-nav.left|down|up|right`. If the focused
// terminal runs vim/nvim/fzf, the chord is pressed into it with `hc keys`
// (encoded for the program's keyboard mode); nvim walks its own splits and
// runs `herdr-app do pane.go` once it's against the edge
// (home/nvim/.config/nvim/lua/config/multiplexer.lua). Anything else, Herdr
// moves pane focus. This is the app's counterpart of the herdr TUI's herdr-nav
// and tmux.conf's is_vim.
//
// Key commands only reach a copy that's on screen, so the `personal` layout
// hosts this mod as a floating block on its root. It draws nothing, and Herdr
// draws no frame around an empty float.

import { View, div } from "gpui-kit";
import { focused, hc, nextCommand, panes, run, terminals } from "herdr";

const CHORD = { left: "ctrl+h", down: "ctrl+j", up: "ctrl+k", right: "ctrl+l" };

// The programs tmux.conf and herdr-nav treat as vim: vi, vim, nvim, view,
// vimdiff, gvim, vimx... plus fzf. Matched on the program table's key ("nvim")
// and, for programs the table doesn't list, the process name it reports.
const VIM = /^(g?(view|n?vim?x?)(diff)?|fzf)$/;

function isVim(program) {
  if (!program) return false;
  return VIM.test(program.key) || VIM.test(String(program.name ?? "").toLowerCase());
}

export default class VimNav extends View {
  init(_props, cx) {
    // One command at a time, so a held key's queued presses each see where the
    // previous one left focus (herdr-nav needed a lock for this).
    cx.spawn(async (cx) => {
      for (;;) {
        const dir = await nextCommand();
        try {
          await this.go(dir);
        } catch (e) {
          console.log(`vim-nav ${dir}: ${e}`);
        }
        cx.notify();
      }
    });
  }

  async go(dir) {
    const chord = CHORD[dir];
    if (!chord) return;
    const f = focused();
    if (!f) return;
    // `shown`: a terminal.show stand-in is what's on screen in that pane.
    const address = f.shown ?? f.terminal;
    const program =
      terminals().find((t) => t.address === address)?.program ??
      panes().find((p) => p.pane === f.pane)?.program;
    if (address && isVim(program)) {
      await hc(["keys", address, chord]);
    } else {
      run("pane.go", { direction: dir });
    }
  }

  render() {
    return div();
  }
}
