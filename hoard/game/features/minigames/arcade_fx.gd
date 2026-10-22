class_name ArcadeFx
## Juice and pack art for the arcade: atlas slices, animated strips, glow, particles,
## floating numbers, the pop curve, hit-stop and shake. Everything here is static.
## (CasinoFx does the same job for the casino; this keeps the arcade standalone.)

const PACKS := "res://art/packs/"
const LIGHT := PACKS + "kenney-particle-pack/PNG (Transparent)/circle_05.png"
const STAR := PACKS + "kenney-particle-pack/PNG (Transparent)/star_06.png"
const COIN_STRIP := PACKS + "evercrazy-coin-gem-8x8/SpinningCoin.png"
const FONT_SMALL := PACKS + "font-m5x7/m5x7.ttf"
const FONT_BIG := PACKS + "google-pixel-fonts-ofl/jersey10/Jersey10-Regular.ttf"

const SND_COIN := PACKS + "juhani-512-retro-sfx/General Sounds/Coins/sfx_coin_single1.ogg"
const SND_COIN_DOUBLE := PACKS + "juhani-512-retro-sfx/General Sounds/Coins/sfx_coin_double1.ogg"
const SND_COINS := PACKS + "juhani-512-retro-sfx/General Sounds/Coins/sfx_coin_cluster3.ogg"
const SND_TICK := PACKS + "kenney-interface-sounds/Audio/tick_001.ogg"
const SND_NOTE := PACKS + "kenney-interface-sounds/Audio/pluck_001.ogg"
const SND_WHISTLE := PACKS + "juhani-512-retro-sfx/General Sounds/Weird Sounds/sfx_sound_refereewhistle.ogg"
const SND_GO := PACKS + "kenney-interface-sounds/Audio/confirmation_002.ogg"
const SND_CLICK := PACKS + "kenney-interface-sounds/Audio/click_001.ogg"
const SND_JACKPOT := PACKS + "ignisforge-sfx-sampler/jackpot_01.ogg"
const SND_CHANT := PACKS + "owlishmedia-creepy-chanting/chant3.ogg"
const SND_BOOM := PACKS + "shattered-pixel-dungeon/sounds/blast.mp3"
const SND_RISE := PACKS + "wobbleboxx-levelup-coin/Rise01.ogg"
const STINGERS := {
	"common": PACKS + "kenney-music-jingles/Audio/Pizzicato jingles/jingles_PIZZI00.ogg",
	"rare": PACKS + "kenney-music-jingles/Audio/Steel jingles/jingles_STEEL00.ogg",
	"epic": PACKS + "kenney-music-jingles/Audio/Sax jingles/jingles_SAX00.ogg",
	"legendary": PACKS + "kenney-music-jingles/Audio/Hit jingles/jingles_HIT00.ogg",
	"mythic": PACKS + "kenney-music-jingles/Audio/Hit jingles/jingles_HIT00.ogg",
}

const PLATE := PACKS + "tiopalada-dark-dwellers-gui/20251029darkDwellers9SlicesA.png"

## Brass is the color of play coins (never cream, which is real money).
const BRASS := Color("e9b949")

static var _atlas_cache: Dictionary = {}
static var _font_cache: Dictionary = {}
static var _stop_depth := 0


# --- art ------------------------------------------------------------------------------

## A slice of a pack sheet. `rect` is [x, y, w, h] as in content JSON.
static func tex(sheet: String, rect: Variant) -> Texture2D:
	var r: Array = rect
	var key := "%s|%s" % [sheet, str(r)]
	if _atlas_cache.has(key):
		return _atlas_cache[key]
	var base: Texture2D = load(sheet)
	if r.size() < 4 or (int(r[2]) == 0 and int(r[3]) == 0):
		_atlas_cache[key] = base
		return base
	var a := AtlasTexture.new()
	a.atlas = base
	a.region = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	_atlas_cache[key] = a
	return a


## A content icon dict {sheet, rect} as a texture.
static func icon(spec: Dictionary) -> Texture2D:
	return tex(str(spec.sheet), spec.rect)


## Frames of a horizontal strip: `count` frames of `w`x`h` starting at (x, y), `step` apart.
static func strip(sheet: String, x: int, y: int, w: int, h: int, count: int, step := -1) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var s := w if step < 0 else step
	for i in count:
		out.append(tex(sheet, [x + i * s, y, w, h]))
	return out


## An animated sprite from a sprite spec {sheet, rect, frames, step}.
static func anim_sprite(spec: Dictionary, fps := 8.0, sheet_override := "") -> AnimatedSprite2D:
	var sheet := sheet_override if sheet_override != "" else str(spec.get("sheet", ""))
	var r: Array = spec.rect
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", fps)
	for t in strip(sheet, int(r[0]), int(r[1]), int(r[2]), int(r[3]), int(spec.get("frames", 1)), int(spec.get("step", r[2]))):
		frames.add_frame("default", t)
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames
	s.play("default")
	s.frame = randi() % maxi(1, int(spec.get("frames", 1)))
	return s


