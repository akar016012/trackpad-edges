# Corners

Status: the corners, their actions, light presses, and the shortcut recorder are built and confirmed working on the built-in trackpad. The system actions and Run Command were added on 2026-11-11 and need a check on the trackpad, as the [roadmap plan](roadmap/system-and-command-corners.md) describes.

All four corners respond to 1 to 4 clicks. A corner with no action stays a normal part of the trackpad, and so does a corner whose action is not finished, such as Press Keys with nothing recorded.

## Actions

Each corner can do one of these things:

- It can mute or unmute the sound.
- It can play or pause media, or skip to the next or previous track, in whichever app is playing.
- It can open an app, and clicking again hides that app.
- It can open an `http` or `https` link in a browser you choose.
- It can open a file or a folder.
- It can press any key combination, including ones that macOS normally keeps for itself, such as Command-Space and Command-Tab, and modifiers alone, including fn. While you record, an event tap sees keys before macOS does and holds them back, so the shortcut does not also run. Escape cancels recording, so Escape itself cannot be recorded. The recorder keeps the exact side of each modifier, so `Right ⌘ Space` sends the right Command key. A shortcut recorded before this existed sends the left key.
- It can run a shortcut from the Shortcuts app in the background.
- It can run one shell command of yours in the background, through your login shell.
- It can lock the screen, start the screen saver, turn the displays off, or put the Mac to sleep.
- It can log out, restart, or shut down the Mac, but only after you confirm it in a box.
- It can toggle Dark Mode, toggle Do Not Disturb, or empty the Trash.

The action popup groups these under No Action, Media, Open, Automation, System, and Power. Log Out, Restart, and Shut Down end with an ellipsis, because they open the confirm box.

## The confirm box

Log Out, Restart, and Shut Down never run straight from a press, because a corner can fire by accident. The app shows its own box first, and the action runs only after you click its button.

- The box asks one question, such as "Restart this Mac?", and it names the corner that asked.
- It has a **Cancel** button and a button that names the action, which is drawn in red. Neither is the default, so Return does nothing, and Escape cancels.
- The buttons take no clicks for the first second, so a click that was already on its way cannot confirm by accident.
- The box takes the keyboard without bringing the app to the front. The focus starts on Cancel, and no key can press the action button, so keys that you were typing when the box appeared can only cancel it. With Full Keyboard Access and no VoiceOver, the action button therefore needs a click. VoiceOver can still press it.
- If nobody answers within 30 seconds, the box closes and nothing happens. It also closes without acting when the screen locks or the Mac sleeps.
- While the box is open, another corner press of these three actions is ignored, so a corner can never answer it.
- After you confirm, the request goes straight to macOS with no second dialog. Apps with unsaved work can still stop a log out, a restart, or a shut down, as they can when you choose these from the Apple menu.

## Run Command

- Each click count of each corner holds one command, so a profile can override it like any other corner action. A command that is blank leaves the corner a normal part of the trackpad.
- The command runs as `<your login shell> -l -c <command>`, with no window, no input, and your home folder as its working folder. A login shell reads your profile file, so the tools that you installed are on the path.
- A command does not get the app's permissions. It starts in a way that makes it answer for its own permissions, so a command that wants to control another app or press keys needs your permission on its own. If macOS cannot start a command that way, the app does not run it and shows a notice.
- A command has no time limit. A press while the same command is still running does not start it again, and a notice says that it is still running.
- **Stop** appears beside the command field while that command runs, and the menu bar menu shows **Stop Running Commands** while any command runs. Stop ends the command and everything that it started in its process group, including a job that it left running in the background. A command counts as running until everything in that group has ended, so a press does not start a second copy while its background job runs. The Stop button follows the text in the field, so after you edit a running command, only the menu bar item can stop the old one. Stop cannot end a process in that group that runs as another user, such as one started with `sudo`, so that command stays listed until the process ends by itself.
- Quitting the app asks every running command to end.
- If a command fails, the app reports its exit status and the last lines of its error output in a notification. Without permission for notifications, the overlay notice shows a short summary instead. A command that you stopped is not reported.
- The app asks for permission to show notifications when you first enter a command.

## System actions

