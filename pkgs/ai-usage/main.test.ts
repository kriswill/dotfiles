import { afterAll, describe, expect, test } from "bun:test";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {
  antigravityCliUsage,
  antigravityLocalCost,
  antigravityQuotaMeters,
  antigravityTranscriptEvents,
  buildGcpBillingSql,
  claudeCliUsage,
  claudeMeters,
  claudePlan,
  codexCostEvents,
  codexLocalCost,
  codexPlanLabel,
  codexLimitMeters,
  fetchAntigravity,
  fetchGcpBilling,
  isMissingExpectedBillingTable,
  parseGcpBillingRow,
  renewCodexLogin,
  signGcpServiceAccountJwt,
} from "./main";

test("Codex renders daily, weekly, model and code-review windows as bars when supplied", () => {
  const daily = { used_percent: 25, limit_window_seconds: 86400, reset_at: 1793650000 };
  const weekly = { ...daily, limit_window_seconds: 604800, used_percent: 10 };
  const meters = codexLimitMeters({
    rate_limit: { primary_window: daily, secondary_window: weekly },
    code_review_rate_limit: { primary_window: weekly },
    additional_rate_limits: [{ limit_name: "special_model", rate_limit: { primary_window: daily } }],
  });
  expect(meters.map((m) => m.label)).toEqual(["Daily", "Weekly", "Code review weekly", "Special Model daily"]);
  expect(meters.map((m) => m.percent)).toEqual([25, 10, 10, 25]);
  expect(codexLimitMeters({ rate_limit: { primary_window: weekly }, additional_rate_limits: null }).map((m) => m.label)).toEqual(["Weekly"]);
});

test("Codex displays the upgraded $100 tier as Pro", () => {
  expect(codexPlanLabel("prolite")).toBe("Pro");
  expect(codexPlanLabel("plus")).toBe("Plus");
  expect(codexPlanLabel("pro")).toBe("Pro");
});

test("Claude tiers show only the multiplier", () => {
  expect(claudePlan({ rateLimitTier: "default_claude_max_20x" })).toBe("20x");
  expect(claudePlan({ rateLimitTier: "default_claude_max_5x" })).toBe("5x");
  expect(claudePlan({ subscriptionType: "pro" })).toBe("Pro");
});

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "ai-usage-test-"));
afterAll(() => fs.rmSync(tmp, { recursive: true, force: true }));
const context = (model: string) => JSON.stringify({ type: "turn_context", payload: { model } });
const usage = (timestamp: string, input: number, cached: number, output: number) => JSON.stringify({
  timestamp, type: "event_msg", payload: { type: "token_count", info: {
    total_token_usage: { input_tokens: input, cached_input_tokens: cached, output_tokens: output, reasoning_output_tokens: Math.floor(output / 2) },
    last_token_usage: { input_tokens: input, cached_input_tokens: cached, output_tokens: output },
  } },
});

describe("Codex local cost", () => {
  test("counts cumulative deltas once and follows model changes", () => {
    const events = codexCostEvents([
      context("gpt-6-astra"), usage("2026-11-01T12:00:00Z", 100, 40, 10),
      usage("2026-11-01T12:00:01Z", 100, 40, 10),
      context("gpt-6.1-sol"), usage("2026-11-01T12:01:00Z", 150, 60, 20),
      '{"incomplete":',
    ].join("\n"));
    expect(events).toHaveLength(2);
    expect(events[1]).toMatchObject({ model: "gpt-6.1-sol", input: 50, cached: 20, output: 10 });
  });

  test("deduplicates fork/archived history and discounts cached input without double counting reasoning", () => {
    const home = path.join(tmp, "sessions-test");
    fs.mkdirSync(path.join(home, "sessions"), { recursive: true });
    fs.mkdirSync(path.join(home, "archived_sessions"));
    const text = [context("gpt-6-astra"), usage("2026-11-01T12:00:00Z", 1e6, 400000, 100000)].join("\n");
    fs.writeFileSync(path.join(home, "sessions/a.jsonl"), text);
    fs.writeFileSync(path.join(home, "archived_sessions/a.jsonl"), text);
    const result = codexLocalCost(home, new Date("2026-11-01T23:00:00Z"));
    expect(result.meters.map((m) => m.usedUsd)).toEqual([11.4, 11.4]);
    expect(result.message).toContain("not billed spend");
    // A changed file must invalidate the cache; unknown rates aren't $0 usage.
    fs.appendFileSync(path.join(home, "sessions/a.jsonl"), "\n" + context("unknown-model") + "\n" + usage("2026-11-01T12:02:00Z", 2e6, 400000, 200000));
    expect(codexLocalCost(home, new Date("2026-11-01T23:00:00Z")).message).toContain("Unpriced models omitted: unknown-model");
  });

  test("uses event dates rather than file dates for month boundaries", () => {
    const home = path.join(tmp, "month-test");
    fs.mkdirSync(path.join(home, "sessions"), { recursive: true });
    fs.writeFileSync(path.join(home, "sessions/old.jsonl"), [
      context("gpt-6.1-sol"), usage("2026-10-30T12:00:00Z", 1e6, 0, 0),
      usage("2026-11-01T12:00:00Z", 2e6, 0, 0),
    ].join("\n"));
    expect(codexLocalCost(home, new Date("2026-11-01T23:00:00Z")).meters[0].usedUsd).toBe(2);
  });
});

