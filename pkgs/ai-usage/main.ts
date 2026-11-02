#!/usr/bin/env bun
// ai-usage: what the AI accounts have used. Claude Max (plan limits + extra
// usage), the Anthropic API (month-to-date $: exact via the Admin API, or
// estimated from Hermes' own session log), and ChatGPT via Codex's plan limits.
//
//   ai-usage [show] [--json]   print the last snapshot (no network)
//   ai-usage refresh           ask the daemon to refetch now (or fetch inline)
//   ai-usage once [--force]    one collection pass in this process
//   ai-usage daemon            poll on schedule; what the user service runs
//   ai-usage path | config     where the snapshot dir / config file live
//
// The daemon writes $XDG_CACHE_HOME/ai-usage/usage.json (no secrets in it).
// The herdr-app `ai-usage` mod watches that folder and draws it; this CLI
// draws it in a terminal. Accounts come from ~/.config/ai-usage/config.json
// (the `ai-usage` stow package).
//
// Rate limits matter more than freshness here:
// - api.anthropic.com/api/oauth/usage backs Claude Code's own /usage panel
//   and is quota-limited per account; a 429's retry-after can run ~50 min,
//   and the herdr TUI's herdr-usage-watcher.ts draws on the same bucket.
//   So: every 10 min at most, retry-after honoured exactly, and the last good
//   reading kept through any failure.
// - OAuth tokens (Claude, Codex) are only ever READ. Their refresh tokens
//   rotate; redeeming one here would sign the real CLI out. An expired token
//   waits for the CLI to refresh it.
// - The Admin API key is read once per daemon lifetime (1Password `op read`,
//   a file, or an env var) and held in memory only.

import { Database } from "bun:sqlite";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const HOME = os.homedir();
const HOST = os.hostname().split(".")[0];
const IS_MAC = process.platform === "darwin";
const expand = (p: string) => p.replace(/^~(?=$|\/)/, HOME);

const CACHE_DIR =
  process.env.AI_USAGE_DIR ||
  path.join(process.env.XDG_CACHE_HOME || path.join(HOME, ".cache"), "ai-usage");
const SNAPSHOT = path.join(CACHE_DIR, "usage.json");
const PIDFILE = path.join(CACHE_DIR, "daemon.pid");
const LOCKFILE = path.join(CACHE_DIR, "fetch.lock");
const CONFIG =
  process.env.AI_USAGE_CONFIG ||
  path.join(process.env.XDG_CONFIG_HOME || path.join(HOME, ".config"), "ai-usage", "config.json");

const MIN = 60_000;
const TICK_MS = 20_000;
const FORCE_GAP_MS = MIN;

// ── Types ──────────────────────────────────────────────────────────────────

type Severity = "normal" | "warning" | "critical";
type Status = "ok" | "stale" | "error" | "setup" | "pending";

type Meter = {
  id: string;
  label: string;
  percent: number | null; // bar fill 0..100; null = a figure with no bar
  value: string; // right-hand text: "37%", "$12.34 / $50"
  usedUsd?: number;
  limitUsd?: number;
  resetsAt?: string | null; // ISO
  severity?: Severity;
};

type Account = {
  id: string;
  provider: Provider;
  title: string;
  plan?: string; // what the provider says the plan is ("Max 20x", "Plus")
  subtitle?: string; // plan · the config's subtitle
  logo: string; // the mod's mods/ai-usage/<logo>.svg
  tint: boolean; // one-color logo: drawn in the text color
  color: string; // the bars' normal color
  price?: string; // "$200/mo"
  url?: string; // the provider's own usage page
  status: Status;
  message?: string;
  meters: Meter[];
  fetchedAt?: string; // last success
  checkedAt?: string; // last attempt
  nextAt?: number; // epoch ms: the next scheduled fetch
  blockedUntil?: number; // epoch ms: server-imposed (retry-after); force can't skip it
};

type Snapshot = { version: 1; host: string; updatedAt: string; accounts: Account[] };

type Provider = "claude" | "anthropic-api" | "hermes" | "codex";
type KeySource = { op?: string; file?: string; env?: string };
type AccountConfig = {
  id: string;
  provider: Provider;
  title?: string;
  subtitle?: string;
  price?: number; // $/month, subscriptions
  url?: string;
  color?: string;
  hosts?: string[]; // only on these hostnames (short form); omitted = everywhere
  disabled?: boolean; // kept in the config, not tracked
  interval?: number; // minutes between fetches
  configDir?: string | string[]; // claude: the Claude Code config dir(s)
  adminKey?: KeySource; // anthropic-api
  budget?: number; // anthropic-api, hermes: $/month the bar fills toward
  stateDb?: string; // hermes: its state.db
  workspaceId?: string | null; // anthropic-api: one workspace only (null = Default)
  codexHome?: string; // codex
};
type Config = { accounts: AccountConfig[] };

