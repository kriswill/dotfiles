#!/usr/bin/env bun
// ai-usage: what the AI accounts have used. Claude Ultra/Max (plan limits + extra
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
//   and ~/.claude-work/claude-usage-work.ts draws on the same bucket.
//   So: every 10 min at most, retry-after honoured exactly, and the last good
//   reading kept through any failure.
// - OAuth credentials are only READ here; this collector never redeems a
//   refresh token itself. Each provider's own CLI renews an expired login:
//   Codex through its app-server, Claude through a prompt-less `claude -p`
//   session whose get_usage control request renews the token and then
//   answers this poll (claudeCliUsage).
// - The Admin API key is read once per daemon lifetime (1Password `op read`,
//   a file, or an env var) and held in memory only.

import { Database } from "bun:sqlite";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { createInterface } from "node:readline";
import { Readable } from "node:stream";

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
  plan?: string; // what the provider says the plan is ("20x", "Plus")
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

type Provider = "claude" | "anthropic-api" | "hermes" | "codex" | "antigravity";
type KeySource = { op?: string; file?: string; env?: string };
type GcpBillingConfig = {
  table: string; // BigQuery billing export table: project.dataset.gcp_billing_export_v1_...
  projectId?: string; // GCP project to run the BigQuery job in (default: settings.json gcp.project or table's project)
  filterProjectId?: string | null; // project.id filter in SQL (default: projectId; null = all projects)
  serviceId?: string | null; // billing service.id filter (default: "C7E2-9256-1C43" = Vertex AI / Agent Platform; null = all)
  credentials?: KeySource; // service account or ADC JSON ({op|file|env}); omitted = GOOGLE_APPLICATION_CREDENTIALS / gcloud ADC
};
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
  budget?: number; // anthropic-api, hermes, antigravity: $/month the bar fills toward
  stateDb?: string; // hermes: its state.db
  workspaceId?: string | null; // anthropic-api: one workspace only (null = Default)
  codexHome?: string; // codex
  localCost?: boolean; // codex: local session API-equivalent estimate, never billed spend
  agyDir?: string; // antigravity: CLI app data dir (default ~/.gemini/antigravity-cli)
  gcpBilling?: GcpBillingConfig; // antigravity: exact Google Cloud spend from BigQuery billing export (+ optional Budgets API)
  gcpBillingFile?: string; // optional per-host JSON; missing file leaves the normal local fallback enabled
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
  antigravity: { title: "Antigravity", logo: "gemini", tint: false, color: "#4285F4", interval: 10 },
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

export function claudePlan(o: any): string | undefined {
  // The usage service names the tiers max_5x / max_20x, but the $200/mo 20x
  // tier is sold as "Claude Ultra" (5x stays "Claude Max"): show only the
  // multiplier and let the config title carry the plan name.
  const tier = String(o?.rateLimitTier ?? "");
  const m = tier.match(/max_(\d+)x/);
  if (m) return `${m[1]}x`;
  const sub = String(o?.subscriptionType ?? "");
  return sub ? titleCase(sub) : undefined;
}

// Money as the endpoint sends it: an integer in minor units + its exponent.
const money = (m: any): number | null =>
  m && typeof m.amount_minor === "number" ? m.amount_minor / 10 ** (m.exponent ?? 2) : null;

// The api/oauth/usage body (direct, or as get_usage's rate_limits) as meters.
export function claudeMeters(data: any): Meter[] {
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

  // Extra usage: pay-as-you-go past the plan limits, capped monthly. An
  // enterprise seat has no plan limits (limits: [], every window null): the
  // same block is then the org's whole credit spend, so name it that.
  const spendLabel = meters.length ? "Extra usage" : "Credit spend";
  const spend = data.spend;
  const xu = data.extra_usage;
  if (spend?.enabled && money(spend.limit) !== null) {
    meters.push(usdMeter("extra", spendLabel, money(spend.used) ?? 0, money(spend.limit)));
  } else if (xu?.is_enabled && typeof xu.monthly_limit === "number") {
    const scale = 10 ** (xu.decimal_places ?? 2);
    meters.push(usdMeter("extra", spendLabel, (xu.used_credits ?? 0) / scale, xu.monthly_limit / scale));
  }
  return meters;
}

const findClaude = () =>
  Bun.which("claude") ??
  [path.join(HOME, ".local/bin/claude"), path.join(HOME, ".nix-profile/bin/claude"), `/etc/profiles/per-user/${os.userInfo().username}/bin/claude`]
    .find((p) => fs.existsSync(p));

