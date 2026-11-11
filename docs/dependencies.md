# Dependencies

This document lists every package, framework, and system method the app uses. It was built from the source code, so update it whenever an import, a private symbol, or a system tool changes.

## External packages

The app bundles `mediaremote-adapter` v0.7.7 (upstream commit `e3ff502`) by Jonas van den Berg, which provides media seeking. It is BSD 3-Clause licensed, and its license text ships in the app as `MediaRemoteAdapter-LICENSE`. Its source is in `Vendor/mediaremote-adapter`, and [media-seek.md](media-seek.md) explains how it is bundled and updated.

The library ships as base64 text in `trackpad-edges/Resources/MediaRemoteAdapter.base64`. It is built from `Vendor/mediaremote-adapter` with a macOS 13 minimum, so that it loads on every system the app supports. To rebuild it, run `cmake -S Vendor/mediaremote-adapter -B <folder> -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0`, then `cmake --build <folder>`, and encode `MediaRemoteAdapter.framework/Versions/A/MediaRemoteAdapter` with `base64 -i <file> | tr -d '\n'`, writing the result to that resource file. `scripts/build-release.sh` refuses a library whose minimum is newer than the app's.

Sparkle 2.10.1 provides automatic updates. It is the only Swift package, `project.xcproj` pins that exact version, and `project.xcworkspace/xcshareddata/swiftpm/Package.resolved` records its commit. Automated dependency updates cannot see a package in an Xcode project, so check its releases by hand. `Package.swift` exists only so that `swift test` can run the gesture tests.

Open source projects were read as references for how the private frameworks behave, but no code was copied from them. The main references were Subsurface (Apache-2.0), TrackEdge by apurv-1 (MIT), TrackpadKit (MIT), and HapticKey (MIT).

## Private Apple frameworks

Apple does not document these frameworks, so a macOS update could break them. The app loads them at runtime with `dlopen` and `dlsym`, so a missing symbol disables a feature instead of stopping the app from launching.

### MultitouchSupport

The framework lives at `/System/Library/PrivateFrameworks/MultitouchSupport.framework`.

| Symbol                             | Purpose                                                                | Used in                        |
| ---------------------------------- | ---------------------------------------------------------------------- | ------------------------------ |
| `MTDeviceCreateList`               | This call lists the multitouch devices.                                | `Input/MultitouchBridge.swift` |
| `MTDeviceGetFamilyID`              | This call identifies Apple's touch mice to skip.                       | `Input/MultitouchBridge.swift` |
| `MTDeviceIsBuiltIn`                | This call tells the diagnostics report whether a trackpad is built in. | `Input/MultitouchBridge.swift` |
| `MTRegisterContactFrameCallback`   | This call registers for touch frames.                                  | `Input/MultitouchBridge.swift` |
| `MTUnregisterContactFrameCallback` | This call frees a callback slot on a rebuild.                          | `Input/MultitouchBridge.swift` |
| `MTDeviceStart`                    | This call starts a device.                                             | `Input/MultitouchBridge.swift` |
| `MTDeviceStop`                     | This call stops a device.                                              | `Input/MultitouchBridge.swift` |
| `MTDeviceGetMTActuator`            | This call gets a trackpad's haptic actuator.                           | `Haptics/HapticEngine.swift`   |
| `MTActuatorOpen`                   | This call opens the actuator for a slide.                              | `Haptics/HapticEngine.swift`   |
| `MTActuatorActuate`                | This call fires a haptic with a chosen strength.                       | `Haptics/HapticEngine.swift`   |
| `MTActuatorClose`                  | This call closes the actuator after a slide.                           | `Haptics/HapticEngine.swift`   |

The app also reads the framework's touch record by byte offset, because the framework has no public header. The offsets were read from the macOS 27.2 binary, and they are listed in `TouchLayout` in `Input/MultitouchBridge.swift`. The app supports macOS 13 or later, but nobody has checked these offsets or the other private frameworks on a system before 27.2.

### Build tools

