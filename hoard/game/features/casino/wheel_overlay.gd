class_name WheelOverlay
extends MachineOverlay
## The prize wheel: twelve wedges painted in their rarity colors, read from /state. A won
## wedge comes off and stays dark until the wheel resets (when gold is won or the last
## wedge goes). Tap the wheel or its lever: the price lands first, then the wheel is
## yanked, flies, and slows unevenly, catching on each peg (tick, hang, tick) with the
## flapper jumping, and stops on the wedge the house drew (wedge_index). That wedge pops
## off, and the cosmetic comes out of it.

const C := Vector2(240, 124)  # the hub
const R_OUT := 86.0
const R_IN := 18.0
const STEP := TAU / 12.0
const DUD_HALF := 0.07  # half a dud sliver's width at the rim, radians
const T_WIND := 0.25
const T_SPIN := 5.4
const TURNS := 5
const SLOW := 2.4  # rad/s: slower than this, the wheel catches on each peg
const SKIP_AFTER := 1.2
const LEVER := Rect2(344, 92, 24, 84)

const SND_TICK := A + "kenney-interface-sounds/Audio/tick_002.ogg"
const SND_PEG := A + "kenney-interface-sounds/Audio/tick_004.ogg"
const SND_LEVER := A + "kenney-rpg-audio/Audio/metalLatch.ogg"
const SND_YANK := A + "kenney-rpg-audio/Audio/creak1.ogg"
const SND_POP := A + "kenney-impact-sounds/Audio/impactGlass_heavy_000.ogg"
const SND_RESET := A + "wobbleboxx-levelup-coin/Rise03.ogg"
const SND_HEART := A + "bart-heartbeat-sounds/heartbeat_fast_0.ogg"
const SND_SLIP := A + "wobbleboxx-levelup-coin/Downer01.ogg"

## The wedges as drawn: [{tier, taken}], the wheel's turn (radians, clockwise), and where
## the pointer came to rest, for the tour.
var wedges: Array = []
var angle := 0.0
var landed_index := -1
var near_miss := ""
var spin_seconds := 0.0
var landed_dud := -1
var skipped := false
## How often an honest near miss is staged when a better wedge sits next door (a tuning knob).
var near_chance := 0.65

var _face: Face
var _flapper: Flapper
var _lever: Lever
var _ticks: Array[AudioStreamPlayer] = []
var _tick_i := 0
var _last_tick := -1.0
var _heart := AudioStreamPlayer.new()


func _build_machine() -> void:
	for w: Dictionary in Game.state.get("casino", {}).get("wheel", {}).get("wedges", []):
		wedges.append({"tier": str(w.get("tier", "common")), "taken": bool(w.get("taken", false))})
	var stand := Stand.new()
	stage.add_child(stand)
	_lever = Lever.new()
	_lever.position = LEVER.position
	stage.add_child(_lever)
	_face = Face.new()
	_face.wedges = wedges
	_face.position = C - Vector2(R_OUT + 12, R_OUT + 12)
	_face.size = Vector2(R_OUT + 12, R_OUT + 12) * 2.0
	_face.pivot_offset = _face.size / 2.0
	stage.add_child(_face)
	_flapper = Flapper.new()
	_flapper.position = Vector2(C.x, C.y - R_OUT - 15)
	stage.add_child(_flapper)
	for i in 4:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_ticks.append(p)
	_heart.stream = looped(SND_HEART)
	_heart.volume_db = -6.0
	add_child(_heart)


func _dealer_line() -> String:
	var dealer: Dictionary = Game.state.get("casino", {}).get("dealer", {})
	var before: Dictionary = dealer.get("before", {}).get("wheel", {})
	return str(before.get(dest, dealer.get("line", "")))


func _price_cents() -> int:
	return int(Game.state.get("casino", {}).get("wheel", {}).get("price_cents", 500))


func _machine_rect() -> Rect2:
	return Rect2(C.x - R_OUT - 14, 18, (R_OUT + 14) * 2 + 40, 214)


## The wheel and the lever, for taps in the tour.
func wheel_control() -> Control:
	return _face


func _pot_key() -> String:
	return "wheel"


