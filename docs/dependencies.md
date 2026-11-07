# Dependencies

This document lists every package, framework, and system method the app uses. It was built from the source code, so update it whenever an import, a private symbol, or a system tool changes.

## External packages

The app has one third-party component, `mediaremote-adapter` v0.7.7 (upstream commit `e3ff502`) by Jonas van den Berg, which provides media seeking. It is BSD 3-Clause licensed, and its license text ships in the app as `MediaRemoteAdapter-LICENSE`. Its source is in `Vendor/mediaremote-adapter`, and [media-seek.md](media-seek.md) explains how it is bundled and updated.

There are no Swift package dependencies, so there is no `Package.resolved` file. `Package.swift` exists only so that `swift test` can run the gesture tests.

Open source projects were read as references for how the private frameworks behave, but no code was copied from them. The main references were Subsurface (Apache-2.0), TrackEdge by apurv-1 (MIT), TrackpadKit (MIT), and HapticKey (MIT).

## Private Apple frameworks

Apple does not document these frameworks, so a macOS update could break them. The app loads them at runtime with `dlopen` and `dlsym`, so a missing symbol disables a feature instead of stopping the app from launching.

### MultitouchSupport

The framework lives at `/System/Library/PrivateFrameworks/MultitouchSupport.framework`.

| Symbol                             | Purpose                                          | Used in                        |
| ---------------------------------- | ------------------------------------------------ | ------------------------------ |
| `MTDeviceCreateList`               | This call lists the multitouch devices.          | `Input/MultitouchBridge.swift` |
| `MTDeviceGetFamilyID`              | This call identifies Apple's touch mice to skip. | `Input/MultitouchBridge.swift` |
| `MTRegisterContactFrameCallback`   | This call registers for touch frames.            | `Input/MultitouchBridge.swift` |
| `MTUnregisterContactFrameCallback` | This call frees a callback slot on a rebuild.    | `Input/MultitouchBridge.swift` |
| `MTDeviceStart`                    | This call starts a device.                       | `Input/MultitouchBridge.swift` |
| `MTDeviceStop`                     | This call stops a device.                        | `Input/MultitouchBridge.swift` |
| `MTDeviceGetMTActuator`            | This call gets a trackpad's haptic actuator.     | `Haptics/HapticEngine.swift`   |
| `MTActuatorOpen`                   | This call opens the actuator for a slide.        | `Haptics/HapticEngine.swift`   |
| `MTActuatorActuate`                | This call fires a haptic with a chosen strength. | `Haptics/HapticEngine.swift`   |
| `MTActuatorClose`                  | This call closes the actuator after a slide.     | `Haptics/HapticEngine.swift`   |

The app also reads the framework's touch record by byte offset, because the framework has no public header. The offsets were read from the macOS 27.2 binary, and they are listed in `TouchLayout` in `Input/MultitouchBridge.swift`.

### Build tools

`scripts/install.sh` and `scripts/build-release.sh` use `xcodebuild`, `codesign`, `security find-identity`, `base64`, `ditto`, `pgrep`, and `lsof`, which all ship with macOS or Xcode. The release workflow also uses `create-dmg` from npm and the GitHub CLI.

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

| Setting                                                     | Purpose                                                            |
| ----------------------------------------------------------- | ------------------------------------------------------------------ |
| `com.apple.symbolichotkeys`, keys 79 and 81                 | These show whether the shortcuts for moving between Spaces are on. |
| `com.apple.swipescrolldirection`                            | This shows the scroll direction that the Scroll action follows.    |
| `com.apple.screenIsLocked` and `com.apple.screenIsUnlocked` | These notifications stop gestures on a locked screen.              |

### IOKit private functions

These functions are used only for external monitor brightness, in `Actions/ExternalDisplayController.swift`.

| Symbol                         | Purpose                                           |
| ------------------------------ | ------------------------------------------------- |
| `IOAVServiceCreateWithService` | This call opens the control channel of a display. |
| `IOAVServiceWriteI2C`          | This call sends a DDC command to a display.       |
| `IOAVServiceReadI2C`           | This call reads a DDC reply from a display.       |

### DisplayServices

The framework lives at `/System/Library/PrivateFrameworks/DisplayServices.framework`.

| Symbol                         | Purpose                                                       | Used in                              |
| ------------------------------ | ------------------------------------------------------------- | ------------------------------------ |
| `DisplayServicesGetBrightness` | This call reads the built-in display's brightness for limits. | `Actions/BrightnessController.swift` |

## Public Apple frameworks

