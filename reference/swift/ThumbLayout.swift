import Foundation

public struct PadRect: Equatable {
    public let x: Double, y: Double, width: Double, height: Double
    public var midX: Double { x + width / 2 }
    public var midY: Double { y + height / 2 }
    public init(_ x: Double, _ y: Double, _ width: Double, _ height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
}

public struct ThumbControl: Equatable {
    public let key: String, shape: String
    public let rect: PadRect
    public let anchorX: Double, anchorY: Double, diameter: Double
    public init(_ key: String, _ shape: String, _ rect: PadRect, _ anchorX: Double? = nil, _ anchorY: Double? = nil, _ diameter: Double? = nil) {
        self.key = key; self.shape = shape; self.rect = rect
        self.anchorX = anchorX ?? rect.midX; self.anchorY = anchorY ?? rect.midY
        self.diameter = diameter ?? min(rect.width, rect.height)
    }
}

/// Geometry uses points/dp, with bounded controls beside the hands rather than
/// stretching them across a tablet. Buttons precede the floating stick zones.
public enum ThumbLayout {
    public static func controls(width w: Double, height h: Double, keys: Set<String>) -> [ThumbControl] {
        guard w >= 200, h >= 160 else { return [] }
        var result: [ThumbControl] = []
        func box(_ key: String, _ shape: String, _ x: Double, _ y: Double, _ width: Double, _ height: Double) {
            result.append(ThumbControl(key, shape, PadRect(x, y, width, height)))
        }
        func circle(_ key: String, _ x: Double, _ y: Double, _ size: Double) {
            box(key, "face", x - size / 2, y - size / 2, size, size)
        }
        let extraDirections = keys.contains("joyL") ? ["dpadU", "dpadL", "dpadR", "dpadD"] : []
        let faceKeys = ["A", "B", "X", "Y"].filter { keys.contains($0) }
        let shoulders = ["R1", "R2"].filter { keys.contains($0) }
        let actionShoulders = !keys.contains("joyR") && (keys.contains("joyL") || keys.contains(where: { $0.hasPrefix("dpad") })) && !faceKeys.isEmpty && faceKeys.count + shoulders.count <= 4 ? shoulders : []
        let utility = (["L2", "L1"] + extraDirections + ["select", "start", "R1", "R2"]).filter { keys.contains($0) && !actionShoulders.contains($0) }
        let columns = max(1, min(utility.count, Int((w - 8) / 52)))
        let rows = utility.isEmpty ? 0 : (utility.count + columns - 1) / columns
        let cell = min(80, (w - 8) / Double(columns))
        let utilityWidth = cell * Double(columns)
        for (index, key) in utility.enumerated() {
            box(key, key.hasPrefix("dpad") ? "dpad" : "utility", (w - utilityWidth) / 2 + Double(index % columns) * cell + 2, Double(index / columns) * 52 + 4, cell - 4, 48)
        }
        let top = Double(rows) * 52 + (rows == 0 ? 8 : 12)
        let available = h - top - 16
        let hasLeft = keys.contains("joyL") || keys.contains(where: { $0.hasPrefix("dpad") })
        let faces = ["A", "B", "X", "Y"].filter { keys.contains($0) }
        let leftX = max(96, min(116, w * 0.24)), rightX = w - max(96, min(116, w * 0.24))
        let stickDiameter = min(152, min(w * 0.40, available * 0.78))
        let thumbY = min(h - stickDiameter / 2 - 16, h - min(112, available * 0.40))

        if !hasLeft && !keys.contains("joyR") && !faces.isEmpty {
            // Answer games use two reachable columns, one for each thumb.
            let columns = faces.count == 1 ? 1 : 2
            let rows = (faces.count + columns - 1) / columns
            let bw = min(180, (w - 40) / Double(columns))
            let bh = min(100, (available - Double(rows - 1) * 12) / Double(rows))
            let y = h - 16 - Double(rows) * bh - Double(rows - 1) * 12
            for (index, key) in faces.enumerated() {
                let x = columns == 1 ? (w - bw) / 2 : (index % 2 == 0 ? 16 : w - bw - 16)
                box(key, "answer", x, y + Double(index / columns) * (bh + 12), bw, bh)
            }
        } else if !faces.isEmpty && !keys.contains("joyR") {
            // Keep a broad primary action and compact secondary cluster beside the hand.
            let actions = faces + actionShoulders, secondary = Array(actions.dropFirst())
            let cols = w >= 560 && available < 200 ? 3 : 2
            let count = (secondary.count + cols - 1) / cols, gap = 10.0, bw = min(cols == 3 ? 184 : 160, w * 0.5 - 32)
            let size = max(48, min(64, min((bw - Double(cols - 1) * gap) / Double(cols), count > 0 ? (available - 48 - Double(count) * gap) / Double(count) : 64)))
            let bh = min(80, available - Double(count) * (size + gap)), x = w - 16 - bw, y = h - 16 - bh
            box(actions[0], "answer", x, y, bw, bh)
            for (index, key) in secondary.enumerated() {
                box(key, "answer", w - 16 - size - Double(index % cols) * (size + gap), y - Double(index / cols + 1) * (size + gap), size, size)
            }
        } else if !faces.isEmpty {
            let dual = keys.contains("joyR")
            let inboard = dual && w >= 560
            let directionInset = !keys.contains("joyL") && hasLeft ? min(16, w * 0.04) : 0
            let cx = inboard ? rightX - 184 : rightX + directionInset
            let cy = dual && !inboard ? thumbY - stickDiameter / 2 - 100 : thumbY
            let space = dual && !inboard ? max(96, available - stickDiameter - 20) : available
            if faces.count == 1 {
                circle(faces[0], cx, max(top + 44, cy), min(92, space * 0.7))
            } else if faces.count <= 2 {
                let size = min(76, min(space * 0.40, w * 0.19))
                circle(faces[0], cx + size * 0.46, max(top + size / 2, cy + size * 0.42), size)
                circle(faces[1], cx - size * 0.58, max(top + size / 2, cy - size * 0.58), size * 0.88)
            } else {
                let size = min(64, max(48, min(w * 0.16, space / 2.9)))
                let gap = size * 0.88
                let centreY = min(h - size / 2 - gap - 16, max(top + size / 2 + gap, cy))
                if space >= size + gap * 2 {
                    for (key, dx, dy) in [("A", 0.0, 1.0), ("B", 1.0, 0.0), ("X", -1.0, 0.0), ("Y", 0.0, -1.0)] where keys.contains(key) {
                        circle(key, cx + dx * gap, centreY + dy * gap, size)
                    }
                } else {
                    let d = min(56, (space - 8) / 2)
                    for (index, key) in faces.enumerated() {
                        circle(key, cx + (index % 2 == 0 ? -1 : 1) * (d + 8) / 2, top + space - d / 2 - Double(index / 2) * (d + 8), d)
                    }
                }
            }
        }
        if !keys.contains("joyL") {
            let size = min(56, min(max(48, (w * 0.5 - 32) / 3), available / 3))
            let cy = min(h - size * 1.5 - 12, max(top + size * 1.5, thumbY))
            for (key, dx, dy) in [("dpadU", 0.0, -1.0), ("dpadD", 0.0, 1.0), ("dpadL", -1.0, 0.0), ("dpadR", 1.0, 0.0)] where keys.contains(key) {
                box(key, "dpad", leftX + dx * size - size / 2, cy + dy * size - size / 2, size, size)
            }
        }
        for key in ["joyL", "joyR"] where keys.contains(key) {
            let left = key == "joyL"
            let y = max(top, min(h * 0.34, h - 180))
            result.append(ThumbControl(key, "stick", PadRect(left ? 4 : w * 0.51, y, w * 0.49 - 4, h - y - 12), left ? leftX : rightX, thumbY, stickDiameter))
        }
        return result
    }
}
