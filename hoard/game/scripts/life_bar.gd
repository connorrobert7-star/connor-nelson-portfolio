class_name LifeBar
extends Control
## Top-left life gauge: a skull-capped Dark Dwellers frame filling through the current
## level (PINK, BLOOD from 75 on), the level painted big beside the skull, the weeks
## left on the bar by an hourglass, and under it a candle with the age and a skull
## with the predicted death year. Everything drawn on the 480x270 grid.

const FRAME := preload("res://art/packs/tiopalada-dark-dwellers-gui/20251118darkDwellersBarD.png")
const CANDLE := preload("res://art/packs/kyrise-rpg-icons-16/icons/16x16/candle_01b.png")
const SKULL := preload("res://art/packs/kyrise-rpg-icons-16/icons/16x16/skull_01a.png")
const SMALL := preload("res://art/ui/fonts/m5x7.ttf")
const BIG := preload("res://art/ui/fonts/Jersey10-Regular.ttf")
## The hollow inside the frame, where the fill goes.
const INNER := Rect2(8, 4, 67, 9)
const WIDTH := 92.0

var _level := -1
var _progress := 0.0
var _shown := 0.0
var _age := ""
var _death := ""
var _weeks := ""
var _t := 0.0
var _pop := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(120, 36)
	size = custom_minimum_size


func show_life(life: Dictionary) -> void:
	var level := int(life.level)
	var first := _level < 0
	var leveled := not first and level != _level
	_level = level
	_progress = clampf(float(life.level_progress), 0.0, 1.0)
	_age = "%.1f" % float(life.age_years)
	_death = str(life.death_date).substr(0, 4)
	_weeks = str(int(life.weeks_left))
	if first:
		_shown = _progress
	else:
		var tw := create_tween()
		tw.tween_property(self, "_shown", _progress, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if leveled:
		_pop = 1.35
		create_tween().tween_property(self, "_pop", 1.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _level >= 0:
		queue_redraw()


func _draw() -> void:
	if _level < 0:
		return
	var fill_color := Palette.BLOOD if _level >= 75 else Palette.PINK
	# The hollow first, then the fill, then the frame over both.
	draw_rect(INNER, Color(Palette.NIGHT, 0.92))
	var w := roundi(INNER.size.x * _shown)
	if w > 0:
		draw_rect(Rect2(INNER.position, Vector2(w, INNER.size.y)), fill_color.darkened(0.15))
		draw_rect(Rect2(INNER.position, Vector2(w, 2)), fill_color.lightened(0.25))
		draw_rect(Rect2(INNER.position + Vector2(0, INNER.size.y - 1), Vector2(w, 1)), fill_color.darkened(0.45))
		# A slow shimmer that sweeps along the fill every few seconds.
		var sweep := fmod(_t * 26.0, INNER.size.x + 60.0) - 6.0
		if sweep < w:
			for i in 3:
				var x := roundi(sweep) - i * 2
				if x >= 0 and x < w:
					draw_rect(Rect2(INNER.position + Vector2(x, 0), Vector2(1, INNER.size.y - 1)), Color(1, 1, 1, 0.35 - i * 0.1))
		# The lit edge of the fill.
		draw_rect(Rect2(INNER.position + Vector2(w - 1, 0), Vector2(1, INNER.size.y)), Color(fill_color.lightened(0.5), 0.9))
	draw_texture(FRAME, Vector2.ZERO)
	# Weeks left on the bar, by an hourglass.
	var ww := SMALL.get_string_size(_weeks, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var wx := INNER.end.x - 2.0 - ww
	_hourglass(Vector2(wx - 8.0, INNER.position.y + 1.0), Palette.MUTED)
	_text(SMALL, 16, _weeks, Vector2(wx, INNER.position.y + 8.0), Palette.MUTED, 2)
	# The level, painted big beside the skull cap.
	draw_set_transform(Vector2(104, 9), 0.0, Vector2(_pop, _pop))
	_text(BIG, 20, str(_level), Vector2(-7, 7), Palette.CREAM if _level < 75 else Palette.BLOOD.lightened(0.3), 2)
	draw_set_transform(Vector2.ZERO)
	# Candle with the age, skull with the death year, on their own small plate.
	var y := 18.0
	var x2 := 11.0 + ceilf(SMALL.get_string_size(_age, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x) + 4.0
	var end := x2 + 13.0 + ceilf(SMALL.get_string_size(_death, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x) + 5.0
	HudPurse.plate(self, Rect2(2, y + 2, end - 2, 13), Color(0.55, 0.5, 0.68, 0.92))
	var flick := 0.85 + 0.15 * sin(_t * 9.0) * sin(_t * 3.7)
	draw_texture(CANDLE, Vector2(-3, y), Color(1, 1, 1, 1).lerp(Color(1.15, 1.0, 0.8), flick - 0.85))
	_text(SMALL, 16, _age, Vector2(11, y + 11), Palette.CREAM.lerp(Palette.MUTED, 0.35), 2)
	draw_texture(SKULL, Vector2(x2 - 2, y), Color(1, 1, 1, 0.9))
	_text(SMALL, 16, _death, Vector2(x2 + 13, y + 11), Palette.CREAM.lerp(Palette.MUTED, 0.35), 2)


func _text(font: Font, px: int, text: String, baseline: Vector2, color: Color, outline := 2) -> void:
	if outline > 0:
		draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, outline, Palette.NIGHT)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)


## A 5x7 hourglass of pixels.
func _hourglass(o: Vector2, color: Color) -> void:
	var rows := ["#####", ".#.#.", "..#..", ".#.#.", "#####"]
	var sand := Palette.GLOW
	for y in rows.size():
		for x in 5:
			if rows[y][x] == "#":
				draw_rect(Rect2(o + Vector2(x, y + 1), Vector2.ONE), color)
	# Sand trickling through.
	var s := int(_t * 2.0) % 3
	draw_rect(Rect2(o + Vector2(2, 2 + s), Vector2.ONE), sand)
	draw_rect(Rect2(o + Vector2(1, 4), Vector2(3, 1)), Color(sand, 0.8))
