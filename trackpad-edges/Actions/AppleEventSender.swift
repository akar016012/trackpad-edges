import AppKit
import CoreServices

/**
 Sends Apple events off the main thread, because a send can wait on a consent prompt. Don't use
 `NSAppleScript`, which is main-thread only. A request to an app with one pending is dropped.
 */
nonisolated final class AppleEventSender: @unchecked Sendable {
    /// Why an event did not arrive.
    enum Failure: Error, Equatable {
        /// Automation was denied or not answered yet.
        case notAllowed
        /// The target did not reply in time, often because it is showing its own question.
        case timedOut
        case failed(Int)
    }

    /// How long to wait for a launched app.
    private static let launchTimeout: TimeInterval = 5

    private let queue = DispatchQueue(label: "apple-events", qos: .userInitiated)
    private let lock = NSLock()
    private var pending: Set<String> = []

    /**
     Runs `body` on the queue unless a request to the same app is pending. Failures arrive on
     the main thread.
     */
    func perform(
        target bundleID: String, _ body: @escaping @Sendable () throws -> Void,
        onFailure: @escaping @MainActor (Failure) -> Void
    ) {
        lock.lock()
        let isNew = pending.insert(bundleID).inserted
        lock.unlock()
        guard isNew else { return }
        queue.async { [weak self] in
            var failure: Failure?
            do {
                try body()
            } catch let error as Failure {
                failure = error
            } catch {
                failure = .failed((error as NSError).code)
            }
            self?.lock.lock()
            self?.pending.remove(bundleID)
            self?.lock.unlock()
            if let failure {
                DispatchQueue.main.async { MainActor.assumeIsolated { onFailure(failure) } }
            }
        }
    }

    /// Sends one event and returns the reply. It blocks, so call it only inside `perform`.
    static func send(
        eventClass: AEEventClass, eventID: AEEventID, to bundleID: String,
        directObject: NSAppleEventDescriptor? = nil,
        parameters: [(AEKeyword, NSAppleEventDescriptor)] = [], timeout: TimeInterval = 30
    ) throws -> NSAppleEventDescriptor {
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleID)
        let event = NSAppleEventDescriptor(
            eventClass: eventClass, eventID: eventID, targetDescriptor: target,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID))
        if let directObject { event.setParam(directObject, forKeyword: keyDirectObject) }
        for (keyword, value) in parameters { event.setParam(value, forKeyword: keyword) }
        do {
            return try event.sendEvent(options: [.waitForReply, .canInteract], timeout: timeout)
        } catch {
            let code = (error as NSError).code
            switch code {
            case Int(errAEEventNotPermitted), Int(errAEEventWouldRequireUserConsent):
                throw Failure.notAllowed
            case Int(errAETimeout): throw Failure.timedOut
            default: throw Failure.failed(code)
            }
        }
    }

    /**
     Starts the app in the background if needed, because events to a stopped app fail. It
     blocks, so call it only inside `perform`.
     */
    static func launchIfNeeded(_ bundleID: String) {
        guard NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty,
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        let launched = DispatchSemaphore(value: 0)
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
            launched.signal()
        }
        _ = launched.wait(timeout: .now() + launchTimeout)
    }

    /// Describes a property of an object, such as `dark mode of appearance preferences`.
    static func property(
        _ code: DescType, of container: NSAppleEventDescriptor? = nil
    ) -> NSAppleEventDescriptor {
        let record = NSAppleEventDescriptor.record()
        record.setDescriptor(
            NSAppleEventDescriptor(typeCode: DescType(typeProperty)),
            forKeyword: AEKeyword(keyAEDesiredClass))
        record.setDescriptor(
            container ?? NSAppleEventDescriptor.null(), forKeyword: AEKeyword(keyAEContainer))
        record.setDescriptor(
            NSAppleEventDescriptor(enumCode: OSType(formPropertyID)),
            forKeyword: AEKeyword(keyAEKeyForm))
        record.setDescriptor(
            NSAppleEventDescriptor(typeCode: code), forKeyword: AEKeyword(keyAEKeyData))
        return record.coerce(toDescriptorType: DescType(typeObjectSpecifier)) ?? record
    }
}
