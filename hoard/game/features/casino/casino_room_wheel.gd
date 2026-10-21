class_name CasinoRoomWheel
extends CasinoRoomMachine
## The prize wheel on its stand (draganas' 64px wheel). It teeters back and forth on its own,
## and twelve rim lamps show the real wedges: each lit in its tier's color, dark once won,
## until the wheel resets. The price is painted on the stand.

const DISC := Rect2(0, 0, 64, 47)
const BASE := Rect2(0, 46, 64, 18)
const CENTER := Vector2(0, -44)
const RIM := 25.0

var wedges: Array = []
var price := 500
var _disc := Sprite2D.new()
var _pips := _Pips.new()
var _label: Label
var _spin := 0.0
var _vel := 0.0
var _next_nudge := 2.0


func _ready() -> void:
	Art.sprite(Art.region(Art.WHEEL, BASE), Vector2(0, -11), self)
	_disc.texture = Art.region(Art.WHEEL, DISC)
	_disc.position = CENTER
	_disc.show_behind_parent = true  # the pointer (drawn by this node) sits on top
	add_child(_disc)
	_disc.add_child(_pips)
	_label = Art.paint(self, Art.dollars(price), Vector2(0, -8), Art.BONE, 10, Art.FONT_BIG)
	var hit := Rect2(Vector2(-32, -70), Vector2(64, 70))
	add_spot("wheel", hit, Vector2(0, 16), Callable())


func dress(casino: Dictionary) -> void:
	var w: Dictionary = casino.get("wheel", {})
	wedges = w.get("wedges", [])
	price = int(w.get("price_cents", price))
	_label.text = Art.dollars(price)
	_pips.wedges = wedges
	_pips.queue_redraw()


func poke() -> void:
	super.poke()
	_vel += 6.0


func idle(delta: float) -> void:
	# A lazy teeter, and now and then a nudge that clicks over a peg or two.
	_next_nudge -= delta
	if _next_nudge <= 0.0:
		_next_nudge = randf_range(3.0, 6.0)
		_vel += randf_range(-2.2, 2.2)
	_vel = move_toward(_vel, 0.0, delta * 1.6)
	var before := int(floor(_spin / (TAU / 12.0)))
	_spin += _vel * delta
	var after := int(floor(_spin / (TAU / 12.0)))
	if before != after:
		Art.play(Art.SND_WHEEL, randf_range(1.1, 1.3), -18.0)
	_disc.rotation = _spin + sin(t * 0.8) * 0.06
	_pips.time = t
	_pips.queue_redraw()


func _draw() -> void:
	# The pointer at the top: a bone flapper that flicks when the wheel moves.
	var flick := clampf(_vel * 0.6, -2.0, 2.0)
	var tip := CENTER + Vector2(flick, -RIM + 3)
	var p := PackedVector2Array([CENTER + Vector2(-3, -RIM - 5), CENTER + Vector2(3, -RIM - 5), tip])
	draw_colored_polygon(p, Art.BONE)
	draw_rect(Rect2(CENTER + Vector2(-1, -RIM - 7), Vector2(3, 3)), Color("c99a4a"))


class _Pips:
	extends Node2D
	## Twelve rim lamps, one per wedge, in the wedge's tier color; a won wedge goes dark.

	var wedges: Array = []
	var time := 0.0

	func _draw() -> void:
		var n := wedges.size()
		for i in n:
			var w: Dictionary = wedges[i]
			var a := -PI / 2.0 + (i + 0.5) * TAU / n
			var p := (Vector2(cos(a), sin(a)) * 24.0).round()
			if w.get("taken", false):
				draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color("1a1220"))
				continue
			var c := Palette.RARITY.get(str(w.tier), Palette.COMMON) as Color
			var on := 0.75 + 0.25 * sin(time * 4.0 + i * 0.9)
			draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), Color(c, 0.35 * on))
			draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), c.lightened(0.2 * on))
