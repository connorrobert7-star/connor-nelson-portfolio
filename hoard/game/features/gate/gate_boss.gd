class_name GateBoss
extends Node2D
## One debt as a boss outside the gate: a big animated sprite from the packs, an HP bar
## with the real balance painted on it, the interest pips, and every reaction (roar, hit,
## heal, death). It only draws numbers from Game.state and API responses; it never does
## money math. `shown_hp` is what the bar shows while an animation catches up.

const BAR_SHEET := "res://art/packs/shattered-pixel-dungeon/interfaces/boss_hp.png"
const BAR_FRAME := Rect2(1, 1, 62, 14)
const BAR_FILL := Rect2(71, 0, 47, 4)
const BAR_GHOST := Rect2(71, 5, 47, 4)
const BAR_SKULL := Rect2(64, 0, 6, 6)
const FILL_AT := Vector2(14, 2)  # where the fill sits inside the frame
const FILL_W := 47.0
const PIP := Color("8fbf7a")

var data: Dictionary = {}
var debt_id := ""
var px := 3
var bar_px := 2
var front := false
var shown_hp := 0.0
var busy := false
var size_px := Vector2.ZERO  # the sprite's drawn size

var _sprite := Sprite2D.new()
var _mat: ShaderMaterial
var _idle: Array[Rect2] = []
var _rage: Array[Rect2] = []
var _fps := 6.0
var _t := randf() * 3.0
var _rage_left := 0.0
var _phase := randf() * TAU
var _light: Sprite2D
var _shadow: Sprite2D
var _bar := Node2D.new()
var _fill := Sprite2D.new()
var _ghost := Sprite2D.new()
var _number: Label
var _pips := Node2D.new()
var _bubble := SpeechBubble.new()
var _bleed := CPUParticles2D.new()
var _drop: Node2D
var _reticle := Node2D.new()
var _targeted := false
var _ghost_ratio := 1.0
var _kick := Vector2.ZERO
var _squash := Vector2.ONE
var _swell := 1.0


func setup(d: Dictionary, pixel_scale: int, is_front: bool) -> void:
	data = d
	debt_id = str(d.debt_id)
	px = pixel_scale
	front = is_front
	bar_px = 2 if is_front else 1
	var look: Dictionary = d.look
	_fps = float(look.get("fps", 6))
	for r: Array in look.idle:
		_idle.append(Rect2(r[0], r[1], r[2], r[3]))
	for r: Array in look.get("rage", look.idle):
		_rage.append(Rect2(r[0], r[1], r[2], r[3]))
	size_px = _idle[0].size * px
	shown_hp = float(d.hp_cents)


func _ready() -> void:
	# The pool of light it stands in, and its shadow.
	_light = GateFx.glow(Color(0.55, 0.42, 0.62, 0.55), size_px.x * 1.1, -2)
	_light.position = Vector2(0, -size_px.y * 0.35)
	add_child(_light)
	_shadow = GateFx.glow(Color(0, 0, 0, 0.0), 1.0, -1)
	_shadow.material = null
	_shadow.modulate = Color(0, 0, 0, 0.55)
	_shadow.scale = Vector2(size_px.x / 64.0 * 0.9, size_px.x / 64.0 * 0.22)
	add_child(_shadow)

	_sprite.texture = load(str(data.look.sheet))
	_sprite.region_enabled = true
	_sprite.region_rect = _idle[0]
	_sprite.centered = true
	_sprite.offset = Vector2(0, -_idle[0].size.y / 2.0)
	_sprite.scale = Vector2(px, px)
	_mat = GateFx.boss_material()
	_sprite.material = _mat
	add_child(_sprite)

	_build_bar()
	_build_reticle()
	_build_drop()
	_bleed.emitting = false
	_bleed.amount = 18
	_bleed.lifetime = 1.1
	_bleed.direction = Vector2.DOWN
	_bleed.spread = 25.0
	_bleed.initial_velocity_min = 4.0
	_bleed.initial_velocity_max = 14.0
	_bleed.gravity = Vector2(0, 40)
	_bleed.color = Color(0.5, 0.42, 0.58)
	_bleed.scale_amount_min = 1.0
	_bleed.scale_amount_max = 2.0
	_bleed.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_bleed.emission_rect_extents = Vector2(FILL_W * bar_px / 2.0, 1)
	_bleed.position = _bar.position + (FILL_AT + Vector2(FILL_W / 2.0, 4)) * bar_px
	_bleed.z_index = 29
	add_child(_bleed)
	# Words come out to the side, toward the middle of the field, clear of the HUD.
	var dir := -1.0 if position.x > 250.0 else 1.0
	_bubble.position = Vector2(dir * (size_px.x / 2.0 + (58.0 if front else 46.0)), -size_px.y * (0.55 if front else 0.6))
	add_child(_bubble)
	_set_shown(shown_hp)
	_dress_pips()


