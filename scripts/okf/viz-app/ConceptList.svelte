<script lang="ts">
  import { encodeHash } from "./hash";
  import type { VizState } from "./state.svelte";

  const { viz }: { viz: VizState } = $props();

  // The focused concept: the selected one, or the referrer while a file view
  // is open (matches the scene's emphasis).
  const focusedId = $derived((viz.selectedConcept ?? viz.backConcept)?.id ?? null);

  let nav: HTMLElement | null = $state(null);
  $effect(() => {
    if (!focusedId || !nav) return;
    nav.querySelector(`a[data-id="${focusedId}"]`)?.scrollIntoView({ block: "nearest" });
  });
</script>

<nav id="list" bind:this={nav}>
  {#each viz.visibleSorted as n (n.id)}
    <a
      href="#{encodeHash({ kind: 'concept', id: n.id })}"
      data-id={n.id}
      class:selected={n.id === focusedId}
      aria-current={n.id === focusedId ? "true" : undefined}
      onclick={(e) => {
        e.preventDefault();
        viz.selectConcept(n.id, true);
      }}><span class="dot" style="background:{viz.colorOf(n.type)}"></span>{n.title}</a
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
  #list a.selected {
    background: var(--page);
    color: var(--ink-1);
    font-weight: 600;
  }
  #list a.selected .dot {
    box-shadow: 0 0 0 2px color-mix(in srgb, var(--ink-1) 40%, transparent);
  }
  .dot {
    display: inline-block;
    width: 8px;
    height: 8px;
    border-radius: 50%;
    margin-right: 7px;
    vertical-align: 1px;
  }
</style>