func lever_control() -> Control:
	return _lever


func _machine_input(event: InputEvent, at: Vector2) -> bool:
	if moment != "choose":
		return false
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return false
	if at.distance_to(C) <= R_OUT + 12 or LEVER.grow(6).has_point(at):
		_pull()
		return true
	return false


func _pull() -> void:
	moment = "pull"
	_lever.pull()
	Sfx.play_path(SND_LEVER, 1.0, -4.0)
	var data := await pay("/casino/wheel", {}, Vector2(C.x, 222))
	if data.is_empty():
		return
	await play(data)


## Spin to a result and reveal it. _pull calls this once the money has landed; it never
## moves money itself.
func play(data: Dictionary) -> void:
	result = data
	phase = Phase.BUSY
	hush()
	if not bool(data.get("hit", true)):
		# A blank: the wheel stops dead on a dud sliver between two wedges, and the dollars
		# drop into the jar.
		var d := int(data.get("dud_index", 0))
		await _spin_to(d, 0.0)
		await _dud(d)
		await pot_blank(Vector2(C.x, C.y - R_OUT + 28))
		finish()
		return
	var k := int(data.get("wedge_index", 0))
	await _spin_to(k)
	await _pop(k)
	await pot_hit()
	await reveal(data.get("item", {}), Vector2(C.x, C.y - R_OUT + 28))
	if bool(data.get("reset", false)):
		await _relight(data.get("wedges", []))
	finish()


# --- the spin ------------------------------------------------------------------------------

static func _index_at(a: float) -> int:
	return int(floorf(fposmod(-a, TAU) / STEP)) % 12


static func _rank(tier: String) -> int:
	return MachineOverlay.TIERS.find(tier)


## Where in wedge k to stop (0..1 across it, in the order the pointer meets it), staging an
## honest near miss when a better wedge that is really on the wheel sits next door.
func _landing(k: int) -> float:
	near_miss = ""
	var won := _rank(str(wedges[k].tier))
	var after: Dictionary = wedges[(k + 11) % 12]  # the pointer would meet it next
	var before: Dictionary = wedges[(k + 1) % 12]  # the pointer just left it
	if randf() < near_chance:
		if not bool(after.taken) and _rank(str(after.tier)) > won:
			near_miss = "short"
			return randf_range(0.06, 0.14)
		if not bool(before.taken) and _rank(str(before.tier)) > won:
			near_miss = "fell"
			return randf_range(0.86, 0.93)
	return randf_range(0.3, 0.7)


func _spin_to(k: int, fixed := -1.0) -> void:
	moment = "spin"
	var f := _landing(k)
	if fixed >= 0.0:
		near_miss = ""  # a dud sliver sits exactly on the boundary at the start of wedge k
		f = fixed
	var a0 := angle
	var target := -(k + f) * STEP
	var travel := fposmod(target - a0, TAU) + TURNS * TAU
	var wind := 0.14
	var total := T_WIND + T_SPIN
	# The boundary the near miss hangs on: the peg between wedge k and its better neighbor.
	var near_p := float(k) if near_miss == "short" else float(k + 1)
	var near_left := 0.5
	Sfx.play_path(SND_YANK, 1.3, -6.0)
	Sfx.play_path(SND_WHOOSH, 0.8, -8.0)
	var s := 0.0
	var real := 0.0
	var last := _index_at(angle)
	var tense := false
	_tapped = false
	while s < total and is_inside_tree():
		await get_tree().process_frame
		var dt := get_process_delta_time()
		real += dt
		var v := _speed(s, travel, wind)
		var p := fposmod(-angle, TAU) / STEP
		var fr := p - floorf(p)
		var rate := 1.0
		if v < SLOW and minf(fr, 1.0 - fr) * STEP < 0.07:
			rate = 0.3
		if near_miss != "" and v < SLOW * 1.2 and near_left > 0.0:
			var dp := absf(fposmod(p - near_p + 6.0, 12.0) - 6.0) * STEP
			if dp < 0.12:
				rate = 0.12
				near_left -= dt
				moment = "near_miss"
				if not tense:
					tense = true
					_heart.play()
		# A tap after the first second hurries the flight; the last two seconds always play.
		if _tapped and real > SKIP_AFTER:
			skipped = true
		_tapped = false
		if skipped and s < total - 2.0:
			rate = 4.0
		s = minf(total, s + dt * rate)
		angle = _angle(a0, s, travel, wind)
		_face.rotation = angle
		_face.speed = v
		var idx := _index_at(angle)
		if idx != last:
			last = idx
			_tick(v)
	_heart.stop()
	if near_miss == "fell":
		Sfx.play_path(SND_SLIP, 1.0, -8.0)
	spin_seconds = real
	landed_index = _index_at(angle)
	_face.speed = 0.0