// Claude Code renews its own OAuth login under a lock in the config dir, and
// re-reads the store under that lock in case another session already rotated
// the refresh token. Redeeming the token from here could race that and void
// the login, so an expired login goes through the CLI: a prompt-less print
// session (safe mode: no hooks, MCP servers or plugins; no transcript) asked
// for the SDK's get_usage control request, which awaits that renewal before
// it reads api/oauth/usage. Its rate_limits is that endpoint's body, so the
// same request is this poll's reading too, and no model call is made. On
// failure rate_limits is just null: no status, no retry-after. get_usage is
// marked experimental upstream; anything unexpected surfaces as `why`.
export async function claudeCliUsage(configDir: string, command?: string, timeoutMs = 60_000): Promise<{ limits?: any; why?: string }> {
  const executable = command ?? findClaude();
  if (!executable) return { why: "claude isn't installed" };
  const dir = expand(configDir);
  // ~/.claude is the default with CLAUDE_CONFIG_DIR unset (its keychain item
  // has no hash suffix); anything else is named explicitly.
  const env: Record<string, string | undefined> = { ...process.env, DISABLE_AUTOUPDATER: "1", CLAUDE_CONFIG_DIR: dir };
  if (dir === path.join(HOME, ".claude")) delete env.CLAUDE_CONFIG_DIR;
  let child: ReturnType<typeof Bun.spawn> | undefined;
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    fs.mkdirSync(CACHE_DIR, { recursive: true });
    child = Bun.spawn(
      [executable, "-p", "--safe-mode", "--no-session-persistence", "--strict-mcp-config",
        "--input-format", "stream-json", "--output-format", "stream-json", "--verbose"],
      { cwd: CACHE_DIR, env, stdin: "pipe", stdout: "pipe", stderr: "ignore" },
    );
    const proc = child;
    (proc.stdin as any).write(JSON.stringify({ type: "control_request", request_id: "usage", request: { subtype: "get_usage", skip_behaviors: true } }) + "\n");
    (proc.stdin as any).flush();
    const read = async (): Promise<{ limits?: any; why?: string }> => {
      const lines = createInterface({ input: Readable.fromWeb(proc.stdout as any) });
      try {
        for await (const line of lines) {
          let msg: any;
          try { msg = JSON.parse(line); } catch { continue; }
          const r = msg?.type === "control_response" ? msg.response : null;
          if (r?.request_id !== "usage") continue;
          if (r.subtype !== "success") return { why: `claude: ${String(r.error ?? "get_usage failed").slice(0, 120)}` };
          if (r.response?.rate_limits) return { limits: r.response.rate_limits };
          return { why: r.response?.rate_limits_available === false ? "claude isn't signed in to a Claude plan" : "claude got no usage reading" };
        }
        return { why: "claude exited without answering" };
      } finally { lines.close(); }
    };
    return await Promise.race([
      read(),
      new Promise<{ why: string }>((resolve) => { timer = setTimeout(() => resolve({ why: "claude timed out" }), timeoutMs); }),
    ]);
  } catch (e: any) {
    return { why: `claude: ${e?.message ?? e}` };
  } finally {
    clearTimeout(timer);
    if (child) {
      // EOF lets it exit by itself, so a token write in flight lands; only a
      // hung one is signalled.
      const proc = child;
      try { (proc.stdin as any).end(); } catch {}
      const exited = (ms: number) => Promise.race([proc.exited.then(() => true), Bun.sleep(ms).then(() => false)]);
      const grace = Math.min(15_000, timeoutMs);
      if (!(await exited(grace))) {
        proc.kill("SIGTERM");
        if (!(await exited(5_000))) proc.kill("SIGKILL");
      }
    }
  }
}

async function fetchClaude(cfg: AccountConfig): Promise<Result> {
  // configDir may list candidates; the first holding a login wins (macs keep
  // the personal profile in ~/.claude-me, nebula in ~/.claude).
  const dirs = ([] as string[]).concat(cfg.configDir ?? process.env.CLAUDE_CONFIG_DIR ?? "~/.claude");
  const login = dirs.map((dir) => ({ dir, o: claudeCredentials(dir) })).find(({ o }) => o?.accessToken?.trim() || o?.refreshToken);
  if (!login) return { status: "setup", message: "Sign in to Claude Code (claude /login)", retryInMs: 5 * MIN };
  const { dir, o } = login;
  const plan = claudePlan(o);
  const token = o.accessToken?.trim();

  // An access token lasts ~8h and only a running Claude Code renews it, so
  // an idle profile's login lapses: let the CLI renew it and read the usage.
  if (!token || (typeof o.expiresAt === "number" && o.expiresAt < Date.now() + MIN)) {
    const { limits, why } = await claudeCliUsage(dir);
    if (limits) return { status: "ok", meters: claudeMeters(limits), subtitle: plan };
    const now = claudeCredentials(dir);
    const renewed = typeof now?.expiresAt === "number" && now.expiresAt > Date.now() + MIN;
    return {
      status: "stale",
      // Renewed but no reading is most likely the endpoint's 429, which
      // get_usage doesn't pass on: back off rather than ask again now.
      message: renewed ? `Claude usage unavailable (${why})` : `Login expired and renewal failed (${why}); run claude /login`,
      subtitle: plan,
      retryInMs: 15 * MIN,
    };
  }

  const { res, data, err } = await getJson("https://api.anthropic.com/api/oauth/usage", {
    Authorization: `Bearer ${token}`,
    "anthropic-beta": "oauth-2025-04-20",
  });
  if (!data) return { ...httpFailure("Claude", res, err), subtitle: plan };
  return { status: "ok", meters: claudeMeters(data), subtitle: plan };
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

// Let the official client own token rotation and persistence. Never redeem a
// refresh token ourselves, and never return account details from this helper.
export async function renewCodexLogin(home: string, command?: string, timeoutMs = 30_000): Promise<boolean> {
  const executable = command ?? Bun.which("codex") ??
    [path.join(HOME, ".local/bin/codex"), path.join(HOME, ".nix-profile/bin/codex")]
      .find((p) => fs.existsSync(p));
  if (!executable) return false;
  let child: ReturnType<typeof Bun.spawn> | undefined;
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    child = Bun.spawn([executable, "app-server"], {
      env: { ...process.env, CODEX_HOME: expand(home) },
      stdin: "pipe", stdout: "pipe", stderr: "ignore",
    });
    const proc = child;
    const send = (message: object) => {
      (proc.stdin as any).write(JSON.stringify(message) + "\n");
      (proc.stdin as any).flush();
    };
    const read = async () => {
      const lines = createInterface({ input: (await import("node:stream")).Readable.fromWeb(proc.stdout as any) });
      try {
        send({ id: 1, method: "initialize", params: { clientInfo: { name: "ai_usage", version: "1" } } });
        for await (const line of lines) {
          let msg: any;
          try { msg = JSON.parse(line); } catch { continue; }
          if (msg.id === 1) {
            if (msg.error) return false;
            send({ method: "initialized" });
            send({ id: 2, method: "account/read", params: { refreshToken: true } });
          } else if (msg.id === 2) {
            return !msg.error && msg.result?.account?.type === "chatgpt";
          }
        }
        return false;
      } finally { lines.close(); }
    };
    return await Promise.race([
      read(),
      new Promise<boolean>((resolve) => { timer = setTimeout(() => resolve(false), timeoutMs); }),
    ]);
  } catch { return false; }
  finally {
    clearTimeout(timer);
    child?.kill("SIGKILL");
    if (child) await child.exited;
  }
}

