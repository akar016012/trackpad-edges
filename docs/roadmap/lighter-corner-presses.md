# Lighter corner presses

Status: this feature is built and confirmed working, using measurements from the phase 0 test session.

In 752 measured contacts, resting fingers and quick taps peaked near a pressure of 50, and physical clicks started near 120. The default threshold of 90 was passed by only 3 of 166 quick taps.

## Goal

A corner should fire on a light, deliberate press. Today a corner needs a firm physical click, and a light touch at the edge of the pad produces no click event at all. This feature also solves a known limit, because a tap would no longer count as a click.

## Behavior

- A finger that lands in a corner and presses past a threshold counts as one corner press.
- The press fires once, and the finger must ease off before it can count again.
- Click counts of 1 to 4 keep working within the 450 ms window.
- A haptic tick confirms each press, because a light press has no physical click to feel.
- A physical click in a corner still counts, so a firm press never fires twice.

## Settings

The Corners pane gains a **Press strength** slider. Its range and default come from the phase 0 measurements.

## Implementation plan

1. Read pressure from the touch record, which `TouchPoint.pressure` already does.
2. Add press detection to `GestureEngine`, with separate thresholds for pressing and releasing so that a wobbling finger cannot fire twice.
3. Keep the detection free of system dependencies, so that unit tests can drive it with plain values.
4. Ignore a click event that follows a detected press for the same contact.

## Risks

- Pressure may not separate a light press from a resting finger. If it does not, corners keep the firm click.
- The name and meaning of the pressure field vary between open source projects, so the measurements must confirm that it responds to force.

## Verification

- Unit tests cover the thresholds, the single firing, and the click that follows a press.
- On the trackpad, a light press fires each corner, and a resting finger and a tap do not.

## Related docs

- [corners.md](../corners.md) describes the corners today.
- [palm-detection.md](palm-detection.md) uses the same measurements.
