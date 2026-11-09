# Hold a corner

Status: this feature is planned, and none of it is built yet.

## Goal

Each corner should be able to hold one more action for a press that is held down. For example, one press could play or pause, and a held press could open the music app.

## Behavior

- A press that stays down for 0.5 seconds fires the corner's hold action, and a firmer haptic confirms it.
- A hold counts only as the first press in a corner. Once a press has counted, a long press counts as an ordinary press, so a slow double click still works.
- A held press does not also count as a click, and the corner's click actions do not fire for it.
- A corner with a hold action cannot fire its single press until the finger lifts or the hold time passes, whichever comes first. A corner without a hold action keeps firing as it does today.
- A physical click that is held counts as a hold too, and its click still never reaches other apps.

## Settings

The clicks popup on the Corners pane gains a **Hold** item after the four click counts. Choosing it makes the action popup edit the hold action, so the 2×2 grid needs no extra rows. A dot marks it when it has an action, as the counts do. A hold action belongs to a corner slot, so a profile can override it.

## Implementation plan

1. Add an optional hold action to `CornerSetting`, so that saved settings still load.
2. Teach `GestureEngine` to record when a press began, and to emit a new `cornerHeld(Zone)` event from `tick` when the press has lasted 0.5 seconds. The release then ends the press without counting it.
3. Make a corner with a hold action defer its first count until release, using the existing settle path for the wait.
4. Add the Hold item to the clicks popup in `CornersPane`, and include it in the profile override.
5. Give the hold its own haptic in `HapticEngine`, so that it feels different from a press.

## Risks

- A corner with a hold action adds a short delay to a single press, up to the time of the release. That is a smaller cost than the wait for a double click, but it can still feel slower.
- A finger that rests on a corner while reading could fire a hold. The pressure threshold should prevent this, because a resting finger stays below it, but this needs a check on the trackpad.

## Verification

- Unit tests cover a hold, a short press beside a hold action, a long second press, a held physical click, and decoding settings with no hold action.
- On the trackpad, a hold fires reliably, and a quick press on the same corner still fires its click action.

## Related docs

- [corners.md](../corners.md) describes the corners today.
- [multi-action-corners.md](multi-action-corners.md) describes click counting.
- [lighter-corner-presses.md](lighter-corner-presses.md) describes how a press is detected.
- [haptics.md](../haptics.md) describes the haptic events.
