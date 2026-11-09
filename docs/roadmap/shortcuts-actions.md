# Shortcuts actions

Status: this feature is planned, and none of it is built yet.

## Goal

The Shortcuts app should be able to control Trackpad Edges. That lets you pause gestures from a keyboard shortcut, turn them off with a Focus, or change an edge as part of a larger automation.

## Behavior

The app offers these actions in the Shortcuts app:

| Action            | What it does                                                                   |
| ----------------- | ------------------------------------------------------------------------------ |
| Pause Gestures    | Pauses every gesture, as the menu bar item does.                               |
| Resume Gestures   | Resumes gestures after a pause.                                                |
| Toggle Gestures   | Pauses gestures if they are running and resumes them if they are paused.       |
| Get Gesture State | Returns whether gestures are paused, so that a shortcut can decide what to do. |
| Set Edge Action   | Sets one edge or two-finger slide for All Apps to an action that you choose.   |

- Each action runs without opening the window, and it starts the app in the background if it is not running.
- A pause from a shortcut shows in the menu bar item, and a resume from the menu works after it.
- Shortcuts lets you give any shortcut a keyboard shortcut, so this also gives the app a global pause key without a recorder of its own.
- Siri and Spotlight can run the same actions, because they come from the same framework.

## Settings

Nothing changes in the window. The General pane could mention that these actions exist, with a button that opens the Shortcuts app.

## Implementation plan

1. Add App Intents for each action. The framework is public and available from macOS 13, which matches the app's minimum.
2. Keep each intent thin, so that it calls into `GestureController` and `SettingsStore` on the main actor and holds no logic of its own.
3. Expose the edge slots and the edge actions as App Enums, so that Shortcuts shows them as menus.
4. Add an App Shortcuts provider with phrases for pausing and resuming, so that the actions appear without setup.
5. List the framework in [dependencies.md](../dependencies.md).

## Risks

- App Intents in an app that lives in the menu bar have not been tried in this project, and the intents must not bring the window forward.
- Set Edge Action changes the defaults, which a profile can override. The action's summary should say that it sets All Apps.

## Verification

- Unit tests cover the settings change behind Set Edge Action.
- By hand, each action works from the Shortcuts app, from a keyboard shortcut, and while the app is not running.

## Related docs

- [menu-bar-and-onboarding.md](../menu-bar-and-onboarding.md) describes the pause in the menu bar item.
- [settings.md](../settings.md) describes the edge slots.
