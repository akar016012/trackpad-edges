# Brightness

Status: this feature is built and confirmed working on the built-in trackpad, including with the pointer on an external monitor that a monitor utility controls.

The left edge presses the brightness keys by default, which controls the built-in display. It uses the same slide motion as [volume](volume.md).

## Behavior

- Brightness moves in 16 steps, which match the brightness keys.
- Holding Shift+Option during a slide gives quarter steps.
- The native macOS brightness indicator appears, because the app presses the brightness keys on your behalf.
- The edge stays off when no built-in display is active, such as on a closed MacBook. The app rechecks this whenever the displays change.

A monitor utility can send the brightness keys to the display under the pointer. The app can read only the built-in display's level, so it always presses the key, and it reports a limit only when the pointer is on the built-in display. The separate [Monitor Brightness](roadmap/more-edge-actions.md) action talks to a monitor directly.

## Implementation notes

`BrightnessController` posts `.systemDefined` brightness key events, which requires the Accessibility permission. It reads the built-in level through the private `DisplayServices` API, which decides when the limit haptic fires.

## Haptics

Each step fires a haptic, and reaching a limit can fire a distinct one. See [haptics.md](haptics.md).

## Related docs

- [gestures.md](gestures.md) describes how a slide starts and ends.
- [settings.md](settings.md) describes edge assignment and sensitivity.
