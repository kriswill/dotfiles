#!/usr/bin/env bun
// Herdr tab-bar usage indicator (experiment).
//
// Spawned by ~/.claude-me/statusline.sh when Claude Code runs inside a Herdr pane
// on the personal ("me"/"default") profile. While this pane's tab is focused,
// it publishes weekly usage (all-models from the statusline-published file,
// Fable-scoped from the OAuth usage endpoint, sparingly) as the
// usage/usage_fable workspace metadata tokens. Our fork's herdr (custom
// branch, ANSI tab-bar command entries) exposes those tokens to its
// tab-bar command as HERDR_TOKEN_USAGE / HERDR_TOKEN_USAGE_FABLE env and
// re-runs ~/.local/bin/dotbar-usage on every token change, which renders
// them as full-color dotbar braille bars — reactive, no tight polling.
// Focus changes arrive as pushed tab.focused events over the herdr API
// socket, so the tokens flip within milliseconds of a switch; they clear on
// focus loss or claude exit, and their TTL clears them if this watcher dies
// uncleanly.
//
// Usage: bun herdr-usage-watcher.ts <claude-pid>

const claudePid = Number(process.argv[2] ?? 0);
const tabId = process.env.HERDR_TAB_ID ?? "";
const paneId = process.env.HERDR_PANE_ID ?? "unknown";
const sockPath = process.env.HERDR_SOCKET_PATH ?? "";
const configDir = process.env.CLAUDE_CONFIG_DIR ?? `${process.env.HOME}/.claude`;
if (!tabId || !sockPath || !claudePid) process.exit(0);

const fs = require("node:fs");
const workspaceId = process.env.HERDR_WORKSPACE_ID ?? "";

const TOKEN_SOURCE = "claude-usage";
const TOKEN_TTL_MS = 15_000; // refreshed by the 5s housekeeping tick

function publishTokens(u: { all: number; fable: number | null }) {
  if (!workspaceId) return;
  const args = [
    "herdr", "workspace", "report-metadata", workspaceId,
    "--source", TOKEN_SOURCE, "--ttl-ms", String(TOKEN_TTL_MS),
    "--token", `usage=${u.all}`,
  ];
  if (u.fable !== null) args.push("--token", `usage_fable=${u.fable}`);
  sh(args);
}

function clearTokens() {
  if (!workspaceId) return;
  sh([
    "herdr", "workspace", "report-metadata", workspaceId,
    "--source", TOKEN_SOURCE,
    "--clear-token", "usage", "--clear-token", "usage_fable",
  ]);
}

// Singleton per pane — exclusive create (wx) so concurrent spawns from rapid
// statusline refreshes can't race past a read-then-write check.
const pidFile = `/tmp/herdr-usage-${paneId.replace(/[^A-Za-z0-9]/g, "_")}.pid`;
{
  let claimed = false;
  for (let i = 0; i < 3 && !claimed; i++) {
    try {
      fs.writeFileSync(pidFile, String(process.pid), { flag: "wx" });
      claimed = true;
    } catch {
      let old = 0;
      try {
        old = Number(fs.readFileSync(pidFile, "utf8"));
      } catch {}
      if (old > 0) {
        try {
          process.kill(old, 0);
          process.exit(0); // holder alive — we're redundant
        } catch {}
      }
      try {
        fs.unlinkSync(pidFile); // stale — remove and retry the exclusive create
      } catch {}
    }
  }
  if (!claimed) process.exit(0);
}

function sh(cmd: string[]): string {
  const p = Bun.spawnSync(cmd, { stdout: "pipe", stderr: "pipe" });
  return p.success ? p.stdout.toString().trim() : "";
}

