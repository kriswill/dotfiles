<script lang="ts">
  import type { ConceptNode, ConceptTree } from "./data";
  import { encodeHash } from "./hash";
  import type { VizState } from "./state.svelte";

  const { viz }: { viz: VizState } = $props();

  const focusedId = $derived(viz.focusedConcept?.id ?? null);

  let nav: HTMLElement | null = $state(null);
  $effect(() => {
    if (!focusedId || !nav) return;
    nav.querySelector(`a[data-id="${focusedId}"]`)?.scrollIntoView({ block: "nearest" });
  });
</script>

{#snippet row(n: ConceptNode)}
  <a
    href="#{encodeHash({ kind: 'concept', id: n.id })}"
    data-id={n.id}
    class:selected={n.id === focusedId}
    aria-current={n.id === focusedId ? "true" : undefined}
    onclick={(e) => {
      e.preventDefault();
      viz.selectConcept(n.id, true);
    }}><span class="dot"></span>{n.title}</a
  >
{/snippet}

{#snippet branch(t: ConceptTree)}
  <div class="tnode" style="--dot:{viz.colorOf(t.node.type)}">
    {@render row(t.node)}
    {#if t.children.length}
      <div class="kids">
        {#each t.children as c (c.node.id)}{@render branch(c)}{/each}
      </div>
    {/if}
  </div>
{/snippet}

<nav id="list" bind:this={nav}>
  {#if viz.listing.tree}
    {@render branch(viz.listing.tree)}
    {#if viz.listing.rest.length}<div class="tree-divider"></div>{/if}
  {/if}
  {#each viz.listing.rest as n (n.id)}
    <div class="tnode" style="--dot:{viz.colorOf(n.type)}">{@render row(n)}</div>
  {/each}
  {#if viz.hiddenMatchCount > 0}
    <button class="hidden-note" onclick={() => viz.showAllTypes()}>
      +{viz.hiddenMatchCount}
      {viz.hiddenMatchCount === 1 ? "match" : "matches"} hidden by type filters — show all
    </button>
  {/if}
</nav>

<style>
  #list {
    margin-top: 14px;
    border-top: 1px solid var(--grid);
    padding-top: 10px;
    /* Connector geometry: dot center sits at x=8px (4px link padding + half
       of the 8px dot) and y=12px (3px padding + half the 18px line box). */
    --railw: 1.5px;
    --indent: 14px;
    --dotx: 8px;
    --rowy: 12px;
  }
  #list a {
    display: block;
    padding: 3px 4px;
    border-radius: 5px;
    color: var(--ink-2);
    text-decoration: none;
    font-size: 13px;
    line-height: 18px;
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
    background: var(--dot);
  }
  .tnode {
    position: relative;
  }
  .kids {
    position: relative;
    padding-left: var(--indent);
  }
  /* Curved elbow from the rail into this row's dot, in the row's own color.
     Pseudos live on the wrapper, not the <a>, whose overflow:hidden (for
     ellipsis) would clip them. */
  .kids > .tnode::before {
    content: "";
    position: absolute;
    pointer-events: none;
    left: calc(var(--dotx) - var(--indent));
    top: 0;
    width: calc(var(--indent) - var(--dotx));
    height: var(--rowy);
    border-left: var(--railw) solid var(--dot);
    border-bottom: var(--railw) solid var(--dot);
    border-bottom-left-radius: 6px;
  }
  /* Rail continuing to later siblings, tinted by the row it passes; spans
     nested subtrees automatically because the wrapper contains them. */
  .kids > .tnode:not(:last-child)::after {
    content: "";
    position: absolute;
    pointer-events: none;
    left: calc(var(--dotx) - var(--indent));
    top: var(--rowy);
    bottom: 0;
    border-left: var(--railw) solid color-mix(in srgb, var(--dot) 45%, var(--grid));
  }
  /* Stub bridging the parent's dot down to the first child's elbow
     (inherits the parent wrapper's --dot). */
  .kids::before {
    content: "";
    position: absolute;
    pointer-events: none;
    left: var(--dotx);
    top: -8px;
    height: 8px;
    border-left: var(--railw) solid color-mix(in srgb, var(--dot) 45%, var(--grid));
  }
  .tree-divider {
    border-top: 1px solid var(--grid);
    margin: 8px 2px 6px;
  }
  .hidden-note {
    display: block;
    width: 100%;
    padding: 4px;
    font: inherit;
    font-size: 12px;
    text-align: left;
    color: var(--ink-muted);
    background: none;
    border: none;
    border-radius: 5px;
    cursor: pointer;
  }
  .hidden-note:hover {
    background: var(--page);
    color: var(--ink-1);
  }
</style>
