import Foundation

/// One finger on the trackpad, in normalized coordinates with a bottom-left origin.
nonisolated struct TouchPoint: Sendable, Equatable {
    let id: Int32
    let x: Float
    let y: Float
    /// How hard the finger presses, in the framework's own units.
    var pressure: Float = 0
    /// How much of the sensor the contact covers, in the framework's own units.
    var size: Float = 0
    /// The length of the contact's long axis, which is large for a palm.
    var majorAxis: Float = 0
}

nonisolated enum Zone: String, Sendable, Equatable, Hashable {
    case left, right, bottom, top, topLeft, topRight, bottomLeft, bottomRight
}

nonisolated enum SlideKind: String, Sendable, Equatable, Hashable, Codable, CaseIterable {
    case volume, brightness, seek, scroll, zoom, switchApps, switchSpaces
    case keyboardBacklight, externalBrightness
}

/// The values that shape gesture recognition. All sizes are fractions of the pad.
nonisolated struct GestureConfig: Sendable, Equatable {
    var edgeWidth: Float = 0.10
    var stepSize: Float = 0.035
    /// Actions that jump between whole things need more travel for each step than a level does.
    var switchStepFactor: Float = 3
    var seekDeadZone: Float = 0.025
    /// How far a finger may stray past a strip before the slide cancels.
    var exitMargin: Float = 0.03
    /// The extra stray allowed once a slide has changed something, because a real slide drifts.
    var movedExitMargin: Float = 0.25
    var cornerWidth: Float = 0.20
    var cornerHeight: Float = 0.17
    var multiClickWindow: TimeInterval = 0.45
    /// How long a finger can lose contact before a slide ends. Contact drops out near the pad's rim.
    var liftGrace: TimeInterval = 0.18
    /// Whether a one-finger slide needs a physical click. Otherwise, landing in a strip starts it.
    /// A two-finger slide always starts on touch, because a two-finger click is a secondary click.
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
    var topAction: SlideKind?
    /// What a two-finger slide controls on each edge. An edge with none ignores two fingers.
    var twoFingerActions: [Zone: SlideKind] = [:]
    /// How soon a second finger must land for two fingers to count as one gesture.
    var twoFingerWindow: TimeInterval = 0.15
    /// Actions that cannot work right now, so their edges stay normal parts of the trackpad.
    var unavailableKinds: Set<SlideKind> = []
    /// The click counts that fire each corner. A corner with none is a normal part of the pad.
    var cornerCounts: [Zone: Set<Int>] = [.topLeft: [1]]
    /// The pressure that counts as a corner press, or nil to need a physical click. Measured on
    /// the built-in trackpad, resting fingers and taps peak near 50, and clicks start near 120.
    var pressThreshold: Float?
    /// The pressure that a finger must fall below before it can press again.
    var pressRelease: Float = 50
    /// A contact this long and this large is a palm. Fingers measured up to 12.5 long, and a firm
    /// click flattens a finger to about 1.3 in size, so both are needed for the first check.
    var palmAxis: Float = 13
    var palmAxisSize: Float = 1.2
    /// A contact this large is a palm whatever its shape.
    var palmSize: Float = 1.6

    /// Returns the zone at a point, testing corners, then top, bottom, left, and right. A corner
    /// with no action does not count, so the edge beneath it still works.
    func zone(x: Float, y: Float) -> Zone? {
        corner(x: x, y: y) ?? strip(x: x, y: y) { slideKind(for: $0) != nil }
    }

    /// Returns the strip at a point that has a two-finger action. Corners keep their priority.
    func twoFingerZone(x: Float, y: Float) -> Zone? {
        guard corner(x: x, y: y) == nil else { return nil }
        return strip(x: x, y: y) { twoFingerKind(for: $0) != nil }
    }

    private func corner(x: Float, y: Float) -> Zone? {
        if y >= 1 - cornerHeight {
            if x <= cornerWidth, hasCorner(.topLeft) { return .topLeft }
            if x >= 1 - cornerWidth, hasCorner(.topRight) { return .topRight }
        }
        if y <= cornerHeight {
            if x <= cornerWidth, hasCorner(.bottomLeft) { return .bottomLeft }
            if x >= 1 - cornerWidth, hasCorner(.bottomRight) { return .bottomRight }
        }
        return nil
    }

    private func strip(x: Float, y: Float, where isActive: (Zone) -> Bool) -> Zone? {
        if y >= 1 - edgeWidth, isActive(.top) { return .top }
        if y <= edgeWidth, isActive(.bottom) { return .bottom }
        guard !bottomQuarterOnly || y <= 0.25 else { return nil }
        if x <= edgeWidth, isActive(.left) { return .left }
        if x >= 1 - edgeWidth, isActive(.right) { return .right }
        return nil
    }

    private func hasCorner(_ zone: Zone) -> Bool {
        cornerCounts[zone]?.isEmpty == false
    }

    func isPalm(_ touch: TouchPoint) -> Bool {
        touch.size >= palmSize || (touch.majorAxis >= palmAxis && touch.size >= palmAxisSize)
    }

    func stepSize(for kind: SlideKind) -> Float {
        kind == .switchApps || kind == .switchSpaces ? stepSize * switchStepFactor : stepSize
    }

    func slideKind(for zone: Zone) -> SlideKind? {
        let kind: SlideKind?
        switch zone {
        case .left: kind = leftAction
        case .right: kind = rightAction
        case .bottom: kind = bottomAction
        case .top: kind = topAction
        case .topLeft, .topRight, .bottomLeft, .bottomRight: kind = nil
        }
        if let kind, unavailableKinds.contains(kind) { return nil }
        return kind
    }

    func twoFingerKind(for zone: Zone) -> SlideKind? {
        guard let kind = twoFingerActions[zone], !unavailableKinds.contains(kind) else { return nil }
        return kind
    }

    func isInside(strip zone: Zone, touch: TouchPoint, moved: Bool = false) -> Bool {
        let limit = edgeWidth + exitMargin + (moved ? movedExitMargin : 0)
        switch zone {
        case .left: return touch.x <= limit
        case .right: return touch.x >= 1 - limit
        case .bottom: return touch.y <= limit
        case .top: return touch.y >= 1 - limit
        case .topLeft, .topRight, .bottomLeft, .bottomRight: return true
        }
    }
}