// Standard API USD / million tokens, verified 2026-11-01:
// https://developers.openai.com/api/docs/pricing
// This is a comparison at current standard prices, not subscription billing.
const CODEX_PRICES: Record<string, [number, number, number]> = {
  "gpt-6-astra": [10, 1, 50],
  "gpt-6.1-sol": [2, 0.1, 10],
  "gpt-6.1-terra": [1, 0.05, 5],
  "gpt-6-luna": [0.1, 0.01, 0.5],
  "gpt-5.6-sol": [4, 0.4, 20],
  "gpt-5.3-codex": [1.75, 0.175, 14],
};

type CostEvent = { key: string; time: number; model: string; input: number; cached: number; output: number };
const sessionCostCache = new Map<string, { size: number; mtime: number; events: CostEvent[] }>();

export function codexCostEvents(text: string): CostEvent[] {
  let model = "unknown";
  let previous = [0, 0, 0];
  const events: CostEvent[] = [];
  for (const line of text.split("\n")) {
    let e: any;
    try { e = JSON.parse(line); } catch { continue; } // an in-progress final line
    const p = e.payload;
    if (e.type === "turn_context") model = p?.model ?? "unknown";
    if (e.type !== "event_msg" || p?.type !== "token_count") continue;
    const u = p.info?.total_token_usage;
    if (!u) continue;
    const total = [u.input_tokens, u.cached_input_tokens ?? 0, u.output_tokens];
    if (!total.every((n) => Number.isFinite(n) && n >= 0)) continue;
    // Repeated token_count notifications carry the same cumulative counters.
    // After a counter reset, count only the explicitly reported last request.
    const last = p.info?.last_token_usage;
    const delta = total.some((n, i) => n < previous[i])
      ? [last?.input_tokens, last?.cached_input_tokens ?? 0, last?.output_tokens]
      : total.map((n, i) => n - previous[i]);
    previous = total;
    if (!delta.every((n) => Number.isFinite(n) && n >= 0) || delta.every((n) => n === 0)) continue;
    const time = Date.parse(e.timestamp);
    if (!Number.isFinite(time)) continue;
    // Forks can copy parent history. Identical historical events count once.
    const key = JSON.stringify([e.timestamp, model, total]);
    events.push({ key, time, model, input: delta[0], cached: delta[1], output: delta[2] });
  }
  return events;
}

export function codexLocalCost(home: string, now = new Date()): { meters: Meter[]; message: string } {
  const month = new Date(now.getFullYear(), now.getMonth(), 1).getTime();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  const seen = new Set<string>();
  const unknown = new Set<string>();
  let monthUsd = 0, todayUsd = 0, count = 0;
  // Include archived sessions and older files resumed this month. Only read
  // changed files; never cache prompts, tool output, or credentials.
  for (const folder of ["sessions", "archived_sessions"]) {
    const root = path.join(expand(home), folder);
    if (!fs.existsSync(root)) continue;
    for (const name of new Bun.Glob("**/*.jsonl").scanSync({ cwd: root })) {
      const file = path.join(root, name);
      let events: CostEvent[];
      try {
        const stat = fs.statSync(file);
        if (stat.mtimeMs < month) continue;
        const cached = sessionCostCache.get(file);
        events = cached?.size === stat.size && cached.mtime === stat.mtimeMs
          ? cached.events : codexCostEvents(fs.readFileSync(file, "utf8"));
        sessionCostCache.set(file, { size: stat.size, mtime: stat.mtimeMs, events });
      } catch { continue; } // a session may be archived while scanning
      for (const e of events) {
        if (e.time < month || e.time > now.getTime() || seen.has(e.key)) continue;
        seen.add(e.key);
        const rates = CODEX_PRICES[e.model];
        if (!rates) { unknown.add(e.model); continue; }
        const cached = Math.min(e.cached, e.input);
        const cost = ((e.input - cached) * rates[0] + cached * rates[1] + e.output * rates[2]) / 1e6;
        monthUsd += cost;
        if (e.time >= today) todayUsd += cost;
        count++;
      }
    }
  }
  const skipped = unknown.size ? ` Unpriced models omitted: ${[...unknown].sort().join(", ")}.` : "";
  return {
    meters: count ? [usdMeter("local-month", "Month est.", monthUsd, null), usdMeter("local-today", "Today est.", todayUsd, null)] : [],
    message: (count ? "Local API-equivalent estimate at standard rates; not billed spend. Excludes tools, speed/context surcharges and other devices."
      : "No priced local token usage this month.") + skipped,
  };
}

