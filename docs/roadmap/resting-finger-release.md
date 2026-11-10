# Release a resting finger

Status: this feature is built and unit tested, but it has not been tried on a trackpad yet. The 0.6 second wait is a first guess that real slides still have to confirm. It ships in version 1.3.

## Goal

A finger that lands in a strip and stays still should give the pointer back. Before this feature, the pointer stayed frozen until that finger left, which was one of the known limits in [plan.md](../plan.md). A thumb that rests on the bottom edge is the most common case.

## Behavior

- If a finger lands in a strip and does not start a slide within 0.6 seconds, the slide is dropped and the pointer moves again.
- After that, the same finger works as an ordinary pointer finger, and it cannot start a slide until it lifts and lands again.
- A slide that has already started is never released this way, however slowly it moves.
- A click that arrived during the wait still goes through as it did before, so nothing is lost. A click that is still held when the wait ends is delivered at that moment, so a drag can follow it.
- A finger that drifts slowly without passing the 4% travel needed to start a slide counts as resting.
- Two fingers that rest in a strip with a two-finger action are released in the same way.

## Click mode

The rule applies only to a slide that started on touch. With **Require a click to start**, a one-finger slide starts with a physical click, and the pointer is frozen only while the button is down. Releasing the button already ends that freeze, so a resting finger never holds the pointer there. A two-finger slide always starts on touch, so the rule applies to it in both modes.

## Contact that drops out

Contact can drop out near the rim of the pad, and a resting thumb sits at the rim.

- The wait counts from the first landing. A contact that drops out and returns within the 0.18 second grace period does not start the wait over, although it does start the slide's settle time over.
- After the pointer is released, a contact that returns within the grace period and within 12% of the pad from where the finger was is still the rested finger. Without this rule, each gap would freeze the pointer for another wait.
- A finger that lands farther away, or after the grace period, is a new finger and can slide at once.

## Settings

The first version has no setting, and the 0.6 second wait is the constant `restRelease` in `GestureConfig`. A setting can come later if testing shows that people need a different wait.

## How it works

1. A slide remembers when its finger first landed, in `landedAt`, apart from the time that its settle period began.
2. `GestureEngine` checks the wait on every touch frame and in `tick`. When the wait has passed and the slide has not started, it drops the slide and emits `slideCanceled` and `pointerReleased`, and `passthroughClick` if a click is held.
3. The engine remembers the released fingers and where they last were until they lift, and no landing or two-finger slide can start while it does. A palm that stays on the pad does not count as one of them, so it cannot hide a gap in contact.
4. `GestureController` asks the engine how much of the wait remains and sets up one check for that moment on each trackpad. Touch frames normally keep arriving while a finger is down, so this check only makes sure that the pointer comes back on time.
5. `PointerFreeze` puts the pointer back where it was frozen before it lets it move, so the release does not make the pointer jump.

## Risks

- A person who lands, pauses, and then slides loses that slide. The wait should be measured with real slides, because 0.6 seconds is only a first guess.
- A very slow slide that takes longer than 0.6 seconds to travel 4% of the pad never starts.
- A person who lifts a rested finger and lands it again in the same place within 0.18 seconds still has a rested finger, so that landing cannot slide.
- A finger that lands, lifts, and lands again within 0.18 seconds is still the same slide, and its wait counts from the first landing. If that first landing is already 0.6 seconds old, the returning finger is released at once and cannot slide. Before this feature, that finger could still slide.

## Verification

- Unit tests cover a resting finger, a slow drift, a slow real slide, a finger that rests and then slides, a click during the wait, a click held past the wait, a slide that a click started, click mode, a resting pair, and contact that drops out before and after the release, including beside a palm.
- On the trackpad, a thumb that rests on the bottom edge should no longer block the pointer, and quick slides should still start as before. This has not been tried yet.
- The known limit in [plan.md](../plan.md) can be removed once that is confirmed.

## Related docs

- [gestures.md](../gestures.md) describes how a slide starts.
- [pointer-freeze.md](../pointer-freeze.md) describes the freeze and click handling.
- [palm-detection.md](palm-detection.md) handles the larger contact of a palm.
