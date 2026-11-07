# Two-finger edge slides

Status: this feature is built, unit tested, and confirmed working.

## Goal

Each edge should hold a second action for a two-finger slide, such as one finger for volume and two for brightness.

## Behavior

- A two-finger slide starts only when both fingers land inside the same strip.
- Two fingers that land anywhere else stay an ordinary scroll or system gesture.
- The fingers count as one position, using their midpoint.
- The feature is off for an edge until you assign a second action.

## Settings

The Edges pane has a **Two-finger slides** section with one popup for each edge.

## How it works

1. `GestureEngine` records the strip where each contact landed. A two-finger slide starts only when both fingers landed in the same strip within 0.15 seconds, so fingers that slide into a strip do not count. If one finger already started a slide that has done nothing yet, that slide gives way.
2. The midpoint of the fingers drives the existing step logic. Each finger is also checked for a contact glitch on its own, because the midpoint would hide half of one.
3. The pointer freeze drops scroll events during the slide, so that macOS does not scroll as well.
4. A two-finger slide starts on touch even in click mode, because a two-finger click is a secondary click.
5. One finger leaving starts the lift grace, so a brief loss of contact does not end the slide. A lost contact may return as a new finger, but only close to where the pair was. Any other new finger ends the slide.
6. If a slide changed something, the pointer stays frozen until the fingers of that motion lift. A slide that changed nothing releases the pointer at once.
7. The settings are optional stored values, so saved settings still load. They are set on the Edges pane only, and not from the menu bar item.

## Risks

- This can collide with two-finger scrolling and system gestures, because macOS reads the same touches. The feature is off for each edge until you assign it, and a scroll that coasts on after the fingers lift can still reach the app under the pointer.
- A firm press during a slide can still produce a secondary click, and a pinch in a strip can still reach apps, because neither passes through the pointer freeze. Both need a check on the trackpad.
- A palm that first looks like a finger can count as a second finger until it is recognized.
- The strip is narrow, so two fingers may be hard to place in it. Testing may show that the strip needs to be wider for this gesture.

## Verification

- Unit tests cover landing, midpoint travel, glitches, returning contacts, new fingers, clicks, palms, and when the pointer is released.
- On the trackpad, two-finger scrolling near an edge still works normally.

## Related docs

- [gestures.md](../gestures.md) describes multi-finger handling today.
- [palm-detection.md](palm-detection.md) describes how a palm is recognized.
