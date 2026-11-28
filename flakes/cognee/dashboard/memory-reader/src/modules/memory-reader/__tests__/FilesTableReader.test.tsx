import { fireEvent, render, screen } from "@testing-library/react";
import type { ReactNode } from "react";
import FilesTable from "@/app/(app)/datasets/[id]/partials/FilesTable";
import { MemoryReaderScope } from "../ReaderScope";

jest.mock("@/ui/elements/ModalShell", () => ({ __esModule: true, default: ({ children }: { children: ReactNode }) => <section role="dialog">{children}</section> }));
jest.mock("react-markdown", () => ({ __esModule: true, default: ({ children }: { children: string }) => <article>{children}</article> }));
let mockInstance: { name: string; instanceId: string; fetch: jest.Mock } | null = null;
jest.mock("@/modules/tenant/TenantProvider", () => ({ useCogniInstance: () => ({ cogniInstance: mockInstance }) }));

// Upstream's table, as the dataset page mounts it: inside the reader scope.
function table(fetch: jest.Mock | null, datasetId: string | null = "collection") {
  mockInstance = fetch && { name: "local", instanceId: "local", fetch };
  const onDelete = jest.fn();
  render(<MemoryReaderScope datasetId={datasetId}><FilesTable
    files={[{ id: "doc", name: "notes.md" }, { id: "binary", name: "scan.pdf" }]}
    blobDescriptions={{}} search="" loadError={false} onDelete={onDelete} onUploadClick={jest.fn()} onRetry={jest.fn()} /></MemoryReaderScope>);
  return onDelete;
}

test("opens only the requested text source, switches to original, closes without deleting", async () => {
  const fetch = jest.fn().mockResolvedValue({ ok: true, text: async () => "# Notes\n\nOriginal words." });
  const onDelete = table(fetch);
  expect(fetch).not.toHaveBeenCalled();
  expect(screen.queryByRole("button", { name: /scan.pdf/i })).not.toBeInTheDocument();
  fireEvent.click(screen.getByRole("button", { name: /notes.md/i }));
  expect(await screen.findByText(/Original words/)).toBeInTheDocument();
  expect(fetch.mock.calls[0][0]).toBe("/v1/datasets/collection/data/doc/raw");
  fireEvent.click(screen.getByRole("button", { name: "Original" }));
  expect(screen.getByText(/Original words/).tagName).toBe("PRE");
  fireEvent.click(screen.getByRole("button", { name: "Close" }));
  expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  expect(onDelete).not.toHaveBeenCalled();
});

test("denied reads reveal no response body", async () => {
  const text = jest.fn();
  table(jest.fn().mockResolvedValue({ ok: false, status: 403, text }));
  fireEvent.click(screen.getByRole("button", { name: /notes.md/i }));
  expect(await screen.findByRole("alert")).toHaveTextContent(/permission/i);
  expect(text).not.toHaveBeenCalled();
});

test.each([
  ["no instance is connected", null, "collection"],
  ["no dataset is in scope", jest.fn(), null],
])("names stay plain text while %s", (_label, fetch, datasetId) => {
  table(fetch, datasetId);
  expect(screen.getByText("notes.md").tagName).toBe("SPAN");
  expect(screen.queryByRole("button", { name: /Read/ })).not.toBeInTheDocument();
});

test("a name that is not valid percent-encoding is shown as it is", () => {
  mockInstance = null;
  render(<FilesTable files={[{ id: "odd", name: "100%.txt" }]}
    blobDescriptions={{}} search="" loadError={false} onDelete={jest.fn()} onUploadClick={jest.fn()} onRetry={jest.fn()} />);
  expect(screen.getByText("100%.txt")).toBeInTheDocument();
});
