<script lang="ts">
  import type { VizState } from "./state.svelte";

  const { viz }: { viz: VizState } = $props();
</script>

{#if viz.model.platforms.length}
  <div id="platform">
    <span class="hint">platform</span>
    {#each ["all", ...viz.model.platforms] as p (p)}
      <button class="seg" class:active={viz.platform === p} onclick={() => viz.setPlatform(p)}>{p}</button>
    {/each}
  </div>
{/if}

<style>
  /* .hint / .seg are global primitives (viz.ts) shared with the other controls. */
  #platform {
    display: flex;
    align-items: center;
    gap: 5px;
    padding: 6px 4px;
    margin-bottom: 6px;
    border-top: 1px solid var(--grid);
  }
</style>
