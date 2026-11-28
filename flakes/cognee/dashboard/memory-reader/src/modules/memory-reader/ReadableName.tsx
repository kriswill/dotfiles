"use client";

import { useState, type ReactElement, type ReactNode } from "react";
import MemoryReader, { canRead } from "./MemoryReader";
import { useReaderScope } from "./ReaderScope";
import { needsContentRead } from "./upstream";

const FILE_LINK = "cursor-pointer rounded text-left text-[13px] font-medium text-[#D2BFFF] underline decoration-violet-400/40 underline-offset-4 hover:decoration-current focus-visible:outline-2";
// The finder's column is narrow: the name takes the free width and truncates.
const DOCUMENT_LINK = "min-w-0 flex-1 cursor-pointer truncate rounded text-left text-[13px] font-medium text-[#D2BFFF] underline decoration-violet-400/40 underline-offset-4 hover:decoration-current focus-visible:outline-2";

interface Row {
  id: string;
  name: string;
  label?: string;
  extension?: string;
}

/**
 * A document row's name. Inside a reader scope, a text document's name is a
 * button that opens it in the reader; anything else renders `children`, the
 * name exactly as upstream draws it.
 */
function ReadableName({ id, title, readable, className, tooltip, children }: {
  id: string; title: string; readable: boolean; className: string; tooltip?: boolean; children: ReactNode;
}): ReactElement {
  const scope = useReaderScope();
  const [open, setOpen] = useState(false);
  if (!scope || !readable) return <>{children}</>;
  return (
    <>
      <button type="button" aria-label={`Read ${title}`} aria-haspopup="dialog" title={tooltip ? `Read ${title}` : undefined}
        className={className} onClick={() => setOpen(true)}>{title}</button>
      {open && <MemoryReader {...scope} id={id} title={title} onClose={() => setOpen(false)} />}
    </>
  );
}

/** For the files table of a dataset's own page. */
export function ReadableFileName({ file, title, children }: { file: Row; title: string; children: ReactNode }): ReactElement {
  return (
    <ReadableName id={file.id} title={title} className={FILE_LINK}
      readable={needsContentRead(file) || canRead(file.name, file.extension)}>{children}</ReadableName>
  );
}

/** For the documents column of the datasets finder, whose rows are raw API rows. */
export function ReadableDocumentName({ doc, title, children }: {
  doc: Row & { originalExtension?: string; original_extension?: string }; title: string; children: ReactNode;
}): ReactElement {
  return (
    <ReadableName id={doc.id} title={title} tooltip className={DOCUMENT_LINK}
      readable={needsContentRead(doc) || canRead(doc.name, doc.originalExtension || doc.original_extension || doc.extension)}>{children}</ReadableName>
  );
}
