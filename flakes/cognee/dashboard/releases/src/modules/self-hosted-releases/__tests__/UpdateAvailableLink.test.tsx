import { render, screen } from "@testing-library/react";
import type { DeploymentReleaseLog } from "../releaseLog";
import UpdateAvailableLink from "../UpdateAvailableLink";

let mockState: { data?: DeploymentReleaseLog; isError?: boolean } = {};
jest.mock("@/modules/releases/useReleases", () => ({ useReleases: () => mockState }));

const update = { version: "v1.6.11", releasedAt: null, summary: "", highlights: [], fixes: [], hasNotes: false };
const log = (upstream: DeploymentReleaseLog["upstream"]): DeploymentReleaseLog => ({
  runningVersion: "1.6.10", available: true, stale: false, releases: [], upstream,
});

it("links to the available release only while an update is known", () => {
  mockState = { data: log({ status: "checked", update }) };
  const { rerender } = render(<UpdateAvailableLink />);
  expect(screen.getByRole("link", { name: "Cognee update available: v1.6.11" })).toHaveAttribute("href", "/releases#available-release");

  mockState = { data: log({ status: "unavailable", update: null }) };
  rerender(<UpdateAvailableLink />);
  expect(screen.queryByRole("link", { name: /update available/i })).not.toBeInTheDocument();

  mockState = { data: log({ status: "checked", update }), isError: true };
  rerender(<UpdateAvailableLink />);
  expect(screen.queryByRole("link", { name: /update available/i })).not.toBeInTheDocument();

  mockState = {};
  rerender(<UpdateAvailableLink />);
  expect(screen.queryByRole("link", { name: /update available/i })).not.toBeInTheDocument();
});
