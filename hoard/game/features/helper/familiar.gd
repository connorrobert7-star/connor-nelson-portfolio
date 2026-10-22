class_name HelperFamiliar
extends Node2D
## Pip, the owner's familiar: a small wisp (Ninja Adventure's Spirit) that floats a step
## behind the wizard in every place, flickering, bobbing, hopping when he stops. Its glow
## brightens and breathes while it has something new to say. Tap it and it explains one
## idea in short bubbles, from the owner's own numbers (state.helper, all written by the
## backend). On a new save it walks the owner through the first five minutes: each beat
## starts when the wizard gets to its place (no forced walking), plays as bubbles, and lets
## go. Two quick taps on Pip skip the tour for good.
##
## It never holds the game: it is never busy, and the world keeps every tap that isn't on
## Pip, or on his bubble where nothing tappable lies under it.
## Any level hosts it: Level._ready() calls HelperFamiliar.join(self).

const SHEET := preload("res://art/packs/ninja-adventure/Actor/Monster/Spirit/SpriteSheet.png")
const CELL := 16
## The sheet's columns: facing down (front), up, left, right. Rows are the flicker frames;
## each cell's bottom row is a baked shadow, cut off (Pip floats; his shadow is drawn).
const FRONT := 0
const LEFT := 2
const RIGHT := 3
const BEHIND := 14.0  # px to the side of the wizard, away from where he faces
const FLOAT := 10.0  # px between the ground and the bottom of the body
const NEAR := 46.0  # px from a beat's place that starts it
const ARRIVE_WAIT := 1.4  # seconds in a place before its arrival beat
const DOUBLE_TAP := 0.45
const HIT := 9.0  # px around the body that count as tapping Pip
const LIGHT := Color("9fe6ff")
const VOICE := 1.45

## Beats and topics shown this session ("beat:case", "topic:fees"). The backend keeps the
## same list (POST /helper/seen); this covers the time until the next /state.
static var heard: Dictionary = {}

var level: Level
var leader: Leader
var bubble := HelperBubble.new()
## Every bubble shown, in order: {who, text, lines}. Tours read it.
var said: Array[Dictionary] = []
## The opening beat playing now, or "".
var beat := ""
## Each beat as it started: {beat, sign, at} (which sign, where the wizard stood). Tours read it.
var trace: Array[Dictionary] = []
var speaking := false

var _pivot := Node2D.new()  # at the bottom of the body; squashes and hops about it
var _body := Sprite2D.new()
var _glow := Sprite2D.new()
var _pool := Sprite2D.new()
var _shadow := _Shadow.new()
var _t := 0.0
var _since := 0.0
var _col := FRONT
var _hop := 0.0
var _hop_tween: Tween
var _was_walking := false
var _idle_t := 0.0
var _last_tap := -10.0
var _gen := 0  # bumps on a skip, so a cut-off line sequence stops where it is
var _vel := Vector2.ZERO
var _sign := ""  # the building whose sign started the sign beat


## A soft dark ellipse on the ground, smaller than the wizard's: Pip is high up.
class _Shadow extends Node2D:
	func _draw() -> void:
		PixelDraw.ellipse(self, Vector2(0, -1), 4, 1, Color(0.04, 0.02, 0.06, 0.32))


static func join(lv: Level) -> void:
	var f := HelperFamiliar.new()
	f.level = lv
	f.leader = lv.leader
	lv.props.add_child(f)


