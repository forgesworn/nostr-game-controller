package dev.forgesworn.joystick

import kotlin.math.*

data class PadRect(val x: Double, val y: Double, val width: Double, val height: Double) {
    val midX get() = x + width / 2
    val midY get() = y + height / 2
}
data class ThumbControl(val key: String, val shape: String, val rect: PadRect,
    val anchorX: Double = rect.midX, val anchorY: Double = rect.midY,
    val diameter: Double = min(rect.width, rect.height))

/** Points/dp geometry shared with the Swift core. Floating sticks sit below
 * compact utility controls; action targets stay beside the player's hands. */
object ThumbLayout {
    fun controls(w: Double, h: Double, keys: Set<String>): List<ThumbControl> {
        if (w < 200 || h < 160) return emptyList()
        val result = mutableListOf<ThumbControl>()
        fun box(key: String, shape: String, x: Double, y: Double, width: Double, height: Double) {
            result.add(ThumbControl(key, shape, PadRect(x, y, width, height)))
        }
        fun circle(key: String, x: Double, y: Double, size: Double) { box(key, "face", x - size / 2, y - size / 2, size, size) }
        val extraDirections = if ("joyL" in keys) listOf("dpadU", "dpadL", "dpadR", "dpadD") else emptyList()
        val faceKeys = listOf("A", "B", "X", "Y").filter { it in keys }
        val shoulders = listOf("R1", "R2").filter { it in keys }
        val actionShoulders = if ("joyR" !in keys && ("joyL" in keys || keys.any { it.startsWith("dpad") }) && faceKeys.isNotEmpty() && faceKeys.size + shoulders.size <= 4) shoulders else emptyList()
        val utility = (listOf("L2", "L1") + extraDirections + listOf("select", "start", "R1", "R2")).filter { it in keys && it !in actionShoulders }
        val columns = max(1, min(utility.size, ((w - 8) / 52).toInt()))
        val rows = if (utility.isEmpty()) 0 else (utility.size + columns - 1) / columns
        val cell = min(80.0, (w - 8) / columns)
        val utilityWidth = cell * columns
        utility.forEachIndexed { index, key -> box(key, if (key.startsWith("dpad")) "dpad" else "utility", (w - utilityWidth) / 2 + index % columns * cell + 2, index / columns * 52.0 + 4, cell - 4, 48.0) }
        val top = rows * 52.0 + if (rows == 0) 8 else 12
        val available = h - top - 16
        val hasLeft = "joyL" in keys || keys.any { it.startsWith("dpad") }
        val faces = listOf("A", "B", "X", "Y").filter { it in keys }
        val leftX = max(96.0, min(116.0, w * .24)); val rightX = w - max(96.0, min(116.0, w * .24))
        val stickDiameter = min(152.0, min(w * .40, available * .78))
        val thumbY = min(h - stickDiameter / 2 - 16, h - min(112.0, available * .40))
        if (!hasLeft && "joyR" !in keys && faces.isNotEmpty()) {
            val cols = if (faces.size == 1) 1 else 2
            val count = (faces.size + cols - 1) / cols
            val bw = min(180.0, (w - 40) / cols)
            val bh = min(100.0, (available - (count - 1) * 12) / count)
            val y = h - 16 - count * bh - (count - 1) * 12
            faces.forEachIndexed { index, key ->
                val x = if (cols == 1) (w - bw) / 2 else if (index % 2 == 0) 16.0 else w - bw - 16
                box(key, "answer", x, y + index / cols * (bh + 12), bw, bh)
            }
        } else if (faces.isNotEmpty() && "joyR" !in keys) {
            // Keep a broad primary action and compact secondary cluster beside the hand.
            val actions = faces + actionShoulders; val secondary = actions.drop(1)
            val cols = if (w >= 560 && available < 200) 3 else 2
            val count = (secondary.size + cols - 1) / cols; val gap = 10.0; val bw = min(if (cols == 3) 184.0 else 160.0, w * .5 - 32)
            val size = max(48.0, min(64.0, min((bw - (cols - 1) * gap) / cols, if (count > 0) (available - 48 - count * gap) / count else 64.0)))
            val bh = min(80.0, available - count * (size + gap)); val x = w - 16 - bw; val y = h - 16 - bh
            box(actions[0], "answer", x, y, bw, bh)
            secondary.forEachIndexed { index, key -> box(key, "answer", w - 16 - size - index % cols * (size + gap), y - (index / cols + 1) * (size + gap), size, size) }
        } else if (faces.isNotEmpty()) {
            val dual = "joyR" in keys; val inboard = dual && w >= 560
            val directionInset = if ("joyL" !in keys && hasLeft) min(16.0, w * .04) else 0.0
            val cx = if (inboard) rightX - 184 else rightX + directionInset
            val cy = if (dual && !inboard) thumbY - stickDiameter / 2 - 100 else thumbY
            val space = if (dual && !inboard) max(96.0, available - stickDiameter - 20) else available
            if (faces.size == 1) circle(faces[0], cx, max(top + 44, cy), min(92.0, space * .7))
            else if (faces.size <= 2) {
                val size = min(76.0, min(space * .40, w * .19))
                circle(faces[0], cx + size * .46, max(top + size / 2, cy + size * .42), size)
                circle(faces[1], cx - size * .58, max(top + size / 2, cy - size * .58), size * .88)
            } else {
                val size = min(64.0, max(48.0, min(w * .16, space / 2.9)))
                val gap = size * .88
                val centreY = min(h - size / 2 - gap - 16, max(top + size / 2 + gap, cy))
                if (space >= size + gap * 2) {
                    for ((key, dx, dy) in listOf(Triple("A", 0.0, 1.0), Triple("B", 1.0, 0.0), Triple("X", -1.0, 0.0), Triple("Y", 0.0, -1.0)))
                        if (key in keys) circle(key, cx + dx * gap, centreY + dy * gap, size)
                } else {
                    val d = min(56.0, (space - 8) / 2)
                    faces.forEachIndexed { index, key -> circle(key, cx + (if (index % 2 == 0) -1 else 1) * (d + 8) / 2, top + space - d / 2 - index / 2 * (d + 8), d) }
                }
            }
        }
        if ("joyL" !in keys) {
            val size = min(56.0, min(max(48.0, (w * .5 - 32) / 3), available / 3))
            val cy = min(h - size * 1.5 - 12, max(top + size * 1.5, thumbY))
            for ((key, dx, dy) in listOf(Triple("dpadU", 0.0, -1.0), Triple("dpadD", 0.0, 1.0), Triple("dpadL", -1.0, 0.0), Triple("dpadR", 1.0, 0.0)))
                if (key in keys) box(key, "dpad", leftX + dx * size - size / 2, cy + dy * size - size / 2, size, size)
        }
        for (key in listOf("joyL", "joyR")) if (key in keys) {
            val left = key == "joyL"; val y = max(top, min(h * .34, h - 180))
            result.add(ThumbControl(key, "stick", PadRect(if (left) 4.0 else w * .51, y, w * .49 - 4, h - y - 12), if (left) leftX else rightX, thumbY, stickDiameter))
        }
        return result
    }
}
