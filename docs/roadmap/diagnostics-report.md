# Diagnostics report

Status: this feature is planned, and none of it is built yet.

## Goal

A bug report should carry the facts that the maintainer needs, without the reporter having to look them up. All testing so far has used built-in trackpads on macOS 27.2, so reports from external trackpads and earlier systems are the most valuable ones, and they are also the hardest to read without details.

## Behavior

- **Copy Diagnostics** puts a plain-text report on the clipboard, and **Report a Problem…** copies the same report and opens a new GitHub issue, so that you can paste it into the form.
- The report lists the app version, the macOS version, the Mac model, each trackpad found with its family ID and whether it is built in, the Accessibility state, whether the media adapter loaded, and each action that is dimmed with the reason.
- The report includes a summary of the settings, such as each edge's action and each corner's action type. It leaves out file paths, links, app names, recorded key labels, and shortcut names, because those can be personal.
- **Record Touches…** records 10 seconds of touch data to a file that you can attach to the issue. The file holds positions, pressure, and contact size, and nothing else. This helps set thresholds on trackpads that the project has never tried.
- Nothing is ever sent by the app. You read the report and choose whether to share it.

## Settings

The General pane gains a **Diagnostics** row with **Copy Diagnostics** and **Record Touches…**. The menu bar item gains **Report a Problem…** beside **Release Notes**, and it opens the bug report.

## Implementation plan

1. Make `MultitouchBridge` keep the family ID and the built-in flag for each device it opens, since it already reads the family ID to skip touch mice.
2. Build the report in a new type with no system calls in its formatting, so that unit tests can check what it includes and what it leaves out.
3. Read the Mac model from `sysctlbyname("hw.model")`, and read the reasons for dimmed actions from the same checks that dim them.
4. Record touches by copying the frames that `GestureController` already receives, for a fixed time, into a small JSON file.
5. Add a **Diagnostics** field to the bug report template in `.github/ISSUE_TEMPLATE/bug_report.yml`. The app opens the empty form and leaves the report on the clipboard, because a report can be too long for a URL, and the report should not travel in one.
6. Describe the report, and everything it leaves out, in [settings.md](../settings.md).

## Risks

- A report must never include a secret or a personal path by accident. A unit test should fail if a path, link, or name from the settings appears in it.
- Touch recordings are large if they run long, so the recording stops by itself after 10 seconds.

## Verification

- Unit tests cover the report's fields, what it leaves out, and the recording format.
- By hand, the report opens in a new issue, and a recording can be attached and read.

## Related docs

- [gestures.md](../gestures.md) describes the trackpads that the app skips.
- [palm-detection.md](palm-detection.md) and [lighter-corner-presses.md](lighter-corner-presses.md) describe the thresholds that recordings help tune.
- [dependencies.md](../dependencies.md) lists the private framework that reads touches.
