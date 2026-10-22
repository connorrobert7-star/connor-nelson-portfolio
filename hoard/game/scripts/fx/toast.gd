class_name Toast
extends Control
## One small framed plate in the toast lane (right-aligned under the purse) with an icon
## by kind: coins (brass coin), money (bone jar, "simulated" chip), item (rarity gem that
## glows), day (sun), ticket (a draw ticket, its number on it), error (red plate; a tap
## retries), or plain (a spark). Main stacks at most three and moves the older ones down.

signal tapped

const SMALL := preload("res://art/ui/fonts/m5x7.ttf")
const COIN := preload("res://art/packs/evercrazy-coin-gem-8x8/SpinningCoin.png")
const H := 14.0

var kind := "plain"
var text := ""
var color := Palette.CREAM
var chip := ""  # a small grey tag after the text, e.g. "simulated"
var _t := 0.0


func setup(p_kind: String, p_text: String, p_color: Color, p_chip := "") -> Toast:
	kind = p_kind
	text = p_text
	color = p_color
	chip = p_chip
	var w := 6.0 + 12.0 + _w(text) + 6.0
	if chip != "":
		w += _w(chip) + 8.0
	size = Vector2(roundf(w), H)
	pivot_offset = size / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP if kind == "error" else Control.MOUSE_FILTER_IGNORE
	return self


func _w(s: String) -> float:
	return SMALL.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	# One touch on a phone is one tap (Level._is_tap skips the copy Godot makes of it).
	if Level._is_tap(event):
		accept_event()
		tapped.emit()


func _draw() -> void:
	var edge := Palette.BLOOD if kind == "error" else Color("5a4773")
	var fill := Color(0.25, 0.05, 0.1, 0.94) if kind == "error" else Color(Palette.NIGHT, 0.92)
	# Plate: dark fill, 1px frame with notched corners, a lit top edge, a drop shadow.
	draw_rect(Rect2(1, H, size.x - 1, 1), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(1, 1, size.x - 2, H - 2), fill)
	draw_rect(Rect2(1, 0, size.x - 2, 1), edge.lightened(0.25))
	draw_rect(Rect2(1, H - 1, size.x - 2, 1), edge.darkened(0.2))
	draw_rect(Rect2(0, 1, 1, H - 2), edge)
	draw_rect(Rect2(size.x - 1, 1, 1, H - 2), edge)
	var ic := Vector2(9, 7)
	match kind:
		"coins":
			var f := int(_t * 10.0) % 18
			draw_texture_rect_region(COIN, Rect2(ic - Vector2(4, 4), Vector2(8, 8)), Rect2(f * 8, 0, 8, 8))
		"money":
			_jar(ic - Vector2(3, 5))
		"item":
			_gem(ic, color)
		"day":
			_sun(ic)
		"ticket":
			_ticket(ic, color)
		"error":
			_bang(ic)
		_:
			_spark(ic, color)
	var x := 18.0
	draw_string_outline(SMALL, Vector2(x, 11), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 2, Palette.NIGHT)
	draw_string(SMALL, Vector2(x, 11), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
	if chip != "":
		var cx := x + _w(text) + 5.0
		var cw := _w(chip) + 4.0
		draw_rect(Rect2(cx, 3, cw, 9), Color(Palette.MUTED, 0.22))
		draw_string(SMALL, Vector2(cx + 2, 11), chip, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Palette.MUTED, 0.8))


func _px(o: Vector2, rows: Array, colors: Dictionary) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if colors.has(row[x]):
				draw_rect(Rect2(o + Vector2(x, y), Vector2.ONE), colors[row[x]])


func _jar(o: Vector2) -> void:
	_px(o, [".nnnnn.", ".lllll.", "..n.n..", ".nbbbn.", "nbbbbbn", "nbhbbsn", "nbhbbsn", "nbbbssn", ".nnnnn."],
		{"n": Palette.NIGHT, "l": Palette.BRASS.darkened(0.2), "b": Palette.BONE, "h": Color.WHITE, "s": Palette.BONE.darkened(0.3)})


func _gem(c: Vector2, col: Color) -> void:
	var glow := 0.25 + 0.2 * sin(_t * 6.0)
	draw_rect(Rect2(c - Vector2(4, 4), Vector2(9, 9)), Color(col, glow * 0.5))
	var rows := ["...n...", "..nhn..", ".nhccn.", "nccccdn", ".ncddn.", "..ndn..", "...n..."]
	_px(c - Vector2(3, 3), rows, {"n": Palette.NIGHT, "h": col.lightened(0.6), "c": col, "d": col.darkened(0.35)})


func _sun(c: Vector2) -> void:
	var rows := ["...g...", ".g...g.", "..yyy..", "gyyyyyg", "..yyy..", ".g...g.", "...g..."]
	_px(c - Vector2(3, 3), rows, {"g": Color(Palette.GLOW, 0.7), "y": Palette.GLOW})


## A 9x7 ticket stub with a notch and a glint, lit in its color.
func _ticket(c: Vector2, col: Color) -> void:
	var glow := 0.25 + 0.2 * sin(_t * 6.0)
	draw_rect(Rect2(c - Vector2(5, 4), Vector2(11, 9)), Color(col, glow * 0.4))
	var rows := ["nnnnnnnnn", "nccccdccn", "ncccc.ccn", ".hcccdcc.", "ncccc.ccn", "nccccdccn", "nnnnnnnnn"]
	_px(c - Vector2(4, 3), rows, {"n": Palette.NIGHT, "c": col, "d": col.darkened(0.4), "h": col.lightened(0.5)})


func _bang(c: Vector2) -> void:
	draw_rect(Rect2(c + Vector2(-1, -4), Vector2(2, 5)), Palette.CREAM)
	draw_rect(Rect2(c + Vector2(-1, 2), Vector2(2, 2)), Palette.CREAM)


func _spark(c: Vector2, col: Color) -> void:
	var a := 0.7 + 0.3 * sin(_t * 8.0)
	draw_rect(Rect2(c + Vector2(0, -3), Vector2(1, 7)), Color(col, a))
	draw_rect(Rect2(c + Vector2(-3, 0), Vector2(7, 1)), Color(col, a))
	draw_rect(Rect2(c + Vector2(-1, -1), Vector2(3, 3)), Color(col.lightened(0.4), a))
