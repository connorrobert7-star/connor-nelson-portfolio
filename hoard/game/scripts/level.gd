class_name Level
extends Node2D
## Base for every place you can stand: the village and each interior.
## Subclasses fill `map` and `legend` in build(), place things, and redraw the
## parts that depend on /state in dress().

signal travel(level_id: String, spawn: Vector2i)

const TILE := 16
const REACH := 18.0
## How close a tap has to land to an interactable's spot to count as tapping it.
const TAP_RADIUS := 20.0
const NPC_FRAMES := {"shopkeeper": 0, "tavern_keeper": 1, "farmer": 2, "shrine_keeper": 3}
## Spawn value for a door that leads back to wherever the player came from.
const RETURN := Vector2i(-1, -1)

var map: Array[String] = []
var legend: Dictionary = {}  # char -> atlas index
var solid := ""  # chars you can't walk through
var follow_camera := true
var main: Node  # scripts/main.gd
## How deep the shared post-process vignette goes here. Rooms that draw their own dark
## set 0 so the corners aren't darkened twice.
var post_vignette := 0.3
## False where the scene shows money moving on a thing itself (the gate boss's balance),
## so no plate covers the number the owner wants to see drop.
var money_toasts := true

var ground := TileMapLayer.new()
var props := Node2D.new()
var dynamic := Node2D.new()
var leader := Leader.new()
var camera := Camera2D.new()

var _spawn := Vector2i.ZERO
var _blocked: Dictionary = {}  # Vector2i -> true
var _open: Dictionary = {}  # Vector2i -> true, walkable despite the map (doors)
var _zones: Array[Dictionary] = []  # {rect, text: Callable}
var _interactables: Array[Dictionary] = []  # {pos, label: Callable, action: Callable}
var _doors: Array[Dictionary] = []  # {rect, level, spawn}
var _pending: Dictionary = {}  # the interactable a tap is walking to
var _cam_pos := Vector2.ZERO  # the camera's smooth position (applied rounded)
var _cam_lead := Vector2.ZERO
var _marker: Node2D  # the chevron over a tapped thing, until the leader gets there

## Camera feel: how far ahead it leads the walk, and how quickly it follows.
const CAM_LEAD := 14.0
const CAM_FOLLOW := 7.0


func setup(main_node: Node, spawn: Vector2i) -> void:
	main = main_node
	_spawn = spawn


func _ready() -> void:
	add_child(ground)
	props.y_sort_enabled = true
	dynamic.y_sort_enabled = true
	add_child(props)
	props.add_child(dynamic)
	props.add_child(leader)
	build()
	_paint()
	leader.position = feet_at(_spawn)
	leader.is_walkable = is_walkable
	leader.arrived.connect(func() -> void:
		_clear_marker()
		if not _pending.is_empty() and leader.position.distance_to(_pending.pos) < REACH + 6:
			leader.hop()
			_use_pending()
	)
	leader.surface_at = surface_at
	var size := Vector2(map[0].length(), map.size()) * TILE
	add_child(camera)
	if follow_camera:
		# The camera is the leader's sibling, not his child: it eases after him with a
		# little lead instead of jerking with every step.
		camera.limit_left = 0
		camera.limit_top = 0
		camera.limit_right = int(size.x)
		camera.limit_bottom = int(size.y)
		_cam_pos = _cam_target(Vector2.ZERO)
		camera.position = _cam_pos.round()
	else:
		camera.position = size / 2.0
	camera.make_current()
	Game.state_changed.connect(_redress)
	if not Game.state.is_empty():
		_redress()


func build() -> void:
	pass


func dress() -> void:
	pass


func _redress() -> void:
	for child in dynamic.get_children():
		child.queue_free()
	dress()


func _process(delta: float) -> void:
	_follow(delta)
	if _marker and leader.target == Vector2.INF:
		_clear_marker()
	if Game.busy or Game.state.is_empty():
		return
	for door: Dictionary in _doors:
		if (door.rect as Rect2).has_point(leader.position):
			Game.busy = true
			if door.level != "village":
				main.village_return = door.tile + Vector2i.DOWN
			travel.emit(door.level, door.spawn)
			return
	for zone: Dictionary in _zones:
		if (zone.rect as Rect2).has_point(leader.position):
			main.show_panel((zone.text as Callable).call())
			return
	main.hide_panel()


# --- camera ----------------------------------------------------------------------

