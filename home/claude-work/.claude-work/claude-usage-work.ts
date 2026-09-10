#!/usr/bin/env bun
// claude-usage-work.ts — refresh the work account's credit-spend cache.
//
// Background refresher for ~/.claude-work/statusline-command.sh. The work
// profile's statusline JSON carries no `rate_limits` block (that only ships
// for consumer plans), so the spend numbers come from the OAuth usage
// endpoint that backs Claude Code's own /usage panel:
//
//     GET https://api.anthropic.com/api/oauth/usage
//
// This endpoint requires the `user:profile` scope, which means it needs a real
// OAuth login: `claudeAiOauth.accessToken` from
// `$CLAUDE_CONFIG_DIR/.credentials.json` (Linux) or the keychain item
// `Claude Code-credentials-<sha256(configDir)[:8]>` (macOS; the plain
// `Claude Code-credentials` name belongs to the default ~/.claude profile).
//
// The `claude-token-work` setup-token that the `claude` wrapper injects as
// $CLAUDE_CODE_OAUTH_TOKEN is deliberately NOT used: it lacks `user:profile`
// and this endpoint answers
//
//     403 oauth_scope_insufficient — required_scopes: ["user:profile"]
//
// for it. Worth knowing when debugging: a shared rate limiter sits in FRONT of
// that scope check, so an unscoped token returns 429 with a long `retry-after`
// for as long as the quota window is shut, and only reveals the 403 once the
// window opens. A 429 here proves nothing about whether the token would work.
//
// If the work profile's credential item is an empty stub (zero-length
// accessToken and refreshToken, expiresAt 0 — the state a cleared or expired
// login leaves behind), there is no usable credential and the spend segment
// stays dark until `claude /login` is run under CLAUDE_CONFIG_DIR=~/.claude-work.
//
// An earlier version of this script read the Claude *desktop* app's claude.ai
// `sessionKey` cookie instead. That was wrong: the desktop app holds whatever
// account you last signed it into — a personal one, in practice — so the
// statusline reported a personal Max credit cap ($33.24/$100) while Claude
// Code was billing the Perforce enterprise org ($214.35/$2,500). Reading the
// same credentials Claude Code authenticates with makes the account correct
// by construction.
//
// The endpoint is quota-limited per account (a 429 carries `retry-after`, and
// the window can run ~50 min), and herdr-usage-watcher.ts draws on the same
// bucket. So: refresh at most every FRESH_MS, honor `retry-after` exactly, and
// serve the last good reading throughout. Writes
// /tmp/claude-usage-work.json for the statusline and the herdr tab-bar watcher
// to read. Never blocks either: they render whatever the cache already holds.

import crypto from "node:crypto";
import fs from "node:fs";

const CACHE = "/tmp/claude-usage-work.json";
const LOCK = "/tmp/claude-usage-work.lock";
const LOCK_STALE_MS = 60_000;

// Refresh cadence. The bucket is shared with herdr-usage-watcher.ts, so stay
// well clear of it — spend moves in dollars over hours, not seconds.
const FRESH_MS = 15 * 60_000;
const FAIL_BACKOFF_MS = 10 * 60_000; // when a failure carries no retry-after

// `nextAt` is the epoch ms before which a refresh is pointless — success
// window or server-dictated backoff, whichever applies. The statusline just
// compares it against now, so all the retry policy lives here.
type Cache = {
  at?: number;
  failAt?: number;
  nextAt?: number;
  pct?: number;
  used?: string;
  limit?: string;
  err?: string;
};

function readCache(): Cache {
  try {
    return JSON.parse(fs.readFileSync(CACHE, "utf8")) ?? {};
  } catch {
    return {};
  }
}

function writeCache(c: Cache) {
  try {
    fs.writeFileSync(CACHE, JSON.stringify(c));
  } catch {}
}

function fail(prev: Cache, err: string, nextAt: number) {
  const now = Date.now();
  writeCache({ ...prev, failAt: now, nextAt, err });
}

// Single refresher at a time — concurrent Claude sessions all share this cache
// and would otherwise each spend a request from the shared quota. Exclusive
// create, with a staleness escape so a killed refresher can't wedge the lock.
function lock(): boolean {
  for (let i = 0; i < 2; i++) {
    try {
      fs.writeFileSync(LOCK, String(process.pid), { flag: "wx" });
      return true;
    } catch {
      try {
        if (Date.now() - fs.statSync(LOCK).mtimeMs < LOCK_STALE_MS) return false;
        fs.unlinkSync(LOCK);
      } catch {
        return false;
      }
    }
  }
  return false;
}

