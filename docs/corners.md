# Corners

Status: the corners, their actions, light presses, and the shortcut recorder are built and confirmed working on the built-in trackpad.

All four corners respond to 1 to 4 clicks. A corner with no action stays a normal part of the trackpad, and so does a corner whose action is not finished, such as Press Keys with nothing recorded.

## Actions

Each corner can do one of these things:

- It can mute or unmute the sound.
- It can play or pause media, or skip to the next or previous track, in whichever app is playing.
- It can open an app, and clicking again hides that app.
- It can open an `http` or `https` link in a browser you choose.
- It can open a file or a folder.
- It can press any key combination, including ones that macOS normally keeps for itself, such as Command-Space and Command-Tab, and modifiers alone, including fn. While you record, an event tap sees keys before macOS does and holds them back, so the shortcut does not also run. Escape cancels recording, so Escape itself cannot be recorded. The recorder keeps the exact side of each modifier, so `Right ⌘ Space` sends the right Command key. A shortcut recorded before this existed sends the left key.
- It can run a shortcut from the Shortcuts app in the background.

## Click counting

A light press fires a corner, with no physical click needed, and a haptic confirms each press. The **Press** slider on the Corners pane sets how light. A physical click also counts, and it never counts twice with a press. Each corner has a click count from 1 to 4. Presses must fall within 450 ms of each other. Earlier clicks only count, and the action fires on the last one. Clicks in a corner that has an action never reach other apps, even if the count is not reached.

## Defaults

The top-left corner mutes by default, and the other corners have no action until you choose one. A bottom corner with an action takes over that part of the bottom strip and the lowest part of the side strip beside it, and a bottom corner with no action leaves the strips as they were.

## Implementation notes

Apps are opened through `NSWorkspace`, and key combinations are synthesized with `CGEvent`, which requires the Accessibility permission. Synthesized events are marked so that the app's own event tap ignores them.

## Haptics

A haptic can fire when a corner action runs. See [haptics.md](haptics.md).

## Related docs

- [settings.md](settings.md) describes the per-corner options.
- [pointer-freeze.md](pointer-freeze.md) describes how corner clicks are kept out of other apps.
