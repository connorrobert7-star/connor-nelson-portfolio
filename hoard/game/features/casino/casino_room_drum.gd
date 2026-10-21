class_name CasinoRoomDrum
extends CasinoRoomMachine
## The weekly draw: a caged drum on a dais over a slow ritual circle. It turns on its own;
## inside, the owner's tickets (one per $5 that landed this week) tumble bone white among
## the cultists' dull ones. Sunday it draws ten.

const SUMMON_FRAMES := 43

var entries := 0
var _circle := Sprite2D.new()
var _frames: Array[Texture2D] = []
var _specks: Array[Vector3] = []  # x phase, y phase, mine (1/0)


func _ready() -> void:
	_frames = Art.strip(Art.SUMMON, Rect2(0, 0, 64, 64), SUMMON_FRAMES)
	_circle.texture = _frames[0]
	_circle.scale = Vector2(0.9, 0.45)
	_circle.position = Vector2(0, -4)
	_circle.modulate = Color(1, 1, 1, 0.75)
	_circle.show_behind_parent = true
	add_child(_circle)
	var hit := Rect2(Vector2(-28, -52), Vector2(56, 54))
	add_spot("draw", hit, Vector2(-34, 6), Callable())
	_reseed()


func dress(casino: Dictionary) -> void:
	var now := int(casino.get("draw", {}).get("entries", 0))
	if now != entries:
		entries = now
		_reseed()


func _reseed() -> void:
	_specks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var mine := mini(entries, 24)
	for i in mine + 16:
		_specks.append(Vector3(rng.randf() * TAU, rng.randf() * TAU, 1.0 if i < mine else 0.0))


func idle(_delta: float) -> void:
	_circle.texture = _frames[int(t * 10.0) % SUMMON_FRAMES]
	queue_redraw()


func _draw() -> void:
	# Dais.
	draw_rect(Rect2(-27, -10, 54, 10), Color("2a2230"))
	draw_rect(Rect2(-27, -10, 54, 1), Color("4a3e55"))
	draw_rect(Rect2(-25, -2, 50, 2), Color("17121c"))
	# A-frame legs up to the axle.
	var hub := Vector2(0, -32)
	for side: int in [-1, 1]:
		draw_line(Vector2(side * 18, -10), hub + Vector2(side * 3, 2), Color("3a2218"), 2.0)
	# The cage: a wire globe turning on its axle, tickets tumbling inside it.
	var spin := t * 1.4
	_ring(hub, 15.5, Color(0.08, 0.04, 0.07, 0.85), true)
	for s: Vector3 in _specks:
		var a := s.x + spin * (1.0 + s.y * 0.08)
		var r := 3.0 + fmod(s.y * 7.0, 10.0)
		var p := hub + Vector2(cos(a) * r, sin(a) * r * 0.8 + 4.0)
		var c := Art.BONE if s.z > 0.5 else Color("5a5060")
		draw_rect(Rect2(p.round(), Vector2(2, 1)), c)
	for k in 4:
		var w := cos(spin + k * PI / 4.0) * 15.0
		_ellipse(hub, absf(w), 15.0, Color(0.75, 0.58, 0.3, 0.5 + 0.5 * absf(w) / 15.0))
	_ellipse(hub, 15.0, 3.0, Color("a07a3a"))
	_ring(hub, 15.5, Color("c99a4a"), false)
	_ring(hub, 16.5, Color("5a3f20"), false)
	draw_rect(Rect2(hub - Vector2(2, 2), Vector2(4, 4)), Color("c99a4a"))
	draw_rect(Rect2(hub - Vector2(2, 2), Vector2(2, 1)), Color("f0cf8a"))
	# Crank, turning.
	var crank := hub + Vector2(19, 0)
	draw_line(hub + Vector2(16, 0), crank, Color("6b4a22"), 1.0)
	var arm := crank + Vector2(cos(spin * 2.0), sin(spin * 2.0)) * 5.0
	draw_line(crank, arm, Color("c99a4a"), 1.0)
	draw_rect(Rect2(arm - Vector2(1, 1), Vector2(2, 2)), Color("e8dcc4"))


## A pixel ring (or a filled disc) of radius r.
func _ring(c: Vector2, r: float, color: Color, filled: bool) -> void:
	if filled:
		for y in range(-int(r), int(r) + 1):
			var half := floorf(sqrt(maxf(0.0, r * r - y * y)))
			draw_rect(Rect2(c.x - half, c.y + y, half * 2.0 + 1.0, 1), color)
		return
	var steps := int(r * 7.0)
	for i in steps:
		var a := TAU * i / steps
		draw_rect(Rect2((c + Vector2(cos(a), sin(a)) * r).floor(), Vector2.ONE), color)


## A pixel ellipse outline, rx by ry around c.
func _ellipse(c: Vector2, rx: float, ry: float, color: Color) -> void:
	var steps := int(maxf(rx, ry) * 6.0) + 4
	for i in steps:
		var a := TAU * i / steps
		draw_rect(Rect2((c + Vector2(cos(a) * rx, sin(a) * ry)).floor(), Vector2.ONE), color)