function windowLabel(seconds: number): string {
  if (seconds === 18_000) return "Session (5h)";
  if (seconds === 86_400) return "Daily";
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

export function codexPlanLabel(plan: string): string {
  // The $100 Pro tier is named "prolite" by the usage service.
  return plan === "prolite" ? "Pro" : titleCase(plan);
}

export function codexLimitMeters(data: any): Meter[] {
  const meters: Meter[] = [];
  const limits = [
    { name: "", limit: data.rate_limit },
    { name: "Code review", limit: data.code_review_rate_limit },
    ...(data.additional_rate_limits ?? []).map((extra: any) => ({
      name: titleCase(String(extra.limit_name ?? extra.metered_feature ?? "Limit")),
      limit: extra.rate_limit,
    })),
  ];
  for (const { name, limit } of limits) {
    for (const window of [limit?.primary_window, limit?.secondary_window]) {
      const meter = windowMeter(name, window);
      if (meter) meters.push(meter);
    }
  }
  return meters;
}

async function fetchCodex(cfg: AccountConfig): Promise<Result> {
  const home = cfg.codexHome ?? process.env.CODEX_HOME ?? "~/.codex";
  let auth = codexAuth(home);
  let t = auth?.tokens;
  if (!t?.access_token) {
    const apiKeyOnly = auth && (auth.OPENAI_API_KEY || auth.auth_mode === "apikey");
    return {
      status: "setup",
      message: apiKeyOnly ? "Codex uses an API key; `codex login` with ChatGPT for plan limits" : "Install Codex and sign in with ChatGPT (codex login)",
      retryInMs: 5 * MIN,
    };
  }
  const claims = jwtClaims(t.access_token);
  if (claims?.exp && claims.exp * 1000 < Date.now()) {
    if (await renewCodexLogin(home)) {
      auth = codexAuth(home);
      t = auth?.tokens;
    }
    const expires = t?.access_token && jwtClaims(t.access_token)?.exp;
    if (!t?.access_token || (expires && expires * 1000 < Date.now()))
      return { status: "stale", message: "Codex login expired; automatic renewal failed. Run codex login, then ai-usage refresh.", retryInMs: 10 * MIN };
  }
  const idClaims = t.id_token ? jwtClaims(t.id_token) : null;
  const accountId =
    t.account_id ?? idClaims?.chatgpt_account_id ?? idClaims?.["https://api.openai.com/auth"]?.chatgpt_account_id;

  const headers: Record<string, string> = { Authorization: `Bearer ${t.access_token}`, "User-Agent": "ai-usage" };
  if (accountId) headers["ChatGPT-Account-Id"] = accountId;
  const { res, data, err } = await getJson("https://chatgpt.com/backend-api/wham/usage", headers);
  if (!data) return httpFailure("ChatGPT", res, err);

  const meters = codexLimitMeters(data);
  const c = data.credits;
  if (c?.unlimited)
    meters.push({ id: "credits", label: "Credits", percent: null, value: "Unlimited" });
  else if (c?.balance != null && c.balance !== "")
    meters.push({ id: "credits", label: "Credits left", percent: null, value: String(c.balance) });

  const plan = data.plan_type ? codexPlanLabel(String(data.plan_type)) : undefined;
  const cost = cfg.localCost ? codexLocalCost(home) : undefined;
  return { status: "ok", meters: [...meters, ...(cost?.meters ?? [])], subtitle: plan, message: cost?.message };
}

// ── Antigravity (agy CLI quotas + GCP BigQuery billing / local transcript fallback) ─

const VERTEX_AI_SERVICE_ID = "C7E2-9256-1C43";
const BQ_TABLE_RE = /^[A-Za-z0-9_.:-]+\.[A-Za-z0-9_]+\.[A-Za-z0-9_]+$/;
const gcpTokenCache = new Map<string, { token: string; expiresAt: number }>();

const b64url = (v: string | Buffer) => Buffer.from(v).toString("base64url");

export function signGcpServiceAccountJwt(
  sa: { client_email: string; private_key: string; token_uri?: string },
  scopes: string[],
  nowSec = Math.floor(Date.now() / 1000),
): string {
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: scopes.join(" "),
    aud: sa.token_uri || "https://oauth2.googleapis.com/token",
    iat: nowSec,
    exp: nowSec + 3600,
  }));
  const input = `${header}.${claims}`;
  const sig = crypto.createSign("RSA-SHA256").update(input).sign(sa.private_key, "base64url");
  return `${input}.${sig}`;
}

