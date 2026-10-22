class_name Main
extends Node
## Holds the current level, the HUD, overlays, toasts, and moves between places.

const TOAST_SECONDS := 2.6
const MAX_TOASTS := 3
## Where a new session opens: the casino once it exists, else the village.
const START_LEVEL := "casino"
## The iris radius that clears the whole 480x270 screen from anywhere on it.
const IRIS_OPEN := 560.0
const CANDLE := preload("res://art/packs/kyrise-rpg-icons-16/icons/16x16/candle_01b.png")

@onready var world: Node2D = $World
@onready var hud: CanvasLayer = $Hud
@onready var prompt_label: Label = $Hud/Prompt
@onready var panel: PanelContainer = $Hud/Panel
@onready var panel_text: Label = $Hud/Panel/Text
@onready var dialogue: Dialogue = $Hud/Dialogue
@onready var top: CanvasLayer = $Top
@onready var fade: ColorRect = $Iris/Fade
@onready var post: ColorRect = $Post/Grade

var level: Level
var village_return := Village.SPAWN
## How deep the vignette is (0.3 normally; reveals can push it to 0.45 for a moment).
var post_vignette := 0.3:
	set(v):
		post_vignette = v
		if post:
			(post.material as ShaderMaterial).set_shader_parameter("vignette", v)
var _error := ""
var _hud_root := Control.new()
var _life := LifeBar.new()
var _purse := HudPurse.new()
var _toasts := Control.new()
var _overlays := Control.new()
var _closing := Control.new()  # overlays playing their outro, out of the way of game flow
var _shown_notifications: Dictionary = {}
var _held_money: Array[Dictionary] = []  # money toasts waiting for an overlay to close
var _day_button: Button
var _waking: TextureRect
var _hud_tween: Tween


func _ready() -> void:
	_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_hud_root)
	hud.move_child(_hud_root, 0)
	_life.position = Vector2(4, 4)
	_hud_root.add_child(_life)
	_purse.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_purse.offset_left = -4 - 240
	_purse.offset_right = -4
	_purse.offset_top = 4
	_purse.offset_bottom = 44
	_hud_root.add_child(_purse)
	prompt_label.reparent(_hud_root)
	_toasts.set_anchors_preset(Control.PRESET_FULL_RECT)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_toasts)
	_overlays.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_overlays)
	_closing.set_anchors_preset(Control.PRESET_FULL_RECT)
	_closing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_closing)
	Game.state_changed.connect(_on_state)
	Game.failed.connect(_on_failed)
	panel.gui_input.connect(_on_panel_input)
	panel.visible = false
	Game.event_fired.connect(_on_event)
	_add_day_button()
	_add_waking_candle()
	_set_cursor()
	var first := START_LEVEL if Features.level_script(START_LEVEL) else "village"
	go_to(first, Room.ENTRANCE if first != "village" else Village.SPAWN)
	Game.refresh()


# --- places ------------------------------------------------------------------

