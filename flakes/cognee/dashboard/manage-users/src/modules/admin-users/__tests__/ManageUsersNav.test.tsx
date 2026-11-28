import { render, screen, waitFor } from "@testing-library/react";
import ManageUsersNav from "../ManageUsersNav";

jest.mock("next/navigation", () => ({ usePathname: () => "/dashboard" }));
jest.mock("@/modules/users/getLocalApiUrl", () => ({ getLocalApiUrl: () => "https://fixture.example.test" }));

beforeEach(() => fetchMock.resetMocks());

it.each([[true, true], [false, false], [undefined, false], ["true", false]])(
  "uses the signed-in superuser flag (%s) to show the admin entry",
  async (flag, visible) => {
    fetchMock.mockResponseOnce(JSON.stringify({ id: "fixture", is_superuser: flag }));
    render(<ManageUsersNav />);
    expect(screen.queryByRole("link", { name: "Manage Users" })).not.toBeInTheDocument();
    await waitFor(() => expect(fetchMock).toHaveBeenCalledWith(
      "https://fixture.example.test/api/v1/users/me", expect.objectContaining({ credentials: "include", cache: "no-store" }),
    ));
    if (visible) expect(await screen.findByRole("link", { name: "Manage Users" })).toHaveAttribute("href", "/manage-users");
    else {
      await new Promise((resolve) => setTimeout(resolve, 0));
      expect(screen.queryByRole("link", { name: "Manage Users" })).not.toBeInTheDocument();
    }
  },
);

it.each([401, 500])("stays hidden when the session check answers %s", async (status) => {
  fetchMock.mockResponseOnce("{}", { status });
  render(<ManageUsersNav />);
  await waitFor(() => expect(fetchMock).toHaveBeenCalled());
  await new Promise((resolve) => setTimeout(resolve, 0));
  expect(screen.queryByText("Administration")).not.toBeInTheDocument();
});
