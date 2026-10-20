class_name Main
extends Node
## Holds the current level and the HUD, and moves between places.

@onready var world: Node2D = $World
@onready var week_label: Label = $Hud/Week
@onready var purse_label: Label = $Hud/Purse
@onready var prompt_label: Label = $Hud/Prompt
@onready var panel: PanelContainer = $Hud/Panel
@onready var panel_text: Label = $Hud/Panel/Text
@onready var dialogue: Dialogue = $Hud/Dialogue
@onready var fade: ColorRect = $Hud/Fade

var level: Level
var _error := ""


func _ready() -> void:
	Game.state_changed.connect(_on_state)
	Game.failed.connect(func(message: String) -> void: _error = message)
	show_panel("Loading the village...")
	go_to("village", Village.SPAWN)
	Game.refresh()


func go_to(level_id: String, spawn: Vector2i) -> void:
	Game.busy = true
	if level:
		var out := create_tween()
		out.tween_property(fade, "modulate:a", 1.0, 0.15)
		await out.finished
		level.queue_free()
	level = _make_level(level_id)
	level.setup(self, spawn)
	level.travel.connect(func(id: String, at: Vector2i) -> void: go_to.call_deferred(id, at))
	world.add_child(level)
	show_prompt("")
	hide_panel()
	var back := create_tween()
	back.tween_property(fade, "modulate:a", 0.0, 0.15)
	await back.finished
	Game.busy = false


static func _make_level(level_id: String) -> Level:
	match level_id:
		"shop":
			return ShopRoom.new()
		"tavern":
			return TavernRoom.new()
	return Village.new()


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


func _on_state() -> void:
	_error = ""
	var s := Game.state
	var hint := "[ earlier" + ("   ] later" if Game.weeks_ago > 0 else "")
	if HoardApi.is_demo():
		hint += "   (fake data)"
	week_label.text = "%s to %s   %s" % [_day(s.window.start), _day(s.window.end), hint]
	purse_label.text = "coins %d    extra this week %s" % [
		int(s.coins), Money.fmt(maxi(0, int(s.extra.extra_cents)))
	]


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
