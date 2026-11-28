import { fireEvent, render, screen } from "@testing-library/react";
import type { ReactNode } from "react";
import DocumentsPanel from "@/app/(app)/datasets/partials/DocumentsPanel";

jest.mock("@/ui/elements/ModalShell", () => ({ __esModule: true, default: ({ children }: { children: ReactNode }) => <section role="dialog">{children}</section> }));
jest.mock("react-markdown", () => ({ __esModule: true, default: ({ children }: { children: string }) => <article>{children}</article> }));
const mockInstance = { instanceId: "local", name: "local", fetch: jest.fn() };
jest.mock("@/modules/tenant/TenantProvider", () => ({ useCogniInstance: () => ({ cogniInstance: mockInstance }) }));

// Upstream's documents column, which mounts the reader scope for the dataset
// selected in the finder.
function panel(selectedId: string | null, docs: { id: string; name: string; extension?: string; original_extension?: string }[]) {
  const onDeleteDoc = jest.fn();
  render(<DocumentsPanel selectedId={selectedId} selectedName="Shared notes" docs={docs} total={docs.length}
    docsLoading={false} docsError={false} hasMore={false} onLoadMore={jest.fn()}
    processingCounts={undefined} processingCountsError={false} processingFailed={false} onRefreshProcessing={jest.fn()}
    processing={false} isUploading={false} uploadStage="idle" uploadError={null} canRetryBuild={false}
    onUpload={jest.fn()} onPaste={jest.fn()} onDeleteDoc={onDeleteDoc} onClearUploadError={jest.fn()}
    onRetryBuild={jest.fn()} onRetryDocs={jest.fn()} />);
  return onDeleteDoc;
}

test("the finder opens the selected document without entering the detail page", async () => {
  mockInstance.fetch.mockResolvedValue({ ok: true, text: async () => "End of the fixture." });
  const onDeleteDoc = panel("shared", [{ id: "fixture", name: "memory-fixture", extension: "txt" }]);
  fireEvent.click(screen.getByRole("button", { name: "Read memory-fixture" }));
  expect(await screen.findByText("End of the fixture.")).toBeVisible();
  expect(mockInstance.fetch.mock.calls[0][0]).toBe("/v1/datasets/shared/data/fixture/raw");
  fireEvent.click(screen.getByRole("button", { name: "Close" }));
  expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  expect(onDeleteDoc).not.toHaveBeenCalled();
});

test("only text documents are readable, judged by the extension the file arrived with", () => {
  panel("shared", [
    { id: "converted", name: "report", extension: "pdf", original_extension: "md" },
    { id: "binary", name: "scan.pdf" },
  ]);
  expect(screen.getByRole("button", { name: "Read report" })).toBeInTheDocument();
  expect(screen.queryByRole("button", { name: /scan.pdf/ })).not.toBeInTheDocument();
  expect(screen.getByText("scan.pdf").tagName).toBe("SPAN");
});