// What a provider fetch hands back. Meters omitted = keep the previous ones.
type Result = {
  status: Status;
  message?: string;
  meters?: Meter[];
  subtitle?: string;
  retryInMs?: number; // overrides the normal interval for the next attempt
  blockMs?: number; // a server-imposed wait (retry-after)
};

const DEFAULTS: Record<Provider, { title: string; logo: string; tint: boolean; color: string; interval: number }> = {
  claude: { title: "Claude", logo: "claude", tint: false, color: "#D97757", interval: 10 },
  "anthropic-api": { title: "Anthropic API", logo: "anthropic", tint: true, color: "#D4A27F", interval: 15 },
  hermes: { title: "Anthropic API", logo: "anthropic", tint: true, color: "#D4A27F", interval: 5 },
  codex: { title: "ChatGPT", logo: "openai", tint: true, color: "#10A37F", interval: 10 },
};

// ── Small helpers ──────────────────────────────────────────────────────────

function readJson<T>(file: string): T | null {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8")) as T;
  } catch {
    return null;
  }
}

function writeAtomic(file: string, text: string) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const tmp = `${file}.${process.pid}.tmp`;
  fs.writeFileSync(tmp, text);
  fs.renameSync(tmp, file);
}

const severityOf = (pct: number): Severity => (pct >= 90 ? "critical" : pct >= 75 ? "warning" : "normal");
const clamp = (n: number) => Math.max(0, Math.min(100, n));

function usd(n: number, cents = true): string {
  const s = cents || !Number.isInteger(n) ? n.toFixed(2) : String(n);
  return `$${s.replace(/\B(?=(\d{3})+(?!\d))/g, ",")}`;
}

function pctMeter(id: string, label: string, pct: number, resetsAt?: string | null, sev?: string): Meter {
  const p = clamp(pct);
  return {
    id,
    label,
    percent: p,
    value: `${Math.round(p)}%`,
    resetsAt: resetsAt ?? null,
    severity: sev === "warning" || sev === "critical" ? sev : severityOf(p),
  };
}

function usdMeter(id: string, label: string, used: number, limit: number | null, resetsAt?: string | null): Meter {
  if (!limit || limit <= 0) return { id, label, percent: null, value: usd(used), usedUsd: used, resetsAt: resetsAt ?? null };
  const p = clamp((used / limit) * 100);
  return {
    id,
    label,
    percent: p,
    value: `${usd(used)} / ${usd(limit, false)}`,
    usedUsd: used,
    limitUsd: limit,
    resetsAt: resetsAt ?? null,
    severity: severityOf(p),
  };
}

const slug = (s: string) => s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
const titleCase = (s: string) => s.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());

function jwtClaims(token: string): any {
  try {
    return JSON.parse(Buffer.from(token.split(".")[1], "base64url").toString("utf8"));
  } catch {
    return null;
  }
}

// retry-after: seconds, or an HTTP date.
function retryAfterMs(res: Response): number | undefined {
  const h = res.headers.get("retry-after");
  if (!h) return undefined;
  const s = Number(h);
  if (Number.isFinite(s) && s > 0) return s * 1000;
  const t = Date.parse(h);
  return Number.isFinite(t) ? Math.max(0, t - Date.now()) : undefined;
}

async function run(cmd: string[], timeoutMs = 30_000): Promise<{ ok: boolean; out: string; err: string }> {
  try {
    const p = Bun.spawn(cmd, { stdout: "pipe", stderr: "pipe", stdin: "ignore" });
    const timer = setTimeout(() => p.kill(), timeoutMs);
    const [out, err, code] = await Promise.all([new Response(p.stdout).text(), new Response(p.stderr).text(), p.exited]);
    clearTimeout(timer);
    return { ok: code === 0, out, err: err.trim() };
  } catch (e: any) {
    return { ok: false, out: "", err: String(e?.message ?? e) };
  }
}

async function getJson(url: string, headers: Record<string, string>): Promise<{ res?: Response; data?: any; err?: string }> {
  try {
    const res = await fetch(url, { headers: { Accept: "application/json", ...headers }, signal: AbortSignal.timeout(20_000) });
    if (!res.ok) {
      // The provider's own reason ("Missing permissions", …) beats a bare status.
      let why = "";
      try {
        const body: any = await res.json();
        why = String(body?.error?.message ?? body?.detail ?? body?.message ?? "").slice(0, 160);
      } catch {}
      return { res, err: why ? `HTTP ${res.status}: ${why}` : `HTTP ${res.status}` };
    }
    return { res, data: await res.json() };
  } catch (e: any) {
    return { err: String(e?.message ?? e) };
  }
}

