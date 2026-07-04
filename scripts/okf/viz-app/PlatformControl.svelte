<script lang="ts">
  import type { VizState } from "./state.svelte";

  const { viz }: { viz: VizState } = $props();
</script>

<div id="platform">
  <span class="hint">platform</span>
  <button class="seg" class:active={viz.platform === "all"} onclick={() => viz.setPlatform("all")}>all</button>
  <button class="seg" class:active={viz.platform === "darwin"} onclick={() => viz.setPlatform("darwin")}>darwin</button>
  <button class="seg" class:active={viz.platform === "nixos"} onclick={() => viz.setPlatform("nixos")}>nixos</button>
</div>

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
