import AppKit

/// Shows a preview during a seek slide, and applies it to the player only on release.
final class SeekController {
    private static let lingerAfterRelease: TimeInterval = 0.7
    private static let sampleDuration: TimeInterval = 2
    /// Some players skip to the next track when they seek to the very end.
    private static let endMargin: Double = 1
    /// The finger travel for one step at normal sensitivity, as a fraction of the pad width.
    private static let baseStepTravel: Float = 0.05

    private let adapter = NowPlayingAdapter()
    private let queue = DispatchQueue(label: "seek", qos: .userInitiated)
    private let overlay = SeekOverlayPanel()

    #if DEBUG
        private var debugBackdrop: DebugBackdrop?
    #endif
    private var overlayStyle = OverlayStyle.glass
    private var overlayPlacement = OverlayPlacement.bottom
    private var generation = 0
    private var origin: NowPlayingAdapter.Playback?
    private var finishedLoading = false
    private var scrubber: SeekScrubber?
    /// Set when the finger lifts before the position has loaded, so the seek can still happen.
    private var commitWhenLoaded = false

    /// How far one step moves, from the Media pane.
    var step = SeekStep.percent(1)
    /// A multiplier where higher values need less finger travel for each step.
    var sensitivity: Float = 1

    var isAvailable: Bool { adapter != nil }

    func applyOverlay(style: OverlayStyle, placement: OverlayPlacement) {
        guard style != overlayStyle || placement != overlayPlacement else { return }
        overlayStyle = style
        overlayPlacement = placement
        overlay.apply(style: style, placement: placement)
    }

    /// Shows the overlay with made-up values, so that a style can be judged in the settings.
    func showSample() {
        guard scrubber == nil else { return }
        overlay.show(position: 150, duration: 600, change: 0.05)
        overlay.hide(after: Self.sampleDuration)
    }

    #if DEBUG
        /// Shows one style after switching through the others, as a person would in the settings.
        func debugShow(style: OverlayStyle, appearance: NSAppearance.Name?, backdrop: String?) {
            if let appearance { overlay.baseAppearance = NSAppearance(named: appearance) }
            if let backdrop { debugBackdrop = DebugBackdrop(kind: backdrop) }
            for other in OverlayStyle.allCases {
                overlay.apply(style: other, placement: .center)
            }
            overlay.apply(style: style, placement: .center)
            overlay.show(position: 150, duration: 600, change: 0.05)
        }
    #endif

    /// Reads the position. This waits for real movement, so that an ordinary touch on the bottom
    /// strip never starts a process.
    private func begin() {
        generation += 1
        origin = nil
        finishedLoading = false
        commitWhenLoaded = false
        scrubber = SeekScrubber(stepTravel: Self.baseStepTravel / sensitivity)
        guard let adapter else {
            finishedLoading = true
            return
        }
        let current = generation
        queue.async { [weak self] in
            let playback = adapter.playback()
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.didLoad(playback, generation: current) }
            }
        }
    }

    /// Updates the preview, and returns true when a haptic tick is due.
    func preview(travel: Float) -> Bool {
        // A released slide is waiting for its position, and new movement must not change it.
        guard !commitWhenLoaded else { return false }
        let isFirst = scrubber == nil
        if isFirst { begin() }
        let stepped = scrubber?.update(travel: travel, limits: limits) ?? false
        refreshOverlay()
        return isFirst || (stepped && origin != nil)
    }

    func commit() {
        // Without a scrubber, this slide never showed a preview, so the overlay is not its own.
        guard !commitWhenLoaded, scrubber != nil else { return }
        if !finishedLoading {
            commitWhenLoaded = true
            return
        }
        applySeek()
    }

    func cancel() {
        // A cancel at this point belongs to a later slide, so the released seek still happens.
        guard !commitWhenLoaded, scrubber != nil else { return }
        generation += 1
        scrubber = nil
        overlay.hide(after: 0)
    }

    private func applySeek() {
        generation += 1
        if let target, let adapter, scrubber?.steps != 0 {
            queue.async { adapter.seek(to: target) }
        }
        overlay.hide(after: Self.lingerAfterRelease)
        scrubber = nil
        commitWhenLoaded = false
    }

    private func didLoad(_ playback: NowPlayingAdapter.Playback?, generation current: Int) {
        guard current == generation else { return }
        origin = playback
        finishedLoading = true
        refreshOverlay()
        if commitWhenLoaded { applySeek() }
    }

    /// How many steps fit before the start and the end of the track.
    private var limits: ClosedRange<Int>? {
        guard let origin else { return nil }
        let length = step.length(duration: origin.duration)
        let back = (origin.elapsed / length).rounded(.up)
        let forward = ((origin.duration - Self.endMargin - origin.elapsed) / length).rounded(.up)
        return -Int(back)...Int(max(forward, 0))
    }

    private var target: Double? {
        guard let origin, let scrubber else { return nil }
        let moved = origin.elapsed + Double(scrubber.steps) * step.length(duration: origin.duration)
        // Media already in its last second stays put, rather than being pulled back to the margin.
        return min(max(moved, 0), max(origin.duration - Self.endMargin, origin.elapsed))
    }

    private func refreshOverlay() {
        guard scrubber != nil else { return }
        if let origin, let target {
            let change = (target - origin.elapsed) / origin.duration
            overlay.show(position: target, duration: origin.duration, change: change)
        } else {
            overlay.show(message: finishedLoading ? "Nothing Is Playing" : "Reading Position…")
        }
    }
}
