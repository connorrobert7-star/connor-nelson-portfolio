class_name BuildingSite
extends Node2D
## One building's site in the village (docs/BUILDINGS.md, Godot). Nothing here is text: a
## signpost with one lamp per requirement of the next tier and its painted number (lit when it
## held at the last check, blinking when it holds now, dark when not), a coin plate when the
## tier is ready (tap the sign or the building to build), scaffolding that rises with progress
## and tally marks for days left, a dust puff when a tier is finished, and a flagpole that
## carries the target banner with its streak pennants. The land's site is its sign by the next
## gated parcel's rope line. Positioned at the map origin; y-sorted with the props.

const T := 16
const WOOD := Color("8a5a2b")
const WOOD_LIGHT := Color("c48a4c")
const WOOD_DARK := Color("4a2e18")
const LAMP_DARK := Color("3a3040")
const DISCOUNT := Color("8cf5ff")
const KIND := {
	"savings_cents": Color("7fe08a"), "house_fund_cents": Color("6fc3ff"),
	"emergency_cents": Color("ff6b6b"), "brokerage_cents": Color("c08cff"),
	"deposit_streak_weeks": Color("ff8a3d"), "land": Color("e8d6a0"),
}
const HAMMER := "kenney-impact-sounds/Audio/impactWood_medium_00%d.ogg"
const KNOCK := "kenney-impact-sounds/Audio/impactWood_light_00%d.ogg"

var building_id := ""
var plot: Dictionary = {}  # Village.building_plot(id); empty for the land
var village: Level
var entry: Dictionary = {}

var _vis := Node2D.new()
var _sign: Node2D
var _flag: Node2D
var _land_pid := ""
var _hammer := 0.5
var _hammer_at := Vector2.ZERO
var _seen_sent := -1
var _busy := false
var _painted := {}  # requirement key -> the number last painted (a change pops it)
var _look: Sprite2D
var _worker: Sprite2D


class Painter extends Node2D:
	var fn: Callable

	func _draw() -> void:
		fn.call(self)


func _ready() -> void:
	y_sort_enabled = true
	_vis.y_sort_enabled = true
	add_child(_vis)


## Where the land's sign stands for a gated parcel: just outside its rope, on the stake's row.
static func land_sign_at(parcel_id: String) -> Vector2:
	var spec: Dictionary = Village.PARCELS[parcel_id]
	var rect: Rect2i = spec.rect
	var stake: Vector2i = spec.stake
	return Vector2((rect.position.x - 1) * T + T / 2.0, (stake.y + 1) * T - 1)


## A requirement's number as painted on the sign.
static func req_text(r: Dictionary) -> String:
	var key := str(r.get("key", ""))
	var need: Variant = r.get("need", 0)
	if key.ends_with("_cents"):
		return VillageArt.dollars(need)
	if key == "deposit_streak_weeks":
		return "%dw" % int(need)
	if key == "land":
		return "L%d" % int(need)
	return str(int(need))


func apply(e: Dictionary, b: Dictionary) -> void:
	entry = e
	for c in _vis.get_children():
		c.queue_free()
	_sign = null
	_flag = null
	_look = null
	_worker = null
	_land_pid = ""
	if e.is_empty():
		return
	var next: Dictionary = e.next if e.get("next") is Dictionary else {}
	var building := bool(e.get("constructing", false))
	var days_left := _days_left(e, b, next)
	if building_id == "land":
		if next.is_empty():
			return
		var look: Variant = next.get("look")
		var pid := str((look as Dictionary).get("parcel", "")) if look is Dictionary else ""
		if not Village.PARCELS.has(pid) or not (Village.PARCELS[pid] as Dictionary).has("stake"):
			return
		_land_pid = pid
		var stake: Vector2i = Village.PARCELS[pid].stake
		if building:
			_scaffold(Rect2i(stake.x - 1, stake.y - 1, 3, 2), float(e.get("progress", 0.0)), days_left, 4)
		else:
			_signpost(land_sign_at(pid), next, true)
		_check_finished(e)
		return
	var look: Variant = e.get("look")
	if look is Dictionary and (look as Dictionary).has("sheet"):
		_draw_look(look, int(e.get("tier", 1)))
	if building_id != "house":
		_dress_tier(int(e.get("tier", 0)))
	if building:
		_scaffold(plot.rect, float(e.get("progress", 0.0)), days_left, 1)
	elif not next.is_empty():
		_signpost(plot.sign_at, next, false)
	if not next.is_empty() or bool(e.get("target", false)):
		_flagpole(e, b)
	_check_finished(e)


