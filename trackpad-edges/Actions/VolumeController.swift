import AudioToolbox
import CoreAudio

/// Changes the system volume by pressing the volume keys, so that the native indicator appears.
final class VolumeController {
    /// The current level from 0 to 1, or nil if the output device has no software volume.
    var level: Float? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        guard let device = defaultOutputDevice() else { return nil }
        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else {
            return nil
        }
        return value
    }

    /// Moves one step and returns false if the level is already at a limit.
    func step(up: Bool, fine: Bool) -> Bool {
        if let level, up ? level >= 1 : level <= 0 { return false }
        MediaKeys.press(up ? MediaKeys.soundUp : MediaKeys.soundDown, fine: fine)
        return true
    }

    private func defaultOutputDevice() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        return status == noErr && device != 0 ? device : nil
    }
}
