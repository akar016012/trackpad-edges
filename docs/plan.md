# Plan

## Context

This project is a macOS menu bar app that turns the edges and corners of a trackpad into controls, while the middle of the trackpad keeps working normally. Haptics are controlled in the settings. The app has no license keys or activation, and it checks for updates once a day.

## Feature status

This list was last updated on 2026-11-11. **Done** means that it was tried on a built-in trackpad and works. **Needs a check** means that it is in the code but has not been tried yet.

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
- [x] [Assignable edges from the window and the menu bar](settings.md)
- [x] [Top edge](roadmap/top-edge.md)
- [x] [More edge actions, including Monitor Brightness](roadmap/more-edge-actions.md)
- [x] [Two-finger edge slides](roadmap/two-finger-slides.md)
- [x] [Per-app profiles](roadmap/per-app-profiles.md)
- [x] [Welcome tour](welcome-tour.md)
- [x] [Palm detection](roadmap/palm-detection.md)
- [x] [Installed build](roadmap/installed-build.md)
- [x] [Seconds per step](roadmap/seconds-per-step.md)
- [x] [Launch at login](menu-bar-and-onboarding.md)
- [x] [Custom app and menu bar icons](dependencies.md)

### Needs a check

- Automatic updates are built, and their signing is tested. Versions 1.2 and 1.3 are the first updates that installed copies can receive on their own, but no successful update of an installed copy has been recorded here yet.
- [ ] [Multiple actions per corner](roadmap/multi-action-corners.md)
- [ ] [Click-to-start option](gestures.md)
- [ ] [Release a resting finger](roadmap/resting-finger-release.md), which is built and unit tested, but the 0.6 second wait has not been tried with real slides
- [ ] [Diagnostics report](roadmap/diagnostics-report.md), which is built and unit tested, but no report has been pasted into an issue and no recording has been made on a trackpad yet
- [ ] External Apple trackpads still need a check, because all testing used the built-in trackpad.
- [ ] Media seek in Safari still needs a check, because only Chrome was tried.
- [ ] [System actions and custom commands on a corner](roadmap/system-and-command-corners.md), which is built and unit tested. A debug build showed the confirm box, ran a command through the login shell, reported its failure, and stopped a command with its background job. No action has fired from the trackpad yet, and the spike questions that need a real press, a consent prompt, or an update of an installed copy are still open.
- [ ] Four fixes from 2026-11-09 have not been tried on a trackpad yet: steps that hold steady on a line, a slide that ends on time after contact drops out, the second look before a mouse-up counts as lost, and the recheck of Switch Spaces when another app comes to the front. Unit tests cover the step logic and the grace period's arithmetic, but the timers and the system's answers need a real run.

### Planned

None of these is built yet, and each document describes the plan.

- [ ] [Press Keys on an edge](roadmap/key-step-edges.md)
- [ ] [Hold a corner](roadmap/corner-hold.md)
- [ ] [Level overlay](roadmap/level-overlay.md)
- [ ] [Settings export and import](roadmap/settings-backup.md)
- [ ] [Shortcuts actions](roadmap/shortcuts-actions.md)

### Known limits

- The app supports macOS 13 or later, but it has been tried only on macOS 27.2. The private frameworks that read touches could behave differently on earlier systems.
- A finger that lands in a strip freezes the pointer, because slides start on touch. [Release a resting finger](roadmap/resting-finger-release.md) gives the pointer back after 0.6 seconds if the finger stays still, but that has not been tried on a trackpad yet, so this limit stays listed until it is confirmed.
- A tap with tap-to-click can still count as a click in a corner.
- A click from a second pointing device can be captured while a finger rests in a zone.
- A finger that is already down after a wake or an unpause can count as a landing.
- A palm that first looks like a finger can cancel a slide before it is recognized.
- Switch Spaces needs the system's Control-arrow shortcuts turned on.
- macOS locks the keyboard backlight off in a bright room, so Keyboard Backlight shows a short notice there. The action is confirmed working, and a Mac without a backlight gets no effect.
- Monitor Brightness works only on monitors and ports that answer over DDC.
- Media seek relies on undocumented behavior, so a macOS update could break it.
- The adapter library sits in a folder that your account can write to, so the app checks it before every run.
- Copies from Xcode and from the Applications folder both act on every gesture if they run together.

