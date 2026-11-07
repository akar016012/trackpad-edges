# Plan

## Context

This project is a desktop macOS menu bar app that turns the edges and corners of a trackpad into controls, while the middle of the trackpad keeps working normally. It reproduces the functionality of a similar app and adds haptics that you can control in settings. It has its own name and design, and it reuses no a similar app branding, copy, or assets. License keys, activation, and update checks are left out because they serve no purpose for everyday use.

## Feature status

This table shows what is added and what is pending. **Confirmed** means that it was tried and approved on this Mac. **Built** means that it is in the code but has not been tried yet.

### Added

| Feature                                       | State     | Doc                                                      |
| --------------------------------------------- | --------- | -------------------------------------------------------- |
| Touch input from a background app             | Confirmed | [gestures.md](gestures.md)                               |
| Volume on an edge                             | Confirmed | [volume.md](volume.md)                                   |
| Pointer freeze during a slide                 | Confirmed | [pointer-freeze.md](pointer-freeze.md)                   |
| Haptic tick on each step                      | Confirmed | [haptics.md](haptics.md)                                 |
| Tap protection                                | Confirmed | [gestures.md](gestures.md)                               |
| Media seek in fixed steps                     | Confirmed | [media-seek.md](media-seek.md)                           |
| Ticking seek bar                              | Confirmed | [media-seek.md](media-seek.md)                           |
| App window with aligned panes                 | Confirmed | [settings.md](settings.md)                               |
| Custom icons in the window                    | Confirmed | [dependencies.md](dependencies.md)                       |
| Custom app and menu bar icons                 | Built     | [dependencies.md](dependencies.md)                       |
| Seek overlay styles and positions             | Built     | [settings.md](settings.md)                               |
| Brightness on an edge                         | Built     | [brightness.md](brightness.md)                           |
| Four hot corners with their actions           | Built     | [corners.md](corners.md)                                 |
| Corner media controls                         | Built     | [corners.md](corners.md)                                 |
| Assignable edges from the window and menu bar | Built     | [settings.md](settings.md)                               |
| Haptic strength, pattern, and event settings  | Built     | [haptics.md](haptics.md)                                 |
| Click-to-start option                         | Built     | [gestures.md](gestures.md)                               |
| Launch at login                               | Built     | [menu-bar-and-onboarding.md](menu-bar-and-onboarding.md) |

### Pending

| Feature                     | Phase | Doc                                                            |
| --------------------------- | ----- | -------------------------------------------------------------- |
| Hardware test session       | 0     | This plan                                                      |
| Lighter corner presses      | 1     | [lighter-corner-presses.md](roadmap/lighter-corner-presses.md) |
| Palm detection              | 1     | [palm-detection.md](roadmap/palm-detection.md)                 |
| Seconds per step            | 2     | [seconds-per-step.md](roadmap/seconds-per-step.md)             |
| Multiple actions per corner | 2     | [multi-action-corners.md](roadmap/multi-action-corners.md)     |
| More edge actions           | 3     | [more-edge-actions.md](roadmap/more-edge-actions.md)           |
| Top edge                    | 3     | [top-edge.md](roadmap/top-edge.md)                             |
| Two-finger edge slides      | 4     | [two-finger-slides.md](roadmap/two-finger-slides.md)           |
| Installed build             | 5     | [installed-build.md](roadmap/installed-build.md)               |
| Per-app profiles            | 6     | [per-app-profiles.md](roadmap/per-app-profiles.md)             |

## Decisions

- The interface uses AppKit rather than SwiftUI. This covers the menu bar item, the settings window, and the overlays.
- Touch input uses the private `MultitouchSupport` framework. `NSTouch` cannot work because Apple's documentation says touches latch to the view under the cursor, so a background app never receives them.
- Haptics use the private `MTActuator` API, because it is the only API with strength control. `NSHapticFeedbackManager` is the fallback when the private API is unavailable.
- Testing focuses on the built-in MacBook trackpad. external Apple trackpad support stays in place, but it gets less testing.
- The app has a window and a menu bar icon, and each edge can be assigned to volume, brightness, seek, or nothing.
- Each batch of features is reviewed by a review, fixed, committed, and pushed.
- Media seeking uses the third-party `mediaremote-adapter`, because no public API can reach other apps. It is confirmed working on macOS 27.2, so there is no AppleScript fallback.
- All four corners are hot corners, and corners can control media playback.

## Feature scope

| Zone             | Input                      | Action                  | Doc                            |
| ---------------- | -------------------------- | ----------------------- | ------------------------------ |
| Right edge       | Slide vertically           | System volume           | [volume.md](volume.md)         |
| Left edge        | Slide vertically           | Built-in brightness     | [brightness.md](brightness.md) |
| Bottom edge      | Slide sideways and release | Media seek              | [media-seek.md](media-seek.md) |
| All four corners | 1 to 4 clicks              | Configurable action     | [corners.md](corners.md)       |
| Middle           | Anything                   | Passes through to macOS | [gestures.md](gestures.md)     |

Every package, framework, and system method is listed in [dependencies.md](dependencies.md). The shared behavior is described in [gestures.md](gestures.md), [pointer-freeze.md](pointer-freeze.md), [haptics.md](haptics.md), [settings.md](settings.md), and [menu-bar-and-onboarding.md](menu-bar-and-onboarding.md).

External display brightness is out of scope for the first version, as it is in a similar app. It can be added later through DDC.

## Project changes