// A failed fetch: a 429 waits exactly as long as the server says.
function httpFailure(what: string, res: Response | undefined, err: string | undefined): Result {
  if (res?.status === 429) {
    const wait = retryAfterMs(res) ?? 15 * MIN;
    return { status: "stale", message: `${what} rate-limited; retrying ${clock(Date.now() + wait)}`, blockMs: wait };
  }
  if (res?.status === 401 || res?.status === 403)
    return { status: "error", message: `${what} refused the credentials (${err ?? res.status})`, retryInMs: 15 * MIN };
  return { status: "stale", message: `${what}: ${err ?? "failed"}`, retryInMs: 5 * MIN };
}

const clock = (ms: number) => new Date(ms).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });

// ── Claude (plan limits via the OAuth usage endpoint) ──────────────────────

// Claude Code keeps OAuth credentials in <configDir>/.credentials.json on
// Linux and in the login keychain on macOS: service "Claude Code-credentials"
// for the default ~/.claude, "-<sha256(configDir)[:8]>" appended otherwise.
function claudeCredentials(configDir: string): any | null {
  const dir = expand(configDir);
  let raw = "";
  try {
    raw = fs.readFileSync(path.join(dir, ".credentials.json"), "utf8");
  } catch {
    if (IS_MAC) {
      const base = "Claude Code-credentials";
      const service = dir === path.join(HOME, ".claude") ? base : `${base}-${crypto.createHash("sha256").update(dir).digest("hex").slice(0, 8)}`;
      const p = Bun.spawnSync(["/usr/bin/security", "find-generic-password", "-s", service, "-w"]);
      raw = p.success ? p.stdout.toString().trim() : "";
    }
  }
  if (!raw) return null;
  try {
    return JSON.parse(raw).claudeAiOauth ?? null;
  } catch {
    return null;
  }
}

function claudePlan(o: any): string | undefined {
  const tier = String(o?.rateLimitTier ?? "");
  const m = tier.match(/max_(\d+)x/);
  if (m) return `Max ${m[1]}x`;
  const sub = String(o?.subscriptionType ?? "");
  return sub ? titleCase(sub) : undefined;
}

// Money as the endpoint sends it: an integer in minor units + its exponent.
const money = (m: any): number | null =>
  m && typeof m.amount_minor === "number" ? m.amount_minor / 10 ** (m.exponent ?? 2) : null;

async function fetchClaude(cfg: AccountConfig): Promise<Result> {
  // configDir may list candidates; the first holding a login wins (macs keep
  // the personal profile in ~/.claude-me, nebula in ~/.claude).
  const dirs = ([] as string[]).concat(cfg.configDir ?? process.env.CLAUDE_CONFIG_DIR ?? "~/.claude");
  const o = dirs.map(claudeCredentials).find((c) => c?.accessToken?.trim());
  const token = o?.accessToken?.trim();
  if (!token) return { status: "setup", message: "Sign in to Claude Code (claude /login)", retryInMs: 5 * MIN };
  const plan = claudePlan(o);
  if (typeof o.expiresAt === "number" && o.expiresAt < Date.now()) {
    return { status: "stale", message: "Token expired; open Claude Code to renew it", subtitle: plan, retryInMs: 2 * MIN };
  }

  const { res, data, err } = await getJson("https://api.anthropic.com/api/oauth/usage", {
    Authorization: `Bearer ${token}`,
    "anthropic-beta": "oauth-2025-04-20",
  });
  if (!data) return { ...httpFailure("Claude", res, err), subtitle: plan };

  const meters: Meter[] = [];
  const five = data.five_hour;
  if (five && typeof five.utilization === "number") meters.push(pctMeter("session", "Session (5h)", five.utilization, five.resets_at));

  const limits: any[] = Array.isArray(data.limits) ? data.limits : [];
  const all = limits.find((l) => l.kind === "weekly_all");
  if (all && typeof all.percent === "number") meters.push(pctMeter("weekly", "Weekly", all.percent, all.resets_at, all.severity));
  else if (data.seven_day && typeof data.seven_day.utilization === "number")
    meters.push(pctMeter("weekly", "Weekly", data.seven_day.utilization, data.seven_day.resets_at));

  for (const l of limits) {
    if (l.kind === "weekly_all" || typeof l.percent !== "number") continue;
    if (l.kind === "weekly_scoped") {
      const name = l.scope?.model?.display_name ?? l.scope?.surface ?? "Scoped";
      meters.push(pctMeter(`weekly-${slug(name)}`, `${name} weekly`, l.percent, l.resets_at, l.severity));
    } else if (!(five && /session|five_hour/.test(l.kind))) {
      meters.push(pctMeter(slug(l.kind), titleCase(l.kind), l.percent, l.resets_at, l.severity));
    }
  }
  if (!limits.length) {
    for (const [k, name] of [["seven_day_opus", "Opus"], ["seven_day_sonnet", "Sonnet"]] as const) {
      const w = data[k];
      if (w && typeof w.utilization === "number") meters.push(pctMeter(`weekly-${slug(name)}`, `${name} weekly`, w.utilization, w.resets_at));
    }
  }

  // Cloud credits: a dollar allowance with its own reset (CodexBar knows the
  // field as iguana_necktie; the API names its buckets with codenames).
  const cc = data.iguana_necktie;
  if (cc && typeof cc.limit_dollars === "number" && cc.limit_dollars > 0)
    meters.push(usdMeter("cloud-credits", "Cloud credits", cc.used_dollars ?? 0, cc.limit_dollars, cc.resets_at));

  // Extra usage: pay-as-you-go past the plan limits, capped monthly.
  const spend = data.spend;
  const xu = data.extra_usage;
  if (spend?.enabled && money(spend.limit) !== null) {
    meters.push(usdMeter("extra", "Extra usage", money(spend.used) ?? 0, money(spend.limit)));
  } else if (xu?.is_enabled && typeof xu.monthly_limit === "number") {
    const scale = 10 ** (xu.decimal_places ?? 2);
    meters.push(usdMeter("extra", "Extra usage", (xu.used_credits ?? 0) / scale, xu.monthly_limit / scale));
  }

  return { status: "ok", meters, subtitle: plan };
}

