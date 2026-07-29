#!/usr/bin/env bun
// Flip the current pane and one neighbor between side-by-side and stacked orientation.
// Algorithm: split the current pane in the opposite orientation (throwaway pane),
// swap that throwaway into the neighbor's slot, then close the throwaway — this
// relocates the neighbor's live terminal/agent into the new orientation without
// killing or restarting its process.

const herdr = (...args: string[]) => {
  const proc = Bun.spawnSync(["herdr", ...args]);
  const out = proc.stdout.toString().trim();
  if (proc.exitCode !== 0) {
    console.error(out || proc.stderr.toString());
    process.exit(proc.exitCode ?? 1);
  }
  return out ? JSON.parse(out) : null;
};

const layoutRes = herdr("pane", "layout", "--current");
const layout = layoutRes.result.layout;
const currentId: string = layout.focused_pane_id;

if (layout.panes.length < 2) {
  console.error("pane-rotate: need at least 2 panes in this tab");
  process.exit(1);
}

function findNeighbor(dir: string): string | null {
  const res = herdr("pane", "neighbor", "--direction", dir, "--pane", currentId);
  return res?.result?.neighbor?.neighbor_pane_id ?? null;
}

let neighborDir = "right";
let neighborId = findNeighbor("right");
if (!neighborId) {
  neighborDir = "down";
  neighborId = findNeighbor("down");
}
if (!neighborId) {
  neighborDir = "left";
  neighborId = findNeighbor("left");
}
if (!neighborId) {
  neighborDir = "up";
  neighborId = findNeighbor("up");
}
if (!neighborId) {
  console.error("pane-rotate: no neighbor pane found");
  process.exit(1);
}

const splitDir = neighborDir === "right" || neighborDir === "left" ? "down" : "right";

const splitRes = herdr("pane", "split", "--pane", currentId, "--direction", splitDir, "--ratio", "0.5", "--no-focus");
const throwawayId: string = splitRes.result.pane.pane_id;

herdr("pane", "swap", "--source-pane", throwawayId, "--target-pane", neighborId);
herdr("pane", "close", throwawayId);

console.log(`pane-rotate: flipped ${currentId} <-> ${neighborId} to ${splitDir}`);
