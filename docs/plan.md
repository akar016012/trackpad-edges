# Plan

## Context

This project is a desktop macOS menu bar app that turns the edges and top corners of a trackpad into controls, while the middle of the trackpad keeps working normally. It reproduces the functionality of a similar app and adds haptics that you can control in settings. It has its own name and design, and it reuses no a similar app branding, copy, or assets. License keys, activation, and update checks are left out because they serve no purpose for everyday use.

## Status

The project is now a macOS menu bar app with a private GitHub repository. Touch input, haptics, and the pointer freeze are confirmed working on the built-in trackpad. Touch-to-start slides are the default, because testing showed that a light touch at the edge produces no click. The right-edge volume slide is confirmed working. Brightness, corners, and assignable edges are built, but they have not been confirmed on hardware yet. The app window, the haptic settings, onboarding, and media seeking are still to be built. The findings below come from a review of the website, Apple's documentation, the installed macOS binaries, and open source projects.

## Decisions

- The interface uses AppKit rather than SwiftUI. This covers the menu bar item, the settings window, and the overlays.
- Touch input uses the private `MultitouchSupport` framework. `NSTouch` cannot work because Apple's documentation says touches latch to the view under the cursor, so a background app never receives them.
- Haptics use the private `MTActuator` API, because it is the only API with strength control. `NSHapticFeedbackManager` is the fallback when the private API is unavailable.
- Testing focuses on the built-in MacBook trackpad. external Apple trackpad support stays in place, but it gets less testing.
- The app has a window and a menu bar icon, and each edge can be assigned to volume, brightness, seek, or nothing.
- Each batch of features is reviewed by a review, fixed, committed, and pushed.
- Media seeking uses a Now Playing workaround so that it can reach most players. If that fails on macOS 27, seeking falls back to Music and Spotify through AppleScript.

## Feature scope

| Zone                           | Input                      | Action                  | Doc                            |
| ------------------------------ | -------------------------- | ----------------------- | ------------------------------ |
| Right edge                     | Slide vertically           | System volume           | [volume.md](volume.md)         |
| Left edge                      | Slide vertically           | Built-in brightness     | [brightness.md](brightness.md) |
| Bottom edge                    | Slide sideways and release | Media seek              | [media-seek.md](media-seek.md) |
| Top-left and top-right corners | 1 to 4 clicks              | Configurable action     | [corners.md](corners.md)       |
| Middle                         | Anything                   | Passes through to macOS | [gestures.md](gestures.md)     |

Every package, framework, and system method is listed in [dependencies.md](dependencies.md). The shared behavior is described in [gestures.md](gestures.md), [pointer-freeze.md](pointer-freeze.md), [haptics.md](haptics.md), [settings.md](settings.md), and [menu-bar-and-onboarding.md](menu-bar-and-onboarding.md).

External display brightness is out of scope for the first version, as it is in a similar app. It can be added later through DDC.

## Project changes

- The target becomes macOS-only by editing `trackpad-edges.xcodeproj/project.xcproj`.
- App Sandbox is turned off, because `MultitouchSupport` does not work inside it.
- `LSUIElement` is set so that the app has no Dock icon.
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
- `Settings/` holds the settings store and the AppKit settings window.
- `UI/` holds the app window and the trackpad diagram, and it will hold the seek overlay.

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

| Risk                                                                | Check on hardware                                          | If it fails                                                           |
| ------------------------------------------------------------------- | ---------------------------------------------------------- | --------------------------------------------------------------------- |
| The pointer freeze may not work from a background app.              | Freeze the pointer while another app is in front.          | Warp the pointer back when the slide ends.                            |
| Opening the actuator may change how normal clicks feel.             | Compare clicks with the actuator open and closed.          | Open the actuator only during a gesture.                              |
| The private haptics API may not behave as the disassembly suggests. | Fire each pattern at several strengths.                    | Fall back to `NSHapticFeedbackManager` and hide the strength control. |
| The Now Playing workaround may not work on macOS 27.                | Read the position and seek a track in Music and a browser. | Fall back to Music and Spotify through AppleScript.                   |

## Verification

- Unit tests cover the zone map and the gesture state machine.
- The app is built and run on this Mac, and each edge and corner is tested by hand on the built-in trackpad, because touch hardware cannot be simulated.
- Clicks near the edges, palm contact, typing, and multi-finger gestures are checked to confirm that normal use is undisturbed.
