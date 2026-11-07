# Per-app profiles

Status: this feature is built and unit tested, but it has not been confirmed on the trackpad yet.

## Goal

Edges and corners should change with the app in front. For example, the bottom edge could scrub a timeline in a video editor and zoom in a design tool.

## Behavior

- The current settings become the default profile, and they apply to every app without its own profile.
- A profile overrides only the edges and corners that you change, and everything else follows the default.
- The app switches profiles as soon as the front app changes.
- A slide in progress finishes with the profile it started with. A corner that is still counting clicks uses the profile in front when it fires.

## Settings

The window has a **Profiles** tab with a list of apps, and it shows what each profile changes. Once an app has a profile, the Edges and Corners panes show an **Applies to** picker, and the choice there follows from one pane to the other. The menu bar item shows the profile in use. Its edges are labeled **Edges for All Apps**, because they always assign the defaults, whatever app is in front.

Only edges and corners belong to a profile. Edge width, sensitivity, the required key, the options, press strength, media, and haptics apply to every app, even when a profile is selected on the pane.

## How it works

1. The stored edges and corners stay where they were, and they are the default profile. Saved settings therefore need no conversion, and `SettingsModel.swift` only adds a list of `AppProfile` values.
2. An `AppProfile` stores only the slots that differ. An edge override wraps its value in `EdgeChoice`, so that Off differs from a slot that the profile leaves alone.
3. `resolved(for:)` lays a profile over the defaults, and `apply(_:toProfile:)` saves an edit. An edit touches only the slots that changed, and a slot set back to its default value stops being an override, so it follows the default again.
4. `GestureController` watches `NSWorkspace.didActivateApplicationNotification`, and it rebuilds the gesture configuration only when the profile in use changes.
5. A slide keeps the action it started with, because `GestureEngine` holds that action until the slide ends.

## Limits

- The window itself counts as the app in front, so a profile cannot be tried while its app is behind the window.
- Many apps need their own shortcuts for actions such as zoom, so a profile may later need custom key combinations on edges.
- A profile is matched by bundle identifier, so an app that changes its identifier needs a new profile.

## Verification

- Unit tests cover loading older settings, overrides, clearing an override, and a profile change during a slide.
- On the trackpad, switching apps should change what an edge does without restarting anything.

## Related docs

- [settings.md](../settings.md) describes the settings today.
- [more-edge-actions.md](more-edge-actions.md) adds the actions that profiles make most useful.
