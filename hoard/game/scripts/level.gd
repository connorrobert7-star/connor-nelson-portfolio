class_name Level
extends Node2D
## Base for every place you can stand: the village and each interior.
## Subclasses fill `map` and `legend` in build(), place things, and redraw the
## parts that depend on /state in dress().

signal travel(level_id: String, spawn: Vector2i)

const TILE := 16
const REACH := 18.0
const NPC_FRAMES := {"shopkeeper": 0, "tavern_keeper": 1, "farmer": 2, "shrine_keeper": 3}

var map: Array[String] = []
var legend: Dictionary = {}  # char -> atlas index
var solid := ""  # chars you can't walk through
var follow_camera := true
var main: Node  # scripts/main.gd

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
	var size := Vector2(map[0].length(), map.size()) * TILE
	if follow_camera:
		leader.add_child(camera)
		camera.limit_left = 0
		camera.limit_top = 0
		camera.limit_right = int(size.x)
		camera.limit_bottom = int(size.y)
	else:
		camera.position = size / 2.0
		add_child(camera)
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


func _process(_delta: float) -> void:
	if Game.busy or Game.state.is_empty():
		return
	for door: Dictionary in _doors:
		if (door.rect as Rect2).has_point(leader.position):
			Game.busy = true
			travel.emit(door.level, door.spawn)
			return
	var it := nearest_interactable()
	main.show_prompt("E  " + (it.label as Callable).call() if not it.is_empty() else "")
	for zone: Dictionary in _zones:
		if (zone.rect as Rect2).has_point(leader.position):
			main.show_panel((zone.text as Callable).call())
			return
	main.hide_panel()


func _unhandled_input(event: InputEvent) -> void:
	if Game.busy or not event.is_action_pressed("interact"):
		return
	var it := nearest_interactable()
	if not it.is_empty():
		get_viewport().set_input_as_handled()
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


## A villager standing on `tile`; you talk to them from `talk_from`.
func add_npc(npc_id: String, tile: Vector2i, talk_from: Vector2i) -> void:
	var s := Sprite2D.new()
	s.texture = preload("res://art/npcs.png")
	s.hframes = 4
	s.frame = NPC_FRAMES[npc_id]
	s.offset = Vector2(0, -14)
	s.position = feet_at(tile)
	props.add_child(s)
	_blocked[tile] = true
	add_interactable(
		tile_center(talk_from),
		func() -> String: return "Talk to " + str(Game.state.dialogue[npc_id].name),
		func() -> void: talk(npc_id)
	)


## Walking onto `tile` takes you to `level_id`, arriving at `spawn`.
func add_door(tile: Vector2i, level_id: String, spawn: Vector2i) -> void:
	_open[tile] = true
	_blocked.erase(tile)
	var r := Rect2(Vector2(tile * TILE), Vector2(TILE, TILE)).grow(-3)
	_doors.append({"rect": r, "level": level_id, "spawn": spawn})


func talk(npc_id: String) -> void:
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
	ls.font_size = 6
	ls.outline_size = 2
	ls.outline_color = Color(0.17, 0.15, 0.13)
	ls.font_color = Color(0.96, 0.93, 0.86)
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