# --- building --------------------------------------------------------------------

func _build_bar() -> void:
	var sheet: Texture2D = load(BAR_SHEET)
	_bar.position = Vector2(-BAR_FRAME.size.x * bar_px / 2.0, -size_px.y - BAR_FRAME.size.y * bar_px - 6)
	_bar.z_index = 30
	add_child(_bar)
	var frame := _region(sheet, BAR_FRAME)
	frame.scale = Vector2(bar_px, bar_px)
	_bar.add_child(frame)
	_ghost = _region(sheet, BAR_GHOST)
	_ghost.position = FILL_AT * bar_px
	_ghost.scale = Vector2(bar_px, bar_px)
	_bar.add_child(_ghost)
	_fill = _region(sheet, BAR_FILL)
	_fill.position = FILL_AT * bar_px
	_fill.scale = Vector2(bar_px, bar_px)
	_bar.add_child(_fill)
	var skull := _region(sheet, BAR_SKULL)
	skull.position = Vector2(4, 4) * bar_px
	skull.scale = Vector2(bar_px, bar_px)
	_bar.add_child(skull)
	_number = GateFx.label("", 16 if front else 12, Palette.CREAM, 5 if front else 4)
	_number.size = Vector2(FILL_W * bar_px + 40, 16)
	_number.position = Vector2(FILL_AT.x * bar_px - 20, FILL_AT.y * bar_px - 8 + 2 * bar_px)
	_number.pivot_offset = _number.size / 2.0
	_bar.add_child(_number)
	_pips.position = Vector2(FILL_AT.x * bar_px, (BAR_FRAME.size.y + 3) * bar_px)
	_bar.add_child(_pips)


