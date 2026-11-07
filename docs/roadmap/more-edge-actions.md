# More edge actions

Status: these actions are built, unit tested, and confirmed working. External monitor brightness is the exception: the one monitor tried refused DDC, so it has never been seen working.

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

- The keyboard backlight has no public API for setting it. The app presses the public media keys, and it reads the state from the private CoreBrightness client so that it knows when nothing can change.
- A Mac with no keyboard backlight, or one that ignores these keys, gets no effect, and the app cannot always tell.
- macOS locks the keyboard backlight off while the room reads as bright, and the system slider then does not move. Covering the light sensor beside the camera unlocked it in testing, and the level moved from 0 to 100%. While it is locked, the app gives the limit haptic if that setting is on, and it shows a short notice in the overlay style from the Media pane, which says that macOS turns the light off when the room is bright. VoiceOver announces the same notice. The app counts the backlight as locked only while automatic brightness is on. Turning off **Adjust keyboard brightness in low light** in System Settings may allow manual control, but that has not been tried.
- Other Apple options were tested and do not help. A CoreHID virtual device is refused, the real backlight device has an undocumented vendor protocol, and setting the level through CoreBrightness has no effect while it is locked.
- DDC varies by monitor and port, and it fails on some HDMI ports and on most TVs. The action is dimmed until a monitor answers.
- Switch Spaces is dimmed when the system's shortcuts for moving between Spaces are off, and the dimmed item's tooltip says why.

## Verification

- Unit tests cover step handling, the DDC messages, and how replies are checked.
- On the trackpad, each action works from an edge, and an unavailable action is dimmed.

## Related docs

- [volume.md](../volume.md) describes the step model.
- [dependencies.md](../dependencies.md) must list any new private API.
