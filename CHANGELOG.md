# Changelog

## Unreleased

- A corner can now lock the screen, start the screen saver, turn the displays off, put the Mac to sleep, or log out, restart, or shut down. Logging out, restarting, and shutting down always ask you to confirm in a box first.
- A corner can toggle Dark Mode, toggle Do Not Disturb, or empty the Trash. Do Not Disturb needs a key that you assign in Keyboard settings.
- A corner can run a shell command in the background. A running command can be stopped from the Corners pane or the menu bar, and a failed command is reported with its last lines of error output.
- The corner action popup is grouped under headers.
- The diagnostics report says which way Lock Screen and Toggle Dark Mode use, and whether Do Not Disturb has a key. It never includes a command.

## 1.3 - 2026-11-09

- A finger that rests on an edge without sliding now gives the pointer back after 0.6 seconds.
- The menu bar menu has a new Report a Problem… item, which copies a diagnostics report and opens a bug report for you to paste it into. The report leaves out paths, links, and names, and the app sends nothing itself.
- The General pane can copy the same report, and it can record 10 seconds of touch data to a file that you can attach to a bug report.
- A level no longer flips back and forth when your finger rests between two steps, and the seek preview holds steady in the same way.
- A seek now applies on time when your finger briefly lost contact just before you lifted it.
- This version no longer resets every setting when it opens settings that a newer version saved.
- A click on an edge or in a corner is no longer dropped on rare occasions.
- Switch Spaces starts working as soon as you turn on its shortcuts in System Settings and leave that window.

## 1.2 - 2026-11-07

- The app now runs on macOS 13 or later. All testing so far has used macOS 27.2.
- On systems before macOS 26, the glass styles for the seek preview look frosted.

## 1.1 - 2026-11-07

- The app checks for updates every 24 hours and can install them for you. You can turn that off in the General pane.
- The menu bar menu has a new Release Notes item, which opens the notes for your version.
- The welcome tour ends with a link to the project on GitHub.

## 1.0 - 2026-11-07

The first public version turns the edges and corners of a Mac trackpad into controls.

- Each edge can change the volume, brightness, or keyboard backlight, seek through media, scroll, zoom, or switch apps and Spaces.
- Each edge can hold a second action for a two-finger slide.
- Each corner can hold an action for each number of presses.
- Each app can have a profile of its own.
- Haptic strength and pattern can be set, and a tour helps you set up the app.
