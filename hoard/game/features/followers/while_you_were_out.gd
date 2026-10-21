class_name WhileYouWereOutOverlay
extends Overlay
## "While you were out": the away queue (state.away) played as a little night scene, highest
## priority first: money that landed, builds, gate hits, mourning, growth, the flock posed in
## the week's reactions, and the personal follower running to hug you. 12 s or less; a tap
## skips to the next beat. When it ends, the beats are marked seen.

const MAX_SECONDS := 12.0
const SECONDS := {
	"landed": 2.4, "build": 1.8, "gate_hit": 1.8, "mourning": 2.4, "grew": 2.2,
	"resized": 1.4, "poses": 2.0, "hug": 2.0,
}
const TV := "res://art/packs/sbs-animated-transitions/Television01_strip_16x128.png"
const SLIME := "res://art/packs/ninja-adventure/Actor/Boss/GiantSlime/Idle.png"
const SLIME_HIT := "res://art/packs/ninja-adventure/Actor/Boss/GiantSlime/Hit.png"
const TOWN := "res://art/packs/kenney-tiny-town/Tilemap/tilemap_packed.png"
const DECOR := "res://art/packs/dawnlike/Objects/Decor0.png"
const CANDLES := "res://art/packs/vk-candles-with-eyes/candles_with_eyes.png"

var beats: Array[Dictionary] = []
var ids: Array = []
## The kinds that played, in order (for tours and tests).
var played: Array[String] = []

var _skip := false
var _scene := Node2D.new()
var _moon := Sprite2D.new()
var _music := AudioStreamPlayer.new()
var _elapsed := 0.0
var _total := 1.0


func _init(away: Array = []) -> void:
	super._init()
	beats = coalesce(away)
	for a: Dictionary in away:
		ids.append(a.get("id"))


## One beat per kind for the scene's repeating kinds; money adds up; at most three of the rest.
static func coalesce(away: Array) -> Array[Dictionary]:
	var sorted := away.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa := int(a.get("priority", 50))
		var pb := int(b.get("priority", 50))
		return pa < pb if pa != pb else int(a.get("id", 0)) < int(b.get("id", 0)))
	var out: Array[Dictionary] = []
	var by_kind: Dictionary = {}
	for a: Dictionary in sorted:
		var kind := str(a.get("kind", ""))
		var payload: Dictionary = a.get("payload", {})
		if by_kind.has(kind):
			var prev: Dictionary = by_kind[kind]
			match kind:
				"landed":
					prev.payload.amount_cents = int(prev.payload.get("amount_cents", 0)) + int(payload.get("amount_cents", 0))
				"poses", "hug", "resized", "grew":
					prev.payload = payload.merged({"from_stage": prev.payload.get("from_stage", payload.get("from_stage", 0))}, true) if kind == "grew" else payload
				_:
					if int(prev.get("count", 1)) < 3:
						prev.count = int(prev.get("count", 1)) + 1
						out.append({"kind": kind, "payload": payload, "priority": a.get("priority", 50)})
			continue
		var beat := {"kind": kind, "payload": payload.duplicate(), "priority": a.get("priority", 50), "count": 1}
		by_kind[kind] = beat
		out.append(beat)
	return out


func _ready() -> void:
	add_backdrop(1.0)
	_build_sky()
	add_child(_scene)
	_music.stream = load(str(FollowerArt.AUDIO.away_bed)) as AudioStream
	_music.volume_db = -18.0
	add_child(_music)
	_music.play()
	_run()