async function gcpAccessToken(
  id: string,
  src: KeySource | undefined,
  scopes: string[],
  fetcher: typeof fetch = fetch,
): Promise<{ token?: string; why?: string; setup?: boolean }> {
  const cacheKey = `${id}:${scopes.join(" ")}`;
  const cached = gcpTokenCache.get(cacheKey);
  if (cached && cached.expiresAt > Date.now() + MIN) return { token: cached.token };

  const effectiveSrc: KeySource | undefined =
    src ??
    (process.env.GOOGLE_APPLICATION_CREDENTIALS
      ? { file: process.env.GOOGLE_APPLICATION_CREDENTIALS }
      : { file: "~/.config/gcloud/application_default_credentials.json" });

  const { key: raw, why } = await adminKey(`gcp:${id}`, effectiveSrc);
  if (!raw) return { why: why ?? "no GCP credentials configured", setup: true };

  let creds: any;
  try {
    creds = JSON.parse(raw);
  } catch {
    keyCache.delete(`gcp:${id}`);
    return { why: "GCP credentials are not valid JSON", setup: true };
  }

  let tokenUrl = creds.token_uri || "https://oauth2.googleapis.com/token";
  let body: URLSearchParams;
  if (creds.type === "service_account" && creds.client_email && creds.private_key) {
    try {
      const assertion = signGcpServiceAccountJwt(creds, scopes);
      body = new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion,
      });
    } catch (e: any) {
      keyCache.delete(`gcp:${id}`);
      return { why: `GCP key signing failed: ${e?.message ?? e}`, setup: true };
    }
  } else if (creds.type === "authorized_user" && creds.client_id && creds.client_secret && creds.refresh_token) {
    tokenUrl = "https://oauth2.googleapis.com/token";
    body = new URLSearchParams({
      grant_type: "refresh_token",
      client_id: creds.client_id,
      client_secret: creds.client_secret,
      refresh_token: creds.refresh_token,
    });
  } else {
    keyCache.delete(`gcp:${id}`);
    return { why: "GCP credentials must be a service_account or authorized_user JSON", setup: true };
  }

  try {
    const res = await fetcher(tokenUrl, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body,
      signal: AbortSignal.timeout(20_000),
    });
    const data: any = await res.json().catch(() => null);
    if (!res.ok || !data?.access_token) {
      if (res.status === 400 || res.status === 401) keyCache.delete(`gcp:${id}`);
      const reason = data?.error_description ?? data?.error ?? `HTTP ${res.status}`;
      return { why: `GCP OAuth: ${String(reason).slice(0, 140)}` };
    }
    const ttlMs = (Number(data.expires_in) || 3600) * 1000;
    gcpTokenCache.set(cacheKey, { token: data.access_token, expiresAt: Date.now() + ttlMs });
    return { token: data.access_token };
  } catch (e: any) {
    return { why: `GCP OAuth: ${e?.message ?? e}` };
  }
}

export function buildGcpBillingSql(table: string): string {
  if (!BQ_TABLE_RE.test(table)) throw new Error(`invalid BigQuery table identifier: ${table}`);
  return [
    "SELECT",
    "  COALESCE(SUM(cost) + SUM(IFNULL((SELECT SUM(c.amount) FROM UNNEST(credits) c), 0)), 0) AS net_mtd,",
    "  COALESCE(SUM(IF(DATE(usage_start_time, 'UTC') = CURRENT_DATE('UTC'),",
    "    cost + IFNULL((SELECT SUM(c.amount) FROM UNNEST(credits) c), 0), 0)), 0) AS net_today,",
    "  COALESCE(SUM(cost), 0) AS gross_mtd,",
    "  MAX(export_time) AS last_export,",
    "  COUNT(*) AS row_count",
    `FROM \`${table}\``,
    "WHERE invoice.month = FORMAT_DATE('%Y%m', CURRENT_DATE('America/Los_Angeles'))",
    "  AND (@projectId = '' OR project.id = @projectId)",
    "  AND (@serviceId = '' OR service.id = @serviceId)",
  ].join("\n");
}

export function parseGcpBillingRow(data: any): {
  netMtd: number;
  netToday: number;
  grossMtd: number;
  lastExport: string | null;
  rowCount: number;
} | null {
  const fields = data?.rows?.[0]?.f;
  if (!Array.isArray(fields) || fields.length < 5) return null;
  const num = (v: any) => {
    const n = Number.parseFloat(String(v ?? "0"));
    return Number.isFinite(n) ? n : 0;
  };
  let lastExport: string | null = null;
  const rawTs = fields[3]?.v;
  if (rawTs != null && rawTs !== "") {
    const sec = Number(rawTs);
    if (Number.isFinite(sec) && sec > 0) lastExport = new Date(sec * 1000).toISOString();
    else if (Number.isFinite(Date.parse(String(rawTs)))) lastExport = new Date(String(rawTs)).toISOString();
  }
  return {
    netMtd: num(fields[0]?.v),
    netToday: num(fields[1]?.v),
    grossMtd: num(fields[2]?.v),
    lastExport,
    rowCount: Math.max(0, Math.round(num(fields[4]?.v))),
  };
}