const configDir = process.env.CLAUDE_CONFIG_DIR || `${process.env.HOME}/.claude`;

// Keychain service name Claude Code uses for this config dir. The default
// profile gets the bare name; every other dir gets an 8-hex suffix.
function keychainService(): string {
  const base = "Claude Code-credentials";
  if (configDir === `${process.env.HOME}/.claude`) return base;
  const hash = crypto.createHash("sha256").update(configDir).digest("hex");
  return `${base}-${hash.slice(0, 8)}`;
}

function keychain(service: string): string {
  return Bun.spawnSync(["security", "find-generic-password", "-s", service, "-w"])
    .stdout.toString()
    .trim();
}

function accessToken(): string {
  let raw = "";
  try {
    raw = fs.readFileSync(`${configDir}/.credentials.json`, "utf8");
  } catch {
    raw = keychain(keychainService());
  }
  if (!raw) return "";
  try {
    // An empty string is what a cleared login leaves behind, not a token.
    return JSON.parse(raw).claudeAiOauth?.accessToken?.trim() ?? "";
  } catch {
    return "";
  }
}

type Money = { amount_minor: number; exponent: number };

function isMoney(v: any): v is Money {
  return v && typeof v.amount_minor === "number" && typeof v.exponent === "number";
}

// amount_minor is an integer in the currency's minor unit; `exponent` says how
// many decimal places that is (2 → cents). The used side wants cents (it
// changes by cents); the limit is a round budget, so drop them.
function money(m: Money, cents: boolean): string {
  const v = m.amount_minor / 10 ** m.exponent;
  return `$${cents ? v.toFixed(m.exponent) : Math.round(v)}`;
}

// The payload shape for an enterprise spend limit is unverified at time of
// writing (the quota window was exhausted), so look in every plausible place
// rather than hard-coding one path: a top-level `spend` object like claude.ai
// returns, or a spend-flavored entry among `limits`. Anything with a
// used/limit money pair counts.
function findSpend(data: any): { used: Money; limit: Money } | null {
  const candidates: any[] = [
    data?.spend,
    data?.credit_spend,
    data?.organization_spend,
    ...(Array.isArray(data?.limits) ? data.limits : []).filter((l: any) =>
      /spend|credit|cost|budget/i.test(`${l?.kind ?? ""} ${l?.type ?? ""}`),
    ),
  ];
  for (const c of candidates) {
    if (!c || c.enabled === false) continue;
    const used = c.used ?? c.spent ?? c.amount_used;
    const limit = c.limit ?? c.cap?.money ?? c.cap?.credits ?? c.amount_limit;
    if (isMoney(used) && isMoney(limit) && limit.amount_minor > 0) return { used, limit };
  }
  return null;
}

async function main() {
  if (!lock()) return;
  const prev = readCache();
  try {
    const token = accessToken();
    if (!token) return fail(prev, "no-token", Date.now() + FAIL_BACKOFF_MS);

    let res: Response;
    try {
      res = await fetch("https://api.anthropic.com/api/oauth/usage", {
        headers: { Authorization: `Bearer ${token}`, "anthropic-beta": "oauth-2025-04-20" },
      });
    } catch (e: any) {
      return fail(prev, `threw: ${e?.message ?? e}`, Date.now() + FAIL_BACKOFF_MS);
    }

    if (!res.ok) {
      // Honor the server's own backoff when it gives one — this endpoint's
      // 429 window is long, and hammering it just keeps it shut.
      const ra = Number(res.headers.get("retry-after"));
      const wait = Number.isFinite(ra) && ra > 0 ? ra * 1000 : FAIL_BACKOFF_MS;
      return fail(prev, `http-${res.status}`, Date.now() + wait);
    }

    const data = await res.json();
    const spend = findSpend(data);
    if (!spend) {
      // Keep the shape we did get, so the next look at this cache says which
      // keys to teach findSpend about.
      return fail(prev, `no-spend: ${Object.keys(data ?? {}).join(",")}`, Date.now() + FRESH_MS);
    }

    const now = Date.now();
    writeCache({
      at: now,
      nextAt: now + FRESH_MS,
      pct: Math.round((spend.used.amount_minor / spend.limit.amount_minor) * 100),
      used: money(spend.used, true),
      limit: money(spend.limit, false),
    });
  } finally {
    try {
      if (Number(fs.readFileSync(LOCK, "utf8")) === process.pid) fs.unlinkSync(LOCK);
    } catch {}
  }
}

await main();
