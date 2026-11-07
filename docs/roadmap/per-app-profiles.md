# Per-app profiles

Status: this feature is planned for phase 6. This feature comes last, because it changes how every setting is stored.

## Goal

Edges and corners should change with the app in front. For example, the bottom edge could scrub a timeline in a video editor and zoom in a design tool.

## Behavior

- The current settings become the default profile, and they apply to every app without its own profile.
- A profile overrides only the edges and corners that you change, and everything else follows the default.
- The app switches profiles as soon as the front app changes.
- A gesture in progress finishes with the profile it started with.

## Settings

The window gains a **Profiles** tab with a list of apps and an add button. The Edges and Corners panes gain a profile picker, and the menu bar item shows the active profile.

## Implementation plan

1. Split `AppSettings` into global settings and a profile of edges and corners.
2. Migrate saved settings into the default profile on first launch.
3. Watch `NSWorkspace.didActivateApplicationNotification`, and rebuild the gesture configuration when the app changes.
4. Add the Profiles tab, and make the panes edit the selected profile.

## Risks

- This changes how settings are stored, so a migration bug could lose your setup. The migration needs unit tests, and it must keep the current settings as the default profile.
- The panes must stay simple, because a picker on every pane adds clutter.
- Many apps need their own shortcuts for actions such as zoom, so a profile may need custom key combinations on edges.

## Verification

- Unit tests cover the migration, the overrides, and a profile change during a gesture.
- On the trackpad, switching apps changes what an edge does without restarting anything.

## Related docs

- [settings.md](../settings.md) describes the settings today.
- [more-edge-actions.md](more-edge-actions.md) adds the actions that profiles make most useful.
