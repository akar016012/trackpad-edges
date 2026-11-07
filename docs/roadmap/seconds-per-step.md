# Seconds per step

Status: this feature is planned for phase 2.

## Goal

A percentage step grows with the track, so 1% is about 5 seconds on a short video and 72 seconds on a 2-hour film. This feature lets you choose a fixed time per step, so a step feels the same on anything.

## Behavior

- Each step moves either a percentage of the track or a fixed number of seconds.
- Everything else about seeking stays the same, including the haptic tick on each step and the preview.

## Settings

The Media pane gains a **Step type** popup with **Percent** and **Seconds**. The step slider then covers 1 to 60 seconds, with a default of 5 seconds.

## Implementation plan

1. Add the step type and the seconds value to `AppSettings`, stored as optional values so that saved settings still load.
2. Give `SeekController` one step length in seconds, worked out from the setting and the track length.
3. Update `MediaPane` so that the labels and the summary match the chosen type.

## Risks

This feature carries little risk, because `SeekScrubber` already counts whole steps and does not depend on what a step means.

## Verification

- Unit tests cover the step length for both types.
- On the trackpad, a 5-second step moves 5 seconds on both a short and a long video.

## Related docs

- [media-seek.md](../media-seek.md) describes seeking today.
