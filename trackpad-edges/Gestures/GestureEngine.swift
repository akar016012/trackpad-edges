import Foundation

/// One finger on the trackpad, in normalized coordinates with a bottom-left origin.
nonisolated struct TouchPoint: Sendable, Equatable {
    let id: Int32
    let x: Float
    let y: Float
}

nonisolated enum Zone: String, Sendable, Equatable {
    case left, right, bottom, topLeft, topRight
}

nonisolated enum SlideKind: String, Sendable, Equatable, Codable, CaseIterable {
    case volume, brightness, seek
}

/// The values that shape gesture recognition. All sizes are fractions of the pad.
nonisolated struct GestureConfig: Sendable, Equatable {
    var edgeWidth: Float = 0.10
    var stepSize: Float = 0.035
    var seekDeadZone: Float = 0.025
    /// How far a finger may stray past a strip before the slide cancels.
    var exitMargin: Float = 0.03
    var cornerWidth: Float = 0.20
    var cornerHeight: Float = 0.17
    var multiClickWindow: TimeInterval = 0.45
    /// How long a finger can lose contact before a slide ends. Contact drops out near the pad's rim.
    var liftGrace: TimeInterval = 0.18
    /// Whether a slide needs a physical click. Otherwise, landing in a strip starts it.
    var requireClick = true
    /// The travel needed before a touch counts as a slide, which is what keeps a tap inert.
    var slideDeadZone: Float = 0.04
    /// How long a finger must stay down before a touch counts as a slide.
    var slideSettleTime: TimeInterval = 0.08
    /// A move this large between two frames is a contact glitch, because fingers are not that fast.
    var maxFrameJump: Float = 0.12
    var bottomQuarterOnly = false
    /// What each edge controls, where nil leaves that edge as a normal part of the trackpad.
    var leftAction: SlideKind? = .brightness
    var rightAction: SlideKind? = .volume
    var bottomAction: SlideKind? = .seek
    var brightnessAvailable = true
    var seekAvailable = true
    /// The clicks needed to fire each corner, where nil means that the corner has no action.
    var topLeftClicks: Int? = 1
    var topRightClicks: Int?

    /// Returns the zone at a point, testing top corners, then bottom, left, and right.
    func zone(x: Float, y: Float) -> Zone? {
        if y >= 1 - cornerHeight {
            if x <= cornerWidth, topLeftClicks != nil { return .topLeft }
            if x >= 1 - cornerWidth, topRightClicks != nil { return .topRight }
        }
        if y <= edgeWidth, slideKind(for: .bottom) != nil { return .bottom }
        guard !bottomQuarterOnly || y <= 0.25 else { return nil }
        if x <= edgeWidth, slideKind(for: .left) != nil { return .left }
        if x >= 1 - edgeWidth, slideKind(for: .right) != nil { return .right }
        return nil
    }

    func slideKind(for zone: Zone) -> SlideKind? {
        let kind: SlideKind?
        switch zone {
        case .left: kind = leftAction
        case .right: kind = rightAction
        case .bottom: kind = bottomAction
        case .topLeft, .topRight: kind = nil
        }
        if kind == .brightness, !brightnessAvailable { return nil }
        if kind == .seek, !seekAvailable { return nil }
        return kind
    }

    func clicks(for zone: Zone) -> Int {
        (zone == .topLeft ? topLeftClicks : topRightClicks) ?? 1
    }

    func isInside(strip zone: Zone, touch: TouchPoint) -> Bool {
        let limit = edgeWidth + exitMargin
        switch zone {
        case .left: return touch.x <= limit
        case .right: return touch.x >= 1 - limit
        case .bottom: return touch.y <= limit
        case .topLeft, .topRight: return true
        }
    }
}

