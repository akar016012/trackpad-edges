# Menu bar and onboarding

Status: the menu bar item and the first-run steps are built. Their layout has been inspected, but the first-run flow has not been confirmed from a clean install.

## Menu bar

The app has a window and a menu bar item, and it keeps running in the menu bar after the window closes. The menu shows how many trackpads were found, offers the Accessibility prompt, assigns each edge, pauses gestures, opens the window, and quits the app.

## First-run guide

The window opens on the General pane whenever the Accessibility permission is missing. That pane explains the permission and how to try a gesture. The app tries to skip the window when it starts at login, but that has not been confirmed with a real login.

## Permissions

| Capability                       | Permission needed                  |
| -------------------------------- | ---------------------------------- |
| Reading touches                  | None, but App Sandbox must be off. |
| Event tap and synthesized events | Accessibility                      |
| AppleScript seek fallback        | Automation, once per app           |

## Rebuilds

macOS can drop the Accessibility grant when an app's signature changes. The app uses a fixed bundle identifier and a stable signing identity to avoid that. If the switch looks on but access is denied, you should remove the app from the Accessibility list and add it again.

## Related docs

- [pointer-freeze.md](pointer-freeze.md) describes what the Accessibility permission is used for.
- [settings.md](settings.md) describes the settings window.
