# Menu bar and onboarding

Status: the menu bar item is built. The first-run guide is not built yet.

## Menu bar

The app runs as a menu bar item. The menu shows how many trackpads were found, offers the Accessibility prompt, pauses gestures, and quits the app.

## First-run guide

The guide appears on first launch. It asks for the Accessibility permission, asks what the top-right corner should do, and lets you try each gesture on your own trackpad.

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
