# Trackpad Edges

Trackpad Edges is a macOS app that turns the edges and corners of a trackpad into controls, while the middle of the trackpad keeps working normally. You touch a strip and slide to change the volume or brightness, seek through media, scroll, zoom, or switch apps and Spaces, and you feel a haptic tick on each step.

The app relies on private Apple frameworks, so a macOS update could break it. No public API can read a trackpad from the background or control its haptic strength, and [docs/dependencies.md](docs/dependencies.md) lists every framework it uses.

## Requirements

- The app needs an Apple silicon Mac with a Force Touch trackpad for haptics. It currently targets macOS 27.2.
- Gestures need the Accessibility permission, which you can grant from the menu bar icon.

## Install

This command builds a signed Release copy and installs it in the Applications folder. A build with a new signing identity asks for the Accessibility permission again.

```bash
scripts/install.sh
```

The script signs with the project's identity. To use your own, first follow the signing step in [CONTRIBUTING.md](CONTRIBUTING.md), because media seek refuses a build signed by a team it does not expect. A real install has not been confirmed yet, and the script does not notarize the app, so a build made this way is for your own Mac.

A new install opens a short welcome tour that sets up the permission, your edges, your corners, and haptics.

## Configure

The app window and the menu bar icon both let you choose what each edge does. The window also sets the corners, profiles for individual apps, the haptic strength and pattern, and launch at login.

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

The app's name, version, category, copyright, and icon are set in the project's build settings, and the text in its About box is in `trackpad-edges/Resources/Credits.rtf`.

## Test

The gesture logic has no system dependencies, so it is covered by a small Swift package at the repository root:

```bash
swift test
```

## Contributing

Contributions are welcome, and [CONTRIBUTING.md](CONTRIBUTING.md) explains how to help. This project has one maintainer, so replies can take up to two weeks. Please report security problems privately, as [SECURITY.md](SECURITY.md) explains. Everyone who takes part agrees to follow the [code of conduct](CODE_OF_CONDUCT.md).

## License

Copyright (C) 2026 Aditya Kar.

Trackpad Edges is free software: you can redistribute it and modify it under the terms of the [GNU General Public License version 3](LICENSE), and only that version (GPL-3.0-only). It is distributed in the hope that it will be useful, but without any warranty, and without even the implied warranty of merchantability or fitness for a particular purpose. The parts that come from others keep their own licenses, which [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) lists. This project is independent, and it is not affiliated with Apple Inc.

## Status

The list of what is done and what is incomplete is in [docs/plan.md](docs/plan.md).

## Documentation

The plan and one document for each feature live in [docs/](docs/plan.md).