func _ready() -> void:
	position = _target()
	_pool.texture = _radial(true)
	_pool.material = _additive()
	_pool.scale = Vector2(1.0, 0.45) * (30.0 / 64.0)
	_pool.modulate = Color(LIGHT, 0.14)
	_pool.show_behind_parent = true
	add_child(_pool)
	_shadow.show_behind_parent = true
	add_child(_shadow)
	add_child(_pivot)
	_glow.texture = _radial(false)
	_glow.material = _additive()
	_glow.scale = Vector2.ONE * (34.0 / 64.0)
	_glow.position = Vector2(0, -7)
	_pivot.add_child(_glow)
	_body.texture = SHEET
	_body.region_enabled = true
	_body.region_rect = Rect2(0, 0, CELL, CELL - 1)
	_body.offset = Vector2(0, -(CELL - 1) / 2.0)
	_pivot.add_child(_body)
	bubble.voice = VOICE
	bubble.drop = FLOAT + 6.0
	add_child(bubble)
	# Arrive with the wizard: a little fade and a squash.
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.3)
	Juice.pop(_pivot, Vector2(0.7, 1.3), 0.5)


# --- following -----------------------------------------------------------------------

func _target() -> Vector2:
	var side := -1.0 if leader.body.flip_h else 1.0
	return leader.position + Vector2(-side * BEHIND, -1.0)


func _process(delta: float) -> void:
	_t += delta
	_since += delta
	var to := _target()
	if position.distance_to(to) > 140.0:
		position = to  # through a door or a jump: no long flight across the map
	var before := position
	position = position.lerp(to, 1.0 - exp(-5.0 * delta))
	_vel = _vel.lerp((position - before) / maxf(delta, 0.001), 1.0 - exp(-10.0 * delta))
	_animate(delta)
	_check_beats()


func _animate(delta: float) -> void:
	var walking := leader.walk_dir != Vector2.ZERO
	if _was_walking and not walking:
		get_tree().create_timer(0.12).timeout.connect(_hop_once.bind(4.0))
	_was_walking = walking
	if absf(_vel.x) > 10.0:
		_col = RIGHT if _vel.x > 0.0 else LEFT
	elif not walking and absf(_vel.x) < 3.0 and _col != FRONT and not _looking_at_vex():
		_col = FRONT
	# Now and then, standing about, a small hop and a look around.
	_idle_t = 0.0 if walking or speaking else _idle_t + delta
	if _idle_t > 5.5:
		_idle_t = -randf_range(0.0, 3.0)
		_hop_once(3.0)
		_col = [LEFT, RIGHT].pick_random()
	var row := int(_t * 6.0) % 4
	_body.region_rect = Rect2(_col * CELL, row * CELL, CELL, CELL - 1)
	var bob := sin(_t * 2.6) * 1.5
	_pivot.position = Vector2(0, roundf(-FLOAT + bob - _hop))
	# The glow breathes while there is something new to say; quiet otherwise.
	var news := _has_news() and not speaking
	var a := 0.34 + 0.16 * sin(_t * 3.2) if news else 0.2
	_glow.modulate = Color(LIGHT, a)
	_pool.modulate = Color(LIGHT, 0.1 + a * 0.25)
	_shadow.scale = Vector2.ONE * (1.0 - 0.15 * (bob + _hop) / 4.0)
	bubble.position = Vector2(0, roundf(-FLOAT - CELL - 1.0 + bob - _hop))


