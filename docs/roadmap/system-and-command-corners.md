# System actions and custom commands on a corner

Status: this feature was built on 2026-11-11 and is unit tested, but it needs a check on the trackpad. The plan below was written the same day. [corners.md](../corners.md) describes the feature as it is built, and the spike results below say which questions are settled.

## Spike results so far

These were checked on macOS 27.2 on 2026-11-11, in a debug build with the debug triggers that [corners.md](../corners.md) lists.

- `SACLockScreenImmediate`, `SLSGetAppearanceThemeLegacy`, `SLSSetAppearanceThemeLegacy`, and `responsibility_spawnattrs_setdisclaim` are all present. None of them has been called from a corner press yet, so question 3 is only half settled.
- A command started with `-l -c` found tools on the path from the profile file and ran in the home folder. That copy was started from the build folder, not at login, so question 6 is still open.
- A failed command showed the overlay notice with its short summary, because the debug copy had no permission for notifications. Question 5 is still open.
- Stop ended a command and the background job that it started, and a command that left a background job running did not hang the app.
- The confirm box appeared on the screen under the pointer, in front of the app window. Questions 9 and 10, the Apple event questions, the lifting finger, hotkey 175 with a real key, and the update of an installed copy are still open.

The build follows the plan, with these differences:

- The confirm box watches for the screen lock and for sleep itself, instead of hearing them from `GestureController`.
- The notification delegate is set by `FailureNotifier`, which `GestureController` installs at launch, instead of by `AppDelegate`.
- The overlay notice holds one short line, so a failure shows only its exit status there, and the last lines of error output appear only in a notification.
- The action button of the confirm box is also tinted red, because macOS 27.2 did not draw the destructive style on a plain button.
- A command stays listed, with its Stop button, until everything in its process group has ended, so that Stop can still end a job that the shell left in the background.
- Quitting the app asks every running command to end, so that no command is left that the app cannot stop.
- `docs/images/corners.png` still shows the old popup, because a new screenshot needs the app's real settings.

## Goal

A corner should be able to control the Mac itself and run anything you can type in a terminal. For example, two presses on a corner could lock the screen, and three presses could run a script that starts your work setup.

## Behavior

The corner actions gain two groups of system actions and one custom action.

| Group      | Action                | What it does                                                                       |
| ---------- | --------------------- | ---------------------------------------------------------------------------------- |
| Power      | Lock Screen           | It locks the screen at once.                                                       |
| Power      | Start Screen Saver    | It starts the screen saver.                                                        |
| Power      | Sleep Display         | It turns the displays off and leaves the Mac awake.                                |
| Power      | Sleep                 | It puts the Mac to sleep.                                                          |
| Power      | Log Out…              | It asks you to confirm, and then it logs you out.                                  |
| Power      | Restart…              | It asks you to confirm, and then it restarts the Mac.                              |
| Power      | Shut Down…            | It asks you to confirm, and then it shuts the Mac down.                            |
| System     | Toggle Dark Mode      | It switches the appearance between light and dark.                                 |
| System     | Toggle Do Not Disturb | It presses the key that you assigned to Do Not Disturb in Keyboard settings.       |
| System     | Empty Trash           | It asks Finder to empty the Trash, and Finder shows its own warning if that is on. |
| Automation | Run Command           | It runs one shell command of yours in the background, through your login shell.    |

### The confirm box

Log Out, Restart, and Shut Down never run straight from a press, because a corner can fire by accident. The app shows its own box first, and the action runs only after you click its button.

- The box asks one question, such as "Restart this Mac?", and it names the corner that asked.
- It has two buttons: one names the action (**Log Out**, **Restart**, or **Shut Down**), and the other is **Cancel**.
- Neither button is the default, so pressing Return does nothing. Escape cancels. This follows Apple's guidance that an alert should have no default button when people must read it first, and that Cancel should never be the default.
- The action button uses the destructive style, because the press may not have been deliberate.
- The box has no countdown. If nobody answers within 30 seconds, it closes and nothing happens. This is the opposite of the macOS dialog, which proceeds on its own after 60 seconds.
- A corner press never answers the box. While the box is open, another press of one of these three actions is ignored.
- The buttons take no clicks for the first second, so a click that was already on its way cannot confirm by accident.
- The box takes the keyboard without bringing the app to the front. Keys that you were typing when it appeared can therefore only cancel it, because the focus starts on Cancel and no key reaches the action button.
- The box closes without acting when the screen locks or the Mac sleeps.
- After you confirm, the app starts the action directly, with no second dialog from macOS. Apps with unsaved work can still stop a log out, a restart, or a shut down, as they can when you choose these from the Apple menu.