`scripts/install.sh` and `scripts/build-release.sh` use `xcodebuild`, `xcrun vtool`, `PlistBuddy`, `codesign`, `security find-identity`, `base64`, `ditto`, `pgrep`, and `lsof`, which all ship with macOS or Xcode. Rebuilding the media adapter also needs `cmake`. The release workflow also uses the GitHub CLI and `create-dmg` from npm, which `.github/dmg/package-lock.json` fixes with all of its dependencies. It signs updates with Sparkle's `sign_update`, checks them with `scripts/verify-update.swift`, and writes the feed with `scripts/make-appcast.py`.

### CoreBrightness private client

`Actions/KeyboardBacklightController.swift` only reads from `KeyboardBrightnessClient`, and the keyboard keys still work if the client is missing.

| Symbol                                | Purpose                                                               |
| ------------------------------------- | --------------------------------------------------------------------- |
| `copyKeyboardBacklightIDs`            | This call finds the keyboard.                                         |
| `brightnessForKeyboard:`              | This call reads the backlight level.                                  |
| `isBacklightSaturatedOnKeyboard:`     | This call reports whether a bright room has locked the backlight off. |
| `isAutoBrightnessEnabledForKeyboard:` | This call reports whether automatic keyboard brightness is on.        |

### System settings the app reads

These values are undocumented, so a macOS update could rename them. The app also matches the `AppleMultitouchDevice` service for trackpads and the `DCPAVServiceProxy` service for external displays.

| Setting                                                     | Purpose                                                                                      |
| ----------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| `com.apple.symbolichotkeys`, keys 79 and 81                 | These show whether the shortcuts for moving between Spaces are on.                           |
| `com.apple.symbolichotkeys`, key 175                        | This holds the key that you assigned to Do Not Disturb, which Toggle Do Not Disturb presses. |
| `com.apple.swipescrolldirection`                            | This shows the scroll direction that the Scroll action follows.                              |
| `com.apple.screenIsLocked` and `com.apple.screenIsUnlocked` | These notifications stop gestures on a locked screen.                                        |

### IOKit private functions

These functions are used only for external monitor brightness, in `Actions/ExternalDisplayController.swift`.

| Symbol                         | Purpose                                           |
| ------------------------------ | ------------------------------------------------- |
| `IOAVServiceCreateWithService` | This call opens the control channel of a display. |
| `IOAVServiceWriteI2C`          | This call sends a DDC command to a display.       |
| `IOAVServiceReadI2C`           | This call reads a DDC reply from a display.       |

### Corner system actions

Each of these is looked up once at launch. Lock Screen and Toggle Dark Mode fall back to a second way when their call is missing, and Run Command refuses to run when its call is missing. The diagnostics report says which way each one uses.

| Symbol                                  | Where it lives                                         | Purpose                                                                        | Used in                            |
| --------------------------------------- | ------------------------------------------------------ | ------------------------------------------------------------------------------ | ---------------------------------- |
| `SACLockScreenImmediate`                | `/System/Library/PrivateFrameworks/login.framework`    | This call locks the screen at once. Control-Command-Q is the fallback.         | `Actions/SystemActionRunner.swift` |
| `SLSGetAppearanceThemeLegacy`           | `/System/Library/PrivateFrameworks/SkyLight.framework` | This call reads whether Dark Mode is on.                                       | `Actions/SystemActionRunner.swift` |
| `SLSSetAppearanceThemeLegacy`           | `/System/Library/PrivateFrameworks/SkyLight.framework` | This call switches Dark Mode. An Apple event to System Events is the fallback. | `Actions/SystemActionRunner.swift` |
| `responsibility_spawnattrs_setdisclaim` | The system library, found with `dlsym(RTLD_DEFAULT)`   | This call makes a command answer for its own permissions instead of the app's. | `Actions/CommandRunner.swift`      |

All four symbols were present on macOS 27.2 on 2026-11-11. Nobody has checked them on an older system yet.

### DisplayServices

The framework lives at `/System/Library/PrivateFrameworks/DisplayServices.framework`.

| Symbol                         | Purpose                                                       | Used in                              |
| ------------------------------ | ------------------------------------------------------------- | ------------------------------------ |
| `DisplayServicesGetBrightness` | This call reads the built-in display's brightness for limits. | `Actions/BrightnessController.swift` |