func _gui_input(event: InputEvent) -> void:
	var tap := (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if tap:
		accept_event()
		_skip = true


func _process(delta: float) -> void:
	_elapsed += delta
	_moon.position = Vector2(lerpf(30.0, 450.0, clampf(_elapsed / _total, 0.0, 1.0)), 30.0 - sin(clampf(_elapsed / _total, 0.0, 1.0) * PI) * 12.0)


func _build_sky() -> void:
	# A moon crosses the top while the night plays out; stars blink.
	var halo := FollowerArt.glow(Color(Palette.CREAM, 0.35), 26.0)
	_moon.add_child(halo)
	var disc := Sprite2D.new()
	disc.texture = FollowerArt.tex(FollowerArt.SOFT)
	disc.scale = Vector2.ONE * 0.1
	disc.modulate = Palette.CREAM
	_moon.add_child(disc)
	add_child(_moon)
	for i in 26:
		var s := Sprite2D.new()
		s.texture = FollowerArt.speck(FollowerArt.SPECK_SPARKLE)
		s.position = Vector2(randf_range(8, 472), randf_range(6, 90))
		s.scale = Vector2.ONE * randf_range(0.3, 0.7)
		s.modulate = Color(Palette.MUTED, randf_range(0.2, 0.7))
		add_child(s)
		var tw := s.create_tween().set_loops()
		tw.tween_property(s, "modulate:a", 0.1, randf_range(0.6, 1.6))
		tw.tween_property(s, "modulate:a", 0.7, randf_range(0.6, 1.6))


func _run() -> void:
	await _tv(true)
	var total := 0.0
	for b in beats:
		total += float(SECONDS.get(b.kind, 1.6))
	var k := minf(1.0, (MAX_SECONDS - 1.2) / maxf(total, 0.1))
	_total = maxf(1.0, total * k)
	for b in beats:
		if not is_inside_tree():
			return
		_clear()
		played.append(str(b.kind))
		var seconds := float(SECONDS.get(b.kind, 1.6)) * k
		var method := "_beat_" + str(b.kind)
		if has_method(method):
			call(method, b.payload, seconds)
		else:
			_beat_other(b.kind, b.payload, seconds)
		await _wait(seconds)
	_clear()
	if not ids.is_empty():
		await Game.call_api("POST", "/away/seen", {"ids": ids})
	await _tv(false)
	await Game.refresh()
	close(played)


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds and not _skip and is_inside_tree():
		await get_tree().process_frame
		t += get_process_delta_time()
	_skip = false


func _tv(on: bool) -> void:
	var s := Sprite2D.new()
	s.centered = false
	s.scale = Vector2(480.0 / 128.0, 270.0 / 128.0)
	s.z_index = 100
	add_child(s)
	for f in 16:
		var frame := f if on else 15 - f
		s.texture = FollowerArt.region(TV, Rect2(frame * 128, 0, 128, 128))
		s.modulate = Color(Palette.NIGHT, 1.0)
		await get_tree().create_timer(0.022).timeout
		if not is_inside_tree():
			return
	s.queue_free()


func _clear() -> void:
	for c in _scene.get_children():
		c.queue_free()


# --- beats ----------------------------------------------------------------------------------------


## Money that landed while you were away pours home as bone-white motes; the bell rings.
func _beat_landed(p: Dictionary, seconds: float) -> void:
	var amount := int(p.get("amount_cents", 0))
	var altar := _sprite(FollowerArt.altar(0), Vector2(240, 214), 3.0, Vector2(0, -16))
	var g := FollowerArt.glow(Color(Palette.GLOW, 0.4), 90.0)
	g.position = Vector2(240, 160)
	_scene.add_child(g)
	_animate(altar, func(t: float) -> void: altar.texture = FollowerArt.altar(int(t * 14.0)))
	FollowerArt.play("bell", 1.0, -2.0)
	FollowerArt.play("motes", 1.0, -6.0)
	var count := clampi(amount / 1500, 14, 36)
	for wave in 3:
		_later(wave * seconds * 0.22, func() -> void:
			FlockFx.motes(_scene, Vector2(240 + randf_range(-120, 120), -10), Vector2(240, 168), count, 0.6))
	var label := FollowerArt.label("+" + Money.fmt(0), FollowerArt.FONT_NUMBERS, 22, Palette.CREAM)
	label.size = Vector2(200, 26)
	label.position = Vector2(140, 92)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scene.add_child(label)
	var tw := label.create_tween()
	tw.tween_interval(seconds * 0.2)
	tw.tween_method(func(v: float) -> void:
		if is_instance_valid(label):
			label.text = "+" + Money.fmt(int(v)), 0.0, float(amount), seconds * 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(func() -> void:
		FollowerArt.play("chant", 1.0, -6.0)
		FlockFx.ring(_scene, Vector2(240, 104), Palette.CREAM, 50.0, 0.5))
	_kneelers(Vector2(240, 214), "chant")


## A missed week: a candle is lit on the Grave of Weeks, the flock in veils, a toll.
func _beat_mourning(p: Dictionary, seconds: float) -> void:
	FollowerArt.play("toll", 0.85, -2.0)
	_later(0.4, func() -> void: FollowerArt.play("dirge", 1.0, -8.0))
	var stone := _sprite(FollowerArt.region(DECOR, Rect2(32, 272, 16, 16)), Vector2(240, 196), 5.0, Vector2(0, -8))
	stone.modulate = Color(0.85, 0.85, 0.95)
	var candle := _sprite(FollowerArt.region(CANDLES, Rect2(111, 15, 14, 26)), Vector2(184, 198), 1.5, Vector2(0, -13))
	var flame := FollowerArt.glow(Color(Palette.GLOW, 0.0), 22.0)
	flame.position = candle.position + Vector2(0, -36)
	_scene.add_child(flame)
	var tw := flame.create_tween()
	tw.tween_interval(seconds * 0.3)
	tw.tween_property(flame, "modulate:a", 0.6, 0.4)
	var start := str(p.get("week_start", ""))
	var end := str(p.get("week_end", ""))
	var words := FollowerArt.label("%s - %s" % [ShrineLevel._short_day(start), ShrineLevel._short_day(end)], FollowerArt.FONT_TINY, 16, Palette.CREAM)
	words.size = Vector2(200, 16)
	words.position = Vector2(140, 108)
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scene.add_child(words)
	_rain()
	_kneelers(Vector2(240, 214), "veiled")


## The personal follower grew a stage (or hatched) while you were out.
func _beat_grew(p: Dictionary, seconds: float) -> void:
	var to := int(p.get("stage", 1))
	var from := int(p.get("from_stage", to - 1))
	var body := FollowerBody.new("personal", "personal", Vector2(240, 200))
	body.wanders = false
	_scene.add_child(body)
	var f: Dictionary = Game.state.get("followers", {})
	var d: Dictionary = (f.get("personal", {}) as Dictionary).duplicate()
	d.stage = maxi(1, from)
	d.hatched = from > 0
	d.pose = "egg" if from == 0 else "bounce"
	d.bubble = ""
	body.apply(d, f, "fervent")
	body.scale = Vector2(3, 3)
	var g := FollowerArt.glow(Color(Palette.CREAM, 0.3), 60.0)
	g.position = Vector2(240, 160)
	_scene.add_child(g)
	_scene.move_child(g, 0)
	d.stage = to
	d.hatched = true
	body.data = d
	_later(seconds * 0.3, func() -> void:
		if from == 0:
			body.hatch()
		else:
			body.grow(to))
	# The kept weeks, as candles: numbers on things.
	var kept := mini(13, int(p.get("kept_weeks", to)))
	for i in kept:
		_later(seconds * 0.45 + i * 0.05, func() -> void:
			var c := _sprite(FollowerArt.region(CANDLES, Rect2(111, 15, 14, 26)), Vector2(240 + (i - (kept - 1) / 2.0) * 16.0, 250), 0.6, Vector2(0, -13))
			var fl := FollowerArt.glow(Color(Palette.GLOW, 0.45), 6.0)
			fl.position = c.position + Vector2(0, -15)
			_scene.add_child(fl)
			FollowerArt.play("coin", 1.0 + i * 0.06, -16.0))


## Holdings are resized on Sunday: quietly, no sound.
func _beat_resized(p: Dictionary, _seconds: float) -> void:
	var f: Dictionary = Game.state.get("followers", {})
	var holds: Array = f.get("holdings", [])
	var giant_x := -1.0
	for i in holds.size():
		var h: Dictionary = holds[i]
		var b := FollowerBody.new("holding", str(h.id), Vector2(80 + i * (320.0 / maxf(1, holds.size() - 1)), 210))
		b.px = Flock.px_for(h)
		b.wanders = false
		_scene.add_child(b)
		var d := h.duplicate()
		d.bubble = ""
		d.pose = "idle"
		b.apply(d, f, "content")
		b.body.scale = Vector2.ONE
		b.create_tween().tween_property(b.body, "scale", Vector2(b.px, b.px), 1.2).set_trans(Tween.TRANS_SINE)
		if bool(h.get("giant", false)):
			giant_x = b.position.x
	if giant_x >= 0.0:
		for c in _scene.get_children():
			if c is FollowerBody and not bool((c as FollowerBody).data.get("giant", false)):
				(c as FollowerBody).stare_at = Vector2(giant_x, 200)
				(c as FollowerBody).bubble_name = "sweat"
	FollowerArt.play("whoosh", 0.7, -18.0)


## The flock, posed in the week: hungry ones drool and growl, lazy ones sleep, the faithful chant.
func _beat_poses(p: Dictionary, _seconds: float) -> void:
	var f: Dictionary = Game.state.get("followers", {})
	var band := str(p.get("band", f.get("faith", {}).get("band", "content")))
	var reactions: Array = p.get("reactions", [])
	var hungry := int(p.get("hungry", 0)) > 0 or "hungry" in reactions
	# What they gather around says what the week was: an empty cauldron, a cold hearth, the fire.
	var prop: Sprite2D
	if hungry:
		prop = _sprite(FollowerArt.region(ShrineLevel.WHIMSY, Rect2(1136, 1026, 24, 38)), Vector2(240, 196), 2.0, Vector2(0, -19))
		prop.modulate = Color(0.6, 0.55, 0.7)
	else:
		prop = _sprite(FollowerArt.altar(0), Vector2(240, 196), 2.0, Vector2(0, -16))
		var cold := band in ["doubting", "mourning"] or bool(p.get("mourning", false))
		prop.modulate = Color(0.5, 0.48, 0.6) if cold else Color.WHITE
		_animate(prop, func(t: float) -> void: prop.texture = FollowerArt.altar(int(t * (4.0 if cold else 14.0))))
	var row: Array = []
	if bool(f.get("personal", {}).get("hatched", false)):
		row.append(f.personal)
	row.append_array(f.get("holdings", []))
	var n := row.size() + 4
	for i in n:
		var side := -1.0 if i % 2 == 0 else 1.0
		var at := Vector2(240 + side * (56 + (i / 2) * 38), 214 - (i / 2) * 6)
		var b: FollowerBody
		var d: Dictionary
		if i < row.size():
			d = (row[i] as Dictionary).duplicate()
			b = FollowerBody.new(str(d.get("kind", "holding")), str(d.id), at)
			b.px = 1
		else:
			b = FollowerBody.new("cultist", "c%d" % i, at)
			d = {"pose": f.get("cultist_pose", "idle"), "bubble": f.get("cultist_bubble", ""), "veiled": f.get("mourning", false), "hungry": hungry}
		b.index = i
		b.wanders = false
		b.stare_at = Vector2(240, 190)
		_scene.add_child(b)
		b.apply(d, f, band)
		b.scale = Vector2(2, 2)
		b.bubble.scale = Vector2(0.55, 0.55)
		b.bubble_now()
	if hungry:
		FollowerArt.play("growl", 0.6, -6.0)
		_later(0.5, func() -> void: FollowerArt.play("growl", 0.7, -8.0))
	elif band == "fervent":
		FollowerArt.play("chant", 1.0, -6.0)


## The personal follower spots you, runs over and hugs.
func _beat_hug(p: Dictionary, seconds: float) -> void:
	var leader := Sprite2D.new()
	leader.texture = Leader.SHEET
	leader.region_enabled = true
	leader.region_rect = Rect2(Leader.IDLE, Leader.FRAME)
	leader.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	leader.offset = Vector2(0, -Leader.FRAME.y / 2.0)
	leader.position = Vector2(200, 210)
	leader.scale = Vector2(3, 3)
	_scene.add_child(leader)
	var f: Dictionary = Game.state.get("followers", {})
	var d: Dictionary = (f.get("personal", {}) as Dictionary).duplicate()
	d.bubble = "love"
	d.pose = "egg" if bool(p.get("egg", false)) or not bool(d.get("hatched", false)) else "bounce"
	var body := FollowerBody.new("personal", "personal", Vector2(520, 210))
	body.wanders = false
	_scene.add_child(body)
	body.apply(d, f, "fervent")
	body.scale = Vector2(3, 3)
	FollowerArt.play("bleat" if not body.egg else "crack", 1.2, -4.0)
	var tw := body.create_tween()
	tw.tween_property(body, "position:x", 262.0, seconds * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if body.egg:
		tw.parallel().tween_property(body, "rotation", -TAU * 2.0, seconds * 0.45)
	tw.tween_callback(func() -> void:
		body.rotation = 0.0
		body.pet(true)
		FlockFx.specks(_scene, Vector2(232, 150), FollowerArt.SPECK_HEART, 5, 18.0)
		var hug := leader.create_tween()
		hug.tween_property(leader, "scale", Vector2(3.4, 2.7), 0.08)
		hug.tween_property(leader, "scale", Vector2(3, 3), 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT))


## A debt boss took a hit from a payment the bank made: motes, a flash, the number.
func _beat_gate_hit(p: Dictionary, seconds: float) -> void:
	var boss := _sprite(FollowerArt.region(SLIME, Rect2(0, 0, 62, 52)), Vector2(250, 214), 3.0, Vector2(0, -26))
	_animate(boss, func(t: float) -> void: boss.texture = FollowerArt.region(SLIME, Rect2((int(t * 8.0) % 5) * 62, 0, 62, 52)))
	var amount := int(p.get("amount_cents", 0))
	_later(seconds * 0.15, func() -> void:
		FlockFx.motes(_scene, Vector2(40, 120), Vector2(250, 150), 18, 0.4))
	_later(seconds * 0.15 + 0.45, func() -> void:
		Sfx.play_path("res://art/packs/kenney-impact-sounds/Audio/impactPunch_heavy_000.ogg", 1.0, -4.0)
		if is_instance_valid(boss):
			boss.modulate = Color(3, 3, 3)
			boss.create_tween().tween_property(boss, "modulate", Color.WHITE, 0.25)
		if amount > 0:
			FlockFx.float_text(_scene, Vector2(250, 96), "-" + Money.fmt(amount), Palette.CREAM, 22))


## The village built something while you were out.
func _beat_build(_p: Dictionary, seconds: float) -> void:
	var house := Node2D.new()
	house.position = Vector2(240, 220)
	_scene.add_child(house)
	var cells := [[Vector2i(4, 4), Vector2i(6, 4)], [Vector2i(4, 5), Vector2i(6, 5)], [Vector2i(0, 7), Vector2i(2, 7)]]
	for row in 3:
		for col in 2:
			var s := Sprite2D.new()
			var cell: Vector2i = cells[row][col]
			s.texture = FollowerArt.region(TOWN, Rect2(cell.x * 16, cell.y * 16, 16, 16))
			s.position = Vector2((col - 0.5) * 48, (row - 2.5) * 48)
			s.scale = Vector2(3, 3)
			s.modulate.a = 0.0
			house.add_child(s)
			var tw := s.create_tween()
			tw.tween_interval((2 - row) * seconds * 0.15 + col * 0.05)
			tw.tween_property(s, "modulate:a", 1.0, 0.05)
			tw.tween_callback(func() -> void:
				FollowerArt.play("pop", 0.7 + row * 0.1, -8.0)
				FlockFx.puff(_scene, house.position + s.position + Vector2(0, 24), Palette.MUTED))


func _beat_other(kind: String, p: Dictionary, _seconds: float) -> void:
	var star := _sprite(FollowerArt.speck(FollowerArt.SPECK_STAR), Vector2(240, 150), 6.0, Vector2.ZERO)
	star.create_tween().set_loops().tween_property(star, "rotation", TAU, 2.0)
	FollowerArt.play("pop", 1.0, -8.0)
	var text := str(p.get("text", ""))
	if text != "":
		var l := FollowerArt.label(text, FollowerArt.FONT_TINY, 16, Palette.CREAM)
		l.size = Vector2(400, 20)
		l.position = Vector2(40, 190)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_scene.add_child(l)
	elif p.has("amount_cents"):
		FlockFx.float_text(_scene, Vector2(240, 120), Money.fmt(int(p.amount_cents)), Palette.CREAM, 20)


# --- helpers ----------------------------------------------------------------------------------------


func _sprite(tex: Texture2D, at: Vector2, s: float, offset: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.position = at
	sp.offset = offset
	sp.scale = Vector2(s, s)
	_scene.add_child(sp)
	FlockFx.pop_in(sp, Vector2(s, s), 0.25)
	return sp


func _animate(node: Node, step: Callable) -> void:
	var tw := node.create_tween()
	tw.tween_method(step, 0.0, 30.0, 30.0)


func _later(seconds: float, fn: Callable) -> void:
	await get_tree().create_timer(seconds).timeout
	if is_inside_tree():
		fn.call()


## Kneeling cultists around a point, in a pose.
func _kneelers(at: Vector2, pose_name: String) -> void:
	var f: Dictionary = Game.state.get("followers", {})
	for i in 6:
		var a := lerpf(PI * 0.1, PI * 0.9, i / 5.0)
		var b := FollowerBody.new("cultist", "k%d" % i, at + Vector2(cos(a) * 170.0, -sin(a) * 10.0 + 26.0))
		b.index = i
		b.wanders = false
		_scene.add_child(b)
		b.apply({"pose": pose_name, "bubble": "crying" if pose_name == "veiled" and i % 2 == 0 else "", "veiled": pose_name == "veiled"}, f, "fervent" if pose_name == "chant" else "mourning")
		b.scale = Vector2(2, 2)
		b.bubble.scale = Vector2(0.55, 0.55)
		b.bubble_now()
		if pose_name == "chant":
			b.chant(4.0)


func _rain() -> void:
	var r := CPUParticles2D.new()
	r.amount = 70
	r.lifetime = 1.0
	r.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	r.emission_rect_extents = Vector2(260, 4)
	r.position = Vector2(240, -6)
	r.direction = Vector2(0.15, 1)
	r.spread = 3.0
	r.gravity = Vector2.ZERO
	r.initial_velocity_min = 260.0
	r.initial_velocity_max = 320.0
	r.scale_amount_min = 1.0
	r.scale_amount_max = 2.0
	r.color = Color(0.7, 0.72, 0.8, 0.45)
	_scene.add_child(r)