export function isMissingExpectedBillingTable(
  status: number | undefined,
  errorMessage: string | undefined,
  table: string,
): boolean {
  if (status !== 404 || !errorMessage) return false;
  const dot = table.indexOf(".");
  if (dot < 0) return false;
  const colonTable = `${table.slice(0, dot)}:${table.slice(dot + 1)}`;
  return /Not found:\s*Table\b/i.test(errorMessage) && (errorMessage.includes(colonTable) || errorMessage.includes(table));
}

export async function fetchGcpBilling(
  id: string,
  bq: GcpBillingConfig,
  fallbackProject: string | undefined,
  fetcher: typeof fetch = fetch,
): Promise<Result> {
  const table = bq.table?.trim();
  if (!table || !BQ_TABLE_RE.test(table)) {
    return { status: "error", subtitle: "GCP Billing", meters: [], message: "gcpBilling.table must be project.dataset.table", retryInMs: 30 * MIN };
  }

  const jobProject = bq.projectId ?? fallbackProject ?? table.split(".")[0];
  const filterProject = bq.filterProjectId === null ? "" : (bq.filterProjectId ?? bq.projectId ?? fallbackProject ?? "");
  const serviceId = bq.serviceId === null ? "" : (bq.serviceId ?? VERTEX_AI_SERVICE_ID);

  const scopes = ["https://www.googleapis.com/auth/bigquery.readonly"];

  const auth = await gcpAccessToken(id, bq.credentials, scopes, fetcher);
  if (!auth.token) {
    const op = !!bq.credentials?.op;
    return {
      status: auth.setup ? "error" : "stale",
      subtitle: "GCP Billing",
      meters: auth.setup ? [] : undefined,
      message: `${auth.why}${op ? "; refresh to retry" : ""}`,
      retryInMs: op ? 60 * MIN : 10 * MIN,
    };
  }

  const headers = {
    Authorization: `Bearer ${auth.token}`,
    Accept: "application/json",
    "Content-Type": "application/json",
  };
  const queryUrl = `https://bigquery.googleapis.com/bigquery/v2/projects/${encodeURIComponent(jobProject)}/queries`;
  let res: Response | undefined;
  let data: any;
  let rawWhy = "";
  let err: string | undefined;
  try {
    res = await fetcher(queryUrl, {
      method: "POST",
      headers,
      body: JSON.stringify({
        query: buildGcpBillingSql(table),
        useLegacySql: false,
        parameterMode: "NAMED",
        timeoutMs: 15_000,
        queryParameters: [
          { name: "projectId", parameterType: { type: "STRING" }, parameterValue: { value: filterProject } },
          { name: "serviceId", parameterType: { type: "STRING" }, parameterValue: { value: serviceId } },
        ],
      }),
      signal: AbortSignal.timeout(25_000),
    });
    if (!res.ok) {
      const body: any = await res.json().catch(() => null);
      rawWhy = String(body?.error?.message ?? "").slice(0, 200);
      err = rawWhy ? `HTTP ${res.status}: ${rawWhy}` : `HTTP ${res.status}`;
    } else {
      data = await res.json();
      // Poll briefly if a cold BigQuery job hasn't completed within timeoutMs.
      for (let i = 0; i < 3 && data && !data.jobComplete && data.jobReference?.jobId; i++) {
        const loc = data.jobReference.location ? `&location=${encodeURIComponent(data.jobReference.location)}` : "";
        const pollUrl = `${queryUrl}/${encodeURIComponent(data.jobReference.jobId)}?timeoutMs=10000${loc}`;
        const pr = await fetcher(pollUrl, { headers: { Authorization: `Bearer ${auth.token}`, Accept: "application/json" }, signal: AbortSignal.timeout(15_000) });
        if (!pr.ok) break;
        data = await pr.json();
      }
    }
  } catch (e: any) {
    err = String(e?.message ?? e);
  }

  if (isMissingExpectedBillingTable(res?.status, rawWhy, table)) {
    return {
      status: "pending",
      subtitle: "GCP Billing",
      meters: [],
      message: "Waiting for Google billing data",
      retryInMs: 10 * MIN,
    };
  }

  if (!data || !data.jobComplete) {
    if (res?.status === 401 || res?.status === 403) {
      gcpTokenCache.delete(`${id}:${scopes.join(" ")}`);
      keyCache.delete(`gcp:${id}`);
      return {
        status: "error",
        subtitle: "GCP Billing",
        meters: [],
        message: `BigQuery billing refused the credentials (${err ?? res.status})`,
        retryInMs: 15 * MIN,
      };
    }
    if (res?.status === 400 || res?.status === 404) {
      return {
        status: "error",
        subtitle: "GCP Billing",
        meters: [],
        message: `BigQuery billing: ${err ?? `HTTP ${res.status}`}`,
        retryInMs: 15 * MIN,
      };
    }
    return { ...httpFailure("BigQuery billing", res, err ?? "query did not complete"), subtitle: "GCP Billing" };
  }

  const parsed = parseGcpBillingRow(data);
  if (!parsed) {
    return {
      status: "error",
      subtitle: "GCP Billing",
      meters: [],
      message: "BigQuery billing returned an unexpected row shape",
      retryInMs: 10 * MIN,
    };
  }

  if (parsed.rowCount === 0) {
    return {
      status: "pending",
      subtitle: "GCP Billing",
      meters: [],
      message: "Waiting for Google billing data",
      retryInMs: 10 * MIN,
    };
  }

  const now = new Date();
  const nextMonth = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1)).toISOString();
  return {
    status: "ok",
    subtitle: "GCP Billing",
    meters: [
      usdMeter("month", "This month", parsed.netMtd, null, nextMonth),
      usdMeter("today", "Today (UTC)", parsed.netToday, null),
    ],
  };
}

