class_name CasinoRoomBooth
extends CasinoRoomMachine
## The scratch-off booth: a striped awning that ripples, tickets on a string that sway, a
## Kenney card back pinned up as the sample, and the three books on the counter, each stack
## as tall as the tickets left in it, its price painted below.

const CARD_BACK := Rect2(448, 32, 32, 32)
const STACK_X := [-17.0, 0.0, 17.0]
const STRIPE_A := Color("ff6fb5")
const STRIPE_B := Color("f6ead2")

var books: Array = []  # [{price_cents, size, left: {tier: n}}]
var _labels: Array[Label] = []
var _card: Sprite2D


func _ready() -> void:
	_card = Art.sprite(Art.region(Art.CARDS, CARD_BACK), Vector2(0, -42), self)
	_card.show_behind_parent = false
	for i in 3:
		_labels.append(Art.paint(self, "", Vector2(STACK_X[i], -5), Art.BONE, 10, Art.FONT_BIG))
	var hit := Rect2(Vector2(-30, -66), Vector2(60, 66))
	add_spot("scratch", hit, Vector2(0, 18), Callable())


func dress(casino: Dictionary) -> void:
	books = casino.get("scratch", [])
	for i in _labels.size():
		_labels[i].text = Art.dollars(int(books[i].price_cents)) if i < books.size() else ""


func cheapest() -> int:
	var best := 1 << 30
	for b: Dictionary in books:
		best = mini(best, int(b.price_cents))
	return best if not books.is_empty() else 100


func idle(_delta: float) -> void:
	_card.rotation = sin(t * 1.4) * 0.05
	queue_redraw()


func _left(b: Dictionary) -> int:
	var n := 0
	for k: String in b.get("left", {}):
		n += int(b.left[k])
	return n


func _draw() -> void:
	draw_rect(Rect2(-32, -2, 64, 5), Color(0, 0, 0, 0.45))
	# Posts and back panel.
	draw_rect(Rect2(-29, -60, 3, 60), Color("3a2218"))
	draw_rect(Rect2(26, -60, 3, 60), Color("3a2218"))
	draw_rect(Rect2(-26, -56, 52, 36), Color("1e1226"))
	# A string of tickets swaying.
	draw_line(Vector2(-26, -53), Vector2(26, -53), Color("6a5a4a"), 1.0)
	for i in 6:
		var x := -22.0 + i * 9.0
		if absf(x) < 10.0:
			continue
		var sway := sin(t * 2.2 + i * 1.3) * 1.5
		var p := Vector2(roundf(x + sway), -52)
		draw_rect(Rect2(p, Vector2(6, 9)), Color("e8dcc4"))
		draw_rect(Rect2(p + Vector2(1, 3), Vector2(4, 4)), Color("9aa4ae"))
		draw_rect(Rect2(p, Vector2(6, 2)), [STRIPE_A, Palette.TEAL, Color("c99a4a")][i % 3])
	# Awning: stripes with a scalloped edge that ripples.
	for i in 8:
		var c := STRIPE_A if i % 2 == 0 else STRIPE_B
		var x := -32.0 + i * 8.0
		draw_rect(Rect2(x, -66, 8, 8), c.darkened(0.25))
		var drop := 2.0 + roundf(sin(t * 3.0 + i * 0.8) * 1.0)
		draw_rect(Rect2(x + 1, -58, 6, drop), c.darkened(0.35))
	draw_rect(Rect2(-32, -67, 64, 1), Color("f6ead2").darkened(0.3))
	# Counter.
	draw_rect(Rect2(-30, -20, 60, 20), Color("3a2218"))
	draw_rect(Rect2(-30, -20, 60, 1), Color("8a6a3a"))
	draw_rect(Rect2(-28, -12, 56, 1), Color("2a1810"))
	# The three books, as tall as what's left.
	for i in mini(3, books.size()):
		var n := _left(books[i])
		var h := maxi(1, ceili(n / 3.0))
		var x: float = STACK_X[i] - 5.0
		for k in h:
			draw_rect(Rect2(x, -21 - k, 10, 1), Color("e8dcc4") if k % 2 == 0 else Color("cfc2a8"))
		var top := -21 - h
		draw_rect(Rect2(x, top - 2, 10, 3), Color("b8c2cc"))
		var glint := int(fmod(t * 6.0 + i * 3.0, 14.0))
		if glint < 10:
			draw_rect(Rect2(x + glint, top - 2, 1, 1), Color.WHITE)
