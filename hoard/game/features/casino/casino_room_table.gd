class_name CasinoRoomTable
extends Node2D
## The felt table under the lamp. On it: the belt as a peg rack by color (what's left of
## the 25 shells), the brass belt itself (loaded face-down, so the order stays hidden), and
## the slot with its little lamp, which is off when the week's extra or caps are gone.
## Position is the table's front edge, centered.

const Art := preload("res://features/casino/casino_room_art.gd")
const SIZE := Vector2(160, 56)
## The belt the backend loads (content/casino/machines.json): 18 grey, 6 blue, 1 purple.
const BELT := {"common": 18, "rare": 6, "epic": 1}
const RACK := Vector2(-72, -47)  # top-left of the peg rack, from the table's front edge
const BELT_AT := Vector2(-42, -19)  # left end of the brass belt
const SLOT := Vector2(58, -34)

const WOOD := Color("3a2218")
const WOOD_HI := Color("5c3626")
const FELT := Color("10201a")
const FELT_HI := Color("13231c")
const BRASS := Color("c99a4a")
const BRASS_HI := Color("f0cf8a")
const BRASS_LO := Color("6b4a22")
const HOLE := Color("07050a")

var left: Dictionary = {"common": 18, "rare": 6, "epic": 1}
var size := 25
var lamp_on := true
var t := 0.0
var _drops: Dictionary = {}  # peg key "tier:i" -> seconds since it dropped
var _flying: Array[Dictionary] = []  # shells flipping out: {x, t}
var _reload := -1.0  # seconds into a fresh belt being loaded, or -1
var _lamp_glow: Sprite2D
var _rack_glow: Sprite2D
var _first := true
var _noise: Array[Vector3] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 260:
		_noise.append(Vector3(rng.randf_range(-76, 76), rng.randf_range(-50, -9), rng.randf()))
	_lamp_glow = Art.glow(self, SLOT + Vector2(2, -9), Art.LAMP, 14, 0.5)
	_lamp_glow.z_index = 3
	_rack_glow = Art.glow(self, RACK + Vector2(12, 21), Palette.EPIC, 9, 0.0)
	_rack_glow.z_index = 3


func dress(casino: Dictionary) -> void:
	var belt: Dictionary = casino.get("belt", {})
	var now: Dictionary = belt.get("left", left)
	size = int(belt.get("size", 25))
	if not _first:
		for tier: String in BELT:
			var was := int(left.get(tier, 0))
			var is_now := int(now.get(tier, 0))
			for i in range(is_now, was):
				_drops["%s:%d" % [tier, i]] = 0.0
			if is_now < was:
				_flying.append({"x": _fired() , "t": 0.0})
				Art.play(Art.SND_PEG, 1.0 + 0.15 * ["common", "rare", "epic"].find(tier), -6.0)
	_first = false
	left = now.duplicate()
	var can := int(casino.get("can_spend_cents", 0))
	set_lamp(can >= _cheapest(casino))
	queue_redraw()


## The purple fired, so a fresh belt loads: the pegs pop back up 15 ms apart and the
## shells clack into the belt one at a time.
func reload() -> void:
	_reload = 0.0
	_drops.clear()
	Art.play(Art.SND_CLACK, 0.9, -6.0)


func set_lamp(on: bool) -> void:
	lamp_on = on
	_lamp_glow.visible = on
	queue_redraw()


## The lamp over the slot clicks off for a beat (a refusal), then shows the truth again.
func click_off(back_on: bool) -> void:
	set_lamp(false)
	Art.play(Art.SND_LAMP_OFF, 1.0, -4.0)
	await get_tree().create_timer(1.6).timeout
	if back_on and is_inside_tree():
		set_lamp(true)
		Art.play(Art.SND_LAMP_ON, 1.0, -10.0)


func _cheapest(casino: Dictionary) -> int:
	var prices: Array[int] = []
	for c: Dictionary in casino.get("cases", []):
		prices.append(int(c.price_cents))
	for b: Dictionary in casino.get("scratch", []):
		prices.append(int(b.price_cents))
	prices.append(int(casino.get("wheel", {}).get("price_cents", 500)))
	prices.append(int(casino.get("claw", {}).get("price_cents", 500)))
	return prices.min() if not prices.is_empty() else 100


func _total_left() -> int:
	var n := 0
	for k: String in left:
		n += int(left[k])
	return n


func _fired() -> int:
	return maxi(0, size - _total_left())


func _process(delta: float) -> void:
	t += delta
	for k: String in _drops.keys():
		_drops[k] += delta
		if _drops[k] > 0.6:
			_drops.erase(k)
	for f: Dictionary in _flying:
		f.t += delta
	if _reload >= 0.0:
		var before := int(_reload / 0.06)
		_reload += delta
		var after := int(_reload / 0.06)
		if after != before and after < size and after % 3 == 0:
			Art.play(Art.SND_CLACK, 1.0 + after * 0.02, -14.0)
		if _reload > size * 0.06 + 0.2:
			_reload = -1.0
	_flying.assign(_flying.filter(func(f: Dictionary) -> bool: return f.t < 0.7))
	_lamp_glow.modulate.a = (0.42 + sin(t * 9.0) * 0.03) if lamp_on else 0.0
	var epic_left := int(left.get("epic", 0))
	_rack_glow.modulate.a = (0.25 + sin(t * 3.0) * 0.08) if epic_left > 0 else 0.0
	queue_redraw()


