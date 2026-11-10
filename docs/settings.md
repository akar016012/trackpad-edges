# Settings

Status: the app window is built and connected. Its layout has been inspected, but changing each option has not been confirmed on hardware yet.

The window is built with AppKit, and it opens at launch, from the Dock, and from the menu bar item. A new install opens the [welcome tour](welcome-tour.md) first. It opens in the center of the screen under the pointer. Every pane uses one layout: a 24-point margin on all sides, two equal columns, one label width, and rows of one height. The window fits each pane exactly, so controls stay in the same place from tab to tab and no pane has leftover space. The tabs are Edges, Corners, Media, Haptics, Profiles, and General. It opens on the General pane while the Accessibility permission is missing. The Dock icon appears only while the window or the tour is open.

## Edges

The pane shows a diagram of the trackpad with each zone and your fingers live.

| Setting                       | Behavior                                                                                                                                                                                                  |
| ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Left, right, top, bottom edge | Each popup assigns Volume, Brightness, Media Seek, Scroll, Zoom, Switch Apps, Switch Spaces, Keyboard Backlight, Monitor Brightness, or Off to that edge. An action that cannot work right now is dimmed. |
| Two-finger slides             | Each popup assigns an action to a two-finger slide on that edge. Every edge starts as Off.                                                                                                                |
| Edge width                    | This slider sets the width of the strips from 5% to 20%, with a default of 10%.                                                                                                                           |
| Sensitivity                   | This slider multiplies the step rate from 0.5 to 2.0, where higher needs less travel.                                                                                                                     |
| Require key                   | This option makes slides start only while a chosen key is held.                                                                                                                                           |
| Require a click to start      | This option makes slides start on a click rather than on touch. Two-finger slides always start on touch.                                                                                                  |
| Sides                         | This option limits side slides to the bottom quarter of the pad.                                                                                                                                          |

The menu bar item can also assign each edge for All Apps, and the window stays in step with it. Two-finger slides are set on the Edges pane only.

## Corners

All four corners can hold an action for each click count from 1 to 4, and the pane arranges them like the trackpad. The clicks popup picks the count to edit, and a dot marks each count that has an action. See [corners.md](corners.md).

## Profiles

The Profiles tab gives an app its own edges and corners, and everything it does not change follows All Apps. See [per-app-profiles.md](roadmap/per-app-profiles.md).

## Media

The overlay uses the Solid style while **Reduce transparency** is on in System Settings, whatever style is chosen here.

| Setting   | Behavior                                                                        |
| --------- | ------------------------------------------------------------------------------- |
| Step type | This popup makes a step a percentage of the track or a fixed number of seconds. |
| Each step | This slider sets one step, from 0.5% to 10% or from 1 to 60 seconds.            |

The **Style** popup sets how the seek preview looks: Glass, Clear Glass, Frosted, or Solid. Before macOS 26, which introduced glass, both glass styles look like Frosted. On macOS 26 or later, Glass follows light and dark mode, and Solid always does. Clear Glass and Frosted always use a dimmed tint with light text, so they stay readable over any content. The **Position** popup places it at the bottom, center, or top of the screen. Changing either one shows a sample for two seconds.

See [media-seek.md](media-seek.md).

## Haptics

The haptic controls are described in [haptics.md](haptics.md).

## Saved settings

The settings are saved as one block in the app's preferences, and each value in it is read on its own when the app starts.

- A value that this version cannot read, such as an action that a newer version added, falls back by itself. An edge turns Off, a corner click gets no action, a profile slot follows All Apps, and any other value takes its default.
- Numbers are held to the ranges that the window offers, so a value changed by hand cannot break a slide or a seek.
- A version that could not read a value drops it the next time it saves a change.
- If the block cannot be read at all, the app starts with its defaults and keeps the old block under a separate key, so that it can be recovered.

## App details

The app is named Trackpad Edges, and it is in the Utilities category. Its name, version, copyright, and category are build settings in the project, and its About box text is in `Resources/Credits.rtf`.

## General

This pane can reopen the welcome tour.

The pane holds the first-run steps, the Accessibility status, launch at login, and updates. **Check daily** is on by default, and **Check Now** checks right away. Both are unavailable in a copy that is not signed with this project's Developer ID.

The **Report a problem** section helps with a bug report, and the app sends nothing itself. Its **Diagnostics** row lines up with the rows above it, with one button beneath the other. A line beneath the buttons says what just happened, and VoiceOver announces it.

- **Copy Diagnostics** puts a plain-text report on the clipboard. It lists the app version, the macOS version, the Mac model, each trackpad with its family ID and whether it is built in, the Accessibility state, whether the app is watching clicks, whether gestures are paused, whether the media adapter loaded, each dimmed action with its reason, and a summary of the settings.
- The report leaves out file paths, links, app names, bundle identifiers, recorded key labels, and shortcut names. A corner shows only the kind of action for each click count, and a profile shows only its number and what it changes.
- **Record Touches…** says what it records, and then records 10 seconds of touch data while gestures keep working. It then asks where to save the file and shows it in the Finder. The file holds a format version, each trackpad's family ID and whether it is built in, and the time of each frame with the number, position, pressure, size, and long axis of each contact. It holds nothing else.

See [diagnostics-report.md](roadmap/diagnostics-report.md).
