import { GlobalRegistrator } from "@happy-dom/global-registrator";

GlobalRegistrator.register();

// Deterministic fallbacks for APIs the viewer touches at init time.
const g = globalThis as Record<string, unknown>;
if (typeof g.matchMedia !== "function") {
  g.matchMedia = () => ({
    matches: false,
    addEventListener() {},
    removeEventListener() {},
  });
}
if (typeof g.ResizeObserver !== "function") {
  g.ResizeObserver = class {
    observe() {}
    unobserve() {}
    disconnect() {}
  };
}
