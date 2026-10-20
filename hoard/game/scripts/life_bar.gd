class_name LifeBar
extends Control
## Top-left life clock: level out of 100 (100 is the predicted day of death),
## progress through the current level, age, and the predicted death year.

const WIDTH := 92.0

var _level := Label.new()
var _detail := Label.new()
var _back := ColorRect.new()
var _fill := ColorRect.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for l: Label in [_level, _detail]:
		l.add_theme_font_size_override("font_size", 8 if l == _level else 6)
		l.add_theme_color_override("font_color", Palette.CREAM if l == _level else Palette.MUTED)
		l.add_theme_color_override("font_outline_color", Palette.NIGHT)
		l.add_theme_constant_override("outline_size", 3)
		add_child(l)
	_back.color = Palette.INK
	_back.position = Vector2(0, 12)
	_back.size = Vector2(WIDTH, 4)
	_fill.color = Palette.BLOOD
	_fill.position = Vector2(0, 12)
	_fill.size = Vector2(0, 4)
	add_child(_back)
	add_child(_fill)
	_detail.position = Vector2(0, 16)


func show_life(life: Dictionary) -> void:
	var level := int(life.level)
	_level.text = "LV %d / 100" % level
	_fill.size.x = WIDTH * float(life.level_progress)
	_fill.color = Palette.BLOOD if level >= 75 else Palette.PINK
	var death_year := str(life.death_date).substr(0, 4)
	_detail.text = "age %.1f   dies %s   %d weeks left" % [float(life.age_years), death_year, int(life.weeks_left)]
