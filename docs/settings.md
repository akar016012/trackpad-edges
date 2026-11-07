# Settings

Status: the app window is built and connected. Its layout has been inspected, but changing each option has not been confirmed on hardware yet.

The window is built with AppKit, and it opens at launch, from the Dock, and from the menu bar item. It opens in the center of the screen under the pointer. Every pane uses one layout: a 24-point margin on all sides, two equal columns, one label width, and rows of one height. The window fits each pane exactly, so controls stay in the same place from tab to tab and no pane has leftover space. It opens on the General pane while the Accessibility permission is missing. The Dock icon appears only while the window is open. No website documents a similar app's real settings layout, so the layout and ranges here are this project's own design.

## Edges

The pane shows a diagram of the trackpad with each zone and your fingers live.

| Setting                  | Behavior                                                                                                                                                                                       |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Left, right, bottom edge | Each popup assigns Volume, Brightness, Media Seek, or Off to that edge. A bottom corner with an action takes over that part of the bottom edge and the lowest part of the side edge beside it. |
| Edge width               | This slider sets the width of the strips from 5% to 20%, with a default of 10%.                                                                                                                |
| Sensitivity              | This slider multiplies the step rate from 0.5 to 2.0, where higher needs less travel.                                                                                                          |
| Require key              | This option makes slides start only while a chosen key is held.                                                                                                                                |
| Require a click to start | This option makes slides start on a click rather than on touch.                                                                                                                                |
| Sides                    | This option limits side slides to the bottom quarter of the pad.                                                                                                                               |

The menu bar item can also assign each edge, and the window stays in step with it.

## Corners

All four corners have an action and a click count, and the pane arranges them like the trackpad. See [corners.md](corners.md).

## Media

| Setting   | Behavior                                                                            |
| --------- | ----------------------------------------------------------------------------------- |
| Each step | This slider sets the percentage of the track that one step moves, from 0.5% to 10%. |

The **Style** popup sets how the seek preview looks: Glass, Clear Glass, Frosted, or Solid. Glass and Solid follow light and dark mode. Clear Glass and Frosted always use a dimmed tint with light text, so they stay readable over any content. The **Position** popup places it at the bottom, center, or top of the screen. Changing either one shows a sample for two seconds.

See [media-seek.md](media-seek.md).

## Haptics

The haptic controls are described in [haptics.md](haptics.md).

## General

The pane holds the first-run steps, the Accessibility status, and launch at login.
