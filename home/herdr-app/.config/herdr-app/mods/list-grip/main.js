// list-grip: a small pill that marks a draggable boundary between two sidebar
// lists, which the borderless theme otherwise leaves invisible.
//
// It only draws; the resizing is Herdr's own boundary drag. A mod can't draw
// outside its block, so the pill is two copies: the `personal` layout ends the
// upper list's column with `{ "half": "top" }` and starts the lower one's with
// `{ "half": "bottom" }`. Each draws half the pill against the shared edge, so
// the boundary runs through the pill's middle and the pointer grabs it there.

import { View, div } from "gpui-kit";
import { h_flex } from "gpui-base";
import { theme, props } from "herdr";

const HALF = 2; // px: half the pill's thickness

export default class ListGrip extends View {
  render() {
    const t = theme();
    const top = props()?.half === "top";
    const half = div().w(28).h(HALF).flex_none().bg(t.input); // not t.border: the theme blanks it
    return h_flex()
      .id("root")
      .size_full()
      .bg(t.chrome)
      .justify_center()
      .when(top, (el) => el.items_end())
      .when(!top, (el) => el.items_start())
      .child(top ? half.rounded_t(HALF) : half.rounded_b(HALF));
  }
}
