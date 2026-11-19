// The herdr-open Herdr mod (home/herdr-app/.config/herdr-app/mods/herdr-open),
// run for real against stand-ins: a core that holds terminal labels and
// delivers each change to every window after a delay, and windows on two or
// three machines, each with its own copy of the mod. Nothing opens a browser
// or a window.
//
//   bun test flakes/herdr/tests/herdr-open-mod.test.ts
//
// Each window gets its own copy of main.js with the "herdr" and "gpui-kit"
// imports pointed at that window's stand-ins, so copies race the way they do
// across machines.

import { afterAll, expect, test } from "bun:test";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const MOD = join(import.meta.dir, "../../../home/herdr-app/.config/herdr-app/mods/herdr-open/main.js");
const dir = mkdtempSync(join(tmpdir(), "herdr-open-test-"));
afterAll(() => rmSync(dir, { recursive: true, force: true }));
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

type Labels = Record<string, string>;

/** Terminals by their real home: `nebula/t1` lives on nebula as `t1`. */
class Core {
  labels = new Map<string, Labels>();
  windows: Window[] = [];
  latency = 20;
  constructor(terminals: string[]) {
    for (const t of terminals) this.labels.set(t, {});
  }
  /** Applies `key=value` changes now, and shows them to every window later. */
  set(terminal: string, changes: Labels) {
    const l = { ...this.labels.get(terminal) };
    for (const [k, v] of Object.entries(changes)) v === "" ? delete l[k] : (l[k] = v);
    this.labels.set(terminal, l);
    setTimeout(() => this.windows.forEach((w) => w.deliver()), this.latency);
  }
}

type WindowSpec = {
  machine: string;
  platform: "macos" | "linux";
  active: boolean;
  focused?: string | null; // a terminal's home name, e.g. "nebula/t1"
  idleS?: number; // macOS only
  openFails?: boolean;
  unameMs?: number; // a slow hostname lookup at startup
};

class Window {
  view: any;
  shown = new Map<string, Labels>(); // what this window's terminals() shows, by home name
  opened: string[][] = [];
  toasts: any[] = [];
  stopped = false;
  constructor(public core: Core, public spec: WindowSpec) {
    core.windows.push(this);
    this.deliver(true);
  }
  /** Home name -> this window's address: its own terminals are bare. */
  local(home: string) {
    const [machine, id] = home.split("/");
    return machine === this.spec.machine ? id : home;
  }
  home(address: string) {
    return address.includes("/") ? address : `${this.spec.machine}/${address}`;
  }
  deliver(quiet = false) {
    for (const [home, labels] of this.core.labels) this.shown.set(home, { ...labels });
    if (!quiet && this.view && !this.stopped) this.view.render(this.cx());
  }
  cx(): any {
    const w = this;
    return {
      spawn: (fn: (cx: any) => Promise<void>) => {
        fn(w.cx()).catch((e) => {
          if (!w.stopped) throw e;
        });
      },
      sleep: async (ms: number) => {
        await sleep(ms);
        if (w.stopped) throw new Error("stopped");
      },
      notify() {},
    };
  }
  herdr() {
    const w = this;
    return {
      checking: () => false,
      terminals: () => [...w.shown].map(([home, labels]) => ({ address: w.local(home), labels: { ...labels } })),
      focused: () => (w.spec.focused ? { tab: "tab1", terminal: w.local(w.spec.focused), shown: null } : { tab: "tab1", terminal: null }),
      panes: () => (w.spec.focused ? [{ pane: "p1", tab: "tab1", terminal: w.local(w.spec.focused) }] : []),
      window: () => ({ active: w.spec.active, platform: w.spec.platform }),
      notify: (n: any) => w.toasts.push(n),
      hc: async (args: string[]) => {
        await sleep(5);
        const [verb, address, ...labels] = args;
        if (verb !== "label") return { code: 2, stdout: "", stderr: "unexpected" };
        w.core.set(w.home(address), Object.fromEntries(labels.map((l) => [l.slice(0, l.indexOf("=")), l.slice(l.indexOf("=") + 1)])));
        return { code: 0, stdout: "", stderr: "" };
      },
      exec: async (cmd: string, args: string[] = []) => {
        if (cmd === "uname") {
          await sleep(w.spec.unameMs ?? 0);
          return { code: 0, stdout: `${w.spec.machine}.local\n`, stderr: "" };
        }
        if (cmd === "/usr/sbin/ioreg") {
          return { code: 0, stdout: `    "HIDIdleTime" = ${Math.round((w.spec.idleS ?? 0) * 1e9)}\n`, stderr: "" };
        }
        w.opened.push([cmd, ...args]);
        return { code: w.spec.openFails ? 1 : 0, stdout: "", stderr: "" };
      },
    };
  }
  async start() {
    const n = Math.random().toString(16).slice(2);
    (globalThis as any)[`__herdr_${n}`] = this.herdr();
    writeFileSync(join(dir, `herdr-${n}.js`), `const h = globalThis.__herdr_${n};\n` +
      Object.keys(this.herdr()).map((k) => `export const ${k} = (...a) => h.${k}(...a);`).join("\n"));
    writeFileSync(join(dir, `kit-${n}.js`), "export class View {}\nexport const div = () => ({});\n");
    const src = readFileSync(MOD, "utf8")
      .replace(/from "herdr"/, `from "./herdr-${n}.js"`)
      .replace(/from "gpui-kit"/, `from "./kit-${n}.js"`);
    writeFileSync(join(dir, `main-${n}.js`), src);
    const Mod = (await import(join(dir, `main-${n}.js`))).default;
    this.view = new Mod();
    this.view.init({}, this.cx());
    await sleep(10); // the hostname
    return this;
  }
  stop() {
    this.stopped = true;
  }
}

