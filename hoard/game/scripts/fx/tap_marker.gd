class_name TapMarker
extends Node2D
## Where a tap landed: a 1px pixel ring that grows and fades (CREAM on bare ground,
## GLOW on a thing), a small x that shakes once where you can't walk, and a bobbing
## down-chevron over a tapped thing until the leader gets there.

const SECONDS := 0.25

var kind := "ground"
var _t := 0.0


static func spawn(parent: Node, at: Vector2, p_kind: String) -> TapMarker:
	var m := TapMarker.new()
	m.kind = p_kind
	m.position = at.round()
	m.z_index = 60
	parent.add_child(m)
	return m


static func chevron(parent: Node, at: Vector2) -> Node2D:
	var c := _Chevron.new()
	c.position = at.round() + Vector2(0, -26)
	c.z_index = 60
	parent.add_child(c)
	return c


func _process(delta: float) -> void:
	_t += delta
	if _t >= (SECONDS if kind != "nope" else 0.4):
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if kind == "nope":
		var a := 1.0 - clampf((_t - 0.25) / 0.15, 0.0, 1.0)
		var dx := roundf(sin(_t * 60.0) * 2.0 * (1.0 - _t / 0.25)) if _t < 0.25 else 0.0
		var col := Color(Palette.BLOOD, a)
		for i in 3:
			draw_rect(Rect2(Vector2(dx - 1 + i, -1 + i), Vector2.ONE), col)
			draw_rect(Rect2(Vector2(dx + 1 - i, -1 + i), Vector2.ONE), col)
		return
	var k := _t / SECONDS
	var frame := mini(3, int(k * 4.0))
	var r: int = [2, 4, 5, 7][frame]
	var col := (Palette.GLOW if kind == "thing" else Palette.CREAM)
	PixelDraw.ring(self, Vector2.ZERO, r, Color(col, 1.0 - k))
	if kind == "thing" and frame < 2:
		draw_rect(Rect2(-1, -1, 2, 2), Color(col, 0.8))


class _Chevron extends Node2D:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var y := roundf(sin(_t * 7.0) * 1.5)
		var a := minf(1.0, _t * 8.0)
		# A 5px wide down-chevron with a dark edge so it reads on any floor.
		for i in 3:
			draw_rect(Rect2(Vector2(-2 + i, y + i - 1), Vector2(1, 1)), Color(Palette.NIGHT, a))
			draw_rect(Rect2(Vector2(2 - i, y + i - 1), Vector2(1, 1)), Color(Palette.NIGHT, a))
		for i in 3:
			draw_rect(Rect2(Vector2(-2 + i, y + i), Vector2(1, 1)), Color(Palette.GLOW, a))
			draw_rect(Rect2(Vector2(2 - i, y + i), Vector2(1, 1)), Color(Palette.GLOW, a))
