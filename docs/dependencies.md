# Dependencies

This document lists every package, framework, and system method the app uses. It was built from the source code, so update it whenever an import, a private symbol, or a system tool changes.

## External packages

The app uses no third-party packages, so there is no `Package.resolved` file. `Package.swift` declares no dependencies, and it exists only so that `swift test` can run the gesture tests.

Open source projects were read as references for how the private frameworks behave, but no code was copied from them. The main references were Subsurface (Apache-2.0), TrackEdge by apurv-1 (MIT), TrackpadKit (MIT), and HapticKey (MIT).

The planned media seek feature may add a third-party Now Playing workaround. See [media-seek.md](media-seek.md).

## Private Apple frameworks

Apple does not document these frameworks, so a macOS update could break them. The app loads them at runtime with `dlopen` and `dlsym`, so a missing symbol disables a feature instead of stopping the app from launching.

### MultitouchSupport

The framework lives at `/System/Library/PrivateFrameworks/MultitouchSupport.framework`.

| Symbol                             | Purpose                                           | Used in                        |
| ---------------------------------- | ------------------------------------------------- | ------------------------------ |
| `MTDeviceCreateList`               | This call lists the multitouch devices.           | `Input/MultitouchBridge.swift` |
| `MTDeviceGetFamilyID`              | This call identifies Apple touch mouse devices to skip. | `Input/MultitouchBridge.swift` |
| `MTRegisterContactFrameCallback`   | This call registers for touch frames.             | `Input/MultitouchBridge.swift` |
| `MTUnregisterContactFrameCallback` | This call frees a callback slot on a rebuild.     | `Input/MultitouchBridge.swift` |
| `MTDeviceStart`                    | This call starts a device.                        | `Input/MultitouchBridge.swift` |
| `MTDeviceStop`                     | This call stops a device.                         | `Input/MultitouchBridge.swift` |
| `MTDeviceGetMTActuator`            | This call gets a trackpad's haptic actuator.      | `Haptics/HapticEngine.swift`   |
| `MTActuatorOpen`                   | This call opens the actuator for a slide.         | `Haptics/HapticEngine.swift`   |
| `MTActuatorActuate`                | This call fires a haptic with a chosen strength.  | `Haptics/HapticEngine.swift`   |
| `MTActuatorClose`                  | This call closes the actuator after a slide.      | `Haptics/HapticEngine.swift`   |

The app also reads the framework's touch record by byte offset, because the framework has no public header. The offsets were read from the macOS 27.2 binary, and they are listed in `TouchLayout` in `Input/MultitouchBridge.swift`.

### DisplayServices

The framework lives at `/System/Library/PrivateFrameworks/DisplayServices.framework`.

| Symbol                         | Purpose                                                       | Used in                              |
| ------------------------------ | ------------------------------------------------------------- | ------------------------------------ |
| `DisplayServicesGetBrightness` | This call reads the built-in display's brightness for limits. | `Actions/BrightnessController.swift` |

## Public Apple frameworks

| Framework                | What the app uses                                                                                                                                                                                                                        | Purpose                                                                                             |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `AppKit`                 | `NSApplication`, `NSStatusBar`, `NSMenu`, `NSWindow`, `NSTabViewController`, `NSOpenPanel`, `NSWorkspace`, `NSEvent.otherEvent`, `NSEvent.addLocalMonitorForEvents`, and `NSHapticFeedbackManager`                                       | These build the interface, press media keys, open apps and links, and provide the fallback haptics. |
| `CoreGraphics`           | `CGEvent.tapCreate`, `CGEvent.tapEnable`, `CGEvent.tapIsEnabled`, `tapPostEvent`, `CGEventSource.buttonState`, `CGAssociateMouseAndMouseCursorPosition`, `CGWarpMouseCursorPosition`, `CGGetActiveDisplayList`, and `CGDisplayIsBuiltin` | These handle clicks, freeze the pointer, post keys, and find the built-in display.                  |
| `ApplicationServices`    | `AXIsProcessTrusted` and `AXIsProcessTrustedWithOptions`, which `AppKit` brings in                                                                                                                                                       | These check and request the Accessibility permission.                                               |
| `CoreAudio`              | `AudioObjectGetPropertyData` with `kAudioHardwarePropertyDefaultOutputDevice`                                                                                                                                                            | This finds the default output device.                                                               |
| `AudioToolbox`           | `kAudioHardwareServiceDeviceProperty_VirtualMainVolume`                                                                                                                                                                                  | This reads the volume so that the app can detect limits.                                            |
| `IOKit`                  | `IOServiceAddMatchingNotification`, `IONotificationPortCreate`, `IONotificationPortSetDispatchQueue`, and `IOIteratorNext` on `AppleMultitouchDevice`                                                                                    | These detect trackpads connecting and disconnecting.                                                |
| `Foundation`             | `Process`, `UserDefaults`, `JSONEncoder`, `DistributedNotificationCenter`, `dlopen`, and `dlsym`                                                                                                                                         | These run shortcuts, store settings, watch for locking, and load private frameworks.                |
| `CoreFoundation`         | `CFMachPortCreateRunLoopSource`, `CFRunLoopAddSource`, `CFRunLoopRemoveSource`, and `CFArrayGetValueAtIndex`                                                                                                                             | These attach event taps to the run loop and read the device list.                                   |
| `OSLog`                  | `Logger`                                                                                                                                                                                                                                 | This records click decisions at the debug level.                                                    |
| `ServiceManagement`      | `SMAppService.mainApp`                                                                                                                                                                                                                   | This provides launch at login.                                                                      |
| `UniformTypeIdentifiers` | `UTType`                                                                                                                                                                                                                                 | This limits the app chooser to applications.                                                        |
| `Carbon.HIToolbox`       | `kVK_Escape`                                                                                                                                                                                                                             | This lets Escape cancel the shortcut recorder.                                                      |
| `XCTest`                 | `XCTestCase`                                                                                                                                                                                                                             | This runs the unit tests.                                                                           |
| `PackageDescription`     | `Package`                                                                                                                                                                                                                                | This defines the test package.                                                                      |

`ServiceManagement`, `UniformTypeIdentifiers`, and `Carbon.HIToolbox` are used only by the app window, which is not connected yet.

## System tools and notifications

| Item                                                        | Purpose                                                       |
| ----------------------------------------------------------- | ------------------------------------------------------------- |
| `/usr/bin/shortcuts`                                        | This tool runs a chosen shortcut in the background.           |
| `com.apple.screenIsLocked` and `com.apple.screenIsUnlocked` | These undocumented notifications pause gestures while locked. |

## Considered but not used

- `NSTouch` is not used, because Apple's documentation says touches latch to the view under the cursor, so a background app never receives them.
- `MediaRemote` is not used yet. Apple has blocked direct third-party use since macOS 15.4, and a read-only check on macOS 27.2 returned nothing, although nothing may have been playing at the time.
