"use client";

import { lazy, Suspense, useEffect, useState } from "react";
import { ModalShell, readTextPrefix } from "./upstream";
import type { CogneeInstance } from "./upstream";

export type ReaderScope = { datasetId: string; instance: CogneeInstance };
export const canRead = (name: string, extension?: string) =>
  /^(txt|md|markdown)$/i.test((extension || name.split(".").pop() || "").replace(/^\./, ""));

const LIMIT = 128 * 1024;
const Markdown = lazy(() => import("react-markdown"));
type Result = { text: string; clipped: boolean } | { error: string };

export default function MemoryReader({ datasetId, instance, id, title, onClose }: ReaderScope & {
  id: string; title: string; onClose: () => void;
}) {
  const [result, setResult] = useState<Result | null>(null);
  const [original, setOriginal] = useState(false);
  const [attempt, retry] = useState(0);
  const path = `/v1/datasets/${encodeURIComponent(datasetId)}/data/${encodeURIComponent(id)}/raw`;
  useEffect(() => {
    const controller = new AbortController();
    async function read(): Promise<Result> {
      const res = await instance.fetch(path, { signal: controller.signal, cache: "no-store" });
      if (!res.ok) return { error: res.status === 401 || res.status === 403 ? "You don’t have permission to read this document." : res.status === 404 ? "This document is no longer available." : "Couldn’t load this document." };
      const prefix = await readTextPrefix(res, LIMIT + 1);
      const bytes = new Blob([prefix]);
      const clipped = bytes.size > LIMIT;
      return { text: clipped ? await bytes.slice(0, LIMIT).text() : prefix, clipped };
    }
    read().catch(() => ({ error: "Couldn’t load this document." })).then(value => {
      if (!controller.signal.aborted) setResult(value);
    });
    return () => controller.abort();
  }, [instance, path, attempt]);

  const control = "rounded-md px-3 py-1.5 text-sm hover:bg-white/10 focus-visible:outline-2 focus-visible:outline-violet-300";
  return <ModalShell width={760} label={`Read ${title}`} onClose={onClose}>
    <header className="flex items-start justify-between gap-4">
      <div className="min-w-0"><p className="mb-1 text-xs font-semibold tracking-widest text-[#BC9BFF] uppercase">Document reader</p>
        <h2 className="text-xl font-semibold text-[#EDECEA] [overflow-wrap:anywhere]">{title}</h2></div>
      <button type="button" className={control} onClick={onClose}>Close</button>
    </header>
    {!result ? <p role="status">Loading document…</p> : "error" in result ? <div><p role="alert">{result.error}</p>
      <button className={control} onClick={() => { setResult(null); retry(n => n + 1); }}>Retry</button></div> : <>
      <div role="group" aria-label="Reading mode" className="flex gap-1 border-b border-white/10 pb-3">
        {[false, true].map(raw => <button key={String(raw)} type="button" aria-pressed={raw === original}
          className={`${control} aria-pressed:bg-violet-400/15 aria-pressed:text-[#D2BFFF]`} onClick={() => setOriginal(raw)}>{raw ? "Original" : "Formatted"}</button>)}
      </div>
      {result.clipped && <p className="text-sm">Showing the first 128 KiB. <a className="text-[#BC9BFF] underline" download="document.txt" href={`/api${path}`}>Download full text</a></p>}
      <div tabIndex={0} role="region" aria-label="Document text" className="max-h-[58dvh] overflow-auto rounded-lg bg-white/[0.035] px-5 py-4 text-[#EDECEA] [overflow-wrap:anywhere]">
        {!result.text.trim() ? <p>This document is empty.</p> : original ? <pre className="whitespace-pre-wrap text-sm">{result.text}</pre> :
          <article className="space-y-3 text-[15px] leading-7 [&_p]:whitespace-pre-line [&_h1]:text-2xl [&_h2]:text-xl [&_h3]:text-lg [&_h1]:font-semibold [&_h2]:font-semibold [&_h3]:font-semibold [&_ul]:list-disc [&_ol]:list-decimal [&_ul]:pl-6 [&_ol]:pl-6 [&_blockquote]:border-l-2 [&_blockquote]:border-violet-400/50 [&_blockquote]:pl-4 [&_pre]:overflow-x-auto [&_pre]:rounded-md [&_pre]:bg-black/40 [&_pre]:p-3 [&_code]:text-sm [&_code]:text-violet-200">
            <Suspense fallback={<p role="status">Formatting document…</p>}>
              <Markdown skipHtml components={{ img: ({ alt }) => <span>{alt || "[image]"}</span>, a: ({ children }) => <span>{children}</span> }}>{result.text}</Markdown>
            </Suspense>
          </article>}
      </div>
    </>}
  </ModalShell>;
}
