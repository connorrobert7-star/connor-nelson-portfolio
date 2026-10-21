class_name CasinoFx
## Shared juice for the casino. Overlays live on the HUD layer (480x270), so these work in
## Control space. Owned by the reel builder; everyone else calls it.
##
## Rarity reads through light only: glow, outline, flash, beams and particles in the five
## rarity colors. Real money is drawn as cream motes. Nothing here touches money.

const LIGHT := "res://art/packs/kenney-particle-pack/PNG (Transparent)/light_01.png"
const STAR := "res://art/packs/kenney-particle-pack/PNG (Transparent)/star_06.png"
const JERSEY := "res://art/packs/google-pixel-fonts-ofl/jersey10/Jersey10-Regular.ttf"
const M5X7 := "res://art/packs/font-m5x7/m5x7.ttf"

## Pack sounds the casino shares (Sfx.play_path).
const SND_CASH := "res://art/packs/lrsf-coins-library/Coins_Pouring/Coins_Pouring_00.ogg"
const SND_BELL := "res://art/packs/kenney-impact-sounds/Audio/impactBell_heavy_000.ogg"
const SND_CHANT := "res://art/packs/owlishmedia-creepy-chanting/chant11.ogg"
const SND_MOTE := "res://art/packs/kenney-interface-sounds/Audio/glass_002.ogg"
const SND_RING := "res://art/packs/ninja-adventure/Audio/Sounds/Magic & Skill/Spirit.ogg"

## The lighter "glow" step of each rarity ramp (docs/ASSETS.md), for halos and cores.
const GLOW := {
	"common": Color("d5d8db"), "rare": Color("9cc4ff"), "epic": Color("d3a3ff"),
	"legendary": Color("ffe08a"), "mythic": Color("ff8a90"),
}
## The dark "shadow" step, for outlines and card floors.
const SHADOW := {
	"common": Color("5d6166"), "rare": Color("1f4f9e"), "epic": Color("5f259c"),
	"legendary": Color("a86a0c"), "mythic": Color("9e141d"),
}

static var _cache: Dictionary = {}
static var _stops := 0


# --- resources -------------------------------------------------------------------

## Any texture or sound by path, loaded once.
static func res(path: String) -> Resource:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


## Play a sound on its own player under `parent`, so a breath can cut it (hush). Use it for
## anything long enough to ring past a beat; it frees itself when done.
static func loud(parent: Node, path: String, pitch := 1.0, db := -6.0) -> AudioStreamPlayer:
	var stream := res(path) as AudioStream
	if stream == null or parent == null or not parent.is_inside_tree():
		return null
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = db
	p.add_to_group("casino_loud")
	parent.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return p


## Cut every casino sound still ringing: the silence before the bang.
static func hush(tree: SceneTree) -> void:
	for n: Node in tree.get_nodes_in_group("casino_loud"):
		(n as AudioStreamPlayer).stop()
		n.queue_free()


## One cell of a pack sheet, e.g. region("res://art/packs/.../sheet.png", Rect2(16, 0, 16, 16)).
static func region(sheet: String, rect: Rect2) -> AtlasTexture:
	var key := "%s@%s" % [sheet, rect]
	if not _cache.has(key):
		var a := AtlasTexture.new()
		a.atlas = res(sheet) as Texture2D
		a.region = rect
		_cache[key] = a
	return _cache[key]


## The icon of a catalog item ({icon: {sheet, rect}}), or null.
static func icon(item: Dictionary) -> AtlasTexture:
	var i: Dictionary = item.get("icon", {})
	if i.is_empty():
		return null
	var r: Array = i.get("rect", [0, 0, 16, 16])
	return region(str(i.sheet), Rect2(r[0], r[1], r[2], r[3]))


static func font(path := JERSEY) -> Font:
	return res(path) as Font


static func additive() -> CanvasItemMaterial:
	if not _cache.has("_add"):
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_cache["_add"] = m
	return _cache["_add"]


static func rarity_color(tier: String) -> Color:
	return Palette.RARITY.get(tier, Palette.CREAM)


static func glow_color(tier: String) -> Color:
	return GLOW.get(tier, Palette.CREAM)


static func shadow_color(tier: String) -> Color:
	return SHADOW.get(tier, Palette.INK)


