# Media seek

Status: this feature is built and confirmed working on the built-in trackpad on macOS 27.2.

The bottom edge seeks through the media that is playing. You touch the strip, slide sideways, and release.

## Behavior

- Seeking is relative to the current position, so a slide starts from where the media already is.
- A dead zone must be crossed before the preview appears. It is 2.5% of the pad width in click mode, and 4% and 0.08 seconds in touch mode.
- Seeking moves in fixed steps, as volume does. One step takes 5% of the pad width at the default sensitivity, which is about 8 mm on this Mac's trackpad, and each step gives one haptic tick. The Sensitivity setting changes that travel, as it does for volume and brightness.
- Each step moves a chosen percentage of the track. You set this from 0.5% to 10% in the Media pane, and the default is 1%, so a step moves 6 seconds of a 10-minute video.
- Finger speed has no effect, so the same slide always moves the same amount.
- The preview stops at the start and just before the end of the track, because some players skip to the next track at the very end. Travel past those limits is forgotten, so reversing responds within about a step or two of travel.
- A slide that returns to where it began does not seek.
- A slide tolerates drift once it has started, so it can stray up to 25% of the pad past the strip without canceling.
- Nothing changes in the player until you lift your finger. An overlay shows the target time, the total time, a progress bar, and the percentage change.
- Canceling a slide leaves the player unchanged. Lifting before the position has loaded still seeks once it loads.
- The overlay says so when nothing is playing.
- A bottom corner with an action takes over that part of the strip.

## Implementation notes

Apple has blocked third-party apps from using `MediaRemote` directly since macOS 15.4, and no public Swift or AppKit API can read or seek another app's playback. The system's own `/usr/bin/perl` can still reach it, so the app uses the third-party `mediaremote-adapter` project, pinned to v0.7.7 at upstream commit `e3ff502`. A macOS update could break this, because it relies on undocumented behavior.

- `NowPlayingAdapter` runs Perl as a child process and reads JSON from it. Each call has a two-second limit.
- The child process very likely inherits the app's Accessibility permission, and the unpacked library sits in a folder that anything running as you can write to. So the app gives Perl a clean environment, and it checks the library's bytes against the bundled copy before each call. A signed build that keeps the library inside the app would be stronger.
- `SeekController` reads the position only after a slide starts moving, so an ordinary touch on the strip never starts a process.
- `SeekScrubber` turns finger travel into whole steps, and unit tests cover it.
- `SeekOverlayPanel` shows the preview, and it never takes focus or receives clicks. It uses `NSGlassEffectView` for the two glass styles, and `NSVisualEffectView` with a mask image for the frosted style, because a layer's corner radius does not round a material that draws behind the window. Its bar is a custom view with no animation, so it snaps to each step in time with the haptic tick.

### Updating the adapter

The adapter's source is in `Vendor/mediaremote-adapter`, and its script is copied unchanged to `Resources/mediaremote-adapter.pl`. Xcode treats any compiled binary in the resources folder as something to link and leaves it out of the app, so the library ships as base64 text in `Resources/MediaRemoteAdapter.base64`. The app unpacks it into `~/Library/Application Support/Trackpad Edges/MediaRemoteAdapter.framework` on launch.

To update it, build the framework from the vendored source with `cmake`, encode its binary with `base64`, and replace those two resource files.

## Haptics

A haptic can fire when the preview first appears and on each step, so you can feel the distance. See [haptics.md](haptics.md).

## Related docs

- [gestures.md](gestures.md) describes how a slide starts and ends.
- [settings.md](settings.md) describes the Media pane.
- [dependencies.md](dependencies.md) lists the adapter and its license.
