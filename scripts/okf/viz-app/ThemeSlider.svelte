<script lang="ts">
  import type { VizState } from "./state.svelte";
  import { THEMES } from "./themes";

  const { viz }: { viz: VizState } = $props();
</script>

<footer class="theme-bar">
  <label for="theme-slider">Theme</label>
  <input
    id="theme-slider"
    type="range"
    min="0"
    max={THEMES.length - 1}
    step="1"
    value={viz.themeIndex}
    aria-label="Color theme"
    oninput={(e) => viz.setTheme(+e.currentTarget.value)}
  />
  <span class="name">{THEMES[viz.themeIndex]?.name}</span>
</footer>

<style>
  .theme-bar {
    display: flex;
    align-items: center;
    gap: 8px;
    flex: none;
    padding: 10px 14px;
    border-top: 1px solid var(--grid);
    background: var(--surface-1);
    font-size: 12px;
    color: var(--ink-muted);
  }
  input {
    flex: 1;
    min-width: 0;
    margin: 0;
    accent-color: var(--link);
  }
  .name {
    width: 44px;
    text-align: right;
    color: var(--ink-2);
  }
</style>