## Ease toward the leader plus a lead in the walk direction, rounded to whole pixels.
## A zoomed camera belongs to whoever zoomed it (close-ups), so it's left alone.
func _follow(delta: float) -> void:
	if not follow_camera or camera.zoom != Vector2.ONE:
		return
	var dir := leader.walk_dir
	if leader.target != Vector2.INF:
		dir = (leader.target - leader.position).normalized()
	_cam_lead = _cam_lead.lerp(dir * CAM_LEAD, 1.0 - exp(-delta / 0.4 * 3.0))
	_cam_pos = _cam_pos.lerp(_cam_target(_cam_lead), 1.0 - exp(-CAM_FOLLOW * delta))
	camera.position = _cam_pos.round()


## Where the camera wants to be, kept inside the limits so it never drifts past an edge.
func _cam_target(lead: Vector2) -> Vector2:
	var t := leader.position + lead
	var half := get_viewport_rect().size / 2.0 / camera.zoom
	var lo := Vector2(camera.limit_left, camera.limit_top) + half
	var hi := Vector2(camera.limit_right, camera.limit_bottom) - half
	t.x = clampf(t.x, lo.x, hi.x) if lo.x <= hi.x else (lo.x + hi.x) / 2.0
	t.y = clampf(t.y, lo.y, hi.y) if lo.y <= hi.y else (lo.y + hi.y) / 2.0
	return t


## What the ground under `feet` sounds like: grass, concrete, wood or carpet.
## Levels can override this; the default reads the map.
func surface_at(feet: Vector2) -> String:
	if self is ShopRoom or self is TavernRoom:
		return "wood"
	var path := (get_script() as Script).resource_path
	if path.contains("casino"):
		var mid := map[0].length() * TILE / 2.0 if not map.is_empty() else 0.0
		return "carpet" if absf(feet.x - mid) < TILE * 1.5 else "concrete"
	var cell := Vector2i((feet / TILE).floor())
	if cell.y < 0 or cell.y >= map.size() or cell.x < 0 or cell.x >= map[cell.y].length():
		return "concrete"
	var ch := map[cell.y][cell.x]
	if self is Village:
		return "grass" if ".,*".contains(ch) else "concrete"
	if ch == "r":
		return "carpet"
	return "concrete"


func _unhandled_input(event: InputEvent) -> void:
	if Game.busy:
		return
	if _is_tap(event):
		get_viewport().set_input_as_handled()
		_on_tap((make_input_local(event) as InputEventMouseButton).position if event is InputEventMouseButton else (make_input_local(event) as InputEventScreenTouch).position)
		return
	if not event.is_action_pressed("interact"):
		return
	var it := nearest_interactable()
	if not it.is_empty():
		get_viewport().set_input_as_handled()
		(it.action as Callable).call()


