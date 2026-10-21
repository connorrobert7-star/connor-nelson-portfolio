class_name CasinoRoomClaw
extends CasinoRoomMachine
## The claw machine: a pink cabinet with a marquee of chasing bulbs, and behind the glass the
## real heap (state.casino.claw.heap), plush Ninja Adventure animals at their spots, the
## rarer ones glowing their tier. The claw wanders its rail and now and then dips.

const PLUSH := ["Cat", "Frog", "Dog", "Racoon", "CatBlack", "LionCub", "Dog2", "CatCyclop"]
const GLASS := Rect2(-24, -72, 48, 42)
const BODY := Color("8a2f63")
const BODY_HI := Color("c24d8c")
const TRIM := Color("2ec4b6")

var heap: Array = []
var price := 500
var _plush: Array[Dictionary] = []  # {sprite, glow}
var _label: Label
var _claw_x := 0.0
var _dip := 0.0
var _next_dip := 4.0
var _heap_layer := Node2D.new()
var _front := Node2D.new()


func _ready() -> void:
	add_child(_heap_layer)
	add_child(_front)
	_front.draw.connect(_draw_front)
	_label = Art.paint(self, Art.dollars(price), Vector2(-12, -8), Art.BONE, 10, Art.FONT_BIG)
	var hit := Rect2(Vector2(-28, -86), Vector2(56, 86))
	add_spot("claw", hit, Vector2(0, 16), Callable())


func dress(casino: Dictionary) -> void:
	var c: Dictionary = casino.get("claw", {})
	price = int(c.get("price_cents", price))
	_label.text = Art.dollars(price)
	var now: Array = c.get("heap", [])
	if now == heap:
		return
	heap = now
	for p: Dictionary in _plush:
		(p.sprite as Node).queue_free()
		if p.glow:
			(p.glow as Node).queue_free()
	_plush.clear()
	var order := heap.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.y) < float(b.y))
	for h: Dictionary in order:
		var kind: String = PLUSH[int(h.slot_index) % PLUSH.size()]
		var at := Vector2(
			roundf(lerpf(GLASS.position.x + 7, GLASS.end.x - 7, float(h.x))),
			roundf(lerpf(GLASS.position.y + 12, GLASS.end.y - 3, float(h.y)))
		)
		var glow: Sprite2D = null
		if str(h.tier) != "common":
			glow = Art.glow(_heap_layer, at + Vector2(0, -5), Art.rarity(str(h.tier)), 8, 0.45)
		var s := Art.sprite(Art.region(Art.ANIMAL % kind, Rect2(0, 0, 16, 16)), at + Vector2(0, -8), _heap_layer)
		s.modulate = Color(0.9, 0.86, 0.95)
		_plush.append({"sprite": s, "glow": glow})


func idle(_delta: float) -> void:
	_claw_x = sin(t * 0.45) * 17.0 + sin(t * 1.3) * 2.0
	_next_dip -= _delta
	if _next_dip <= 0.0:
		_next_dip = randf_range(5.0, 8.0)
		_dip = 0.001
		Art.play(Art.SND_CLAW, randf_range(1.2, 1.4), -20.0)
	if _dip > 0.0:
		_dip += _delta
		if _dip > 1.6:
			_dip = 0.0
	for i in _plush.size():
		var g: Sprite2D = _plush[i].glow
		if g:
			g.modulate.a = 0.35 + 0.12 * sin(t * 3.0 + i)
	queue_redraw()
	_front.queue_redraw()


