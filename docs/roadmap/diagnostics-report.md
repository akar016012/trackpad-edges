# Diagnostics report

Status: this feature is built and unit tested, and the layout of the General pane has been inspected. The buttons have not been used in the running app yet, so no report has been pasted into a real issue and no recording has been saved. It ships in version 1.3.

## Goal

A bug report should carry the facts that the maintainer needs, without the reporter having to look them up. All testing so far has used built-in trackpads on macOS 27.2, so reports from external trackpads and earlier systems are the most valuable ones, and they are also the hardest to read without details.

## Behavior

- **Copy Diagnostics** puts a plain-text report on the clipboard, and **Report a Problem…** copies the same report and opens a new GitHub issue, so that you can paste it into the form.
- The report lists the app version, the macOS version as plain numbers with its build, the Mac model, each trackpad found with its family ID and whether it is built in, the Accessibility state, whether the app is watching clicks, whether gestures are paused, whether the media adapter loaded, and each action that is dimmed with the reason.
- The report includes a summary of the settings, such as each edge's action and the kind of action on each corner click. A profile is listed by its number with the edges and corners that it changes.
- The report leaves out file paths, links, app names, bundle identifiers, recorded key labels, and shortcut names, because those can be personal.
- **Record Touches…** explains what it records and then records 10 seconds of touch data. Gestures keep working during the recording. When it ends, the app asks where to save the file and shows it in the Finder, so that you can attach it to the issue. This helps set thresholds on trackpads that the project has never tried.
- Nothing is ever sent by the app. You read the report and choose whether to share it.

## The recording file

The file is compact JSON with these values, and it holds nothing else.

| Value       | Meaning                                                                                                   |
| ----------- | --------------------------------------------------------------------------------------------------------- |
| `version`   | This number is 1, and it changes if the format does.                                                      |
| `trackpads` | Each trackpad has its `familyID` and `isBuiltIn`, and a value that the system did not give is left out.   |
| `frames`    | Each frame has its `time` in seconds since the recording began, its `trackpad` index, and its `contacts`. |
| `contacts`  | Each contact has the framework's `id` for it, and its `x`, `y`, `pressure`, `size`, and `majorAxis`.      |

Positions are fractions of the pad with the origin at the bottom-left corner. A frame with no contacts is kept, because it shows when a finger lifted. Values are rounded, and the recording stops at 5,000 frames, so the file stays small.

## Settings

The General pane has a **Report a problem** section. Its **Diagnostics** row holds **Copy Diagnostics** with **Record Touches…** beneath it, because the two buttons are too wide to share one row of the pane's form. A line beneath them says what just happened. The menu bar item has **Report a Problem…** after **Release Notes**.

## How it works

1. `MultitouchBridge` keeps the family ID and the built-in flag for each device that it opens, in `deviceInfo`. The built-in flag comes from `MTDeviceIsBuiltIn`.
2. `DiagnosticsReport` in `Gestures/` formats the report with no system calls, so that unit tests can check what it includes and what it leaves out.
3. `GestureController` gathers the facts. It reads the Mac model from `sysctlbyname("hw.model")` and the build from `kern.osversion`, and it reads the dimmed actions from the same checks that dim them.
4. `GestureController` copies each raw frame from the framework into a `TouchRecording` for 10 seconds. Frames that the health check makes up for a lost finger are not recorded. A recording ends early if the trackpads are listed afresh, such as after a wake.
5. The bug report form in `.github/ISSUE_TEMPLATE/bug_report.yml` has a **Diagnostics** field. The app opens the empty form and leaves the report on the clipboard, because a report can be too long for a link, and the report should not travel in one.

## Risks

- A report must never include a secret or a personal path by accident. A unit test fails if a path, link, or name from the settings appears in it, or even a part of one.
- **Report a Problem…** replaces whatever was on the clipboard. The menu item's tooltip says that it copies the report.
- A recording is lost if the app window is replaced by the welcome tour while it runs. A new recording ends one that is still running, so each one gets its full time.
- The save panel can open behind another app, because the recording runs while you use the trackpad elsewhere. The app asks for attention in the Dock and tells VoiceOver that the recording is over, but that has not been tried yet.

## Verification

- Unit tests cover the report's fields, what it leaves out, and the recording format.
- By hand, the report should paste into a new issue, and a recording should attach and read back. Neither has been tried yet.

## Related docs

- [settings.md](../settings.md) describes the General pane.
- [gestures.md](../gestures.md) describes the trackpads that the app skips.
- [palm-detection.md](palm-detection.md) and [lighter-corner-presses.md](lighter-corner-presses.md) describe the thresholds that recordings help tune.
- [dependencies.md](../dependencies.md) lists the private framework that reads touches.
