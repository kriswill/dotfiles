// Viewer entry: parse the baked-in #data blob, build the immutable model and
// the reactive state, and mount the Svelte app. Data + layout are baked in by
// flakes/okf/viz.ts.
import { mount } from "svelte";
import App from "./App.svelte";
import { loadFromDom } from "./data";
import { mark } from "./perf";
import { createVizState } from "./state.svelte";

const model = loadFromDom();
mark("viz:parse");

const viz = createVizState(model);
mount(App, { target: document.body, props: { viz } });
mark("viz:mount");