let seq = 0;
/** What herdr-open does on the terminal's machine: label, wait for an answer, clean up. */
async function request(core: Core, terminal: string, url: string, opts: { dry?: boolean; waitMs?: number; at?: number } = {}) {
  const id = `${opts.at ?? Date.now()}-${(seq++).toString(16).padStart(8, "0")}`;
  const key = `herdr-open.${id}${opts.dry ? "-dry" : ""}`;
  core.set(terminal, { [key]: url });
  const deadline = Date.now() + (opts.waitMs ?? 2500);
  let answer = "";
  while (Date.now() < deadline) {
    answer = core.labels.get(terminal)?.[`${key}.done`] ?? "";
    if (answer) break;
    await sleep(10);
  }
  core.set(terminal, { [key]: "", [`${key}.claim`]: "", [`${key}.done`]: "" });
  return answer;
}

async function scene(specs: WindowSpec[], terminals = ["nebula/t1"]) {
  const core = new Core(terminals);
  const windows = [];
  for (const s of specs) windows.push(await new Window(core, s).start());
  return { core, windows, stop: () => windows.forEach((w) => w.stop()) };
}

const mac = (o: Partial<WindowSpec> = {}): WindowSpec => ({ machine: "k", platform: "macos", active: true, focused: "nebula/t1", idleS: 1, ...o });
const nebula = (o: Partial<WindowSpec> = {}): WindowSpec => ({ machine: "nebula", platform: "linux", active: true, focused: "nebula/t1", ...o });

test("the Mac in use wins over nebula's window left in front", async () => {
  const s = await scene([mac(), nebula()]);
  const answer = await request(s.core, "nebula/t1", "https://example.com/a");
  await sleep(600);
  s.stop();
  expect(answer).toMatch(/^k:[0-9a-f]+ here$/);
  expect(s.windows[0].opened).toEqual([["/usr/bin/open", "https://example.com/a"]]);
  expect(s.windows[1].opened).toEqual([]);
  expect(s.windows[0].toasts).toEqual([]); // from the focused terminal: no toast
});

test("an idle Mac stays out; nebula opens it itself", async () => {
  const s = await scene([mac({ idleS: 300 }), nebula()]);
  const answer = await request(s.core, "nebula/t1", "https://example.com/b");
  s.stop();
  expect(answer).toMatch(/^nebula:[0-9a-f]+ here$/);
  expect(s.windows[1].opened).toEqual([["env", "-u", "BROWSER", "xdg-open", "https://example.com/b"]]);
  expect(s.windows[0].opened).toEqual([]);
});

test("no window in front: nobody answers, herdr-open opens it at home", async () => {
  const s = await scene([mac({ active: false }), nebula({ active: false })]);
  const answer = await request(s.core, "nebula/t1", "https://example.com/c", { waitMs: 800 });
  s.stop();
  expect(answer).toBe("");
  expect(s.windows.flatMap((w) => w.opened)).toEqual([]);
});

