extends Node2D
## The village. Builds the tilemap and buildings once, then re-dresses the world
## from /state: crops, tavern, drains, shrine. Every reaction state comes from
## the backend; this script only draws it.

const TILE := 16
const MAP := [
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"T......................................T",
	"T..................................T...T",
	"TT..................................T..T",
	"T.....,................................T",
	"T..............,.......................T",
	"T..ssssssss...........,................T",
	"T..ssssssss.......................,....T",
	"T..ssssssss........................,...T",
	"T..ssssssss.......,.=.......,.=........T",
	"T......=...,........=.........=.,......T",
	"T.,...,=...,..,.....=..,......=........T",
	"T======================================T",
	"T....,........=...........=..,...,.....T",
	"T.......,.....=...........=............T",
	"T...............................,......T",
	"T.............................,......,TT",
	"T.,.......,..........................T.T",
	"TT.............,.......................T",
	"T.T..........,..,....,.........,.....,.T",
	"TT...................,................TT",
	"T,....,................................T",
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
]
const TILE_INDEX := {".": 0, ",": 1, "=": 2, "~": 3, "s": 5, "T": 6}
const LOW_WATER := 4
const RIVER_EDGE_ROW := 4
const BANK_ROW := 5
const SPAWN := Vector2i(20, 17)

# Building footprints in tiles: x, y, w, h.
const HOUSE_PLOT := Rect2i(19, 10, 3, 3)
const TAVERN := Rect2i(29, 10, 4, 3)
const SHRINE := Rect2i(13, 19, 2, 3)
const SHOP := Rect2i(25, 19, 3, 3)
const BOARD := Rect2i(21, 15, 1, 1)
const FIELDS := Rect2i(3, 10, 8, 4)
const RIVER := Rect2i(0, 2, 40, 5)

const CROP_FRAME := {"bumper": 0, "healthy": 1, "wilting": 2, "withered": 3}

@onready var ground: TileMapLayer = $Ground
@onready var props: Node2D = $Props
@onready var dynamic: Node2D = $Props/Dynamic
@onready var leader: Leader = $Props/Leader
@onready var camera: Camera2D = $Props/Leader/Camera2D
@onready var api: HoardApi = $Api
@onready var week_label: Label = $Hud/Week
@onready var purse_label: Label = $Hud/Purse
@onready var panel: PanelContainer = $Hud/Panel
@onready var panel_text: Label = $Hud/Panel/Text

var state: Dictionary = {}
var weeks_ago := 0
var _blocked: Dictionary = {}  # Vector2i -> true
var _zones: Array[Dictionary] = []  # {rect: Rect2, text: Callable}
var _error := ""
var _shrine_sprite: Sprite2D


func _ready() -> void:
	_add_wasd()
	_build_ground()
	_build_buildings()
	leader.position = Vector2(SPAWN.x * TILE + TILE / 2.0, (SPAWN.y + 1) * TILE)
	leader.is_walkable = _is_walkable
	camera.limit_right = MAP[0].length() * TILE
	camera.limit_bottom = MAP.size() * TILE
	api.state_loaded.connect(_on_state)
	api.failed.connect(_on_failed)
	_show_panel("Loading the village...")
	api.fetch_state(weeks_ago)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo) or state.is_empty():
		return
	var key := (event as InputEventKey).keycode
	if key == KEY_BRACKETLEFT and weeks_ago < int(state.history_weeks) - 1:
		weeks_ago += 1
		api.fetch_state(weeks_ago)
	elif key == KEY_BRACKETRIGHT and weeks_ago > 0:
		weeks_ago -= 1
		api.fetch_state(weeks_ago)


func _process(_delta: float) -> void:
	if _error != "":
		_show_panel(_error)
		return
	if state.is_empty():
		return
	for zone: Dictionary in _zones:
		if (zone.rect as Rect2).has_point(leader.position):
			_show_panel((zone.text as Callable).call())
			return
	panel.visible = false


# --- world -------------------------------------------------------------------

func _add_wasd() -> void:
	for pair: Array in [["ui_left", KEY_A], ["ui_right", KEY_D], ["ui_up", KEY_W], ["ui_down", KEY_S]]:
		var ev := InputEventKey.new()
		ev.physical_keycode = pair[1]
		InputMap.action_add_event(pair[0], ev)


func _build_ground() -> void:
	var source := TileSetAtlasSource.new()
	source.texture = preload("res://art/tiles.png")
	source.texture_region_size = Vector2i(TILE, TILE)
	for i in 8:
		source.create_tile(Vector2i(i, 0))
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(TILE, TILE)
	tiles.add_source(source, 0)
	ground.tile_set = tiles
	for y in MAP.size():
		var row: String = MAP[y]
		for x in row.length():
			var ch := row[x]
			ground.set_cell(Vector2i(x, y), 0, Vector2i(TILE_INDEX[ch], 0))
			if ch == "T" or ch == "~":
				_blocked[Vector2i(x, y)] = true


