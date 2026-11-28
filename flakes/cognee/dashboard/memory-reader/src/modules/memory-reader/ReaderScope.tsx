"use client";

import { createContext, useContext, type ReactElement, type ReactNode } from "react";
import { useCogniInstance } from "./upstream";
import type { ReaderScope } from "./MemoryReader";

const ReaderScopeContext = createContext<ReaderScope | null>(null);

/**
 * Says which dataset the document rows below it belong to. Mounted around
 * upstream's two document lists; without it a row's name stays plain text.
 * The instance comes from the session, so nothing is passed down through
 * upstream's components.
 */
export function MemoryReaderScope({ datasetId, children }: { datasetId: string | null; children: ReactNode }): ReactElement {
  const { cogniInstance } = useCogniInstance();
  const scope = datasetId && cogniInstance ? { datasetId, instance: cogniInstance } : null;
  return <ReaderScopeContext.Provider value={scope}>{children}</ReaderScopeContext.Provider>;
}

export function useReaderScope(): ReaderScope | null {
  return useContext(ReaderScopeContext);
}
