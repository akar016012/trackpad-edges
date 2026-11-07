# Haptics

Status: haptics are built for steps, limits, and corners, and a tick on each volume step is confirmed working on the built-in trackpad. The settings window for these controls is not built yet.

Haptics let you feel a level change without looking. a similar app offers only a light click on each step, so the controls described here go beyond it.

## Settings

| Setting  | Planned behavior                                                                   |
| -------- | ---------------------------------------------------------------------------------- |
| Haptics  | This switch turns all haptics on or off.                                           |
| Strength | This slider sets how strong each haptic feels.                                     |
| Pattern  | This option chooses the feel of each haptic, such as a light tick or a firm click. |
| Events   | These switches choose which events fire a haptic.                                  |
| Test     | This button fires a haptic with the current settings.                              |

## Events

| Event                          | Default |
| ------------------------------ | ------- |
| Each volume or brightness step | On      |
| Reaching a limit               | On      |
| Corner action                  | On      |
| Seek preview appears           | On      |

## Implementation notes

The app uses the private `MTActuator` API, because Apple's public `NSHapticFeedbackManager` has no strength control. Strength maps to the amplitude argument of `MTActuatorActuate`, and pattern maps to an actuator ID. The final mapping is chosen by feel during hardware testing.

- Haptic calls stay off the touch callback, and they are throttled to one every 20 to 50 ms.
- The private API may bypass the system haptic setting, so the app's own switch matters.
- Opening the actuator may change how normal clicks feel, so the app opens it only at the first haptic of a gesture and closes it when the gesture ends.

## Trackpad support

| Trackpad                    | Expected support                                                                       |
| --------------------------- | -------------------------------------------------------------------------------------- |
| Built-in Force Touch        | Full control is expected, and this is the main test target.                            |
| Rechargeable external Apple trackpad | This is unverified, and some reports suggest haptics may be unreliable over Bluetooth. |
| Original external Apple trackpad     | It has no haptic engine, so haptics are unavailable.                                   |

When only the public API is available, the strength control is disabled and the settings window explains why.

## Related docs

- [settings.md](settings.md) describes where these controls live.
