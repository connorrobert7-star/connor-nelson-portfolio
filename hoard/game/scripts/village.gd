class_name Village
extends Level
## The village hub, at night, on an island about twice the size it was. The old village
## (parcel "home") still sits under the river: loud doors around a stone square lead to the
## casino, the arcade, the shrine and the gate. South of the square the commons run down to
## the wall: the fields, the granary, the ossuary and room for the flock to roam. East of
## both, three parcels wait behind rope lines and haze until their land tier is built
## (VillageParcel). The house builds itself out of the House Fund; the town wall is the
## Emergency Fund; ruined buildings wait behind offering tablets. Numbers are painted on
## things; the only table of numbers is the ledger stone. Every state comes from the backend
## (Game.state); this script only draws it.

## A gated parcel just opened (after its reveal, or at once when the village loads open).
signal parcel_opened(parcel_id: String)

const W := 62
const H := 40
const RIVER_EDGE_ROW := 4
const BANK_ROW := 5
const FRONT_ROAD_ROW := 12  # the road in front of the top row of buildings
const ROAD_ROW := 33  # the road inside the wall
const WALL_BASE_ROW := 37  # the wall stands on this line and rises over rows 34-36
## Map char -> ground index (see GROUND).
const LEGEND := {".": 0, ",": 1, "*": 2, "=": 3, "#": 4, "~": 5, "T": 7, "w": 8, "x": 9}
const PLAZA_TINT := Color(0.66, 0.66, 0.62)
const GRASS_TINT := Color(0.6, 0.6, 0.7)
## Ground tiles, all from packs: [sheet, Vector2i(col, row)] on a 16 px grid.
## A third value darkens that tile further at night (each tint is its own alternative tile,
## so two entries can share a pack tile and still differ).
const GROUND := [
	[VillageArt.TOWN, Vector2i(0, 0), GRASS_TINT],  # 0 grass
	[VillageArt.TOWN, Vector2i(1, 0), GRASS_TINT],  # 1 grass tufts
	[VillageArt.TOWN, Vector2i(2, 0), GRASS_TINT],  # 2 flowers
	[VillageArt.FLOOR, Vector2i(17, 16), Color(0.7, 0.65, 0.75)],  # 3 road
	[VillageArt.TOWN, Vector2i(1, 9), PLAZA_TINT],  # 4 square stone
	[VillageArt.WATER, Vector2i(11, 1), Color(0.75, 0.7, 1.0)],  # 5 river
	[VillageArt.TOWN, Vector2i(4, 3), Color(0.7, 0.6, 0.6)],  # 6 low river (mud)
	[VillageArt.TOWN, Vector2i(0, 0), Color(0.5, 0.5, 0.62)],  # 7 under trees
	[VillageArt.FLOOR, Vector2i(17, 16), Color(0.6, 0.55, 0.65)],  # 8 under the wall
	[VillageArt.TOWN, Vector2i(5, 3), Color(0.35, 0.3, 0.4)],  # 9 outside the wall
	[VillageArt.TOWN, Vector2i(1, 0), Color(0.4, 0.42, 0.44)],  # 10 wild ground (not yours yet)
	[VillageArt.TOWN, Vector2i(0, 0), Color(0.34, 0.36, 0.4)],  # 11 wild ground, darker
	[VillageArt.TOWN, Vector2i(0, 8), PLAZA_TINT],  # 12 square edge: top left
	[VillageArt.TOWN, Vector2i(1, 8), PLAZA_TINT],  # 13 top
	[VillageArt.TOWN, Vector2i(2, 8), PLAZA_TINT],  # 14 top right
	[VillageArt.TOWN, Vector2i(0, 9), PLAZA_TINT],  # 15 left
	[VillageArt.TOWN, Vector2i(2, 9), PLAZA_TINT],  # 16 right
	[VillageArt.TOWN, Vector2i(0, 10), PLAZA_TINT],  # 17 bottom left
	[VillageArt.TOWN, Vector2i(1, 10), PLAZA_TINT],  # 18 bottom
	[VillageArt.TOWN, Vector2i(2, 10), PLAZA_TINT],  # 19 bottom right
]
const WILD_GROUND := 10
const LOW_WATER := 6
const SPAWN := Vector2i(24, 17)
const NIGHT_GROUND := Color(0.36, 0.3, 0.46)

## The island, in parcels (tile rects). home and commons are open from day one; east, south
## and north open when Game.state.buildings.land.parcels lists them (land tiers 2 to 4, in
## this order, which is also the order their reveals play in).
## `land` picks how a gated parcel is dressed; `stake` is where its survey stake stands.
const PARCELS := {
	"home": {"rect": Rect2i(1, 5, 42, 19)},
	"commons": {"rect": Rect2i(1, 24, 42, 10)},
	"east": {"rect": Rect2i(43, 13, 18, 11), "land": "reach", "stake": Vector2i(45, 18)},
	"south": {"rect": Rect2i(43, 24, 18, 10), "land": "meadow", "stake": Vector2i(45, 28)},
	"north": {"rect": Rect2i(43, 5, 18, 8), "land": "cliffs", "stake": Vector2i(45, 9)},
}
const START_PARCELS := ["home", "commons"]
## Cultists that move into a gated parcel when it opens.
const SETTLERS_PER_PARCEL := 2

const ARCADE := Rect2i(2, 8, 6, 4)
const TAVERN := Rect2i(11, 8, 4, 4)
const TAVERN_DOOR := Vector2i(12, 11)
const SHRINE := Rect2i(30, 8, 6, 4)
const HOUSE_PLOT := Rect2i(3, 15, 6, 4)
## Where the buildings feature draws each building with tiers: `rect` is the footprint (its
## facade blocks it), `feet` the tile at its door / bottom middle, `sign` and `flag` the clear
## tiles beside it for the next tier's signpost and the target banner's pole. `parcel` is the
## land it stands on (the lodge's plot is overgrown until the east reach opens).
## Use Village.building_plots() for the same with pixel anchors worked out.
const BUILDING_PLOTS := {
	"house": {"parcel": "home", "rect": HOUSE_PLOT, "feet": Vector2i(5, 18), "sign": Vector2i(1, 18), "flag": Vector2i(10, 18)},
	"arcade": {"parcel": "home", "rect": ARCADE, "feet": Vector2i(5, 11), "sign": Vector2i(1, 11), "flag": Vector2i(8, 11)},
	"tavern": {"parcel": "home", "rect": TAVERN, "feet": TAVERN_DOOR, "sign": Vector2i(10, 11), "flag": Vector2i(15, 11)},
	"shrine": {"parcel": "home", "rect": SHRINE, "feet": Vector2i(32, 11), "sign": Vector2i(28, 11), "flag": Vector2i(37, 11)},
	"lodge": {"parcel": "east", "rect": Rect2i(50, 15, 7, 4), "feet": Vector2i(53, 18), "sign": Vector2i(48, 18), "flag": Vector2i(58, 18)},
}

