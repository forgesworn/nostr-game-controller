package dev.forgesworn.joystick
import org.json.JSONObject
import kotlin.math.*

data class InlineGraphic(val png: String) {
    fun valid(): Boolean = runCatching {
        require(png.length <= 12288 && png.length % 4 == 0 && png.matches(Regex("[A-Za-z0-9+/]+={0,2}")))
        val bytes = java.util.Base64.getDecoder().decode(png)
        require(bytes.size >= 24 && bytes.take(8).map { it.toInt() and 255 } == listOf(137,80,78,71,13,10,26,10))
        require(String(bytes,12,4,Charsets.US_ASCII) == "IHDR")
        val header = java.nio.ByteBuffer.wrap(bytes,16,8)
        header.int in 1..256 && header.int in 1..256
    }.getOrDefault(false)
}
data class ControlZone(val x: Double,val y: Double,val width: Double,val height: Double)
data class ControlPlacement(val x: Double,val y: Double,val size: Double,val shape: String = "circle",val zone: ControlZone? = null) {
    fun valid(stick: Boolean): Boolean = x.isFinite() && y.isFinite() && size.isFinite() && x in 0.0..1.0 && y in 0.0..1.0 && size in (if(stick) 96.0..192.0 else 48.0..192.0) && shape in listOf("circle","rounded") &&
        (zone == null || stick && listOf(zone.x,zone.y,zone.width,zone.height).all { it.isFinite() } && zone.x >= 0 && zone.y >= 0 && zone.width >= .1 && zone.height >= .1 && zone.x+zone.width <= 1.000001 && zone.y+zone.height <= 1.000001 && x >= zone.x && x <= zone.x+zone.width && y >= zone.y && y <= zone.y+zone.height)
}
data class ControllerLayout(val portrait: Map<String,ControlPlacement>?,val landscape: Map<String,ControlPlacement>?) {
    fun controls(w: Double,h: Double,keys: Set<String>): List<ThumbControl>? {
        if(w < 200 || h < 160) return null
        val map = (if(w > h) landscape else portrait) ?: return null
        if(map.keys != keys) return null
        val ordered = keys.filter { !it.startsWith("joy") }.sorted() + keys.filter { it.startsWith("joy") }.sorted()
        val controls = ordered.map { key ->
            val p = map.getValue(key); val size = min(p.size,min(w-8,h-8)); val x = (p.x*w).coerceIn(size/2+4,w-size/2-4); val y = (p.y*h).coerceIn(size/2+4,h-size/2-4)
            val rect = p.zone?.let { PadRect(it.x*w,it.y*h,it.width*w,it.height*h) } ?: PadRect(x-size/2,y-size/2,size,size)
            ThumbControl(key,if(key.startsWith("joy")) "stick" else if(p.shape == "rounded") "utility" else "face",rect,x,y,size)
        }
        fun overlaps(a: PadRect,b: PadRect) = min(a.x+a.width,b.x+b.width)-max(a.x,b.x) > .01 && min(a.y+a.height,b.y+b.height)-max(a.y,b.y) > .01
        for(a in controls.filter { it.key.startsWith("joy") }) if(a.anchorX < a.rect.x || a.anchorX > a.rect.x+a.rect.width || a.anchorY < a.rect.y || a.anchorY > a.rect.y+a.rect.height) return null
        for(i in controls.indices) for(j in i+1 until controls.size) {
            val a = controls[i]; val b = controls[j]
            if(a.key.startsWith("joy") == b.key.startsWith("joy") && overlaps(a.rect,b.rect)) return null
        }
        return controls
    }
    companion object {
        fun decode(value: JSONObject,keys: Set<String>): ControllerLayout {
            require(value.get("version") == 1 && (value.has("portrait") || value.has("landscape")))
            fun orientation(name: String): Map<String,ControlPlacement>? {
                if(!value.has(name)) return null
                val map = value.getJSONObject(name); require(map.keys().asSequence().toSet() == keys)
                return keys.associateWith { key ->
                    val p = map.getJSONObject(key); require(!p.has("shape") || p.get("shape") is String); for(field in listOf("x","y","size")) require(p.get(field) is Number)
                    val z = if(p.has("zone")) p.getJSONObject("zone").let { for(field in listOf("x","y","width","height")) require(it.get(field) is Number); ControlZone(it.getDouble("x"),it.getDouble("y"),it.getDouble("width"),it.getDouble("height")) } else null
                    ControlPlacement(p.getDouble("x"),p.getDouble("y"),p.getDouble("size"),p.optString("shape","circle"),z).also { require(it.valid(key.startsWith("joy"))) }
                }
            }
            return ControllerLayout(orientation("portrait"),orientation("landscape"))
        }
    }
}
data class ControllerTheme(val background: String? = null,val accent: String? = null) {
    companion object { fun colour(value: String) = value.matches(Regex("#[0-9A-Fa-f]{3}([0-9A-Fa-f]{3})?")) }
}