// ── Anthropic API (month-to-date cost via the Admin API) ───────────────────

// Held for the daemon's lifetime; never written anywhere.
const keyCache = new Map<string, string>();

async function adminKey(id: string, src: KeySource | undefined): Promise<{ key?: string; why?: string }> {
  const cached = keyCache.get(id);
  if (cached) return { key: cached };
  let key = "";
  if (src?.env) {
    key = process.env[src.env]?.trim() ?? "";
    if (!key) return { why: `$${src.env} is unset` };
  } else if (src?.file) {
    try {
      key = fs.readFileSync(expand(src.file), "utf8").trim();
    } catch {
      return { why: `can't read ${src.file}` };
    }
  } else if (src?.op) {
    // `op` stays the ambient one: the setgid, desktop-integrated binary.
    // A cold handshake can fail once; `op signin` primes the session.
    let r = await run(["op", "read", "--no-newline", src.op]);
    if (!r.ok) {
      await run(["op", "signin"]);
      r = await run(["op", "read", "--no-newline", src.op]);
    }
    if (!r.ok) return { why: `1Password: ${r.err.split("\n")[0] || "read failed"}` };
    key = r.out.trim();
  } else return { why: "no adminKey in config" };
  if (!key) return { why: "the admin key is empty" };
  keyCache.set(id, key);
  return { key };
}

async function fetchAnthropicApi(cfg: AccountConfig): Promise<Result> {
  const { key, why } = await adminKey(cfg.id, cfg.adminKey);
  if (!key) {
    const op = !!cfg.adminKey?.op;
    return { status: "setup", message: `${why}${op ? "; refresh to retry" : ""}`, retryInMs: op ? 60 * MIN : 10 * MIN };
  }

  const now = new Date();
  const monthStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
  const today = now.toISOString().slice(0, 10);
  const iso = (d: Date) => d.toISOString().replace(/\.\d{3}Z$/, "Z");
  const filter = cfg.workspaceId !== undefined;

  let totalCents = 0;
  let todayCents = 0;
  let page: string | null = null;
  for (let i = 0; i < 6; i++) {
    const u = new URL("https://api.anthropic.com/v1/organizations/cost_report");
    u.searchParams.set("starting_at", iso(monthStart));
    u.searchParams.set("bucket_width", "1d");
    u.searchParams.set("limit", "31");
    if (filter) u.searchParams.append("group_by[]", "workspace_id");
    if (page) u.searchParams.set("page", page);
    const { res, data, err } = await getJson(u.toString(), { "x-api-key": key, "anthropic-version": "2023-06-01" });
    if (!data) {
      if (res?.status === 401 || res?.status === 403) keyCache.delete(cfg.id); // re-read next time
      return httpFailure("Admin API", res, err);
    }
    for (const bucket of data.data ?? []) {
      for (const r of bucket.results ?? []) {
        if (filter && (r.workspace_id ?? null) !== cfg.workspaceId) continue;
        const cents = Number.parseFloat(r.amount); // decimal string, in cents
        if (!Number.isFinite(cents)) continue;
        totalCents += cents;
        if (String(bucket.starting_at).startsWith(today)) todayCents += cents;
      }
    }
    page = data.has_more ? data.next_page : null;
    if (!page) break;
  }

  const nextMonth = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1)).toISOString();
  return {
    status: "ok",
    meters: [
      usdMeter("month", "This month", totalCents / 100, cfg.budget ?? null, nextMonth),
      usdMeter("today", "Today (UTC)", todayCents / 100, null),
    ],
  };
}