func _build_buildings() -> void:
	_place(preload("res://art/house_plot.png"), HOUSE_PLOT)
	_place(preload("res://art/tavern.png"), TAVERN)
	_place(preload("res://art/shop.png"), SHOP)
	_place(preload("res://art/sign.png"), BOARD)
	_shrine_sprite = _place(preload("res://art/shrine.png"), SHRINE, 2)
	for r: Rect2i in [TAVERN, SHOP, SHRINE, BOARD]:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				_blocked[Vector2i(x, y)] = true

	_zone(FIELDS, _fields_text)
	_zone(TAVERN, _tavern_text)
	_zone(SHRINE, _shrine_text)
	_zone(SHOP, _shop_text)
	_zone(HOUSE_PLOT, _house_text, 0)
	_zone(BOARD, _board_text, 2)
	_zone(RIVER, _river_text)


func _place(tex: Texture2D, footprint: Rect2i, hframes := 1, parent: Node = null) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.hframes = hframes
	var h := tex.get_height()
	s.offset = Vector2(0, -h / 2.0)
	s.position = Vector2(
		(footprint.position.x + footprint.size.x / 2.0) * TILE, footprint.end.y * TILE
	)
	(parent if parent else props).add_child(s)
	return s


func _zone(r: Rect2i, text: Callable, grow := 1) -> void:
	var px := Rect2(Vector2(r.position * TILE), Vector2(r.size * TILE)).grow(grow * TILE)
	_zones.append({"rect": px, "text": text})


func _is_walkable(feet: Rect2) -> bool:
	var a := Vector2i((feet.position / TILE).floor())
	var b := Vector2i((feet.end / TILE).floor())
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			if y < 0 or x < 0 or y >= MAP.size() or x >= MAP[0].length():
				return false
			if _blocked.has(Vector2i(x, y)):
				return false
	return true


# --- reactions ---------------------------------------------------------------

func _on_state(s: Dictionary) -> void:
	state = s
	_error = ""
	for child in dynamic.get_children():
		child.queue_free()
	_dress_crops()
	_dress_tavern()
	_dress_river()
	_shrine_sprite.frame = 1 if s.shrine.state == "glowing" else 0
	var w: Dictionary = s.window
	var hint := "[ earlier" + ("   ] later" if weeks_ago > 0 else "")
	week_label.text = "%s to %s   %s" % [_day(w.start), _day(w.end), hint]
	purse_label.text = "coins %d    extra this week %s" % [
		int(s.coins), Money.fmt(maxi(0, int(s.extra.extra_cents)))
	]


func _on_failed(message: String) -> void:
	_error = message


func _dress_crops() -> void:
	var crops: Dictionary = state.crops
	var main: int = CROP_FRAME[crops.state]
	# Wilting and withered fields keep a few plants one stage better, so it reads
	# as a field having a bad week rather than a dead one.
	for y in range(FIELDS.position.y, FIELDS.end.y):
		for x in range(FIELDS.position.x, FIELDS.end.x):
			var s := Sprite2D.new()
			s.texture = preload("res://art/crops.png")
			s.hframes = 4
			var better := main >= 2 and (x * 7 + y * 13) % 4 == 0
			s.frame = main - 1 if better else main
			s.offset = Vector2(0, -8)
			s.position = Vector2(x * TILE + 8, (y + 1) * TILE)
			dynamic.add_child(s)


func _dress_tavern() -> void:
	var tavern: Dictionary = state.tavern
	var packed: bool = tavern.state == "packed"
	var count := mini(int(tavern.visits), 8 if packed else 3)
	for i in count:
		var s := Sprite2D.new()
		s.texture = preload("res://art/villager.png")
		s.hframes = 2
		s.frame = 1 if packed else 0  # packed tavern, lazy followers
		s.offset = Vector2(0, -8)
		if i < 4:  # along the front
			s.position = Vector2((TAVERN.position.x + i) * TILE + 8, (TAVERN.end.y + 1) * TILE)
		else:  # spilling round the side
			var j := i - 4
			s.position = Vector2((TAVERN.end.x + j % 2) * TILE + 8, (TAVERN.position.y + 1 + j / 2) * TILE)
		dynamic.add_child(s)
	if not packed:
		var coin := Sprite2D.new()
		coin.texture = preload("res://art/coin.png")
		coin.position = Vector2((TAVERN.position.x + 2.5) * TILE, (TAVERN.end.y) * TILE - 40)
		dynamic.add_child(coin)
		var tw := coin.create_tween().set_loops()
		tw.tween_property(coin, "position:y", coin.position.y - 4, 0.6)
		tw.tween_property(coin, "position:y", coin.position.y, 0.6)


