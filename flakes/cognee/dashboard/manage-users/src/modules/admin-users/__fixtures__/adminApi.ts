import type { UserDetail, UserSummary } from "../api";

export const API = "https://fixture.example.test";

export function summary(overrides: Partial<UserSummary> = {}): UserSummary {
  return {
    id: "u-reader", email: "reader@example.test", isSuperuser: false, isActive: true, isVerified: true,
    hasPassword: true, isSelf: false, isDefault: false, isAgent: false, createdAt: "2026-11-02T10:00:00Z",
    apiKeyCount: 1, datasetsOwned: 1, ...overrides,
  };
}

export function detail(overrides: Partial<UserDetail> = {}): UserDetail {
  return {
    ...summary(),
    parentEmail: null,
    locks: { demote: null, deactivate: null, delete: null },
    apiKeys: [{ id: "k-1", name: "Hermes", label: "abcd1234****", createdAt: "2026-11-03T10:00:00Z", lastUsedAt: null }],
    maxApiKeys: 10,
    ownedDatasets: [{ id: "d-own", name: "notes", createdAt: null }],
    datasetAccess: [
      { datasetId: "d-shared", name: "handbook", ownerEmail: "operator@example.test", permissions: ["read"], source: "direct", sourceName: null, effective: true },
    ],
    grantableDatasets: [
      { id: "d-shared", name: "handbook", ownerEmail: "operator@example.test" },
      { id: "d-other", name: "runbooks", ownerEmail: "operator@example.test" },
    ],
    tenants: [],
    availableTenants: [],
    ...overrides,
  };
}

export interface Call {
  method: string;
  path: string;
  body: unknown;
  headers: Headers;
  init: RequestInit;
}

type Reply = { status?: number; body?: unknown };

/**
 * Answers the admin API from a table of "METHOD /path" replies and records
 * every call. A reply may be a list, used in order, the last one repeating.
 */
export function serve(routes: Record<string, Reply | Reply[]>): Call[] {
  const calls: Call[] = [];
  const seen: Record<string, number> = {};
  fetchMock.mockResponse(async (request) => {
    const path = request.url.replace(`${API}/api/v1`, "");
    const key = `${request.method} ${path}`;
    const text = await request.text();
    calls.push({ method: request.method, path, body: text ? JSON.parse(text) : undefined, headers: request.headers, init: {} });
    const entry = routes[key];
    if (!entry) return { status: 500, body: JSON.stringify({ detail: `unexpected ${key}` }) };
    const list = Array.isArray(entry) ? entry : [entry];
    const reply = list[Math.min(seen[key] ?? 0, list.length - 1)];
    seen[key] = (seen[key] ?? 0) + 1;
    const status = reply.status ?? 200;
    return { status, body: status === 204 ? "" : JSON.stringify(reply.body ?? null) };
  });
  return calls;
}

export function changes(calls: Call[]): Call[] {
  return calls.filter((call) => call.method !== "GET");
}
