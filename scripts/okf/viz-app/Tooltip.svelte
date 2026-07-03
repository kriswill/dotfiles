<script lang="ts">
  import type { VizState } from "./state.svelte";

  const { viz }: { viz: VizState } = $props();
</script>

{#if viz.hover}
  {@const n = viz.model.nodes[viz.hover.i]}
  <div id="tip" style="left:{viz.hover.x}px; top:{viz.hover.y}px">
    <b>{n.title}</b><span class="t">{n.type}</span>
    <div class="d">{n.desc}</div>
  </div>
{/if}

<style>
  #tip {
    position: absolute;
    pointer-events: none;
    max-width: 320px;
    background: var(--surface-1);
    border: 1px solid var(--grid);
    border-radius: 8px;
    padding: 8px 10px;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.12);
    z-index: 3;
  }
  #tip b {
    display: block;
  }
  #tip .t {
    color: var(--ink-muted);
    font-size: 12px;
  }
  #tip .d {
    color: var(--ink-2);
    font-size: 12px;
    margin-top: 3px;
  }
</style>
