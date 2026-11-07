# Top edge

Status: this feature is built and unit tested, but it has not been confirmed on the trackpad yet.

## Goal

The top edge should become a fourth assignable strip between the top corners, so that all four sides can be used.

## Behavior

- The top strip works like the bottom strip, and a slide runs along the width of the pad.
- A top corner with an action takes over its part of the strip.
- The top strip is off by default.

## Settings

The Edges pane and the menu bar item gain a **Top edge** choice, and the diagram draws the strip.

## Implementation plan

1. Add `top` to `Zone`, and add `topAction` to `GestureConfig`.
2. Test the top strip after the corners and before the side strips, and treat it like the bottom strip for travel.
3. Add the setting as an optional stored value, so that saved settings still load.
4. Add the row to `EdgesPane`, and draw it in `TrackpadDiagramView`.

## Risks

- A top strip shrinks the room for ordinary pointer starts, which is why it stays off by default.

## Verification

- Unit tests cover zone priority and travel along the top strip.
- On the trackpad, the top strip works with and without top corner actions.

## Related docs

- [gestures.md](../gestures.md) describes the zones today.
