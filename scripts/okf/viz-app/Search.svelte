<script lang="ts">
  import type { VizState } from "./state.svelte";

  const { viz }: { viz: VizState } = $props();
</script>

<input id="q" type="search" placeholder="Search concepts…" aria-label="Search concepts" bind:value={viz.query} />

<style>
  #q {
    width: 100%;
    padding: 6px 8px;
    font: inherit;
    color: inherit;
    background: var(--page);
    border: 1px solid var(--baseline);
    border-radius: 6px;
    margin-bottom: 12px;
  }
</style>
