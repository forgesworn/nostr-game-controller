package dev.forgesworn.joystick
import kotlin.math.*

data class TiltVector(val x: Double, val y: Double)

/** Downward gravity, in g: x right, y up, z out of the screen. */
class TiltSteering {
    companion object {
        const val DEADZONE = 50.0 * 4 / 35
        fun inputs(slot: String, mode: String, vector: TiltVector): List<Input> =
            if (hypot(vector.x, vector.y) < DEADZONE) Stick.end(slot, mode)
            else Stick.move(slot, mode, vector.x, vector.y, deadzone = DEADZONE)
    }
    var acceptedSample = false; private set
    private var baseline: TiltVector? = null
    private var smoothed: DoubleArray? = null
    private var lastTime: Double? = null
    private var lastRotation: Int? = null
    fun reset() { baseline = null; smoothed = null; lastTime = null; lastRotation = null; acceptedSample = false }
    fun sample(x: Double, y: Double, z: Double, rotation: Int, time: Double, filterRaw: Boolean = false): TiltVector? {
        acceptedSample = false
        if (!x.isFinite() || !y.isFinite() || !z.isFinite() || !time.isFinite() || rotation !in 0..3) return null
        val magnitude = sqrt(x * x + y * y + z * z)
        if (magnitude < .2 || magnitude > 2) return null
        if (lastRotation != rotation) { reset(); lastRotation = rotation }
        var values = doubleArrayOf(x, y, z)
        val previous = smoothed; val previousTime = lastTime
        if (filterRaw && previous != null && previousTime != null) {
            val alpha = 1 - exp(-(time - previousTime).coerceIn(0.0, .5) / .06)
            values = DoubleArray(3) { previous[it] + alpha * (values[it] - previous[it]) }
        }
        smoothed = values; lastTime = time; acceptedSample = true
        val gx: Double; val gy: Double
        when (rotation) {
            1 -> { gx = -values[1]; gy = values[0] }
            2 -> { gx = -values[0]; gy = -values[1] }
            3 -> { gx = values[1]; gy = -values[0] }
            else -> { gx = values[0]; gy = values[1] }
        }
        val pose = TiltVector(atan2(gx, hypot(gy, values[2])), atan2(-gy, hypot(gx, values[2])))
        val neutral = baseline ?: run { baseline = pose; return null }
        val gain = 50 / (35 * PI / 180)
        return TiltVector((pose.x - neutral.x) * gain, (pose.y - neutral.y) * gain)
    }
}
