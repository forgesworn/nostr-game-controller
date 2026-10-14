import Foundation

public struct TiltVector: Equatable {
    public let x: Double, y: Double
}

/// Downward gravity in device axes (x right, y up, z out of the screen).
/// The initial pose is neutral. Rotation takes a new neutral pose, so changing
/// the display orientation never becomes a game movement.
public final class TiltSteering {
    public static let deadzone = 50.0 * 4 / 35
    public private(set) var acceptedSample = false
    private var baseline: TiltVector?
    private var smoothed: [Double]?
    private var lastTime: Double?
    private var lastRotation: Int?
    public init() {}
    public static func inputs(slot: String, mode: String, vector: TiltVector) -> [Input] {
        if hypot(vector.x, vector.y) < deadzone { return Stick.end(slot: slot, mode: mode) }
        return Stick.move(slot: slot, mode: mode, dx: vector.x, dy: vector.y, deadzone: deadzone)
    }
    public func reset() { baseline = nil; smoothed = nil; lastTime = nil; lastRotation = nil; acceptedSample = false }
    public func sample(x: Double, y: Double, z: Double, rotation: Int, time: Double, filterRaw: Bool = false) -> TiltVector? {
        acceptedSample = false
        guard x.isFinite, y.isFinite, z.isFinite, time.isFinite, (0...3).contains(rotation) else { return nil }
        let magnitude = sqrt(x * x + y * y + z * z)
        guard magnitude >= 0.2, magnitude <= 2 else { return nil }
        if lastRotation != rotation { reset(); lastRotation = rotation }
        var values = [x, y, z]
        if filterRaw, let previous = smoothed, let lastTime {
            let alpha = 1 - exp(-max(0, min(0.5, time - lastTime)) / 0.06)
            values = zip(previous, values).map { old, new in old + alpha * (new - old) }
        }
        smoothed = values; lastTime = time; acceptedSample = true
        let gx: Double, gy: Double
        switch rotation {
        case 1: gx = -values[1]; gy = values[0]
        case 2: gx = -values[0]; gy = -values[1]
        case 3: gx = values[1]; gy = -values[0]
        default: gx = values[0]; gy = values[1]
        }
        let pose = TiltVector(x: atan2(gx, hypot(gy, values[2])), y: atan2(-gy, hypot(gx, values[2])))
        guard let neutral = baseline else { baseline = pose; return nil }
        let gain = 50 / (35 * Double.pi / 180)
        return TiltVector(x: (pose.x - neutral.x) * gain, y: (pose.y - neutral.y) * gain)
    }
}
