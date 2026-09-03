#!/usr/bin/env bun
// claude-usage-work.ts — refresh the work account's credit-spend cache.
//
// Background refresher for ~/.claude-work/statusline-command.sh. The work
// profile's statusline JSON carries no `rate_limits` block (that only ships
// for consumer plans), and the profile's Claude Code token — the
// `claude-token-work` Keychain item that claude-account-selector injects as
// CLAUDE_CODE_OAUTH_TOKEN — is a `setup-token` without the `user:profile`
// scope, so api.anthropic.com/api/oauth/usage answers 403 for it.
//
// The Claude *desktop* app, however, holds a full claude.ai web session for
// the same (work) account, and claude.ai/api/organizations/<org>/usage returns
// the org's credit spend. So: pull the app's `sessionKey` cookie out of its
// Chromium cookie store — AES-128-CBC under a PBKDF2 stretch of the "Claude
// Safe Storage" Keychain password, the standard Electron safeStorage scheme —
// and call that endpoint with it.
//
// Writes /tmp/claude-usage-work.json for the statusline to read. Never blocks
// it: the statusline spawns this detached when the cache goes stale and always
// renders whatever the cache already holds.

import { Database } from "bun:sqlite";
import crypto from "node:crypto";
import fs from "node:fs";

const CACHE = "/tmp/claude-usage-work.json";
const LOCK = "/tmp/claude-usage-work.lock";
const LOCK_STALE_MS = 60_000;
const COOKIES = `${process.env.HOME}/Library/Application Support/Claude/Cookies`;
const UA =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " +
  "(KHTML, like Gecko) Claude/1.0 Chrome/132.0.0.0 Electron/34.0.0 Safari/537.36";

type Cache = { at?: number; failAt?: number; org?: string; pct?: number; used?: string; limit?: string };

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

// Single refresher at a time — concurrent Claude sessions all share this cache
// and would otherwise each open their own request. Exclusive create, with a
// staleness escape so a killed refresher can't wedge the lock permanently.
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

// Chromium safeStorage: key = PBKDF2-HMAC-SHA1(keychain password, "saltysalt",
// 1003, 16), AES-128-CBC with an all-spaces IV. Recent Chromium prefixes the
// plaintext with a 32-byte SHA-256 of the cookie's domain; detect that by the
// first byte not being printable ASCII and skip it.
function cookieReader() {
  const pw = Bun.spawnSync([
    "security", "find-generic-password", "-s", "Claude Safe Storage", "-a", "Claude Key", "-w",
  ]).stdout.toString().trim();
  if (!pw) return null;
  const key = crypto.pbkdf2Sync(pw, "saltysalt", 1003, 16, "sha1");
  const iv = Buffer.alloc(16, 0x20);
  return (buf: Buffer): string => {
    const tag = buf.subarray(0, 3).toString();
    if (tag !== "v10" && tag !== "v11") return buf.toString("utf8");
    const d = crypto.createDecipheriv("aes-128-cbc", key, iv);
    d.setAutoPadding(false);
    let out = Buffer.concat([d.update(buf.subarray(3)), d.final()]);
    const pad = out[out.length - 1];
    if (pad > 0 && pad <= 16) out = out.subarray(0, out.length - pad);
    return /^[\x20-\x7e]/.test(out.toString("utf8")) ? out.toString("utf8") : out.subarray(32).toString("utf8");
  };
}

// Copy first: the app keeps the store open, and a readonly attach to a live
// SQLite file can still fail on its journal.
function readCookies(): { sessionKey: string; org: string } | null {
  const dec = cookieReader();
  if (!dec || !fs.existsSync(COOKIES)) return null;
  const tmp = `/tmp/claude-usage-work-cookies.${process.pid}`;
  try {
    fs.copyFileSync(COOKIES, tmp);
    const db = new Database(tmp, { readonly: true });
    const rows = db
      .query("select name, encrypted_value from cookies where host_key like '%claude.ai' and name in ('sessionKey','lastActiveOrg')")
      .all() as { name: string; encrypted_value: Uint8Array }[];
    db.close();
    const get = (n: string) => {
      const r = rows.find((x) => x.name === n);
      return r ? dec(Buffer.from(r.encrypted_value)) : "";
    };
    const sessionKey = get("sessionKey");
    return sessionKey ? { sessionKey, org: get("lastActiveOrg") } : null;
  } catch {
    return null;
  } finally {
    try {
      fs.unlinkSync(tmp);
    } catch {}
  }
}

async function api(path: string, sessionKey: string): Promise<any | null> {
  try {
    const res = await fetch(`https://claude.ai${path}`, {
      headers: {
        Cookie: `sessionKey=${sessionKey}`,
        "User-Agent": UA,
        Accept: "application/json",
        "anthropic-client-platform": "web_claude_ai",
      },
    });
    return res.ok ? await res.json() : null;
  } catch {
    return null;
  }
}

// amount_minor is an integer in the currency's minor unit; `exponent` says how
// many decimal places that is (2 → cents).
function money(m: { amount_minor: number; exponent: number }, cents: boolean): string {
  const v = m.amount_minor / 10 ** m.exponent;
  return `$${cents ? v.toFixed(m.exponent) : Math.round(v)}`;
}

async function main() {
  if (!lock()) return;
  const prev = readCache();
  try {
    const ck = readCookies();
    if (!ck) return writeCache({ ...prev, failAt: Date.now() });

    let org = ck.org || prev.org || "";
    let usage = org ? await api(`/api/organizations/${org}/usage`, ck.sessionKey) : null;
    if (!usage) {
      // Stale or absent lastActiveOrg — resolve the org the session can chat in.
      const orgs = await api("/api/organizations", ck.sessionKey);
      org = (Array.isArray(orgs) ? orgs.find((o: any) => o.capabilities?.includes("chat")) : null)?.uuid ?? "";
      usage = org ? await api(`/api/organizations/${org}/usage`, ck.sessionKey) : null;
    }

    const spend = usage?.spend;
    if (!spend?.enabled || !spend.used || !spend.limit || spend.limit.amount_minor <= 0) {
      return writeCache({ ...prev, org: org || prev.org, failAt: Date.now() });
    }

    writeCache({
      at: Date.now(),
      org,
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
