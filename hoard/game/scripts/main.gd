class_name Main
extends Node
## Holds the current level, the HUD, overlays, toasts, and moves between places.

const TOAST_SECONDS := 2.6
## Where a new session opens: the casino once it exists, else the village.
const START_LEVEL := "casino"

@onready var world: Node2D = $World
@onready var hud: CanvasLayer = $Hud
@onready var week_label: Label = $Hud/Week
@onready var purse_label: Label = $Hud/Purse
@onready var prompt_label: Label = $Hud/Prompt
@onready var panel: PanelContainer = $Hud/Panel
@onready var panel_text: Label = $Hud/Panel/Text
@onready var dialogue: Dialogue = $Hud/Dialogue
@onready var fade: ColorRect = $Hud/Fade

var level: Level
var village_return := Village.SPAWN
var _error := ""
var _life := LifeBar.new()
var _toasts := VBoxContainer.new()
var _overlays := Control.new()
var _shown_notifications: Dictionary = {}
var _day_button: Button


func _ready() -> void:
	_life.position = Vector2(6, 16)
	hud.add_child(_life)
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.position = Vector2(-120, 40)
	_toasts.size = Vector2(240, 0)
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_toasts)
	_overlays.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_overlays)
	hud.move_child(fade, -1)
	Game.state_changed.connect(_on_state)
	Game.failed.connect(func(message: String) -> void: _error = message)
	Game.event_fired.connect(_on_event)
	_add_day_button()
	show_panel("Waking the village...")
	var first := START_LEVEL if Features.level_script(START_LEVEL) else "village"
	go_to(first, Room.ENTRANCE if first != "village" else Village.SPAWN)
	Game.refresh()


# --- places ------------------------------------------------------------------

func go_to(level_id: String, spawn: Vector2i) -> void:
	Game.busy = true
	if level:
		Sfx.play("door")
		var out := create_tween()
		out.tween_property(fade, "modulate:a", 1.0, 0.15)
		await out.finished
		level.queue_free()
	if spawn == Level.RETURN:
		spawn = village_return
	level = make_level(level_id)
	level.setup(self, spawn)
	level.travel.connect(func(id: String, at: Vector2i) -> void: go_to.call_deferred(id, at))
	world.add_child(level)
	show_prompt("")
	hide_panel()
	var back := create_tween()
	back.tween_property(fade, "modulate:a", 0.0, 0.15)
	await back.finished
	Game.busy = false


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


# --- overlays and juice --------------------------------------------------------

## Show a full-screen overlay and wait for it to close. Returns what it closed with.
func open_overlay(overlay: Overlay) -> Variant:
	Game.busy = true
	overlay.main = self
	_overlays.add_child(overlay)
	var result: Variant = await overlay.closed
	Game.busy = false
	return result


func toast(text: String, color := Palette.CREAM, sound := "") -> void:
	if sound != "":
		Sfx.play(sound)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Palette.NIGHT)
	label.add_theme_constant_override("outline_size", 3)
	_toasts.add_child(label)
	var tw := label.create_tween()
	tw.tween_interval(TOAST_SECONDS)
	tw.tween_property(label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(label.queue_free)


## Shake the current camera a little. Big moments only.
func shake(strength := 3.0, seconds := 0.25) -> void:
	if level == null:
		return
	var cam := level.camera
	var tw := create_tween()
	var steps := int(seconds / 0.03)
	for i in steps:
		var f := strength * (1.0 - float(i) / steps)
		tw.tween_property(cam, "offset", Vector2(randf_range(-f, f), randf_range(-f, f)), 0.03)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.03)


func _on_event(e: Dictionary) -> void:
	match str(e.get("kind", "")):
		"coins":
			var d := int(e.delta)
			toast(("+%d coins" if d > 0 else "%d coins") % d, Palette.GLOW, "coin" if d > 0 else "")
		"money_moved":
			var note := "" if e.status != "simulated" else "  (simulated)"
			toast("%s moved: %s%s" % [Money.fmt(int(e.amount_cents)), str(e.reason), note], Palette.BILE, "cash")
		"item":
			toast("New: %s" % str(e.get("name", e.item_id)), Palette.RARITY.get(str(e.get("tier", "")), Palette.CREAM), "pop")
		_:
			if e.has("text"):
				toast(str(e.text), Palette.CREAM, str(e.get("sound", "pop")))


# --- HUD -----------------------------------------------------------------------

func _process(_delta: float) -> void:
	if _error != "":
		show_panel(_error)
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
				Sfx.play("whoosh")
				await Game.advance_days(1)
				toast("A day passes. %s" % _day(Game.state.today), Palette.MUTED)


## Demo only: a tappable "next day" in the corner, same as the N key.
func _add_day_button() -> void:
	var b := Button.new()
	b.text = "next day"
	b.flat = true
	b.add_theme_font_size_override("font_size", 6)
	b.add_theme_color_override("font_color", Palette.MUTED)
	b.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	b.position = Vector2(-44, 15)
	b.focus_mode = Control.FOCUS_NONE
	b.visible = false
	b.pressed.connect(func() -> void:
		if Game.busy or not Game.state.get("demo", false):
			return
		Sfx.play("whoosh")
		await Game.advance_days(1)
		toast("A day passes. %s" % _day(Game.state.today), Palette.MUTED)
	)
	hud.add_child(b)
	_day_button = b


func _on_state() -> void:
	if _day_button:
		_day_button.visible = Game.state.get("demo", false)
	_error = ""
	var s := Game.state
	var hint := "[ earlier" + ("   ] later" if Game.weeks_ago > 0 else "")
	if s.get("demo", false):
		hint += "   N next day"
	week_label.text = "%s to %s   %s" % [_day(s.window.start), _day(s.window.end), hint]
	purse_label.text = "coins %d    extra %s" % [int(s.coins), Money.fmt(maxi(0, int(s.extra.extra_cents)))]
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


func show_panel(text: String) -> void:
	if dialogue.visible:
		return
	panel_text.text = text
	panel.visible = true


func hide_panel() -> void:
	if _error == "":
		panel.visible = false


func show_prompt(text: String) -> void:
	prompt_label.text = text


static func _day(iso: String) -> String:
	const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var parts := iso.split("-")
	return "%s %d" % [MONTHS[int(parts[1]) - 1], int(parts[2])]