## A gradient from explicit stops: grad([0.0, 1.0], [from, to]).
static func grad(offsets: Array, colors: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	return g


## A 1x3 white pixel streak for sparks aligned to their flight.
static func _streak() -> Texture2D:
	if not _cache.has("_streak"):
		var img := Image.create(1, 3, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_cache["_streak"] = ImageTexture.create_from_image(img)
	return _cache["_streak"]


## Draws a sprite as a flat silhouette in `color` (for rarity outlines and missing items).
static func silhouette(color: Color) -> ShaderMaterial:
	var key := "_sil%s" % color.to_html()
	if not _cache.has(key):
		if not _cache.has("_sil_shader"):
			var sh := Shader.new()
			sh.code = "shader_type canvas_item;\nuniform vec4 tint : source_color;\nvoid fragment() {\n\tCOLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * tint.a);\n}\n"
			_cache["_sil_shader"] = sh
		var m := ShaderMaterial.new()
		m.shader = _cache["_sil_shader"]
		m.set_shader_parameter("tint", color)
		_cache[key] = m
	return _cache[key]


## A label in the casino's painted lettering (Jersey 10), outlined in night.
static func label(text: String, color: Color, size := 10, path := JERSEY) -> Label:
	var l := Label.new()
	l.text = text
	var f := font(path)
	if f:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Palette.NIGHT)
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# --- particles -------------------------------------------------------------------

## A one-shot spray of square pixels.
static func burst(parent: Node, pos: Vector2, color: Color, amount := 24, speed := 120.0, life := 0.6) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.95
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.4
	p.damping_max = speed * 0.9
	p.gravity = Vector2(0, 220)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color.lightened(0.45), 1.0))
	ramp.set_color(1, Color(color, 0.0))
	p.color_ramp = ramp
	p.position = pos
	p.z_index = 8
	parent.add_child(p)
	p.emitting = true
	p.get_tree().create_timer(life + 0.2).timeout.connect(p.queue_free)


## Sparks that shoot out in streaks along their flight and hang a moment, in a rarity
## color, with a slower cloud of glow-colored pixels behind them.
static func sparks(parent: Node, pos: Vector2, tier: String, amount := 16) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.75
	p.explosiveness = 1.0
	p.texture = _streak()
	p.particle_flag_align_y = true
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 200.0 + amount
	# Damping stays under gravity: a streak aligned to a velocity of zero blows up in size.
	p.damping_min = 40.0
	p.damping_max = 80.0
	p.gravity = Vector2(0, 140)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color_ramp = grad([0.0, 0.25, 1.0], [Color.WHITE, glow_color(tier), Color(rarity_color(tier), 0.0)])
	p.position = pos
	p.z_index = 8
	parent.add_child(p)
	p.emitting = true
	p.get_tree().create_timer(1.0).timeout.connect(p.queue_free)
	burst(parent, pos, rarity_color(tier), maxi(6, amount / 2), 110.0, 0.9)


## Soft round puffs of dust or smoke that drift and fade.
static func smoke(parent: Node, pos: Vector2, count := 8, color := Palette.MUTED) -> void:
	for i in count:
		var g := glow(parent, pos + Vector2(randf_range(-8, 8), randf_range(-4, 4)), Color(color, 0.35), randf_range(6, 11), false)
		var drift := Vector2(randf_range(-26, 26), randf_range(-22, -4))
		var tw := g.create_tween()
		tw.set_parallel(true)
		tw.tween_property(g, "position", g.position + drift, 0.7).set_ease(Tween.EASE_OUT)
		tw.tween_property(g, "scale", Vector2(1.8, 1.8), 0.7)
		tw.tween_property(g, "modulate:a", 0.0, 0.7)
		tw.chain().tween_callback(g.queue_free)


## Gold flakes drifting down (legendary) or red embers rising (mythic), across `area`.
static func flakes(parent: Node, area: Rect2, tier: String, seconds := 2.6) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	var rising := tier == "mythic"
	p.amount = 120 if rising else 70
	p.lifetime = 2.4
	p.preprocess = 0.6
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(area.size.x / 2.0, 4)
	p.position = Vector2(area.get_center().x, area.end.y if rising else area.position.y)
	p.direction = Vector2.UP if rising else Vector2.DOWN
	p.spread = 25.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 70.0 if rising else 45.0
	p.gravity = Vector2(0, -30) if rising else Vector2(0, 26)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.5
	if rising:
		p.color_ramp = grad([0.0, 0.3, 1.0], [Color("ffd9a0"), rarity_color(tier), Color(rarity_color(tier), 0.0)])
	else:
		p.color_ramp = grad([0.0, 0.5, 1.0], [glow_color(tier), rarity_color(tier), Color(shadow_color(tier), 0.0)])
	p.z_index = 6
	parent.add_child(p)
	p.emitting = true
	p.get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.emitting = false
			p.get_tree().create_timer(p.lifetime).timeout.connect(p.queue_free)
	)
	return p