// ── Hermes (its own cost estimate, from its session log) ───────────────────

// Hermes prices every API call it makes (official list prices, snapshotted in
// its release) into session_model_usage. That needs no Admin API access,
// which a Claude Console *individual* org doesn't get at all. It counts only
// Hermes' calls, at list price, and only where Hermes runs. Month and day are
// UTC, as Anthropic bills.
function fetchHermes(cfg: AccountConfig): Result {
  const file = expand(cfg.stateDb ?? "/var/lib/hermes/.hermes/state.db");
  if (!fs.existsSync(file)) return { status: "setup", message: `No Hermes state at ${file}`, retryInMs: 30 * MIN };
  const now = new Date();
  const month = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1) / 1000;
  const today = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()) / 1000;
  let db: Database | undefined;
  try {
    db = new Database(file, { readonly: true });
    const cost = "CASE WHEN actual_cost_usd > 0 THEN actual_cost_usd ELSE estimated_cost_usd END";
    const sum = (since: number) =>
      db!
        .query(`SELECT coalesce(sum(${cost}), 0) AS usd, count(DISTINCT session_id) AS sessions
                FROM session_model_usage WHERE billing_provider = 'anthropic' AND last_seen >= ?`)
        .get(since) as { usd: number; sessions: number };
    const m = sum(month);
    const d = sum(today);
    const nextMonth = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1)).toISOString();
    return {
      status: "ok",
      subtitle: "estimated",
      meters: [
        usdMeter("month", `This month · ${m.sessions} session${m.sessions === 1 ? "" : "s"}`, m.usd, cfg.budget ?? null, nextMonth),
        usdMeter("today", "Today (UTC)", d.usd, null),
      ],
    };
  } catch (e: any) {
    return { status: "stale", message: `Hermes state: ${e?.message ?? e}`, retryInMs: 5 * MIN };
  } finally {
    db?.close();
  }
}

// ── ChatGPT / Codex (plan limits via chatgpt.com's wham/usage) ─────────────

// Codex keeps auth in $CODEX_HOME/auth.json by default; with
// cli_auth_credentials_store = "keyring" it's in the keychain under service
// "Codex Auth", account "cli|<sha256(realpath CODEX_HOME)[:16]>".
function codexAuth(home: string): any | null {
  const dir = expand(home);
  const file = readJson<any>(path.join(dir, "auth.json"));
  if (file) return file;
  if (IS_MAC) {
    let real = dir;
    try {
      real = fs.realpathSync(dir);
    } catch {}
    const account = `cli|${crypto.createHash("sha256").update(real).digest("hex").slice(0, 16)}`;
    const p = Bun.spawnSync(["/usr/bin/security", "find-generic-password", "-s", "Codex Auth", "-a", account, "-w"]);
    if (p.success) {
      try {
        return JSON.parse(p.stdout.toString());
      } catch {}
    }
  }
  return null;
}

function windowLabel(seconds: number): string {
  if (seconds === 18_000) return "Session (5h)";
  if (seconds === 604_800) return "Weekly";
  return seconds % 86_400 === 0 ? `${seconds / 86_400}d window` : `${Math.round(seconds / 3600)}h window`;
}

function windowMeter(prefix: string, w: any): Meter | null {
  if (!w || typeof w.used_percent !== "number") return null;
  const label = windowLabel(Number(w.limit_window_seconds));
  const resets =
    typeof w.reset_at === "number"
      ? new Date(w.reset_at * 1000).toISOString()
      : typeof w.reset_after_seconds === "number"
        ? new Date(Date.now() + w.reset_after_seconds * 1000).toISOString()
        : null;
  return pctMeter(slug(`${prefix} ${label}`), prefix ? `${prefix} ${label.toLowerCase()}` : label, w.used_percent, resets);
}

