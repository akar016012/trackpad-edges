# Two-finger edge slides

Status: this feature is planned for phase 4. This feature depends on palm detection, because a palm must not count as a second finger.

## Goal

Each edge should hold a second action for a two-finger slide, such as one finger for volume and two for brightness.

## Behavior

- A two-finger slide starts only when both fingers land inside the same strip.
- Two fingers that land anywhere else stay an ordinary scroll or system gesture.
- The fingers count as one position, using their midpoint.
- The feature is off for an edge until you assign a second action.

## Settings

The Edges pane gains a second action for each edge, and it keeps the same aligned rows.

## Implementation plan

1. Let `GestureEngine` record a two-finger landing, and require both contacts to land in the strip within a short window.
2. Track the midpoint, so that the existing step logic works unchanged.
3. Keep the pointer freeze for the slide, and also drop scroll events during it.
4. Add the setting as an optional stored value, so that saved settings still load.

## Risks

- This can collide with two-finger scrolling and system gestures, because macOS reads the same touches. If a scroll still leaks through, the feature becomes opt-in for each edge.
- The strip is narrow, so two fingers may be hard to place in it. Testing may show that the strip needs to be wider for this gesture.

## Verification

- Unit tests cover landing, midpoint travel, and a second finger that lands outside the strip.
- On the trackpad, two-finger scrolling near an edge still works normally.

## Related docs

- [gestures.md](../gestures.md) describes multi-finger handling today.
- [palm-detection.md](palm-detection.md) must be finished first.
