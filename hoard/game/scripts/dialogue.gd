class_name Dialogue
extends PanelContainer
## Talking box: portrait in a bone frame, the name on a plate, typed-out lines with
## blips in the speaker's voice, and choices as pixel buttons that squash when pressed.
##   d.open(npc_id, name); await d.say([...]); var i: int = await d.ask(text, options); d.close()
## ask() returns -1 if the player backs out with Esc.

signal _advanced
signal _chosen(index: int)

const CHAR_SECONDS := 0.018
const GUI := "res://art/packs/tiopalada-dark-dwellers-gui/"
const BLIP := "res://art/packs/ignisforge-sfx-sampler/blip_15.ogg"
## Blip pitch by speaker; anyone else talks at 1.0.
const VOICES := {"shopkeeper": 1.0, "tavern_keeper": 1.15, "vex": 0.7}

var _portrait := TextureRect.new()
var _frame := TextureRect.new()
var _name := Label.new()
var _text := Label.new()
var _choices := GridContainer.new()
var _typing: Tween
var _cursor := _Cursor.new()
var _voice := 1.0
var _open_tween: Tween


## The arrow that bobs beside the focused choice.
class _Cursor extends Node2D:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var x := roundf(sin(_t * 8.0) * 1.5)
		var rows := ["n...", "nyn.", "nyyn", "nyyyn", "nyyn", "nyn.", "n..."]
		for y in rows.size():
			var row: String = rows[y]
			for i in row.length():
				var c := Color.TRANSPARENT
				if row[i] == "n":
					c = Palette.NIGHT
				elif row[i] == "y":
					c = Palette.GLOW
				if c.a > 0.0:
					draw_rect(Rect2(Vector2(x + i, y - 3), Vector2.ONE), c)


func _ready() -> void:
	visible = false
	var box := StyleBoxTexture.new()
	box.texture = load(GUI + "20251029darkDwellers9SlicesA.png")
	box.set_texture_margin_all(10)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 7
	box.content_margin_bottom = 7
	box.modulate_color = Color(0.62, 0.58, 0.75, 0.97)
	add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	# Portrait inside the Dark Dwellers bone frame.
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(50, 58)
	holder.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(holder)
	_portrait.position = Vector2(6, 14)
	_portrait.size = Vector2(37, 40)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	holder.add_child(_portrait)
	_frame.texture = load(GUI + "20251125portraitFrameC.png")
	_frame.position = Vector2(0, -12)  # the arch peeks over the box
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_frame)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	# The name on a small plate.
	var plate := StyleBoxTexture.new()
	plate.texture = load(GUI + "20251117darkDwellersHeaderB.png")
	plate.texture_margin_left = 10
	plate.texture_margin_right = 10
	plate.texture_margin_top = 8
	plate.texture_margin_bottom = 8
	plate.content_margin_left = 12
	plate.content_margin_right = 12
	plate.content_margin_top = 1
	plate.content_margin_bottom = 3
	_name.add_theme_stylebox_override("normal", plate)
	_name.add_theme_color_override("font_color", Palette.GLOW)
	_name.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(0, 22)
	_choices.add_theme_constant_override("h_separation", 6)
	_choices.add_theme_constant_override("v_separation", 1)
	col.add_child(_name)
	col.add_child(_text)
	col.add_child(_choices)
	_cursor.visible = false
	add_child(_cursor)


func open(npc_id: String, speaker: String) -> void:
	Game.busy = true
	var look := Level.npc_look(npc_id)
	var tex: Texture2D = look.texture
	var frames := int(look.get("hframes", 1))
	var w := tex.get_width() / frames
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(int(look.get("frame", 0)) * w, 0, w, tex.get_height())
	_portrait.texture = atlas
	_name.text = speaker
	_text.text = ""
	_voice = float(VOICES.get(npc_id, 1.0))
	var was_open := visible
	visible = true
	if not was_open:
		Sfx.ui("open")
		modulate.a = 0.0
		pivot_offset = Vector2(size.x / 2.0, size.y)
		scale = Vector2(0.97, 0.9)
		if _open_tween:
			_open_tween.kill()
		_open_tween = create_tween().set_parallel()
		_open_tween.tween_property(self, "modulate:a", 1.0, 0.12)
		_open_tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	visible = false
	_cursor.visible = false
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
		b.disabled = i < disabled.size() and disabled[i]
		b.pressed.connect(func() -> void: _chosen.emit(i))
		_juice_button(b)
		_choices.add_child(b)
		if first == null and not b.disabled:
			first = b
	if first:
		first.grab_focus.call_deferred()
	var pick: int = await _chosen
	_clear_choices()
	return pick


## Hover lights it and blips; pressing squashes it and springs back.
func _juice_button(b: Button) -> void:
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus()
			Sfx.ui("hover")
	)
	b.button_down.connect(func() -> void:
		b.pivot_offset = b.size / 2.0
		b.scale = Vector2(0.92, 0.92)
	)
	b.pressed.connect(func() -> void:
		Sfx.ui("press")
		Juice.pop(b, Vector2(0.92, 0.92), 0.35)
	)


func _process(_delta: float) -> void:
	if not visible:
		return
	var f := get_viewport().gui_get_focus_owner()
	_cursor.visible = f is Button and f.get_parent() == _choices
	if _cursor.visible:
		var r := (f as Control).get_global_rect()
		_cursor.position = (r.position - get_global_rect().position + Vector2(-2, r.size.y / 2.0)).round()


func _type(line: String) -> void:
	_text.text = line
	_text.visible_characters = 0
	if _typing:
		_typing.kill()
	_typing = create_tween()
	var n := line.length()
	_typing.tween_method(func(v: int) -> void:
		if v != _text.visible_characters:
			_text.visible_characters = v
			if v % 2 == 1 and v <= n and line[v - 1] != " ":
				Sfx.play_path(BLIP, _voice * randf_range(0.94, 1.06), -20.0, "UI")
	, 0, n, n * CHAR_SECONDS)
	_typing.tween_callback(func() -> void: _text.visible_characters = -1)


func _clear_choices() -> void:
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()


func _release() -> void:
	Game.busy = false


func _gui_input(event: InputEvent) -> void:
	if Level._is_tap(event) and _choices.get_child_count() == 0:
		accept_event()
		_advance_or_finish()


func _advance_or_finish() -> void:
	if _text.visible_characters >= 0 and _text.visible_characters < _text.text.length():
		_typing.kill()
		_text.visible_characters = -1
	else:
		Sfx.ui("tap")
		_advanced.emit()


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
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel") or Level._is_tap(event):
		get_viewport().set_input_as_handled()
		_advance_or_finish()
