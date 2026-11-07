# Palm detection

Status: this feature is built, using measurements from the phase 0 test session, but it has not been confirmed on the trackpad yet.

A contact counts as a palm at a size of 1.6 or more, or at a long axis of 13 or more with a size of 1.2 or more. A firm click flattens a finger to about 1.3 in size, and three-finger gestures have long axes with small sizes, so neither of those counts.

## Goal

A resting palm should never start a slide or freeze the pointer. Today a palm alone in a strip counts as a finger, and a palm beside a finger counts as a second finger.

## Behavior

- A contact larger than a threshold is treated as a palm and ignored.
- A palm does not start a gesture, and it does not cancel a finger's gesture.
- A finger that rests flat stays a finger as long as it is under the threshold.

## Settings

No setting is needed, because the measurements separate a flat finger from a palm cleanly.

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
