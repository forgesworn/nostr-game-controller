import Foundation

public enum PairingCode {
    public static func display(_ code: String) -> String {
        guard code.range(of: "^[a-zA-Z0-9]{6}$", options: .regularExpression) != nil else { return code }
        return String(code.prefix(3)) + " " + String(code.suffix(3))
    }
    public static func normalize(_ input: String) -> String {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.range(of: "^[a-zA-Z0-9]{3}[\\s-]+[a-zA-Z0-9]{3}$", options: .regularExpression) != nil {
            return text.replacingOccurrences(of: "[\\s-]", with: "", options: .regularExpression).uppercased()
        }
        return text.uppercased()
    }
}

public struct Pairing: Equatable, Codable {
    public let session: String
    public let broker: URL
    public var key: String { "v2|\(broker.absoluteString)|\(session)" }
    public var socketURL: URL {
        var url = URLComponents(url: broker, resolvingAgainstBaseURL: false)!
        url.queryItems = [URLQueryItem(name: "s", value: session), URLQueryItem(name: "r", value: "phone"), URLQueryItem(name: "v", value: "2"), URLQueryItem(name: "recover", value: "1")]
        return url.url!
    }
    public static func parse(_ input: String, allowLoopback: Bool = false) throws -> Pairing {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        var session = PairingCode.normalize(text), endpoint = "wss://controller.pallasite.app/"
        if let url = URLComponents(string: text), let scheme = url.scheme {
            guard ["https", "joystick"].contains(scheme.lowercased()), url.user == nil, url.password == nil else { throw ProtocolError.invalidPairing }
            let items = url.queryItems ?? []
            guard items.filter({ $0.name == "s" }).count == 1,
                  items.filter({ $0.name == "v" }).count == 1,
                  items.first(where: { $0.name == "v" })?.value == "2",
                  items.filter({ $0.name == "w" }).count <= 1 else { throw ProtocolError.invalidPairing }
            session = items.first(where: { $0.name == "s" })?.value ?? ""
            endpoint = items.first(where: { $0.name == "w" })?.value ?? endpoint
        }
        guard session.range(of: "^[a-zA-Z0-9_-]{6,128}$", options: .regularExpression) != nil,
              var url = URLComponents(string: endpoint), url.host != nil,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.scheme == "wss" || (allowLoopback && url.scheme == "ws" && ["localhost", "127.0.0.1", "::1"].contains(url.host!)) else { throw ProtocolError.invalidPairing }
        if url.path.isEmpty { url.path = "/" }
        guard let broker = url.url else { throw ProtocolError.invalidPairing }
        return Pairing(session: session, broker: broker)
    }
}

public enum ProtocolError: Error, LocalizedError {
    case invalidPairing, unsupportedControls
    public var errorDescription: String? {
        switch self {
        case .invalidPairing: return "Use a six-letter code or a version 2 Joystick pairing link with a secure broker."
        case .unsupportedControls: return "This game's controls are not supported by this version of Joystick."
        }
    }
}
public struct Slot: Codable, Equatable {
    public var graphic: InlineGraphic? = nil
    public var mode: String?
    public var tapAction: String?
    public var icon: String?
    public var label: String?
    public var colour: String?
}
public struct ControllerSpec: Codable, Equatable {
    public var layout: ControllerLayout? = nil
    public var theme: ControllerTheme? = nil
    public var name: String
    public var version: Int
    public var slots: [String: Slot]
    public static func decode(_ data: Data) throws -> ControllerSpec {
        guard data.count <= 49152 else { throw ProtocolError.unsupportedControls }
        guard let object = try JSONSerialization.jsonObject(with:data) as? [String:Any] else { throw ProtocolError.unsupportedControls }
        func validOptional(_ object: [String:Any],_ fields:[String]) -> Bool { fields.allSatisfy { !(object[$0] is NSNull) } }
        guard validOptional(object,["layout","theme"]) else { throw ProtocolError.unsupportedControls }
        if let slots = object["slots"] as? [String:[String:Any]] { for slot in slots.values {
            guard validOptional(slot,["mode","label","icon","colour","graphic","tapAction"]) else { throw ProtocolError.unsupportedControls }
        } }
        if let theme = object["theme"] as? [String:Any], !validOptional(theme,["background","accent"]) { throw ProtocolError.unsupportedControls }
        if let layout = object["layout"] as? [String:Any] {
            guard validOptional(layout,["portrait","landscape"]) else { throw ProtocolError.unsupportedControls }
            for orientation in ["portrait","landscape"] { if let map = layout[orientation] as? [String:[String:Any]] { for placement in map.values {
                guard validOptional(placement,["shape","zone"]) else { throw ProtocolError.unsupportedControls }
            } } }
        }
        let spec = try JSONDecoder().decode(ControllerSpec.self,from:data)
        try spec.validate(); return spec
    }
    public func validate() throws {
        let allowed = Set(["joyL", "joyR", "A", "B", "X", "Y", "L1", "L2", "R1", "R2", "start", "select", "dpadU", "dpadD", "dpadL", "dpadR"])
        guard version == 1, name.utf16.count <= 128, slots.count <= 16,
              slots.allSatisfy({ allowed.contains($0.key) && ($0.value.mode == nil || ["heading", "xy", "tilt"].contains($0.value.mode!))
                && ($0.value.graphic?.valid ?? true) && ($0.value.colour.map(ControllerTheme.colour) ?? true)
                && ($0.value.label?.utf16.count ?? 0) <= 48 && ($0.value.icon?.utf16.count ?? 0) <= 64
                && ($0.value.tapAction == nil || allowed.contains($0.value.tapAction!)) }),
              slots.values.reduce(0, { $0 + ($1.graphic?.png.count ?? 0) }) <= 32768,
              theme?.valid ?? true, layout?.valid(keys: Set(slots.keys)) ?? true else { throw ProtocolError.unsupportedControls }
    }
}
public struct Feedback: Codable {
    public var message: String
    public var selected: String?
    public var locked: Bool?
    public var tone: String?
}
public struct Input: Equatable, Codable {
    public let k: String
    public let v: String
    public init(_ key: String, _ value: String) { k = key; v = value }
}
public enum Stick {
    public static func move(slot: String, mode: String, dx: Double, dy: Double, radius: Double = 50, deadzone: Double = 18) -> [Input] {
        guard dx.isFinite, dy.isFinite, radius > 0 else { return end(slot: slot, mode: mode) }
        let distance = hypot(dx, dy), divisor = max(radius, distance)
        let axes = mode == "xy" ? [Input("\(slot)-x", "\(Int(floor(dx / divisor * 1000 + 0.5)))"), Input("\(slot)-y", "\(Int(floor(dy / divisor * 1000 + 0.5)))")] : [Input(slot, "\(Int(floor(atan2(dy, dx) * 1000 + 0.5)))")]
        return axes + [Input("\(slot)-thrust", distance >= deadzone ? "1" : "0"), Input("\(slot)-power", "\(distance >= deadzone ? Int((min(1, distance / radius) * 1000).rounded()) : 0)")]
    }
    public static func end(slot: String, mode: String) -> [Input] {
        var frames = [Input("\(slot)-thrust", "0"), Input("\(slot)-power", "0"), Input("\(slot)-end", "1")]
        if mode == "xy" { frames += [Input("\(slot)-x", "0"), Input("\(slot)-y", "0")] }
        return frames
    }
}