## Decisions

- The interface uses AppKit rather than SwiftUI. This covers the menu bar item, the settings window, and the overlays.
- Touch input uses the private `MultitouchSupport` framework. `NSTouch` cannot work because Apple's documentation says touches latch to the view under the cursor, so a background app never receives them.
- Haptics use the private `MTActuator` API, because it is the only API with strength control. `NSHapticFeedbackManager` is the fallback when the private API is unavailable.
- Testing focuses on the built-in MacBook trackpad. Support for external Apple trackpads stays in place, but it gets less testing.
- The app has a window and a menu bar icon, and each edge can be assigned to any of nine actions or to nothing.
- Media seeking uses the third-party `mediaremote-adapter`, because no public API can reach other apps. It is confirmed working on macOS 27.2, so there is no AppleScript fallback.
- All four corners are hot corners, and corners can control media playback.

## Feature scope

| Zone             | Input                      | Action                   | Doc                                |
| ---------------- | -------------------------- | ------------------------ | ---------------------------------- |
| Right edge       | Slide vertically           | System volume            | [volume.md](volume.md)             |
| Left edge        | Slide vertically           | Built-in brightness      | [brightness.md](brightness.md)     |
| Bottom edge      | Slide sideways and release | Media seek               | [media-seek.md](media-seek.md)     |
| Top edge         | Slide sideways             | Off until you assign it  | [top-edge.md](roadmap/top-edge.md) |
| All four corners | 1 to 4 presses             | An action for each count | [corners.md](corners.md)           |
| Middle           | Anything                   | Passes through to macOS  | [gestures.md](gestures.md)         |

Every package, framework, and system method is listed in [dependencies.md](dependencies.md). The shared behavior is described in [gestures.md](gestures.md), [pointer-freeze.md](pointer-freeze.md), [haptics.md](haptics.md), [settings.md](settings.md), and [menu-bar-and-onboarding.md](menu-bar-and-onboarding.md).

Any edge can use any action, and the full list is in [more edge actions](roadmap/more-edge-actions.md).

## Project setup

- The target is macOS-only, and App Sandbox is off, because `MultitouchSupport` does not work inside it.
- `LSUIElement` is set, so the app has a Dock icon only while its window is open.
- The bundle identifier is stable, and signing stays on your development team, so the Accessibility permission survives rebuilds.
- A `.gitignore` covers `xcuserdata/`. Unit tests run through a small Swift package at the repository root, because `swift test` needs no project file support.

## Code layout

All source lives under `trackpad-edges/`.

- `App/` holds the app delegate, the gesture controller, the main menu, the updater, and the project's links.
- `Input/` holds the `MultitouchSupport` bridge, device hot-plug and sleep handling, the event taps, and the watchdog that protects clicks.
- `Gestures/` holds the zone map and a gesture state machine with no system dependencies, so unit tests can cover it. The settings model, the diagnostics report, and the touch recording format live there for the same reason.
- `Actions/` holds the edge actions, including volume, brightness, media seek, and external displays, and the corner actions.
- `Haptics/` holds the haptic engine behind one small interface.
- `Settings/` holds the settings store and the panes of the app window.
- `UI/` holds the app window, the welcome tour, the trackpad diagram, and the seek overlay.
- `scripts/` holds the build and install scripts.
- `site/` holds the [landing page](landing-page.md), which is outside the app.
- `Resources/` holds the bundled adapter, its license, and the About box text, and `Vendor/` holds the adapter source.

## What was done

1. The `docs/` folder and the project conversion came first, and the riskiest techniques were then proven first: touch input in a background app, the private haptics API, and the pointer freeze.
2. The gesture engine, click handling, volume, brightness, corners, and assignable edges were built with unit tests.
3. The app window, the haptic settings, and the first-run steps were added.
4. Media seek was added through the adapter. Full-pad mapping and speed-based acceleration both proved hard to control, so seeking now moves in fixed steps, as volume does.
5. The window layout was rebuilt on one set of rules, and custom icons were added.
6. Measurements from 752 contacts set the thresholds for lighter corner presses and palm detection. Resting fingers and taps peaked near a pressure of 50, and physical clicks started near 120.
7. The shortcut recorder was rebuilt to accept any key combination, including the left or right modifier.

## Roadmap