test("a loopback address from another machine goes back to it", async () => {
  for (const url of [
    "http://localhost:5173/",
    "http://127.0.0.1:8080/x",
    "http://[::1]:3000",
    "https://claude.ai/oauth/authorize?client_id=x&redirect_uri=http%3A%2F%2Flocalhost%3A54545%2Fcallback",
  ]) {
    const s = await scene([mac()]);
    const answer = await request(s.core, "nebula/t1", url);
    s.stop();
    expect(answer).toMatch(/ host$/);
    expect(s.windows[0].opened).toEqual([]);
    expect(s.windows[0].toasts[0].body).toContain("opened on nebula");
  }
});

test("a loopback address from this machine's own terminal opens here", async () => {
  const s = await scene([mac({ focused: "k/t9" })], ["k/t9"]);
  const answer = await request(s.core, "k/t9", "http://localhost:5173/");
  s.stop();
  expect(answer).toMatch(/^k:[0-9a-f]+ here$/);
  expect(s.windows[0].opened).toEqual([["/usr/bin/open", "http://localhost:5173/"]]);
});

test("only http(s) without spaces or control characters, at most 8 KiB", async () => {
  const s = await scene([mac()]);
  for (const url of ["javascript:alert(1)", "file:///etc/passwd", "vscode://file/x", "https://a b", "https://a\u0007b", `https://x/${"a".repeat(8200)}`]) {
    expect(await request(s.core, "nebula/t1", url, { waitMs: 400 })).toBe("");
  }
  s.stop();
  expect(s.windows[0].opened).toEqual([]);
});

test("requests already there at startup, or a minute old, are history", async () => {
  const core = new Core(["nebula/t1"]);
  core.set("nebula/t1", { "herdr-open.1795000000000-0000beef": "https://example.com/old" });
  await sleep(30);
  const w = await new Window(core, mac()).start();
  const answer = await request(core, "nebula/t1", "https://example.com/stale", { at: Date.now() - 120_000, waitMs: 500 });
  w.deliver(); // render again with the old request still present
  await sleep(300);
  w.stop();
  expect(answer).toBe("");
  expect(w.opened).toEqual([]);
});

test("--where answers without opening anything", async () => {
  const s = await scene([mac()]);
  const here = await request(s.core, "nebula/t1", "https://example.com/w", { dry: true });
  const back = await request(s.core, "nebula/t1", "http://localhost:1/", { dry: true });
  s.stop();
  expect(here).toMatch(/^k:[0-9a-f]+ dry-here$/);
  expect(back).toMatch(/^k:[0-9a-f]+ dry-host$/);
  expect(s.windows[0].opened).toEqual([]);
  expect(s.windows[0].toasts).toEqual([]);
});

test("two Macs equally in use: exactly one opens it", async () => {
  for (let i = 0; i < 5; i++) {
    const s = await scene([mac(), mac({ machine: "mini" })]);
    const answer = await request(s.core, "nebula/t1", `https://example.com/race${i}`);
    await sleep(300);
    s.stop();
    expect(answer).toMatch(/ here$/);
    expect(s.windows.flatMap((w) => w.opened).length).toBe(1);
  }
});

test("a terminal without the keyboard opens with a toast", async () => {
  const s = await scene([mac({ focused: null })]);
  const answer = await request(s.core, "nebula/t1", "https://example.com/bg");
  s.stop();
  expect(answer).toMatch(/ here$/);
  expect(s.windows[0].toasts.map((t) => t.title)).toEqual(["Opened a link from nebula/t1"]);
});

test("at most 6 opens in 10 s per window; the rest fall back", async () => {
  const s = await scene([mac()]);
  const answers = [];
  for (let i = 0; i < 8; i++) answers.push(await request(s.core, "nebula/t1", `https://example.com/n${i}`, { waitMs: 500 }));
  s.stop();
  expect(answers.filter((a) => a.endsWith(" here")).length).toBe(6);
  expect(s.windows[0].opened.length).toBe(6);
  expect(s.windows[0].toasts.filter((t) => t.title === "Link not opened").length).toBe(2);
});

test("opening fails here: handed back to the terminal's machine", async () => {
  const s = await scene([mac({ openFails: true })]);
  const answer = await request(s.core, "nebula/t1", "https://example.com/f");
  s.stop();
  expect(answer).toMatch(/ host$/);
});

test("a request made while the window is still starting counts", async () => {
  const core = new Core(["nebula/t1"]);
  const w = new Window(core, mac({ unameMs: 300 }));
  const started = w.start();
  const answer = await request(core, "nebula/t1", "https://example.com/early");
  await started;
  w.stop();
  expect(answer).toMatch(/ here$/);
  expect(w.opened.length).toBe(1);
});
