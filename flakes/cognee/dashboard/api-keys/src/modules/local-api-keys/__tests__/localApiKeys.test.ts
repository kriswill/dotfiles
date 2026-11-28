import { createLocalApiKey, listLocalApiKeys, revokeLocalApiKey } from "../localApiKeys";
import { HttpError } from "../upstream";
import createApiKey from "@/modules/apiKeys/createAPIKey";
import deleteApiKey from "@/modules/apiKeys/deleteAPIKey";
import getApiKeys from "@/modules/apiKeys/getApiKeys";

const mockLocalFetch = jest.fn();
jest.mock("@/modules/instances/localFetch", () => ({
  __esModule: true,
  default: (...args: unknown[]) => mockLocalFetch(...args),
}));

const reply = (body: unknown, status = 200) => ({ ok: status < 400, status, json: async () => body });

it("creates a key by name and returns it once", async () => {
  mockLocalFetch.mockResolvedValue(reply({ id: "fixture", key: "issued-once" }));
  await expect(createLocalApiKey({ name: "Codex setup" })).resolves.toEqual({
    ok: true, key: { id: "fixture", key: "issued-once" },
  });
  expect(mockLocalFetch).toHaveBeenCalledWith("/v1/auth/api-keys", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name: "Codex setup" }),
  });
});

it("reports a refused or failed creation without throwing", async () => {
  mockLocalFetch.mockResolvedValueOnce(reply({ detail: "denied" }, 403));
  await expect(createLocalApiKey()).resolves.toEqual({ ok: false, error: "Could not create an API key.", status: 403 });

  mockLocalFetch.mockRejectedValueOnce(new HttpError(409, "Conflict", "A key with this name exists."));
  await expect(createLocalApiKey({ name: "taken" })).resolves.toEqual({
    ok: false, error: "A key with this name exists.", status: 409,
  });

  mockLocalFetch.mockRejectedValueOnce("offline");
  await expect(createLocalApiKey()).resolves.toEqual({ ok: false, error: "Could not create an API key.", status: undefined });
});

it("lists the keys the backend returns", async () => {
  const keys = [{ id: "fixture", key: "abc…", label: "abc…", name: "Codex setup" }];
  mockLocalFetch.mockResolvedValue(reply(keys));
  await expect(listLocalApiKeys()).resolves.toEqual(keys);
  expect(mockLocalFetch).toHaveBeenCalledWith("/v1/auth/api-keys");
});

it("revokes one key by its encoded id and throws when refused", async () => {
  mockLocalFetch.mockResolvedValueOnce(reply(null));
  await revokeLocalApiKey("a/b");
  expect(mockLocalFetch).toHaveBeenCalledWith("/v1/auth/api-keys/a%2Fb", { method: "DELETE" });

  mockLocalFetch.mockResolvedValueOnce(reply(null, 403));
  await expect(revokeLocalApiKey("fixture")).rejects.toThrow("Could not revoke the API key.");
});

// The seam: upstream's three stubs are what the API Keys page imports.
it("is what the upstream API-key modules call", async () => {
  mockLocalFetch.mockResolvedValue(reply({ id: "fixture", key: "issued-once" }));
  await expect(createApiKey({ name: "from the page" })).resolves.toMatchObject({ ok: true });
  expect(mockLocalFetch).toHaveBeenLastCalledWith("/v1/auth/api-keys", expect.objectContaining({ method: "POST" }));

  mockLocalFetch.mockResolvedValue(reply([]));
  await expect(getApiKeys()).resolves.toEqual([]);
  expect(mockLocalFetch).toHaveBeenLastCalledWith("/v1/auth/api-keys");

  mockLocalFetch.mockResolvedValue(reply(null));
  await deleteApiKey("fixture");
  expect(mockLocalFetch).toHaveBeenLastCalledWith("/v1/auth/api-keys/fixture", { method: "DELETE" });
});
