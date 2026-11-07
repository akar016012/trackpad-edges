# Contributing to Trackpad Edges

Thank you for your interest in this project. It is maintained by one person in their spare time, so this guide explains what helps most and what to expect.

## What to expect

- The maintainer tries to reply to issues and pull requests within two weeks, and some replies may take longer.
- Bug reports that include steps to reproduce them get attention first.
- The project may decline a good idea if it does not fit the app's focus. That is a decision about scope, and it is not a judgment of your work.

## The project's focus

Trackpad Edges turns the edges and corners of a Mac trackpad into controls, and it leaves the middle of the trackpad alone. Controls move in fixed steps, and each step can be felt. Ideas that keep this simple are the most likely to be accepted, and [docs/plan.md](docs/plan.md) shows what is built and what needs a check.

## Reporting a bug

Open an issue with the bug report form. Include your Mac model, your macOS version, which trackpad you use, and the steps that cause the problem. Security problems are different, so please follow [SECURITY.md](SECURITY.md) and do not open a public issue for them.

## Suggesting a feature

Open an issue with the feature request form before you write code, so that nobody spends time on a change that cannot be accepted. Describe the problem you want to solve first, and the solution second.

## Setting up

You need a Mac with Apple silicon, a Force Touch trackpad, and Xcode 27.2 or later. The app runs on macOS 13 or later, so put any API newer than macOS 13 behind an `#available` check.

1. Clone the repository, and open `trackpad-edges.xcodeproj` in Xcode.
2. Choose your own team under **Signing & Capabilities**, and leave that change out of your pull request.
3. Run the `trackpad-edges` scheme, and grant the Accessibility permission when the app asks.

Only a copy signed with this project's Developer ID checks for updates, so a copy that you build yourself cannot replace itself with the official app.

Quit the app before you change its Accessibility permission. A running copy can hold up clicks for the whole Mac while that permission changes, and a copy paused in the debugger holds them until you resume or stop it.

To sign an installed build with your own identity, change `team` in `scripts/build-release.sh` and `signingRequirement` in `trackpad-edges/Actions/NowPlayingAdapter.swift`.

## Running the tests

The gesture and settings logic has no system dependencies, so it runs without Xcode's project:

```bash
swift test
```

Touch hardware cannot be simulated, so a change to how gestures feel also needs a try on a real trackpad. Say in your pull request what you tried.

## Making a change

- Keep a pull request to one change, and link the issue that it addresses.
- Add tests for logic in `trackpad-edges/Gestures/`, which is where decisions should live so that they can be tested.
- Update any document that your change makes out of date, in the same pull request.
- Write full sentences in documents and comments, and use American English.
- Match the formatting of the files around your change.
- Keep the window's layout on its shared margin, columns, and row heights, which are defined in `SettingsPane`.
- Pin any new GitHub Action to a full commit SHA, with its version in a comment, because the repository refuses actions that are not pinned.
- Never commit a secret, such as a certificate, a key, or a token. If one reaches a pull request, say so and treat it as exposed, because deleting it does not remove it from the history.

## How a pull request is merged

The `main` branch accepts contributions only through pull requests, and the `logic-tests` check must pass first. GitHub holds the checks on a first pull request until the maintainer approves the run, so a short wait at that point is normal. The maintainer squashes each pull request into one commit, so its title becomes the commit message and should describe the change.

Pull requests never receive the release secrets, so you can open one from a fork without any setup. The maintainer reads changes to `.github/` and `scripts/` with extra care, because those files build what people download.

## Private APIs

The app relies on private Apple frameworks, because public APIs cannot do this work. [docs/dependencies.md](docs/dependencies.md) lists every one. A public API that does the same job is always welcome as a replacement.

## License

By contributing, you agree that your contribution is licensed under the [GNU General Public License version 3](LICENSE), which is the license of this project. Everyone who takes part agrees to follow the [code of conduct](CODE_OF_CONDUCT.md).