async function fetchCodex(cfg: AccountConfig): Promise<Result> {
  const auth = codexAuth(cfg.codexHome ?? process.env.CODEX_HOME ?? "~/.codex");
  const t = auth?.tokens;
  if (!t?.access_token) {
    const apiKeyOnly = auth && (auth.OPENAI_API_KEY || auth.auth_mode === "apikey");
    return {
      status: "setup",
      message: apiKeyOnly ? "Codex uses an API key; `codex login` with ChatGPT for plan limits" : "Install Codex and sign in with ChatGPT (codex login)",
      retryInMs: 5 * MIN,
    };
  }
  const claims = jwtClaims(t.access_token);
  if (claims?.exp && claims.exp * 1000 < Date.now())
    return { status: "stale", message: "Token expired; run codex to renew it", retryInMs: 2 * MIN };
  const idClaims = t.id_token ? jwtClaims(t.id_token) : null;
  const accountId =
    t.account_id ?? idClaims?.chatgpt_account_id ?? idClaims?.["https://api.openai.com/auth"]?.chatgpt_account_id;

  const headers: Record<string, string> = { Authorization: `Bearer ${t.access_token}`, "User-Agent": "ai-usage" };
  if (accountId) headers["ChatGPT-Account-Id"] = accountId;
  const { res, data, err } = await getJson("https://chatgpt.com/backend-api/wham/usage", headers);
  if (!data) return httpFailure("ChatGPT", res, err);

  const meters: Meter[] = [];
  for (const w of [data.rate_limit?.primary_window, data.rate_limit?.secondary_window]) {
    const m = windowMeter("", w);
    if (m) meters.push(m);
  }
  for (const extra of data.additional_rate_limits ?? []) {
    const name = extra.limit_name ?? extra.metered_feature ?? "Limit";
    for (const w of [extra.rate_limit?.primary_window, extra.rate_limit?.secondary_window]) {
      const m = windowMeter(titleCase(String(name)), w);
      if (m) meters.push(m);
    }
  }
  const c = data.credits;
  if (c?.has_credits && !c.unlimited && c.balance != null && c.balance !== "")
    meters.push({ id: "credits", label: "Credits", percent: null, value: String(c.balance) });

  const plan = data.plan_type ? titleCase(String(data.plan_type)) : undefined;
  return { status: "ok", meters, subtitle: plan };
}

const FETCH: Record<Provider, (cfg: AccountConfig) => Promise<Result>> = {
  claude: fetchClaude,
  "anthropic-api": fetchAnthropicApi,
  hermes: async (cfg) => fetchHermes(cfg),
  codex: fetchCodex,
};

// ── Config, snapshot, scheduling ───────────────────────────────────────────

function loadConfig(): AccountConfig[] {
  const c = readJson<Config>(CONFIG);
  const list = Array.isArray(c?.accounts) ? c!.accounts : [];
  return list.filter((a) => a?.id && !a.disabled && FETCH[a.provider] && (!a.hosts?.length || a.hosts.includes(HOST)));
}

function readSnapshot(): Snapshot | null {
  return readJson<Snapshot>(SNAPSHOT);
}

// The static half of an account (labels, logo, price) always follows the
// config; the live half (status, meters, timing) carries over.
function shell(cfg: AccountConfig, prev: Account | undefined): Account {
  const d = DEFAULTS[cfg.provider];
  return {
    id: cfg.id,
    provider: cfg.provider,
    title: cfg.title ?? d.title,
    plan: prev?.plan,
    subtitle: joinSubtitle(cfg, prev?.plan),
    logo: d.logo,
    tint: d.tint,
    color: cfg.color ?? d.color,
    price: cfg.price ? `${usd(cfg.price, false)}/mo` : undefined,
    url: cfg.url,
    status: prev?.status ?? "pending",
    message: prev?.message,
    meters: prev?.meters ?? [],
    fetchedAt: prev?.fetchedAt,
    checkedAt: prev?.checkedAt,
    nextAt: prev?.nextAt,
    blockedUntil: prev?.blockedUntil,
  };
}

function joinSubtitle(cfg: AccountConfig, live?: string): string | undefined {
  // "ChatGPT Plus · Plus" says it twice: drop a plan the title already names.
  const title = (cfg.title ?? "").toLowerCase();
  const plan = live && !title.includes(live.toLowerCase()) ? live : undefined;
  const parts = [plan, cfg.subtitle].filter(Boolean);
  return parts.length ? parts.join(" · ") : undefined;
}

