import { render, screen } from "@testing-library/react";
import type { DeploymentReleaseLog } from "../releaseLog";

const mockUseReleases = jest.fn();
jest.mock("@/modules/analytics", () => ({ TrackPageView: () => null }));
jest.mock("react-markdown", () => ({ __esModule: true, default: ({ children }: { children: string }) => <article>{children}</article> }));
jest.mock("@/modules/releases/useReleases", () => ({ useReleases: () => mockUseReleases() }));

import ReleaseNotesPage from "../ReleaseNotesPage";

const CLOUD_LOG: DeploymentReleaseLog = {
  runningVersion: "1.6.2-b45dc59",
  available: true,
  stale: false,
  releases: [{
    version: "v1.6.2", releasedAt: "2026-10-01T13:52:19Z", summary: "Faster graph loads.",
    highlights: ["Graphs open sooner"], fixes: [], hasNotes: true,
  }],
};
const installed = { ...CLOUD_LOG.releases[0], version: "v1.6.10", summary: "", highlights: [], markdown: "Installed release body" };
const SELF_HOSTED_LOG: DeploymentReleaseLog = {
  ...CLOUD_LOG, runningVersion: "1.6.10", releases: [installed],
  upstream: { status: "checked", update: { ...installed, version: "v1.6.11", markdown: "Available release body" } },
};

function renderPage(state: { data?: DeploymentReleaseLog; isLoading?: boolean; isError?: boolean }) {
  mockUseReleases.mockReturnValue({ data: undefined, isLoading: false, isError: false, ...state });
  return render(<ReleaseNotesPage />);
}

it("shows installed and available notes in separately labeled sections", async () => {
  renderPage({ data: SELF_HOSTED_LOG });
  expect(screen.getByText("Self-hosted Cognee")).toBeInTheDocument();
  expect(screen.getByRole("heading", { name: "Running version · v1.6.10" })).toBeInTheDocument();
  expect(await screen.findByText("Installed release body")).toBeInTheDocument();
  expect(screen.getByRole("heading", { name: "Update available · v1.6.11" }).closest("section")).toHaveAttribute("id", "available-release");
  expect(screen.getByText("Available release body")).toBeInTheDocument();
  expect(screen.getByRole("link", { name: "View v1.6.11 on GitHub" })).toHaveAttribute("href", "https://github.com/topoteretes/cognee/releases/tag/v1.6.11");
});

it.each([
  ["checked", "No newer stable release is available."],
  ["unsupported", "This build does not use a stable version tag."],
  ["unavailable", "Could not check for a newer release on GitHub."],
] as const)("says what a %s check found when there is no update", (status, message) => {
  renderPage({ data: { ...SELF_HOSTED_LOG, releases: [], upstream: { status, update: null } } });
  expect(screen.getByRole("heading", { name: "Upstream release" })).toBeInTheDocument();
  expect(screen.getByText(message)).toBeInTheDocument();
  expect(screen.getByText("Could not load GitHub notes for the running version.")).toBeInTheDocument();
});

it("says the log is unavailable when the route fails", () => {
  renderPage({ isError: true });
  expect(screen.getByText("The Cognee release log is unavailable.")).toBeInTheDocument();
  expect(screen.getByText("Release notes could not be loaded. Try again in a moment.")).toBeInTheDocument();
});

it("keeps the deployment's heading but not its last notes when a refresh fails", () => {
  renderPage({ data: SELF_HOSTED_LOG, isError: true });
  expect(screen.getByText("Self-hosted Cognee")).toBeInTheDocument();
  expect(screen.getByText("Release notes could not be loaded. Try again in a moment.")).toBeInTheDocument();
  expect(screen.queryByText(/Update available/)).not.toBeInTheDocument();
});

it("is upstream's page while loading and for a log without an upstream check", () => {
  const { unmount } = renderPage({ isLoading: true });
  expect(screen.getByText("Loading release notes…")).toBeInTheDocument();
  expect(screen.getByText("What changed in Cloud, release by release.")).toBeInTheDocument();
  unmount();

  renderPage({ data: CLOUD_LOG });
  expect(screen.getByText("This workspace runs Cloud v1.6.2.")).toBeInTheDocument();
  expect(screen.getByText("Graphs open sooner")).toBeInTheDocument();
});