## Public Apple frameworks

| Framework                | What the app uses                                                                                                                                                                                                                                                                                                                                                                                            | Purpose                                                                                                                                                                                                                              |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `AppKit`                 | `NSApplication`, `NSStatusBar`, `NSMenu`, `NSWindow`, `NSTabViewController`, `NSOpenPanel`, `NSSavePanel`, `NSAlert`, `NSPasteboard`, `NSPanel`, `NSGlassEffectView`, `NSVisualEffectView`, `NSTableView`, `NSWorkspace`, `NSRunningApplication`, `NSEvent.otherEvent`, `NSAppleEventManager`, and `NSHapticFeedbackManager`, `NSMenuItem.sectionHeader`, and `accessibilityDisplayShouldReduceTransparency` | These build the interface, press media keys, open apps and links, copy the diagnostics report, save a touch recording, and provide the fallback haptics.                                                                             |
| `CoreGraphics`           | `CGEvent.tapCreate`, `CGEvent.tapEnable`, `CGPreflightPostEventAccess`, `CGEvent(scrollWheelEvent2Source:)`, `CGEvent.tapIsEnabled`, `tapPostEvent`, `CGEventSource.buttonState`, `CGAssociateMouseAndMouseCursorPosition`, `CGWarpMouseCursorPosition`, `CGGetActiveDisplayList`, and `CGDisplayIsBuiltin`                                                                                                  | These handle clicks, freeze the pointer, post keys, record shortcuts, and find the built-in display.                                                                                                                                 |
| `Security`               | `SecStaticCodeCreateWithPath`, `SecRequirementCreateWithString`, and `SecStaticCodeCheckValidity`                                                                                                                                                                                                                                                                                                            | These check the app against its signature before the adapter runs.                                                                                                                                                                   |
| `ApplicationServices`    | `AXIsProcessTrusted` and `AXIsProcessTrustedWithOptions`, which `AppKit` brings in, `AXUIElementSetMessagingTimeout`, and `kAXTrustedCheckOptionPrompt`                                                                                                                                                                                                                                                      | These check and request the Accessibility permission.                                                                                                                                                                                |
| `CoreAudio`              | `AudioObjectGetPropertyData` with `kAudioHardwarePropertyDefaultOutputDevice`                                                                                                                                                                                                                                                                                                                                | This finds the default output device.                                                                                                                                                                                                |
| `AudioToolbox`           | `kAudioHardwareServiceDeviceProperty_VirtualMainVolume`                                                                                                                                                                                                                                                                                                                                                      | This reads the volume so that the app can detect limits.                                                                                                                                                                             |
| `IOKit`                  | `IOServiceAddMatchingNotification`, `IONotificationPortCreate`, `IONotificationPortSetDispatchQueue`, `IOIteratorNext`, `IOServiceGetMatchingServices`, and `IORegistryEntryCreateCFProperty`, and the `NX_` constants from `IOKit.hidsystem`                                                                                                                                                                | These detect trackpads connecting and disconnecting, and they find external displays.                                                                                                                                                |
| `Foundation`             | `Process`, `Pipe`, `FileManager`, `UserDefaults`, `JSONEncoder`, `JSONSerialization`, `DistributedNotificationCenter`, `ProcessInfo`, `sysctlbyname`, `dlopen`, `dlsym`, and `NSAppleEventDescriptor` with `sendEvent(options:timeout:)`                                                                                                                                                                     | These run shortcuts and `pmset`, store settings, watch for locking, read the macOS version and the Mac model for the diagnostics report, load private frameworks, and send Apple events to Finder, System Events, and `loginwindow`. |
| `CoreServices`           | The Apple event constants `kAEReallyLogOut`, `kAERestart`, `kAEShutDown`, `kAEGetData`, `kAESetData`, `errAEEventNotPermitted`, `errAEEventWouldRequireUserConsent`, and `errAETimeout`                                                                                                                                                                                                                      | These name the session events, which only `Actions/SessionActionRunner.swift` uses, and the events that read and set Dark Mode.                                                                                                      |
| `UserNotifications`      | `UNUserNotificationCenter`, `UNMutableNotificationContent`, and `UNNotificationRequest`                                                                                                                                                                                                                                                                                                                      | These report a failed corner command, one notification for each corner.                                                                                                                                                              |
| `Darwin`                 | `posix_spawn` with its file actions and attributes, `waitpid`, `kill`, `pipe`, `getpwuid`, and `DispatchSource.makeReadSource`                                                                                                                                                                                                                                                                               | These start a corner command in its own process group, read its error output, and stop it.                                                                                                                                           |
| `CoreFoundation`         | `CFMachPortCreateRunLoopSource`, `CFRunLoopAddSource`, `CFRunLoopRemoveSource`, and `CFArrayGetValueAtIndex`                                                                                                                                                                                                                                                                                                 | These attach event taps to the run loop and read the device list.                                                                                                                                                                    |
| `OSLog`                  | `Logger`                                                                                                                                                                                                                                                                                                                                                                                                     | This records click decisions at the debug level, and tap stalls and pointer problems at the notice level.                                                                                                                            |
| `ServiceManagement`      | `SMAppService.mainApp`, and `SMAppService.openSystemSettingsLoginItems`                                                                                                                                                                                                                                                                                                                                      | This provides launch at login.                                                                                                                                                                                                       |
| `UniformTypeIdentifiers` | `UTType`                                                                                                                                                                                                                                                                                                                                                                                                     | This limits the app chooser to applications, and it names the file type of a touch recording.                                                                                                                                        |
| `ApplicationServices`    | `AXUIElementCreateApplication` and `AXUIElementSetAttributeValue`                                                                                                                                                                                                                                                                                                                                            | These bring an app forward for the Switch Apps action, and they bring Finder forward before Empty Trash.                                                                                                                             |
| `Carbon.HIToolbox`       | the `kVK_` key codes                                                                                                                                                                                                                                                                                                                                                                                         | These name keys in the shortcut recorder and send keys for corners, zoom, and Spaces.                                                                                                                                                |
| `XCTest`                 | `XCTestCase`                                                                                                                                                                                                                                                                                                                                                                                                 | This runs the unit tests.                                                                                                                                                                                                            |
| `PackageDescription`     | `Package`                                                                                                                                                                                                                                                                                                                                                                                                    | This defines the test package.                                                                                                                                                                                                       |

