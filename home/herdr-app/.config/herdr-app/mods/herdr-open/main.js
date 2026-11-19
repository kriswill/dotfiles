// herdr-open: links opened in any hc terminal you're looking at open here, in
// this machine's browser, whichever machine runs the program that opened them.
//
// The other half is herdr-open (flakes/herdr/pkgs/herdr-open.sh), $BROWSER on
// every machine (programs.herdr-core.browser). Run in an hc terminal, it puts
// the URL on that terminal as a label, herdr-open.<ms>-<hex>=<url>, and waits.
// herdr-core sends label changes to every Herdr window that knows the
// terminal, on any machine, so every copy of this mod sees the request in
// terminals(). One of them claims it (<key>.claim=<me>; the last write wins,
// so each claimant reads it back), opens the link, and answers
// <key>.done=<me> here. Nobody answers within 2.5 s: herdr-open opens it on
// its own machine, as before.
//
// Who claims: only a window that is in front (window().active), and the one
// most likely to have the person in front of it goes first. The delay before
// claiming adds up: 0 ms for the terminal with the keyboard here, 100 ms for
// one on screen in this tab, 200 ms for any other; on macOS 10 ms per second
// since the last keyboard or mouse input (HIDIdleTime; over a minute idle
// doesn't claim at all), on Linux, which has no such number here, a flat
// 400 ms. So a Mac in use beats nebula's window left in front on its desk.
//
// Safety. A request can only come from a label, and only a process that can
// talk to a core writes labels; terminal output can't (an escape sequence
// could come from `cat` of any file). This copy opens only http(s) URLs, at
// most 8 KiB, without spaces or control characters, by argv (no shell), at
// most 6 every 10 s, and shows a toast for every open that didn't come from
// the terminal with the keyboard. A loopback address (localhost, 127.x, ::1,
// or an OAuth redirect to one) from another machine's terminal means that
// machine, so it is handed back (`host`) with a toast saying so.
//
// The `personal` layout hosts it as an empty float, like vim-nav: a copy runs
// only while its block is in the layout. render() only notices new requests;
// the loop started in init() acts on them, so no host call runs in render.

import { View, div } from "gpui-kit";
import { terminals, focused, panes, window as appWindow, hc, exec, notify, checking } from "herdr";

const REQUEST = /^herdr-open\.(\d{13})-([0-9a-f]{8})(-dry)?$/;
const SAFE_URL = /^https?:\/\/[^\s\x00-\x1f\x7f]+$/i;
const MAX_URL = 8192;
const MAX_AGE_MS = 60_000; // older requests are history (a reconnect replays labels)
const RATE = { count: 6, ms: 10_000 };
const DELAY = { focused: 0, tab: 100, window: 200 };
const IDLE_MS_PER_S = 10;
const IDLE_MAX_S = 60;
const UNKNOWN_IDLE_MS = 400;
const CLAIM_BACK_MS = 1000; // our claim's round trip through the cores
const TICK_MS = 50;

const LOOPBACK = /^(localhost|.+\.localhost|127\.\d+\.\d+\.\d+|\[::1\]|0\.0\.0\.0|\[::\])$/i;