func _dress_river() -> void:
	var river: Dictionary = state.drains
	var low: bool = river.river == "low"
	for x in MAP[0].length():
		ground.set_cell(Vector2i(x, RIVER_EDGE_ROW), 0, Vector2i(LOW_WATER if low else 3, 0))
	var drains: Array = river.drains
	for i in drains.size():
		var d: Dictionary = drains[i]
		var x := 4 + i * 9
		var s := Sprite2D.new()
		s.texture = preload("res://art/drain.png")
		s.hframes = 2
		s.frame = 1 if d.charged_this_week else 0
		s.centered = false
		s.position = Vector2(x * TILE, BANK_ROW * TILE - 4)
		dynamic.add_child(s)
		var label := Label.new()
		label.text = ("new: " if d.new else "") + str(d.merchant)
		label.label_settings = _small_text()
		label.position = Vector2(x * TILE - 16, BANK_ROW * TILE + 10)
		label.size = Vector2(48, 10)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dynamic.add_child(label)
		if d.charged_this_week:
			var tw := s.create_tween().set_loops()
			tw.tween_property(s, "modulate:a", 0.6, 0.5)
			tw.tween_property(s, "modulate:a", 1.0, 0.5)


func _small_text() -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font_size = 6
	ls.outline_size = 2
	ls.outline_color = Color(0.17, 0.15, 0.13)
	ls.font_color = Color(0.96, 0.93, 0.86)
	return ls


# --- panel text --------------------------------------------------------------

func _show_panel(text: String) -> void:
	panel_text.text = text
	panel.visible = true


func _day(iso: String) -> String:
	const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var parts := iso.split("-")
	return "%s %d" % [MONTHS[int(parts[1]) - 1], int(parts[2])]


func _c(v: Variant) -> String:
	return Money.fmt(int(v))


func _fields_text() -> String:
	var c: Dictionary = state.crops
	var line: String = {
		"bumper": "Well under budget. Bumper harvest.",
		"healthy": "Under budget. The crops are healthy.",
		"wilting": "Over budget. The crops are wilting.",
		"withered": "Well over budget. The crops have withered.",
	}[c.state]
	return "Fields\nGroceries for the week: %s of %s.\n%s" % [
		_c(c.spent_cents), _c(c.budget_cents), line
	]


func _tavern_text() -> String:
	var t: Dictionary = state.tavern
	var line := (
		"Over budget. Packed, and the regulars will be lazy tomorrow."
		if t.state == "packed"
		else "Under budget. Quiet, and a few coins trickle in."
	)
	return "Tavern\nEating out for the week: %s of %s across %d visits.\n%s" % [
		_c(t.spent_cents), _c(t.budget_cents), int(t.visits), line
	]


func _river_text() -> String:
	var r: Dictionary = state.drains
	var lines := PackedStringArray()
	lines.append("River")
	lines.append("Subscriptions in the last 30 days: %s of %s." % [_c(r.monthly_cents), _c(r.budget_cents)])
	lines.append("Over budget, so the river runs low." if r.river == "low" else "Under budget. The river is high.")
	for d: Dictionary in r.drains:
		var note := "new this week" if d.new else "last charged %s" % _day(d.last_charged)
		lines.append("  %s  %s  (%s)" % [d.merchant, _c(d.amount_cents), note])
	return "\n".join(lines)


func _shrine_text() -> String:
	var saved := int(state.shrine.saved_cents)
	if saved > 0:
		return "Shrine\nMoved to savings that week: %s.\nThe shrine is glowing." % Money.fmt(saved)
	return "Shrine\nNothing moved to savings that week.\nThe shrine is dim."


func _shop_text() -> String:
	var e: Dictionary = state.extra
	if int(e.extra_cents) <= 0:
		return "Shop\nNothing extra this week. Cases are greyed out until next week."
	return "Shop\nExtra this week: %s. Case cap left: %s.\nThe shop opens in Phase 1." % [
		_c(e.extra_cents), _c(e.cap_remaining_cents)
	]


func _house_text() -> String:
	var h: Dictionary = state.house
	return "House plot\n%s: %s.\nBuilding stages start in Phase 2." % [h.name, _c(h.balance_cents)]


func _board_text() -> String:
	var w: Dictionary = state.week
	var by: Dictionary = w.by_system
	var names: Array = by.keys().filter(func(k: String) -> bool: return by[k] > 0)
	names.sort_custom(func(a: String, b: String) -> bool: return by[a] > by[b])
	var lines := PackedStringArray()
	lines.append("Notice board: %s to %s" % [_day(state.window.start), _day(state.window.end)])
	lines.append("In %s.  Out %s." % [_c(w.in_cents), _c(w.out_cents)])
	for n: String in names:
		lines.append("  %s  %s" % [state.systems.get(n, n), _c(by[n])])
	return "\n".join(lines)