- The target becomes macOS-only by editing `trackpad-edges.xcodeproj/project.xcproj`.
- App Sandbox is turned off, because `MultitouchSupport` does not work inside it.
- `LSUIElement` is set so that the app has a Dock icon only while its window is open.
- The placeholder bundle identifier is replaced with a stable one, and signing stays on your development team so that the Accessibility permission survives rebuilds.
- `MyApp.swift` and `ContentView.swift` are replaced by an AppKit entry point.
- A `.gitignore` covers `xcuserdata/`, and a README is added. Unit tests run through a small Swift package at the repository root, because `swift test` needs no project file support.

## Code layout

All source lives under `trackpad-edges/`.

- `App/` holds the app delegate, the gesture controller, and the main menu.
- `Input/` holds the `MultitouchSupport` bridge, device hot-plug and sleep handling, and the event tap.
- `Gestures/` holds the zone map and a gesture state machine with no system dependencies, so unit tests can cover it.
- `Actions/` holds the volume, brightness, media seek, and corner actions.
- `Haptics/` holds the haptic engine behind one small interface.
- `Settings/` holds the settings store and the panes of the app window.
- `UI/` holds the app window, the trackpad diagram, and the seek overlay.
- `Resources/` holds the bundled adapter, and `Vendor/` holds its source.

## Build order

1. Create this `docs/` folder.
2. Convert the project to a macOS menu bar app and confirm that it builds.
3. Validate the riskiest techniques on this Mac, as listed under Risks.
4. Build the zone map and gesture state machine with unit tests.
5. Build click handling and the pointer freeze.
6. Build volume, brightness, and haptics.
7. Build the corner actions.
8. Build media seeking and its overlay.
9. Build the settings window and the first-run guide.
10. Run the full verification, have a review check the changes, and update these docs.

## Risks

| Risk                                                                | Check on hardware                                 | If it fails                                                           |
| ------------------------------------------------------------------- | ------------------------------------------------- | --------------------------------------------------------------------- |
| The pointer freeze may not work from a background app.              | Freeze the pointer while another app is in front. | Warp the pointer back when the slide ends.                            |
| Opening the actuator may change how normal clicks feel.             | Compare clicks with the actuator open and closed. | Open the actuator only during a gesture.                              |
| The private haptics API may not behave as the disassembly suggests. | Fire each pattern at several strengths.           | Fall back to `NSHapticFeedbackManager` and hide the strength control. |

## Roadmap

All of these features are approved, and none of them is built yet. Each one has its own document in `docs/roadmap/`. Each phase is reviewed, fixed, committed, and pushed before the next one starts.

### Phase 0: Hardware test session

This phase confirms brightness, the corners, and the Haptics pane, which have not been tried on the trackpad. It also records pressure and contact size for light presses, firm clicks, taps, and resting palms, because phase 1 needs those numbers.

### Phase 1: Reliability

- **[Lighter corner presses](roadmap/lighter-corner-presses.md):** A corner fires on a light press, detected from the pressure in the touch data, rather than on a firm click. This also stops taps from counting as clicks.
- **[Palm detection](roadmap/palm-detection.md):** A large contact is ignored, so a resting palm does not start a slide or freeze the pointer.

### Phase 2: Small additions

- **[Seconds per step](roadmap/seconds-per-step.md):** The Media pane offers fixed seconds per step as an alternative to a percentage, so steps stay small on long videos.
- **[Multiple actions per corner](roadmap/multi-action-corners.md):** Each corner can hold a different action for each click count, such as one click to play or pause and two clicks to skip.

### Phase 3: More controls

- **[More edge actions](roadmap/more-edge-actions.md):** An edge can scroll, zoom, switch apps or Spaces, change the keyboard backlight, or change external monitor brightness.
- **[Top edge](roadmap/top-edge.md):** The top edge becomes a fourth assignable strip between the top corners.

### Phase 4: Two-finger edge slides

See [two-finger-slides.md](roadmap/two-finger-slides.md). Each edge can hold a second action for a two-finger slide, such as one finger for volume and two for brightness.

### Phase 5: Installed build

See [installed-build.md](roadmap/installed-build.md). A signed copy in the Applications folder makes launch at login reliable, and it lets the adapter library move inside the signed app, away from a user-writable folder.

### Phase 6: Per-app profiles

See [per-app-profiles.md](roadmap/per-app-profiles.md). Edges and corners can change with the front app. This comes last because it changes how every setting is stored.

### Roadmap risks

| Risk                                                                             | Plan                                                                                           |
| -------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| Pressure may not separate a light press from a resting finger.                   | Phase 0 measures this. If it fails, corners keep the firm click.                               |
| Contact size may not separate a palm from a flat finger.                         | Phase 0 measures this. If it fails, a size threshold becomes a setting.                        |
| Two-finger slides can collide with scrolling and system gestures.                | The slide must start with both fingers in the strip. If that is unreliable, it becomes opt-in. |
| Keyboard backlight has no public API.                                            | Use its media key first, and leave the action out if that does not work on this Mac.           |
| External brightness over DDC varies by monitor and port.                         | Show the action only when a monitor responds.                                                  |
| Switching Spaces depends on system shortcuts being turned on.                    | Tell the user in the settings when the shortcut is off.                                        |
| A top strip shrinks the room for ordinary pointer starts.                        | It stays off by default.                                                                       |
| Moving the library inside the app needs a build phase in the new project format. | Test it in phase 5, and keep the current unpacking if that fails.                              |
| Per-app profiles change how settings are stored.                                 | Keep the current settings as the default profile, so nothing is lost.                          |

## Verification

- Unit tests cover the zone map and the gesture state machine.
- The app is built and run on this Mac, and each edge and corner is tested by hand on the built-in trackpad, because touch hardware cannot be simulated.
- Clicks near the edges, palm contact, typing, and multi-finger gestures are checked to confirm that normal use is undisturbed.