async function refreshAccount(cfg: AccountConfig, prev: Account | undefined, force: boolean): Promise<Account> {
  const acc = shell(cfg, prev);
  const now = Date.now();
  if ((acc.blockedUntil ?? 0) > now) return acc;
  // A forced refresh still waits a minute after the last attempt, so a
  // mashed refresh button can't spend the provider's quota.
  const recent = now - Date.parse(acc.checkedAt ?? "") < FORCE_GAP_MS;
  if ((!force || recent) && (acc.nextAt ?? 0) > now) return acc;

  const r = await FETCH[cfg.provider](cfg);
  const interval = (cfg.interval ?? DEFAULTS[cfg.provider].interval) * MIN;
  acc.checkedAt = new Date().toISOString();
  acc.message = r.message;
  if (r.subtitle !== undefined) {
    acc.plan = r.subtitle;
    acc.subtitle = joinSubtitle(cfg, r.subtitle);
  }
  acc.blockedUntil = r.blockMs ? now + r.blockMs : undefined;
  acc.nextAt = now + (r.blockMs ?? r.retryInMs ?? interval);
  if (r.status === "ok") {
    acc.status = "ok";
    acc.meters = r.meters ?? [];
    acc.fetchedAt = acc.checkedAt;
  } else if (r.status === "setup") {
    acc.status = "setup";
    acc.meters = [];
  } else {
    // stale beats nothing: keep the last good meters through a failure
    acc.status = acc.meters.length ? "stale" : r.status;
  }
  return acc;
}

// One pass over every account; returns the new snapshot (written if changed).
async function collect(force: boolean): Promise<Snapshot> {
  const prev = readSnapshot();
  const byId = new Map((prev?.accounts ?? []).map((a) => [a.id, a]));
  const accounts: Account[] = [];
  for (const cfg of loadConfig()) {
    try {
      accounts.push(await refreshAccount(cfg, byId.get(cfg.id), force));
    } catch (e: any) {
      const a = shell(cfg, byId.get(cfg.id));
      a.status = a.meters.length ? "stale" : "error";
      a.message = `internal error: ${e?.message ?? e}`;
      a.nextAt = Date.now() + 5 * MIN;
      accounts.push(a);
    }
  }
  const snap: Snapshot = { version: 1, host: HOST, updatedAt: new Date().toISOString(), accounts };
  const strip = (s: Snapshot | null) => JSON.stringify(s?.accounts ?? null);
  if (strip(prev) !== strip(snap)) writeAtomic(SNAPSHOT, JSON.stringify(snap, null, 2) + "\n");
  return snap;
}

// One collector at a time: exclusive create, with a staleness escape.
function lock(): boolean {
  fs.mkdirSync(CACHE_DIR, { recursive: true });
  for (let i = 0; i < 2; i++) {
    try {
      fs.writeFileSync(LOCKFILE, String(process.pid), { flag: "wx" });
      return true;
    } catch {
      try {
        if (Date.now() - fs.statSync(LOCKFILE).mtimeMs < 3 * MIN) return false;
        fs.unlinkSync(LOCKFILE);
      } catch {
        return false;
      }
    }
  }
  return false;
}
function unlock() {
  try {
    if (Number(fs.readFileSync(LOCKFILE, "utf8")) === process.pid) fs.unlinkSync(LOCKFILE);
  } catch {}
}

function daemonPid(): number | null {
  const pid = Number(fs.existsSync(PIDFILE) ? fs.readFileSync(PIDFILE, "utf8") : 0);
  if (!pid) return null;
  try {
    process.kill(pid, 0);
    return pid;
  } catch {
    return null;
  }
}

async function daemon() {
  const other = daemonPid();
  if (other && other !== process.pid) {
    console.error(`ai-usage: daemon already running (pid ${other})`);
    process.exit(0);
  }
  fs.mkdirSync(CACHE_DIR, { recursive: true });
  fs.writeFileSync(PIDFILE, String(process.pid));
  try {
    fs.unlinkSync(LOCKFILE); // a lock left by a killed predecessor
  } catch {}

  let busy = false;
  let again = false; // a refresh arrived mid-pass
  let force = false;
  const pass = async () => {
    if (busy) {
      again = true;
      return;
    }
    busy = true;
    try {
      do {
        again = false;
        const f = force;
        force = false;
        if (lock()) {
          try {
            await collect(f);
          } finally {
            unlock();
          }
        }
      } while (again);
    } catch (e: any) {
      console.error(`ai-usage: ${e?.message ?? e}`);
    } finally {
      busy = false;
    }
  };

  // SIGUSR1 = refresh now: reread the config, drop cached keys (so a locked
  // 1Password gets another try), and fetch everything not server-blocked.
  process.on("SIGUSR1", () => {
    keyCache.clear();
    force = true;
    void pass();
  });
  const bye = () => {
    try {
      if (Number(fs.readFileSync(PIDFILE, "utf8")) === process.pid) fs.unlinkSync(PIDFILE);
    } catch {}
    unlock();
    process.exit(0);
  };
  process.on("SIGTERM", bye);
  process.on("SIGINT", bye);

  console.error(`ai-usage: daemon ${process.pid} on ${HOST}; config ${CONFIG}; writing ${SNAPSHOT}`);
  await pass();
  setInterval(pass, TICK_MS);
}

// ── Terminal view ──────────────────────────────────────────────────────────