### Run Command

- Each click count of each corner holds one command, so a profile can override it like any other corner action.
- The command runs as `<your login shell> -l -c <command>`, with no window, with your home folder as its working folder, and with no input.
- A login shell reads your profile file, so tools that you installed are on the path. It does not read the interactive setup file, because that can be slow and can hang with no terminal.
- A command does not get the app's permissions. The app starts it in a way that makes the command answer for itself, so a command that wants to control another app or press keys must be allowed by you on its own. macOS then asks on behalf of the shell, not on behalf of Trackpad Edges. If the app cannot start a command that way, it does not run the command, and it shows a notice.
- A command has no time limit. A press while the same command is still running does not start it again, and a notice says that it is still running.
- A command that is still running can be stopped. The Corners pane shows a **Stop** button beside it, and the menu bar item shows **Stop Running Commands** while any command runs.
- If the command exits with an error, the app reports it with the last lines of its error output. It uses a notification when notifications are allowed, and it uses the app's own overlay notice otherwise.
- A corner whose command is blank stays a normal part of the trackpad, as every unfinished action does.

### Other details

- Start Screen Saver, Sleep Display, and Sleep wait about half a second after the press, so that the lifting finger does not wake the Mac again.
- Lock Screen, Start Screen Saver, Sleep Display, and Sleep are ignored for 3 seconds after the Mac wakes or unlocks. A finger that was already resting on a corner could otherwise send the Mac straight back to sleep.
- Toggle Do Not Disturb needs a one-time setup, because macOS offers apps no way to change a Focus. You assign a key to Do Not Disturb in Keyboard settings, and the app reads that key each time and presses it. Without a key, a press shows a notice that says what to set, and the Corners pane says the same.
- Lock Screen and Toggle Dark Mode each have two ways to work, and the app picks the second one by itself when the first is missing on a system. The diagnostics report says which way each one uses.
- Empty Trash follows Finder's own "Show warning before emptying the Trash" setting. If you turned that warning off, the Trash is emptied with no question.
- An older version of the app that reads these settings drops only the new actions, click by click, and keeps everything else.

## Settings

- The action popup on the Corners pane is grouped with separators and headers, because it grows from 10 items to 21. The groups are No Action, Media, Open, Automation, System, and Power.
- Log Out, Restart, and Shut Down end with an ellipsis in the popup, because they open the confirm box.
- **Run Command** reveals a monospaced text field for that corner's command, and the field fills the column. A **Stop** button appears beside it while that command runs.
- **Toggle Do Not Disturb** reveals a status line and a button that opens Keyboard settings while no key is assigned. The line is read again whenever the pane appears, so it never shows an old answer.
- The app asks for permission to show notifications when you first enter a command, because that is the moment when the reason is clear.
- macOS asks once for permission to control Finder the first time Empty Trash runs. It may ask in the same way for the power actions and for Toggle Dark Mode, which the spike will show.
- The welcome tour's short picker gains no new actions, and only its sentence about the Corners tab changes.

## Implementation plan

### 1. Spike

The spike runs on a throwaway branch, with a debug-only trigger so that it works without a trackpad. It records results on macOS 27.2 and on the oldest system within reach, and it settles these questions:

1. Does an Apple event to `loginwindow`, to Finder, or to System Events show a consent prompt, and do `kAEReallyLogOut`, `kAERestart`, and `kAEShutDown` work from this app? `AEDeterminePermissionToAutomateTarget` with `askUserIfNeeded` set to false answers the first part without side effects.
2. How does Finder's `empty` command behave with the warning on, with it off, and with an empty Trash, and does the warning open in front?
3. Does the private appearance call toggle Dark Mode on old systems, and does `SACLockScreenImmediate` work off the main thread?
4. Does a lifting finger wake the display or dismiss the screen saver, and is half a second enough?
5. Do notifications show for this menu bar app, with and without its window open?
6. What path does `-l -c` give a command when the app started at login?
7. Does symbolic hotkey 175 read and post correctly?
8. Do the Accessibility permission and an automatic update survive the build that carries the new entitlement? The test starts from a copy of version 1.3 that was installed from its release and already has the permission, and it updates that copy through a local feed.
9. Does a floating panel that does not activate the app take clicks and the Escape key while another app is in front?
10. Does a command that is started with `responsibility_spawnattrs_setdisclaim` lose the app's Accessibility and Automation permissions, and which name does macOS show when that command asks for a permission of its own?