func _days_left(e: Dictionary, b: Dictionary, next: Dictionary) -> int:
	var crew: Variant = b.get("crew")
	if crew is Dictionary and str((crew as Dictionary).get("building_id", "")) == building_id:
		return maxi(0, int(crew.get("days", 0)) - int(crew.get("days_done", 0)))
	return ceili(float(next.get("days", 0)) * (1.0 - float(e.get("progress", 0.0))))


# --- the signpost --------------------------------------------------------------------------

func _signpost(at: Vector2, next: Dictionary, land: bool) -> void:
	var root := Node2D.new()
	root.position = at
	root.z_index = 4 if land else 1  # over the facades beside it (and the gated parcel's haze)
	_vis.add_child(root)
	_sign = root
	var reqs: Array = next.get("requires", [])
	var font := VillageArt.font(VillageArt.FONT_PRICE)
	var texts: Array[String] = []
	var widths: Array[float] = []
	for r: Dictionary in reqs:
		var s := req_text(r)
		texts.append(s)
		widths.append(maxf(10.0, font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x))
	# Lamp x positions, centered on the post, then kept on the map (and off the parcel's haze).
	var xs: Array[float] = []
	var x := 0.0
	for i in widths.size():
		if i > 0:
			x += (widths[i - 1] + widths[i]) / 2.0 + 3.0
		xs.append(x)
	# The row runs left from the post, away from the building (and off the parcel's haze).
	var shift := -x
	var left := at.x + shift - widths[0] / 2.0 if not widths.is_empty() else at.x
	if left < 4.0:
		shift += 4.0 - left
	var right := at.x + shift + x + (widths[-1] / 2.0 if not widths.is_empty() else 0.0)
	if right > Village.W * T - 4:
		shift -= right - (Village.W * T - 4)
	var x0 := floorf(shift - 6.0)
	var x1 := ceilf(shift + x + 6.0)
	var ready := bool(next.get("ready", false))
	# A post with an arm; a plank hangs from the arm on two chains, the numbers painted on it
	# and a lamp per requirement along its top edge.
	var p := Painter.new()
	p.fn = func(c: Node2D) -> void:
		var a0 := minf(x0, -2.0)
		var a1 := maxf(x1, 2.0)
		c.draw_rect(Rect2(-2, -37, 5, 37), VillageArt.INK)
		c.draw_rect(Rect2(-1, -36, 3, 36), WOOD)
		c.draw_rect(Rect2(-1, -36, 1, 36), WOOD_LIGHT)
		c.draw_rect(Rect2(a0 - 1, -38, a1 - a0 + 2, 4), VillageArt.INK)
		c.draw_rect(Rect2(a0, -37, a1 - a0, 2), WOOD)
		c.draw_rect(Rect2(a0, -37, a1 - a0, 1), WOOD_LIGHT)
		for cx: float in [x0 + 3.0, x1 - 4.0]:
			for cy in range(-35, -27):
				c.draw_rect(Rect2(cx, cy, 1, 1), Color("9a8f86") if cy % 2 == 0 else Color("5a5450"))
		c.draw_rect(Rect2(x0 - 1, -28, x1 - x0 + 2, 14), VillageArt.INK)
		c.draw_rect(Rect2(x0, -27, x1 - x0, 12), WOOD_DARK)
		c.draw_rect(Rect2(x0, -27, x1 - x0, 1), WOOD)
		c.draw_rect(Rect2(x0, -16, x1 - x0, 1), Color(0, 0, 0, 0.35))
		if ready:
			c.draw_rect(Rect2(-14, -12, 28, 12), VillageArt.INK)
			c.draw_rect(Rect2(-13, -11, 26, 10), WOOD_DARK)
			c.draw_rect(Rect2(-13, -11, 26, 1), WOOD_LIGHT)
	root.add_child(p)
	for i in reqs.size():
		var r: Dictionary = reqs[i]
		var lx := shift + xs[i]
		var col: Color = KIND.get(str(r.get("key", "")), VillageArt.BONE)
		var lamp := Painter.new()
		lamp.position = Vector2(lx, -27.5)
		var lit := bool(r.get("met_at_check", false))
		var now := bool(r.get("met_now", false))
		lamp.fn = func(c: Node2D) -> void:
			c.draw_circle(Vector2.ZERO, 2.5, VillageArt.INK)
			c.draw_circle(Vector2.ZERO, 1.8, col if (lit or now) else LAMP_DARK)
		root.add_child(lamp)
		if lit:
			VillageArt.glow(root, lamp.position, Color(col, 0.75), 16, 0.3)
		elif now:
			var tw := lamp.create_tween().set_loops()
			tw.tween_property(lamp, "modulate:a", 0.15, 0.35)
			tw.tween_property(lamp, "modulate:a", 1.0, 0.35)
		var discounted := bool(next.get("discounted", false)) and int(r.get("need", 0)) < int(r.get("base_need", 0))
		var color := DISCOUNT if discounted else (VillageArt.BONE if lit or now else Color(VillageArt.BONE, 0.6))
		var l := VillageArt.paint(root, texts[i], Vector2(lx, -20), color, 10)
		l.z_index = 3
		var key := str(r.get("key", i))
		if _painted.has(key) and _painted[key] != texts[i]:
			VillageArt.pop(l)
		_painted[key] = texts[i]
		if discounted:
			VillageArt.glow(root, Vector2(lx, -20), Color(DISCOUNT, 0.45), widths[i] + 14, 0.4)
	if ready:
		var stake := Node2D.new()
		stake.z_index = 3
		root.add_child(stake)
		var coin := Sprite2D.new()
		coin.texture = VillageArt.sheet("res://art/coin.png")
		coin.position = Vector2(-7, -6)
		stake.add_child(coin)
		var price := VillageArt.paint(stake, str(int(next.get("coins", 0))), Vector2(4, -7), VillageArt.BRASS, 10)
		price.size.x = 20
		price.position.x = -3
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		if bool(next.get("can_build", false)):
			VillageArt.glow(root, Vector2(0, -6), Color(VillageArt.BRASS, 0.6), 34, 0.5)
			VillageArt.bob(stake, 1.0, 1.0)