func _draw() -> void:
	# Body and shadow.
	draw_rect(Rect2(-30, -2, 60, 5), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(-28, -86, 56, 86), BODY)
	draw_rect(Rect2(-28, -86, 2, 86), BODY_HI)
	draw_rect(Rect2(26, -86, 2, 86), BODY.darkened(0.3))
	# Marquee with chasing bulbs.
	draw_rect(Rect2(-26, -84, 52, 10), Color("2a1530"))
	var lead := int(t * 9.0) % 10
	for i in 10:
		var on := (i == lead or i == (lead + 5) % 10)
		var c := Art.BONE if on else Color("5a3a4a")
		draw_rect(Rect2(-23 + i * 5, -81, 2, 2), c)
		draw_rect(Rect2(-23 + i * 5, -78, 2, 2), Color("5a3a4a") if on else Color(TRIM, 0.7))
	# The glass: dark inside. The heap layer draws over this, the front layer over that.
	draw_rect(GLASS.grow(1), Color("1a0f1c"))
	draw_rect(GLASS, Color("0c161d"))
	draw_rect(Rect2(GLASS.position.x, GLASS.end.y - 4, GLASS.size.x, 4), Color("16242c"))


## In front of the heap: the rail and claw, the glass glint, the controls.
func _draw_front() -> void:
	# Rail, carriage, cable and claw.
	var top := GLASS.position.y + 2
	_front.draw_rect(Rect2(GLASS.position.x + 1, top, GLASS.size.x - 2, 1), Color("4a5a66"))
	var cx := roundf(_claw_x)
	_front.draw_rect(Rect2(cx - 3, top - 1, 7, 3), Color("8a9aa6"))
	var drop := 4.0 + (sin(clampf(_dip / 1.6, 0.0, 1.0) * PI) * 22.0 if _dip > 0.0 else 0.0)
	var head := Vector2(cx, top + 2 + drop)
	_front.draw_line(Vector2(cx, top + 2), head, Color("b0bcc4"), 1.0)
	var open := 2.0 if _dip > 0.0 and _dip < 0.8 else 1.0
	_front.draw_rect(Rect2(head + Vector2(-2, 0), Vector2(5, 2)), Color("c8d0d6"))
	_front.draw_line(head + Vector2(-2, 2), head + Vector2(-2 - open, 6), Color("c8d0d6"), 1.0)
	_front.draw_line(head + Vector2(2, 2), head + Vector2(2 + open, 6), Color("c8d0d6"), 1.0)
	_front.draw_line(head + Vector2(0, 2), head + Vector2(0, 6), Color("c8d0d6"), 1.0)
	# Glass glint sweeping across every few seconds.
	var sweep := fmod(t, 4.5) / 0.9
	if sweep < 1.0:
		var gx := GLASS.position.x - 10 + sweep * (GLASS.size.x + 20)
		var glint := PackedVector2Array([
			Vector2(gx, GLASS.position.y), Vector2(gx + 4, GLASS.position.y),
			Vector2(gx - 8, GLASS.end.y), Vector2(gx - 12, GLASS.end.y)])
		var clipped := Geometry2D.intersect_polygons(glint, PackedVector2Array([
			GLASS.position, Vector2(GLASS.end.x, GLASS.position.y), GLASS.end, Vector2(GLASS.position.x, GLASS.end.y)]))
		for poly: PackedVector2Array in clipped:
			if poly.size() >= 3 and not Geometry2D.triangulate_polygon(poly).is_empty():
				_front.draw_colored_polygon(poly, Color(1, 1, 1, 0.08))
	_front.draw_rect(GLASS, Color(TRIM, 0.55), false, 1.0)
	# Control panel: joystick and button.
	_front.draw_rect(Rect2(-26, -29, 52, 9), Color("2a1d33"))
	_front.draw_rect(Rect2(-26, -29, 52, 1), Color("4a3a55"))
	var stick := Vector2(-10 + roundf(sin(t * 0.45) * 1.0), -27)
	_front.draw_line(Vector2(-10, -22), stick, Color("1a1220"), 1.0)
	_front.draw_rect(Rect2(stick - Vector2(1, 1), Vector2(3, 3)), TRIM)
	_front.draw_rect(Rect2(6, -25, 5, 3), Palette.PINK if int(t * 2.0) % 2 == 0 else Palette.PINK.darkened(0.4))
	# Prize chute.
	_front.draw_rect(Rect2(8, -16, 14, 10), Color("07040a"))
	_front.draw_rect(Rect2(8, -16, 14, 1), BODY_HI)