Phases 0 to 6 are complete, and phase 7 is built but needs a check on a trackpad. Version 1.3 includes phase 7. Phases 8 and 9 are planned, and none of their features is built yet. Each feature has its own document in `docs/roadmap/`. The **Needs a check** list comes next, followed by phase 8.

### Phase 0: Hardware test session (complete)

This phase confirmed brightness, the corners, and the Haptics pane, and it recorded pressure and contact size for phase 1.

### Phase 1: Reliability (complete)

- **[Lighter corner presses](roadmap/lighter-corner-presses.md):** A corner fires on a light press, detected from the pressure in the touch data. This is confirmed working.
- **[Palm detection](roadmap/palm-detection.md):** A large contact is ignored, so a resting palm does not start a slide or freeze the pointer. This is confirmed working.

### Phase 2: Small additions (complete)

- **[Seconds per step](roadmap/seconds-per-step.md):** The Media pane offers fixed seconds per step as an alternative to a percentage, so steps stay small on long videos.
- **[Multiple actions per corner](roadmap/multi-action-corners.md):** Each corner can hold a different action for each click count, such as one click to play or pause and two clicks to skip.

### Phase 3: More controls (complete)

- **[More edge actions](roadmap/more-edge-actions.md):** An edge can scroll, zoom, switch apps or Spaces, change the keyboard backlight, or change external monitor brightness.
- **[Top edge](roadmap/top-edge.md):** The top edge becomes a fourth assignable strip between the top corners.

### Phase 4: Two-finger edge slides (complete)

See [two-finger-slides.md](roadmap/two-finger-slides.md). Each edge can hold a second action for a two-finger slide, such as one finger for volume and two for brightness. This is confirmed working.

### Phase 5: Installed build (complete)

See [installed-build.md](roadmap/installed-build.md). A signed copy in the Applications folder makes launch at login reliable, and it moves the adapter library inside the signed app, where the app checks it against its signature. This is confirmed working.

### Phase 6: Per-app profiles (complete)

See [per-app-profiles.md](roadmap/per-app-profiles.md). Edges and corners can change with the front app. The saved settings stay as the default profile, so nothing needed converting. This is confirmed working.

### Phase 7: Reliability and reports (built, needs a check)

- **[Release a resting finger](roadmap/resting-finger-release.md):** A finger that lands in a strip and stays still gives the pointer back after 0.6 seconds. This is built and unit tested, and it removes one of the known limits once it is confirmed on a trackpad.
- **[Diagnostics report](roadmap/diagnostics-report.md):** The app copies a report for bug reports and can record 10 seconds of touches, which helps with external trackpads and earlier systems that have not been tried. This is built and unit tested, but no report has been pasted into a real issue yet.

### Phase 8: More controls (in progress)

- **[Press Keys on an edge](roadmap/key-step-edges.md):** An edge presses one recorded key combination for each step up and another for each step down, such as switching browser tabs.
- **[Hold a corner](roadmap/corner-hold.md):** Each corner can hold one more action for a press that is held for half a second.
- **[System actions and custom commands on a corner](roadmap/system-and-command-corners.md):** A corner can lock, sleep, restart, or shut down the Mac, toggle Dark Mode or Do Not Disturb, empty the Trash, or run a shell command. Log Out, Restart, and Shut Down ask you to confirm first. This is built and unit tested, and it needs a check on the trackpad.
- **[Level overlay](roadmap/level-overlay.md):** Monitor Brightness and Switch Apps show their level or the next app, because macOS shows no indicator for them.

### Phase 9: Backup and automation (planned)

- **[Settings export and import](roadmap/settings-backup.md):** Settings, including profiles, can be saved to a file and loaded on another Mac, with a summary to confirm first.
- **[Shortcuts actions](roadmap/shortcuts-actions.md):** The Shortcuts app can pause and resume gestures and set an edge, which also allows a global pause key.

## Verification

- Unit tests cover the zone map, the gesture state machine, the settings model, the diagnostics report, the touch recording format, and the rules behind the system actions and Run Command.
- The app is built and run on a MacBook, and each edge and corner is tested by hand on the built-in trackpad, because touch hardware cannot be simulated.
- Clicks near the edges, palm contact, typing, and multi-finger gestures are checked to confirm that normal use is undisturbed.
