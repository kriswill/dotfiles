<script lang="ts">
  import type { VizState } from "./state.svelte";

  const { viz }: { viz: VizState } = $props();
</script>

<nav id="list">
  {#each viz.visibleSorted as n (n.id)}
    <a
      href="#c/{n.id}"
      onclick={(e) => {
        e.preventDefault();
        viz.selectConcept(n.id, true);
      }}>{n.title}</a
    >
  {/each}
</nav>

<style>
  #list {
    margin-top: 14px;
    border-top: 1px solid var(--grid);
    padding-top: 10px;
  }
  #list a {
    display: block;
    padding: 3px 4px;
    border-radius: 5px;
    color: var(--ink-2);
    text-decoration: none;
    font-size: 13px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  #list a:hover {
    background: var(--page);
    color: var(--ink-1);
  }
</style>
