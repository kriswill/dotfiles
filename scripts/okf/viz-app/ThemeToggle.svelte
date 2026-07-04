<script lang="ts">
  import type { VizState } from "./state.svelte";

  interface Props {
    viz: VizState;
    stageEl: HTMLElement | null;
    /** Bumped by Stage on window resize — clientWidth reads are not reactive. */
    resizeSeq?: number;
  }
  const { viz, stageEl, resizeSeq = 0 }: Props = $props();

  const isDark = $derived(viz.themeIndex === 1);
  const label = $derived(isDark ? "Switch to light theme" : "Switch to dark theme");
  // Stay clear of the detail panel — hug the graph's visible right edge
  // rather than the stage's, which the panel covers once it's open.
  const rightPx = $derived.by(() => {
    void resizeSeq;
    if (viz.sel.kind === "none" || !stageEl) return 16;
    return viz.panelPx(stageEl.clientWidth) + 16;
  });
</script>

<button
  id="theme-toggle"
  class="theme-toggle"
  type="button"
  aria-label={label}
  title={label}
  style:right={rightPx + "px"}
  onclick={() => viz.setTheme(isDark ? 0 : 1)}
>{isDark ? "☀" : "☾"}</button>

<style>
  .theme-toggle {
    position: absolute;
    bottom: 16px;
    z-index: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    width: 36px;
    height: 36px;
    border: 1px solid var(--grid);
    border-radius: 50%;
    background: var(--surface-1);
    color: var(--ink-2);
    font-size: 16px;
    line-height: 1;
    cursor: pointer;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
  }
  .theme-toggle:hover,
  .theme-toggle:focus-visible {
    color: var(--ink-1);
    border-color: var(--ink-muted);
    outline: none;
  }
</style>
