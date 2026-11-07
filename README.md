# Trackpad Edges

Trackpad Edges is a personal macOS app that turns the edges and corners of a trackpad into controls, while the middle of the trackpad keeps working normally. You touch a strip and slide to change the volume or brightness, seek through media, scroll, zoom, or switch apps and Spaces, and you feel a haptic tick on each step.

The app is for everyday use. It relies on the private `MultitouchSupport` framework, so a macOS update could break it.

## Requirements

- The app needs an Apple silicon Mac with a Force Touch trackpad for haptics. It currently targets macOS 27.2.
- Gestures need the Accessibility permission, which you can grant from the menu bar icon.

## Configure

The app window and the menu bar icon both let you choose what each edge does. The window also sets the corners, the haptic strength and pattern, and launch at login.

## Build and run

Open `trackpad-edges.xcodeproj` in Xcode and run the `trackpad-edges` scheme, or build from the command line:

```bash
xcodebuild -project trackpad-edges.xcodeproj -scheme trackpad-edges -configuration Debug -derivedDataPath build build
```

```bash
open "build/Build/Products/Debug/Trackpad Edges.app"
```

## Make a copy to keep

In Xcode, choose **Product > Archive**, and then **Distribute App** in the Organizer. **Direct Distribution** signs and notarizes the app with your Developer ID, and it needs the Hardened Runtime, which is on. **Custom > Copy App** is the quickest way to get a local copy, and it skips notarization.

The app's name, version, category, copyright, and icon are set in the project's build settings, and the text in its About box is in `Resources/Credits.rtf`.

## Test

The gesture logic has no system dependencies, so it is covered by a small Swift package at the repository root:

```bash
swift test
```

## Third-party code

Media seeking uses `mediaremote-adapter` under the BSD 3-Clause license. Its source is in `Vendor/mediaremote-adapter`.

## Status

The list of what is done and what is incomplete is in [docs/plan.md](docs/plan.md).

## Documentation

The plan and one document for each feature live in [docs/](docs/plan.md).