function alive(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

// Keychain service name: "Claude Code-credentials-" + first 8 hex of
// sha256(config dir path); the plain dir ~/.claude uses the unsuffixed name.
function keychainService(): string {
  const base = "Claude Code-credentials";
  if (configDir === `${process.env.HOME}/.claude`) return base;
  const hash = new Bun.CryptoHasher("sha256").update(configDir).digest("hex");
  return `${base}-${hash.slice(0, 8)}`;
}

// Weekly all-models %: published by statusline.sh from the statusline JSON's
// rate_limits — costs zero API calls. No freshness gate; weekly moves slowly.
const WEEKLY_FILE = "/tmp/herdr-claude-weekly.json";

function readWeeklyAll(): number | null {
  try {
    const c = JSON.parse(fs.readFileSync(WEEKLY_FILE, "utf8"));
    if (typeof c.all === "number") return Math.round(c.all);
  } catch {}
  return null;
}

// Fable-scoped weekly %: only available from the OAuth usage endpoint, which
// rate-limits aggressively (it backs Claude Code's own /usage UI). Cache is
// shared by all watcher instances; fetch at most every CACHE_FRESH_MS, and
// after any failure back off FAIL_BACKOFF_MS before trying again.
const CACHE_FILE = "/tmp/herdr-claude-usage-cache.json";
const CACHE_FRESH_MS = 30 * 60_000;
const FAIL_BACKOFF_MS = 15 * 60_000;

function readCache(): { at?: number; fable?: number; failAt?: number } {
  try {
    return JSON.parse(fs.readFileSync(CACHE_FILE, "utf8")) ?? {};
  } catch {}
  return {};
}

async function getFable(): Promise<number | null> {
  const c = readCache();
  const now = Date.now();
  const fresh = typeof c.fable === "number" && now - (c.at ?? 0) < CACHE_FRESH_MS;
  const backingOff = now - (c.failAt ?? 0) < FAIL_BACKOFF_MS;
  if (!fresh && !backingOff) {
    const f = await fetchFable();
    try {
      if (f !== null) fs.writeFileSync(CACHE_FILE, JSON.stringify({ at: now, fable: f }));
      else fs.writeFileSync(CACHE_FILE, JSON.stringify({ ...c, failAt: now }));
    } catch {}
    if (f !== null) return f;
  }
  return typeof c.fable === "number" ? c.fable : null; // stale beats nothing
}

async function fetchFable(): Promise<number | null> {
  const raw = sh(["security", "find-generic-password", "-s", keychainService(), "-w"]);
  if (!raw) return null;
  let token = "";
  try {
    token = JSON.parse(raw).claudeAiOauth?.accessToken ?? "";
  } catch {}
  if (!token) return null;
  try {
    const res = await fetch("https://api.anthropic.com/api/oauth/usage", {
      headers: { Authorization: `Bearer ${token}`, "anthropic-beta": "oauth-2025-04-20" },
    });
    if (!res.ok) return null;
    const data: any = await res.json();
    const limits: any[] = data.limits ?? [];
    const fable = limits.find(
      (l) => l.kind === "weekly_scoped" && /fable/i.test(l.scope?.model?.display_name ?? ""),
    )?.percent;
    return fable == null ? null : Math.round(fable);
  } catch {
    return null;
  }
}

let usage: { all: number; fable: number | null } | null = null;
let focused = false;
let shown = false;

function apply() {
  if (focused && usage) {
    publishTokens(usage);
    shown = true;
  } else if (shown) {
    clearTokens();
    shown = false;
  }
}

function cleanup() {
  if (shown) clearTokens();
  try {
    // Only remove the pidfile if we still own it — another instance may have
    // legitimately claimed it after ours was cleaned up externally.
    if (Number(fs.readFileSync(pidFile, "utf8")) === process.pid) fs.unlinkSync(pidFile);
  } catch {}
}

process.on("SIGTERM", () => {
  cleanup();
  process.exit(0);
});
process.on("SIGINT", () => process.emit("SIGTERM" as any));

// Initial focus state (events only report changes).
try {
  focused = !!JSON.parse(sh(["herdr", "tab", "get", tabId])).result.tab.focused;
} catch {}
async function refreshUsage() {
  const all = readWeeklyAll();
  if (all === null) return; // no statusline data yet
  const fable = await getFable();
  if (all !== usage?.all || fable !== (usage?.fable ?? null)) {
    usage = { all, fable };
    apply();
  }
}
await refreshUsage();
apply();

// Event-driven focus tracking: pushed tab.focused events over the API socket.
let buf = "";
function connect() {
  Bun.connect({
    unix: sockPath,
    socket: {
      open(s) {
        buf = "";
        s.write(
          JSON.stringify({
            id: "sub",
            method: "events.subscribe",
            params: { subscriptions: [{ type: "tab.focused" }] },
          }) + "\n",
        );
      },
      data(_s, chunk) {
        buf += chunk.toString();
        let nl;
        while ((nl = buf.indexOf("\n")) !== -1) {
          const line = buf.slice(0, nl);
          buf = buf.slice(nl + 1);
          try {
            const msg = JSON.parse(line);
            if (msg.event === "tab_focused") {
              focused = msg.data.tab_id === tabId;
              apply();
            }
          } catch {}
        }
      },
      close() {
        // herdr server restarted or dropped us — retry while claude lives.
        if (alive(claudePid)) setTimeout(connect, 2000);
      },
      error() {},
    },
  }).catch(() => {
    if (alive(claudePid)) setTimeout(connect, 2000);
  });
}
connect();

// Housekeeping: claude liveness (5s) and usage refresh (5 min).
setInterval(() => {
  if (!alive(claudePid)) {
    cleanup();
    process.exit(0);
  }
  // Keep the metadata tokens' TTL alive while visible.
  if (focused && usage) publishTokens(usage);
}, 5000);

// Every 60s: re-read the (free) weekly file; the Fable fetch inside is gated
// by its own 30-min cache and 15-min failure backoff.
setInterval(refreshUsage, 60_000);
