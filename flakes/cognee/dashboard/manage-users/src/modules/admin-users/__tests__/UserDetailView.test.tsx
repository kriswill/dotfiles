import { MantineProvider } from "@mantine/core";
import { fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import { notifications } from "@mantine/notifications";
import UserDetailView from "../UserDetailView";
import { changes, detail, serve } from "../__fixtures__/adminApi";

const push = jest.fn();
jest.mock("next/navigation", () => ({ useRouter: () => ({ push }), usePathname: () => "/manage-users/u-reader" }));
jest.mock("@mantine/notifications", () => ({ notifications: { show: jest.fn() } }));
jest.mock("@/modules/users/getLocalApiUrl", () => ({ getLocalApiUrl: () => "https://fixture.example.test" }));

const USER = "/admin/users/u-reader";

function open(): void {
  render(<MantineProvider><UserDetailView userId="u-reader" /></MantineProvider>);
}

function section(name: string): HTMLElement {
  return screen.getByRole("region", { name });
}

beforeEach(() => fetchMock.resetMocks());

it("shows the account, its keys by name only, and what it can reach", async () => {
  serve({ [`GET ${USER}`]: { body: detail() } });
  open();

  expect(await screen.findByRole("heading", { level: 1, name: "reader@example.test" })).toBeInTheDocument();
  expect(within(section("API keys")).getByText("Hermes")).toBeInTheDocument();
  expect(within(section("API keys")).getByText(/Never used/)).toBeInTheDocument();
  expect(within(section("Dataset access")).getByRole("list", { name: "Owned datasets" })).toHaveTextContent("notes");
  expect(screen.getByRole("combobox", { name: "Access to handbook" })).toHaveValue("view");
  // A dataset already shared is not offered again.
  const offered = within(screen.getByRole("combobox", { name: "Dataset to share" })).getAllByRole("option").map((option) => option.textContent);
  expect(offered).toEqual(["Choose a dataset…", "runbooks (operator@example.test)"]);
  expect(section("Tenants and roles")).toHaveTextContent("This instance has no tenants");
});

it.each([
  [401, "Sign in again to manage users."],
  [403, "Superuser access required."],
  [404, "This user no longer exists."],
])("explains a %s instead of showing an account", async (status, message) => {
  serve({ [`GET ${USER}`]: { status, body: { detail: "reader@example.test" } } });
  open();
  expect(await screen.findByRole("alert")).toHaveTextContent(message);
  expect(screen.queryByText("reader@example.test")).not.toBeInTheDocument();
  expect(screen.getByRole("link", { name: "All users" })).toHaveAttribute("href", "/manage-users");
});

it("holds back changes the server would refuse and says why", async () => {
  const locks = { demote: "You cannot remove your own superuser access.", deactivate: "You cannot deactivate your own account.", delete: "You cannot delete your own account." };
  serve({ [`GET ${USER}`]: { body: detail({ isSuperuser: true, isSelf: true, locks }) } });
  open();

  expect(await screen.findByRole("button", { name: "Remove superuser access" })).toBeDisabled();
  expect(screen.getByRole("button", { name: "Deactivate" })).toBeDisabled();
  expect(screen.getByRole("button", { name: "Delete user" })).toBeDisabled();
  for (const reason of Object.values(locks)) expect(screen.getByText(reason)).toBeInTheDocument();
});

it("asks before removing superuser access and reports a refusal in the dialog", async () => {
  const calls = serve({
    [`GET ${USER}`]: { body: detail({ isSuperuser: true }) },
    [`PUT ${USER}/account`]: { status: 409, body: { detail: "This is the only superuser who can sign in." } },
  });
  open();

  fireEvent.click(await screen.findByRole("button", { name: "Remove superuser access" }));
  expect(changes(calls)).toHaveLength(0);
  const dialog = await screen.findByRole("dialog", { name: "Remove superuser access?" });
  fireEvent.click(within(dialog).getByRole("button", { name: "Remove superuser access" }));

  expect(await within(dialog).findByRole("alert")).toHaveTextContent("This is the only superuser who can sign in.");
  expect(changes(calls)[0]).toMatchObject({ method: "PUT", body: { isSuperuser: false } });
  expect(notifications.show).not.toHaveBeenCalled();
});

it("reactivates without a dialog and re-reads the account", async () => {
  const calls = serve({
    [`GET ${USER}`]: [{ body: detail({ isActive: false }) }, { body: detail() }],
    [`PUT ${USER}/account`]: { status: 204 },
  });
  open();

  fireEvent.click(await screen.findByRole("button", { name: "Reactivate" }));
  expect(await screen.findByRole("button", { name: "Deactivate" })).toBeEnabled();
  expect(changes(calls)[0].body).toEqual({ isActive: true });
  expect(notifications.show).toHaveBeenCalledWith(expect.objectContaining({ title: "Account reactivated" }));
});

it("sets a password only once both entries match, and can revoke keys with it", async () => {
  const calls = serve({ [`GET ${USER}`]: { body: detail() }, [`PUT ${USER}/password`]: { body: { revokedApiKeys: 1 } } });
  open();

  fireEvent.click(await screen.findByRole("button", { name: "Set a new password" }));
  const dialog = await screen.findByRole("dialog", { name: "Set a new password" });
  const submit = within(dialog).getByRole("button", { name: "Set password" });
  fireEvent.change(within(dialog).getByLabelText("New password"), { target: { value: "correct horse" } });
  fireEvent.change(within(dialog).getByLabelText("Repeat new password"), { target: { value: "correct house" } });
  expect(within(dialog).getByText("The passwords do not match.")).toBeInTheDocument();
  expect(submit).toBeDisabled();
  fireEvent.change(within(dialog).getByLabelText("Repeat new password"), { target: { value: "correct horse" } });
  fireEvent.click(within(dialog).getByRole("checkbox", { name: /Also revoke this user's API key/ }));
  fireEvent.click(submit);

  await waitFor(() => expect(notifications.show).toHaveBeenCalledWith(expect.objectContaining({ title: "Password set", message: "1 API key revoked." })));
  expect(changes(calls)[0].body).toEqual({ password: "correct horse", revokeApiKeys: true });
  // The password is not left on the page once it has been sent.
  await waitFor(() => expect(screen.queryByRole("dialog")).not.toBeInTheDocument());
  expect(document.body).not.toHaveTextContent("correct horse");
});

it("shows a new key once and drops it when the dialog closes", async () => {
  const key = "f".repeat(64);
  const calls = serve({ [`GET ${USER}`]: { body: detail() }, [`POST ${USER}/api-keys`]: { status: 201, body: { id: "k-2", name: "ci", label: "ffffffff****", key } } });
  open();

  fireEvent.click(await screen.findByRole("button", { name: "Create key" }));
  const form = await screen.findByRole("dialog", { name: "Create an API key" });
  fireEvent.change(within(form).getByLabelText("Key name"), { target: { value: " ci " } });
  fireEvent.click(within(form).getByRole("button", { name: "Create key" }));

  const issued = await screen.findByRole("dialog", { name: "Copy the new key" });
  expect(within(issued).getByRole("status", { name: "New API key" })).toHaveTextContent(key);
  expect(changes(calls)[0].body).toEqual({ name: "ci" });
  fireEvent.click(within(issued).getByRole("button", { name: "Done" }));
  await waitFor(() => expect(document.body).not.toHaveTextContent(key));
});

it("revokes a key only after confirmation", async () => {
  const calls = serve({ [`GET ${USER}`]: [{ body: detail() }, { body: detail({ apiKeys: [] }) }], [`DELETE ${USER}/api-keys/k-1`]: { status: 204 } });
  open();

  fireEvent.click(await screen.findByRole("button", { name: "Revoke Hermes" }));
  expect(changes(calls)).toHaveLength(0);
  fireEvent.click(within(await screen.findByRole("dialog", { name: "Revoke this API key?" })).getByRole("button", { name: "Revoke key" }));
  expect(await screen.findByText("No API keys.")).toBeInTheDocument();
  expect(changes(calls).map((call) => `${call.method} ${call.path}`)).toEqual([`DELETE ${USER}/api-keys/k-1`]);
});

it("changes, removes and grants dataset access as whole levels", async () => {
  const calls = serve({
    [`GET ${USER}`]: { body: detail() },
    [`PUT ${USER}/datasets/d-shared/permissions`]: { status: 204 },
    [`PUT ${USER}/datasets/d-other/permissions`]: { status: 409, body: { detail: "This dataset is outside the user's current tenant." } },
  });
  open();

  fireEvent.change(await screen.findByRole("combobox", { name: "Access to handbook" }), { target: { value: "edit" } });
  await waitFor(() => expect(changes(calls)).toHaveLength(1));
  await waitFor(() => expect(screen.getByRole("button", { name: "Remove access to handbook" })).toBeEnabled());
  fireEvent.click(screen.getByRole("button", { name: "Remove access to handbook" }));
  await waitFor(() => expect(changes(calls)).toHaveLength(2));
  await waitFor(() => expect(screen.getByRole("combobox", { name: "Dataset to share" })).toBeEnabled());
  fireEvent.change(screen.getByRole("combobox", { name: "Dataset to share" }), { target: { value: "d-other" } });
  fireEvent.change(screen.getByRole("combobox", { name: "Level for the new access" }), { target: { value: "full" } });
  await waitFor(() => expect(screen.getByRole("button", { name: "Grant access" })).toBeEnabled());
  fireEvent.click(screen.getByRole("button", { name: "Grant access" }));

  expect(await within(section("Dataset access")).findByRole("alert")).toHaveTextContent("outside the user's current tenant");
  expect(changes(calls).map((call) => call.body)).toEqual([
    { permissions: ["read", "write"] },
    { permissions: [] },
    { permissions: ["read", "write", "delete", "share"] },
  ]);
});

it("shows inherited and custom access without offering to edit what a role grants", async () => {
  serve({ [`GET ${USER}`]: { body: detail({ datasetAccess: [
    { datasetId: "d-shared", name: "handbook", ownerEmail: null, permissions: ["read", "share"], source: "direct", sourceName: null, effective: false },
    { datasetId: "d-team", name: "wiki", ownerEmail: "operator@example.test", permissions: ["read", "write"], source: "role", sourceName: "Editors", effective: true },
  ] }) } });
  open();

  expect(await screen.findByRole("combobox", { name: "Access to handbook" })).toHaveValue("");
  expect(screen.getByText(/Holds read, share/)).toBeInTheDocument();
  expect(screen.getByText("Not in effect")).toBeInTheDocument();
  expect(screen.getByText("Can edit, through the role Editors")).toBeInTheDocument();
  expect(screen.queryByRole("combobox", { name: "Access to wiki" })).not.toBeInTheDocument();
});

it("manages tenant membership and roles where tenants exist", async () => {
  const roles = [{ id: "r-1", name: "Editors" }, { id: "r-2", name: "Readers" }];
  const calls = serve({
    [`GET ${USER}`]: { body: detail({
      tenants: [{ id: "t-1", name: "Lab", isOwner: false, isCurrent: true, roles: [roles[0]] }],
      availableTenants: [{ id: "t-1", name: "Lab", roles }, { id: "t-2", name: "Ops", roles: [] }],
    }) },
    [`DELETE ${USER}/roles/r-1`]: { status: 204 },
    [`POST ${USER}/roles/r-2`]: { status: 204 },
    [`POST ${USER}/tenants/t-2`]: { status: 204 },
    [`DELETE ${USER}/tenants/t-1`]: { status: 204 },
  });
  open();

  fireEvent.click(await screen.findByRole("button", { name: "Remove role Editors" }));
  await waitFor(() => expect(changes(calls)).toHaveLength(1));
  await waitFor(() => expect(screen.getByRole("combobox", { name: "Role to add in Lab" })).toBeEnabled());
  fireEvent.change(screen.getByRole("combobox", { name: "Role to add in Lab" }), { target: { value: "r-2" } });
  await waitFor(() => expect(screen.getByRole("button", { name: "Add role" })).toBeEnabled());
  fireEvent.click(screen.getByRole("button", { name: "Add role" }));
  await waitFor(() => expect(changes(calls)).toHaveLength(2));
  fireEvent.change(screen.getByRole("combobox", { name: "Tenant to add this user to" }), { target: { value: "t-2" } });
  await waitFor(() => expect(screen.getByRole("button", { name: "Add to tenant" })).toBeEnabled());
  fireEvent.click(screen.getByRole("button", { name: "Add to tenant" }));
  await waitFor(() => expect(changes(calls)).toHaveLength(3));
  fireEvent.click(screen.getByRole("button", { name: "Remove from Lab" }));
  expect(changes(calls)).toHaveLength(3);
  fireEvent.click(within(await screen.findByRole("dialog", { name: "Remove from Lab?" })).getByRole("button", { name: "Remove from tenant" }));
  await waitFor(() => expect(changes(calls)).toHaveLength(4));

  expect(changes(calls).map((call) => `${call.method} ${call.path}`)).toEqual([
    `DELETE ${USER}/roles/r-1`, `POST ${USER}/roles/r-2`, `POST ${USER}/tenants/t-2`, `DELETE ${USER}/tenants/t-1`,
  ]);
});

it("deletes only after the email is typed, and says what is kept", async () => {
  const calls = serve({ [`GET ${USER}`]: { body: detail() }, [`DELETE ${USER}`]: { status: 204 } });
  open();

  fireEvent.click(await screen.findByRole("button", { name: "Delete user" }));
  const dialog = await screen.findByRole("dialog", { name: "Delete this user?" });
  expect(dialog).toHaveTextContent("Kept: the 1 dataset it owns");
  expect(dialog).toHaveTextContent("its 1 API key");
  const confirm = within(dialog).getByRole("button", { name: "Delete user" });
  expect(confirm).toBeDisabled();
  fireEvent.change(within(dialog).getByLabelText("Type reader@example.test to confirm"), { target: { value: "reader@example" } });
  expect(confirm).toBeDisabled();
  fireEvent.change(within(dialog).getByLabelText("Type reader@example.test to confirm"), { target: { value: "reader@example.test" } });
  fireEvent.click(confirm);

  await waitFor(() => expect(push).toHaveBeenCalledWith("/manage-users"));
  expect(changes(calls).map((call) => `${call.method} ${call.path}`)).toEqual([`DELETE ${USER}`]);
});