## A soft additive glow (rarity glow under items, cream under money). `radius` in px.
static func glow(parent: Node, pos: Vector2, color: Color, radius := 16.0, add := true) -> TextureRect:
	var t := TextureRect.new()
	t.texture = res(LIGHT) as Texture2D
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.size = Vector2(radius, radius) * 2.0
	t.position = pos - Vector2(radius, radius)
	t.pivot_offset = Vector2(radius, radius)
	t.modulate = color
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if add:
		t.material = additive()
	parent.add_child(t)
	return t


## A rarity glow that breathes under something until freed. Returns it.
static func rarity_glow(parent: Node, pos: Vector2, tier: String, radius := 24.0) -> TextureRect:
	var g := glow(parent, pos, Color(rarity_color(tier), 0.8), radius)
	var tw := g.create_tween().set_loops()
	tw.tween_property(g, "modulate:a", 0.45, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(g, "modulate:a", 0.85, 0.6).set_trans(Tween.TRANS_SINE)
	return g


## A ring that expands and fades.
static func ring(parent: Node, pos: Vector2, color: Color, radius := 40.0, seconds := 0.45) -> void:
	var r := Ring.new()
	r.color = color
	r.position = pos
	r.z_index = 7
	parent.add_child(r)
	var tw := r.create_tween()
	tw.set_parallel(true)
	tw.tween_property(r, "radius", radius, seconds).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(r, "width", 0.5, seconds)
	tw.tween_property(r, "modulate:a", 0.0, seconds).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(r.queue_free)


## A vertical light beam at x, from the top down to `bottom`, fading out at its foot.
## Returns it; it fades itself out after `seconds` (0 keeps it until freed).
static func beam(parent: Node, x: float, bottom: float, tier: String, width := 16.0, seconds := 0.6) -> Control:
	var b := Beam.new()
	b.color = rarity_color(tier)
	b.core = glow_color(tier)
	b.position = Vector2(x, 0)
	b.height = bottom
	b.z_index = 5
	parent.add_child(b)
	var tw := b.create_tween()
	tw.tween_property(b, "width", width, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if seconds > 0.0:
		tw.tween_interval(seconds)
		tw.tween_property(b, "width", 0.0, 0.3)
		tw.tween_callback(b.queue_free)
	return b


# --- screen ----------------------------------------------------------------------

## A full-screen color flash on the overlay layer.
static func flash(parent: Control, color: Color, alpha := 0.55, seconds := 0.3) -> void:
	var r := ColorRect.new()
	r.color = Color(color, alpha)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.z_index = 200
	parent.add_child(r)
	var tw := r.create_tween()
	tw.tween_property(r, "color:a", 0.0, seconds).set_ease(Tween.EASE_IN)
	tw.tween_callback(r.queue_free)


## Freeze the game for a beat (big moments only). Real time, not game time. Overlapping
## stops hold until the last one ends.
static func hit_stop(tree: SceneTree, seconds := 0.08) -> void:
	_stops += 1
	Engine.time_scale = 0.02
	await tree.create_timer(seconds, true, false, true).timeout
	_stops -= 1
	if _stops <= 0:
		_stops = 0
		Engine.time_scale = 1.0


## Shake a Control or Node2D around where it sits, decaying to rest.
static func shake(node: CanvasItem, strength := 3.0, seconds := 0.25) -> void:
	if not node.has_meta("shake_home"):
		node.set_meta("shake_home", node.get("position"))
	var home: Vector2 = node.get_meta("shake_home")
	if node.has_meta("shake_tween"):
		var old: Tween = node.get_meta("shake_tween")
		if old and old.is_valid():
			old.kill()
	var tw := node.create_tween()
	node.set_meta("shake_tween", tw)
	var steps := maxi(2, int(seconds / 0.03))
	for i in steps:
		var f := strength * (1.0 - float(i) / steps)
		tw.tween_property(node, "position", home + Vector2(randf_range(-f, f), randf_range(-f, f)).round(), 0.03)
	tw.tween_property(node, "position", home, 0.03)


## Slowly scale a Control up around its center, for reveals.
static func zoom(c: Control, to := 1.12, seconds := 0.8) -> Tween:
	c.pivot_offset = c.size / 2.0
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(to, to), seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tw


# --- money -----------------------------------------------------------------------

## Bone-white motes fountain up from `from`, then home into `to` one after another; the jar
## flashes, the bell and the choir sound once, and "+$20 House Fund" floats up. Real money
## only. Await it: returns when the last mote has landed.
static func money_landed(parent: Control, from: Vector2, to: Vector2, amount_cents: int, label: String) -> void:
	loud(parent, SND_CASH, 1.0, -8.0)
	var count := clampi(amount_cents / 100, 8, 40)
	var tree := parent.get_tree()
	var gap := 0.5 / count
	for i in count:
		var m := Mote.new()
		m.position = from
		m.z_index = 9
		parent.add_child(m)
		var spray := from + Vector2(randf_range(-44, 44), randf_range(-62, -20))
		var bend := spray.lerp(to, 0.4) + Vector2(randf_range(-24, 24), -30)
		var tw := m.create_tween()
		tw.tween_property(m, "position", spray, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(i * gap)
		tw.tween_method(func(t: float) -> void:
			m.position = spray.lerp(bend, t).lerp(bend.lerp(to, t), t), 0.0, 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var pitch := 1.0 + i * 0.6 / count
		tw.tween_callback(func() -> void:
			if i % 2 == 0:
				Sfx.play_path(SND_MOTE, pitch, -14.0)
			m.queue_free()
		)
	await tree.create_timer(0.24 + 0.5 + 0.3).timeout
	var g := glow(parent, to, Color(Palette.CREAM, 1.0), 26.0)
	g.z_index = 9
	var gt := g.create_tween()
	gt.tween_property(g, "modulate:a", 0.0, 0.6)
	gt.tween_callback(g.queue_free)
	burst(parent, to, Palette.CREAM, 10, 70.0, 0.5)
	loud(parent, SND_BELL, 1.0, -10.0)
	loud(parent, SND_CHANT, 1.0, -2.0)
	float_text(parent, to + Vector2(30, -20), "+%s %s" % [dollars(amount_cents), label], Palette.CREAM, 16)


## A number or word that pops up and drifts away.
static func float_text(parent: Control, pos: Vector2, text: String, color: Color, size := 8) -> void:
	var l := label(text, color, size)
	l.z_index = 10
	parent.add_child(l)
	l.reset_size()
	l.position = pos - Vector2(l.size.x / 2.0, l.size.y / 2.0)
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2(0.5, 0.5)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "position:y", l.position.y - 18, 1.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


## "$20" for whole dollars, "$20.50" otherwise. Formatting only.
static func dollars(cents: int) -> String:
	var s := Money.fmt(cents)
	return s.trim_suffix(".00")


# --- drawn pieces ------------------------------------------------------------------

class Ring:
	extends Node2D
	var color := Color.WHITE
	var radius := 2.0:
		set(v):
			radius = v
			queue_redraw()
	var width := 3.0:
		set(v):
			width = v
			queue_redraw()

	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, color, width)


class Beam:
	extends Control
	var color := Color.WHITE
	var core := Color.WHITE
	var height := 200.0
	var width := 0.0:
		set(v):
			width = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		material = CasinoFx.additive()

	func _draw() -> void:
		if width <= 0.1:
			return
		var w := width
		var fade := _fade()
		var steps := 6
		for i in steps:
			var f := float(i) / steps
			var ww := w * (1.0 - f)
			draw_texture_rect(fade, Rect2(-ww / 2.0, 0, ww, height), false, Color(color, 0.08 + 0.1 * f))
		var cw := maxf(2.0, w * 0.24)
		draw_texture_rect(fade, Rect2(-cw / 2.0, 0, cw, height), false, Color(core, 0.75))

	static func _fade() -> Texture2D:
		if not CasinoFx._cache.has("_beam_fade"):
			var t := GradientTexture2D.new()
			t.gradient = CasinoFx.grad([0.0, 0.65, 1.0], [Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
			t.fill_from = Vector2(0, 0)
			t.fill_to = Vector2(0, 1)
			t.width = 2
			t.height = 64
			CasinoFx._cache["_beam_fade"] = t
		return CasinoFx._cache["_beam_fade"]


class Mote:
	extends Control
	## One bone-white mote of real money, with a little light around it.
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(3, 3)

	func _draw() -> void:
		draw_texture_rect(CasinoFx.res(CasinoFx.LIGHT) as Texture2D, Rect2(-5, -5, 13, 13), false, Color(Palette.CREAM, 0.55))
		draw_rect(Rect2(0, 0, 3, 3), Palette.CREAM)