The spike can change the plan in three places:

- Toggle Dark Mode falls back to an Apple event to System Events if the private call fails.
- Failure reports use only the overlay notice if notifications do not work.
- Run Command does not ship if a command cannot be separated from the app's permissions. The plan must then be revisited first, and the candidate is an approval for each command that is kept in the Keychain, where another process cannot change it without a system prompt.

### 2. Model, in `Gestures/`

1. Add `case system(action: SystemAction)` and `case command(script: String)` to `CornerAction` in `CornerModel.swift`. A command is configured when its trimmed text is not empty.
2. Add `SystemAction.swift` with a `String`-backed enum of the ten actions. It carries `title`, `group`, and `confirmsFirst`, and it does not carry the Apple event codes, which stay private to the one file that sends them.
3. Add `CornerActionKind.swift` as the one source of titles and groups. `CornersPane`, `DiagnosticsReport`, and `WelcomeTour` read it, which removes today's three copies of the same strings.
4. Add `ShellCommand.swift` with the logic that needs no system: the shell choice, the environment allowlist, the capped tail of the error output, and the failure summary.
5. Add `SymbolicHotKey.swift`, which parses entry 175 of `com.apple.symbolichotkeys`. Switch Spaces in `EdgeActions.swift` already reads that table.
6. Add `PowerActionGuard.swift`, which decides from the time of the last wake or unlock whether a power action may run. It holds no system calls, so unit tests cover the 3 seconds.
7. Make the diagnostics report print only "Run Command" and the action's title, never the command text. Add lines that say whether Lock Screen and Toggle Dark Mode use their first way or their second, and whether a Do Not Disturb key is set.

### 3. Signing

1. Add `Config/TrackpadEdges.entitlements` with `com.apple.security.automation.apple-events`. Apple's documentation says that an app needs this entitlement to ask for permission to send Apple events to other apps.
2. Set `CODE_SIGN_ENTITLEMENTS` in the Xcode project, and add `NSAppleEventsUsageDescription` to `Config/Info.plist`.
3. Pass `--entitlements` on the final app signature in `scripts/build-release.sh`, and make the script fail if the signed app does not show the key. Signing with `--force` and no entitlements file would strip it.

### 4. Runners, in `Actions/`

Nothing here may block the main thread, because it serves every click on the Mac and the watchdog disables the taps after a stall of 0.75 seconds.

| Action                      | Mechanism                                                                                                             |
| --------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Log Out, Restart, Shut Down | The confirm box runs first, and an Apple event then goes to `loginwindow`.                                            |
| Empty Trash                 | Finder is brought forward, and an Apple event then tells it to empty the Trash.                                       |
| Toggle Dark Mode            | The private appearance call is used if the spike confirms it, and an Apple event to System Events is the fallback.    |
| Toggle Do Not Disturb       | The app posts the key from hotkey 175 through the existing `KeyPoster`.                                               |
| Lock Screen                 | `SACLockScreenImmediate` is called off the main thread, and a posted Control-Command-Q is the fallback.               |
| Start Screen Saver          | `NSWorkspace` opens `ScreenSaverEngine.app` after the short wait.                                                     |
| Sleep, Sleep Display        | `/usr/bin/pmset sleepnow` or `displaysleepnow` runs after the short wait.                                             |
| Run Command                 | `posix_spawn` starts the login shell off the main thread, in its own process group and without the app's permissions. |

1. Add `AppleEventSender.swift`, which sends events with `NSAppleEventDescriptor.sendEvent(options:timeout:)` on one serial background queue. It drops a request while one is pending to the same target, so repeated presses cannot stack consent prompts. `NSAppleScript` is not used, because it is limited to the main thread.
2. Add `SystemActionRunner.swift`, which maps each `SystemAction` to its mechanism. It looks up the private lock and appearance calls once at launch, and it uses the second way for an action whose call is missing.
3. Add `SessionActionRunner.swift` for Log Out, Restart, and Shut Down. The three event codes and the function that sends them are private to this file, and its only entry point shows the confirm box. No other code can reach those events, so no later change can skip the box by mistake.
4. Add `CommandRunner.swift`.
   - It takes the shell from the user's account record, and it builds a clean environment from an allowlist.
   - It starts the shell with `posix_spawn`, not with `Process`, because only `posix_spawn` accepts the attribute from `responsibility_spawnattrs_setdisclaim`. That private call makes the command answer for its own permissions. The app finds the call with `dlsym`, and it refuses to run a command when the call is missing.
   - It puts the shell in its own process group, so that **Stop** can end the command and everything it started. Stop sends a terminate signal, and it sends a kill signal 2 seconds later if the command is still there, as `NowPlayingAdapter` does for its helper.
   - It drains the error output as it arrives, and it finishes when the process ends. Reading to the end of the output would hang on a command that leaves a background job running.