describe("Codex-managed login renewal", () => {
  function client(name: string, response: string): string {
    const file = path.join(tmp, name);
    fs.writeFileSync(file, `#!${process.execPath}\nimport { createInterface } from 'node:readline';
for await (const line of createInterface({ input: process.stdin })) {
 const msg = JSON.parse(line);
 if (msg.method === 'initialize') console.log(JSON.stringify({ id: msg.id, result: {} }));
 if (msg.method === 'account/read') {
   if (msg.params.refreshToken !== true) process.exit(1);
   ${response}
 }
}\n`, { mode: 0o700 });
    return file;
  }
  test("handshakes and delegates renewal to the official protocol", async () => {
    const bin = client("ok.ts", "console.log(JSON.stringify({id:msg.id,result:{account:{type:'chatgpt'}}}));");
    expect(await renewCodexLogin(tmp, bin)).toBe(true);
  });
  test("handles login errors without leaking the server message", async () => {
    const bin = client("error.ts", "console.log(JSON.stringify({id:msg.id,error:{message:'secret server detail'}}));");
    expect(await renewCodexLogin(tmp, bin)).toBe(false);
  });
  test("bounds a stalled client and handles a missing executable", async () => {
    const bin = client("hang.ts", "await new Promise(() => {});");
    expect(await renewCodexLogin(tmp, bin, 100)).toBe(false);
    expect(await renewCodexLogin(tmp, path.join(tmp, "missing"))).toBe(false);
  });
});

test("Claude reads the usage body the same whether direct or via get_usage", () => {
  const meters = claudeMeters({
    five_hour: null,
    seven_day: { utilization: 46, resets_at: "2026-11-06T22:59:59Z" },
    limits: [
      { kind: "weekly_all", percent: 46, severity: "normal", resets_at: "2026-11-06T22:59:59Z" },
      { kind: "weekly_scoped", percent: 27, severity: "normal", scope: { model: { display_name: "Fable" } } },
    ],
    iguana_necktie: { limit_dollars: 250, used_dollars: 37.45, resets_at: "2026-11-05T07:59:00Z" },
    spend: { enabled: true, used: { amount_minor: 0, exponent: 2 }, limit: { amount_minor: 20000, exponent: 2 } },
  });
  expect(meters.map((m) => m.label)).toEqual(["Weekly", "Fable weekly", "Cloud credits", "Extra usage"]);
  expect(meters.map((m) => m.value)).toEqual(["46%", "27%", "$37.45 / $250", "$0.00 / $200"]);
  // An enterprise seat: no plan limits, so its spend is the whole picture.
  expect(claudeMeters({ limits: [], spend: { enabled: true, used: { amount_minor: 500 }, limit: { amount_minor: 1000 } } })
    .map((m) => m.label)).toEqual(["Credit spend"]);
});