## Plots features build on: plot_id -> {rect, door}. `door` is the tile in the plot's
## bottom row that leads inside once a feature registers a level for it.
const PLOTS := {
	"arcade": {"rect": ARCADE, "door": Vector2i(5, 11)},
	"casino": {"rect": Rect2i(20, 7, 4, 5), "door": Vector2i(21, 11), "wide": true},
	"shrine": {"rect": SHRINE, "door": Vector2i(32, 11)},
	"gate": {"rect": Rect2i(20, 33, 4, 4), "door": Vector2i(21, 36), "wide": true},
}
## The village's own places.
const SHOP := Rect2i(31, 19, 3, 3)
const SHOP_DOOR := Vector2i(32, 21)
const FIELDS := Rect2i(2, 25, 8, 3)
const LEDGER := Rect2i(21, 16, 2, 1)
const PLAZA := Rect2i(14, 13, 16, 9)
const GATE_ROAD := Rect2i(21, 22, 2, 11)
## Where the square's cultists wander, and the commons' (tile rects).
const PLAZA_ROAM := Rect2i(15, 14, 14, 7)
const COMMONS_ROAM := Rect2i(12, 28, 28, 4)
const WALL_SPANS := [[0, 18], [25, 61]]
const WALL_POST_X := 17
const RUINS := {
	"bell_tower": {"feet": Vector2i(40, 11), "ruined": [VillageArt.RUINS, 12, 6, 4, 5], "restored": [VillageArt.HOUSES, 25, 14, 4, 5], "tablet": Vector2(0, 46)},
	"granary": {"feet": Vector2i(15, 27), "ruined": [VillageArt.RUINS, 11, 3, 3, 3], "restored": [VillageArt.HOUSES, 23, 0, 3, 3], "tablet": Vector2(50, 0)},
	"ossuary": {"feet": Vector2i(32, 28), "ruined": [VillageArt.RUINS, 11, 0, 3, 3], "restored": [VillageArt.HOUSES, 29, 0, 4, 3], "tablet": Vector2(-56, 0)},
}
## Drains sit on the river bank, clear of the tall facades.
const DRAIN_COLS := [5, 10, 29, 39, 14]
const CROP_FRAME := {"bumper": 0, "healthy": 1, "wilting": 2, "withered": 3}
## The HUD's corners (480x270 screen px): world labels that pass under them fade out.
const HUD_LEFT := Vector2(176, 46)
const HUD_RIGHT := Vector2(130, 30)
const HUD_TOP := 18.0

var house: VillageHouse
var wall: VillageWall
var ruins: Dictionary = {}  # ruin_id -> VillageRuin
var parcels: Dictionary = {}  # gated parcel id -> VillageParcel
var cultists: Array[VillageCultist] = []
var ledger_stone: Node2D

var _under := Node2D.new()  # glows and pools of light on the ground, under everything standing
var _door_lamps: Dictionary = {}  # place -> Label painted on its lamp
var _open_plots: Dictionary = {}  # plot_id -> level id it leads to
var _shrine_flame: AnimatedSprite2D
var _beats_running := false
var _awaiting_seen := false
var _focus := Vector2.ZERO
var _shake_tween: Tween
var _land_shown := false  # the first dress opens parcels without a show
var _revealing := false
var _closed_px: Array[Rect2] = []
var _settlers: Dictionary = {}  # parcel id -> Array[VillageCultist]
var _labels: Array[Label] = []  # painted numbers and words in the world (fade under the HUD)


func build() -> void:
	map = _make_map()
	legend = LEGEND
	solid = "T~wx"
	add_child(_under)
	move_child(_under, 1)
	_border_trees()
	_outside()
	_river_life()
	_plots()
	_tavern_and_shop()
	_square()
	_commons()
	_fields_bed()
	house = VillageHouse.new()
	house.position = Vector2(HOUSE_PLOT.position.x * TILE + 8, HOUSE_PLOT.end.y * TILE)
	props.add_child(house)
	block(Rect2i(HOUSE_PLOT.position.x, HOUSE_PLOT.end.y - 3, 5, 3))
	add_interactable(house.position + Vector2(32, -8), func() -> String: return "", house.poke)
	add_interactable(house.position + Vector2(78, -8), func() -> String: return "", house.poke)
	wall = VillageWall.new()
	wall.spans = WALL_SPANS
	wall.post_x = WALL_POST_X
	wall.position = Vector2(0, WALL_BASE_ROW * TILE)
	props.add_child(wall)
	add_interactable(feet_at(Vector2i(WALL_POST_X, ROAD_ROW)) + Vector2(0, -4), func() -> String: return "", wall.poke)
	for ruin_id: String in RUINS:
		var spec: Dictionary = RUINS[ruin_id]
		var r := VillageRuin.new()
		r.ruin_id = ruin_id
		r.ruined_art = spec.ruined
		r.restored_art = spec.restored
		r.tablet_at = spec.tablet
		r.position = feet_at(spec.feet) + Vector2(0, 1)
		props.add_child(r)
		ruins[ruin_id] = r
		var art: Array = spec.ruined
		var w: int = art[3]
		var h := mini(3, int(art[4]))
		block(Rect2i(int(spec.feet.x) - w / 2, int(spec.feet.y) - h + 1, w, h))
		var base := r.position + r.tablet_at
		block(Rect2i(int(base.x / TILE) - 1, int((base.y - 2) / TILE), 2, 1))
		add_interactable(r.position + r.tablet_at + Vector2(0, 6), func() -> String: return "", r.poke)
	add_npc("farmer", Vector2i(13, 26), Vector2i(13, 27))
	add_npc("shrine_keeper", Vector2i(36, 12), Vector2i(36, 13))
	_land()
	_cultists()
	_ambience()
	Game.event_fired.connect(_on_event)