## A one-shot effect from a strip; frees itself at the end.
static func one_shot(parent: Node, pos: Vector2, sheet: String, w: int, h: int, count: int, fps := 18.0, tint := Color.WHITE, scale := 1.0, add := false) -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	frames.set_animation_loop("default", false)
	frames.set_animation_speed("default", fps)
	for t in strip(sheet, 0, 0, w, h, count):
		frames.add_frame("default", t)
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames
	s.position = pos
	s.modulate = tint
	s.scale = Vector2(scale, scale)
	s.z_index = 40
	if add:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		s.material = m
	parent.add_child(s)
	s.play("default")
	s.animation_finished.connect(s.queue_free)
	return s


static func font(big := false) -> Font:
	var path := FONT_BIG if big else FONT_SMALL
	if not _font_cache.has(path):
		var f: FontFile = load(path)
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f.hinting = TextServer.HINTING_NONE
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_font_cache[path] = f
	return _font_cache[path]


## A pixel-font label with a dark outline. Numbers on things, never sentences.
static func label(text: String, size := 16, color := Palette.CREAM, big := false, outline := 4) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(big))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Palette.NIGHT)
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A soft additive light. Rarity colors only for rarity; everything else uses its own hue.
static func glow(parent: Node, pos: Vector2, color: Color, radius := 32.0, energy := 0.6) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(LIGHT)
	s.position = pos
	s.modulate = Color(color, energy)
	s.scale = Vector2.ONE * (radius / 24.0)  # the soft blob fills about 48 of 128 px
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	parent.add_child(s)
	return s


## Make a glow breathe forever (pools of light are never still).
## A dark Dark Dwellers plate behind a tally (the HUD's own frame), so no number floats bare.
static func plate(parent: Node, rect: Rect2, tint := Color(0.5, 0.46, 0.6, 0.95)) -> NinePatchRect:
	var p := NinePatchRect.new()
	p.texture = load(PLATE)
	p.patch_margin_left = 6
	p.patch_margin_right = 6
	p.patch_margin_top = 6
	p.patch_margin_bottom = 6
	p.position = rect.position.round()
	p.size = rect.size.round()
	p.modulate = tint
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


static func breathe(node: CanvasItem, low := 0.55, high := 1.0, seconds := 1.4) -> void:
	var base := node.modulate
	var tw := node.create_tween().set_loops()
	tw.tween_property(node, "modulate:a", base.a * low, seconds * 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "modulate:a", base.a * high, seconds * 0.5).set_trans(Tween.TRANS_SINE)


## Idle bob: 1 px on a sine with a random phase.
static func bob(node: Node2D, px := 1.0, seconds := 1.2) -> void:
	var y := node.position.y
	var tw := node.create_tween().set_loops()
	tw.tween_interval(randf() * seconds * 0.5)
	tw.tween_property(node, "position:y", y - px, seconds * 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "position:y", y, seconds * 0.5).set_trans(Tween.TRANS_SINE)


# --- motion ---------------------------------------------------------------------------

## A one-shot spray of square pixels.
static func burst(parent: Node, pos: Vector2, color: Color, amount := 16, speed := 90.0, life := 0.55, gravity := 260.0) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.95
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = color
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color, 0.0))
	p.color_ramp = ramp
	p.position = pos
	p.z_index = 45
	parent.add_child(p)
	p.emitting = true
	p.get_tree().create_timer(life + 0.3, true, false, true).timeout.connect(p.queue_free)


## A number or word that pops up and drifts away (Balatro's float: pop 1.6 -> 1, rise, fade).
static func float_text(parent: Node, pos: Vector2, text: String, color: Color, size := 16, big := false, rise := 14.0) -> Label:
	var l := label(text, size, color, big)
	l.z_index = 60
	parent.add_child(l)
	l.reset_size()
	l.pivot_offset = l.size / 2.0
	l.position = pos - l.size / 2.0
	l.scale = Vector2(1.6, 1.6)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "position:y", l.position.y - rise, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.25)
	tw.tween_callback(l.queue_free)
	return l