describe("Claude-managed login renewal (get_usage over the SDK control channel)", () => {
  // Stands in for `claude -p … --input-format stream-json`: answers the
  // get_usage control request, echoing what it was launched with.
  function client(name: string, answer: string): string {
    const file = path.join(tmp, name);
    fs.writeFileSync(file, `#!${process.execPath}\nimport { createInterface } from 'node:readline';
for await (const line of createInterface({ input: process.stdin })) {
 const msg = JSON.parse(line);
 const req = msg.request;
 if (msg.type !== 'control_request' || req.subtype !== 'get_usage' || req.skip_behaviors !== true) process.exit(1);
 const reply = (response) => console.log(JSON.stringify({ type: 'control_response', response: { request_id: msg.request_id, ...response } }));
 console.log(JSON.stringify({ type: 'system', subtype: 'ui_invalidate' }));
 ${answer}
}\n`, { mode: 0o700 });
    return file;
  }
  test("asks a prompt-less safe-mode session for usage under the account's config dir", async () => {
    const bin = client("claude-ok.ts", "reply({ subtype: 'success', response: { rate_limits_available: true, rate_limits: { dir: process.env.CLAUDE_CONFIG_DIR, args: process.argv.slice(2), noUpdate: process.env.DISABLE_AUTOUPDATER } } });");
    const { limits, why } = await claudeCliUsage(path.join(tmp, "profile"), bin);
    expect(why).toBeUndefined();
    expect(limits.dir).toBe(path.join(tmp, "profile"));
    expect(limits.noUpdate).toBe("1");
    expect(limits.args).toEqual(expect.arrayContaining(["-p", "--safe-mode", "--no-session-persistence", "--strict-mcp-config"]));
    expect(limits.args).not.toContain("--bare"); // bare mode never reads the OAuth login
  });
  test("leaves CLAUDE_CONFIG_DIR unset for the default ~/.claude", async () => {
    const bin = client("claude-env.ts", "reply({ subtype: 'success', response: { rate_limits: { dir: process.env.CLAUDE_CONFIG_DIR ?? null } } });");
    expect((await claudeCliUsage("~/.claude", bin)).limits.dir).toBeNull();
  });
  test("reports a missing reading, a refused request, a stall and a missing executable", async () => {
    const none = client("claude-none.ts", "reply({ subtype: 'success', response: { rate_limits_available: true, rate_limits: null } });");
    expect(await claudeCliUsage(tmp, none)).toEqual({ why: "claude got no usage reading" });
    const out = client("claude-out.ts", "reply({ subtype: 'success', response: { rate_limits_available: false, rate_limits: null } });");
    expect((await claudeCliUsage(tmp, out)).why).toBe("claude isn't signed in to a Claude plan");
    const refused = client("claude-error.ts", "reply({ subtype: 'error', error: 'get_usage is not supported in this context' });");
    expect((await claudeCliUsage(tmp, refused)).why).toBe("claude: get_usage is not supported in this context");
    const hang = client("claude-hang.ts", "await new Promise(() => {});");
    expect(await claudeCliUsage(tmp, hang, 200)).toEqual({ why: "claude timed out" });
    expect((await claudeCliUsage(tmp, path.join(tmp, "missing"))).why).toMatch(/^claude: /);
  });
});

