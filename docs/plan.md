# Plan

## Context

This project is a desktop macOS menu bar app that turns the edges and corners of a trackpad into controls, while the middle of the trackpad keeps working normally. It reproduces the functionality of a similar app and adds haptics that you can control in settings. It has its own name and design, and it reuses no a similar app branding, copy, or assets. License keys, activation, and update checks are left out because they serve no purpose for everyday use.

## Feature status

Work stopped here on 2026-11-06, and the incomplete items below are left for later. **Done** means that it was tried and approved on this Mac. **Needs a check** means that it is in the code but has not been tried yet.

### Done

- [x] [Touch input from a background app](gestures.md)
- [x] [Volume on an edge](volume.md)
- [x] [Brightness on an edge](brightness.md)
- [x] [Media seek in fixed steps](media-seek.md)
- [x] [Ticking seek bar](media-seek.md)
- [x] [Seek overlay styles and positions](settings.md)
- [x] [Pointer freeze during a slide](pointer-freeze.md)
- [x] [Tap protection](gestures.md)
- [x] [Haptic tick on each step](haptics.md)
- [x] [Haptic strength, pattern, and event settings](haptics.md)
- [x] [Four hot corners with their actions](corners.md)
- [x] [Corner media controls](corners.md)
- [x] [Lighter corner presses](roadmap/lighter-corner-presses.md)
- [x] [Recording any key combination, including the left or right modifier](corners.md)
- [x] [App window with aligned panes](settings.md)
- [x] [Custom icons in the window](dependencies.md)

### Needs a check

- [ ] [Palm detection](roadmap/palm-detection.md)
- [ ] [Assignable edges from the window and the menu bar](settings.md)
- [ ] [Click-to-start option](gestures.md)
- [ ] [Launch at login](menu-bar-and-onboarding.md)
- [ ] [Custom app and menu bar icons](dependencies.md)
- [ ] external Apple trackpad support, because all testing used the built-in trackpad
- [ ] Media seek in Safari, because only Chrome was tried

### Incomplete

- [ ] [Seconds per step](roadmap/seconds-per-step.md)
- [ ] [Multiple actions per corner](roadmap/multi-action-corners.md)
- [ ] [More edge actions](roadmap/more-edge-actions.md)
- [ ] [Top edge](roadmap/top-edge.md)
- [ ] [Two-finger edge slides](roadmap/two-finger-slides.md)
- [ ] [Installed build](roadmap/installed-build.md)
- [ ] [Per-app profiles](roadmap/per-app-profiles.md)

### Known limits

- A finger that lands in a strip freezes the pointer until it leaves, because slides start on touch.
- A tap with tap-to-click can still count as a click in a corner.
- A click from a second pointing device can be captured while a finger rests in a zone.
- A finger that is already down after a wake or an unpause can count as a landing.
- A palm that first looks like a finger can cancel a slide before it is recognized.
- Media seek relies on undocumented behavior, so a macOS update could break it.
- The adapter library sits in a user-writable folder until the installed build moves it inside the signed app.

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
| All four corners | 1 to 4 presses             | Configurable action     | [corners.md](corners.md)       |
| Middle           | Anything                   | Passes through to macOS | [gestures.md](gestures.md)     |

Every package, framework, and system method is listed in [dependencies.md](dependencies.md). The shared behavior is described in [gestures.md](gestures.md), [pointer-freeze.md](pointer-freeze.md), [haptics.md](haptics.md), [settings.md](settings.md), and [menu-bar-and-onboarding.md](menu-bar-and-onboarding.md).

External display brightness is not built yet, and it is part of [more edge actions](roadmap/more-edge-actions.md).

## Project setup

- The target is macOS-only, and App Sandbox is off, because `MultitouchSupport` does not work inside it.
- `LSUIElement` is set, so the app has a Dock icon only while its window is open.
- The bundle identifier is stable, and signing stays on your development team, so the Accessibility permission survives rebuilds.
- A `.gitignore` covers `xcuserdata/`. Unit tests run through a small Swift package at the repository root, because `swift test` needs no project file support.

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

## What was done

1. The `docs/` folder and the project conversion came first, and the riskiest techniques were then proven on this Mac: touch input in a background app, the private haptics API, and the pointer freeze.
2. The gesture engine, click handling, volume, brightness, corners, and assignable edges were built with unit tests.
3. The app window, the haptic settings, and the first-run steps were added.
4. Media seek was added through the adapter. Full-pad mapping and speed-based acceleration both proved hard to control, so seeking now moves in fixed steps, as volume does.
5. The window layout was rebuilt on one set of rules, and custom icons were added.
6. Measurements from 752 contacts set the thresholds for lighter corner presses and palm detection. Resting fingers and taps peaked near a pressure of 50, and physical clicks started near 120.
7. The shortcut recorder was rebuilt to accept any key combination, including the left or right modifier.

Each batch was reviewed by a review, fixed, committed, and pushed.

## Roadmap

Phases 0 and 1 are complete, and phases 2 to 6 are not started. Each feature has its own document in `docs/roadmap/`. To pick this up later, start with the **Needs a check** list, and then build phase 2. Each phase should be reviewed, fixed, committed, and pushed before the next one starts.

### Phase 0: Hardware test session (complete)

This phase confirmed brightness, the corners, and the Haptics pane, and it recorded pressure and contact size for phase 1.

### Phase 1: Reliability (complete)

- **[Lighter corner presses](roadmap/lighter-corner-presses.md):** A corner fires on a light press, detected from the pressure in the touch data. This is confirmed working.
- **[Palm detection](roadmap/palm-detection.md):** A large contact is ignored, so a resting palm does not start a slide or freeze the pointer. This is built, but it still needs a check.

### Phase 2: Small additions (not started)

- **[Seconds per step](roadmap/seconds-per-step.md):** The Media pane offers fixed seconds per step as an alternative to a percentage, so steps stay small on long videos.
- **[Multiple actions per corner](roadmap/multi-action-corners.md):** Each corner can hold a different action for each click count, such as one click to play or pause and two clicks to skip.

### Phase 3: More controls (not started)

- **[More edge actions](roadmap/more-edge-actions.md):** An edge can scroll, zoom, switch apps or Spaces, change the keyboard backlight, or change external monitor brightness.
- **[Top edge](roadmap/top-edge.md):** The top edge becomes a fourth assignable strip between the top corners.

### Phase 4: Two-finger edge slides (not started)

See [two-finger-slides.md](roadmap/two-finger-slides.md). Each edge can hold a second action for a two-finger slide, such as one finger for volume and two for brightness.

### Phase 5: Installed build (not started)

See [installed-build.md](roadmap/installed-build.md). A signed copy in the Applications folder makes launch at login reliable, and it lets the adapter library move inside the signed app, away from a user-writable folder.

### Phase 6: Per-app profiles (not started)

See [per-app-profiles.md](roadmap/per-app-profiles.md). Edges and corners can change with the front app. This comes last because it changes how every setting is stored.

### Risks for the remaining phases

| Risk                                                                             | Plan                                                                                           |
| -------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
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
