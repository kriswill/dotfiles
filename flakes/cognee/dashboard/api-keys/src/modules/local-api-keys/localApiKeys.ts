// API keys of a self-hosted Cognee, through the backend's own
// /api/v1/auth/api-keys routes and the signed-in session.

import { HttpError, localFetch } from "./upstream";
import type { ApiKey, CreateApiKeyResult } from "./upstream";

const CREATE_FAILED = "Could not create an API key.";

export async function createLocalApiKey(options: { name?: string } = {}): Promise<CreateApiKeyResult> {
  try {
    const response = await localFetch("/v1/auth/api-keys", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: options.name }),
    });
    if (!response.ok) {
      return { ok: false, error: CREATE_FAILED, status: response.status };
    }
    return { ok: true, key: await response.json() };
  } catch (error) {
    return {
      ok: false,
      error: error instanceof Error ? error.message : CREATE_FAILED,
      status: error instanceof HttpError ? error.status : undefined,
    };
  }
}

export async function listLocalApiKeys(): Promise<ApiKey[]> {
  const response = await localFetch("/v1/auth/api-keys");
  return response.json();
}

export async function revokeLocalApiKey(keyId: string): Promise<void> {
  const response = await localFetch("/v1/auth/api-keys/" + encodeURIComponent(keyId), {
    method: "DELETE",
  });
  if (!response.ok) throw new Error("Could not revoke the API key.");
}
