class_name DialButton
extends Button
## Demo only: the "next day" control as a little sun-and-moon dial. Tapping it turns
## the dial half a turn (day to night to day) with a squash and a click.

var _turn := 0.0
var _hover := false
var _t := 0.0


func _ready() -> void:
	text = ""
	flat = true
	focus_mode = Control.FOCUS_NONE
	for s in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(s, StyleBoxEmpty.new())
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	custom_minimum_size = Vector2(15, 15)
	size = custom_minimum_size
	pivot_offset = size / 2.0
	mouse_entered.connect(func() -> void:
		_hover = true
		Sfx.ui("hover")
	)
	mouse_exited.connect(func() -> void: _hover = false)
	button_down.connect(func() -> void: scale = Vector2(0.85, 0.85))
	pressed.connect(_spin)


func _spin() -> void:
	Sfx.ui("press")
	Juice.pop(self, Vector2(1.2, 0.85), 0.4)
	var tw := create_tween()
	tw.tween_property(self, "_turn", _turn + PI, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var c := (size / 2.0).floor()
	# Plate.
	PixelDraw.disc(self, c, 7, Palette.NIGHT)
	PixelDraw.ring(self, c, 7, Color("5a4773").lightened(0.2 if _hover else 0.0))
	# The dial: sun on one end, moon on the other, turning about the center.
	var a := _turn - PI / 2.0
	var sun := c + Vector2(cos(a), sin(a)) * 3.0
	var moon := c - Vector2(cos(a), sin(a)) * 3.0
	PixelDraw.disc(self, moon, 2, Palette.MUTED)
	draw_rect(Rect2(moon.round() + Vector2(0, -2), Vector2(2, 2)), Palette.NIGHT)
	var glow := 0.3 + 0.15 * sin(_t * 3.0)
	PixelDraw.disc(self, sun, 3, Color(Palette.GLOW, glow))
	PixelDraw.disc(self, sun, 2, Palette.GLOW)