## The wheel's turn at clock s: a short yank back, then a flick that bleeds speed to nothing.
func _angle(a0: float, s: float, travel: float, wind: float) -> float:
	if s < T_WIND:
		return a0 - wind * sin(PI / 2.0 * s / T_WIND)
	var u := clampf((s - T_WIND) / T_SPIN, 0.0, 1.0)
	return a0 - wind + (travel + wind) * (1.0 - pow(1.0 - u, 3.2))


func _speed(s: float, travel: float, wind: float) -> float:
	if s < T_WIND:
		return 0.0
	var u := clampf((s - T_WIND) / T_SPIN, 0.0, 1.0)
	return (travel + wind) * 3.2 * pow(1.0 - u, 2.2) / T_SPIN


## A peg passes the flapper: a click on its own player, never closer than 30 ms, pitched up
## as the wheel slows; slow pegs click heavier.
func _tick(v: float) -> void:
	_flapper.kick(clampf(v / 6.0, 0.35, 1.0))
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_tick < 0.03:
		return
	_last_tick = now
	var slowness := clampf(1.0 - v / 14.0, 0.0, 1.0)
	var p := _ticks[_tick_i % _ticks.size()]
	_tick_i += 1
	p.stream = res(SND_PEG if v < SLOW else SND_TICK) as AudioStream
	p.pitch_scale = lerpf(1.25, 0.9, slowness) + randf_range(-0.03, 0.03)
	p.volume_db = lerpf(-14.0, -3.0, slowness)
	p.play()


## The wheel stopped on dud sliver d: it goes dull, a low thud, nothing comes off.
func _dud(d: int) -> void:
	moment = "dud"
	landed_dud = d
	_face.dud_hot = d
	Sfx.play_path(SND_SLIP, 0.8, -6.0)
	shake(_room, 1.0, 0.12)
	await get_tree().create_timer(0.6).timeout
	_face.dud_hot = -1