static func _is_tap(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	return event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed


## A click or tap in the world: walk to it, and use whatever was tapped once there.
func _on_tap(point: Vector2) -> void:
	var tapped: Dictionary = {}
	var best := TAP_RADIUS
	for it: Dictionary in _interactables:
		var d := point.distance_to(it.pos)
		if d < best:
			best = d
			tapped = it
	_clear_marker()
	if tapped.is_empty():
		_pending = {}
		var ok := is_walkable(Rect2(point + Leader.FOOT.position, Leader.FOOT.size))
		TapMarker.spawn(self, point, "ground" if ok else "nope")
		Sfx.ui("tap", randf_range(0.95, 1.05))
		leader.walk_to(point)
		return
	_pending = tapped
	TapMarker.spawn(self, point, "thing")
	Sfx.ui("select")
	if leader.position.distance_to(tapped.pos) < REACH:
		leader.hop()
		_use_pending()
	else:
		_marker = TapMarker.chevron(self, tapped.pos)
		leader.walk_to(tapped.pos)


func _clear_marker() -> void:
	if _marker and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null


func _use_pending() -> void:
	if _pending.is_empty() or Game.busy:
		return
	var it := _pending
	_pending = {}
	(it.action as Callable).call()


func nearest_interactable() -> Dictionary:
	var best: Dictionary = {}
	var best_d := REACH
	for it: Dictionary in _interactables:
		var d := leader.position.distance_to(it.pos)
		if d < best_d:
			best_d = d
			best = it
	return best


# --- building helpers ----------------------------------------------------------

func feet_at(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * TILE + TILE / 2.0, (tile.y + 1) * TILE - 1)


func tile_center(tile: Vector2i) -> Vector2:
	return Vector2(tile) * TILE + Vector2(TILE, TILE) / 2.0


func _paint() -> void:
	var tex: Texture2D = preload("res://art/tiles.png")
	var source := TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = Vector2i(TILE, TILE)
	for i in tex.get_width() / TILE:
		source.create_tile(Vector2i(i, 0))
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(TILE, TILE)
	tiles.add_source(source, 0)
	ground.tile_set = tiles
	for y in map.size():
		for x in map[y].length():
			var ch := map[y][x]
			set_tile(Vector2i(x, y), legend[ch])
			if solid.contains(ch) and not _open.has(Vector2i(x, y)):
				_blocked[Vector2i(x, y)] = true


func set_tile(cell: Vector2i, index: int) -> void:
	ground.set_cell(cell, 0, Vector2i(index, 0))


func block(r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			_blocked[Vector2i(x, y)] = true


func place(tex: Texture2D, footprint: Rect2i, hframes := 1, parent: Node = null) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.hframes = hframes
	s.offset = Vector2(0, -tex.get_height() / 2.0)
	s.position = Vector2((footprint.position.x + footprint.size.x / 2.0) * TILE, footprint.end.y * TILE)
	(parent if parent else props).add_child(s)
	return s


func add_zone(r: Rect2i, text: Callable, grow := 1) -> void:
	var px := Rect2(Vector2(r.position * TILE), Vector2(r.size * TILE)).grow(grow * TILE)
	_zones.append({"rect": px, "text": text})


func add_interactable(pos: Vector2, label: Callable, action: Callable) -> void:
	_interactables.append({"pos": pos, "label": label, "action": action})


## The sprite sheet, frame and frame count for a villager, from a feature or the core four.
static func npc_look(npc_id: String) -> Dictionary:
	var look := Features.npc(npc_id)
	if not look.is_empty():
		return look
	return {"texture": preload("res://art/npcs.png"), "frame": NPC_FRAMES.get(npc_id, 0), "hframes": 4}


## A villager standing on `tile`; you talk to them from `talk_from`.
## Their name and lines come from Game.state.dialogue[npc_id].
func add_npc(npc_id: String, tile: Vector2i, talk_from: Vector2i, action: Callable = Callable()) -> Sprite2D:
	var look := npc_look(npc_id)
	var s := Sprite2D.new()
	s.texture = look.texture
	s.hframes = int(look.get("hframes", 1))
	s.frame = int(look.get("frame", 0))
	s.offset = Vector2(0, -s.texture.get_height() / 2.0 + 2)
	s.position = feet_at(tile)
	props.add_child(s)
	_blocked[tile] = true
	add_interactable(
		tile_center(talk_from),
		func() -> String: return "Talk to " + str(Game.state.get("dialogue", {}).get(npc_id, {}).get("name", "them")),
		action if action.is_valid() else func() -> void: talk(npc_id)
	)
	return s


## Walking onto `tile` takes you to `level_id`, arriving at `spawn`.
func add_door(tile: Vector2i, level_id: String, spawn: Vector2i) -> void:
	_open[tile] = true
	_blocked.erase(tile)
	var r := Rect2(Vector2(tile * TILE), Vector2(TILE, TILE)).grow(-3)
	_doors.append({"rect": r, "level": level_id, "spawn": spawn, "tile": tile})


func talk(npc_id: String) -> void:
	if not Game.state.get("dialogue", {}).has(npc_id):
		return
	var npc: Dictionary = Game.state.dialogue[npc_id]
	var d: Dialogue = main.dialogue
	d.open(npc_id, npc.name)
	await d.say(npc.lines)
	d.close()


func is_walkable(feet: Rect2) -> bool:
	var a := Vector2i((feet.position / TILE).floor())
	var b := Vector2i((feet.end / TILE).floor())
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			if y < 0 or x < 0 or y >= map.size() or x >= map[0].length():
				return false
			if _blocked.has(Vector2i(x, y)):
				return false
	return true


func small_label(text: String, pos: Vector2, width := 48.0) -> Label:
	var ls := LabelSettings.new()
	ls.font = preload("res://art/ui/fonts/m5x7.ttf")
	ls.font_size = 16
	ls.outline_size = 2
	ls.outline_color = Palette.NIGHT
	ls.font_color = Palette.CREAM
	var label := Label.new()
	label.text = text
	label.label_settings = ls
	label.position = pos - Vector2(width / 2.0, 0)
	label.size = Vector2(width, 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


static func c(v: Variant) -> String:
	return Money.fmt(int(v))


static func hours(h: Variant) -> String:
	return "%.1f h of work" % float(h)