5. Add `FailureNotifier.swift`, which posts one notification per corner so that a new failure replaces the old one, and which falls back to `SeekController.showNotice`.
6. Extend `CornerActionRunner.swift` with the two new cases, and wire the notice and the short wait into `fireCorner` in `GestureController.swift`.
7. Record the time of each wake and unlock in `GestureController.swift`, which already hears the unlock, and ask `PowerActionGuard` before a power action runs.
8. Set the notification delegate in `AppDelegate.swift` so that a notification also shows while the window is in front, and add **Stop Running Commands** to the menu bar item while a command runs.

### 5. Confirm box, in `UI/`

1. Add `ConfirmationPanel.swift`, a small floating panel that is not modal. `NSAlert` is not used, because `runModal()` runs a modal loop on the main thread and a sheet needs a window to attach to.
2. Build it as an `NSPanel` with the `nonactivatingPanel` style, and show it on the screen that holds the pointer, in front of other windows. Such a panel can take the keyboard without activating the app. The app therefore never asks macOS for activation, which is only a request from macOS 14 on and could be refused.
3. Give the box no default button, make Escape cancel, and put the keyboard focus on Cancel.
4. Turn both buttons on 1 second after the box appears.
5. Close the box after 30 seconds, on screen lock, and on sleep, each time without acting. `GestureController.observeLocking` already hears the lock.
6. Keep the question and the button titles in `SystemAction`, so that unit tests cover the text.

### 6. Settings UI, in `Settings/`

1. Add `groupedPopup` to `SettingsPane.swift`. It maps items by tag, not by position, and it adds separators and headers. `NSMenuItem.sectionHeader(title:)` exists from macOS 14, so the macOS 13 fallback that `AppDelegate.swift` already has moves into one shared helper.
2. Switch `CornersPane.swift` to the grouped popup. Three places there treat the menu position as the action today, and all three change to tags.
3. Add the command field, its Stop button, and the Do Not Disturb status line to the detail row, and give `textField` a width parameter.
4. Read the shared titles in `WelcomeTour.swift`, and update its sentence about the Corners tab.

### 7. Docs, in the same change

- Action lists: [corners.md](../corners.md), `README.md`, both corner passages of the landing page (with no tool or library names), and [welcome-tour.md](../welcome-tour.md).
- Reference: [dependencies.md](../dependencies.md) for the new private symbols, `pmset`, the login shell, Apple events, and notifications, then [settings.md](../settings.md), the permissions table in [menu-bar-and-onboarding.md](../menu-bar-and-onboarding.md), and [plan.md](../plan.md).
- `SECURITY.md` must say that a corner can run a shell command, that the command runs as you but without the app's Accessibility and Automation permissions, and that anything able to change the app's saved settings can therefore run a command on the next press.
- [settings-backup.md](settings-backup.md) must say that an import shows each command in full and keeps imported commands off until you confirm them.
- `CHANGELOG.md` gains entries under Unreleased, and `docs/images/corners.png` needs a new screenshot.
- The release notes say what to do if the Accessibility permission is lost after the update, but only if the spike shows that this can happen.

## Risks

Each risk has a safeguard in the plan above. The last column says what the safeguard does not cover.

