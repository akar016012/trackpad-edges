# Volume

Status: this feature is built and confirmed working on the built-in trackpad, including touch-to-start, the pointer freeze, haptic ticks, and taps that leave the volume alone. Quarter steps have not been confirmed yet.

The right edge controls system volume by default, and [settings.md](settings.md) describes how to reassign it. You touch the strip and slide up to raise the volume or down to lower it.

## Behavior

- Volume moves in 16 steps, which match the volume keys.
- One step takes 3.5% of the pad height at the default sensitivity, so a full sweep takes about 56% of the pad height. Touch mode adds 4% of travel before the first step.
- Steps are relative to the level when the slide began, and the level stays between 0 and 16.
- A tap in the strip never changes the volume, because a touch must travel 4% of the pad before steps begin.
- Reversing direction during a slide works.
- Holding Shift+Option during a slide gives quarter steps, as it does on the keyboard.
- The native macOS volume indicator appears, because the app presses the volume keys on your behalf.

## Implementation notes

`VolumeController` posts `.systemDefined` media key events at `.cghidEventTap` through `MediaKeys`, which requires the Accessibility permission. The current level is read through CoreAudio so that the app knows when it has reached a limit.

## Haptics

Each step fires a haptic, and reaching 0 or the maximum can fire a distinct one. See [haptics.md](haptics.md).

## Related docs

- [gestures.md](gestures.md) describes how a slide starts and ends.
- [settings.md](settings.md) describes edge assignment and sensitivity.