- Start Screen Saver, Sleep Display, and Sleep wait half a second after the press, so that the lifting finger does not wake the Mac again.
- Lock Screen, Start Screen Saver, Sleep Display, and Sleep are ignored for 3 seconds after the Mac wakes or unlocks, so that a finger that was already resting on a corner cannot send the Mac straight back to sleep.
- Toggle Do Not Disturb needs a one-time setup, because macOS offers apps no way to change a Focus. You assign a key to "Turn Do Not Disturb On/Off" in Keyboard settings, under Keyboard Shortcuts and Mission Control, and the app reads that key on each press and presses it. Without a key, a press shows a notice, and the Corners pane offers a button that opens Keyboard settings.
- Empty Trash brings Finder forward and asks it to empty the Trash, so Finder shows its own warning if that is on. If you turned the warning off in Finder's settings, the Trash is emptied with no question.
- macOS asks once for permission to control Finder the first time Empty Trash runs. If you deny it, a press shows a notice that says where to allow it.
- Lock Screen and Toggle Dark Mode each have two ways to work, and the app uses the second when the first is missing on a system. The diagnostics report says which way each one uses.
- An older version of the app that reads these settings drops only the new actions, click by click, and keeps everything else.

## Click counting

A light press fires a corner, with no physical click needed, and a haptic confirms each press. The **Press** slider on the Corners pane sets how light. A physical click also counts, and it never counts twice with a press. Each corner can hold a different action for each click count from 1 to 4. Presses must fall within 450 ms of each other. The highest configured count fires at once. A lower count waits for that window to close, so a single click only waits if the corner also has a higher count. Clicks in a corner that has an action never reach other apps, even if the count is not reached.

## Defaults

The top-left corner mutes by default, and the other corners have no action until you choose one. A bottom corner with an action takes over that part of the bottom strip and the lowest part of the side strip beside it, and a bottom corner with no action leaves the strips as they were.

## Implementation notes

Apps are opened through `NSWorkspace`, and key combinations are synthesized with `CGEvent`, which requires the Accessibility permission. Synthesized events are marked so that the app's own event tap ignores them.

`CornerActionKind` is the one place that names each action and its group, and the Corners pane, the welcome tour, and the diagnostics report all read it. The popup finds each item by its tag, because the headers and separators shift the positions.

- `SystemActionRunner` carries out the system actions that need no confirmation. Lock Screen calls `SACLockScreenImmediate` off the main thread and falls back to pressing Control-Command-Q. Toggle Dark Mode calls `SLSGetAppearanceThemeLegacy` and `SLSSetAppearanceThemeLegacy` and falls back to an Apple event to System Events. The screen saver opens `ScreenSaverEngine.app`, and the two sleep actions run `/usr/bin/pmset sleepnow` or `displaysleepnow`. Toggle Do Not Disturb reads entry 175 of `com.apple.symbolichotkeys` and posts that key.
- `SessionActionRunner` is the only code that holds the event codes for logging out, restarting, and shutting down, and its only entry point shows `ConfirmationPanel`. After you confirm, it sends `kAEReallyLogOut`, `kAERestart`, or `kAEShutDown` to `loginwindow`.
- `AppleEventSender` sends every Apple event on one background queue and drops a request while another one to the same app is waiting, so repeated presses cannot stack consent prompts.
- `CommandRunner` starts the shell with `posix_spawn` off the main thread, in its own process group, with a clean environment from an allowlist. The private call `responsibility_spawnattrs_setdisclaim` makes the command answer for its own permissions, and the app refuses to run a command when that call is missing. Stop sends a terminate signal to the process group and a kill signal 2 seconds later if it is still there. The app reads the error output as it arrives and stops reading at its end, and it reports the result when the shell ends, so a command that leaves a background job running cannot hang it. It then checks once a second until the process group is empty, and only then removes the Stop button.
- `FailureNotifier` posts one notification for each corner, so a new failure replaces the old one, and it falls back to the overlay notice.
- `PowerActionGuard` decides from the time of the last wake or unlock whether a power action may run.

Debug builds accept three launch arguments for trying these without a trackpad. `-debugConfirm YES` shows the confirm box, and confirming it only shows a notice. `-debugCommand '<command>'` runs a command as the top-left corner would, and `-debugStopAfter 3` stops every command after that many seconds.

## Haptics

A haptic confirms each press. An action that fires after the click window closes adds no second haptic, because its press was already confirmed. See [haptics.md](haptics.md).

## Related docs

- [settings.md](settings.md) describes the per-corner options.
- [pointer-freeze.md](pointer-freeze.md) describes how corner clicks are kept out of other apps.
- [system-and-command-corners.md](roadmap/system-and-command-corners.md) holds the plan for the system actions and Run Command, with what still needs a check.
