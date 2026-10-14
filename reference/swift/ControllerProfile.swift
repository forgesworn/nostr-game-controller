import Foundation

public struct InlineGraphic: Codable, Equatable {
    public var png: String
    public var valid: Bool {
        guard png.count <= 12288, png.count % 4 == 0, png.range(of: "^[A-Za-z0-9+/]+={0,2}$", options: .regularExpression) != nil, let data = Data(base64Encoded: png), data.count >= 24,
              Array(data.prefix(8)) == [137,80,78,71,13,10,26,10], String(data: data[12..<16], encoding: .ascii) == "IHDR" else { return false }
        func word(_ n: Int) -> Int { data[n..<n+4].reduce(0) { $0 * 256 + Int($1) } }
        return (1...256).contains(word(16)) && (1...256).contains(word(20))
    }
}
public struct ControlZone: Codable, Equatable { public var x: Double, y: Double, width: Double, height: Double }
public struct ControlPlacement: Codable, Equatable {
    public var x: Double, y: Double, size: Double
    public var shape: String?
    public var zone: ControlZone?
    public func valid(stick: Bool) -> Bool {
        guard x.isFinite, y.isFinite, size.isFinite, (0...1).contains(x), (0...1).contains(y),
              (stick ? 96.0...192.0 : 48.0...192.0).contains(size), shape == nil || ["circle", "rounded"].contains(shape!) else { return false }
        if let z = zone {
            guard stick, [z.x,z.y,z.width,z.height].allSatisfy(\.isFinite), z.x >= 0, z.y >= 0, z.width >= 0.1, z.height >= 0.1,
                  z.x + z.width <= 1.000001, z.y + z.height <= 1.000001, x >= z.x, x <= z.x + z.width, y >= z.y, y <= z.y + z.height else { return false }
        }
        return true
    }
}
public struct ControllerLayout: Codable, Equatable {
    public var version: Int
    public var portrait: [String: ControlPlacement]?
    public var landscape: [String: ControlPlacement]?
    public func valid(keys: Set<String>) -> Bool {
        guard version == 1, portrait != nil || landscape != nil else { return false }
        return [portrait,landscape].compactMap { $0 }.allSatisfy { map in
            Set(map.keys) == keys && map.allSatisfy { $0.value.valid(stick: $0.key.hasPrefix("joy")) }
        }
    }
    public func controls(width w: Double, height h: Double, keys: Set<String>) -> [ThumbControl]? {
        guard w >= 200, h >= 160, valid(keys: keys), let map = w > h ? landscape : portrait else { return nil }
        let ordered = keys.filter { !$0.hasPrefix("joy") }.sorted() + keys.filter { $0.hasPrefix("joy") }.sorted()
        let controls: [ThumbControl] = ordered.compactMap { key in
            guard let p = map[key] else { return nil }
            let size = min(p.size, w-8, h-8), x = max(size/2+4,min(w-size/2-4,p.x*w)), y = max(size/2+4,min(h-size/2-4,p.y*h))
            var rect = PadRect(x-size/2,y-size/2,size,size)
            if let z = p.zone { rect = PadRect(z.x*w,z.y*h,z.width*w,z.height*h) }
            let shape = key.hasPrefix("joy") ? "stick" : p.shape == "rounded" ? "utility" : "face"
            return ThumbControl(key,shape,rect,x,y,size)
        }
        func overlaps(_ a: PadRect, _ b: PadRect) -> Bool { min(a.x+a.width,b.x+b.width)-max(a.x,b.x) > 0.01 && min(a.y+a.height,b.y+b.height)-max(a.y,b.y) > 0.01 }
        for a in controls where a.key.hasPrefix("joy") {
            guard a.anchorX >= a.rect.x, a.anchorX <= a.rect.x+a.rect.width, a.anchorY >= a.rect.y, a.anchorY <= a.rect.y+a.rect.height else { return nil }
        }
        for i in controls.indices { for j in controls.indices where j > i {
            let a = controls[i], b = controls[j]
            if a.key.hasPrefix("joy") == b.key.hasPrefix("joy") && overlaps(a.rect,b.rect) { return nil }
        } }
        return controls
    }
}
public struct ControllerTheme: Codable, Equatable {
    public var background: String?
    public var accent: String?
    public var valid: Bool { [background,accent].compactMap { $0 }.allSatisfy(Self.colour) }
    public static func colour(_ value: String) -> Bool { value.range(of: "^#[0-9a-fA-F]{3}([0-9a-fA-F]{3})?$", options: .regularExpression) != nil }
}
