class_name CasinoRoomBook
extends CasinoRoomMachine
## The collection book on its counter: a skull-bound book (Kyrise) that floats a little over
## the wood and falls open on its own now and then. Specks rise off it for each cosmetic
## owned, so a fuller book is a busier one.

const CLOSED := Rect2(160, 16, 16, 16)
const OPEN := Rect2(176, 16, 16, 16)

var owned := 0
var _book := Sprite2D.new()
var _closed: Texture2D
var _open: Texture2D
var _glow: Sprite2D
var _flip := 5.0
var _specks := CPUParticles2D.new()


func _ready() -> void:
	_closed = Art.region(Art.ICONS, CLOSED)
	_open = Art.region(Art.ICONS, OPEN)
	_glow = Art.glow(self, Vector2(0, -24), Art.LAMP, 16, 0.22)
	_book.texture = _closed
	_book.position = Vector2(0, -25)
	add_child(_book)
	_specks.amount = 8
	_specks.lifetime = 2.2
	_specks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_specks.emission_rect_extents = Vector2(6, 2)
	_specks.position = Vector2(0, -28)
	_specks.direction = Vector2(0, -1)
	_specks.spread = 25.0
	_specks.gravity = Vector2.ZERO
	_specks.initial_velocity_min = 4.0
	_specks.initial_velocity_max = 9.0
	_specks.color = Color(Art.BONE, 0.6)
	_specks.material = Art.additive()
	_specks.emitting = false
	_specks.z_index = 3
	add_child(_specks)
	var hit := Rect2(Vector2(-22, -40), Vector2(44, 40))
	add_spot("book", hit, Vector2(0, 16), Callable())


func dress(casino: Dictionary) -> void:
	owned = 0
	for k: String in casino.get("owned", {}):
		owned += int(casino.owned[k])
	_specks.amount = clampi(2 + owned, 2, 16)
	_specks.emitting = owned > 0


func poke() -> void:
	super.poke()
	_book.texture = _open
	_flip = 0.5
	Art.play(Art.SND_BOOK, 1.0, -10.0)


func idle(delta: float) -> void:
	_book.position.y = -25.0 + roundf(sin(t * 1.6) * 1.0) - 1.0
	_glow.modulate.a = 0.18 + 0.05 * sin(t * 1.6) + focus * 0.12
	_flip -= delta
	if _flip <= 0.0:
		if _book.texture == _open:
			_book.texture = _closed
			_flip = randf_range(5.0, 9.0)
		else:
			_book.texture = _open
			_flip = 0.7
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-22, -2, 44, 5), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(-20, -16, 40, 16), Color("3a2218"))
	draw_rect(Rect2(-20, -16, 40, 2), Color("5c3626"))
	draw_rect(Rect2(-20, -16, 40, 1), Color("8a6a3a"))
	draw_rect(Rect2(-18, -9, 36, 1), Color("2a1810"))
	# A shadow on the wood that breathes with the float.
	var w := 12.0 - absf(sin(t * 1.6)) * 2.0
	draw_rect(Rect2(-w / 2.0, -15, w, 1), Color(0, 0, 0, 0.35))
