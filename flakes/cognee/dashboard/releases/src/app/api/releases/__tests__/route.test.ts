/** @jest-environment node */
import { GET } from "../route";

const backend = "http://127.0.0.1:8000";
const upstream = "https://api.github.com/repos/topoteretes/cognee/releases";
jest.mock("@/modules/config/serverRuntimeConfig", () => ({ getServerBackendUrl: () => "http://127.0.0.1:8000" }));

const release = (tag: string, body: string) => ({ tag_name: tag, body, published_at: "2026-11-26T17:05:51Z", draft: false, prerelease: false });
const jsonResponse = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
const ready = (version: string) => ({ status: "ready", health: "healthy", version });

it("gets the installed version from the API and keeps its exact notes separate from a newer stable release", async () => {
  const replies = new Map<string, unknown>([
    [`${backend}/health`, ready("1.6.9")],
    [`${upstream}/tags/v1.6.9`, release("v1.6.9", "Installed notes")],
    [`${upstream}/latest`, release("v1.6.11", "Upgrade notes")],
  ]);
  const fetchMock = jest.spyOn(globalThis, "fetch").mockImplementation(async (url) => {
    const result = replies.get(String(url));
    return result ? jsonResponse(result) : new Response(null, { status: 404 });
  });
  try {
    const response = await GET();
    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect(await response.json()).toMatchObject({
      runningVersion: "1.6.9",
      releases: [{ version: "v1.6.9", markdown: "Installed notes" }],
      upstream: { status: "checked", update: { version: "v1.6.11", markdown: "Upgrade notes" } },
    });
    await GET();
    expect(fetchMock.mock.calls.filter(([url]) => String(url).startsWith(upstream))).toHaveLength(2);
    expect(fetchMock).toHaveBeenCalledWith(`${upstream}/latest`, expect.objectContaining({ redirect: "error", credentials: "omit" }));

    replies.set(`${backend}/health`, ready("1.6.11"));
    replies.set(`${upstream}/tags/v1.6.11`, release("v1.6.11", "Now installed"));
    expect(await (await GET()).json()).toMatchObject({
      runningVersion: "1.6.11", upstream: { status: "checked", update: null },
    });
    replies.set(`${backend}/health`, ready("1.7.0"));
    expect(await (await GET()).json()).toMatchObject({
      runningVersion: "1.7.0", releases: [], upstream: { status: "checked", update: null },
    });
    replies.set(`${backend}/health`, ready("1.7.0-rc.1"));
    expect(await (await GET()).json()).toMatchObject({
      runningVersion: "1.7.0-rc.1", upstream: { status: "unsupported", update: null },
    });
    replies.delete(`${backend}/health`);
    expect((await GET()).status).toBe(503);
  } finally {
    fetchMock.mockRestore();
  }
});

it("does not turn a failed GitHub check into an all-clear or hide the installed notes", async () => {
  jest.useFakeTimers().setSystemTime(Date.now() + 16 * 60_000);
  const fetchMock = jest.spyOn(globalThis, "fetch").mockImplementation(async (url) => {
    if (String(url) === `${backend}/health`) return jsonResponse(ready("1.6.10"));
    if (String(url) === `${upstream}/tags/v1.6.10`) return jsonResponse(release("v1.6.10", "Installed notes"));
    return new Response(null, { status: 503 });
  });
  try {
    expect(await (await GET()).json()).toMatchObject({
      releases: [{ version: "v1.6.10", markdown: "Installed notes" }],
      upstream: { status: "unavailable", update: null },
    });
  } finally {
    fetchMock.mockRestore();
    jest.useRealTimers();
  }
});

it.each([
  { code: 200, status: "ready", health: "degraded" },
  { code: 503, status: "not ready", health: "unhealthy" },
])("uses the running version from a $code $health health result", async ({ code, status, health }) => {
  const fetchMock = jest.spyOn(globalThis, "fetch").mockImplementation(async (url) => {
    if (String(url) === `${backend}/health`) return jsonResponse({ status, health, version: "1.6.8" }, code);
    return new Response(null, { status: 404 });
  });
  try {
    const response = await GET();
    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect(await response.json()).toMatchObject({ runningVersion: "1.6.8" });
  } finally {
    fetchMock.mockRestore();
  }
});