describe("Antigravity quotas and Pay-As-You-Go local cost", () => {
  test("parses consumer quota groups and buckets into percentage meters", () => {
    const meters = antigravityQuotaMeters([
      {
        name: "Gemini Models",
        buckets: [
          { window: "5h", remaining_fraction: 0.75, reset_time: "2026-11-24T23:00:00Z" },
          { window: "weekly", remaining_fraction: 0.9, reset_time: "2026-11-30T00:00:00Z" },
        ],
      },
      {
        name: "Claude and GPT models",
        buckets: [{ window: "5h", used_percent: 40, reset_time: "2026-11-24T23:00:00Z" }],
      },
    ]);
    expect(meters.map((m) => m.label)).toEqual(["Gemini (5h)", "Gemini weekly", "Claude/GPT (5h)"]);
    expect(meters.map((m) => m.percent)).toEqual([25, 10, 40]);
  });

  test("prices transcript turns across UTC boundaries with regional uplift and unpriced-model notices", () => {
    const agyDir = path.join(tmp, "agy-test");
    const logDir = path.join(agyDir, "brain/conv-1/.system_generated/logs");
    fs.mkdirSync(logDir, { recursive: true });
    const transcript = [
      JSON.stringify({ created_at: "2026-10-31T23:00:00Z", model: "gemini-4-neon-medium", input_tokens: 1e6, cache_read_tokens: 0, output_tokens: 0 }),
      JSON.stringify({ created_at: "2026-11-23T12:00:00Z", model: "gemini-4-neon-medium", input_tokens: 1e6, cache_read_tokens: 2e6, output_tokens: 100000 }),
      JSON.stringify({ created_at: "2026-11-24T12:00:00Z", model: "gemini-4-hydrogen-high", input_tokens: 1e6, cache_read_tokens: 0, output_tokens: 0 }),
      '{"incomplete":',
    ].join("\n");
    expect(antigravityTranscriptEvents(transcript)).toHaveLength(3);
    fs.writeFileSync(path.join(logDir, "transcript.jsonl"), transcript);

    const now = new Date("2026-11-24T22:00:00Z");
    // Nov 23 neon: 3 + 0.30 + 1.50 = 4.80; Nov 24 hydrogen: 1.50 -> month = 6.30, today = 1.50
    const globalRes = antigravityLocalCost(agyDir, 50, false, now);
    expect(globalRes.meters[0].usedUsd).toBeCloseTo(6.3, 6);
    expect(globalRes.meters[0].percent).toBeCloseTo(12.6, 6);
    expect(globalRes.meters[1].usedUsd).toBeCloseTo(1.5, 6);

    // Regional uplift (1.1x)
    const usRes = antigravityLocalCost(agyDir, 50, true, now);
    expect(usRes.meters[0].usedUsd).toBeCloseTo(6.93, 6);
    expect(usRes.meters[1].usedUsd).toBeCloseTo(1.65, 6);

    // Appending an unknown model invalidates the file cache and surfaces the notice
    fs.appendFileSync(
      path.join(logDir, "transcript.jsonl"),
      "\n" + JSON.stringify({ created_at: "2026-11-24T13:00:00Z", model: "unknown-model-x", input_tokens: 1e5, cache_read_tokens: 0, output_tokens: 1e4 }),
    );
    expect(antigravityLocalCost(agyDir, 50, false, now).message).toContain("Unpriced models omitted: unknown-model-x");
  });

  test("invokes agy -p /usage --output-format json and handles empty groups, errors, and timeouts", async () => {
    const mkAgy = (name: string, body: string) => {
      const file = path.join(tmp, name);
      fs.writeFileSync(file, `#!${process.execPath}\n${body}\n`, { mode: 0o700 });
      return file;
    };
    const ok = mkAgy(
      "agy-ok.ts",
      `if (process.argv.slice(2).join(" ") !== "-p /usage --output-format json") process.exit(1);
console.log(JSON.stringify({ status: "SUCCESS", command: { name: "usage", data: { groups: [{ name: "Gemini Models", buckets: [] }] } } }));`,
    );
    expect((await antigravityCliUsage(ok)).groups).toHaveLength(1);

    const payg = mkAgy(
      "agy-payg.ts",
      `console.log(JSON.stringify({ status: "SUCCESS", command: { name: "usage", data: { groups: [] } } }));`,
    );
    expect(await antigravityCliUsage(payg)).toEqual({ groups: [] });

    const err = mkAgy(
      "agy-err.ts",
      `console.log(JSON.stringify({ status: "ERROR", error: "not signed in" }));`,
    );
    expect((await antigravityCliUsage(err)).why).toBe("agy: not signed in");

    const hang = mkAgy("agy-hang.ts", "await new Promise(() => {});");
    expect(await antigravityCliUsage(hang, 150)).toEqual({ why: "agy timed out" });
  });
});

