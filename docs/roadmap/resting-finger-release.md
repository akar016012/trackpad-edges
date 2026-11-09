# Release a resting finger

Status: this feature is planned, and none of it is built yet.

## Goal

A finger that lands in a strip and stays still should give the pointer back. Today the pointer stays frozen until that finger leaves, which is one of the known limits in [plan.md](../plan.md). A thumb that rests on the bottom edge is the most common case.

## Behavior

- If a finger lands in a strip and does not start a slide within 0.6 seconds, the landing is dropped and the pointer moves again.
- After that, the same finger works as an ordinary pointer finger, and it cannot start a slide until it lifts and lands again.
- A slide that has already started is never released this way, however slowly it moves.
- A click that arrived during the wait still goes through as it does today, so nothing is lost.
- A finger that drifts slowly without passing the 4% travel needed to start a slide counts as resting.

## Settings

The first version has no setting, and the 0.6 second wait is a constant. A setting can come later if testing shows that people need a different wait.

## Implementation plan

1. Give the landing in `GestureEngine` the time that it began, which the engine already knows from `firstContactAt`.
2. In `tick`, drop a landing that has not engaged after the wait, and emit `pointerReleased`.
3. Remember the dropped contact's ID until it lifts, so that it cannot start a slide later.
4. Check how [click mode](../gestures.md) freezes the pointer, and decide whether the same rule applies there before building it.
5. Remove the limit from the known limits in [plan.md](../plan.md) once it is confirmed.

## Risks

- A person who lands, pauses, and then slides would lose that slide. The wait should be measured with real slides, because 0.6 seconds is only a first guess.
- Releasing the pointer while the finger is still down could make the pointer jump if the freeze keeps a separate position. The release must start from where the pointer was frozen.

## Verification

- Unit tests cover a resting finger, a slow real slide, a finger that rests and then slides, and a click during the wait.
- On the trackpad, a thumb that rests on the bottom edge no longer blocks the pointer, and quick slides still start as before.

## Related docs

- [gestures.md](../gestures.md) describes how a slide starts.
- [pointer-freeze.md](../pointer-freeze.md) describes the freeze and click handling.
- [palm-detection.md](palm-detection.md) handles the larger contact of a palm.
