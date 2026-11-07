# More edge actions

Status: this feature is planned for phase 3.

## Goal

An edge should be able to do more than change volume, change brightness, or seek.

## Behavior

Each new action works in steps with a haptic tick, as volume does.

| Action                      | What a slide does                                          |
| --------------------------- | ---------------------------------------------------------- |
| Scroll                      | The slide scrolls the window under the pointer.            |
| Zoom                        | The slide zooms in and out by pressing the zoom shortcuts. |
| Switch apps                 | Each step moves to the next or previous app.               |
| Switch Spaces               | Each step moves one Space left or right.                   |
| Keyboard backlight          | Each step changes the keyboard backlight.                  |
| External monitor brightness | Each step changes the brightness of an external display.   |

## Settings

The edge popups on the Edges pane and in the menu bar item list the new actions. An action that cannot work on this Mac is left out.

## Implementation plan

1. Extend `SlideKind`, and keep the saved values compatible.
2. Add one small controller for each action in `Actions/`, each with the same `step` call that volume uses.
3. Synthesize scrolling with `CGEvent`, and press shortcuts with the existing key code path.
4. Press the keyboard backlight through its media keys.
5. Reach external displays over DDC with `IOAVServiceWriteI2C`, and throttle the writes.

## Risks

- The keyboard backlight has no public API, so the action is left out if its media key does not work here.
- DDC varies by monitor and port, and it fails on some HDMI ports and on most TVs. The action appears only when a monitor responds.
- Switching Spaces depends on the system shortcuts being turned on, so the settings must say when they are off.
- Switching apps with synthesized keys may feel unlike a real Command-Tab, so it needs testing.

## Verification

- Unit tests cover the settings and the step handling.
- On the trackpad, each action works from each edge, and an unavailable action is hidden.

## Related docs

- [volume.md](../volume.md) describes the step model.
- [dependencies.md](../dependencies.md) must list any new private API.