describe("Antigravity exact GCP BigQuery billing", () => {
  const { publicKey, privateKey } = crypto.generateKeyPairSync("rsa", {
    modulusLength: 2048,
    publicKeyEncoding: { type: "spki", format: "pem" },
    privateKeyEncoding: { type: "pkcs8", format: "pem" },
  });

  test("signs a verifiable RS256 service account JWT", () => {
    const jwt = signGcpServiceAccountJwt(
      { client_email: "ai-usage@example.iam.gserviceaccount.com", private_key: privateKey },
      ["https://www.googleapis.com/auth/bigquery.readonly"],
      1795550000,
    );
    const [h, c, s] = jwt.split(".");
    const verify = crypto.createVerify("RSA-SHA256").update(`${h}.${c}`);
    expect(verify.verify(publicKey, s, "base64url")).toBe(true);
    expect(JSON.parse(Buffer.from(c, "base64url").toString("utf8"))).toMatchObject({
      iss: "ai-usage@example.iam.gserviceaccount.com",
      scope: "https://www.googleapis.com/auth/bigquery.readonly",
      iat: 1795550000,
      exp: 1795553600,
    });
  });

  test("validates BigQuery table names, parses rows, and distinguishes missing table from missing dataset", () => {
    expect(() => buildGcpBillingSql("bad; DROP TABLE x")).toThrow();
    expect(buildGcpBillingSql("my-proj.billing.gcp_billing_export_v1_012345")).toContain("invoice.month");

    expect(parseGcpBillingRow({
      rows: [{ f: [{ v: "14.825" }, { v: "2.10" }, { v: "15.00" }, { v: "1795550000.5" }, { v: "42" }] }],
    })).toEqual({
      netMtd: 14.825,
      netToday: 2.1,
      grossMtd: 15,
      lastExport: new Date(1795550000.5 * 1000).toISOString(),
      rowCount: 42,
    });

    const tbl = "singular-array-330521.billing_export.gcp_billing_export_v1_012A18_B207AE_A0176E";
    expect(isMissingExpectedBillingTable(404, "Not found: Table singular-array-330521:billing_export.gcp_billing_export_v1_012A18_B207AE_A0176E was not found in location US", tbl)).toBe(true);
    expect(isMissingExpectedBillingTable(404, "Not found: Dataset singular-array-330521:billing_export was not found in location US", tbl)).toBe(false);
    expect(isMissingExpectedBillingTable(403, "Access Denied: Table singular-array-330521:billing_export.gcp_billing_export_v1_012A18_B207AE_A0176E", tbl)).toBe(false);
  });

  test("exchanges JWT and queries BigQuery for Google-reported net charges without caps or Budgets API", async () => {
    const keyFile = path.join(tmp, "gcp-sa.json");
    fs.writeFileSync(keyFile, JSON.stringify({
      type: "service_account",
      client_email: "ai-usage@my-proj.iam.gserviceaccount.com",
      private_key: privateKey,
      token_uri: "https://oauth2.googleapis.com/token",
    }));

    const seen: string[] = [];
    const fakeFetch = (async (url: string | URL, init?: RequestInit) => {
      const u = String(url);
      seen.push(u);
      if (u.includes("oauth2.googleapis.com/token")) {
        return new Response(JSON.stringify({ access_token: "ya29.test", expires_in: 3600 }), { status: 200 });
      }
      if (u.includes("bigquery.googleapis.com")) {
        const body = JSON.parse(String(init?.body));
        expect(body.queryParameters).toEqual([
          { name: "projectId", parameterType: { type: "STRING" }, parameterValue: { value: "my-proj" } },
          { name: "serviceId", parameterType: { type: "STRING" }, parameterValue: { value: "C7E2-9256-1C43" } },
        ]);
        return new Response(JSON.stringify({
          jobComplete: true,
          rows: [{ f: [{ v: "12.34" }, { v: "1.50" }, { v: "12.34" }, { v: "1795550000" }, { v: "18" }] }],
        }), { status: 200 });
      }
      return new Response("unexpected call", { status: 500 });
    }) as typeof fetch;

    const res = await fetchGcpBilling(
      "antigravity-bq-test",
      {
        table: "my-proj.billing_export.gcp_billing_export_v1_012345",
        credentials: { file: keyFile },
      },
      "my-proj",
      fakeFetch,
    );
    expect(res.status).toBe("ok");
    expect(res.subtitle).toBe("GCP Billing");
    expect(res.meters?.map((m) => [m.label, m.value, m.percent])).toEqual([
      ["This month", "$12.34", null],
      ["Today (UTC)", "$1.50", null],
    ]);
    expect(seen).toHaveLength(2);
    expect(seen.some((u) => u.includes("billingbudgets"))).toBe(false);
  });

  test("shows Waiting for Google billing data when the expected export table is 404 or empty", async () => {
    const keyFile = path.join(tmp, "gcp-sa-wait.json");
    fs.writeFileSync(keyFile, JSON.stringify({
      type: "service_account",
      client_email: "ai-usage@my-proj.iam.gserviceaccount.com",
      private_key: privateKey,
    }));

    const table = "my-proj.billing_export.gcp_billing_export_v1_012345";
    const missingTableFetch = (async (url: string | URL) => {
      if (String(url).includes("oauth2.googleapis.com/token")) {
        return new Response(JSON.stringify({ access_token: "ya29.wait1", expires_in: 3600 }), { status: 200 });
      }
      return new Response(JSON.stringify({
        error: { message: "Not found: Table my-proj:billing_export.gcp_billing_export_v1_012345 was not found in location US" },
      }), { status: 404 });
    }) as typeof fetch;

    const r404 = await fetchGcpBilling("antigravity-bq-404", { table, credentials: { file: keyFile } }, "my-proj", missingTableFetch);
    expect(r404).toMatchObject({ status: "pending", subtitle: "GCP Billing", meters: [], message: "Waiting for Google billing data" });

    const emptyFetch = (async (url: string | URL) => {
      if (String(url).includes("oauth2.googleapis.com/token")) {
        return new Response(JSON.stringify({ access_token: "ya29.wait2", expires_in: 3600 }), { status: 200 });
      }
      return new Response(JSON.stringify({
        jobComplete: true,
        rows: [{ f: [{ v: "0" }, { v: "0" }, { v: "0" }, { v: null }, { v: "0" }] }],
      }), { status: 200 });
    }) as typeof fetch;

    const rEmpty = await fetchGcpBilling("antigravity-bq-empty", { table, credentials: { file: keyFile } }, "my-proj", emptyFetch);
    expect(rEmpty).toMatchObject({ status: "pending", subtitle: "GCP Billing", meters: [], message: "Waiting for Google billing data" });
  });

  test("keeps real permission and configuration errors visible without falling back to estimates", async () => {
    const keyFile = path.join(tmp, "gcp-sa-err.json");
    fs.writeFileSync(keyFile, JSON.stringify({
      type: "service_account",
      client_email: "ai-usage@my-proj.iam.gserviceaccount.com",
      private_key: privateKey,
    }));
    const table = "my-proj.billing_export.gcp_billing_export_v1_012345";

    const missingDatasetFetch = (async (url: string | URL) => {
      if (String(url).includes("oauth2.googleapis.com/token")) {
        return new Response(JSON.stringify({ access_token: "ya29.err1", expires_in: 3600 }), { status: 200 });
      }
      return new Response(JSON.stringify({
        error: { message: "Not found: Dataset my-proj:billing_export was not found in location US" },
      }), { status: 404 });
    }) as typeof fetch;
    const rDataset = await fetchGcpBilling("antigravity-bq-ds", { table, credentials: { file: keyFile } }, "my-proj", missingDatasetFetch);
    expect(rDataset.status).toBe("error");
    expect(rDataset.meters).toEqual([]);
    expect(rDataset.message).toContain("Not found: Dataset");

    const forbiddenFetch = (async (url: string | URL) => {
      if (String(url).includes("oauth2.googleapis.com/token")) {
        return new Response(JSON.stringify({ access_token: "ya29.err2", expires_in: 3600 }), { status: 200 });
      }
      return new Response(JSON.stringify({
        error: { message: "Access Denied: BigQuery BigQuery: User does not have permission" },
      }), { status: 403 });
    }) as typeof fetch;
    const r403 = await fetchGcpBilling("antigravity-bq-403", { table, credentials: { file: keyFile } }, "my-proj", forbiddenFetch);
    expect(r403.status).toBe("error");
    expect(r403.meters).toEqual([]);
    expect(r403.message).toContain("403");

    const rMissingFile = await fetchAntigravity({
      id: "antigravity",
      provider: "antigravity",
      gcpBillingFile: path.join(tmp, "does-not-exist.json"),
    });
    expect(rMissingFile.status).toBe("error");
    expect(rMissingFile.meters).toEqual([]);
    expect(rMissingFile.message).toContain("Cannot read GCP billing config");
  });
});