/// Turns touch frames and physical clicks from one trackpad into gesture events.
///
/// This type has no system dependencies, so unit tests can drive it with plain values. A gesture
/// needs a single finger that landed in a zone, and corners and click mode also need a physical
/// click. A click that stays swallowed loses both halves, and a click that turns out to be
/// ordinary is replayed. The controller handles the rare cases where macOS loses a mouse-up.
nonisolated struct GestureEngine {
    enum Event: Sendable, Equatable {
        case slideBegan(SlideKind)
        case stepped(Int)
        case seekMoved(Float)
        case slideEnded(SlideKind)
        case slideCanceled(SlideKind)
        /// The pointer may move again. If a slide changed a level before it was canceled, this
        /// comes only after that finger lifts.
        case pointerReleased
        /// The swallowed mouse-down must be delivered now, and the real mouse-up will follow it.
        case passthroughClick
        case cornerFired(Zone)
    }

    struct ClickResult: Sendable, Equatable {
        var swallow: Bool
        var events: [Event]
    }

    private struct Slide {
        let zone: Zone
        let kind: SlideKind
        var id: Int32
        /// The position along the slide's axis that steps are counted from.
        var anchor: Float
        var lastPosition: Float
        /// The position across the slide's axis where the finger started.
        var crossAnchor: Float
        var startedAt: TimeInterval
        var emittedSteps = 0
        /// Whether a touch has passed the dead zone, so that it now counts as a slide.
        var engaged = false
        /// Whether the slide has changed a level or shown a preview, so it is more than a click.
        var moved = false
        var liftedAt: TimeInterval?

        init(zone: Zone, kind: SlideKind, touch: TouchPoint, now: TimeInterval) {
            self.zone = zone
            self.kind = kind
            id = touch.id
            anchor = Self.position(of: touch, in: zone)
            lastPosition = anchor
            crossAnchor = Self.crossPosition(of: touch, in: zone)
            startedAt = now
        }

        /// Starts a new contact over, because a tap that returns must also settle before it counts.
        mutating func restart(with touch: TouchPoint, now: TimeInterval) {
            id = touch.id
            anchor = Self.position(of: touch, in: zone)
            lastPosition = anchor
            crossAnchor = Self.crossPosition(of: touch, in: zone)
            startedAt = now
            liftedAt = nil
        }

        /// The bottom edge runs along the pad's width, and the side edges along its height.
        static func position(of touch: TouchPoint, in zone: Zone) -> Float {
            zone == .bottom ? touch.x : touch.y
        }

        static func crossPosition(of touch: TouchPoint, in zone: Zone) -> Float {
            zone == .bottom ? touch.y : touch.x
        }
    }

    private struct CornerClicks {
        let zone: Zone
        var count: Int
        var lastClick: TimeInterval
    }

    var config = GestureConfig()

    private var touches: [TouchPoint] = []
    private var landing: (id: Int32, zone: Zone)?
    private var slide: Slide?
    private var pressedCorner: Zone?
    private var cornerClicks: CornerClicks?
    private var swallowedDown = false
    /// The finger of a canceled slide. The pointer stays frozen until this finger lifts.
    private var drainingFinger: Int32?

    private var draining: Bool { drainingFinger != nil }
    var isSliding: Bool { slide != nil }
    var hasTouches: Bool { !touches.isEmpty }
    /// Whether this trackpad has a gesture in progress, so that it owns the next click.
    var isBusy: Bool { slide != nil || draining || swallowedDown }
    var touchCount: Int { touches.count }
    var hasLanding: Bool { landing != nil }

    mutating func process(
        _ newTouches: [TouchPoint], now: TimeInterval = 0, modifierSatisfied: Bool = true
    ) -> [Event] {
        let wasEmpty = touches.isEmpty
        touches = newTouches
        if newTouches.count != 1 {
            landing = nil
        } else if wasEmpty, let touch = newTouches.first,
            let zone = config.zone(x: touch.x, y: touch.y)
        {
            landing = (touch.id, zone)
        }
        if let finger = drainingFinger {
            guard !newTouches.contains(where: { $0.id == finger }) else { return [] }
            drainingFinger = nil
            return [.pointerReleased]
        }
        if slide != nil { return updateSlide(now: now, modifierSatisfied: modifierSatisfied) }
        return startTouchSlide(now: now, modifierSatisfied: modifierSatisfied)
    }

    /// Ends a slide whose finger stayed away for longer than the grace period.
    mutating func tick(now: TimeInterval) -> [Event] {
        guard let current = slide, let liftedAt = current.liftedAt,
            now - liftedAt >= config.liftGrace
        else { return [] }
        slide = nil
        guard current.moved else { return cancelUnmoved(current) }
        return [.slideEnded(current.kind), .pointerReleased]
    }

    private mutating func startTouchSlide(now: TimeInterval, modifierSatisfied: Bool) -> [Event] {
        guard !config.requireClick, modifierSatisfied, !swallowedDown, let landing,
            let touch = touches.first, touch.id == landing.id,
            config.zone(x: touch.x, y: touch.y) == landing.zone,
            let kind = config.slideKind(for: landing.zone)
        else { return [] }
        slide = Slide(zone: landing.zone, kind: kind, touch: touch, now: now)
        // Clearing this stops a canceled slide from restarting while the finger stays down.
        self.landing = nil
        return [.slideBegan(kind)]
    }

    /// Decides whether a physical click belongs to a gesture, using the latest touch frame.
    mutating func mouseDown(now: TimeInterval = 0, modifierSatisfied: Bool = true) -> ClickResult {
        // Pressure can ease off and return during a slide, and that press belongs to the slide.
        if slide != nil || draining {
            swallowedDown = true
            return ClickResult(swallow: true, events: [])
        }
        guard let landing, touches.count == 1, let touch = touches.first, touch.id == landing.id,
            config.zone(x: touch.x, y: touch.y) == landing.zone
        else { return ClickResult(swallow: false, events: []) }

        if let kind = config.slideKind(for: landing.zone) {
            guard modifierSatisfied else { return ClickResult(swallow: false, events: []) }
            slide = Slide(zone: landing.zone, kind: kind, touch: touch, now: now)
            swallowedDown = true
            return ClickResult(swallow: true, events: [.slideBegan(kind)])
        }
        pressedCorner = landing.zone
        swallowedDown = true
        return ClickResult(swallow: true, events: [])
    }

    mutating func mouseUp(now: TimeInterval) -> ClickResult {
        guard swallowedDown else { return ClickResult(swallow: false, events: []) }
        swallowedDown = false

        if let zone = pressedCorner {
            pressedCorner = nil
            return ClickResult(swallow: true, events: countCornerClick(zone, now: now))
        }
        if let current = slide, !current.moved {
            slide = nil
            return ClickResult(
                swallow: false,
                events: [.slideCanceled(current.kind), .pointerReleased, .passthroughClick])
        }
        // A slide that has moved keeps going until the finger lifts, so pressure can ease off.
        return ClickResult(swallow: true, events: [])
    }

    /// Recovers when macOS never delivered the mouse-up for a swallowed click.
    mutating func mouseUpLost() -> [Event] {
        swallowedDown = false
        pressedCorner = nil
        guard let current = slide, !current.moved else { return [] }
        slide = nil
        return [.slideCanceled(current.kind), .pointerReleased]
    }

    /// Ends whatever is in progress, such as when the screen locks. Nothing is replayed.
    mutating func abort() -> [Event] {
        var events: [Event] = []
        if let current = slide {
            events = [.slideCanceled(current.kind), .pointerReleased]
        } else if draining {
            events = [.pointerReleased]
        }
        let keptConfig = config
        self = GestureEngine()
        config = keptConfig
        return events
    }

    private mutating func updateSlide(now: TimeInterval, modifierSatisfied: Bool) -> [Event] {
        guard var current = slide else { return [] }
        if touches.isEmpty {
            if current.liftedAt == nil { current.liftedAt = now }
            slide = current
            return []
        }
        if current.liftedAt != nil {
            guard touches.count == 1, let touch = touches.first,
                config.isInside(strip: current.zone, touch: touch)
            else {
                // This is a new gesture rather than the same finger, so the old slide ends here.
                slide = nil
                let ended: [Event] =
                    current.moved
                    ? [.slideEnded(current.kind), .pointerReleased] : cancelUnmoved(current)
                return ended + startTouchSlide(now: now, modifierSatisfied: modifierSatisfied)
            }
            if current.moved || current.engaged {
                // Shifting the anchor means that where the finger returns produces no steps.
                let position = Slide.position(of: touch, in: current.zone)
                current.anchor += position - current.lastPosition
                current.lastPosition = position
                current.id = touch.id
                current.liftedAt = nil
            } else {
                current.restart(with: touch, now: now)
            }
            slide = current
            landing = nil
        }
        guard touches.count == 1, let touch = touches.first, touch.id == current.id,
            config.isInside(strip: current.zone, touch: touch)
        else {
            slide = nil
            guard current.moved else { return cancelUnmoved(current) }
            // The pointer stays frozen until the finger lifts, so it cannot jump mid-motion.
            drainingFinger = current.id
            return [.slideCanceled(current.kind)]
        }

        let position = Slide.position(of: touch, in: current.zone)
        let jump = position - current.lastPosition
        current.lastPosition = position
        if abs(jump) > config.maxFrameJump {
            current.anchor += jump
            slide = current
            return []
        }

        let travel = position - current.anchor
        if !config.requireClick, !current.engaged {
            let sideways = abs(Slide.crossPosition(of: touch, in: current.zone) - current.crossAnchor)
            guard abs(travel) >= config.slideDeadZone, abs(travel) > sideways,
                now - current.startedAt >= config.slideSettleTime
            else {
                slide = current
                return []
            }
            current.engaged = true
            if current.kind != .seek {
                // Steps count from here, so crossing the dead zone cannot jump the level.
                current.anchor = position
                slide = current
                return []
            }
        }

        if current.kind == .seek {
            guard current.moved || current.engaged || abs(travel) >= config.seekDeadZone else {
                slide = current
                return []
            }
            current.moved = true
            slide = current
            return [.seekMoved(travel)]
        }

        let steps = Int(travel / config.stepSize)
        guard steps != current.emittedSteps else {
            slide = current
            return []
        }
        let change = steps - current.emittedSteps
        current.emittedSteps = steps
        current.moved = true
        slide = current
        return [.stepped(change)]
    }

    /// Hands the click back right away, so that a drag or a release that follows stays coherent.
    private mutating func cancelUnmoved(_ current: Slide) -> [Event] {
        var events: [Event] = [.slideCanceled(current.kind), .pointerReleased]
        if swallowedDown {
            swallowedDown = false
            events.append(.passthroughClick)
        }
        return events
    }

    private mutating func countCornerClick(_ zone: Zone, now: TimeInterval) -> [Event] {
        var count = 1
        if let previous = cornerClicks, previous.zone == zone,
            now - previous.lastClick <= config.multiClickWindow
        {
            count = previous.count + 1
        }
        guard count >= config.clicks(for: zone) else {
            cornerClicks = CornerClicks(zone: zone, count: count, lastClick: now)
            return []
        }
        cornerClicks = nil
        return [.cornerFired(zone)]
    }
}