func go_to(level_id: String, spawn: Vector2i) -> void:
	Game.busy = true
	var iris := fade.material as ShaderMaterial
	if level:
		# Close the iris on the wizard at the door.
		iris.set_shader_parameter("center", _leader_screen())
		Sfx.play_path("res://art/packs/kenney-interface-sounds/Audio/maximize_006.ogg", 0.8, -16.0, "UI")
		var out := create_tween()
		out.tween_method(func(r: float) -> void: iris.set_shader_parameter("radius", r), IRIS_OPEN * 0.55, 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await out.finished
		Sfx.play("door")
		level.queue_free()
	if spawn == Level.RETURN:
		spawn = village_return
	level = make_level(level_id)
	level.setup(self, spawn)
	level.travel.connect(func(id: String, at: Vector2i) -> void: go_to.call_deferred(id, at))
	world.add_child(level)
	show_prompt("")
	hide_panel()
	await get_tree().create_timer(0.06).timeout
	await _until_ready()
	# Open from the new spawn point.
	iris.set_shader_parameter("center", _leader_screen())
	if _waking:
		var w := _waking
		_waking = null
		w.create_tween().tween_property(w, "modulate:a", 0.0, 0.15).finished.connect(w.queue_free)
	var back := create_tween()
	back.tween_method(func(r: float) -> void: iris.set_shader_parameter("radius", r), 0.0, IRIS_OPEN, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await back.finished
	Game.busy = false


## On first load, wait (iris closed, candle flickering) until /state is in.
func _until_ready() -> void:
	await get_tree().process_frame
	var t := 0.0
	while Game.state.is_empty() and t < 20.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	await get_tree().process_frame


func _leader_screen() -> Vector2:
	if level == null or not is_instance_valid(level):
		return Vector2(240, 135)
	var p := level.leader.get_global_transform_with_canvas().origin + Vector2(0, -12)
	return p.clamp(Vector2.ZERO, Vector2(480, 270))


static func make_level(level_id: String) -> Level:
	var script := Features.level_script(level_id)
	if script:
		return script.new()
	match level_id:
		"shop":
			return ShopRoom.new()
		"tavern":
			return TavernRoom.new()
	return Village.new()


func _add_waking_candle() -> void:
	var c := TextureRect.new()
	c.texture = CANDLE
	c.set_anchors_preset(Control.PRESET_CENTER)
	c.position = Vector2(-8, -8)
	c.size = Vector2(16, 16)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Iris.add_child(c)
	var tw := c.create_tween().set_loops()
	tw.tween_property(c, "modulate", Color(1.2, 1.05, 0.8), 0.12)
	tw.tween_property(c, "modulate", Color(0.8, 0.7, 0.75), 0.09)
	tw.tween_property(c, "modulate", Color(1, 1, 1), 0.2)
	_waking = c


## A pixel pointer on desktop and web, sized to the window's scale.
func _set_cursor() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("mobile"):
		return
	var sheet: Texture2D = load("res://art/packs/tiopalada-dark-dwellers-gui/20251124mouseSmall1-Sheet.png")
	if sheet == null:
		return
	var img := sheet.get_image()
	var k := clampi(int(get_window().size.y / 270.0), 1, 4)
	for i in 2:
		var frame := img.get_region(Rect2i(i * 17, 0, 17, 17))
		frame.resize(17 * k, 17 * k, Image.INTERPOLATE_NEAREST)
		var shape := Input.CURSOR_ARROW if i == 0 else Input.CURSOR_POINTING_HAND
		Input.set_custom_mouse_cursor(ImageTexture.create_from_image(frame), shape, Vector2(2, 2) * k)


# --- overlays and juice --------------------------------------------------------

## Show a full-screen overlay and wait for it to close. Returns what it closed with.
func open_overlay(overlay: Overlay) -> Variant:
	Game.busy = true
	overlay.main = self
	_overlays.add_child(overlay)
	_hide_hud(true)
	var result: Variant = await overlay.closed
	Game.busy = false
	var others := _overlays.get_children().filter(func(c: Node) -> bool: return c != overlay and not c.is_queued_for_deletion())
	if others.is_empty():
		_hide_hud(false)
		_flush_money.call_deferred()
	return result


## Called by Overlay.close(): take it out of the overlay list at once (game flow
## never waits on an outro) and let it play out on the closing layer.
func retire_overlay(overlay: Overlay) -> void:
	if overlay.get_parent() == _overlays:
		_overlays.remove_child(overlay)
		_closing.add_child(overlay)


## The whole HUD slides up and fades while an overlay is open, then settles back.
func _hide_hud(hidden: bool) -> void:
	if _hud_tween:
		_hud_tween.kill()
	_hud_tween = create_tween().set_parallel()
	if hidden:
		_hud_tween.tween_property(_hud_root, "position:y", -20.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_hud_tween.tween_property(_hud_root, "modulate:a", 0.0, 0.15)
	else:
		_hud_tween.tween_property(_hud_root, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_hud_tween.tween_property(_hud_root, "modulate:a", 1.0, 0.2)


func toast(text: String, color := Palette.CREAM, sound := "", kind := "plain", chip := "") -> Toast:
	if sound != "":
		Sfx.play(sound)
	var t := Toast.new().setup(kind, text, color, chip)
	_toasts.add_child(t)
	# Older ones step down; past three, the oldest leaves.
	var live: Array[Toast] = []
	for c in _toasts.get_children():
		if c is Toast and not (c as Toast).has_meta("leaving"):
			live.append(c)
	while live.size() > MAX_TOASTS:
		_toast_leave(live.pop_front(), 0.12)
	for i in live.size():
		var tt := live[live.size() - 1 - i]
		var y := 6.0 + i * 16.0
		var x := roundf((480.0 - tt.size.x) / 2.0)
		if tt.has_meta("move"):
			var old: Tween = tt.get_meta("move")
			if old and old.is_valid():
				old.kill()
		var tw := tt.create_tween().set_parallel()
		if tt == t:
			tt.position = Vector2(x, y - 12.0)
			tt.modulate.a = 0.0
			tw.tween_property(tt, "position:y", y, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(tt, "modulate:a", 1.0, 0.12)
		else:
			tt.modulate.a = 1.0
			tw.tween_property(tt, "position:y", y, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tt.set_meta("move", tw)
	var hold := t.create_tween()
	hold.tween_interval(TOAST_SECONDS if kind != "error" else 6.0)
	hold.tween_callback(func() -> void: _toast_leave(t, 0.3))
	return t


func _toast_leave(t: Toast, seconds: float) -> void:
	if not is_instance_valid(t) or t.has_meta("leaving"):
		return
	t.set_meta("leaving", true)
	var tw := t.create_tween().set_parallel()
	tw.tween_property(t, "position:y", t.position.y - 6.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(t, "modulate:a", 0.0, seconds)
	tw.chain().tween_callback(t.queue_free)


## Shake the current camera a little. Big moments only.
func shake(strength := 3.0, _seconds := 0.25) -> void:
	Juice.shake_px(strength)


func _on_event(e: Dictionary) -> void:
	match str(e.get("kind", "")):
		"coins":
			var d := int(e.delta)
			toast(("+%d coins" if d > 0 else "%d coins") % d, Palette.BRASS, "coin" if d > 0 else "", "coins")
		"money_moved":
			if _overlays.get_child_count() > 0:
				_held_money.append(e)
			else:
				_money_toast(e)
		"item":
			toast(str(e.get("name", e.item_id)), Palette.RARITY.get(str(e.get("tier", "")), Palette.CREAM), "pop", "item")
		_:
			if e.has("text"):
				toast(str(e.text), Palette.CREAM, str(e.get("sound", "pop")))


func _money_toast(e: Dictionary) -> void:
	var chip := "simulated" if str(e.get("status", "")) == "simulated" else ""
	toast("%s  %s" % [Money.fmt(int(e.amount_cents)), str(e.reason)], Palette.BONE, "cash", "money", chip)


func _flush_money() -> void:
	if _overlays.get_child_count() > 0:
		return
	var held := _held_money.duplicate()
	_held_money.clear()
	for i in held.size():
		if i > 0:
			await get_tree().create_timer(0.25).timeout
		_money_toast(held[i])


# --- HUD -----------------------------------------------------------------------

func _process(_delta: float) -> void:
	if _day_button:
		# Demo only, and never over an overlay or while something is playing out.
		_day_button.visible = Game.state.get("demo", false) and not Game.busy and _overlays.get_child_count() == 0
	if dialogue.visible:
		panel.visible = false
		prompt_label.text = ""


func _unhandled_input(event: InputEvent) -> void:
	if Game.busy or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_BRACKETLEFT:
			Game.change_week(1)
		KEY_BRACKETRIGHT:
			Game.change_week(-1)
		KEY_N:
			if Game.state.get("demo", false):
				_next_day()


func _next_day() -> void:
	Sfx.play("whoosh")
	await Game.advance_days(1)
	toast(_day(Game.state.today), Palette.MUTED, "", "day")


## Demo only: a tappable sun-and-moon dial in the corner, same as the N key.
func _add_day_button() -> void:
	var b := DialButton.new()
	b.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	b.offset_left = -4 - 15
	b.offset_right = -4
	b.offset_top = 23
	b.offset_bottom = 38
	b.visible = false
	b.pressed.connect(func() -> void:
		if Game.busy or not Game.state.get("demo", false):
			return
		_next_day()
	)
	_hud_root.add_child(b)
	_day_button = b


func _on_state() -> void:
	_error = ""
	var s := Game.state
	var week := "%s-%s" % [_day(s.window.start), _day(s.window.end).split(" ")[-1]] if _day(s.window.start).split(" ")[0] == _day(s.window.end).split(" ")[0] else "%s-%s" % [_day(s.window.start), _day(s.window.end)]
	_purse.show_purse(int(s.coins), maxi(0, int(s.extra.extra_cents)), week)
	_life.show_life(s.life)
	_show_notifications(s.get("notifications", []))


func _show_notifications(items: Array) -> void:
	var ids: Array = []
	for n: Dictionary in items:
		if _shown_notifications.has(n.id):
			continue
		_shown_notifications[n.id] = true
		ids.append(n.id)
		toast(str(n.text), Palette.GLOW, str(n.get("data", {}).get("sound", "pop")))
	if not ids.is_empty():
		Game.call_api("POST", "/notifications/seen", {"ids": ids})


## A connection error shows as a red toast (its last line only); a tap retries.
func _on_failed(message: String) -> void:
	var lines := message.strip_edges().split("\n", false)
	var text := lines[-1].strip_edges() if not lines.is_empty() else message
	if text == _error:
		return
	_error = text
	Sfx.ui("nope")
	var t := toast(text.left(60), Palette.CREAM, "", "error")
	t.tapped.connect(func() -> void:
		_error = ""
		Sfx.ui("tap")
		_toast_leave(t, 0.15)
		Game.refresh()
	)


func _on_panel_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
		panel.visible = false


func show_panel(text: String) -> void:
	if dialogue.visible:
		return
	panel_text.text = text
	panel.visible = true


func hide_panel() -> void:
	panel.visible = false


func show_prompt(text: String) -> void:
	prompt_label.text = text


static func _day(iso: String) -> String:
	const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var parts := iso.split("-")
	return "%s %d" % [MONTHS[int(parts[1]) - 1], int(parts[2])]
