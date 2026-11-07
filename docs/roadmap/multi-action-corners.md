# Multiple actions per corner

Status: this feature is planned for phase 2. This feature is simpler to finish after lighter corner presses.

## Goal

Each corner should hold a different action for each click count. For example, one click could play or pause, and two clicks could skip to the next track.

## Behavior

- Each corner has up to four actions, one for each click count from 1 to 4.
- The highest configured count fires at once, because no further click can change the result.
- A lower count waits for the 450 ms window to close, so that a single click can still become a double click.
- A corner with only one action fires at once, as it does today.

## Settings

The Corners pane shows one row for each click count in a corner, opened from a compact summary, so that the 2×2 grid stays aligned.

## Implementation plan

1. Change `CornerSetting` to hold an action for each click count, and migrate the current single action on load.
2. Teach `GestureEngine` to wait for the window to close, using the existing `tick` path.
3. Rework `CornersPane` for the extra rows, using the shared layout rules.

## Risks

- Waiting for the window adds up to 450 ms of delay to a single click whenever a higher count is configured. That is the same trade-off as a double click.
- The extra rows must fit the approved layout.

## Verification

- Unit tests cover each count, the wait, the immediate firing, and the settings migration.
- On the trackpad, one corner runs two different actions reliably.

## Related docs

- [corners.md](../corners.md) describes the corners today.
- [lighter-corner-presses.md](lighter-corner-presses.md) changes how a press is detected.
