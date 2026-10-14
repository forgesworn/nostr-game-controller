package dev.forgesworn.joystick

import java.net.URI
import java.net.URLEncoder
import java.net.URLDecoder
import java.util.Locale
import org.json.JSONObject
import kotlin.math.*

object PairingCode {
    fun display(code: String): String = if (code.matches(Regex("[a-zA-Z0-9]{6}"))) code.take(3) + " " + code.takeLast(3) else code
    fun normalize(input: String): String {
        val text = input.trim()
        return (if (text.matches(Regex("[a-zA-Z0-9]{3}[\\s-]+[a-zA-Z0-9]{3}"))) text.replace(Regex("[\\s-]"), "") else text).uppercase(Locale.ROOT)
    }
}

data class Pairing(val session: String, val broker: String) {
    val key get() = "v2|$broker|$session"
    val socketUrl get() = "$broker?s=${URLEncoder.encode(session, "UTF-8")}&r=phone&v=2&recover=1"
    companion object {
        fun parse(input: String, allowLoopback: Boolean = false): Pairing {
            val text = input.trim()
            var session = PairingCode.normalize(text)
            var endpoint = "wss://controller.pallasite.app/"
            val uri = if (text.contains("://")) URI(text) else null
            if (uri?.scheme != null) {
                require(uri.scheme.lowercase(Locale.ROOT) in listOf("https", "joystick") && uri.userInfo == null) { "Use a version 2 Joystick pairing link." }
                val items = (uri.rawQuery ?: "").split('&').map { it.split('=', limit = 2) }.map { listOf(URLDecoder.decode(it[0], "UTF-8"), it.getOrElse(1) { "" }) }
                fun values(key: String) = items.filter { it[0] == key }.map { URLDecoder.decode(it[1], "UTF-8") }
                require(values("s").size == 1 && values("v") == listOf("2") && values("w").size <= 1) { "Use a version 2 Joystick pairing link." }
                session = values("s").single(); endpoint = values("w").firstOrNull() ?: endpoint
            }
            require(session.matches(Regex("[A-Za-z0-9_-]{6,128}"))) { "Enter a six-letter code or game pairing link." }
            val server = URI(endpoint)
            require(server.host != null && server.userInfo == null && server.rawQuery == null && server.rawFragment == null && (server.port == -1 || server.port in 1..65535)) { "Invalid controller service." }
            require(server.scheme == "wss" || (allowLoopback && server.scheme == "ws" && server.host in listOf("localhost", "127.0.0.1", "10.0.2.2", "::1"))) { "The controller service must use a secure connection." }
            if (server.path.isNullOrEmpty()) endpoint += "/"
            return Pairing(session, endpoint)
        }
    }
}
data class Slot(val mode: String = "heading", val label: String = "", val icon: String = "", val tapAction: String? = null, val colour: String = "", val graphic: InlineGraphic? = null)
data class Spec(val name: String, val slots: Map<String, Slot>,val layout: ControllerLayout? = null,val theme: ControllerTheme? = null) {
    companion object {
        val keys = setOf("joyL", "joyR", "A", "B", "X", "Y", "L1", "L2", "R1", "R2", "start", "select", "dpadU", "dpadD", "dpadL", "dpadR")
        fun decode(json: JSONObject): Spec {
            require(json.toString().toByteArray(Charsets.UTF_8).size <= 49152 && json.get("version") == 1)
            val name = json.getString("name"); require(name.length <= 128)
            val slots = json.getJSONObject("slots"); require(slots.length() <= 16)
            val result = linkedMapOf<String, Slot>()
            for (key in slots.keys()) {
                require(key in keys); val value = slots.getJSONObject(key); for(field in listOf("mode","label","icon","colour","tapAction")) require(!value.has(field) || value.get(field) is String)
                val mode = value.optString("mode", "heading")
                require(mode in listOf("heading", "xy", "tilt"))
                val graphic = if(value.has("graphic")) InlineGraphic(value.getJSONObject("graphic").getString("png")).also { require(it.valid()) } else null
                require(value.optString("label").length <= 48 && value.optString("icon").length <= 64 && (!value.has("colour") || ControllerTheme.colour(value.getString("colour"))))
                val tap = if(value.has("tapAction")) value.getString("tapAction").also { require(it in keys) } else null
                result[key] = Slot(mode, value.optString("label"), value.optString("icon"),tap,value.optString("colour"),graphic)
            }
            require(result.values.sumOf { it.graphic?.png?.length ?: 0 } <= 32768)
            val layout = if(json.has("layout")) ControllerLayout.decode(json.getJSONObject("layout"),result.keys) else null
            val theme = if(json.has("theme")) json.getJSONObject("theme").let { v ->
                fun color(key: String) = if(v.has(key)) v.getString(key).also { require(ControllerTheme.colour(it)) } else null
                ControllerTheme(color("background"),color("accent"))
            } else null
            return Spec(name, result,layout,theme)
        }
    }
}
data class Input(val k: String, val v: String)
object Stick {
    fun move(slot: String, mode: String, dx: Double, dy: Double, radius: Double = 50.0, deadzone: Double = 18.0): List<Input> {
        if (!dx.isFinite() || !dy.isFinite() || radius <= 0) return end(slot, mode)
        val distance = hypot(dx, dy); val divisor = max(radius, distance)
        val axes = if (mode == "xy") listOf(Input("$slot-x", (dx / divisor * 1000).roundToInt().toString()), Input("$slot-y", (dy / divisor * 1000).roundToInt().toString())) else listOf(Input(slot, (atan2(dy, dx) * 1000).roundToInt().toString()))
        return axes + listOf(Input("$slot-thrust", if (distance >= deadzone) "1" else "0"), Input("$slot-power", if (distance >= deadzone) (min(1.0, distance / radius) * 1000).roundToInt().toString() else "0"))
    }
    fun end(slot: String, mode: String) = listOf(Input("$slot-thrust", "0"), Input("$slot-power", "0"), Input("$slot-end", "1")) + if (mode == "xy") listOf(Input("$slot-x", "0"), Input("$slot-y", "0")) else emptyList()
}
