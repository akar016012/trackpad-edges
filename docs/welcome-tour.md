# Welcome tour

Status: the tour is built and confirmed working, but it has not been walked through from a clean install.

## Goal

Someone who has just downloaded the app should be able to grant the permission, feel a first slide, and choose their setup without reading anything else.

## Behavior

The tour opens by itself on the first launch of a new install. It has seven steps, and every control except the link to the project changes the real settings.

| Step            | What it does                                                                                                                                                                        |
| --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Welcome         | The step explains what the app does.                                                                                                                                                |
| Permission      | The step shows live whether Accessibility is on, and it opens the system prompt.                                                                                                    |
| First slide     | A live diagram shows your fingers, and the step confirms your first real slide.                                                                                                     |
| Edges           | You pick Everyday, Browsing, or Volume Only as a starting point, and then change any edge.                                                                                          |
| Corners         | You choose a simple action for each corner. A corner set up in more detail keeps its setup unless you change it.                                                                    |
| Haptics         | You turn the tick on or off, set its strength and pattern, and try it.                                                                                                              |
| You are all set | You choose whether the app starts at login, and the step says where the settings live. **Star on GitHub** opens the project page, because GitHub cannot star a project from a link. |

A preset leaves an edge off when its action cannot work on this Mac. Closing the window or choosing **Skip Tour**, which every step but the last offers, ends the tour, and it does not open by itself again.

## When it opens

`WelcomeProgress` decides this. A new install has no saved settings, so the tour opens and stays pending until you finish or close it. A copy with saved settings already belongs to someone who knows the app, so the tour stays closed. The tour should not open when the app starts at login, but that has not been confirmed with a real login. An existing user who never changed a setting sees the tour once, because settings are saved only after a change.

You can take the tour again from the General pane or the menu bar item. Opening it closes the app window, because both edit the same settings.

## Related docs

- [menu-bar-and-onboarding.md](menu-bar-and-onboarding.md) describes the permission.
- [settings.md](settings.md) describes every setting that the tour touches.