# --- the building's look, scaffolding and the finished beat ---------------------------------

func _draw_look(look: Dictionary, tier: int) -> void:
	var r: Array = look.get("rect", [0, 0, 16, 16])
	var t := VillageArt.tex(str(look.sheet), Rect2(r[0], r[1], r[2], r[3]))
	if t.atlas == null:
		return
	var s := VillageArt.sprite(_vis, t, plot.base)
	s.scale = Vector2.ONE * float(look.get("scale", 1.0))
	_look = s
	var w := float(r[2]) * s.scale.x
	var h := float(r[3]) * s.scale.y
	var light := Color(str(look.glow)) if look.has("glow") else VillageArt.WARM
	if look.has("glow"):
		var g := VillageArt.glow(s, Vector2(0, -float(r[3]) / 2.0), Color(light, 0.5), float(r[2]) * 1.6, 0.35)
		g.z_index = 1
	# A built look throws its light on the ground and out of its door.
	var pool := VillageArt.pool(_vis, plot.base + Vector2(0, -4), Color(light.lerp(VillageArt.WARM, 0.5), 0.16 + 0.05 * tier), w * (1.4 + 0.2 * tier), 0.1)
	pool.z_index = -1
	VillageArt.spill(_vis, plot.base + Vector2(0, -2), Color(light, 0.3), 12, 34, 26).z_index = -1


