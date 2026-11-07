# Media seek

Status: planned. This feature has not been built yet, and it is the riskiest part of the project.

The bottom edge seeks through the media that is playing. You touch the strip, slide sideways, and release.

## Behavior

- Seeking is relative to the current position, so a slide starts from where the media already is.
- A dead zone must be crossed before the preview appears. It is 2.5% of the pad width in click mode, and 4% and 0.08 seconds in touch mode.
- The full width of the pad equals the full length of the track.
- Nothing changes in the player until you release. An overlay shows the target time, the total time, and a progress bar.
- Canceling a slide leaves the player unchanged.

## Implementation notes

Apple has blocked third-party apps from using `MediaRemote` directly since macOS 15.4, so the first choice is a Now Playing workaround that reaches most players. That workaround has not been verified on macOS 27, and an update could break it.

If it fails testing, seeking falls back to Music and Spotify through AppleScript. That fallback cannot seek video in browsers, and macOS asks for Automation permission once per app.

## Haptics

A haptic can fire when the preview appears. See [haptics.md](haptics.md).

## Related docs

- [gestures.md](gestures.md) describes how a slide starts and ends.
- [settings.md](settings.md) describes sensitivity and the other slide options.