func _draw() -> void:
	var w := SIZE.x
	var h := SIZE.y
	# Shadow, apron, rim, felt.
	draw_rect(Rect2(-w / 2 - 2, -3, w + 4, 7), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(-w / 2, -8, w, 8), WOOD)
	draw_rect(Rect2(-w / 2, -8, w, 1), WOOD_HI)
	draw_rect(Rect2(-w / 2 + 2, -3, w - 4, 1), BRASS_LO)
	draw_rect(Rect2(-w / 2, -h, w, h - 8), WOOD)
	draw_rect(Rect2(-w / 2, -h, w, 1), WOOD_HI)
	draw_rect(Rect2(-w / 2 + 3, -h + 3, w - 6, h - 14), FELT)
	for n: Vector3 in _noise:
		if n.z > 0.55:
			draw_rect(Rect2(Vector2(n.x, n.y).floor(), Vector2.ONE), FELT_HI)
	_draw_rack()
	_draw_belt()
	_draw_slot()


func _draw_rack() -> void:
	draw_rect(Rect2(RACK - Vector2(2, 2), Vector2(28, 26)), WOOD)
	draw_rect(Rect2(RACK - Vector2(2, 2), Vector2(28, 1)), WOOD_HI)
	var row := 0
	for tier: String in ["common", "rare", "epic"]:
		var total: int = BELT[tier]
		var have := int(left.get(tier, 0))
		var rows := ceili(total / 6.0)
		for i in total:
			var col := i % 6
			var r := row + i / 6
			var x := RACK.x + col * 4 + (10 if total == 1 else 0)
			var y := RACK.y + r * 4 + (2 if tier == "rare" else 0) + (4 if tier == "epic" else 0)
			var key := "%s:%d" % [tier, i]
			draw_rect(Rect2(x, y, 3, 3), HOLE)
			var g := (row * 6) + i
			if _reload >= 0.0 and _reload * 1000.0 / 15.0 < g:
				continue
			if i < have:
				var c := Art.rarity(tier)
				draw_rect(Rect2(x, y - 1, 3, 3), c)
				draw_rect(Rect2(x, y - 1, 1, 1), c.lightened(0.5))
			elif _drops.has(key):
				var k: float = _drops[key] / 0.6
				var dy := minf(k * 3.0, 2.0) - (sin(k * PI) * 1.0 if k > 0.4 else 0.0)
				draw_rect(Rect2(x, y - 1 + dy, 3, 3), Color(Art.rarity(tier), 1.0 - k))
		row += rows


func _draw_belt() -> void:
	var fired := _fired()
	draw_rect(Rect2(BELT_AT + Vector2(-2, -1), Vector2(size * 4 + 3, 10)), Color("1c1210"))
	for i in size:
		var x := BELT_AT.x + i * 4
		var y := BELT_AT.y
		if i < fired or (_reload >= 0.0 and _reload / 0.06 < i):
			draw_rect(Rect2(x, y + 6, 3, 1), Color("2a1c14"))
			continue
		# A brass shell standing in the belt, the next one to fire nudged forward.
		var nudge := 1.0 if i == fired else 0.0
		draw_rect(Rect2(x, y - nudge, 3, 8), BRASS)
		draw_rect(Rect2(x, y - nudge, 1, 8), BRASS_HI)
		draw_rect(Rect2(x, y + 5 - nudge, 3, 3), BRASS_LO)
		if i == fired and int(t * 2.0) % 2 == 0:
			draw_rect(Rect2(x + 1, y - nudge, 1, 1), Color.WHITE)
	for f: Dictionary in _flying:
		var k: float = f.t / 0.7
		var p := BELT_AT + Vector2(int(f.x) * 4 - k * 14, -sin(k * PI) * 16 + k * 6)
		draw_rect(Rect2(p, Vector2(3, 6)), Color(BRASS, 1.0 - k))


func _draw_slot() -> void:
	# A brass mouth for the bill, with a little gooseneck lamp leaning over it.
	draw_rect(Rect2(SLOT + Vector2(-8, 4), Vector2(18, 8)), BRASS_LO)
	draw_rect(Rect2(SLOT + Vector2(-8, 4), Vector2(18, 1)), BRASS_HI)
	draw_rect(Rect2(SLOT + Vector2(-5, 7), Vector2(12, 2)), HOLE)
	draw_line(SLOT + Vector2(9, 4), SLOT + Vector2(9, -6), BRASS_LO, 1.0)
	draw_line(SLOT + Vector2(9, -6), SLOT + Vector2(4, -10), BRASS_LO, 1.0)
	draw_rect(Rect2(SLOT + Vector2(-1, -12), Vector2(7, 3)), BRASS)
	var bulb := Color("fff1cf") if lamp_on else Color("3a3040")
	draw_rect(Rect2(SLOT + Vector2(1, -9), Vector2(3, 2)), bulb)
	if lamp_on:
		var cone := PackedVector2Array([SLOT + Vector2(0, -8), SLOT + Vector2(5, -8), SLOT + Vector2(9, 5), SLOT + Vector2(-5, 5)])
		draw_colored_polygon(cone, Color(Art.LAMP, 0.10))