const findAgy = () =>
  Bun.which("agy") ??
  [path.join(HOME, ".local/bin/agy"), path.join(HOME, ".nix-profile/bin/agy"), `/etc/profiles/per-user/${os.userInfo().username}/bin/agy`]
    .find((p) => fs.existsSync(p));

// Standard Google Cloud / Vertex AI global USD / million [input, cached, output]
// tokens, verified 2026-11-24. Output includes thinking/reasoning tokens.
function agyModelRates(model: string, timeMs: number): [number, number, number] | null {
  const base = model.toLowerCase().replace(/-(low|medium|high|xhigh|max)$/, "");
  const dec2026 = Date.UTC(2026, 11, 1);
  const jan2027 = Date.UTC(2027, 0, 1);
  if (base === "gemini-4-neon") return [3, 0.15, 15];
  if (base === "gemini-4-hydrogen") return [1.5, 0.075, 7.5];
  if (base === "gemini-4-carbon" || base === "gemini-4-argon") return timeMs >= dec2026 ? [4, 0.2, 20] : [2, 0.1, 10];
  if (base === "gemini-3.8-flash") return timeMs >= jan2027 ? [1.5, 0.15, 7.5] : [0.75, 0.075, 3.75];
  if (base === "gemini-3.1-pro") return [2, 0.2, 12];
  return null;
}

type AgyCostEvent = { time: number; model: string; input: number; cached: number; output: number };
const agyTranscriptCache = new Map<string, { size: number; mtime: number; events: AgyCostEvent[] }>();

export function antigravityTranscriptEvents(text: string): AgyCostEvent[] {
  const events: AgyCostEvent[] = [];
  for (const line of text.split("\n")) {
    let e: any;
    try { e = JSON.parse(line); } catch { continue; }
    if (typeof e?.input_tokens !== "number" || typeof e?.output_tokens !== "number" || typeof e?.model !== "string") continue;
    const cached = typeof e.cache_read_tokens === "number" ? e.cache_read_tokens : 0;
    if (e.input_tokens < 0 || cached < 0 || e.output_tokens < 0) continue;
    const time = Date.parse(e.created_at);
    if (!Number.isFinite(time)) continue;
    events.push({ time, model: e.model, input: e.input_tokens, cached, output: e.output_tokens });
  }
  return events;
}

export function antigravityLocalCost(
  agyDir: string,
  budget: number | null,
  regionalUplift = false,
  now = new Date(),
): { meters: Meter[]; message: string } {
  const month = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1);
  const today = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
  const nextMonth = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1)).toISOString();
  const brain = path.join(expand(agyDir), "brain");
  const unknown = new Set<string>();
  const multiplier = regionalUplift ? 1.1 : 1;
  let monthUsd = 0, todayUsd = 0;

  if (fs.existsSync(brain)) {
    for (const rel of new Bun.Glob("*/.system_generated/logs/transcript.jsonl").scanSync({ cwd: brain })) {
      const file = path.join(brain, rel);
      let events: AgyCostEvent[];
      try {
        const stat = fs.statSync(file);
        if (stat.mtimeMs < month) continue;
        const cached = agyTranscriptCache.get(file);
        events = cached?.size === stat.size && cached.mtime === stat.mtimeMs
          ? cached.events : antigravityTranscriptEvents(fs.readFileSync(file, "utf8"));
        agyTranscriptCache.set(file, { size: stat.size, mtime: stat.mtimeMs, events });
      } catch { continue; }
      for (const e of events) {
        if (e.time < month || e.time > now.getTime()) continue;
        const rates = agyModelRates(e.model, e.time);
        if (!rates) { unknown.add(e.model); continue; }
        // In agy transcripts, input_tokens is uncached input; cache_read_tokens is separate.
        const cost = ((e.input * rates[0] + e.cached * rates[1] + e.output * rates[2]) / 1e6) * multiplier;
        monthUsd += cost;
        if (e.time >= today) todayUsd += cost;
      }
    }
  }

  const skipped = unknown.size ? ` Unpriced models omitted: ${[...unknown].sort().join(", ")}.` : "";
  return {
    meters: [
      usdMeter("month", "This month", monthUsd, budget, nextMonth),
      usdMeter("today", "Today (UTC)", todayUsd, null),
    ],
    message: "Local estimate from transcripts; not billed spend." + skipped,
  };
}

