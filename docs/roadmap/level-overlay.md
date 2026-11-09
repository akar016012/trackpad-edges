# Level overlay

Status: this feature is planned, and none of it is built yet.

## Goal

Actions that macOS shows no indicator for should show their own. Volume, brightness, and the keyboard backlight already show the system's indicator, because the app presses their keys. Monitor Brightness and Switch Apps show nothing, so a slide on them gives no sign of where it will land except the haptic tick.

## Behavior

- A Monitor Brightness slide shows the monitor's name and a stepped bar with its level.
- A Switch Apps slide shows the icon and name of the app that each step reaches, before that app comes forward.
- The overlay uses the style and position from the Media pane, as the seek preview does, and it hides shortly after the slide ends.
- VoiceOver announces each new level or app name, as it does for the backlight notice.
- Scroll and Zoom keep showing nothing, because the window under the pointer already shows the change.

## Settings

The Media pane gains a **Show levels** option, which is on by default. The pane's title could become **Overlay**, because the style and position then apply to more than media, but that is a separate decision.

## Implementation plan

1. Generalize `SeekOverlayPanel` so that it can show a title, a detail, and an optional stepped bar or icon. Its `show(title:detail:)` path is a starting point.
2. Make `ExternalDisplayController` report the level and the display name after each step. Names come from the display's own information through `NSScreen.localizedName`.
3. Make the Switch Apps step in `EdgeActions` report the app it reached.
4. Show the overlay from `GestureController` on each step, and hide it on `slideEnded` and `slideCanceled`.
5. Add the setting as an optional stored value, so that saved settings still load.

## Risks

- The overlay must never take focus, or Switch Apps would switch to the app's own panel. The seek panel is already non-activating, and this must stay true.
- A Switch Apps slide that shows the target first and switches at the end would feel different from today. The first version should keep switching on each step and only add the overlay.

## Verification

- Unit tests cover the level and name that each step reports.
- On the trackpad, a Monitor Brightness slide shows its level on a monitor that answers DDC, and a Switch Apps slide names each app.

## Related docs

- [more-edge-actions.md](more-edge-actions.md) describes both actions.
- [media-seek.md](../media-seek.md) describes the seek overlay.
- [settings.md](../settings.md) describes the Media pane.
