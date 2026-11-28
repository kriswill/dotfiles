import { fireEvent, render, screen } from "@testing-library/react";
import type { ReactNode } from "react";
import { LocalAgentSetupModal } from "../LocalAgentSetupModal";
import type { SetupConnectorCfg } from "../upstream";

let mockInstance: { name: string } | null = { name: "LocalCognee" };
jest.mock("@/modules/tenant/TenantProvider", () => ({
  useCogniInstance: () => ({ cogniInstance: mockInstance, serviceUrl: "https://cognee.example.com", apiKey: "workspace-key", isInitializing: false }),
}));
jest.mock("@/ui/layout/OsPreferenceContext", () => ({ useOsPreference: () => ({ os: "mac" }) }));
jest.mock("@/app/(app)/dashboard/hooks/useDashboardTelemetry", () => ({
  useDashboardTelemetry: () => ({ sessions: [], connections: [] }),
}));
// Upstream's modal is real; only the wizard it renders the steps into is a stub.
jest.mock("@/ui/elements/ConnectedAgentModal", () => ({ ConnectedAgentModal: () => null }));
jest.mock("@/ui/elements/SetupWizardModal", () => ({
  SetupWizardModal: ({ steps }: { steps: { title: string; code?: string; content?: ReactNode }[] }) => (
    <ol>{steps.map((step) => <li key={step.title}>{step.title}: {step.code}{step.content}</li>)}</ol>
  ),
}));
const mockCreate = jest.fn();
jest.mock("@/modules/local-api-keys/localApiKeys", () => ({ createLocalApiKey: (...args: unknown[]) => mockCreate(...args) }));

function card(key: string, name: string): SetupConnectorCfg & { buildSteps: jest.Mock } {
  return {
    key, name, cta: "", description: "", icon: null,
    buildSteps: jest.fn((_baseUrl: string, apiKey: string, gated: boolean) => [
      { title: "Install", description: "" },
      { title: "Configure", description: "", code: `KEY=${apiKey} gated=${gated}` },
    ]),
  };
}

function open(active: SetupConnectorCfg) {
  render(<LocalAgentSetupModal cards={[active]} connectedKeys={{}} activeKey={active.key} onClose={jest.fn()} />);
}

beforeEach(() => {
  mockInstance = { name: "LocalCognee" };
});

it("asks for a key in place of the configure step, then shows the instructions with it", async () => {
  const codex = card("codex", "Codex");
  mockCreate.mockResolvedValue({ ok: true, key: { id: "fixture", key: "issued-once" } });
  open(codex);

  expect(codex.buildSteps).toHaveBeenLastCalledWith("https://cognee.example.com", "your-api-key", true, "mac");
  expect(screen.getByText(/Install:/)).toBeInTheDocument();
  expect(screen.queryByText(/Configure:/)).not.toBeInTheDocument();
  expect(screen.queryByText(/workspace-key/)).not.toBeInTheDocument();

  fireEvent.click(screen.getByRole("button", { name: "Create API key" }));
  expect(await screen.findByText(/KEY=issued-once gated=false/)).toBeInTheDocument();
  expect(mockCreate).toHaveBeenCalledWith({ name: "Codex setup" });
  expect(screen.queryByRole("button", { name: "Create API key" })).not.toBeInTheDocument();
});

it("puts the key step first for Hermes", () => {
  open(card("hermes", "Hermes"));
  expect(screen.getAllByRole("listitem")[0]).toHaveTextContent("Create an API key");
  expect(screen.getByText(/Configure: KEY=your-api-key gated=true/)).toBeInTheDocument();
});

it("shows why a key could not be created and lets the user try again", async () => {
  mockCreate.mockResolvedValue({ ok: false, error: "Could not create an API key.", status: 403 });
  open(card("claude-code", "Claude Code"));
  fireEvent.click(screen.getByRole("button", { name: "Create API key" }));
  expect(await screen.findByRole("alert")).toHaveTextContent("Could not create an API key.");
  expect(screen.getByRole("button", { name: "Create API key" })).toBeEnabled();
});

it("leaves other connectors and other instances to upstream's own key", () => {
  const cursor = card("cursor", "Cursor");
  open(cursor);
  expect(cursor.buildSteps).toHaveBeenLastCalledWith("https://cognee.example.com", "workspace-key", false, "mac");
  expect(screen.getByText(/KEY=workspace-key gated=false/)).toBeInTheDocument();

  mockInstance = { name: "CloudCognee" };
  const codex = card("codex", "Codex");
  open(codex);
  expect(codex.buildSteps).toHaveBeenLastCalledWith("https://cognee.example.com", "workspace-key", false, "mac");
  expect(screen.queryByRole("button", { name: "Create API key" })).not.toBeInTheDocument();
});