func _region(tex: Texture2D, r: Rect2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.region_enabled = true
	s.region_rect = r
	s.centered = false
	return s


func _build_reticle() -> void:
	_reticle.visible = false
	_reticle.z_index = 20
	add_child(_reticle)
	var w := size_px.x / 2.0 + 6
	var top := -size_px.y - 4
	for corner: Vector2 in [Vector2(-w, top), Vector2(w, top), Vector2(-w, 4), Vector2(w, 4)]:
		var l := Line2D.new()
		l.width = 2
		l.default_color = Palette.CREAM
		var sx := 1.0 if corner.x < 0 else -1.0
		var sy := 1.0 if corner.y < 0 else -1.0
		l.points = PackedVector2Array([corner + Vector2(0, 8 * sy), corner, corner + Vector2(8 * sx, 0)])
		_reticle.add_child(l)


## The cosmetic only this boss drops, hanging off the bar in its rarity's glow.
func _build_drop() -> void:
	var drop: Variant = data.get("drop")
	if not drop is Dictionary or bool(data.defeated):
		return
	_drop = Node2D.new()
	_drop.position = _bar.position + Vector2(BAR_FRAME.size.x * bar_px + 10, BAR_FRAME.size.y * bar_px / 2.0)
	_drop.z_index = 31
	add_child(_drop)
	var tier_color: Color = Palette.RARITY.get(str(drop.tier), Palette.CREAM)
	var g := GateFx.glow(Color(tier_color, 0.7), 14, 0)
	_drop.add_child(g)
	var at := AtlasTexture.new()
	at.atlas = load(str(drop.icon.sheet))
	var r: Array = drop.icon.rect
	at.region = Rect2(r[0], r[1], r[2], r[3])
	# Its outline in the rarity's color around a dark silhouette, until it drops.
	for off: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		var edge := Sprite2D.new()
		edge.texture = at
		edge.material = GateFx.solid_material(tier_color)
		edge.position = off
		_drop.add_child(edge)
	var icon := Sprite2D.new()
	icon.texture = at
	icon.material = GateFx.solid_material(Color("1d1424"))
	_drop.add_child(icon)


func _dress_pips() -> void:
	for c in _pips.get_children():
		c.queue_free()
	var days: Variant = data.get("days_to_heal")
	if days == null or bool(data.defeated):
		return
	var n := int(days)
	if n <= 0 or n > 7:
		return
	for i in n:
		var p := ColorRect.new()
		p.color = PIP
		p.size = Vector2(3, 3) * (1 if bar_px == 1 else 1.5)
		p.position = Vector2(i * 6 * (1 if bar_px == 1 else 1.5), 0)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pips.add_child(p)
		var tw := p.create_tween().set_loops()
		tw.tween_interval(i * 0.08)
		tw.tween_property(p, "modulate:a", 0.25, 0.5)
		tw.tween_property(p, "modulate:a", 1.0, 0.5)


# --- every frame --------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	var raging := _rage_left > 0.0
	if raging:
		_rage_left -= delta
	var frames := _rage if raging else _idle
	var speed := _fps * (1.8 if raging else (1.4 if hp_ratio() < 0.5 else 1.0))
	_sprite.region_rect = frames[int(_t * speed) % frames.size()]
	var bob := roundf(sin(_t * TAU / 1.2 + _phase) * 1.0)
	var shiver := Vector2.ZERO
	if hp_ratio() < 0.25 and not bool(data.get("defeated", false)) and fmod(_t, 2.3) < 0.18:
		shiver = Vector2(randf_range(-1, 1), 0).round()
	_sprite.position = Vector2(0, bob) + _kick + shiver
	var breath := 1.0 + 0.02 * sin(_t * TAU / 2.4 + _phase)
	_sprite.scale = Vector2(px * _squash.x * _swell, px * _squash.y * breath * _swell)
	if _reticle.visible:
		var pulse := 1.0 + 0.05 * sin(_t * 8.0)
		_reticle.scale = Vector2(pulse, pulse)
	if _drop:
		_drop.position.y = _bar.position.y + BAR_FRAME.size.y * bar_px / 2.0 + roundf(sin(_t * 2.0 + _phase) * 2.0)
	_bleed.emitting = hp_ratio() < 0.5 and shown_hp > 0.0


## The balance painted on the bar right now.
func painted() -> String:
	return _number.text


func hp_ratio() -> float:
	return clampf(shown_hp / maxf(1.0, float(data.max_hp_cents)), 0.0, 1.0)


func _set_shown(v: float) -> void:
	shown_hp = maxf(0.0, v)
	_fill.scale.x = bar_px * hp_ratio()
	_number.text = Money.fmt(int(roundf(shown_hp)))


func _set_ghost(ratio: float) -> void:
	_ghost_ratio = ratio
	_ghost.scale.x = bar_px * ratio


## New data from /state. Snaps the bar unless a reaction is animating it.
func refresh(d: Dictionary) -> void:
	data = d
	_dress_pips()
	if not busy:
		_set_shown(float(d.hp_cents))
		_set_ghost(hp_ratio())


## Where hits land, in the parent's space.
func chest() -> Vector2:
	return position + Vector2(0, -size_px.y * 0.5)


## The tappable area, in the parent's space.
func hit_rect() -> Rect2:
	return Rect2(position + Vector2(-size_px.x / 2.0 - 6, -size_px.y - 30), Vector2(size_px.x + 12, size_px.y + 34))


func set_target(on: bool) -> void:
	_targeted = on
	_reticle.visible = on
	_light.modulate = Color(0.85, 0.7, 0.9, 0.85) if on else Color(0.55, 0.42, 0.62, 0.55)


# --- reactions ------------------------------------------------------------------

func say(text: String, hold := 1.6) -> void:
	if text != "":
		await _bubble.say(text, hold)


func line(kind: String) -> String:
	var lines: Variant = data.get("lines", {}).get(kind, "")
	if lines is Array:
		return str((lines as Array).pick_random()) if not (lines as Array).is_empty() else ""
	return str(lines)


## It sees the stack coming: the rage frames, a low growl.
func brace() -> void:
	_rage_left = 0.7
	Sfx.play_path(str(data.look.get("roar", "")), 0.7, -18.0)


## The payment didn't go: a shrug, shoulders up twice, and back to waiting.
func shrug() -> void:
	_rage_left = 0.0
	var tw := create_tween()
	for k in 2:
		tw.tween_property(self, "_squash", Vector2(0.95, 1.07), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "_squash", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Telegraph, then roar: two quick swells, the rage frames, and the sound.
func roar(text := "", loud := true) -> void:
	var look: Dictionary = data.look
	_rage_left = 0.9
	var tw := create_tween()
	tw.tween_property(self, "_swell", 1.06, 0.12).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "_swell", 1.0, 0.1)
	tw.tween_property(self, "_swell", 1.1, 0.14).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		Sfx.play_path(str(look.get("roar", "")), randf_range(0.9, 1.05), -4.0 if loud else -14.0)
		if loud and front:
			_shake(2.0, 0.3)
		GateFx.burst(get_parent(), chest() + Vector2(0, -size_px.y * 0.2), GateFx.ASH, 10, 60.0, 0.8, -20.0)
	)
	tw.tween_property(self, "_swell", 1.0, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if text != "":
		say(text)
	await tw.finished


## A payment lands: exactly `amount` of damage, down to `to_hp`.
func hit(amount_cents: int, to_hp: int, text := "", by_bank := false) -> void:
	busy = true
	var look: Dictionary = data.look
	var parent := get_parent()
	_mat.set_shader_parameter("flash", 1.0)
	GateFx.hit_stop(get_tree(), GateFx.stop_for(amount_cents))
	Sfx.play_path("res://art/packs/kenney-impact-sounds/Audio/impactPunch_heavy_00%d.ogg" % randi_range(0, 4), randf_range(0.9, 1.1), -2.0)
	Sfx.play_path("res://art/packs/kenney-impact-sounds/Audio/impactMetal_heavy_00%d.ogg" % randi_range(0, 4), randf_range(0.9, 1.1), -8.0)
	Sfx.play_path(str(look.get("hurt", "")), randf_range(0.95, 1.1), -6.0)
	_shake(2.0, 0.2)
	GateFx.puff(parent, chest() + Vector2(randf_range(-8, 8), randf_range(-8, 8)), 2.0 if amount_cents >= 10000 else 1.5)
	GateFx.burst(parent, chest(), Palette.CREAM, 18 + mini(amount_cents / 500, 30), 170.0, 0.55)
	GateFx.burst(parent, chest(), Color("d8cfc0"), 10, 90.0, 0.9)
	GateFx.float_number(parent, chest() + Vector2(randf_range(-10, 10), -8), "-" + Money.fmt(amount_cents), Palette.CREAM, 20 if front else 15, 16.0, 0.9)
	if amount_cents >= 10000:
		GateFx.flash(parent, Color.WHITE, 0.3, 0.1)
	await get_tree().create_timer(0.034).timeout
	_mat.set_shader_parameter("flash", 0.0)
	var tw := create_tween()
	tw.tween_property(self, "_kick", Vector2(0, -3), 0.08)
	tw.parallel().tween_property(self, "_squash", Vector2(1.12, 0.88), 0.06)
	tw.tween_property(self, "_kick", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "_squash", Vector2.ONE, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# The bar: the leading edge jumps, the ghost follows, the painted number counts down.
	var from := shown_hp
	var ratio_before := hp_ratio()
	var bt := create_tween()
	bt.tween_method(_set_shown, from, float(to_hp), 0.08)
	bt.tween_interval(0.12)
	bt.tween_method(_set_ghost, ratio_before, clampf(float(to_hp) / maxf(1.0, float(data.max_hp_cents)), 0.0, 1.0), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_number.scale = Vector2(1.35, 1.35)
	var nt := _number.create_tween()
	nt.tween_property(_number, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if text == "" and not by_bank:
		text = line("low") if float(to_hp) / maxf(1.0, float(data.max_hp_cents)) < 0.5 and randf() < 0.6 else line("hit")
	if text != "" and to_hp > 0:
		say(text, 1.2)
	await bt.finished
	busy = false


## Interest: Goo's two beats, the amount said out loud, and a slow green heal.
func heal(amount_cents: int, to_hp: int, text: String) -> void:
	busy = true
	var parent := get_parent()
	for beat in 2:
		Sfx.play_path("res://art/packs/shattered-pixel-dungeon/sounds/chargeup.mp3", 0.8 if beat == 0 else 1.0, -4.0)
		var tw := create_tween()
		tw.tween_property(self, "_swell", 1.12, 0.22).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_method(func(a: float) -> void: _mat.set_shader_parameter("wash", Color(GateFx.MONEY_GREEN, a)), 0.0, 0.45, 0.22)
		tw.tween_property(self, "_swell", 1.0, 0.25).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_method(func(a: float) -> void: _mat.set_shader_parameter("wash", Color(GateFx.MONEY_GREEN, a)), 0.45, 0.15, 0.25)
		await tw.finished
		await get_tree().create_timer(0.18).timeout
	say(text, 1.8)
	Sfx.play_path("res://art/packs/ninja-adventure/Audio/Sounds/Magic & Skill/Heal.ogg", 0.9, -3.0)
	# Green motes rise out of the ground into it, slowly.
	for i in 14:
		var m := ColorRect.new()
		m.color = GateFx.MONEY_GREEN
		m.size = Vector2(2, 2)
		m.position = position + Vector2(randf_range(-size_px.x * 0.6, size_px.x * 0.6), randf_range(-4, 6))
		m.z_index = 40
		parent.add_child(m)
		var mt := m.create_tween()
		mt.tween_interval(i * 0.05)
		mt.tween_property(m, "position", chest() + Vector2(randf_range(-6, 6), randf_range(-6, 6)), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		mt.tween_callback(m.queue_free)
	GateFx.float_number(parent, chest() + Vector2(0, -size_px.y * 0.45), "+" + Money.fmt(amount_cents), GateFx.MONEY_GREEN, 16 if front else 13, 18.0, 1.4)
	var bt := create_tween()
	bt.tween_method(_set_shown, shown_hp, float(to_hp), 1.2).set_trans(Tween.TRANS_SINE)
	bt.parallel().tween_method(_set_ghost, _ghost_ratio, clampf(float(to_hp) / maxf(1.0, float(data.max_hp_cents)), 0.0, 1.0), 1.2)
	bt.parallel().tween_method(func(a: float) -> void: _mat.set_shader_parameter("wash", Color(GateFx.MONEY_GREEN, a)), 0.35, 0.0, 1.2)
	await bt.finished
	await get_tree().create_timer(0.6).timeout
	busy = false


## Paid off. Shakes apart, the bar shatters, it dissolves into ash. Returns when it's gone.
func die(text: String) -> void:
	busy = true
	var look: Dictionary = data.look
	var parent := get_parent()
	_reticle.visible = false
	if _drop:
		_drop.visible = false
	GateFx.hit_stop(get_tree(), 0.2)
	GateFx.flash(parent, Color.WHITE, 0.8, 0.15)
	Sfx.play_path(str(look.get("die", "")), 0.8, -2.0)
	Sfx.play_path("res://art/packs/shattered-pixel-dungeon/sounds/shatter.mp3", 1.0, -4.0)
	_shatter_bar()
	_rage_left = 2.2
	var tw := create_tween()
	for i in 10:
		tw.tween_callback(func() -> void:
			_mat.set_shader_parameter("flash", 1.0 if i % 2 == 0 else 0.0)
			_kick = Vector2(randf_range(-3, 3), randf_range(-2, 2)).round()
			if i % 3 == 0:
				GateFx.puff(parent, chest() + Vector2(randf_range(-size_px.x / 2, size_px.x / 2), randf_range(-size_px.y / 3, size_px.y / 3)), 0.8)
				Sfx.play_path("res://art/packs/kenney-impact-sounds/Audio/impactPunch_heavy_00%d.ogg" % (i % 5), 0.7 + i * 0.04, -6.0)
		)
		tw.tween_interval(0.09)
	await tw.finished
	_mat.set_shader_parameter("flash", 0.0)
	_kick = Vector2.ZERO
	say(text, 2.4)
	_shake(6.0, 0.6)
	Sfx.play("boss_down", 0.8)
	Sfx.play_path("res://art/packs/shattered-pixel-dungeon/sounds/blast.mp3", 0.8, -3.0)
	GateFx.blast(parent, position + Vector2(0, -size_px.y * 0.45), maxf(1.0, size_px.y / 70.0))
	GateFx.burst(parent, chest(), GateFx.ASH, 60, 160.0, 1.4, 120.0)
	GateFx.burst(parent, chest(), Palette.CREAM, 20, 220.0, 0.8)
	var dt := create_tween()
	dt.tween_method(func(v: float) -> void: _mat.set_shader_parameter("dissolve", v), 0.0, 1.0, 1.1)
	dt.parallel().tween_property(self, "_squash", Vector2(1.25, 0.2), 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	dt.parallel().tween_property(_light, "modulate:a", 0.0, 1.1)
	dt.parallel().tween_property(_shadow, "modulate:a", 0.0, 1.1)
	await dt.finished
	_sprite.visible = false
	await get_tree().create_timer(1.0).timeout
	busy = false


## The HP bar breaks into shards that spin off and fall.
func _shatter_bar() -> void:
	var parent := get_parent()
	var origin := position + _bar.position
	var w := BAR_FRAME.size.x * bar_px
	var h := BAR_FRAME.size.y * bar_px
	var colors := [Color("9b9a86"), Color("6d6c5c"), Color("c8c6ae"), Color("8f2a2a"), Palette.CREAM]
	for k in 22:
		var shard := ColorRect.new()
		shard.color = colors[k % colors.size()]
		shard.size = Vector2(randi_range(2, 5), randi_range(2, 4)) * bar_px
		shard.position = origin + Vector2(randf_range(0, w), randf_range(0, h))
		shard.pivot_offset = shard.size / 2.0
		shard.z_index = 70
		shard.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(shard)
		var dx := randf_range(-70, 70)
		var tw := shard.create_tween()
		tw.tween_property(shard, "position", shard.position + Vector2(dx * 0.4, randf_range(-26, -8)), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(shard, "rotation", randf_range(-6, 6), 1.0)
		tw.tween_property(shard, "position", shard.position + Vector2(dx, randf_range(80, 130)), 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(shard, "modulate:a", 0.0, 0.75)
		tw.tween_callback(shard.queue_free)
	_bar.visible = false
	_bleed.emitting = false


func _shake(strength: float, seconds: float) -> void:
	var level := get_parent()
	while level and not level is Level:
		level = level.get_parent()
	if level and (level as Level).main:
		(level as Level).main.shake(strength, seconds)