/// Turns touch frames and physical clicks from one trackpad into gesture events.
///
/// This type has no system dependencies, so unit tests can drive it with plain values. A gesture
/// needs a single finger that landed in a zone, or two that landed together in a strip with a
/// two-finger action. A slide starts on landing, or on a physical click in click mode for one
/// finger, and a corner fires on a press or a physical click. A click that stays swallowed
/// loses both halves, and a click that turns out to be ordinary is replayed. The controller
/// handles the rare cases where macOS loses a mouse-up.
nonisolated struct GestureEngine {
    enum Event: Sendable, Equatable {
        case slideBegan(SlideKind)
        case stepped(Int)
        case seekMoved(Float)
        case slideEnded(SlideKind)
        case slideCanceled(SlideKind)
        /// The pointer may move again. If a slide changed a level before it was canceled, or a
        /// two-finger slide ended with a finger still down, this comes only after they lift.
        case pointerReleased
        /// The swallowed mouse-down must be delivered now, and the real mouse-up will follow it.
        case passthroughClick
        /// A corner press counted, and the corner is waiting to see if more follow.
        case cornerCounted
        /// A corner fires at once, because no higher click count can follow.
        case cornerFired(Zone, clicks: Int)
        /// A corner fires after its wait, and the press that led to it was already confirmed.
        case cornerSettled(Zone, clicks: Int)
    }

    struct ClickResult: Sendable, Equatable {
        var swallow: Bool
        var events: [Event]
    }

    private struct Slide {
        let zone: Zone
        let kind: SlideKind
        var id: Int32
        /// The fingers of a two-finger slide and where each last was along the slide's axis. A
        /// two-finger slide follows the point between them, and a one-finger slide leaves this empty.
        var fingers: [Int32: Float] = [:]
        var isPair: Bool { !fingers.isEmpty }
        /// The position along the slide's axis that steps are counted from.
        var anchor: Float
        var lastPosition: Float
        /// The position across the slide's axis where the finger started.
        var crossAnchor: Float
        /// The latest position across the slide's axis, which tells a returning finger from a
        /// new one.
        var lastCross: Float
        var startedAt: TimeInterval
        var emittedSteps = 0
        /// The sign of the last step, which a step that turns back must overcome by a margin.
        var stepDirection = 0
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
            lastCross = crossAnchor
            startedAt = now
        }

        /// Starts a new contact over, because a tap that returns must also settle before it counts.
        mutating func restart(with touch: TouchPoint, now: TimeInterval) {
            id = touch.id
            anchor = Self.position(of: touch, in: zone)
            lastPosition = anchor
            crossAnchor = Self.crossPosition(of: touch, in: zone)
            lastCross = crossAnchor
            startedAt = now
            liftedAt = nil
        }

        /// The top and bottom edges run along the pad's width, and the sides along its height.
        static func position(of touch: TouchPoint, in zone: Zone) -> Float {
            isHorizontal(zone) ? touch.x : touch.y
        }

        static func crossPosition(of touch: TouchPoint, in zone: Zone) -> Float {
            isHorizontal(zone) ? touch.y : touch.x
        }

        private static func isHorizontal(_ zone: Zone) -> Bool {
            zone == .bottom || zone == .top
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
    /// The fingers of a slide that is over. The pointer stays frozen until they have all lifted.
    private var drainingFingers: Set<Int32> = []
    /// Every contact on the pad, including palms, because a finger that becomes a palm is still down.
    private var rawTouchIDs: Set<Int32> = []
    /// The strip with a two-finger action where each contact landed, which can be none.
    private var landedStrips: [Int32: Zone?] = [:]
    /// Contacts judged to be palms, which stay palms until they lift.
    private var palms: Set<Int32> = []
    private var pressHeld = false
    /// True when a pressure press already counted, so the physical click that follows does not.
    private var pressCounted = false
    /// When the first of the current fingers landed, while a second can still join it.
    private var firstContactAt: TimeInterval?

    private var draining: Bool { !drainingFingers.isEmpty }
    var isDraining: Bool { draining }
    var isSliding: Bool { slide != nil }
    /// Whether a slide's fingers have left, so that it ends if they stay away.
    var isAwaitingLift: Bool { slide?.liftedAt != nil }
    var hasTouches: Bool { !touches.isEmpty }

    /// How long until a slide whose fingers have left ends, or nil if no slide is waiting. A
    /// finger can return and leave again, which starts the wait over.
    func liftGraceRemaining(now: TimeInterval) -> TimeInterval? {
        guard let liftedAt = slide?.liftedAt else { return nil }
        return max(liftedAt + config.liftGrace - now, 0)
    }

    /// Whether this trackpad has a gesture in progress, so that it owns the next click.
    var isBusy: Bool { slide != nil || draining || swallowedDown }
    var touchCount: Int { touches.count }
    var hasLanding: Bool { landing != nil }

    mutating func process(
        _ rawTouches: [TouchPoint], now: TimeInterval = 0, modifierSatisfied: Bool = true
    ) -> [Event] {
        rawTouchIDs = Set(rawTouches.map(\.id))
        palms.formIntersection(rawTouchIDs)
        palms.formUnion(rawTouches.filter(config.isPalm).map(\.id))
        let newTouches = rawTouches.filter { !palms.contains($0.id) }
        let wasEmpty = touches.isEmpty
        touches = newTouches
        // A new contact starts fresh, unless its click from the last contact is still open.
        if wasEmpty, !newTouches.isEmpty, !swallowedDown { pressCounted = false }
        if wasEmpty, !newTouches.isEmpty { firstContactAt = now }
        landedStrips = landedStrips.filter { rawTouchIDs.contains($0.key) }
        for touch in newTouches where !landedStrips.keys.contains(touch.id) {
            landedStrips[touch.id] = .some(config.twoFingerZone(x: touch.x, y: touch.y))
        }
        if newTouches.count != 1 {
            landing = nil
        } else if wasEmpty, let touch = newTouches.first,
            let zone = config.zone(x: touch.x, y: touch.y)
        {
            landing = (touch.id, zone)
        }
        if draining {
            drainingFingers.formIntersection(rawTouchIDs)
            return draining ? [] : [.pointerReleased]
        }
        if let events = startPairSlide(now: now, modifierSatisfied: modifierSatisfied) {
            return events
        }
        if slide?.isPair == true { return updatePairSlide(now: now) }
        if slide != nil {
            let events = updateSlide(now: now, modifierSatisfied: modifierSatisfied)
            // A slide that a second finger ended uses up that finger's chance to join it.
            if slide == nil { firstContactAt = nil }
            return events
        }
        return updateCornerPress(now: now)
            + startTouchSlide(now: now, modifierSatisfied: modifierSatisfied)
    }

    /// Counts a corner press from pressure alone, so a corner needs no physical click. Separate
    /// press and release levels stop a wobbling finger from counting twice.
    private mutating func updateCornerPress(now: TimeInterval) -> [Event] {
        guard touches.count == 1, let touch = touches.first, let threshold = config.pressThreshold,
            let landing, touch.id == landing.id, config.slideKind(for: landing.zone) == nil,
            config.zone(x: touch.x, y: touch.y) == landing.zone
        else {
            if touches.isEmpty { pressHeld = false }
            return []
        }
        if pressHeld {
            if touch.pressure < config.pressRelease { pressHeld = false }
            return []
        }
        guard touch.pressure >= threshold else { return [] }
        pressHeld = true
        pressCounted = true
        return countCornerClick(landing.zone, now: now)
    }

    /// Handles what waits on time: a corner's click window and a slide's lift grace.
    mutating func tick(now: TimeInterval) -> [Event] {
        settleCorner(now: now) + endLiftedSlide(now: now)
    }

    /// Fires a waiting corner once its click window has closed.
    private mutating func settleCorner(now: TimeInterval) -> [Event] {
        guard let pending = cornerClicks, now - pending.lastClick > config.multiClickWindow else {
            return []
        }
        return settled(pending)
    }

    private mutating func settled(_ pending: CornerClicks) -> [Event] {
        cornerClicks = nil
        guard config.cornerCounts[pending.zone]?.contains(pending.count) == true else { return [] }
        return [.cornerSettled(pending.zone, clicks: pending.count)]
    }

    /// Ends a slide whose finger stayed away for longer than the grace period.
    private mutating func endLiftedSlide(now: TimeInterval) -> [Event] {
        guard let current = slide, let liftedAt = current.liftedAt,
            now - liftedAt >= config.liftGrace
        else { return [] }
        return leave(current)
    }

    /// Starts a two-finger slide when both fingers landed in one strip within a short window. A
    /// slide that one finger began gives way, as long as it has done nothing yet.
    private mutating func startPairSlide(now: TimeInterval, modifierSatisfied: Bool) -> [Event]? {
        guard touches.count == 2, let firstContactAt, now - firstContactAt <= config.twoFingerWindow,
            modifierSatisfied, !swallowedDown, slide?.engaged != true, slide?.moved != true,
            let zone = landedStrips[touches[0].id] ?? nil,
            (landedStrips[touches[1].id] ?? nil) == zone,
            let kind = config.twoFingerKind(for: zone)
        else { return nil }
        let canceled: [Event] = slide.map { [.slideCanceled($0.kind)] } ?? []
        var pair = Slide(zone: zone, kind: kind, touch: midpoint, now: now)
        pair.fingers = fingerPositions(in: zone)
        slide = pair
        self.firstContactAt = nil
        return canceled + [.slideBegan(kind)]
    }

    /// The point between two fingers, which moves like one finger.
    private var midpoint: TouchPoint {
        TouchPoint(
            id: touches[0].id, x: (touches[0].x + touches[1].x) / 2,
            y: (touches[0].y + touches[1].y) / 2)
    }

    private func fingerPositions(in zone: Zone) -> [Int32: Float] {
        Dictionary(
            touches.map { ($0.id, Slide.position(of: $0, in: zone)) }, uniquingKeysWith: { $1 })
    }

    private mutating func updatePairSlide(now: TimeInterval) -> [Event] {
        guard var current = slide else { return [] }
        guard touches.count <= 2 else { return leave(current) }
        let hasNewFinger = touches.contains { current.fingers[$0.id] == nil }
        guard touches.count == 2 else {
            guard !hasNewFinger else { return leave(current) }
            // One finger leaves before the other, and contact can drop out near the pad's rim.
            if current.liftedAt == nil { current.liftedAt = now }
            slide = current
            return []
        }
        let touch = midpoint
        let position = Slide.position(of: touch, in: current.zone)
        let cross = Slide.crossPosition(of: touch, in: current.zone)
        // A lost contact can return as a new finger, but only close to where the pair was.
        let isReturning =
            current.liftedAt != nil && abs(cross - current.lastCross) <= config.maxFrameJump
            && abs(position - current.lastPosition) <= config.maxFrameJump
        guard !hasNewFinger || isReturning,
            config.isInside(strip: current.zone, touch: touch, moved: current.moved)
        else { return leave(current) }

        // The midpoint halves one finger's glitch, so each finger is checked on its own.
        let positions = fingerPositions(in: current.zone)
        let hasGlitch = positions.contains { id, value in
            current.fingers[id].map { abs(value - $0) > config.maxFrameJump } ?? false
        }
        current.fingers = positions
        if current.liftedAt != nil || hasGlitch {
            // Shifting the anchor means that this change of contact produces no steps.
            current.anchor += position - current.lastPosition
            current.lastPosition = position
            current.lastCross = cross
            current.liftedAt = nil
        }
        guard !hasGlitch else {
            slide = current
            return []
        }
        return advance(current, position: position, cross: cross, now: now)
    }

    /// Ends a slide whose fingers are gone or have become another gesture. If it changed
    /// something, the pointer stays frozen until the fingers of that motion lift.
    private mutating func leave(_ current: Slide) -> [Event] {
        slide = nil
        guard current.moved else { return cancelUnmoved(current) }
        let isFinished = current.liftedAt != nil
        let event: Event = isFinished ? .slideEnded(current.kind) : .slideCanceled(current.kind)
        drainingFingers =
            isFinished ? Set(current.fingers.keys).intersection(rawTouchIDs) : rawTouchIDs
        return drainingFingers.isEmpty ? [event, .pointerReleased] : [event]
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
            if pressCounted {
                pressCounted = false
                return ClickResult(swallow: true, events: [])
            }
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
        pressCounted = false
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
            // A drifted slide keeps its allowance only if the finger returns close to where it was.
            let isNearby = touches.first.map {
                abs(Slide.crossPosition(of: $0, in: current.zone) - current.lastCross)
                    <= config.maxFrameJump
            }
            guard touches.count == 1, let touch = touches.first,
                config.isInside(
                    strip: current.zone, touch: touch,
                    moved: current.moved && isNearby == true)
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
                current.lastCross = Slide.crossPosition(of: touch, in: current.zone)
                current.id = touch.id
                current.liftedAt = nil
            } else {
                current.restart(with: touch, now: now)
            }
            slide = current
            landing = nil
        }
        guard touches.count == 1, let touch = touches.first, touch.id == current.id,
            config.isInside(strip: current.zone, touch: touch, moved: current.moved)
        else {
            slide = nil
            guard current.moved else { return cancelUnmoved(current) }
            // The pointer stays frozen until the finger lifts, so it cannot jump mid-motion.
            drainingFingers = [current.id]
            return [.slideCanceled(current.kind)]
        }

        return advance(
            current, position: Slide.position(of: touch, in: current.zone),
            cross: Slide.crossPosition(of: touch, in: current.zone), now: now)
    }

    /// Moves a slide to a new position, and returns whatever that changes.
    private mutating func advance(
        _ slide: Slide, position: Float, cross: Float, now: TimeInterval
    ) -> [Event] {
        var current = slide
        let jump = position - current.lastPosition
        current.lastPosition = position
        current.lastCross = cross
        if abs(jump) > config.maxFrameJump {
            current.anchor += jump
            self.slide = current
            return []
        }

        let travel = position - current.anchor
        // A two-finger slide never needs a click, because a two-finger click is a secondary click.
        if !config.requireClick || current.isPair, !current.engaged {
            let sideways = abs(cross - current.crossAnchor)
            guard abs(travel) >= config.slideDeadZone, abs(travel) > sideways,
                now - current.startedAt >= config.slideSettleTime
            else {
                self.slide = current
                return []
            }
            current.engaged = true
            if current.kind != .seek {
                // Steps count from here, so crossing the dead zone cannot jump the level.
                current.anchor = position
                self.slide = current
                return []
            }
        }

        if current.kind == .seek {
            guard current.moved || current.engaged || abs(travel) >= config.seekDeadZone else {
                self.slide = current
                return []
            }
            current.moved = true
            self.slide = current
            return [.seekMoved(travel)]
        }

        // A finger that rests on the line between two steps must not flip the level back and forth.
        let steps = StepCount.count(
            at: travel / config.stepSize(for: current.kind), from: current.emittedSteps,
            direction: current.stepDirection)
        guard steps != current.emittedSteps else {
            self.slide = current
            return []
        }
        let change = steps - current.emittedSteps
        current.emittedSteps = steps
        current.stepDirection = change.signum()
        current.moved = true
        self.slide = current
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

    /// Counts one press or click. The highest configured count fires at once, and a lower one waits
    /// for the click window to close, so that a single click can still become a double click.
    private mutating func countCornerClick(_ zone: Zone, now: TimeInterval) -> [Event] {
        var events: [Event] = []
        var count = 1
        if let previous = cornerClicks {
            if previous.zone == zone, now - previous.lastClick <= config.multiClickWindow {
                count = previous.count + 1
            } else {
                events = settled(previous)
            }
        }
        guard let highest = config.cornerCounts[zone]?.max() else { return events }
        guard count >= highest else {
            cornerClicks = CornerClicks(zone: zone, count: count, lastClick: now)
            return events + [.cornerCounted]
        }
        cornerClicks = nil
        return events + [.cornerFired(zone, clicks: highest)]
    }
}