## Balatro's pop: scale = 1 + A sin(2 pi 8 t)(1 - t/0.4)^3, a small wobble in rotation.
static func pop(node: CanvasItem, amp := 0.2, rot := 0.12) -> void:
	if not is_instance_valid(node):
		return
	var dir := 1.0 if randf() < 0.5 else -1.0
	# Remember the resting scale once, so pops on top of pops never shrink or grow it.
	if not node.has_meta("pop_base"):
		node.set_meta("pop_base", node.get("scale"))
	var base_scale: Vector2 = node.get_meta("pop_base")
	if node.has_meta("pop_tween"):
		var old: Tween = node.get_meta("pop_tween")
		if old and old.is_valid():
			old.kill()
	var tw := node.create_tween()
	node.set_meta("pop_tween", tw)
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(node):
			return
		var k := pow(1.0 - t / 0.4, 3.0)
		var s := 1.0 + amp * sin(TAU * 8.0 * t) * k
		node.set("scale", base_scale * s)
		node.set("rotation", rot * dir * sin(TAU * 6.5 * t) * pow(1.0 - t / 0.4, 2.0)), 0.0, 0.4, 0.4)
	tw.tween_callback(func() -> void:
		if is_instance_valid(node):
			node.set("scale", base_scale)
			node.set("rotation", 0.0))


## Squash and stretch on a tap: (0.9, 1.1) then (1.1, 0.9) then settle.
static func squash(node: Node2D, base := Vector2.ONE) -> void:
	var tw := node.create_tween()
	tw.tween_property(node, "scale", base * Vector2(0.86, 1.14), 0.05)
	tw.tween_property(node, "scale", base * Vector2(1.14, 0.86), 0.08)
	tw.tween_property(node, "scale", base, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Freeze for a beat. Real time, not game time. Nested stops end with the last one.
static func hit_stop(tree: SceneTree, seconds := 0.06) -> void:
	_stop_depth += 1
	Engine.time_scale = 0.03
	await tree.create_timer(seconds, true, false, true).timeout
	_stop_depth -= 1
	if _stop_depth <= 0:
		_stop_depth = 0
		Engine.time_scale = 1.0


## Shake a node's position around where it rests. Capped at 6 px.
static func shake(node: Node2D, strength := 3.0, seconds := 0.25) -> void:
	if not is_instance_valid(node):
		return
	var home: Vector2 = node.get_meta("home", node.position)
	node.set_meta("home", home)
	var s := minf(strength, 6.0)
	var tw := node.create_tween()
	var steps := maxi(1, int(seconds / 0.03))
	for i in steps:
		var f := s * (1.0 - float(i) / steps)
		tw.tween_property(node, "position", home + Vector2(randf_range(-f, f), randf_range(-f, f)), 0.03)
	tw.tween_property(node, "position", home, 0.03)


## A full-screen color flash over an overlay.
static func flash(parent: Control, color: Color, alpha := 0.5, seconds := 0.25) -> void:
	var r := ColorRect.new()
	r.color = Color(color, alpha)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(r)
	var tw := r.create_tween()
	tw.tween_property(r, "color:a", 0.0, seconds)
	tw.tween_callback(r.queue_free)


## A brass play coin that arcs from `from` to `to`, then calls `landed`.
static func fly_coin(parent: Node, from: Vector2, to: Vector2, delay := 0.0, landed := Callable()) -> void:
	var c := Sprite2D.new()
	c.texture = tex(COIN_STRIP, [0, 0, 8, 8])
	c.position = from
	c.z_index = 70
	c.visible = delay <= 0.0
	parent.add_child(c)
	var mid := (from + to) / 2.0 + Vector2(randf_range(-30, 30), randf_range(-60, -20))
	var tw := c.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
		tw.tween_callback(func() -> void: c.visible = true)
	tw.tween_method(func(t: float) -> void:
		c.position = from.lerp(mid, t).lerp(mid.lerp(to, t), t)
		c.rotation = t * 6.0, 0.0, 1.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		if landed.is_valid():
			landed.call()
		c.queue_free())


static func sfx(path: String, pitch := 1.0, volume_db := -6.0) -> void:
	Sfx.play_path(path, pitch, volume_db)


## Pitch for step `s` up a scale (major for notes, pentatonic for coins).
static func scale_pitch(s: int, pentatonic := false) -> float:
	var steps: Array = [0, 2, 4, 5, 7, 9, 11]
	if pentatonic:
		steps = [0, 3, 5, 7, 10]
	var octave := s / steps.size()
	var semis: int = int(steps[s % steps.size()]) + 12 * mini(octave, 2)
	return pow(2.0, semis / 12.0)


static func rarity_color(tier: String) -> Color:
	return Palette.RARITY.get(tier, Palette.CREAM)


## Loop a music bed on its own player under `parent`.
static func music(parent: Node, path: String, volume_db := -14.0, bus := "Music") -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	if ResourceLoader.exists(path):
		var stream: AudioStream = load(path)
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		elif stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
		p.stream = stream
	p.volume_db = volume_db
	parent.add_child(p)
	if p.stream:
		p.play()
	return p
