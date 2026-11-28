import { getLocalApiUrl } from "./upstream";

export type DatasetPermission = "read" | "write" | "delete" | "share";

export interface UserSummary {
  id: string;
  email: string;
  isSuperuser: boolean;
  isActive: boolean;
  isVerified: boolean;
  hasPassword: boolean;
  isSelf: boolean;
  isDefault: boolean;
  isAgent: boolean;
  createdAt: string | null;
  apiKeyCount: number;
  datasetsOwned: number;
}

export interface ApiKeyInfo {
  id: string;
  name: string | null;
  label: string | null;
  createdAt: string | null;
  lastUsedAt: string | null;
}

export interface NewApiKey {
  id: string;
  name: string | null;
  label: string | null;
  key: string;
}

export interface DatasetAccess {
  datasetId: string;
  name: string | null;
  ownerEmail: string | null;
  permissions: DatasetPermission[];
  source: "direct" | "tenant" | "role";
  sourceName: string | null;
  effective: boolean;
}

export interface DatasetOption {
  id: string;
  name: string | null;
  ownerEmail: string | null;
}

export interface RoleRef {
  id: string;
  name: string;
}

export interface Membership extends RoleHolder {
  isOwner: boolean;
  isCurrent: boolean;
}

export interface RoleHolder {
  id: string;
  name: string;
  roles: RoleRef[];
}

export interface Locks {
  demote: string | null;
  deactivate: string | null;
  delete: string | null;
}

export interface UserDetail extends UserSummary {
  parentEmail: string | null;
  locks: Locks;
  apiKeys: ApiKeyInfo[];
  maxApiKeys: number;
  ownedDatasets: { id: string; name: string | null; createdAt: string | null }[];
  datasetAccess: DatasetAccess[];
  grantableDatasets: DatasetOption[];
  tenants: Membership[];
  availableTenants: RoleHolder[];
}

export interface AccountChange {
  isSuperuser?: boolean;
  isActive?: boolean;
  isVerified?: boolean;
}

/** A refused request. `status` 401 and 403 mean the session, not the change. */
export class AdminApiError extends Error {
  constructor(readonly status: number, message: string) {
    super(message);
    this.name = "AdminApiError";
  }
}

const FALLBACK: Record<number, string> = {
  401: "Your session has ended. Sign in again.",
  403: "Superuser access required.",
  404: "Not found.",
};

async function reason(response: Response): Promise<string> {
  const fallback = FALLBACK[response.status] ?? `The server answered ${response.status}.`;
  // 401 and 403 bodies describe the server's login setup, not this change.
  if (response.status === 401 || response.status === 403) return fallback;
  try {
    const body: unknown = await response.json();
    const detail = (body as { detail?: unknown } | null)?.detail;
    if (typeof detail === "string" && detail) return detail;
    // Cognee reports a malformed body as a list of field problems.
    if (Array.isArray(detail) && typeof detail[0]?.msg === "string") return detail[0].msg;
  } catch {
    // No JSON body to read.
  }
  return fallback;
}

async function request<T>(path: string, method = "GET", body?: unknown, signal?: AbortSignal): Promise<T> {
  const headers: Record<string, string> = {};
  // The backend refuses a change that does not declare it came from here.
  if (method !== "GET") headers["X-Cognee-Admin"] = "1";
  if (body !== undefined) headers["Content-Type"] = "application/json";
  let response: Response;
  try {
    response = await fetch(`${getLocalApiUrl()}/api/v1/admin${path}`, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
      credentials: "include",
      cache: "no-store",
      redirect: "error",
      signal,
    });
  } catch (error) {
    if (signal?.aborted) throw error;
    throw new AdminApiError(0, "Could not reach the server.");
  }
  if (!response.ok) throw new AdminApiError(response.status, await reason(response));
  return (response.status === 204 ? undefined : await response.json()) as T;
}

const user = (id: string): string => `/users/${encodeURIComponent(id)}`;

export const adminApi = {
  listUsers: (signal?: AbortSignal) => request<UserSummary[]>("/users", "GET", undefined, signal),
  getUser: (id: string, signal?: AbortSignal) => request<UserDetail>(user(id), "GET", undefined, signal),
  createUser: (input: { email: string; password: string | null; isSuperuser: boolean }) =>
    request<UserSummary>("/users", "POST", input),
  changeAccount: (id: string, change: AccountChange) => request<void>(`${user(id)}/account`, "PUT", change),
  setPassword: (id: string, password: string, revokeApiKeys: boolean) =>
    request<{ revokedApiKeys: number }>(`${user(id)}/password`, "PUT", { password, revokeApiKeys }),
  deleteUser: (id: string) => request<void>(user(id), "DELETE"),
  createApiKey: (id: string, name: string) => request<NewApiKey>(`${user(id)}/api-keys`, "POST", { name }),
  revokeApiKey: (id: string, keyId: string) =>
    request<void>(`${user(id)}/api-keys/${encodeURIComponent(keyId)}`, "DELETE"),
  setPermissions: (id: string, datasetId: string, permissions: readonly DatasetPermission[]) =>
    request<void>(`${user(id)}/datasets/${encodeURIComponent(datasetId)}/permissions`, "PUT", { permissions }),
  addToTenant: (id: string, tenantId: string) =>
    request<void>(`${user(id)}/tenants/${encodeURIComponent(tenantId)}`, "POST"),
  removeFromTenant: (id: string, tenantId: string) =>
    request<void>(`${user(id)}/tenants/${encodeURIComponent(tenantId)}`, "DELETE"),
  addRole: (id: string, roleId: string) => request<void>(`${user(id)}/roles/${encodeURIComponent(roleId)}`, "POST"),
  removeRole: (id: string, roleId: string) =>
    request<void>(`${user(id)}/roles/${encodeURIComponent(roleId)}`, "DELETE"),
};