| Framework                | What the app uses                                                                                                                                                                                                                                                                                                                                                  | Purpose                                                                                                   |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------- |
| `AppKit`                 | `NSApplication`, `NSStatusBar`, `NSMenu`, `NSWindow`, `NSTabViewController`, `NSOpenPanel`, `NSPanel`, `NSGlassEffectView`, `NSVisualEffectView`, `NSTableView`, `NSWorkspace`, `NSRunningApplication`, `NSEvent.otherEvent`, `NSAppleEventManager`, and `NSHapticFeedbackManager`, `NSMenuItem.sectionHeader`, and `accessibilityDisplayShouldReduceTransparency` | These build the interface, press media keys, open apps and links, and provide the fallback haptics.       |
| `CoreGraphics`           | `CGEvent.tapCreate`, `CGEvent.tapEnable`, `CGPreflightPostEventAccess`, `CGEvent(scrollWheelEvent2Source:)`, `CGEvent.tapIsEnabled`, `tapPostEvent`, `CGEventSource.buttonState`, `CGAssociateMouseAndMouseCursorPosition`, `CGWarpMouseCursorPosition`, `CGGetActiveDisplayList`, and `CGDisplayIsBuiltin`                                                        | These handle clicks, freeze the pointer, post keys, record shortcuts, and find the built-in display.      |
| `Security`               | `SecStaticCodeCreateWithPath`, `SecRequirementCreateWithString`, and `SecStaticCodeCheckValidity`                                                                                                                                                                                                                                                                  | These check the app against its signature before the adapter runs.                                        |
| `ApplicationServices`    | `AXIsProcessTrusted` and `AXIsProcessTrustedWithOptions`, which `AppKit` brings in, `AXUIElementSetMessagingTimeout`, and `kAXTrustedCheckOptionPrompt`                                                                                                                                                                                                            | These check and request the Accessibility permission.                                                     |
| `CoreAudio`              | `AudioObjectGetPropertyData` with `kAudioHardwarePropertyDefaultOutputDevice`                                                                                                                                                                                                                                                                                      | This finds the default output device.                                                                     |
| `AudioToolbox`           | `kAudioHardwareServiceDeviceProperty_VirtualMainVolume`                                                                                                                                                                                                                                                                                                            | This reads the volume so that the app can detect limits.                                                  |
| `IOKit`                  | `IOServiceAddMatchingNotification`, `IONotificationPortCreate`, `IONotificationPortSetDispatchQueue`, `IOIteratorNext`, `IOServiceGetMatchingServices`, and `IORegistryEntryCreateCFProperty`, and the `NX_` constants from `IOKit.hidsystem`                                                                                                                      | These detect trackpads connecting and disconnecting, and they find external displays.                     |
| `Foundation`             | `Process`, `Pipe`, `FileManager`, `UserDefaults`, `JSONEncoder`, `JSONSerialization`, `DistributedNotificationCenter`, `dlopen`, and `dlsym`                                                                                                                                                                                                                       | These run shortcuts, store settings, watch for locking, and load private frameworks.                      |
| `CoreFoundation`         | `CFMachPortCreateRunLoopSource`, `CFRunLoopAddSource`, `CFRunLoopRemoveSource`, and `CFArrayGetValueAtIndex`                                                                                                                                                                                                                                                       | These attach event taps to the run loop and read the device list.                                         |
| `OSLog`                  | `Logger`                                                                                                                                                                                                                                                                                                                                                           | This records click decisions at the debug level, and tap stalls and pointer problems at the notice level. |
| `ServiceManagement`      | `SMAppService.mainApp`, and `SMAppService.openSystemSettingsLoginItems`                                                                                                                                                                                                                                                                                            | This provides launch at login.                                                                            |
| `UniformTypeIdentifiers` | `UTType`                                                                                                                                                                                                                                                                                                                                                           | This limits the app chooser to applications.                                                              |
| `ApplicationServices`    | `AXUIElementCreateApplication` and `AXUIElementSetAttributeValue`                                                                                                                                                                                                                                                                                                  | These bring an app forward for the Switch Apps action.                                                    |
| `Carbon.HIToolbox`       | the `kVK_` key codes                                                                                                                                                                                                                                                                                                                                               | These name keys in the shortcut recorder and send keys for corners, zoom, and Spaces.                     |
| `XCTest`                 | `XCTestCase`                                                                                                                                                                                                                                                                                                                                                       | This runs the unit tests.                                                                                 |
| `PackageDescription`     | `Package`                                                                                                                                                                                                                                                                                                                                                          | This defines the test package.                                                                            |

`ServiceManagement` and `UniformTypeIdentifiers` are used only by the app window.

## System tools and notifications

| Item                                                        | Purpose                                                       |
| ----------------------------------------------------------- | ------------------------------------------------------------- |
| `/usr/bin/perl`                                             | This tool runs the media seek adapter.                        |
| `/usr/bin/shortcuts`                                        | This tool runs a chosen shortcut in the background.           |
| `com.apple.screenIsLocked` and `com.apple.screenIsUnlocked` | These undocumented notifications pause gestures while locked. |

## Considered but not used

- `NSTouch` is not used, because Apple's documentation says touches latch to the view under the cursor, so a background app never receives them.
- `MediaRemote` is not called directly, because Apple has blocked third-party use since macOS 15.4. The adapter reaches it through the system Perl.
- `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter` are not used, because they only publish an app's own playback.
- AppleScript is not used for seeking, because it reaches only Music and Spotify, and the adapter covers those too.

## Assets

The app icon, the glyphs in `Assets.xcassets`, and the render at `site/assets/feel.jpg` were made for this project. `site/fonts/archivo.woff2` is the Archivo font under the SIL Open Font License, and its license is at `site/fonts/OFL.txt`.
