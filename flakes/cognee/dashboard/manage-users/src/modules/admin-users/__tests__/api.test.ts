import { AdminApiError, adminApi } from "../api";
import { API, serve } from "../__fixtures__/adminApi";

jest.mock("@/modules/users/getLocalApiUrl", () => ({ getLocalApiUrl: () => "https://fixture.example.test" }));

beforeEach(() => fetchMock.resetMocks());

it("reads with the session cookie, uncached, and never follows a redirect", async () => {
  serve({ "GET /admin/users": { body: [] } });
  await adminApi.listUsers();
  expect(fetchMock).toHaveBeenCalledWith(`${API}/api/v1/admin/users`, expect.objectContaining({ method: "GET", credentials: "include", cache: "no-store", redirect: "error" }));
  expect(new Headers(fetchMock.mock.calls[0][1]?.headers).has("X-Cognee-Admin")).toBe(false);
});

it("marks every change as coming from the dashboard", async () => {
  const calls = serve({ "PUT /admin/users/u%2F1/account": { status: 204 }, "DELETE /admin/users/u%2F1": { status: 204 } });
  await adminApi.changeAccount("u/1", { isActive: false });
  await adminApi.deleteUser("u/1");
  expect(calls.map((call) => call.headers.get("X-Cognee-Admin"))).toEqual(["1", "1"]);
  expect(calls[0].body).toEqual({ isActive: false });
});

it.each([
  [409, { detail: "This is the only superuser who can sign in." }, "This is the only superuser who can sign in."],
  [400, { detail: [{ msg: "String should have at least 8 characters" }], body: { password: "short" } }, "String should have at least 8 characters"],
  [401, { detail: "Authentication is required because ENABLE_BACKEND_ACCESS_CONTROL is on" }, "Your session has ended. Sign in again."],
  [403, { detail: "Forbidden" }, "Superuser access required."],
  [502, "<html>", "The server answered 502."],
])("explains a %s refusal in the server's words where it is safe to", async (status, body, message) => {
  serve({ "PUT /admin/users/u-1/password": { status, body } });
  const refusal = await adminApi.setPassword("u-1", "short", false).catch((error: unknown) => error);
  expect(refusal).toBeInstanceOf(AdminApiError);
  expect(refusal).toMatchObject({ status, message });
});

it("reports an unreachable server instead of throwing a network error", async () => {
  fetchMock.mockReject(new TypeError("Failed to fetch"));
  await expect(adminApi.listUsers()).rejects.toMatchObject({ status: 0, message: "Could not reach the server." });
});
