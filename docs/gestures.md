# Gestures

Status: touch slides on the left, right, and bottom edges and the corners are confirmed working on the built-in trackpad. The top edge, click mode, and palm detection are built and unit tested, but they have not been confirmed on hardware yet.

## Zones

The trackpad is divided into zones using normalized coordinates, where the origin is the bottom-left corner of the pad.

| Zone             | Default size                        |
| ---------------- | ----------------------------------- |
| Right edge       | 10% of the pad width                |
| Left edge        | 10% of the pad width                |
| Bottom edge      | 10% of the pad height               |
| Top edge         | 10% of the pad height               |
| Top-left corner  | 20% of the width, 17% of the height |
| Top-right corner | 20% of the width, 17% of the height |
| Bottom corners   | 20% of the width, 17% of the height |

Zones are tested in this order: corners, top edge, bottom edge, left edge, then right edge. A corner counts only if it has an action, so the top and bottom strips otherwise span the full width of the pad. The top edge is off until you assign it.

## Starting a slide

By default, a slide starts as soon as one finger lands inside a strip. A finger that lands elsewhere and moves into a strip does nothing, which keeps ordinary trackpad use undisturbed. The trade-off is that the pointer does not move while a finger that landed in a strip stays there.

The **Require a click to start** setting matches a similar app: the finger must land in the strip and then click. Testing showed that a light touch at the edge produces no click at all, so this mode needs a firm press.

The pointer freezes at landing, but a touch counts as a slide only after the finger has been down for 0.08 seconds and has traveled 4% of the pad, mostly along the strip. Steps count from that point, so a tap does not change a level. A move of more than 12% of the pad between two frames is treated as a contact glitch and ignored, because the reported position can jump near the rim.

## Ending a slide

- Lifting the finger ends the slide, so easing off the click during a slide does not stop it.
- Contact can drop out near the rim of the pad, which was seen about every 0.2 seconds in testing. A slide therefore survives a gap of up to 0.18 seconds, and wherever the contact returns in the strip produces no steps. A contact that returns outside the strip, or with a second finger, ends the slide and starts fresh.
- Leaving the strip by more than 3% of the pad cancels a slide that has not changed anything yet. Once a slide has changed something, it can stray a further 25% of the pad, because a real slide drifts. A second finger cancels a slide at any time.
- Volume and brightness steps that were already applied stay applied after a cancel.
- A click with no slide passes through to macOS as a normal click when you release it.

## What is ignored

Multi-finger gestures and ordinary pointer movement never start a slide, and a finger that moves into a strip does not count. A palm is recognized from its size and shape, and it does not start a gesture. A palm that is already full size does not cancel one either, although a palm that first looks like a finger can cancel a slide before it is recognized. Corners fire on pressure, so a tap does not normally reach them, although a tap with tap-to-click can still count as a click.

A contact counts as lifted if no touch data arrives for 0.25 seconds, because the framework can drop the final frame. Gestures stop while the screen is locked.

## Multiple trackpads

Each trackpad has its own gesture state, because mixing devices would report doubled fingers. When two trackpads are connected, a trackpad with a gesture in progress owns the next click. Otherwise, a click goes to the first trackpad with a finger resting in a zone, because click events do not say which trackpad they came from. A click from a separate mouse can be captured the same way while a finger rests in a zone. Apple touch mouse devices also report touches, so the app skips them. Trackpads are rebuilt after one connects or disconnects and after the Mac wakes.

## Related docs

- [pointer-freeze.md](pointer-freeze.md) explains click handling during a slide.
- [settings.md](settings.md) lists the options that change zone sizes and the start rule.
