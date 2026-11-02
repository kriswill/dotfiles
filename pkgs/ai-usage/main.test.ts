import { afterAll, describe, expect, test } from "bun:test";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { codexCostEvents, codexLocalCost, codexPlanLabel, codexLimitMeters, renewCodexLogin } from "./main";

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
