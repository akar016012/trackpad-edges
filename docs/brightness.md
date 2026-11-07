# Brightness

Status: this feature is built, but it has not been confirmed on hardware yet.

The left edge controls the brightness of the built-in display by default. It uses the same slide motion as [volume](volume.md).

## Behavior

- Brightness moves in 16 steps, which match the brightness keys.
- Holding Shift+Option during a slide gives quarter steps.
- The native macOS brightness indicator appears, because the app presses the brightness keys on your behalf.
- The edge stays off when no built-in display is active, such as on a closed MacBook. The app rechecks this whenever the displays change.

External display brightness is out of scope for the first version.

## Implementation notes

`BrightnessController` posts `.systemDefined` brightness key events, which requires the Accessibility permission. It reads the current level through the private `DisplayServices` API so that it knows when it has reached a limit.

## Haptics

Each step fires a haptic, and reaching a limit can fire a distinct one. See [haptics.md](haptics.md).

## Related docs

- [gestures.md](gestures.md) describes how a slide starts and ends.
- [settings.md](settings.md) describes swap sides and sensitivity.