## Every tier changes the outline and the light: banners on poles at the corners from the
## second, lanterns either side of the door from the third, a beacon on top from the fourth.
func _dress_tier(tier: int) -> void:
	if tier < 2:
		return
	var w := float((plot.rect as Rect2i).size.x * T)
	var h := float((plot.rect as Rect2i).size.y * T)
	if is_instance_valid(_look):
		w = _look.texture.get_width() * _look.scale.x
		h = _look.texture.get_height() * _look.scale.y
	w = minf(w, float((plot.rect as Rect2i).size.x * T) + 16.0)
	for side in [-1, 1]:
		# Out at the plot's edges, clear of whatever stands in front of the facade.
		var foot: Vector2 = plot.base + Vector2(side * maxf(w / 2.0 + 2.0, (plot.rect as Rect2i).size.x * T / 2.0 + 4.0), 0)
		var pole := Painter.new()
		pole.position = foot
		pole.fn = func(c: Node2D) -> void:
			c.draw_rect(Rect2(-1, -h - 18, 3, h + 18), VillageArt.INK)
			c.draw_rect(Rect2(0, -h - 17, 1, h + 17), WOOD_LIGHT)
			c.draw_circle(Vector2(0.5, -h - 19), 1.5, VillageArt.BRASS)
		_vis.add_child(pole)
		var flag := VillageArt.anim(pole, VillageArt.frames(VillageArt.FLAG, Vector2i(16, 16), 4, 6), Vector2(8 if side > 0 else -7, -h - 10))
		flag.flip_h = side < 0
		if tier >= 3:
			var lantern := VillageArt.sprite(_vis, VillageArt.tiles(VillageArt.HOUSES, 29, 16), plot.base + Vector2(side * 14.0, 2))
			lantern.z_index = 1
			VillageArt.pool(lantern, Vector2(0, -8), Color(VillageArt.WARM, 0.7), 24, 0.2).z_index = 2
			VillageArt.pool(_vis, plot.base + Vector2(side * 14.0, 0), Color(VillageArt.WARM, 0.25), 70, 0.15).z_index = -1
	if tier >= 4:
		var beacon := VillageArt.pool(_vis, plot.base + Vector2(0, -h - 6), Color(VillageArt.BRASS, 0.6), 40, 0.25)
		beacon.z_index = 2
		VillageArt.embers(_vis, plot.base + Vector2(0, -h - 4), Color(VillageArt.BRASS, 0.8), 12, 5, 14).z_index = 2


func _scaffold(rect: Rect2i, progress: float, days_left: int, z: int) -> void:
	var w := float(rect.size.x * T)
	var full := float(rect.size.y * T + 8)
	var h := maxf(10.0, full * clampf(progress, 0.0, 1.0))
	var p := Painter.new()
	p.position = Vector2(rect.position.x * T + w / 2.0, rect.end.y * T)
	p.z_index = z
	p.fn = func(c: Node2D) -> void:
		var xs: Array[float] = []
		var px := -w / 2.0 + 2.0
		while px <= w / 2.0 - 2.0:
			xs.append(px)
			px += 16.0
		if xs[-1] < w / 2.0 - 4.0:
			xs.append(w / 2.0 - 2.0)
		var y := -4.0
		var prev := 0.0
		while y > -h:
			for i in xs.size() - 1:
				c.draw_line(Vector2(xs[i], prev), Vector2(xs[i + 1], y), WOOD_DARK, 1.0)
			c.draw_rect(Rect2(-w / 2.0, y - 1, w, 3), WOOD_LIGHT)
			c.draw_rect(Rect2(-w / 2.0, y + 2, w, 1), WOOD_DARK)
			prev = y
			y -= 11.0
		for x in xs:
			c.draw_rect(Rect2(x - 1, -h - 2, 2, h + 2), WOOD)
		c.draw_rect(Rect2(-w / 2.0 - 1, -h - 3, w + 2, 2), WOOD_LIGHT)
		# Days left in tally marks on a board at the foot.
		var n := mini(days_left, 10)
		if n > 0:
			var bw := 6.0 + n * 3.0 + (n / 5) * 2.0
			c.draw_rect(Rect2(-bw / 2.0, -12, bw, 10), WOOD_DARK)
			var tx := -bw / 2.0 + 3.0
			for i in n:
				if i % 5 == 4:
					c.draw_line(Vector2(tx - 13, -4), Vector2(tx, -10), VillageArt.BONE, 1.0)
					tx += 4.0
				else:
					c.draw_rect(Rect2(tx, -10, 1, 7), VillageArt.BONE)
					tx += 3.0
	_vis.add_child(p)
	_hammer_at = p.position + Vector2(0, -h)
	_sign = p
	# A worker on the top plank, hammering: every knock throws sparks.
	_worker = Sprite2D.new()
	_worker.texture = VillageArt.tex(VillageArt.HOODED_A, Rect2(16, 112, 16, 16))
	_worker.offset = Vector2(0, -8)
	_worker.position = p.position + Vector2(w / 4.0, -h - 2)
	_worker.z_index = z + 1
	_vis.add_child(_worker)
	_hammer_at = _worker.position + Vector2(-6, -6)


