# Palm detection

Status: this feature is planned for phase 1. This feature waits on contact size measurements from the phase 0 test session.

## Goal

A resting palm should never start a slide or freeze the pointer. Today a palm alone in a strip counts as a finger, and a palm beside a finger counts as a second finger.

## Behavior

- A contact larger than a threshold is treated as a palm and ignored.
- A palm does not start a gesture, and it does not cancel a finger's gesture.
- A finger that rests flat stays a finger as long as it is under the threshold.

## Settings

No setting is planned. If the measurements cannot separate a flat finger from a palm cleanly, a **Palm sensitivity** slider goes on the Edges pane.

## Implementation plan

1. Read contact size and major axis from the touch record, which `TouchPoint` already does.
2. Filter palms out in `GestureEngine.process`, before any gesture logic sees the touches.
3. Decide once per contact, and keep that decision until the contact lifts, so that a growing palm cannot flip back and forth.

## Risks

- A palm can begin as a small contact, so the first frames may look like a finger. The settle time of 0.08 seconds gives the size time to grow before a slide counts.
- A flat thumb may overlap with a small palm.

## Verification

- Unit tests cover palm filtering, a palm beside a finger, and a contact that grows into a palm.
- On the trackpad, typing with palms resting on the pad never freezes the pointer.

## Related docs

- [gestures.md](../gestures.md) describes what is ignored today.
- [lighter-corner-presses.md](lighter-corner-presses.md) uses the same measurements.
