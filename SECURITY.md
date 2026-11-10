# Security policy

## Reporting a vulnerability

Please do not report security problems in public issues or pull requests.

Use [GitHub's private vulnerability reporting](https://github.com/akar016012/trackpad-edges/security/advisories/new), or send your report to adi.kar@adiportfolio.com. Describe the problem, the steps to reproduce it, and the version you used.

This project has one maintainer, who works on it in their spare time. You can expect a first reply within seven days. Please give the maintainer a reasonable time to fix the problem before you share it publicly. You will be credited unless you prefer not to be.

## Supported versions

Only the latest release receives security fixes.

## What the app can do

These details explain what a vulnerability in this app could affect.

- The app holds the Accessibility permission, so it can post keyboard and media key events, hold back or swallow left clicks, block pointer and scroll events during a slide, and bring apps forward.
- While you record a shortcut, the app reads and swallows keyboard events. It reads no key presses at any other time, although it checks which modifier keys are held during a gesture.
- Its event taps sit in the path of every left click, so a stalled or misbehaving app can hold up clicks for the whole Mac. A watchdog turns the taps off if the app's main thread stalls.
- The app reads touches from the trackpad through a private framework. It stores them only when you use **Record Touches…** on the General pane, which saves 10 seconds of touch data to a file that you choose. That file holds the position, pressure, and size of each contact, and the app sends it nowhere.
- The app makes one kind of network request, which is its update check. It reads a small feed from this project's website when it first runs and then every 24 hours, and you can turn that off in the General pane. The request carries the app's version and no personal data, although the website's host sees your IP address, as with any web request. If you install an update, the app downloads it from this project's GitHub releases, and GitHub sees that request in the same way. The app has no accounts, tracking, or analytics. An action that you assign can still reach the network, such as a link or a shortcut.
- An update replaces the app, so the app checks it before it opens the download. It accepts an update that carries a valid signature from this project's update key, or one whose new app is signed with this project's Developer ID. Either credential alone could therefore deliver code to installed copies if its holder also controlled the feed, so a stolen key or certificate should be reported like any other vulnerability.
- A corner can open apps, links, and files, and it can run a shortcut through `/usr/bin/shortcuts`. These come from your settings, which are stored in your user preferences without encryption, so anything that can write those preferences can change what a corner launches.
- The Monitor Brightness action sends control messages to external displays.
- Media seek runs the system's Perl with a bundled library, and that child process probably inherits the Accessibility permission. The app checks the library before each run. An installed build validates its whole signature, and a build run from Xcode compares the library's bytes.

## How reports are handled

The maintainer confirms the report, judges its severity by what an attacker could reach, and prepares a fix in private. Users learn about it in the release notes of the fixed version, which credit the reporter.
