# Pointer freeze and click handling

Status: the pointer freeze is confirmed working on the built-in trackpad. Click handling is built, but it has not been confirmed on hardware yet.

## Pointer freeze

The pointer stays still during a slide and returns to exactly where it was. The freeze starts when the slide starts, which is at landing by default and at the physical click in click mode. The pointer stays frozen for about 0.2 seconds after a lift, because of the grace period. If a slide that changed a level is canceled, the pointer stays frozen until that finger lifts. `PointerFreeze` detaches the pointer from the mouse, which needs no permission. It also drops pointer events in an event tap, which needs the Accessibility permission.

## Click handling

A physical click cannot be stopped at the hardware. Corner clicks are held back the same way. `ClickTap` stops it reaching other apps by holding back the mouse-down event. If the click turns out to have no slide, the app replays a copy of that mouse-down just ahead of the real mouse-up, so other apps see a normal click that arrives when you release. If a slide is canceled before it moves, the app delivers the mouse-down right away, so a drag that follows stays coherent. If macOS loses a mouse-up, or if the screen locks during a click, the app clears its state and discards any mouse-up that no longer has a mouse-down.

Clicks that do not land in a zone pass through with no delay. Without the Accessibility permission, every click passes through and no gesture starts, including touch slides.

## Limits

Suppression is best effort, because touch frames and pointer events arrive independently. Apple scopes `CGAssociateMouseAndMouseCursorPosition` to a foreground app, so its behavior in a background app needs testing.

## Reliability

- The app re-enables the tap when macOS disables it for a timeout or for user input.
- A health check runs four times a second. It repairs a disabled tap, and it removes both taps if the Accessibility permission is revoked, because a tap can stall input after that.
- Both taps run on the main thread, so a long stall on that thread would delay clicks.
- An always-active tap on pointer movement can slow the cursor, so that part of the tap is enabled only during a gesture.

## Related docs

- [gestures.md](gestures.md) describes when a slide starts.
- [menu-bar-and-onboarding.md](menu-bar-and-onboarding.md) describes the Accessibility permission that the tap needs.
