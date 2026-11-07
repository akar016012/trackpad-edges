# More edge actions

Status: these actions are built and unit tested, but they have not been confirmed on the trackpad yet. External monitor brightness also needs a monitor that answers over DDC.

## Goal

An edge should be able to do more than change volume, change brightness, or seek.

## Behavior

Each new action works in steps with a haptic tick, as volume does. Switch apps and Switch Spaces need three times the travel for each step, because each step jumps a whole app or Space.

| Action                      | What a slide does                                          |
| --------------------------- | ---------------------------------------------------------- |
| Scroll                      | The slide scrolls the window under the pointer up or down. |
| Zoom                        | The slide zooms in and out by pressing the zoom shortcuts. |
| Switch apps                 | Each step moves to the next or previous app.               |
| Switch Spaces               | Each step moves one Space left or right.                   |
| Keyboard backlight          | Each step changes the keyboard backlight.                  |
| External monitor brightness | Each step changes the brightness of an external display.   |

## Settings

The edge popups on the Edges pane and in the menu bar item list the new actions. An action that cannot work right now is dimmed, and an edge set to it stays a normal part of the trackpad until it can work.

## How it works

1. `SlideKind` lists every action, and saved values stay compatible.
2. `Actions/EdgeActions.swift` carries out one step of any action, and it calls the same `step` that volume uses.
3. Scrolling is synthesized with `CGEvent`, and it follows the system's scroll direction. A slide along the top or bottom edge also scrolls up and down.
4. Zoom and Switch Spaces press the system's shortcuts through the existing key path. Zoom uses the key positions of a US layout, so it may not zoom on other layouts.
5. Switch apps fixes the list of apps when a slide begins, and it brings each app forward through Accessibility, because macOS ignores a plain activation request from a background app.
6. The keyboard backlight is pressed through its media keys.
7. External displays are reached over DDC with `IOAVServiceWriteI2C`. A display counts only after it answers a read, each display keeps its own level, and a fast slide writes only the newest level.

## Limits

- The keyboard backlight has no public API, and some Macs ignore its media keys, so the action may do nothing even though it is offered.
- DDC varies by monitor and port, and it fails on some HDMI ports and on most TVs. The action is dimmed until a monitor answers.
- Switch Spaces is dimmed when the system's shortcuts for moving between Spaces are off, and the dimmed item's tooltip says why.

## Verification

- Unit tests cover step handling, the DDC messages, and how replies are checked.
- On the trackpad, each action should work from each edge, and an unavailable action should be dimmed.

## Related docs

- [volume.md](../volume.md) describes the step model.
- [dependencies.md](../dependencies.md) must list any new private API.