func _hop_once(height: float) -> void:
	if not is_inside_tree():
		return
	if _hop_tween:
		_hop_tween.kill()
	_hop_tween = create_tween()
	_hop_tween.tween_method(func(v: float) -> void: _hop = v, 0.0, height, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hop_tween.tween_method(func(v: float) -> void: _hop = v, height, 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_hop_tween.tween_callback(func() -> void: Juice.pop(_pivot, Vector2(1.2, 0.85), 0.3))


func _looking_at_vex() -> bool:
	return beat != "" and _vex() != null and _vex().get("speaking") == true


# --- what Pip knows -------------------------------------------------------------------

func helper() -> Dictionary:
	return Game.state.get("helper", {})


func _opening() -> Dictionary:
	return helper().get("opening", {})


func opening_active() -> bool:
	if not _opening().get("active", false):
		return false
	for b: Dictionary in _opening().get("beats", []):
		if not heard.has("beat:" + str(b.id)):
			return true
	return false


func _has_news() -> bool:
	if opening_active():
		return true
	for t: Dictionary in helper().get("queue", []):
		if not heard.has("topic:" + str(t.id)):
			return true
	return false


# --- the opening ----------------------------------------------------------------------

func _check_beats() -> void:
	if speaking or Game.busy or not opening_active() or level == null:
		return
	for b: Dictionary in _opening().get("beats", []):
		if heard.has("beat:" + str(b.id)) or str(b.place) != level.place_id:
			continue
		var lines := _beat_here(b)
		if not lines.is_empty():
			_play_beat(b, lines)
			return


## The beat's lines if the wizard is at its place now, else [].
func _beat_here(b: Dictionary) -> Array:
	var at := leader.position
	match str(b.near):
		"arrive":
			var vex := _vex()
			if _since >= ARRIVE_WAIT and not (vex != null and vex.get("speaking") == true):
				return b.lines
		"shelf", "book":
			var thing: Variant = level.get(str(b.near))
			if thing is Node2D and at.distance_to((thing as Node2D).position) < 64.0:
				return b.lines
		"sign":
			for id: String in (b.get("by_building", {}) as Dictionary):
				var p := sign_at(id)
				if p != Vector2.INF and at.distance_to(p) < NEAR:
					_sign = id
					return b.by_building[id]
		"arcade", "gate", "shrine":
			if level is Village and Village.PLOTS.has(str(b.near)):
				var door: Vector2i = Village.PLOTS[str(b.near)].door
				var reach := 72.0 if b.near == "gate" else NEAR
				if at.distance_to(level.feet_at(door)) < reach:
					return b.lines
	return []


## Where a building's sign stands in the village (the land's by the parcel it opens next).
static func sign_at(building_id: String) -> Vector2:
	for e: Dictionary in Game.state.get("buildings", {}).get("list", []):
		if str(e.id) != building_id or not (e.get("next") is Dictionary) or e.get("constructing", false):
			continue
		if building_id == "land":
			var look: Variant = e.next.get("look")
			var pid := str((look as Dictionary).get("parcel", "")) if look is Dictionary else ""
			if Village.PARCELS.has(pid) and (Village.PARCELS[pid] as Dictionary).has("stake"):
				return BuildingSite.land_sign_at(pid)
			return Vector2.INF
		if Village.BUILDING_PLOTS.has(building_id):
			return Village.building_plot(building_id).sign_at
	return Vector2.INF


func _play_beat(b: Dictionary, lines: Array) -> void:
	var items: Array = []
	# Pip says who he is first, wherever the owner first stops.
	if str(b.id) != "meet" and not heard.has("beat:meet"):
		for m: Dictionary in _opening().get("beats", []):
			if str(m.id) == "meet":
				items.append_array(m.lines)
				_mark("beat", "meet")
	items.append_array(lines)
	_mark("beat", str(b.id))
	if not opening_active():
		items.append_array(_opening().get("end", []))
	beat = str(b.id)
	trace.append({"beat": beat, "sign": _sign if beat == "sign" else "", "at": leader.position.round()})
	await speak(items)
	if is_inside_tree() and beat == str(b.id):
		beat = ""


func _mark(kind: String, id: String) -> void:
	heard["%s:%s" % [kind, id]] = true
	Game.call_api("POST", "/helper/seen", {kind: id})


func skip_opening() -> void:
	_gen += 1
	bubble.cut()
	for b: Dictionary in _opening().get("beats", []):
		heard["beat:" + str(b.id)] = true
	beat = ""
	Game.call_api("POST", "/helper/skip")
	Sfx.ui("close")
	await speak(_opening().get("skip", []))


# --- asking ---------------------------------------------------------------------------

## One tap with nothing on: the next idea in the queue, or the resting line.
func ask() -> void:
	for t: Dictionary in helper().get("queue", []):
		if heard.has("topic:" + str(t.id)):
			continue
		_mark("topic", str(t.id))
		await speak(t.lines)
		return
	await speak(helper().get("rest", []))


## Say lines in order (strings are Pip's; {who: "vex", text} goes to Vex if he's here).
func speak(items: Array) -> void:
	if items.is_empty():
		return
	var gen := _gen
	speaking = true
	for i in items.size():
		if gen != _gen or not is_inside_tree():
			return
		var it: Variant = items[i]
		var who := str(it.get("who", "pip")) if it is Dictionary else "pip"
		var text := str(it.get("text", "")) if it is Dictionary else str(it)
		if who == "vex" and _vex() != null:
			await _vex_says(text)
			continue
		_hop_once(2.0)
		# Started without waiting so the wrapped lines can be noted, then waited on.
		bubble.say(text, i < items.size() - 1)
		said.append({"who": who, "text": text, "lines": bubble.lines.size()})
		await bubble.done
	if gen == _gen:
		speaking = false


func _vex() -> Node2D:
	var v: Variant = level.get("vex") if level else null
	return v as Node2D if v is Node2D and (v as Node2D).has_method("say") else null


## Vex states it from behind his table; Pip turns to watch.
func _vex_says(text: String) -> void:
	var vex := _vex()
	var t := 0.0
	while vex.get("speaking") == true and t < 4.0 and is_inside_tree():
		await get_tree().process_frame
		t += get_process_delta_time()
	if not is_inside_tree():
		return
	_col = RIGHT if vex.global_position.x > global_position.x else LEFT
	said.append({"who": "vex", "text": text, "lines": 1})
	await vex.call("say", text, 2.2)


# --- taps -----------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if Game.busy or level == null or not Level._is_tap(event):
		return
	var local := level.make_input_local(event)
	var p: Vector2 = (local as InputEventMouseButton).position if local is InputEventMouseButton else (local as InputEventScreenTouch).position
	if p.distance_to(global_position + _pivot.position + Vector2(0, -7)) < HIT:
		get_viewport().set_input_as_handled()
		_tapped_me()
		return
	if bubble.showing() and bubble.hit_rect().has_point(p):
		bubble.advance()
		Sfx.ui("tap", 1.3)
		if not _world_wants(p):
			get_viewport().set_input_as_handled()
		return
	# Walking on: a line that has been up a while lets go.
	if bubble.showing() and bubble.shown_for > 1.2:
		bubble.advance()


func _tapped_me() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var twice := now - _last_tap < DOUBLE_TAP
	_last_tap = now
	Juice.pop(_pivot, Vector2(1.3, 0.75), 0.35)
	Sfx.ui("select", 1.4)
	if twice and (opening_active() or beat != ""):
		skip_opening()
		return
	if bubble.showing():
		bubble.advance()
		return
	if speaking:
		return
	if opening_active():
		# Wait a moment: a second tap means skip the tour, not ask.
		await get_tree().create_timer(DOUBLE_TAP).timeout
		if not is_inside_tree() or _last_tap != now or speaking:
			return
	ask()


## Something small in the world answers this point (a machine, a doorway, a villager): the
## tap that moved Pip's line on still goes to it. A building's whole facade doesn't count,
## or a tap on a line over a house would walk the wizard inside.
func _world_wants(p: Vector2) -> bool:
	for it: Dictionary in level._interactables:
		if p.distance_to(it.pos) < Level.TAP_RADIUS:
			return true
	if not level._door_at(p).is_empty():
		return true
	var spots: Variant = level.get("_hotspots")
	if spots is Array:
		for h: Variant in spots:
			if h is Dictionary and (h as Dictionary).get("rect") is Rect2 and (h.rect as Rect2).has_point(p):
				return true
	return false


# --- light ----------------------------------------------------------------------------

static func _radial(pool: bool) -> GradientTexture2D:
	var g := Gradient.new()
	if pool:
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	else:
		g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


static func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m
