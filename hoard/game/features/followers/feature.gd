class_name FollowersFeature
extends HoardFeature
## Step 3: the flock. The shrine level, the Flock node any level can place, the naming rite,
## and the "while you were out" scene, which plays the away queue when you come back after a
## day line (in the casino, the village or the shrine) and marks it seen.

## The loaded instance, for levels that want the away scene now (the shrine on entry).
static var instance: FollowersFeature
## Tours run with the automatic away scene off unless they turn it on.
static var away_in_tours := false

var _played_day := ""
var _retrying := false


func _init() -> void:
	instance = self
	Game.state_changed.connect(_on_state)


func id() -> String:
	return "followers"


func levels() -> Dictionary:
	return {"shrine": ShrineLevel}


func plot_id() -> String:
	return "shrine"


func door_level() -> String:
	return "shrine"


## On the village plot: a small flame altar with a few nameless cultists chanting around it.
func build_village(village: Level, plot: Rect2i) -> void:
	var px := Rect2(Vector2(plot.position * Level.TILE), Vector2(plot.size * Level.TILE))
	var altar := Sprite2D.new()
	altar.texture = FollowerArt.altar(0)
	altar.offset = Vector2(0, -16)
	altar.position = Vector2(px.get_center().x, px.position.y + 30)
	village.props.add_child(altar)
	var glow := FollowerArt.glow(Color(Palette.GLOW, 0.4), 40.0)
	glow.position = altar.position + Vector2(0, -18)
	village.add_child(glow)
	var flame := altar.create_tween().set_loops()
	for f in 8:
		flame.tween_callback(func() -> void: altar.texture = FollowerArt.altar(f))
		flame.tween_interval(0.1)
	var flock := Flock.new("cultists", px.grow_individual(-4, -6, -4, -18))
	flock.max_cultists = 5
	flock.interactive = false
	flock.shrine_point = altar.position + Vector2(0, 8)
	village.props.add_child(flock)


# --- while you were out -------------------------------------------------------------------------


func _on_state() -> void:
	if Game.state.is_empty() or (Game.state.get("away", []) as Array).is_empty():
		return
	if str(Game.state.get("today", "")) == _played_day or Game.weeks_ago != 0:
		return
	var main := find_main()
	if main == null or (_in_tour() and not away_in_tours):
		return
	if Game.busy or main.get("level") == null:
		_retry()
		return
	if _at_hub(main):
		play_away_now(main)


func _retry() -> void:
	if _retrying:
		return
	_retrying = true
	await (Engine.get_main_loop() as SceneTree).create_timer(0.6).timeout
	_retrying = false
	_on_state()


func _at_hub(main: Node) -> bool:
	var lvl: Node = main.get("level")
	var casino := Features.level_script("casino")
	return lvl is Village or lvl is ShrineLevel or (casino != null and lvl.get_script() == casino)


## Play whatever is in the away queue now (the shrine calls this on entry).
func play_away_now(main: Node) -> void:
	var away: Array = Game.state.get("away", [])
	if away.is_empty() or Game.busy or main == null or (_in_tour() and not away_in_tours):
		return
	_played_day = str(Game.state.get("today", ""))
	await main.open_overlay(WhileYouWereOutOverlay.new(away))


static func find_main() -> Node:
	var root := (Engine.get_main_loop() as SceneTree).root
	for n in root.get_children():
		if n is Main:
			return n
		for m in n.get_children():
			if m is Main:
				return m
	return null


static func _in_tour() -> bool:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Tour") != null