## The won wedge flashes and comes off the wheel.
func _pop(k: int) -> void:
	moment = "pop"
	var tier := str(wedges[k].tier)
	var color := CasinoFx.rarity_color(tier)
	_face.hot = k
	var top := Vector2(C.x, C.y - R_OUT + 30)
	Sfx.play_path(SND_POP, 1.0 + _rank(tier) * 0.1, -4.0)
	var flare := rarity_glow(_fx, top, tier, 30.0 + 8.0 * _rank(tier))
	ring(_fx, top, color, 26.0, 0.3)
	if tier != "common":
		CasinoFx.flash(self, color, 0.2, 0.2)
	await CasinoFx.hit_stop(get_tree(), 0.06)
	await get_tree().create_timer(0.35).timeout
	flare.create_tween().tween_property(flare, "modulate:a", 0.0, 0.4).finished.connect(flare.queue_free)
	var shard := Shard.new()
	shard.tier = tier
	shard.position = C
	# The shard is drawn pointing straight up; turn it to where wedge k sits now.
	shard.rotation = angle + (k + 0.5) * STEP
	stage.add_child(shard)
	wedges[k].taken = true
	_face.hot = -1
	_face.queue_redraw()
	ring(_fx, Vector2(C.x, C.y - R_OUT + 30), color, 34.0, 0.35)
	var tw := shard.create_tween().set_parallel(true)
	tw.tween_property(shard, "position", C + Vector2(0, -22), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(shard, "scale", Vector2(1.25, 1.25), 0.35)
	tw.chain().tween_property(shard, "modulate:a", 0.0, 0.2)
	tw.chain().tween_callback(shard.queue_free)
	await get_tree().create_timer(0.3).timeout


## Gold came out, or the last wedge went: every wedge lights back up around the wheel.
func _relight(fresh: Array) -> void:
	moment = "reset"
	for i in wedges.size():
		var w: Dictionary = fresh[i] if i < fresh.size() else {}
		wedges[i].taken = bool(w.get("taken", false))
		_face.queue_redraw()
		_tick(1.0)
		await get_tree().create_timer(0.05).timeout
	Sfx.play_path(SND_RESET, 1.0, -4.0)
	ring(_fx, C, Palette.CREAM, R_OUT + 20.0, 0.5)
	await get_tree().create_timer(0.5).timeout


# --- drawn pieces ------------------------------------------------------------------------

## A wedge between two angles, darkest at the hub, the rarity color at the rim.
static func wedge_poly(ci: CanvasItem, c: Vector2, a0: float, a1: float, tier: String, taken: bool, hot := 0.0) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var inner: Color
	var outer: Color
	if taken:
		inner = Color("120c18")
		outer = Color("1d1424")
	elif tier == "common":
		# Grey wedges stay dull so the colors that matter light up.
		inner = Color("26252b")
		outer = MachineOverlay.SHADOW.common.lerp(CasinoFx.rarity_color(tier), 0.3 + 0.5 * hot)
	else:
		inner = MachineOverlay.SHADOW.get(tier, Color.BLACK)
		outer = CasinoFx.rarity_color(tier).lerp(MachineOverlay.GLOW.get(tier, Color.WHITE), hot)
	for j in 7:
		var a := lerpf(a0, a1, j / 6.0)
		pts.append(c + Vector2(cos(a), sin(a)) * WheelOverlay.R_IN)
		cols.append(inner)
	for j in 7:
		var a := lerpf(a1, a0, j / 6.0)
		pts.append(c + Vector2(cos(a), sin(a)) * WheelOverlay.R_OUT)
		cols.append(outer)
	ci.draw_polygon(pts, cols)


class Face:
	extends Control
	## The wheel itself; it turns as a whole (rotation is the wheel's angle).
	var wedges: Array = []
	var hot := -1
	var dud_hot := -1
	var speed := 0.0
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var light := MachineOverlay.res(MachineOverlay.LIGHT) as Texture2D
		var R := WheelOverlay.R_OUT
		draw_circle(c, R + 9.0, MachineOverlay.BODY_DARK)
		draw_arc(c, R + 6.0, 0.0, TAU, 64, MachineOverlay.TRIM, 5.0)
		draw_arc(c, R + 8.5, 0.0, TAU, 64, MachineOverlay.TRIM_LIT, 1.0)
		for i in wedges.size():
			var a0 := -PI / 2.0 + i * WheelOverlay.STEP
			var a1 := a0 + WheelOverlay.STEP
			var w: Dictionary = wedges[i]
			var tier := str(w.tier)
			var taken := bool(w.taken)
			var h := 0.0
			if i == hot:
				h = 0.5 + 0.5 * sin(_t * 30.0)
			WheelOverlay.wedge_poly(self, c, a0, a1, tier, taken, h)
			var mid := (a0 + a1) / 2.0
			if not taken and tier != "common":
				var gp := c + Vector2(cos(mid), sin(mid)) * 58.0
				draw_texture_rect(light, Rect2(gp - Vector2(22, 22), Vector2(44, 44)), false, Color(CasinoFx.rarity_color(tier), 0.35 + 0.15 * sin(_t * 3.0 + i)))
		for i in wedges.size():
			var a0 := -PI / 2.0 + i * WheelOverlay.STEP
			draw_line(c + Vector2(cos(a0), sin(a0)) * WheelOverlay.R_IN, c + Vector2(cos(a0), sin(a0)) * R, Palette.NIGHT, 1.0)
		# The marks, standing on the rim, pointing out.
		for i in wedges.size():
			var mid := -PI / 2.0 + (i + 0.5) * WheelOverlay.STEP
			var w: Dictionary = wedges[i]
			var tier := str(w.tier)
			var taken := bool(w.taken)
			var frame := 0 if taken else int(_t * 10.0 + i * 7) % 24
			frame = mini(frame, MachineOverlay.symbol_frames(tier) - 1)
			# Flying: each mark drags two fading copies of itself behind it.
			if speed > 4.0 and not taken:
				for g: int in [2, 1]:
					var back := mid - speed * 0.012 * g
					draw_set_transform(c + Vector2(cos(back), sin(back)) * 60.0, back + PI / 2.0, Vector2.ONE)
					MachineOverlay.draw_symbol(self, Vector2.ZERO, tier, frame, 0.8, Color(1, 1, 1, 0.22 * (3 - g)))
			draw_set_transform(c + Vector2(cos(mid), sin(mid)) * 60.0, mid + PI / 2.0, Vector2.ONE)
			MachineOverlay.draw_symbol(self, Vector2.ZERO, tier, frame, 0.8, Color(0.12, 0.1, 0.15, 0.9) if taken else Color.WHITE)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# The dud slivers: a thin dead notch on every boundary, where a blank lands.
		for i in wedges.size():
			var b := -PI / 2.0 + i * WheelOverlay.STEP
			var pts := PackedVector2Array()
			for a: float in [b - WheelOverlay.DUD_HALF, b + WheelOverlay.DUD_HALF]:
				pts.append(c + Vector2(cos(a), sin(a)) * R)
			pts.append(c + Vector2(cos(b), sin(b)) * (WheelOverlay.R_IN + 22.0))
			var dead := Color("0b080e")
			if i == dud_hot:
				dead = dead.lerp(Color("4a3a52"), 0.5 + 0.5 * sin(_t * 20.0))
			draw_colored_polygon(pts, dead)
			draw_line(pts[0], pts[2], Color(MachineOverlay.TRIM, 0.5), 1.0)
			draw_line(pts[1], pts[2], Color(MachineOverlay.TRIM, 0.5), 1.0)
		# Pegs at the wedge edges, and bulbs that chase around the rim.
		for i in wedges.size():
			var a0 := -PI / 2.0 + i * WheelOverlay.STEP
			var pp := c + Vector2(cos(a0), sin(a0)) * (R + 2.0)
			draw_circle(pp, 2.5, MachineOverlay.TRIM_LIT)
			draw_rect(Rect2(pp - Vector2(1, 2), Vector2(1, 1)), Palette.CREAM)
		var chase := int(_t * (6.0 + speed * 2.0))
		for i in 36:
			var a := TAU * i / 36.0
			var bp := c + Vector2(cos(a), sin(a)) * (R + 6.0)
			var lit := (i + chase) % 4 == 0
			draw_rect(Rect2(bp - Vector2(1, 1), Vector2(2, 2)), Color(Palette.CREAM, 0.95 if lit else 0.25))
		# The hub: an eye that stays upright while the wheel turns, looking up at the flapper.
		draw_circle(c, WheelOverlay.R_IN + 1.0, MachineOverlay.TRIM)
		draw_circle(c, WheelOverlay.R_IN - 1.0, MachineOverlay.BODY)
		draw_set_transform(c, -rotation, Vector2.ONE)
		c = Vector2.ZERO
		var look := Vector2(sin(_t * 0.7) * 0.4, -1.0).normalized()
		var lid := PackedVector2Array()
		for j in 18:
			var a := TAU * j / 18.0
			lid.append(c + Vector2(cos(a) * 12.0, sin(a) * 8.0 * (0.4 + 0.6 * absf(sin(a)))))
		draw_colored_polygon(lid, Palette.CREAM)
		draw_circle(c + look * 3.0, 4.5, Color("3b2a47"))
		draw_circle(c + look * 3.5, 2.2, Palette.NIGHT)
		draw_rect(Rect2(c + look * 3.5 + Vector2(1, -2), Vector2(1, 1)), MachineOverlay.EYES)
		lid.append(lid[0])
		draw_polyline(lid, MachineOverlay.TRIM, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


class Flapper:
	extends Control
	## The bone flapper at the top. Pegs knock it aside; it springs back.
	var _a := 0.0
	var _v := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func kick(strength: float) -> void:
		_a = -0.55 * strength
		_v = 0.0

	func _process(delta: float) -> void:
		_v += (-_a * 320.0 - _v * 20.0) * delta
		_a += _v * delta
		queue_redraw()

	func _draw() -> void:
		var light := MachineOverlay.res(MachineOverlay.LIGHT) as Texture2D
		draw_texture_rect(light, Rect2(-14, -10, 28, 28), false, Color(Palette.CREAM, 0.15))
		draw_set_transform(Vector2.ZERO, _a, Vector2.ONE)
		var tip := PackedVector2Array([Vector2(-5, 0), Vector2(5, 0), Vector2(1, 17), Vector2(-1, 17)])
		draw_colored_polygon(tip, Palette.CREAM)
		draw_polyline(PackedVector2Array([tip[0], tip[1], tip[2], tip[3], tip[0]]), MachineOverlay.TRIM, 1.0)
		draw_line(Vector2(0, 3), Vector2(0, 14), Color(MachineOverlay.TRIM, 0.6), 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_circle(Vector2.ZERO, 3.0, MachineOverlay.TRIM_LIT)
		draw_circle(Vector2.ZERO, 1.0, MachineOverlay.BODY_DARK)


class Shard:
	extends Node2D
	## The won wedge, off the wheel.
	var tier := "common"

	func _draw() -> void:
		var half := WheelOverlay.STEP / 2.0
		WheelOverlay.wedge_poly(self, Vector2.ZERO, -PI / 2.0 - half, -PI / 2.0 + half, tier, false, 0.6)


class Stand:
	extends Control
	## The post and foot the wheel stands on, with the coin slot.
	func _init() -> void:
		size = Vector2(480, 270)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var cx := WheelOverlay.C.x
		var foot := PackedVector2Array([Vector2(cx - 22, 196), Vector2(cx + 22, 196), Vector2(cx + 46, 230), Vector2(cx - 46, 230)])
		draw_colored_polygon(foot, MachineOverlay.BODY)
		draw_polyline(PackedVector2Array([foot[0], foot[1], foot[2], foot[3], foot[0]]), MachineOverlay.TRIM, 1.0)
		draw_rect(Rect2(cx - 50, 229, 100, 3), MachineOverlay.TRIM)
		draw_rect(Rect2(cx - 9, 219, 18, 4), MachineOverlay.TRIM_LIT)
		draw_rect(Rect2(cx - 7, 220, 14, 2), Color.BLACK)


class Lever:
	extends Control
	## The pull handle at the side: a slot, a rod, a knob. It yanks down when pulled.
	var _down := 0.0:
		set(v):
			_down = v
			queue_redraw()

	func _init() -> void:
		size = WheelOverlay.LEVER.size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func pull() -> void:
		var tw := create_tween()
		tw.tween_property(self, "_down", 1.0, 0.12).set_ease(Tween.EASE_IN)
		tw.tween_interval(0.25)
		tw.tween_property(self, "_down", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		var light := MachineOverlay.res(MachineOverlay.LIGHT) as Texture2D
		draw_rect(Rect2(4, 16, 16, 60), MachineOverlay.BODY_DARK)
		draw_rect(Rect2(4, 16, 16, 60), MachineOverlay.TRIM, false, 1.0)
		draw_rect(Rect2(10, 20, 4, 52), Color.BLACK)
		var knob_y := lerpf(14.0, 62.0, _down)
		draw_line(Vector2(12, 46), Vector2(12, knob_y), MachineOverlay.TRIM_LIT, 3.0)
		draw_texture_rect(light, Rect2(0, knob_y - 12, 24, 24), false, Color(Palette.TEAL, 0.35))
		draw_circle(Vector2(12, knob_y), 7.0, Palette.TEAL.darkened(0.35))
		draw_circle(Vector2(12, knob_y), 5.5, Palette.TEAL)
		draw_rect(Rect2(9, knob_y - 4, 2, 2), Palette.CREAM)
