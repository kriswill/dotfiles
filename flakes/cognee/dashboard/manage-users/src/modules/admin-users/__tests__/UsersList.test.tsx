import { MantineProvider } from "@mantine/core";
import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import UsersList from "../UsersList";
import { changes, serve, summary } from "../__fixtures__/adminApi";

const push = jest.fn();
jest.mock("next/navigation", () => ({ useRouter: () => ({ push }), usePathname: () => "/manage-users" }));
jest.mock("@mantine/notifications", () => ({ notifications: { show: jest.fn() } }));
jest.mock("@/modules/users/getLocalApiUrl", () => ({ getLocalApiUrl: () => "https://fixture.example.test" }));

const roster = [
  summary({ id: "a", email: "operator@example.test", isSuperuser: true, isSelf: true, apiKeyCount: 2, datasetsOwned: 0 }),
  summary({ id: "b", email: "reader@example.test", isActive: false, hasPassword: false, apiKeyCount: 0 }),
];

function open(): void {
  render(<MantineProvider><UsersList /></MantineProvider>);
}

beforeEach(() => fetchMock.resetMocks());

it("lists every account, links each to its own page, and filters", async () => {
  serve({ "GET /admin/users": { body: roster } });
  open();

  expect(await screen.findByRole("link", { name: "operator@example.test" })).toHaveAttribute("href", "/manage-users/a");
  expect(screen.getByRole("columnheader", { name: "Datasets owned" })).toBeInTheDocument();
  expect(screen.getByRole("rowheader", { name: "reader@example.test" }).closest("tr")).toHaveTextContent("StandardInactive, no password01");
  fireEvent.change(screen.getByRole("combobox", { name: "Filter by role" }), { target: { value: "superuser" } });
  expect(screen.queryByText("reader@example.test")).not.toBeInTheDocument();
  expect(screen.getByText("1 of 2 users")).toBeInTheDocument();
  fireEvent.change(screen.getByRole("searchbox", { name: "Search by email" }), { target: { value: "missing" } });
  expect(screen.getByText("No users match your filters.")).toBeInTheDocument();
});

it("renders access denied without showing accounts or offering changes", async () => {
  serve({ "GET /admin/users": { status: 403, body: { detail: "operator@example.test" } } });
  open();
  expect(await screen.findByRole("alert")).toHaveTextContent("Superuser access required");
  expect(screen.queryByText(/operator@example.test/)).not.toBeInTheDocument();
  expect(screen.queryByRole("button", { name: "Add user" })).not.toBeInTheDocument();
});

it("clears previously loaded users if a refresh loses access", async () => {
  serve({ "GET /admin/users": [{ body: roster }, { status: 401 }] });
  open();
  await screen.findByText("operator@example.test");
  fireEvent.click(screen.getByRole("button", { name: "Refresh users" }));
  expect(await screen.findByRole("alert")).toHaveTextContent("Sign in again");
  expect(screen.queryByText("operator@example.test")).not.toBeInTheDocument();
});

it("does not present a server failure as an empty roster and can retry", async () => {
  serve({ "GET /admin/users": [{ status: 503 }, { body: [] }] });
  open();
  expect(await screen.findByRole("alert")).toHaveTextContent("Could not load users");
  fireEvent.click(screen.getByRole("button", { name: "Try again" }));
  expect(await screen.findByText("No users to display.")).toBeInTheDocument();
});

it("adds a key-only account and opens it", async () => {
  const calls = serve({ "GET /admin/users": { body: roster }, "POST /admin/users": { status: 201, body: summary({ id: "new", email: "agent@example.test" }) } });
  open();
  fireEvent.click(await screen.findByRole("button", { name: "Add user" }));
  const dialog = await screen.findByRole("dialog", { name: "Add user" });
  const submit = screen.getAllByRole("button", { name: "Add user" }).find((button) => dialog.contains(button))!;

  fireEvent.change(screen.getByLabelText("Email"), { target: { value: " agent@example.test " } });
  expect(submit).toBeDisabled();
  fireEvent.click(screen.getByRole("checkbox", { name: /No password/ }));
  expect(screen.queryByLabelText("Password")).not.toBeInTheDocument();
  expect(screen.getByRole("checkbox", { name: /Superuser/ })).toBeDisabled();
  fireEvent.click(submit);

  await waitFor(() => expect(push).toHaveBeenCalledWith("/manage-users/new"));
  expect(changes(calls)[0].body).toEqual({ email: "agent@example.test", password: null, isSuperuser: false });
});

it("keeps the dialog open with the server's reason when the account is refused", async () => {
  serve({ "GET /admin/users": { body: roster }, "POST /admin/users": { status: 409, body: { detail: "A user with this email already exists." } } });
  open();
  fireEvent.click(await screen.findByRole("button", { name: "Add user" }));
  await screen.findByRole("dialog", { name: "Add user" });
  fireEvent.change(screen.getByLabelText("Email"), { target: { value: "reader@example.test" } });
  fireEvent.change(screen.getByLabelText("Password"), { target: { value: "long enough" } });
  fireEvent.submit(screen.getByLabelText("Email").closest("form")!);
  expect(await screen.findByRole("alert")).toHaveTextContent("A user with this email already exists.");
  expect(push).not.toHaveBeenCalled();
});
