# Press Keys on an edge

Status: this feature is planned, and none of it is built yet.

## Goal

An edge should be able to press a key combination on each step, with one combination for each direction. This turns any app's keyboard shortcuts into a slide. For example, an edge could switch browser tabs with Control-Tab and Control-Shift-Tab, step through video frames with the arrow keys, or walk back through undo history with Command-Z and Command-Shift-Z.

## Behavior

- A new **Press Keys** action joins the edge popups. It needs two recorded combinations: one for a slide up or to the right, and one for a slide down or to the left.
- Each step presses one combination and gives a haptic tick, as volume does.
- A step takes the same travel as Zoom, because each key press usually makes one discrete change.
- An edge whose combinations are not both recorded stays a normal part of the trackpad, as a corner with nothing recorded does today.
- The keys go to the app in front, so this action works best inside a [per-app profile](per-app-profiles.md).
- The action has no limit, so the limit haptic never plays for it.

## Settings

When an edge is set to Press Keys, a small **Keys** button appears beside its popup. The button opens a popover with two shortcut recorders, labeled **Up or right** and **Down or left**, so the pane's rows and columns stay the same size. The recorders reuse `KeyRecorderButton`, so they accept any combination, including the left or right modifier. The menu bar item lists the action, but recording keys needs the window.

The combinations belong to the edge slot, so a profile can give the same edge different keys in each app.

## Implementation plan

1. Add `pressKeys` to `SlideKind`, so that saved values stay compatible.
2. Add an optional `EdgeKeys` value for each edge slot in `AppSettings`, holding the two recorded combinations. Older settings decode with no keys.
3. Carry the keys through `EdgeChoice`, so that a profile can override them along with the action, and make `resolved(for:)` lay them over the defaults.
4. Make `EdgeActions.step` press the matching combination through `KeyPoster.press`, which already marks synthesized events so that the event tap ignores them.
5. Add the Keys button and popover to `EdgesPane`, and dim the action in the menu bar item until both combinations exist.

## Risks

- Keys that macOS keeps for itself, such as Command-Tab, may not behave the same when they repeat quickly. The first build should test a fast slide with those keys.
- A fast slide can send many presses in a row. If an app falls behind, the slide could overshoot, so steps may need a short minimum gap.
- A combination can do something destructive in the wrong app, which is one reason the popover should show which apps the edge applies to.

## Verification

- Unit tests cover decoding settings that have no keys, the profile override, and the choice of combination for each direction.
- On the trackpad, an edge switches tabs in a browser and steps frames in a video player, and a half-recorded edge stays normal.

## Related docs

- [more-edge-actions.md](more-edge-actions.md) describes the other step actions.
- [corners.md](../corners.md) describes the shortcut recorder.
- [per-app-profiles.md](per-app-profiles.md) describes how slots are overridden.
