# Corners

Status: the click counting, every action, and the Corners pane are built, but they have not been confirmed on hardware yet.

The top-left and top-right corners respond to 1 to 4 clicks. A corner with no action stays a normal part of the trackpad, and so does a corner whose action is not finished, such as Press Keys with nothing recorded.

## Actions

Each corner can do one of these things:

- It can mute or unmute the sound.
- It can play or pause media, or skip to the next or previous track, in whichever app is playing.
- It can open an app, and clicking again hides that app.
- It can open an `http` or `https` link in a browser you choose.
- It can open a file or a folder.
- It can press a key combination, such as a screenshot shortcut.
- It can run a shortcut from the Shortcuts app in the background.

## Click counting

Each corner has a click count from 1 to 4. Clicks must fall within 450 ms of each other. Earlier clicks only count, and the action fires on the last one. Clicks in a corner that has an action never reach other apps, even if the count is not reached.

## Defaults

The top-left corner mutes by default, and the top-right corner has no action until you choose one.

## Implementation notes

Apps are opened through `NSWorkspace`, and key combinations are synthesized with `CGEvent`, which requires the Accessibility permission. Synthesized events are marked so that the app's own event tap ignores them.

## Haptics

A haptic can fire when a corner action runs. See [haptics.md](haptics.md).

## Related docs

- [settings.md](settings.md) describes the per-corner options.
- [pointer-freeze.md](pointer-freeze.md) describes how corner clicks are kept out of other apps.