export function antigravityQuotaMeters(groups: any[]): Meter[] {
  const meters: Meter[] = [];
  for (const g of groups) {
    const rawName = String(g?.name ?? "").trim();
    const shortName = /gemini/i.test(rawName)
      ? "Gemini"
      : /claude/i.test(rawName) && /gpt/i.test(rawName)
        ? "Claude/GPT"
        : rawName.replace(/\s+models?$/i, "") || "Quota";
    for (const b of Array.isArray(g?.buckets) ? g.buckets : []) {
      const pct =
        typeof b?.used_percent === "number"
          ? b.used_percent
          : typeof b?.remaining_fraction === "number"
            ? Math.round((1 - b.remaining_fraction) * 10000) / 100
            : null;
      if (pct === null || !Number.isFinite(pct)) continue;
      const winRaw = String(b.window ?? "").trim().toLowerCase();
      const win = winRaw === "5h" ? "(5h)" : winRaw || "";
      const label = win ? `${shortName} ${win}` : shortName;
      meters.push(pctMeter(slug(label), label, pct, b.reset_time ?? b.resets_at ?? null));
    }
  }
  return meters;
}

export async function antigravityCliUsage(command?: string, timeoutMs = 25_000): Promise<{ groups?: any[]; missing?: boolean; why?: string }> {
  const executable = command ?? findAgy();
  if (!executable) return { missing: true, why: "agy isn't installed" };
  let child: ReturnType<typeof Bun.spawn> | undefined;
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    fs.mkdirSync(CACHE_DIR, { recursive: true });
    child = Bun.spawn([executable, "-p", "/usage", "--output-format", "json"], {
      cwd: CACHE_DIR,
      stdin: "ignore",
      stdout: "pipe",
      stderr: "pipe",
    });
    const proc = child;
    const result = await Promise.race([
      Promise.all([new Response(proc.stdout as any).text(), new Response(proc.stderr as any).text(), proc.exited]).then(
        ([out, err, code]) => ({ out, err, code }),
      ),
      new Promise<{ timeout: true }>((resolve) => { timer = setTimeout(() => resolve({ timeout: true }), timeoutMs); }),
    ]);
    if ("timeout" in result) {
      proc.kill("SIGKILL");
      return { why: "agy timed out" };
    }
    let parsed: any = null;
    for (const line of result.out.trim().split("\n").reverse()) {
      try { parsed = JSON.parse(line); break; } catch {}
    }
    if (!parsed) return { why: `agy: ${(result.err || result.out || `exit ${result.code}`).trim().slice(0, 120)}` };
    if (parsed.status === "ERROR") return { why: `agy: ${String(parsed.error ?? "usage failed").slice(0, 120)}` };
    const groups = parsed?.command?.data?.groups;
    if (Array.isArray(groups)) return { groups };
    return { why: "agy returned no usage groups" };
  } catch (e: any) {
    return { why: `agy: ${e?.message ?? e}` };
  } finally {
    clearTimeout(timer);
  }
}

export async function fetchAntigravity(cfg: AccountConfig, fetcher: typeof fetch = fetch): Promise<Result> {
  const dir = cfg.agyDir ?? "~/.gemini/antigravity-cli";
  const settings = readJson<any>(path.join(expand(dir), "settings.json"));

  // Google-reported net charges from BigQuery billing export (no estimates or spending caps).
  if (cfg.gcpBilling) {
    return fetchGcpBilling(cfg.id, cfg.gcpBilling, settings?.gcp?.project, fetcher);
  }
  if (cfg.gcpBillingFile) {
    const file = expand(cfg.gcpBillingFile);
    const billing = readJson<GcpBillingConfig>(file);
    if (!billing) {
      return {
        status: "error",
        subtitle: "GCP Billing",
        meters: [],
        message: `Cannot read GCP billing config (${cfg.gcpBillingFile})`,
        retryInMs: 5 * MIN,
      };
    }
    return fetchGcpBilling(cfg.id, billing, settings?.gcp?.project, fetcher);
  }

  const { groups, missing, why } = await antigravityCliUsage();
  if (missing) return { status: "setup", message: "Install Antigravity CLI (agy) and sign in", retryInMs: 10 * MIN };
  if (!groups) return { status: "stale", message: why ?? "Antigravity usage unavailable", retryInMs: 5 * MIN };
  if (groups.length > 0) return { status: "ok", meters: antigravityQuotaMeters(groups) };

  return {
    status: "pending",
    subtitle: "GCP Billing",
    meters: [],
    message: "Waiting for Google billing data",
    retryInMs: 10 * MIN,
  };
}

const FETCH: Record<Provider, (cfg: AccountConfig) => Promise<Result>> = {
  claude: fetchClaude,
  "anthropic-api": fetchAnthropicApi,
  hermes: async (cfg) => fetchHermes(cfg),
  codex: fetchCodex,
  antigravity: fetchAntigravity,
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
  } else if (r.status === "setup" || r.status === "pending") {
    acc.status = r.status;
    acc.meters = [];
    acc.fetchedAt = undefined;
  } else if (r.meters !== undefined) {
    acc.status = r.status;
    acc.meters = r.meters;
    if (!r.meters.length) acc.fetchedAt = undefined;
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
    gcpTokenCache.clear();
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
const GLYPH: Record<string, string> = { claude: "✻", anthropic: "A", openai: "◎", gemini: "✦" };
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
    if (a.message) out.push(`  ${a.status === "ok" || a.status === "pending" ? dim(a.message) : hex("#E6C384")(a.message)}`);
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

if (import.meta.main) await main();