func _ready() -> void:
	super._ready()
	ground.modulate = NIGHT_GROUND
	# Coming back through a door in the wall (the gate) would land outside it: step inside.
	var tile := Vector2i((leader.position / TILE).floor())
	while tile.y > BANK_ROW and (_blocked.has(tile) or _open.has(tile) or tile.y > ROAD_ROW):
		tile.y -= 1
	leader.position = feet_at(tile)
	# Pop out of the door with a little hop.
	leader.scale = Vector2(1.25, 0.75)
	var tw := leader.create_tween()
	tw.tween_property(leader, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_collect_labels()


func dress() -> void:
	for plot_id: String in PLOTS:
		var f := Features.for_plot(plot_id)
		if f:
			f.dress_village(self, PLOTS[plot_id].rect)
	_dress_land()
	_dress_crops()
	_dress_tavern()
	_dress_river()
	_dress_lamps()
	_collect_labels.call_deferred()
	if _shrine_flame:
		var glowing: bool = Game.state.get("shrine", {}).get("state", "dim") == "glowing"
		_shrine_flame.scale = Vector2.ONE * (1.4 if glowing else 0.8)
	var v: Dictionary = Game.state.get("village", {})
	if v.is_empty():
		return
	if _awaiting_seen:
		_awaiting_seen = false
		_beats_running = false
	var building := house.apply(v.house)
	var change := wall.apply(v.wall)
	var plays: Array = []
	for ruin: Dictionary in v.ruins:
		var r: VillageRuin = ruins.get(ruin.id)
		if r:
			var what := r.apply(ruin)
			if what != "":
				plays.append([r, what])
	if (building or change != "" or not plays.is_empty()) and not _beats_running:
		_play_beats(building, change, plays)


# --- the island's land ------------------------------------------------------------------------

## The map, drawn from the constants above: trees, the river, land, roads, the wall, outside.
static func _make_map() -> Array[String]:
	var rows: Array[String] = []
	for y in H:
		var line := ""
		for x in W:
			line += _map_char(x, y)
		rows.append(line)
	return rows


static func _map_char(x: int, y: int) -> String:
	var gate: Dictionary = PLOTS.gate
	var cell := Vector2i(x, y)
	if y < 2:
		return "T"
	if y <= RIVER_EDGE_ROW:
		return "~"
	if y >= WALL_BASE_ROW:
		return "x"
	if y > ROAD_ROW:
		var door: Vector2i = gate.door
		return "=" if x == door.x or x == door.x + 1 else "w"
	if x == 0 or x == W - 1:
		return "T"
	if y == ROAD_ROW or GATE_ROAD.has_point(cell):
		return "="
	if PLAZA.has_point(cell):
		return "#"
	if y == FRONT_ROAD_ROW and (PARCELS.home.rect as Rect2i).has_point(cell):
		return "="
	return "."


## Parcel ids that are open now: home and commons, plus what the land tier has opened.
static func open_parcels() -> Array:
	var b: Variant = Game.state.get("buildings")
	if b is Dictionary:
		var land: Variant = (b as Dictionary).get("land")
		if land is Dictionary and (land as Dictionary).get("parcels") is Array:
			var out: Array = (land as Dictionary).parcels.duplicate()
			for p in START_PARCELS:
				if not out.has(p):
					out.append(p)
			return out
	return START_PARCELS.duplicate()


func parcel_open(parcel_id: String) -> bool:
	if parcels.has(parcel_id):
		return (parcels[parcel_id] as VillageParcel).is_open
	return START_PARCELS.has(parcel_id)


## The building sites with their pixel anchors: `base` is the footprint's bottom middle,
## `feet_at`, `sign_at` and `flag_at` are where a sprite's feet go on those tiles.
## This is the hook the buildings feature reads.
static func building_plots() -> Dictionary:
	var out := {}
	for id: String in BUILDING_PLOTS:
		out[id] = building_plot(id)
	return out


static func building_plot(id: String) -> Dictionary:
	var p: Dictionary = (BUILDING_PLOTS[id] as Dictionary).duplicate()
	var r: Rect2i = p.rect
	p["id"] = id
	p["base"] = Vector2((r.position.x + r.size.x / 2.0) * TILE, r.end.y * TILE)
	p["feet_at"] = _feet(p.feet)
	p["sign_at"] = _feet(p.sign)
	p["flag_at"] = _feet(p.flag)
	return p


static func _feet(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * TILE + TILE / 2.0, (tile.y + 1) * TILE - 1)


## Closed parcels are off the map for walking (the leader's and the cultists' feet).
func is_walkable(feet: Rect2) -> bool:
	for r in _closed_px:
		if r.intersects(feet):
			return false
	return super.is_walkable(feet)


func _land() -> void:
	for id: String in PARCELS:
		var spec: Dictionary = PARCELS[id]
		if not spec.has("land"):
			continue
		var p := VillageParcel.new()
		p.parcel_id = id
		p.rect = spec.rect
		p.land = spec.land
		p.stake_tile = spec.stake
		props.add_child(p)
		parcels[id] = p
		for r in p.decor_tiles():
			block(r)
	_closed_px.clear()
	for id: String in parcels:
		_closed_px.append((parcels[id] as VillageParcel).px_rect())
	_rope_up()


## Open what the land tier has opened. The first time, parcels just stand open; after that a
## newly opened parcel plays its reveal.
func _dress_land() -> void:
	var open := open_parcels()
	var newly: Array[String] = []
	for id: String in parcels:
		var p: VillageParcel = parcels[id]
		var now := open.has(id)
		if now == p.is_open:
			continue
		if now and _land_shown:
			newly.append(id)
			continue
		p.set_open(now)
		_paint_parcel(p, now)
		_settle(id, now, false)
		if now:
			parcel_opened.emit(id)
	_land_shown = true
	_refresh_land()
	if not newly.is_empty() and not _revealing:
		_reveal(newly)


func _refresh_land() -> void:
	_closed_px.clear()
	for id: String in parcels:
		var p: VillageParcel = parcels[id]
		if not p.is_open:
			_closed_px.append(p.px_rect())
	_rope_up()


## Ropes run along each closed parcel's edges that meet open land.
func _rope_up() -> void:
	for id: String in parcels:
		var p: VillageParcel = parcels[id]
		if p.is_open:
			continue
		var segs: Array = []
		var a: Rect2i = p.rect
		for other: String in PARCELS:
			if other == id or not parcel_open(other):
				continue
			var b: Rect2i = PARCELS[other].rect
			if b.end.x == a.position.x or a.end.x == b.position.x:
				var x := a.position.x if b.end.x == a.position.x else a.end.x
				var y0 := maxi(a.position.y, b.position.y)
				var y1 := mini(a.end.y, b.end.y)
				if y1 > y0:
					segs.append([Vector2(x * TILE, y0 * TILE + 10), Vector2(x * TILE, y1 * TILE - 2)])
			elif b.end.y == a.position.y or a.end.y == b.position.y:
				var y := a.position.y if b.end.y == a.position.y else a.end.y
				var x0 := maxi(a.position.x, b.position.x)
				var x1 := mini(a.end.x, b.end.x)
				if x1 > x0:
					segs.append([Vector2(x0 * TILE + 8, y * TILE), Vector2(x1 * TILE - 8, y * TILE)])
		p.set_ropes(segs)


func _paint_parcel(p: VillageParcel, open: bool) -> void:
	for y in range(p.rect.position.y, p.rect.end.y):
		for x in range(p.rect.position.x, p.rect.end.x):
			_ground_cell(Vector2i(x, y), open)


func _ground_cell(cell: Vector2i, open: bool) -> void:
	if open:
		var p := _parcel_at(cell)
		var bloom: int = VillageParcel.BLOOM.get(p.land, 9) if p else 23
		var index: int = legend[map[cell.y][cell.x]]
		if index == 0:
			var h := (cell.x * 73 + cell.y * 151) % 23
			index = 2 if h % bloom == 0 else (1 if h % 5 == 0 else 0)
		set_tile(cell, index)
	else:
		set_tile(cell, WILD_GROUND if (cell.x * 31 + cell.y * 17) % 3 else WILD_GROUND + 1)


func _parcel_at(cell: Vector2i) -> VillageParcel:
	for id: String in parcels:
		var p: VillageParcel = parcels[id]
		if p.rect.has_point(cell):
			return p
	return null


## Newly opened parcels, one at a time: pan there, play the reveal, open the ground.
func _reveal(ids: Array[String]) -> void:
	_revealing = true
	await VillageArt.wait(self, 0.4)
	for id in ids:
		var p: VillageParcel = parcels[id]
		await focus(p.center(), 0.6)
		_stare(p.center())
		await p.play_open(_ground_cell)
		_refresh_land()
		_settle(id, true, true)
		parcel_opened.emit(id)
		await VillageArt.wait(self, 0.6)
	await focus_back(0.5)
	_revealing = false
	_collect_labels()


# --- the overnight beats: house, wall, sockets, restorations -----------------------------

func _play_beats(building: bool, change: String, plays: Array) -> void:
	_beats_running = true
	await VillageArt.wait(self, 0.5)
	var parts: Array[String] = []
	if building:
		await focus(house.global_position + Vector2(32, -24), 0.45)
		_stare(house.global_position)
		await house.play_build(self)
		await VillageArt.wait(self, 0.6)
		parts.append("house")
	if change != "":
		await focus(Vector2(WALL_POST_X * TILE, WALL_BASE_ROW * TILE - 30), 0.45)
		await wall.play_change(self, change)
		await VillageArt.wait(self, 0.6)
		parts.append("wall")
	for p: Array in plays:
		var r: VillageRuin = p[0]
		await focus(r.global_position + Vector2(r.tablet_at.x / 2.0, -30), 0.45)
		_stare(r.global_position)
		if p[1] == "restore":
			await r.play_restore(self)
		else:
			await r.play_fill(self)
		await VillageArt.wait(self, 0.9)
		if not parts.has("bundles"):
			parts.append("bundles")
	await focus_back(0.4)
	if parts.is_empty():
		_beats_running = false
		return
	# Tell the backend they played; the refresh that follows re-dresses and frees the beats.
	_awaiting_seen = true
	Game.act("/village/seen", {"parts": parts})


## Pan the camera to a point in the world (the leader stays put), inside the map's edges.
func focus(point: Vector2, seconds := 0.45) -> void:
	var half := get_viewport_rect().size / 2.0
	var size := Vector2(map[0].length(), map.size()) * TILE
	_focus = point.clamp(half, size - half) - leader.position.clamp(half, size - half)
	var tw := create_tween()
	tw.tween_property(camera, "offset", _focus, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


func focus_back(seconds := 0.4) -> void:
	_focus = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(camera, "offset", Vector2.ZERO, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


func shake(strength := 3.0, seconds := 0.25) -> void:
	if _shake_tween:
		_shake_tween.kill()
	_shake_tween = create_tween()
	var steps := int(seconds / 0.03)
	for i in steps:
		var f := strength * (1.0 - float(i) / steps)
		_shake_tween.tween_property(camera, "offset", _focus + Vector2(randf_range(-f, f), randf_range(-f, f)), 0.03)
	_shake_tween.tween_property(camera, "offset", _focus, 0.03)


func _stare(point: Vector2) -> void:
	for c in cultists:
		c.stare_at(point, randf_range(1.0, 2.0))


# --- input and the HUD -------------------------------------------------------------------------

func _on_tap(point: Vector2) -> void:
	# A cultist under the finger hops, unless the tap is closer to something to use.
	var thing := TAP_RADIUS
	for it: Dictionary in _interactables:
		thing = minf(thing, point.distance_to(it.pos))
	var best: VillageCultist = null
	var best_d := minf(10.0, thing)
	for c in cultists:
		var d := point.distance_to(c.position + Vector2(0, -7))
		if d < best_d:
			best_d = d
			best = c
	if best:
		best.poke()
		return
	super._on_tap(point)


func _process(delta: float) -> void:
	super._process(delta)
	# Everything in the village is tapped, not read: no key prompts here at all.
	if main:
		main.show_prompt("")
	_hud_fade()


## Labels painted on things fade out while they pass under the HUD's corners.
func _hud_fade() -> void:
	var xf := get_viewport().get_canvas_transform()
	var width := get_viewport_rect().size.x
	for v: Variant in _labels:
		if not is_instance_valid(v) or not (v as Label).is_visible_in_tree():
			continue
		var l := v as Label
		var p := xf * (l.global_position + l.size / 2.0)
		var top := HUD_TOP
		if p.x < HUD_LEFT.x:
			top = HUD_LEFT.y
		elif p.x > width - HUD_RIGHT.x:
			top = HUD_RIGHT.y
		l.self_modulate.a = clampf((p.y - top) / 10.0, 0.0, 1.0)


func _collect_labels() -> void:
	_labels.clear()
	for n in props.find_children("*", "Label", true, false):
		if not n.is_queued_for_deletion():
			_labels.append(n as Label)


func open_ledger() -> void:
	if Game.busy:
		return
	VillageArt.squash(ledger_stone, Vector2(1.15, 0.85))
	VillageArt.sfx("kenney-impact-sounds/Audio/impactMining_00%d.ogg" % (randi() % 5), 0.8, -8)
	await main.open_overlay(StatsOverlay.new())


func _on_event(e: Dictionary) -> void:
	if str(e.get("kind", "")) == "money_moved":
		for i in cultists.size():
			cultists[i].chant(i * 0.06)


# --- building the hub ------------------------------------------------------------------------

func _border_trees() -> void:
	var dead := [Vector2i(4, 0), Vector2i(6, 0)]
	for x in range(0, W, 2):
		var t := VillageArt.sprite(props, VillageArt.tiles(VillageArt.NATURE, dead[(x / 2) % 2].x, 0, 2, 2), Vector2(x * TILE + 16, 2 * TILE - 2), x % 4 == 0)
		t.modulate = Color(0.8, 0.75, 0.9)
		_sway(t, 0.035)
	var leaves := CPUParticles2D.new()
	leaves.texture = VillageArt.tex(VillageArt.LEAF, Rect2(0, 0, 8, 7))
	leaves.amount = 16
	leaves.lifetime = 5.0
	leaves.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	leaves.emission_rect_extents = Vector2(W * TILE / 2.0, 4)
	leaves.position = Vector2(W * TILE / 2.0, TILE)
	leaves.gravity = Vector2(6, 14)
	leaves.angular_velocity_min = -90
	leaves.angular_velocity_max = 90
	leaves.color = Color(0.75, 0.55, 0.8)
	add_child(leaves)
	for y in range(5, ROAD_ROW + 1, 2):
		for x in [0, W - 1]:
			_sway(VillageArt.sprite(props, VillageArt.tiles(VillageArt.TOWN, 4 if y % 4 == 1 else 3, 1, 1, 2), Vector2(x * TILE + 8, (y + 1) * TILE)), 0.05)


## Trees lean in the wind, each on its own beat.
func _sway(s: Sprite2D, amount: float) -> void:
	var tw := s.create_tween().set_loops()
	tw.tween_interval(randf() * 1.5)
	tw.tween_property(s, "rotation", amount, 1.6 + randf()).set_trans(Tween.TRANS_SINE)
	tw.tween_property(s, "rotation", -amount * 0.5, 1.6 + randf()).set_trans(Tween.TRANS_SINE)


## Beyond the wall: dead ground, fog, and the debts waiting outside the gate.
func _outside() -> void:
	var mid := W * TILE / 2.0
	var dark := VillageArt.glow(_under, Vector2(mid, (WALL_BASE_ROW + 2) * TILE), Color(0, 0, 0, 0.9), W * TILE * 1.4)
	dark.material = null
	dark.scale.y = 0.12
	for x in range(1, W, 3):
		var t := VillageArt.sprite(props, VillageArt.tiles(VillageArt.NATURE, 0 if x % 2 else 2, 5, 2, 3), Vector2(x * TILE + 8, H * TILE - 2))
		t.modulate = Color(0.35, 0.3, 0.45)
	var debts: Array = Game.state.get("debts", [])
	for i in mini(3, maxi(1, debts.size())):
		var x: int = [13, 32, 40][i]
		var slime := VillageArt.anim(props, VillageArt.frames(VillageArt.PACKS + "ninja-adventure/Actor/Boss/GiantSlime/Idle.png", Vector2i(62, 52), 5, 5), Vector2(x * TILE, (WALL_BASE_ROW - 1) * TILE + 4))
		slime.self_modulate = Color(0.3, 0.18, 0.4, 0.95)
		slime.scale = Vector2.ONE * (1.4 - i * 0.25)
		for ex in [-8, 8]:
			VillageArt.glow(slime, Vector2(ex, 2), Color(VillageArt.SICK, 1.0), 9, 0.6)
		VillageArt.bob(slime, 2.0, 3.0 + i)
	var fog := Sprite2D.new()
	fog.texture = VillageArt.sheet(VillageArt.FOG)
	fog.position = Vector2(mid, (H - 1) * TILE + 8)
	fog.scale = Vector2(3.4, 0.6)
	fog.modulate = Color(0.55, 0.45, 0.8, 0.12)
	fog.material = VillageArt.additive()
	fog.z_index = 1
	add_child(fog)
	var drift := fog.create_tween().set_loops()
	drift.tween_property(fog, "position:x", mid + 40.0, 9.0).set_trans(Tween.TRANS_SINE)
	drift.tween_property(fog, "position:x", mid - 40.0, 9.0).set_trans(Tween.TRANS_SINE)


func _river_life() -> void:
	VillageArt.embers(_under, Vector2(W * TILE / 2.0, 3.5 * TILE), Color(0.6, 1.0, 0.8, 0.6), W * TILE, 16, 6)


## Facades for the plots: loud doors with lamps, neon and sound. A feature that owns a
## plot draws on top in build_village(); its door opens once its level exists.
func _plots() -> void:
	for plot_id: String in PLOTS:
		var plot: Dictionary = PLOTS[plot_id]
		var f := Features.for_plot(plot_id)
		var level_id := ""
		if f and f.door_level() != "":
			level_id = f.door_level()
		elif Features.level_script(plot_id):
			level_id = plot_id
		match plot_id:
			"casino":
				_facade_casino(plot.rect)
			"arcade":
				_facade_arcade(plot.rect)
			"shrine":
				_facade_shrine(plot.rect)
			"gate":
				_facade_gate(plot.rect, level_id != "")
		if f:
			f.build_village(self, plot.rect)
		if level_id != "":
			add_door(plot.door, level_id, Room.ENTRANCE)
			if plot.get("wide", false):
				add_door(plot.door + Vector2i.RIGHT, level_id, Room.ENTRANCE)
			_open_plots[plot_id] = level_id
		else:
			block(Rect2i(plot.door, Vector2i.ONE))
		if plot_id != "gate":
			block(Rect2i(plot.rect.position, plot.rect.size - Vector2i(0, 1)))
			for x in range(plot.rect.position.x, plot.rect.end.x):
				if Vector2i(x, plot.rect.end.y - 1) != plot.door and not (plot.get("wide", false) and x == plot.door.x + 1 and level_id != ""):
					block(Rect2i(x, plot.rect.end.y - 1, 1, 1))
		else:
			block(Rect2i(plot.rect.position.x, plot.rect.position.y + 1, 1, 3))
			block(Rect2i(plot.rect.end.x - 1, plot.rect.position.y + 1, 1, 3))
			if level_id == "":
				block(Rect2i(plot.door.x, plot.door.y - 1, 2, 2))
			else:
				# The gatehouse blocks its own footing; keep the way through it to the door clear.
				for y in range(plot.rect.position.y, plot.door.y):
					for dx in 2:
						_blocked.erase(Vector2i(plot.door.x + dx, y))


func _door_light(at: Vector2, color: Color, size := 90.0) -> void:
	VillageArt.glow(_under, at, color, size, 0.35)


## A lamp on a post by a door, with a number painted on its plate.
func _lamp(place: String, at: Vector2, color: Color) -> void:
	var post := VillageArt.sprite(props, VillageArt.tiles(VillageArt.TOWN, 11, 4), at)
	var head := VillageArt.sprite(props, VillageArt.tiles(VillageArt.HOUSES, 29, 16), at + Vector2(0, -12))
	head.z_index = 1
	VillageArt.glow(_under, at + Vector2(0, -2), Color(color, 0.55), 70, 0.4)
	var halo := VillageArt.glow(head, Vector2(0, -8), Color(color, 0.9), 30, 0.5)
	halo.z_index = 2
	var plate := VillageArt.paint(props, "", at + Vector2(0, -36), VillageArt.BONE, 10)
	plate.z_index = 3
	VillageArt.bob(plate, 1.0, 2.0)
	_door_lamps[place] = plate
	post.z_index = 0


func _facade_casino(r: Rect2i) -> void:
	var feet := Vector2((r.position.x + r.size.x / 2.0) * TILE, r.end.y * TILE)
	VillageArt.sprite(props, VillageArt.tiles(VillageArt.HOUSES, 12, 0, 4, 3), feet + Vector2(-56, 0))
	VillageArt.sprite(props, VillageArt.tiles(VillageArt.HOUSES, 12, 0, 4, 3), feet + Vector2(56, 0), true)
	block(Rect2i(r.position.x - 3, r.end.y - 3, 3, 3))
	block(Rect2i(r.end.x, r.end.y - 3, 3, 3))
	var hall := VillageArt.sprite(props, VillageArt.tiles(VillageArt.HOUSES, 25, 7, 4, 7), feet + Vector2(0, 1))
	hall.z_index = 0
	_door_light(feet + Vector2(0, 8), Color(1.0, 0.45, 0.7, 0.5), 96)
	_door_light(feet + Vector2(0, -56), Color(0.75, 0.35, 0.9, 0.3), 120)
	# Outline neons only: a filled disc sign read as a purple blob over the square.
	VillageArt.neon(props, "Sign 14/Sign 14 Glow - PINK.png", Vector2i(67, 67), 18, feet + Vector2(-56, -70), 8, 6).scale = Vector2(0.8, 0.8)
	VillageArt.neon(props, "Sign 14/Sign 14 Glow - BLUE.png", Vector2i(67, 67), 18, feet + Vector2(56, -70), 9, 6).scale = Vector2(0.8, 0.8)
	var enter := VillageArt.neon(props, "Sign 13/Sign 13 Glow - GREEN.png", Vector2i(56, 39), 15, feet + Vector2(0, -122), 8, 5)
	enter.z_index = 2
	# A chase of bulbs along the front.
	for i in 18:
		var bulb := VillageArt.glow(props, feet + Vector2(-80 + i * 9.4, -50 - absf(sin(i * 0.35)) * 6), Color(1.0, 0.85, 0.5, 0.0), 10)
		var tw := bulb.create_tween().set_loops()
		tw.tween_interval(i * 0.06)
		tw.tween_property(bulb, "modulate:a", 1.0, 0.05)
		tw.tween_property(bulb, "modulate:a", 0.15, 0.5)
		tw.tween_interval(1.1 - i * 0.06)
	_lamp("casino", feet + Vector2(-26, 14), Color(1.0, 0.4, 0.8))
	_bleed(feet, PACKS_AUDIO_CASINO, -14)


func _facade_arcade(r: Rect2i) -> void:
	var feet := Vector2((r.position.x + r.size.x / 2.0) * TILE, r.end.y * TILE)
	VillageArt.sprite(props, VillageArt.tiles(VillageArt.HOUSES, 19, 0, 4, 3), feet + Vector2(0, 1))
	_door_light(feet + Vector2(0, 4), Color(0.25, 0.6, 1.0, 0.6), 110)
	VillageArt.neon(props, "Sign 5/Sign 5  Glow - BLUE.png", Vector2i(33, 33), 18, feet + Vector2(-26, -58), 10)
	VillageArt.neon(props, "Sign 12/Sign 12 Glow - TEAL.png", Vector2i(60, 34), 51, feet + Vector2(14, -62), 12, 17).scale = Vector2(0.8, 0.8)
	_lamp("arcade", feet + Vector2(34, 14), Color(0.35, 0.7, 1.0))
	_bleed(feet, "freesound-cc0-picks/443091_LICHTLE_Marion_2018_2019_ArcadeCoins_wav.mp3", -20)


func _facade_shrine(r: Rect2i) -> void:
	var feet := Vector2((r.position.x + r.size.x / 2.0) * TILE, r.end.y * TILE)
	VillageArt.sprite(props, VillageArt.tiles(VillageArt.HOUSES, 0, 5, 3, 2), feet + Vector2(0, -2))
	for side in [-36, 36]:
		VillageArt.sprite(props, VillageArt.tiles(VillageArt.HOUSES, 1, 15, 2, 3), feet + Vector2(side, -4), side > 0)
		VillageArt.glow(_under, feet + Vector2(side, -20), Color(VillageArt.EMBER, 0.45), 60, 0.4)
	_shrine_flame = VillageArt.anim(props, VillageArt.frames(VillageArt.FLAME, Vector2i(20, 30), 10, 12), feet + Vector2(0, -22))
	_shrine_flame.material = VillageArt.additive()
	VillageArt.glow(_under, feet + Vector2(0, -10), Color(Palette.GLOW, 0.6), 130, 0.35)
	VillageArt.embers(props, feet + Vector2(0, -30), Color(Palette.GLOW, 0.9), 20, 8, 22)
	_lamp("shrine", feet + Vector2(-40, 14), Palette.GLOW)
	_bleed(feet, "owlishmedia-creepy-chanting/chant5.ogg", -18)


func _facade_gate(r: Rect2i, open: bool) -> void:
	var feet := Vector2((r.position.x + r.size.x / 2.0) * TILE, WALL_BASE_ROW * TILE)
	for side in [-1, 1]:
		var tower := VillageArt.sprite(props, VillageArt.tiles(VillageArt.TOWERS, 16 if side < 0 else 14, 0, 2, 2), feet + Vector2(side * 32, 0), side > 0)
		tower.scale = Vector2(1.0, 1.5)
	if open:
		VillageArt.sprite(props, VillageArt.tiles(VillageArt.TOWN, 3, 10, 2, 1), feet)
		VillageArt.sprite(props, VillageArt.tiles(VillageArt.TOWN, 5, 9, 2, 1), feet + Vector2(0, -16))
	else:
		VillageArt.sprite(props, VillageArt.tiles(VillageArt.TOWN, 3, 9, 2, 2), feet)
	_door_light(feet + Vector2(0, -8), Color(VillageArt.SICK, 0.5), 90)
	VillageArt.embers(props, feet + Vector2(0, -6), Color(VillageArt.SICK, 0.6), 30, 6, 12)
	_lamp("gate", Vector2(feet.x - 56, (ROAD_ROW + 1) * TILE - 1), VillageArt.SICK)
	_bleed(feet + Vector2(0, 40), "rubberduck-80-rpg-sfx/creature_monster_02.ogg", -16)


func _tavern_and_shop() -> void:
	var tf := Vector2((TAVERN.position.x + TAVERN.size.x / 2.0) * TILE, TAVERN.end.y * TILE)
	VillageArt.sprite(props, VillageArt.tiles(VillageArt.HOUSES, 0, 0, 4, 3), tf + Vector2(0, 1))
	VillageArt.neon(props, "Sign 7/Sign 7 Glow - PINK.png", Vector2i(28, 34), 19, tf + Vector2(22, -50), 10)
	_door_light(tf + Vector2(0, 4), Color(1.0, 0.55, 0.3, 0.6), 100)
	_lamp("tavern", tf + Vector2(-26, 14), Color(1.0, 0.6, 0.3))
	block(TAVERN)
	add_door(TAVERN_DOOR, "tavern", Room.ENTRANCE)
	var sf := Vector2((SHOP.position.x + SHOP.size.x / 2.0) * TILE, SHOP.end.y * TILE)
	VillageArt.sprite(props, VillageArt.tiles(VillageArt.HOUSES, 16, 0, 3, 3), sf + Vector2(0, 1))
	VillageArt.neon(props, "Sign 1/Sign 1 Glow - OPEN.png", Vector2i(31, 24), 72, sf + Vector2(0, -52), 12, 18)
	_door_light(sf + Vector2(0, 4), Color(0.4, 1.0, 0.8, 0.5), 90)
	_lamp("shop", sf + Vector2(32, 14), Color(0.4, 1.0, 0.8))
	block(SHOP)
	add_door(SHOP_DOOR, "shop", Room.ENTRANCE)


## The square: a stone slab with lamps on the corners and the ledger stone in the middle.
func _square() -> void:
	var stone_feet := Vector2((LEDGER.position.x + 1) * TILE, LEDGER.end.y * TILE)
	ledger_stone = Node2D.new()
	ledger_stone.position = stone_feet
	props.add_child(ledger_stone)
	VillageArt.sprite(ledger_stone, VillageArt.tex(VillageArt.DCSS + "altars/altar_base.png", Rect2(0, 0, 32, 32)), Vector2(0, 4))
	VillageArt.glow(_under, stone_feet + Vector2(0, -6), Color(VillageArt.BONE, 0.4), 110, 0.3)
	var digits := VillageArt.paint(ledger_stone, "", Vector2(0, -24), VillageArt.BONE, 10)
	digits.name = "Digits"
	VillageArt.bob(digits, 1.5, 2.4)
	VillageArt.embers(ledger_stone, Vector2(0, -16), Color(VillageArt.BONE, 0.7), 20, 4, 10)
	block(LEDGER)
	add_interactable(stone_feet + Vector2(0, 8), func() -> String: return "", open_ledger)
	add_interactable(stone_feet + Vector2(0, -12), func() -> String: return "", open_ledger)
	var corners := [PLAZA.position, Vector2i(PLAZA.end.x - 1, PLAZA.position.y), Vector2i(PLAZA.position.x, PLAZA.end.y - 1), PLAZA.end - Vector2i.ONE]
	for corner: Vector2i in corners:
		var at := feet_at(corner)
		VillageArt.sprite(props, VillageArt.tiles(VillageArt.TOWN, 11, 4), at)
		var head := VillageArt.sprite(props, VillageArt.tiles(VillageArt.HOUSES, 30, 16), at + Vector2(0, -12))
		head.z_index = 1
		VillageArt.glow(_under, at, Color(1.0, 0.7, 0.4, 0.45), 80, 0.3)
		block(Rect2i(corner, Vector2i.ONE))
	# Cracks and pebbles so the slab reads as stone, not paint.
	for y in range(PLAZA.position.y + 1, PLAZA.end.y - 1):
		for x in range(PLAZA.position.x + 1, PLAZA.end.x - 1):
			var h := (x * 37 + y * 101) % 11
			if h < 3 and not LEDGER.grow(1).has_point(Vector2i(x, y)):
				var s := Sprite2D.new()
				s.texture = VillageArt.tiles(VillageArt.FLOOR_DETAIL, [3, 5, 6][h], 0)
				s.centered = false
				s.position = Vector2(x * TILE, y * TILE)
				s.modulate = Color(0.45, 0.42, 0.5, 0.55)
				s.flip_h = (x + y) % 2 == 0
				_under.add_child(s)
	var bats := CPUParticles2D.new()
	bats.amount = 32
	bats.lifetime = 6.0
	bats.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	bats.emission_rect_extents = Vector2(W * TILE / 2.0 - 40, 240)
	bats.position = Vector2(W * TILE / 2.0, 19 * TILE)
	bats.gravity = Vector2.ZERO
	bats.initial_velocity_min = 2
	bats.initial_velocity_max = 6
	bats.spread = 180
	bats.color = Color(0.85, 1.0, 0.6, 0.8)
	bats.material = VillageArt.additive()
	bats.z_index = 5
	var ramp := Gradient.new()
	ramp.set_offset(0, 0.0)
	ramp.set_color(0, Color(0.85, 1.0, 0.6, 0.0))
	ramp.add_point(0.5, Color(0.85, 1.0, 0.6, 0.9))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.85, 1.0, 0.6, 0.0))
	bats.color_ramp = ramp
	add_child(bats)


## The commons: open meadow between the square and the wall, a few trees on its edges, and
## the road down to the gate. The fields, the granary and the ossuary stand here.
func _commons() -> void:
	var trees := [
		[VillageArt.NATURE, 6, 8, 2, 2, Vector2i(2, 31)], [VillageArt.NATURE, 6, 8, 2, 2, Vector2i(39, 26)],
		[VillageArt.TOWN, 4, 1, 1, 2, Vector2i(5, 31)], [VillageArt.TOWN, 3, 1, 1, 2, Vector2i(37, 24)],
		[VillageArt.TOWN, 4, 1, 1, 2, Vector2i(41, 30)], [VillageArt.TOWN, 3, 1, 1, 2, Vector2i(26, 24)],
		[VillageArt.NATURE, 6, 8, 2, 2, Vector2i(1, 21)], [VillageArt.TOWN, 3, 1, 1, 2, Vector2i(10, 21)],
		[VillageArt.TOWN, 4, 1, 1, 2, Vector2i(40, 19)], [VillageArt.TOWN, 4, 1, 1, 2, Vector2i(38, 22)],
	]
	for t: Array in trees:
		var tile: Vector2i = t[5]
		var w: int = t[3]
		var s := VillageArt.sprite(props, VillageArt.tiles(t[0], t[1], t[2], w, t[4]), Vector2(tile.x * TILE + w * 8.0, (tile.y + 1) * TILE))
		s.modulate = Color(0.85, 0.85, 0.95)
		_sway(s, 0.03)
		block(Rect2i(tile, Vector2i(w, 1)))
	# Bushes and flowers that don't block: life in the grass.
	var bits := [[VillageArt.NATURE, 1, 10], [VillageArt.NATURE, 3, 11], [VillageArt.NATURE, 2, 11], [VillageArt.NATURE, 6, 11], [VillageArt.NATURE, 4, 10]]
	var commons: Rect2i = PARCELS.commons.rect
	for y in range(commons.position.y, commons.end.y - 1):
		for x in range(commons.position.x + 1, commons.end.x - 1):
			var h := (x * 53 + y * 97) % 29
			var cell := Vector2i(x, y)
			if h > 1 or GATE_ROAD.grow(1).has_point(cell) or FIELDS.grow(1).has_point(cell) or _blocked.has(cell):
				continue
			var b: Array = bits[(x + y) % bits.size()]
			var s := VillageArt.sprite(props, VillageArt.tiles(b[0], b[1], b[2]), Vector2(x * TILE + 8, (y + 1) * TILE))
			s.modulate = Color(0.75, 0.72, 0.85)
	for x in [3, 9, 33, 38]:
		VillageArt.sprite(props, VillageArt.tiles(VillageArt.FLOOR_DETAIL, 13 + x % 2, 0), Vector2(x * TILE + 8, ROAD_ROW * TILE + 12))


func _fields_bed() -> void:
	for y in range(FIELDS.position.y, FIELDS.end.y):
		for x in range(FIELDS.position.x, FIELDS.end.x):
			var col := 0 if x == FIELDS.position.x else (2 if x == FIELDS.end.x - 1 else 1)
			var row := 6 if y == FIELDS.position.y else 8
			var s := Sprite2D.new()
			s.texture = VillageArt.tiles(VillageArt.FIELD, col, row)
			s.centered = false
			s.position = Vector2(x * TILE, y * TILE)
			s.modulate = Color(0.7, 0.6, 0.65)
			_under.add_child(s)


## Nine cultists: five wander the square, four the commons. Each parcel that opens gets its own.
func _cultists() -> void:
	for i in 9:
		_add_cultist(i, PLAZA_ROAM if i < 5 else COMMONS_ROAM)


func _add_cultist(look: int, roam: Rect2i, at := Vector2.INF) -> VillageCultist:
	var area := Rect2(Vector2(roam.position * TILE) + Vector2(4, 12), Vector2(roam.size * TILE) - Vector2(8, 12))
	var c := VillageCultist.new()
	c.look = look
	c.area = area
	c.is_walkable = is_walkable
	c.position = at if at != Vector2.INF else area.position + Vector2(randf() * area.size.x, randf() * area.size.y)
	props.add_child(c)
	cultists.append(c)
	return c


## Settlers move into a parcel when it opens (and leave if a replayed state closes it again).
func _settle(parcel_id: String, open: bool, show: bool) -> void:
	var have: Array = _settlers.get(parcel_id, [])
	if not open:
		for c: VillageCultist in have:
			cultists.erase(c)
			c.queue_free()
		_settlers.erase(parcel_id)
		return
	if not have.is_empty():
		return
	var p: VillageParcel = parcels[parcel_id]
	var roam := p.rect.grow(-2)
	for i in SETTLERS_PER_PARCEL:
		var at := Vector2(roam.get_center() * TILE) + Vector2((i - 0.5) * 40, 8)
		var c := _add_cultist(cultists.size() + i, roam, at)
		have.append(c)
		if show:
			VillageArt.burst(props, at + Vector2(0, -6), Color(0.85, 0.8, 0.75), 12, 40, 0.5)
			c.poke()
	_settlers[parcel_id] = have


const PACKS_AUDIO_CASINO := "freesound-cc0-picks/79088_AkasakaPachinkoParlorLunchtime_4micsStereoExpanded_wav.mp3"


## Each door bleeds its own sound into the square, louder as you walk up to it.
func _bleed(at: Vector2, path: String, db: float) -> void:
	var full := VillageArt.PACKS + path
	if not ResourceLoader.exists(full):
		return
	var stream: AudioStream = load(full)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	var p := AudioStreamPlayer2D.new()
	p.stream = stream
	p.volume_db = db
	p.max_distance = 220.0
	p.attenuation = 2.0
	p.position = at
	p.autoplay = true
	add_child(p)


func _ambience() -> void:
	var music := AudioStreamPlayer.new()
	var path := VillageArt.PACKS + "ninja-adventure/Audio/Music/26 - Lost Village.ogg"
	if ResourceLoader.exists(path):
		var s: AudioStreamOggVorbis = load(path)
		s.loop = true
		music.stream = s
		music.volume_db = -18.0
		music.autoplay = true
		add_child(music)


# --- state on things -------------------------------------------------------------------------

func _dress_lamps() -> void:
	var s := Game.state
	var extra := maxi(0, int(s.get("extra", {}).get("extra_cents", 0)))
	var casino: Dictionary = s.get("casino", {})
	if _door_lamps.has("casino"):
		var cases: Array = casino.get("cases", [])
		var prices := PackedStringArray()
		for c: Dictionary in cases:
			prices.append(VillageArt.dollars(int(c.price_cents)))
		_door_lamps.casino.text = " ".join(prices) if not prices.is_empty() else VillageArt.dollars(extra)
	if _door_lamps.has("arcade"):
		# The arcade feature lights a candle per flame over its door; the lamp only counts
		# them when nothing else does.
		var flames: Variant = s.get("minigames", {}).get("flames", {})
		var left := int((flames as Dictionary).get("left", 0)) if flames is Dictionary else 0
		var drawn := Features.for_plot("arcade") != null
		_door_lamps.arcade.text = "" if drawn else ("1 flame" if left == 1 else "%d flames" % left)
		_door_lamps.arcade.label_settings.font_color = VillageArt.BRASS
	if _door_lamps.has("shrine"):
		var days: Variant = s.get("village", {}).get("stats", {}).get("days_since_landing")
		_door_lamps.shrine.text = "" if days == null else ("today" if int(days) == 0 else ("1 day" if int(days) == 1 else "%d days" % int(days)))
	if _door_lamps.has("gate"):
		# The gate feature paints the front debt's balance over the gate itself.
		var debts: Array = s.get("debts", [])
		var bal: Dictionary = s.get("balances", {})
		var hp := -1
		for d: Dictionary in debts:
			var b := int(bal.get(d.id, d.balance_cents))
			if b > 0 and (hp < 0 or b < hp):
				hp = b
		var drawn := Features.for_plot("gate") != null
		_door_lamps.gate.text = VillageArt.dollars(hp) if hp > 0 and not drawn else ""
		_door_lamps.gate.label_settings.font_color = VillageArt.SICK
	if _door_lamps.has("tavern"):
		var t: Dictionary = s.get("tavern", {})
		_door_lamps.tavern.text = "%s/%s" % [VillageArt.dollars(t.get("spent_cents", 0)), VillageArt.dollars(t.get("budget_cents", 0))]
	if _door_lamps.has("shop"):
		var can := int(s.get("shop", {}).get("can_spend_cents", 0))
		_door_lamps.shop.text = VillageArt.dollars(can) if can > 0 else ""
	var digits: Label = ledger_stone.get_node("Digits")
	digits.text = VillageArt.dollars(extra)


func _dress_crops() -> void:
	var crops: Dictionary = Game.state.get("crops", {})
	if crops.is_empty():
		return
	var main_frame: int = CROP_FRAME[crops.state]
	# Wilting and withered fields keep a few plants one stage better, so it reads
	# as a field having a bad week rather than a dead one.
	for y in range(FIELDS.position.y, FIELDS.end.y):
		for x in range(FIELDS.position.x, FIELDS.end.x):
			var s := Sprite2D.new()
			s.texture = preload("res://art/crops.png")
			s.hframes = 4
			var better := main_frame >= 2 and (x * 7 + y * 13) % 4 == 0
			s.frame = main_frame - 1 if better else main_frame
			s.offset = Vector2(0, -8)
			s.position = Vector2(x * TILE + 8, (y + 1) * TILE)
			dynamic.add_child(s)
			if main_frame >= 2:
				var sway := s.create_tween().set_loops()
				sway.tween_property(s, "rotation", 0.08, 0.9 + (x % 3) * 0.2).set_trans(Tween.TRANS_SINE)
				sway.tween_property(s, "rotation", -0.04, 0.9).set_trans(Tween.TRANS_SINE)
	var sign_at := Vector2(FIELDS.end.x * TILE + 8, FIELDS.end.y * TILE)
	VillageArt.sprite(dynamic, VillageArt.tiles(VillageArt.TOWN, 11, 6), sign_at)
	var over := int(crops.spent_cents) > int(crops.budget_cents)
	var l := VillageArt.paint(dynamic, "%s/%s" % [VillageArt.dollars(int(crops.spent_cents)), VillageArt.dollars(int(crops.budget_cents))], sign_at + Vector2(0, -24), Color("ff9a8a") if over else VillageArt.BONE, 10)
	VillageArt.bob(l, 1.0, 1.8)


func _dress_tavern() -> void:
	var t: Dictionary = Game.state.get("tavern", {})
	if t.is_empty():
		return
	if t.state == "quiet":
		var coin := Sprite2D.new()
		coin.texture = preload("res://art/coin.png")
		coin.position = Vector2((TAVERN.position.x + 3.5) * TILE, TAVERN.end.y * TILE - 54)
		dynamic.add_child(coin)
		var tw := coin.create_tween().set_loops()
		tw.tween_property(coin, "position:y", coin.position.y - 4, 0.6)
		tw.tween_property(coin, "position:y", coin.position.y, 0.6)
	else:
		# Packed: the overflow sleeps it off outside.
		for i in 3:
			var s := Sprite2D.new()
			s.texture = preload("res://art/villager.png")
			s.hframes = 2
			s.frame = 1
			s.offset = Vector2(0, -8)
			s.position = Vector2((TAVERN.end.x) * TILE + 8 + i * 10, (TAVERN.end.y + 1) * TILE)
			dynamic.add_child(s)


## Drains on the river bank: each shows what it takes a month, in whole dollars on its grate.
## A new one glows red and carries its name; the full list is on the ledger stone.
func _dress_river() -> void:
	var river: Dictionary = Game.state.get("drains", {})
	if river.is_empty():
		return
	var low: bool = river.river == "low"
	for x in W:
		set_tile(Vector2i(x, RIVER_EDGE_ROW), LOW_WATER if low else 5)
	var drains: Array = river.drains
	for i in drains.size():
		var d: Dictionary = drains[i]
		var x: int = DRAIN_COLS[i % DRAIN_COLS.size()]
		var s := Sprite2D.new()
		s.texture = preload("res://art/drain.png")
		s.hframes = 2
		s.frame = 1 if d.charged_this_week else 0
		s.centered = false
		s.position = Vector2(x * TILE, BANK_ROW * TILE - 4)
		dynamic.add_child(s)
		var at := Vector2(x * TILE + 8, BANK_ROW * TILE + 18)
		var fresh: bool = d.get("new", false)
		VillageArt.paint(dynamic, VillageArt.dollars(int(d.amount_cents)), at, Color("ff9a8a") if fresh else Color(VillageArt.BONE, 0.85), 10)
		if fresh:
			VillageArt.glow(dynamic, at + Vector2(0, -12), Color(1.0, 0.3, 0.25, 0.5), 30, 0.5)
			VillageArt.paint(dynamic, str(d.merchant), at + Vector2(0, 9), Color("ff9a8a"), 16, VillageArt.FONT_SMALL)
		if d.charged_this_week:
			var tw := s.create_tween().set_loops()
			tw.tween_property(s, "modulate:a", 0.6, 0.5)
			tw.tween_property(s, "modulate:a", 1.0, 0.5)


# --- ground ------------------------------------------------------------------------------------

## The ground comes from pack sheets (one atlas source per sheet); `index` points into GROUND.
func _paint() -> void:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(TILE, TILE)
	var sources: Dictionary = {}
	_ground_alts.clear()
	for g: Array in GROUND:
		var path: String = g[0]
		if not sources.has(path):
			var src := TileSetAtlasSource.new()
			src.texture = VillageArt.sheet(path)
			src.texture_region_size = Vector2i(TILE, TILE)
			sources[path] = tiles.add_source(src)
		var atlas: TileSetAtlasSource = tiles.get_source(sources[path])
		if not atlas.has_tile(g[1]):
			atlas.create_tile(g[1])
		var alt := 0
		if g.size() > 2:
			alt = atlas.create_alternative_tile(g[1])
			atlas.get_tile_data(g[1], alt).modulate = g[2]
		_ground_alts.append(alt)
	ground.tile_set = tiles
	_ground_sources = sources
	for y in map.size():
		for x in map[y].length():
			var ch := map[y][x]
			var index: int = legend[ch]
			# A few tufts and flowers in the grass.
			if index == 0 and (x * 73 + y * 151) % 23 == 0:
				index = 2
			set_tile(Vector2i(x, y), index)
			if solid.contains(ch) and not _open.has(Vector2i(x, y)):
				_blocked[Vector2i(x, y)] = true
	_paint_square_edges()
	for id: String in parcels:
		var p: VillageParcel = parcels[id]
		_paint_parcel(p, p.is_open)


## The square's slab gets its rim (the same Tiny Town slab's edge tiles).
func _paint_square_edges() -> void:
	var r := PLAZA
	for x in range(r.position.x, r.end.x):
		set_tile(Vector2i(x, r.position.y), 12 if x == r.position.x else (14 if x == r.end.x - 1 else 13))
		set_tile(Vector2i(x, r.end.y - 1), 17 if x == r.position.x else (19 if x == r.end.x - 1 else 18))
	for y in range(r.position.y + 1, r.end.y - 1):
		set_tile(Vector2i(r.position.x, y), 15)
		set_tile(Vector2i(r.end.x - 1, y), 16)


var _ground_sources: Dictionary = {}
var _ground_alts: Array[int] = []  # GROUND index -> alternative tile id carrying its tint


func set_tile(cell: Vector2i, index: int) -> void:
	var g: Array = GROUND[index]
	ground.set_cell(cell, _ground_sources.get(g[0], 0), g[1], _ground_alts[index] if index < _ground_alts.size() else 0)
