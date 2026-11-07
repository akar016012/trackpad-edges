# Settings

Status: the app window is built and connected. Its layout has been inspected, but changing each option has not been confirmed on hardware yet.

The window is built with AppKit, and it opens at launch, from the Dock, and from the menu bar item. It opens in the center of the screen under the pointer, and each pane centers its content in a window of the same size. It opens on the General pane while the Accessibility permission is missing. The Dock icon appears only while the window is open. No website documents a similar app's real settings layout, so the layout and ranges here are this project's own design.

## Edges

The pane shows a diagram of the trackpad with each zone and your fingers live.

| Setting                  | Behavior                                                                                                                      |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------------- |
| Left, right, bottom edge | Each popup assigns Volume, Brightness, Media Seek, or Off to that edge. Media Seek has no effect until that feature is built. |
| Edge width               | This slider sets the width of the strips from 5% to 20%, with a default of 10%.                                               |
| Sensitivity              | This slider multiplies the step rate from 0.5 to 2.0, where higher needs less travel.                                         |
| Require key              | This option makes slides start only while a chosen key is held.                                                               |
| Require a physical click | This option makes slides start on a click rather than on touch.                                                               |
| Bottom quarter           | This option limits side slides to the bottom quarter of the pad.                                                              |

The menu bar item can also assign each edge, and the window stays in step with it.

## Corners

Each corner has an action and a click count. See [corners.md](corners.md).

## Haptics

The haptic controls are described in [haptics.md](haptics.md).

## General

The pane holds the first-run steps, the Accessibility status, and launch at login.
