class_name CasinoRoomShelf
extends CasinoRoomMachine
## The reliquary of sealed cases in the back corner: one Whimsy Hallow chest per price,
## with the price painted beside it in bone white. Every few seconds one of them rattles.
## Tap a case to have Vex state the odds and open it (the room wires the action).

## case_id -> chest row on the Whimsy sheet (48x40 frames, 21 per row).
const LOOK := {"case_10": 8, "case_20": 7, "case_50": 9}
const BOARDS := [-58.0, -34.0, -10.0]
const W := 64.0
const H := 88.0
const CHEST_X := -8.0

var cases: Array = []  # [{id, price_cents, affordable}]
var chests: Dictionary = {}  # case_id -> {sprite, frames, board}
var _rattle := 3.0
var _rattling := ""
var _rattle_t := 0.0
var _labels: Array[Label] = []


## Build the chests for the cases in state (top shelf is the dearest).
func dress(casino: Dictionary) -> void:
	var now: Array = casino.get("cases", [])
	if chests.is_empty() and not now.is_empty():
		_build(now)
	cases = now
	for c: Dictionary in cases:
		if chests.has(c.id):
			var ch: Dictionary = chests[c.id]
			(ch.sprite as Sprite2D).modulate = Color.WHITE if c.get("affordable", true) else Color(0.55, 0.5, 0.6)


func _build(now: Array) -> void:
	var sorted := now.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.price_cents) > int(b.price_cents))
	for i in mini(sorted.size(), BOARDS.size()):
		var c: Dictionary = sorted[i]
		var board: float = BOARDS[i]
		var row: int = LOOK.get(c.id, 7)
		var frames := Art.strip(Art.CHESTS, Rect2(0, row * 40, 48, 40), 12, Vector2(48, 0))
		var s := Art.sprite(frames[0], Vector2(CHEST_X - 24, board - 40), self, false)
		var light := Art.glow(self, Vector2(CHEST_X, board - 12), Art.LAMP, 18, 0.10, 0.6)
		chests[c.id] = {"sprite": s, "frames": frames, "board": board, "light": light}
		_labels.append(Art.paint(self, Art.dollars(int(c.price_cents)), Vector2(20, board - 9), Art.BONE, 10, Art.FONT_BIG))
		var hit := Rect2(Vector2(CHEST_X - 17, board - 22), Vector2(34, 22))
		add_spot(c.id, hit, Vector2(CHEST_X - 8 + i * 8, 14), Callable())


## The world rect for a case, for taps.
func case_rect(case_id: String) -> Rect2:
	for s: Dictionary in spots:
		if s.id == case_id:
			return Rect2(position + (s.hit as Rect2).position, (s.hit as Rect2).size)
	return Rect2()


func idle(delta: float) -> void:
	_rattle -= delta
	if _rattle <= 0.0 and not chests.is_empty():
		_rattle = randf_range(3.0, 5.5)
		_rattling = chests.keys()[randi() % chests.size()]
		_rattle_t = 0.0
		Art.play(Art.SND_RATTLE % (randi() % 5), randf_range(0.9, 1.2), -16.0)
	if _rattling != "":
		_rattle_t += delta
		var ch: Dictionary = chests[_rattling]
		var f := 2 + int(_rattle_t * 16.0)
		if f > 9:
			f = 0
			_rattling = ""
		(ch.sprite as Sprite2D).texture = ch.frames[f]
	for id: String in chests:
		var ch: Dictionary = chests[id]
		var light: Sprite2D = ch.light
		light.modulate.a = 0.10 + 0.03 * sin(t * 2.0 + float(ch.board)) + focus * 0.05
	queue_redraw()


func _draw() -> void:
	# A tall dark cabinet: back panel, posts, a crest, and three lit shelves.
	draw_rect(Rect2(-W / 2 - 2, -H - 2, W + 4, H + 4), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(-W / 2, -H, W, H), Color("1b1020"))
	draw_rect(Rect2(-W / 2, -H, 3, H), Color("3a2218"))
	draw_rect(Rect2(W / 2 - 3, -H, 3, H), Color("3a2218"))
	draw_rect(Rect2(-W / 2 - 2, -H - 4, W + 4, 5), Color("3a2218"))
	draw_rect(Rect2(-W / 2 - 2, -H - 4, W + 4, 1), Color("8a6a3a"))
	var crest := PackedVector2Array([Vector2(-8, -H - 4), Vector2(0, -H - 10), Vector2(8, -H - 4)])
	draw_colored_polygon(crest, Color("3a2218"))
	draw_rect(Rect2(-1, -H - 7, 2, 2), Color("c99a4a"))
	for b: float in BOARDS:
		draw_rect(Rect2(-W / 2 + 3, b, W - 6, 4), Color("4a2c1c"))
		draw_rect(Rect2(-W / 2 + 3, b, W - 6, 1), Color("a07a3a"))
		draw_rect(Rect2(-W / 2 + 3, b - 21, W - 6, 1), Color(1, 0.9, 0.75, 0.10))
	draw_rect(Rect2(-W / 2, -2, W, 2), Color("2a1810"))
