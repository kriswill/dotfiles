// Startup measurement for `okf viz --perf`: load the built viz.html in
// headless Chrome via file://, wait for the in-page performance marks
// (window.__okf.perf, see viz-app/perf.ts), and print a timing table.
// puppeteer-core drives the *system* Chrome — no Chromium download.
import { existsSync } from "node:fs";
import puppeteer from "puppeteer-core";
import type { PerfEntry } from "./viz-app/perf";

const DEFAULT_CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

export async function measureStartup(htmlPath: string, timeoutMs = 15_000): Promise<PerfEntry[]> {
  const executablePath = process.env.PUPPETEER_EXECUTABLE_PATH ?? DEFAULT_CHROME;
  if (!existsSync(executablePath)) {
    throw new Error(`viz --perf: Chrome not found at ${executablePath} — set PUPPETEER_EXECUTABLE_PATH`);
  }
  const browser = await puppeteer.launch({ executablePath, headless: true });
  try {
    const page = await browser.newPage();
    const pageErrors: string[] = [];
    page.on("pageerror", (e) => pageErrors.push(String(e)));
    await page.goto("file://" + htmlPath);
    await page.waitForFunction(
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      () => (window as any).__okf?.perf?.summary().some((e: { name: string }) => e.name === "viz:interactive"),
      { timeout: timeoutMs, polling: 50 },
    );
    if (pageErrors.length) console.error("viz --perf: page errors:", pageErrors.join("; "));
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    return await page.evaluate(() => (window as any).__okf.perf.summary() as PerfEntry[]);
  } finally {
    await browser.close();
  }
}

export function printStartup(entries: PerfEntry[]) {
  console.log("viz startup (headless chrome, ms since navigation):");
  for (const e of entries) {
    console.log(`  ${e.name.slice(4).padEnd(12)} ${e.ms.toFixed(1).padStart(8)}`);
  }
}