`ServiceManagement` and `UniformTypeIdentifiers` are used only by the app window.

## System tools and notifications

| Item                                                               | Purpose                                                                                                                   |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------- |
| `/usr/bin/perl`                                                    | This tool runs the media seek adapter.                                                                                    |
| `/usr/bin/shortcuts`                                               | This tool runs a chosen shortcut in the background.                                                                       |
| `/usr/bin/pmset`                                                   | `pmset sleepnow` and `pmset displaysleepnow` put the Mac or its displays to sleep.                                        |
| Your login shell                                                   | Run Command starts the shell from your account record with `-l -c`, or `/bin/zsh` if the account names none that can run. |
| `/System/Library/CoreServices/ScreenSaverEngine.app`               | Start Screen Saver opens this app.                                                                                        |
| `NSWorkspace.didWakeNotification` and `screensDidWakeNotification` | These hold back the sleep and lock actions for 3 seconds after a wake.                                                    |
| `com.apple.screenIsLocked` and `com.apple.screenIsUnlocked`        | These undocumented notifications pause gestures while locked.                                                             |

## Considered but not used

- `NSTouch` is not used, because Apple's documentation says touches latch to the view under the cursor, so a background app never receives them.
- `MediaRemote` is not called directly, because Apple has blocked third-party use since macOS 15.4. The adapter reaches it through the system Perl.
- `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter` are not used, because they only publish an app's own playback.
- AppleScript is not used for seeking, because it reaches only Music and Spotify, and the adapter covers those too.

## Assets

The app icon, the glyphs in `Assets.xcassets`, the render at `site/assets/feel.jpg`, and the launch film at `site/assets/launch.mp4` with its poster frame were made for this project. `site/fonts/archivo.woff2` is the Archivo font under the SIL Open Font License, and its license is at `site/fonts/OFL.txt`.