const tty = process.stdout.isTTY && !process.env.NO_COLOR;
const sgr = (code: string) => (s: string) => (tty ? `\x1b[${code}m${s}\x1b[0m` : s);
const dim = sgr("2");
const bold = sgr("1");
const hex = (h: string) => {
  const n = Number.parseInt(h.replace("#", ""), 16);
  return sgr(`38;2;${(n >> 16) & 255};${(n >> 8) & 255};${n & 255}`);
};
const GLYPH: Record<string, string> = { claude: "✻", anthropic: "A", openai: "◎" };
const SEV_COLOR: Record<Severity, string | null> = { normal: null, warning: "#E6C384", critical: "#E46876" };

function bar(pct: number, width: number, color: string): string {
  const cells = (clamp(pct) / 100) * width;
  const full = Math.floor(cells);
  const parts = " ▏▎▍▌▋▊▉";
  const frac = parts[Math.round((cells - full) * 8)] ?? "";
  const filled = "█".repeat(full) + (full < width && frac.trim() ? frac : "");
  const rest = width - full - (full < width && frac.trim() ? 1 : 0);
  return hex(color)(filled) + dim("·".repeat(Math.max(0, rest)));
}

function until(iso: string | null | undefined): string {
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

const ago = (iso?: string) => {
  if (!iso) return "never";
  const m = Math.round((Date.now() - Date.parse(iso)) / MIN);
  return m < 1 ? "just now" : m < 60 ? `${m}m ago` : `${Math.round(m / 60)}h ago`;
};

function render(snap: Snapshot | null): string {
  if (!snap?.accounts?.length)
    return `No usage yet. Is the daemon running? (ai-usage once fetches now)\nconfig: ${CONFIG}\n`;
  const out: string[] = [];
  const width = 22;
  for (const a of snap.accounts) {
    const head = `${hex(a.color)(GLYPH[a.logo] ?? "•")} ${bold(a.title)}${a.subtitle ? dim(` · ${a.subtitle}`) : ""}`;
    out.push(a.price ? `${head}  ${dim(a.price)}` : head);
    for (const m of a.meters) {
      const color = SEV_COLOR[m.severity ?? "normal"] ?? a.color;
      const reset = m.resetsAt ? dim(`  resets in ${until(m.resetsAt)}`) : "";
      const b = m.percent === null ? " ".repeat(width) : bar(m.percent, width, color);
      out.push(`  ${m.label.padEnd(16)} ${b}  ${m.value.padStart(m.percent === null ? 0 : 4)}${reset}`);
    }
    if (a.message) out.push(`  ${a.status === "ok" ? dim(a.message) : hex("#E6C384")(a.message)}`);
    if (a.fetchedAt) out.push(dim(`  updated ${ago(a.fetchedAt)}`));
    out.push("");
  }
  return out.join("\n");
}

// ── CLI ────────────────────────────────────────────────────────────────────

async function main() {
  const [cmd = "show", ...rest] = process.argv.slice(2);
  const json = rest.includes("--json");
  const print = (s: Snapshot | null) => process.stdout.write(json ? JSON.stringify(s, null, 2) + "\n" : render(s));

  switch (cmd) {
    case "show":
    case "--json":
      print(readSnapshot());
      return;
    case "daemon":
      return daemon();
    case "once": {
      if (daemonPid()) {
        console.error("ai-usage: the daemon is running; use `ai-usage refresh`");
        process.exit(1);
      }
      if (!lock()) {
        console.error("ai-usage: another collector is running");
        process.exit(1);
      }
      try {
        return print(await collect(rest.includes("--force")));
      } finally {
        unlock();
      }
    }
    case "refresh": {
      const pid = daemonPid();
      if (!pid) {
        if (!lock()) return print(readSnapshot());
        try {
          return print(await collect(true));
        } finally {
          unlock();
        }
      }
      const before = fs.existsSync(SNAPSHOT) ? fs.statSync(SNAPSHOT).mtimeMs : 0;
      process.kill(pid, "SIGUSR1");
      for (let i = 0; i < 40; i++) {
        await Bun.sleep(500);
        if ((fs.existsSync(SNAPSHOT) ? fs.statSync(SNAPSHOT).mtimeMs : 0) !== before) break;
      }
      return print(readSnapshot());
    }
    case "path":
      return console.log(CACHE_DIR);
    case "config":
      return console.log(CONFIG);
    default:
      console.log(
        "usage: ai-usage [show [--json] | refresh | once [--force] | daemon | path | config]\n" +
          `  config:   ${CONFIG}\n  snapshot: ${SNAPSHOT}`,
      );
      process.exit(cmd === "help" || cmd === "--help" || cmd === "-h" ? 0 : 2);
  }
}

await main();
