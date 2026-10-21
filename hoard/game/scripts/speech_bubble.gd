class_name SpeechBubble
extends Node2D
## Words over a character's head instead of a text panel. Types out with blips,
## holds, then fades. say() returns when the line is done (or tapped past).
##   var bubble := SpeechBubble.new(); dealer.add_child(bubble); bubble.position = Vector2(0, -36)
##   await bubble.say("Twenty-five shells. One purple.")

signal finished

const CHAR_SECONDS := 0.03
const HOLD_SECONDS := 1.6
const MAX_WIDTH := 150.0

var _panel := PanelContainer.new()
var _label := Label.new()
var _tween: Tween


func _ready() -> void:
	z_index = 50
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.CREAM, 0.95)
	style.set_corner_radius_all(3)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	_panel.add_theme_stylebox_override("panel", style)
	_label.add_theme_font_size_override("font_size", 7)
	_label.add_theme_color_override("font_color", Palette.NIGHT)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_label)
	_panel.visible = false
	add_child(_panel)


func say(text: String, hold := HOLD_SECONDS) -> void:
	if _tween:
		_tween.kill()
	_label.text = text
	_label.visible_ratio = 0.0
	_label.custom_minimum_size.x = minf(MAX_WIDTH, 8.0 + text.length() * 4.2)
	_panel.reset_size()
	_panel.visible = true
	_panel.modulate.a = 1.0
	_panel.scale = Vector2(0.6, 0.6)
	await get_tree().process_frame
	_panel.position = Vector2(-_panel.size.x / 2.0, -_panel.size.y)
	_panel.pivot_offset = Vector2(_panel.size.x / 2.0, _panel.size.y)
	_tween = create_tween()
	_tween.tween_property(_panel, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var steps := text.length()
	for i in steps:
		_tween.tween_callback(func() -> void:
			_label.visible_ratio = float(i + 1) / steps
			if i % 3 == 0:
				Sfx.play("blip", randf_range(0.8, 1.1))
		)
		_tween.tween_interval(CHAR_SECONDS)
	_tween.tween_interval(hold)
	_tween.tween_property(_panel, "modulate:a", 0.0, 0.25)
	_tween.tween_callback(func() -> void:
		_panel.visible = false
		finished.emit()
	)
	await finished


func hide_now() -> void:
	if _tween:
		_tween.kill()
	_panel.visible = false
	finished.emit()