| Risk                                                                                              | Safeguard                                                                                                                                                                                | What remains                                                                                                                |
| ------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| Log Out, Restart, and Shut Down act at once, so a path around the confirm box would be dangerous. | The event codes are private to one file whose only entry point shows the box. The buttons wait 1 second, no key reaches the action button, and the box closes without acting.            | An app with unsaved work can still be asked to quit after a deliberate confirm, as it is from the Apple menu.               |
| The new entitlement could cost the Accessibility permission or break an automatic update.         | macOS should tie both to the bundle identifier and the signing team, which do not change. The spike proves this on an installed copy of version 1.3 before any release.                  | If the spike fails, the release notes carry the steps, and the app already opens its window when the permission is missing. |
| A private lock or appearance call can disappear in a later macOS.                                 | The app looks each call up at launch and uses the second way when it is missing. The diagnostics report says which way is in use.                                                        | The second way to lock presses Control-Command-Q, which fails if you changed that system shortcut.                          |
| Run Command lets saved settings run code, which could borrow the app's permissions.               | A command starts without the app's permissions, and it does not run at all if that cannot be done. The report never prints a command, and a settings import never turns one on silently. | Anything that can change the saved settings can still run a command as you, which it could already do without the app.      |
| A command that never exits blocks later presses of the same command.                              | A notice says that the command is still running, and **Stop** in the pane or in the menu bar ends the command and everything it started.                                                 | A command that you leave running keeps running until you stop it or it ends.                                                |
| Toggle Do Not Disturb depends on a key that you set, and macOS can change its hotkey table.       | The app reads the key on every press and whenever the pane appears. A missing key shows a notice with the fix, and the report says whether a key is set.                                 | If macOS removes the entry, the action stops working, and Press Keys or Run Shortcut can replace it.                        |
| macOS may refuse to bring the app to the front, so the confirm box could miss the keyboard.       | The box is a panel that takes the keyboard without activating the app, so it never asks for activation.                                                                                  | The spike must confirm this on macOS 13 and on macOS 27.                                                                    |
| A finger that rests on a corner during a wake could send the Mac back to sleep or lock it again.  | The four power actions that need no confirmation are ignored for 3 seconds after a wake or an unlock.                                                                                    | A deliberate press in those 3 seconds is also ignored.                                                                      |

## Verification

- Unit tests cover these points:
  - Both new actions survive saving, and their saved form is pinned.
  - An unknown system action loads as no action while the corner's other clicks survive.
  - A blank command does not count as configured.
  - Log Out, Restart, and Shut Down confirm first, and no other action does.
  - A power action is refused within 3 seconds of a wake or an unlock and allowed after that.
  - Every title is unique and has no slash.
  - The shell choice, the environment allowlist, the tail cap, and the failure summary behave as described.
  - Hotkey parsing handles an enabled entry, a disabled entry, an unset key, and malformed data.
  - The report leaves out a command that the fixture contains.
- `codesign -d --entitlements -` shows the Apple events key on the app that `scripts/install.sh` builds.
- On the trackpad, each action fires from one press and from two presses, clicks elsewhere keep working while a consent prompt or the confirm box is open, and the log shows no watchdog trip.
- The confirm box does nothing on Return, cancels on Escape, closes by itself after 30 seconds, and ignores a second corner press. A click in its first second does nothing, and typing in another app when it appears never confirms it.
- A search of the source finds the three session event codes in `SessionActionRunner.swift` only.
- Denying the permission to control Finder produces a clear notice, not silence.
- A failing command is reported, and a command that starts a background job does not hang the app.
- A command that tries to control another app or press keys is not allowed silently, and macOS asks on behalf of the shell.
- **Stop** ends a command that sleeps forever and a job that it started, from the pane and from the menu bar.
- A press with no Do Not Disturb key shows the notice, and the report shows which way Lock Screen and Toggle Dark Mode use.
- A finger held on a Sleep corner through a wake does not put the Mac back to sleep.
- A copy of version 1.3 that updates to this build keeps its Accessibility permission.
- Settings saved by this build load in version 1.3 with only the new clicks dropped.
- The popup and the detail rows stay aligned on macOS 13 and on macOS 14 or later.

## Related docs

- [corners.md](../corners.md) describes the corners today.
- [multi-action-corners.md](multi-action-corners.md) describes click counting, which decides when an action fires.
- [corner-hold.md](corner-hold.md) describes the planned hold action, which these actions could also use.
- [settings-backup.md](settings-backup.md) describes the planned import, which must treat commands with care.
- [dependencies.md](../dependencies.md) lists every framework, private symbol, and system tool.
- Apple documents the [Apple Events entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.automation.apple-events), the [guidelines for alerts](https://developer.apple.com/design/human-interface-guidelines/alerts), [cooperative activation](https://developer.apple.com/documentation/appkit/passing-control-from-one-app-to-another-with-cooperative-activation), and [asking permission to use notifications](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications).
