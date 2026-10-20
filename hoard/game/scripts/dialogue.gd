class_name Dialogue
extends PanelContainer
## Talking box: portrait, name, typed-out lines, and choices.
##   d.open(npc_id, name); await d.say([...]); var i: int = await d.ask(text, options); d.close()
## ask() returns -1 if the player backs out with Esc.

signal _advanced
signal _chosen(index: int)

const CHAR_SECONDS := 0.018

var _portrait := TextureRect.new()
var _name := Label.new()
var _text := Label.new()
var _choices := GridContainer.new()
var _typing: Tween


func _ready() -> void:
	visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	_portrait.custom_minimum_size = Vector2(48, 48)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_portrait)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	row.add_child(col)
	_name.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	_name.add_theme_font_size_override("font_size", 8)
	_text.add_theme_font_size_override("font_size", 8)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(0, 20)
	_choices.add_theme_constant_override("h_separation", 6)
	_choices.add_theme_constant_override("v_separation", 2)
	col.add_child(_name)
	col.add_child(_text)
	col.add_child(_choices)


func open(npc_id: String, speaker: String) -> void:
	Game.busy = true
	var atlas := AtlasTexture.new()
	atlas.atlas = preload("res://art/npcs.png")
	atlas.region = Rect2(Level.NPC_FRAMES[npc_id] * 32, 0, 32, 32)
	_portrait.texture = atlas
	_name.text = speaker
	_text.text = ""
	visible = true


func close() -> void:
	visible = false
	_clear_choices()
	_release.call_deferred()


func say(lines: Array) -> void:
	for line: String in lines:
		_clear_choices()
		_type(line)
		await _advanced


func ask(prompt: String, options: Array[String], disabled: Array[bool] = []) -> int:
	_clear_choices()
	_type(prompt)
	_choices.columns = 2 if options.size() > 5 else 1
	var first: Button = null
	for i in options.size():
		var b := Button.new()
		b.text = options[i]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 8)
		b.disabled = i < disabled.size() and disabled[i]
		b.pressed.connect(func() -> void: _chosen.emit(i))
		_choices.add_child(b)
		if first == null and not b.disabled:
			first = b
	if first:
		first.grab_focus.call_deferred()
	var pick: int = await _chosen
	_clear_choices()
	return pick


func _type(line: String) -> void:
	_text.text = line
	_text.visible_ratio = 0.0
	if _typing:
		_typing.kill()
	_typing = create_tween()
	_typing.tween_property(_text, "visible_ratio", 1.0, line.length() * CHAR_SECONDS)


func _clear_choices() -> void:
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()


func _release() -> void:
	Game.busy = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _choices.get_child_count() > 0:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_chosen.emit(-1)
		elif event.is_action_pressed("interact"):
			var focused := get_viewport().gui_get_focus_owner()
			if focused is Button and not (focused as Button).disabled:
				get_viewport().set_input_as_handled()
				(focused as Button).pressed.emit()
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _text.visible_ratio < 1.0:
			_typing.kill()
			_text.visible_ratio = 1.0
		else:
			_advanced.emit()
