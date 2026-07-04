<script lang="ts">
  import type { VizState } from "./state.svelte";

  const { viz }: { viz: VizState } = $props();
</script>

{#if viz.selectedConcept}
  <div id="isolate">
    <span class="hint">neighbors</span>
    <button
      class="seg"
      class:active={viz.isolateDepth === 1}
      onclick={() => viz.setIsolate(viz.isolateDepth === 1 ? 0 : 1)}
    >
      1-hop
    </button>
    <button
      class="seg"
      class:active={viz.isolateDepth === 2}
      onclick={() => viz.setIsolate(viz.isolateDepth === 2 ? 0 : 2)}
    >
      2-hop
    </button>
    <button class="seg" class:active={viz.isolateDepth === 0} onclick={() => viz.setIsolate(0)}>off</button>
  </div>
{/if}

<style>
  #isolate {
    display: flex;
    align-items: center;
    gap: 5px;
    padding: 6px 4px;
    margin-bottom: 6px;
    border-top: 1px solid var(--grid);
    border-bottom: 1px solid var(--grid);
  }
  #isolate .hint {
    margin-right: auto;
    color: var(--ink-muted);
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }
  #isolate .seg {
    padding: 2px 6px;
    font: inherit;
    font-size: 12px;
    color: var(--ink-muted);
    background: none;
    border: 1px solid transparent;
    border-radius: 5px;
    cursor: pointer;
  }
  #isolate .seg:hover {
    color: var(--ink-1);
  }
  #isolate .seg.active {
    color: var(--ink-1);
    border-color: var(--grid);
    background: var(--page);
    font-weight: 600;
  }
</style>