it.each([
  { label: "the health exception", code: 503, body: { status: "not ready", reason: "health check failed" } },
  { label: "a version-only failure", code: 503, body: { version: "1.6.8" } },
  { label: "an unexpected HTTP error", code: 502, body: { status: "not ready", health: "unhealthy", version: "1.6.8" } },
  { label: "an invalid 503 version", code: 503, body: { status: "not ready", health: "unhealthy", version: "unknown" } },
  { label: "an unrelated success body", code: 200, body: { version: "1.6.8" } },
])("does not trust the backend version in $label", async ({ code, body }) => {
  const fetchMock = jest.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse(body, code));
  try {
    const response = await GET();
    expect(response.status).toBe(503);
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect(await response.json()).toEqual({ error: "Running Cognee version unavailable" });
    expect(fetchMock).toHaveBeenCalledTimes(1);
  } finally {
    fetchMock.mockRestore();
  }
});

it.each([
  { runningVersion: "1.6.6rc1", tag: "v1.6.6rc1", prerelease: false },
  { runningVersion: "v1.6.5.dev0", tag: "v1.6.5.dev0", prerelease: false },
  { runningVersion: "1.7.0-rc.2", tag: "v1.7.0-rc.2", prerelease: true },
])("uses the exact $tag notes without comparing a nonstable installed version", async ({ runningVersion, tag, prerelease }) => {
  const exactUrl = `${upstream}/tags/${tag}`;
  const fetchMock = jest.spyOn(globalThis, "fetch").mockImplementation(async (url) => {
    if (String(url) === `${backend}/health`) return jsonResponse(ready(runningVersion));
    if (String(url) === exactUrl) return jsonResponse({ ...release(tag, "Exact notes"), prerelease });
    return jsonResponse(release("v1.7.1", "Stable notes"));
  });
  try {
    expect(await (await GET()).json()).toMatchObject({
      runningVersion, releases: [{ version: tag, markdown: "Exact notes" }],
      upstream: { status: "unsupported", update: null },
    });
    await GET();
    expect(fetchMock.mock.calls.map(([url]) => url)).toEqual([`${backend}/health`, exactUrl, `${backend}/health`]);
    expect(fetchMock).toHaveBeenCalledWith(exactUrl, expect.objectContaining({ cache: "no-store" }));
  } finally {
    fetchMock.mockRestore();
  }
});

it.each([
  { runningVersion: "1.6.5rc1", tag: "v1.6.5", draft: false },
  { runningVersion: "1.6.4rc1", tag: "v1.6.4rc1", draft: true },
  { runningVersion: "1.6.4rc2", tag: ["v1.6.4rc2"], draft: false },
])("rejects mismatched, malformed or draft exact-release results for $runningVersion", async ({ runningVersion, tag, draft }) => {
  const exactUrl = `${upstream}/tags/v${runningVersion}`;
  const fetchMock = jest.spyOn(globalThis, "fetch").mockImplementation(async (url) => {
    if (String(url) === `${backend}/health`) return jsonResponse(ready(runningVersion));
    return jsonResponse({ ...release("ignored", "Not installed notes"), tag_name: tag, draft });
  });
  try {
    expect(await (await GET()).json()).toMatchObject({
      runningVersion, releases: [], upstream: { status: "unsupported", update: null },
    });
    expect(fetchMock.mock.calls.map(([url]) => url)).toEqual([`${backend}/health`, exactUrl]);
  } finally {
    fetchMock.mockRestore();
  }
});

it("does not use an unsupported tag spelling in a GitHub request", async () => {
  const fetchMock = jest.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse(ready("1.6.6_rc1")));
  try {
    expect(await (await GET()).json()).toMatchObject({
      runningVersion: "1.6.6_rc1", releases: [], upstream: { status: "unsupported", update: null },
    });
    expect(fetchMock).toHaveBeenCalledTimes(1);
  } finally {
    fetchMock.mockRestore();
  }
});

it("does not treat a nonnumeric latest tag as stable even when GitHub does", async () => {
  jest.useFakeTimers().setSystemTime(Date.now() + 24 * 60 * 60_000);
  const fetchMock = jest.spyOn(globalThis, "fetch").mockImplementation(async (url) => {
    if (String(url) === `${backend}/health`) return jsonResponse(ready("1.6.4"));
    if (String(url) === `${upstream}/latest`) return jsonResponse(release("v1.6.6rc1", "Not stable"));
    return jsonResponse(release("v1.6.4", "Installed notes"));
  });
  try {
    expect(await (await GET()).json()).toMatchObject({
      releases: [{ version: "v1.6.4", markdown: "Installed notes" }],
      upstream: { status: "unavailable", update: null },
    });
  } finally {
    fetchMock.mockRestore();
    jest.useRealTimers();
  }
});