function hostOf(url) {
  const m = /^https?:\/\/(?:[^@/?#]*@)?(\[[^\]]*\]|[^:/?#]*)/i.exec(url);
  return m ? m[1].toLowerCase() : "";
}

/** Points at the machine it came from: a loopback host, or an OAuth flow
 *  whose redirect goes back to one (its callback listens there). */
function loopback(url) {
  if (LOOPBACK.test(hostOf(url))) return true;
  let q = url;
  try {
    q = decodeURIComponent(url);
  } catch {
    // keep it encoded
  }
  return /[?&](redirect_uri|redirect_url|callback_url|return_to)=https?:\/\/(localhost|127\.\d+\.\d+\.\d+|\[::1\])([:/?#&]|$)/i.test(q);
}

function labelsOf(address) {
  return terminals().find((t) => t.address === address)?.labels ?? null;
}

export default class HerdrOpen extends View {
  init(_props, cx) {
    this.me = `?:${Math.random().toString(16).slice(2, 8)}`;
    this.seen = new Set(); // "<address> <key>" of every request already noticed
    this.queue = [];
    this.opens = [];
    this.started = false;
    if (checking()) return;
    // Requests already on terminals when this copy starts aren't news. Taken
    // now, not after the hostname below, so a request made meanwhile counts.
    this.notice(true);
    this.started = true;
    cx.spawn(async () => {
      try {
        const r = await exec("uname", ["-n"]);
        const host = r.stdout.trim().split(".")[0];
        if (host) this.me = `${host}:${this.me.split(":")[1]}`;
      } catch {
        // keep "?": it only names this window in answers
      }
    });
    cx.spawn(async (cx) => {
      for (;;) {
        await cx.sleep(TICK_MS);
        while (this.queue.length) {
          const req = this.queue.shift();
          cx.spawn(async (cx) => {
            try {
              await this.handle(cx, req);
            } catch (e) {
              console.error(`herdr-open: ${e?.message ?? e}`);
            }
          });
        }
      }
    });
  }

  render() {
    if (this.started) this.notice(false);
    else terminals(); // read it, so label changes render this copy again
    return div();
  }

  /** Queues requests this copy hasn't seen; forgets ones that are gone. */
  notice(initial) {
    const now = Date.now();
    const present = new Set();
    for (const t of terminals()) {
      const labels = t.labels ?? {};
      for (const key of Object.keys(labels)) {
        const m = REQUEST.exec(key);
        if (!m) continue;
        const id = `${t.address} ${key}`;
        present.add(id);
        if (this.seen.has(id)) continue;
        this.seen.add(id);
        if (initial || Math.abs(now - Number(m[1])) > MAX_AGE_MS) continue;
        if (labels[`${key}.claim`] || labels[`${key}.done`]) continue;
        this.queue.push({ address: t.address, key, url: labels[key], dry: Boolean(m[3]) });
      }
    }
    for (const id of this.seen) if (!present.has(id)) this.seen.delete(id);
  }

  /** How long to wait before claiming, or null: not this window. */
  async delay(address) {
    if (!appWindow()?.active) return null;
    const f = focused();
    let ms;
    if (f && (f.terminal === address || f.shown === address)) ms = DELAY.focused;
    else if (panes().some((p) => p.terminal === address && p.tab === f?.tab)) ms = DELAY.tab;
    else ms = DELAY.window;
    if (appWindow().platform !== "macos") return ms + UNKNOWN_IDLE_MS;
    try {
      const r = await exec("/usr/sbin/ioreg", ["-r", "-k", "HIDIdleTime", "-d", "1"], { timeout: 2000 });
      const ns = /"HIDIdleTime" = (\d+)/.exec(r.stdout);
      if (!ns) return ms + UNKNOWN_IDLE_MS;
      const idle = Number(ns[1]) / 1e9;
      return idle > IDLE_MAX_S ? null : ms + Math.round(idle * IDLE_MS_PER_S);
    } catch {
      return ms + UNKNOWN_IDLE_MS;
    }
  }

  allowed() {
    const now = Date.now();
    this.opens = this.opens.filter((t) => now - t < RATE.ms);
    if (this.opens.length >= RATE.count) return false;
    this.opens.push(now);
    return true;
  }

  async handle(cx, { address, key, url, dry }) {
    // Not ours to open: herdr-open waits, then opens it on its own machine.
    if (typeof url !== "string" || url.length > MAX_URL || !SAFE_URL.test(url)) return;
    const wait = await this.delay(address);
    if (wait === null) return;
    if (wait > 0) await cx.sleep(wait);

    let labels = labelsOf(address);
    if (!labels || labels[key] !== url || labels[`${key}.claim`] || labels[`${key}.done`]) return;
    if (!dry && !this.allowed()) {
      notify({ title: "Link not opened", body: `Too many links from ${address}: ${url}`, level: "warning" });
      return;
    }
    const claimed = await hc(["label", address, `${key}.claim=${this.me}`]);
    if (claimed.code !== 0) return;
    for (let waited = 0; ; waited += TICK_MS) {
      labels = labelsOf(address);
      const claim = labels?.[`${key}.claim`];
      if (claim === this.me) break;
      if (claim || !labels?.[key] || waited >= CLAIM_BACK_MS) return;
      await cx.sleep(TICK_MS);
    }

    const remote = address.includes("/");
    const machine = remote ? address.split("/")[0] : "here";
    const onHost = remote && loopback(url);
    const background = focused()?.terminal !== address;
    let verdict = onHost ? "host" : "here";
    if (!dry && verdict === "here") {
      const r =
        appWindow().platform === "macos"
          ? await exec("/usr/bin/open", [url])
          : await exec("env", ["-u", "BROWSER", "xdg-open", url]);
      if (r.code !== 0) verdict = "host";
    }
    await hc(["label", address, `${key}.done=${this.me} ${dry ? "dry-" : ""}${verdict}`]);
    if (dry) return;
    if (verdict === "host") {
      const why = onHost ? `a loopback address, so it opened on ${machine}` : "opening it here failed";
      notify({ title: `Link from ${address}`, body: `${url}\n${why}`, level: "info" });
    } else if (background) {
      notify({ title: `Opened a link from ${address}`, body: url, level: "info", timeout: 4000 });
    }
    cx.notify();
  }
}
