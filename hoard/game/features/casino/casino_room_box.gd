class_name CasinoRoomBox
extends Node2D
## The box on the wall behind Vex: 100 holes, each case uses one, used holes go dark.
## Two of them are special (legendary, or mythic one time in four). The announced, unfired
## specials show as studs down the side; when a special is next, the lamp on top lights in
## its color and that hole burns. A fresh box lights up in a sweep.
## Position is the board's center.

const Art := preload("res://features/casino/casino_room_art.gd")
const HOLE := 3
const PITCH := 4
const GRID := 10
const BOARD := Vector2(48, 48)

var used := 0
var specials: Array = []
var next_tier := ""
var t := 0.0
var _sweep := -1.0  # seconds into a fresh-box sweep, or -1
var _first := true
var _lamp_glow: Sprite2D
var _hole_glow: Sprite2D
var _stud_glows: Array[Sprite2D] = []


func _ready() -> void:
	_lamp_glow = Art.glow(self, Vector2(0, -29), Palette.LEGENDARY, 26, 0.0)
	_lamp_glow.z_index = 3
	_hole_glow = Art.glow(self, Vector2.ZERO, Palette.LEGENDARY, 8, 0.0)
	_hole_glow.z_index = 3
	for i in 2:
		var g := Art.glow(self, Vector2(BOARD.x / 2 + 4, -10 + i * 8), Palette.LEGENDARY, 6, 0.0)
		g.z_index = 3
		_stud_glows.append(g)


func dress(casino: Dictionary) -> void:
	var box: Dictionary = casino.get("box", {})
	var now := int(box.get("used", 0))
	if not _first and now < used:
		_sweep = 0.0
		Art.play(Art.SND_BELL, 0.7, -10.0)
	_first = false
	used = now
	specials = box.get("specials", [])
	next_tier = str(box.get("next_tier", "")) if box.get("next_is_special", false) else ""
	if next_tier == "<null>":
		next_tier = ""
	queue_redraw()


func is_tell() -> bool:
	return next_tier != ""


func tell_color() -> Color:
	return Art.rarity(next_tier) if is_tell() else Color.TRANSPARENT


func _hole_pos(i: int) -> Vector2:
	var span := GRID * PITCH - 1
	return Vector2(-span / 2.0 + (i % GRID) * PITCH, -span / 2.0 + (i / GRID) * PITCH).floor()


func _process(delta: float) -> void:
	t += delta
	if _sweep >= 0.0:
		_sweep += delta
		if _sweep > 1.2:
			_sweep = -1.0
	var tell := tell_color()
	var pulse := 0.5 + 0.5 * sin(t * 5.0)
	_lamp_glow.modulate = Color(tell, 0.55 + pulse * 0.2) if is_tell() else Color(0, 0, 0, 0)
	_hole_glow.modulate = Color(tell, 0.5 + pulse * 0.4) if is_tell() else Color(0, 0, 0, 0)
	if is_tell():
		_hole_glow.position = _hole_pos(used) + Vector2(1.5, 1.5)
	for i in _stud_glows.size():
		var on := i < specials.size()
		_stud_glows[i].modulate = Color(Art.rarity(str(specials[i])), 0.35 + pulse * 0.1) if on else Color(0, 0, 0, 0)
	queue_redraw()


func _draw() -> void:
	var half := BOARD / 2.0
	# Chains up into the dark, the board, its brass rim.
	draw_line(Vector2(-14, -half.y), Vector2(-10, -half.y - 10), Color("4a3a2a"), 1.0)
	draw_line(Vector2(14, -half.y), Vector2(10, -half.y - 10), Color("4a3a2a"), 1.0)
	draw_rect(Rect2(-half - Vector2(2, 2), BOARD + Vector2(4, 4)), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(-half, BOARD), Color("2a1912"))
	draw_rect(Rect2(-half, BOARD), Color("7a5a2a"), false, 1.0)
	draw_rect(Rect2(-half + Vector2(1, 1), Vector2(BOARD.x - 2, 1)), Color("a07a3a"))
	var tell := tell_color()
	for i in GRID * GRID:
		var p := _hole_pos(i)
		if i < used:
			draw_rect(Rect2(p, Vector2(HOLE, HOLE)), Color("0b0710"))
		elif i == used and is_tell():
			draw_rect(Rect2(p - Vector2.ONE, Vector2(HOLE + 2, HOLE + 2)), Color(tell, 0.6))
			draw_rect(Rect2(p, Vector2(HOLE, HOLE)), tell.lightened(0.3))
		else:
			var shimmer := 0.08 * sin(t * 1.3 - (i % GRID) * 0.4 - (i / GRID) * 0.25)
			var base := Color("6b5130").lightened(maxf(0.0, shimmer))
			if _sweep >= 0.0:
				# A fresh box: the holes light one after another, 8 ms apart.
				var k := _sweep * 125.0 - i
				base = base.darkened(0.8) if k < 0.0 else base.lightened(clampf(1.0 - k / 10.0, 0.0, 1.0) * 0.8)
			draw_rect(Rect2(p, Vector2(HOLE, HOLE)), base)
			draw_rect(Rect2(p, Vector2(1, 1)), Color("9a7a48"))
	# The announced specials, still unfired: studs down the right side.
	for i in specials.size():
		var c := Art.rarity(str(specials[i]))
		var sp := Vector2(half.x + 3, -12 + i * 8)
		draw_rect(Rect2(sp, Vector2(3, 3)), c)
		draw_rect(Rect2(sp, Vector2(1, 1)), c.lightened(0.6))
	# The tell lamp: a caged bulb on top of the board.
	var top := Vector2(0, -half.y - 6)
	draw_rect(Rect2(top + Vector2(-5, -2), Vector2(10, 7)), Color("3a2e22"))
	var bulb := tell.lightened(0.35) if is_tell() else Color("2c2434")
	draw_rect(Rect2(top + Vector2(-3, -1), Vector2(6, 5)), bulb)
	for x in [-3, 0, 3]:
		draw_line(top + Vector2(x, -2), top + Vector2(x, 5), Color("6b5130"), 1.0)