func _check_finished(e: Dictionary) -> void:
	var tier := int(e.get("tier", 0))
	if tier > int(e.get("seen_tier", tier)) and _seen_sent != tier and not bool(e.get("constructing", false)):
		_seen_sent = tier
		_finished()


func _finished() -> void:
	var at: Vector2 = land_sign_at(_land_pid) + Vector2(0, -12) if building_id == "land" else (plot.base as Vector2) + Vector2(0, -20)
	VillageArt.burst(self, at, VillageArt.BONE, 26, 80, 0.8, 120)
	VillageArt.burst(self, at + Vector2(0, 8), WOOD_LIGHT, 14, 50, 0.6, 160)
	Sfx.play("pop")
	Sfx.play("reveal_rare")
	VillageArt.sfx("kenney-impact-sounds/Audio/impactBell_heavy_00%d.ogg" % randi_range(0, 4), 0.8, -8.0)
	var base: Vector2 = (land_sign_at(_land_pid) if building_id == "land" else plot.base)
	_dust_ring(base)
	if is_instance_valid(_look):
		# The building rises a little and settles, and a bright sweep crosses its face.
		var y := _look.position.y
		var tw := _look.create_tween()
		tw.tween_property(_look, "position:y", y - 2.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_look, "position:y", y, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		var size := _look.texture.get_size() * _look.scale
		var sweep := Polygon2D.new()
		sweep.polygon = PackedVector2Array([Vector2(-6, 0), Vector2(2, 0), Vector2(10, -size.y), Vector2(2, -size.y)])
		sweep.color = Color(1, 0.95, 0.8, 0.55)
		sweep.material = VillageArt.additive()
		sweep.position = base + Vector2(-size.x / 2.0 - 8.0, 0)
		sweep.z_index = 2
		_vis.add_child(sweep)
		var go := sweep.create_tween()
		go.tween_property(sweep, "position:x", base.x + size.x / 2.0, 0.5).set_trans(Tween.TRANS_SINE)
		go.parallel().tween_property(sweep, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
		go.tween_callback(sweep.queue_free)
	if village is Village:
		(village as Village).shake(2.0, 0.2)
	await VillageArt.wait(self, 0.7)
	await Game.act("/buildings/seen", {"building_id": building_id})


func _process(delta: float) -> void:
	if not bool(entry.get("constructing", false)) or village == null:
		return
	_hammer -= delta
	if _hammer > 0.0:
		return
	_hammer = randf_range(0.55, 1.3)
	if village.leader.position.distance_to(_hammer_at) > 260.0:
		return
	VillageArt.sfx(HAMMER % randi_range(0, 4), randf_range(0.85, 1.15), -12.0)
	VillageArt.burst(_vis, _hammer_at + Vector2(randf_range(-3, 3), 0), WOOD_LIGHT, 3, 30, 0.4)
	VillageArt.burst(_vis, _hammer_at, Color(1.0, 0.85, 0.4), 5, 55, 0.25, 220)
	if is_instance_valid(_worker):
		VillageArt.squash(_worker, Vector2(1.2, 0.8), 0.16)
		_worker.flip_h = not _worker.flip_h if randf() < 0.2 else _worker.flip_h


## A ring of dust rolling out along the ground from a building's foot.
func _dust_ring(at: Vector2) -> void:
	var ring := Painter.new()
	ring.position = at
	ring.z_index = 3
	ring.fn = func(c: Node2D) -> void:
		for i in 20:
			var a := TAU * i / 20.0
			c.draw_rect(Rect2((Vector2(cos(a) * 12.0, sin(a) * 4.0)).round(), Vector2(2, 2)), Color(0.8, 0.72, 0.62, 0.8))
	add_child(ring)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector2(3.2, 3.2), 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
	tw.tween_callback(ring.queue_free)


# --- taps ----------------------------------------------------------------------------------

func tap_build() -> void:
	if _busy or entry.is_empty():
		return
	var next: Dictionary = entry.next if entry.get("next") is Dictionary else {}
	var n: Node2D = _sign if is_instance_valid(_sign) else null
	if bool(entry.get("constructing", false)):
		VillageArt.sfx(HAMMER % randi_range(0, 4), 1.0, -8.0)
		if n:
			VillageArt.squash(n, Vector2(1.1, 0.92))
		return
	if not bool(next.get("can_build", false)):
		_shake(n)
		return
	_busy = true
	if n:
		VillageArt.squash(n, Vector2(1.25, 0.75))
	Sfx.play("coin")
	var res: Array = await Game.act("/buildings/build", {"building_id": building_id})
	_busy = false
	if res[1] != "":
		_shake(_sign if is_instance_valid(_sign) else null)
	elif village is Village:
		(village as Village).shake(1.5, 0.15)


func tap_land(parcel_id: String) -> void:
	if parcel_id == _land_pid:
		await tap_build()


func tap_flag() -> void:
	if _busy or entry.is_empty():
		return
	if bool(entry.get("target", false)):
		if is_instance_valid(_flag):
			VillageArt.squash(_flag, Vector2(0.9, 1.1))
		return
	_busy = true
	Sfx.play("whoosh")
	var res: Array = await Game.act("/buildings/target", {"building_id": building_id})
	_busy = false
	if res[1] != "":
		_shake(_flag if is_instance_valid(_flag) else null)
	elif is_instance_valid(_flag):
		VillageArt.squash(_flag, Vector2(0.8, 1.2), 0.3)
		VillageArt.sfx(KNOCK % 0, 0.8, -8.0)


func _shake(n: Node2D) -> void:
	VillageArt.sfx(KNOCK % randi_range(0, 4), 0.7, -6.0)
	if n == null:
		return
	var x := n.position.x
	var tw := n.create_tween()
	for i in 4:
		tw.tween_property(n, "position:x", x + (2.0 if i % 2 == 0 else -2.0), 0.04)
	tw.tween_property(n, "position:x", x, 0.04)


# --- the flagpole --------------------------------------------------------------------------

func _flagpole(e: Dictionary, b: Dictionary) -> void:
	var root := Node2D.new()
	root.position = plot.flag_at
	_vis.add_child(root)
	_flag = root
	var t: Variant = b.get("target")
	var is_target := bool(e.get("target", false)) or (t is Dictionary and str((t as Dictionary).get("building_id", "")) == building_id)
	var pennants := 0
	var hot := false
	if is_target and t is Dictionary:
		pennants = mini(6, int((t as Dictionary).get("streak_weeks", 0)))
		hot = bool((t as Dictionary).get("discount_active", false))
	var p := Painter.new()
	p.fn = func(c: Node2D) -> void:
		c.draw_rect(Rect2(-1, -32, 2, 32), WOOD_LIGHT)
		c.draw_rect(Rect2(0, -32, 1, 32), WOOD)
		c.draw_circle(Vector2(0, -33), 1.5, VillageArt.BRASS)
		c.draw_rect(Rect2(-3, -2, 6, 2), WOOD_DARK)
		for i in pennants:
			var y := -14.0 + i * 2.0
			var col := VillageArt.BRASS if i % 2 == 0 else VillageArt.EMBER
			c.draw_colored_polygon(PackedVector2Array([Vector2(1, y - 1), Vector2(6, y), Vector2(1, y + 1)]), col)
	root.add_child(p)
	if is_target:
		var flag := VillageArt.anim(root, VillageArt.frames(VillageArt.FLAG, Vector2i(16, 16), 4, 6), Vector2(8, -25))
		flag.z_index = 1
		if hot:
			VillageArt.glow(root, Vector2(6, -24), Color(VillageArt.BRASS, 0.8), 44, 0.4)
