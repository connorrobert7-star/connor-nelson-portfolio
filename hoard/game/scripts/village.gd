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
	[VillageArt.TOWN, Vector2i(0, 0), GRASS_TINT * Color(0.9, 0.9, 0.94)],  # 20 grass, a darker patch
	[VillageArt.TOWN, Vector2i(1, 0), GRASS_TINT * Color(0.9, 0.9, 0.94)],  # 21 tufts in the darker patch
	[VillageArt.TOWN, Vector2i(0, 0), GRASS_TINT * Color(0.97, 1.03, 1.0)],  # 22 grass, a greener patch
	[VillageArt.TOWN, Vector2i(1, 0), GRASS_TINT * Color(0.97, 1.03, 1.0)],  # 23 tufts in the greener patch
	[VillageArt.TOWN, Vector2i(1, 9), PLAZA_TINT * Color(0.88, 0.87, 0.9)],  # 24 square stone, darker
	[VillageArt.TOWN, Vector2i(1, 9), PLAZA_TINT * Color(1.04, 0.98, 0.94)],  # 25 square stone, warmer
	[VillageArt.TOWN, Vector2i(7, 3), PLAZA_TINT * Color(0.72, 0.76, 0.74)],  # 26 mossy cobbles
	[VillageArt.FLOOR, Vector2i(11, 12), Color(0.62, 0.66, 0.74)],  # 27 deep grass
]
const WILD_GROUND := 10
const LOW_WATER := 6
const SPAWN := Vector2i(24, 17)
const NIGHT_GROUND := Color(0.31, 0.26, 0.4)
## Where the light gathers at the river's edge (cool, the moon's) and in the square (warm).
const MOON := Color(0.55, 0.72, 1.0)

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
## The crowd when the state has no follower count, and the most the island draws.
const CROWD_FALLBACK := 9
const CROWD_MAX := 40

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
var _crowd: Array[VillageCultist] = []  # the square's and the commons' cultists
var _labels: Array[Label] = []  # painted numbers and words in the world (fade under the HUD)
var _noise := FastNoiseLite.new()  # ground patches: value noise, same island every load
var _lamp_heads: Array[Vector2] = []  # where moths circle
var _reflections: Array = []  # [x, color] of every light the river mirrors
var _music: AudioStreamPlayer
var _loud: Array[Vector2] = []  # doors loud enough to duck the music
var _critters: Critters
var _npcs: Array = []  # [sprite, ninja character] for the villagers who stand in the hub
var _puff_frames: SpriteFrames


func build() -> void:
	map = _make_map()
	legend = LEGEND
	solid = "T~wx"
	_noise.noise_type = FastNoiseLite.TYPE_VALUE
	_noise.seed = 7
	_noise.frequency = 0.11
	_noise.fractal_octaves = 2
	add_child(_under)
	move_child(_under, 1)
	_breathe_light()
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
	_npcs.append([add_npc("farmer", Vector2i(13, 26), Vector2i(13, 27)), "Woman"])
	_npcs.append([add_npc("shrine_keeper", Vector2i(36, 12), Vector2i(36, 13)), "Master"])
	_land()
	# Features that own no plot (the buildings feature) dress the whole island.
	for f in Features.all:
		if f.plot_id() == "":
			f.build_village(self, Rect2i())
	_cultists()
	_ground_life()
	_river_glass()
	_critters = Critters.new()
	_critters.village = self
	add_child(_critters)
	_ambience()
	_fix_npcs()
	Game.event_fired.connect(_on_event)


func _ready() -> void:
	super._ready()
	ground.modulate = NIGHT_GROUND
	# One more row of dead wood above the map: at the top of the island the camera rises
	# two tiles further, so the north facades and their signs clear the HUD's corners.
	camera.limit_top = -2 * TILE
	for y in [-2, -1]:
		for x in W:
			set_tile(Vector2i(x, y), legend["T"])
	_cam_pos = _cam_target(Vector2.ZERO)
	camera.position = _cam_pos.round()
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
	for f in Features.all:
		if f.plot_id() == "":
			f.dress_village(self, Rect2i())
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
			index = 2 if h % bloom == 0 else grass_at(cell)
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
	_hud_fade()
	_duck_music()


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
		var plate := l.get_node_or_null("Plate") as CanvasItem
		if plate:
			plate.modulate.a = l.self_modulate.a


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
	for row in 2:
		for x in range(-row, W, 2):
			var t := VillageArt.sprite(props, VillageArt.tiles(VillageArt.NATURE, dead[((x + row) / 2) % 2].x, 0, 2, 2), Vector2(x * TILE + 16, (2 - row * 2) * TILE - 2 - row * 3), (x + row) % 4 == 0)
			# The back row sits deeper in the dark.
			t.modulate = Color(0.8, 0.75, 0.9) if row == 0 else Color(0.55, 0.5, 0.66)
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
	# Embers drift up out of the dark, and red eyes blink beyond the gate: the debts, waiting.
	var embers := VillageArt.embers(props, Vector2(mid, (H - 1) * TILE), Color(1.0, 0.4, 0.25, 0.7), W * TILE, 12, 10)
	embers.lifetime = 4.0
	embers.z_index = 2
	for i in 6:
		var eyes := BuildingSite.Painter.new()
		eyes.material = VillageArt.additive()
		eyes.z_index = 2
		eyes.position = Vector2([96, 200, 300, 420, 610, 760][i], (WALL_BASE_ROW + 1 + i % 2) * TILE + 6)
		eyes.fn = func(c: Node2D) -> void:
			c.draw_rect(Rect2(-2, 0, 1, 1), Color(1.0, 0.25, 0.2))
			c.draw_rect(Rect2(2, 0, 1, 1), Color(1.0, 0.25, 0.2))
			c.draw_rect(Rect2(-3, -1, 7, 3), Color(1.0, 0.2, 0.15, 0.2))
		eyes.modulate.a = 0.0
		add_child(eyes)
		var tw := eyes.create_tween().set_loops()
		tw.tween_interval(randf_range(1.0, 6.0))
		tw.tween_property(eyes, "modulate:a", 1.0, 0.5)
		tw.tween_interval(randf_range(1.5, 3.0))
		tw.tween_property(eyes, "scale:y", 0.0, 0.05)
		tw.tween_property(eyes, "scale:y", 1.0, 0.06)
		tw.tween_interval(randf_range(0.8, 2.0))
		tw.tween_property(eyes, "modulate:a", 0.0, 0.4)


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


## A door throws its own color onto the road: a trapezoid of light from the threshold down,
## a soft pool where it lands, and the river mirrors it.
func _door_light(at: Vector2, color: Color, size := 90.0) -> void:
	var door := at + Vector2(0, -6)
	VillageArt.spill(_under, door, Color(color, color.a * 0.75), 18, size * 0.6, size * 0.42)
	VillageArt.pool(_under, at + Vector2(0, 6), Color(color, color.a * 0.6), size * 0.75, 0.1)


## A lamp on a post by a door: a warm pool on the ground, moths, and a brass plate on the post
## with a number painted on it (the tavern chalks its own on a slate on an easel).
func _lamp(place: String, at: Vector2, color: Color, carrier := "brass") -> void:
	var post := VillageArt.sprite(props, VillageArt.tiles(VillageArt.TOWN, 11, 4), at)
	var head := VillageArt.sprite(props, VillageArt.tiles(VillageArt.HOUSES, 29, 16), at + Vector2(0, -12))
	head.z_index = 1
	VillageArt.pool(_under, at + Vector2(0, -2), Color(color.lerp(VillageArt.WARM, 0.35), 0.3), 120)
	var halo := VillageArt.pool(head, Vector2(0, -8), Color(color, 0.85), 30, 0.2)
	halo.z_index = 2
	_lamp_heads.append(at + Vector2(0, -20))
	var spot := at + Vector2(0, -7)
	if carrier == "slate":
		spot = at + Vector2(48, -6)
	var plate := VillageArt.paint(props, "", spot, VillageArt.BONE, 10)
	plate.z_index = 3
	VillageArt.carry(plate, carrier)
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
	_door_light(feet + Vector2(0, 8), Color(1.0, 0.4, 0.72, 0.55), 110)
	VillageArt.pool(_under, feet + Vector2(0, -56), Color(0.75, 0.35, 0.9, 0.3), 130, 0.08)
	# Outline neons only: a filled disc sign read as a purple blob over the square.
	_buzz(VillageArt.neon(props, "Sign 14/Sign 14 Glow - PINK.png", Vector2i(67, 67), 18, feet + Vector2(-56, -70), 8, 6), Color(1.0, 0.4, 0.8))
	_buzz(VillageArt.neon(props, "Sign 14/Sign 14 Glow - BLUE.png", Vector2i(67, 67), 18, feet + Vector2(56, -70), 9, 6), Color(0.4, 0.6, 1.0))
	var enter := VillageArt.neon(props, "Sign 13/Sign 13 Glow - GREEN.png", Vector2i(56, 39), 15, feet + Vector2(0, -122), 8, 5)
	enter.z_index = 2
	_buzz(enter, Color(0.5, 1.0, 0.5), 1.0)
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
	_door_light(feet + Vector2(-4, 4), Color(0.25, 0.6, 1.0, 0.5), 100)
	VillageArt.spill(_under, feet + Vector2(5, -2), Color(1.0, 0.35, 0.8, 0.35), 12, 40, 44)
	VillageArt.spill(_under, feet + Vector2(0, -2), Color(0.4, 1.0, 0.6, 0.18), 8, 30, 36)
	_buzz(VillageArt.neon(props, "Sign 5/Sign 5  Glow - BLUE.png", Vector2i(33, 33), 18, feet + Vector2(-26, -58), 10), Color(0.3, 0.6, 1.0), 1.0)
	_buzz(VillageArt.neon(props, "Sign 12/Sign 12 Glow - TEAL.png", Vector2i(60, 34), 51, feet + Vector2(14, -62), 12, 17), Color(0.3, 1.0, 0.9))
	_lamp("arcade", feet + Vector2(34, 14), Color(0.35, 0.7, 1.0))
	_bleed(feet, "freesound-cc0-picks/443091_LICHTLE_Marion_2018_2019_ArcadeCoins_wav.mp3", -20)


func _facade_shrine(r: Rect2i) -> void:
	var feet := Vector2((r.position.x + r.size.x / 2.0) * TILE, r.end.y * TILE)
	VillageArt.sprite(props, VillageArt.tiles(VillageArt.HOUSES, 0, 5, 3, 2), feet + Vector2(0, -2))
	for side in [-36, 36]:
		VillageArt.sprite(props, VillageArt.tiles(VillageArt.HOUSES, 1, 15, 2, 3), feet + Vector2(side, -4), side > 0)
		VillageArt.pool(_under, feet + Vector2(side, -14), Color(VillageArt.EMBER, 0.42), 80, 0.22)
	_shrine_flame = VillageArt.anim(props, VillageArt.frames(VillageArt.FLAME, Vector2i(20, 30), 10, 12), feet + Vector2(0, -22))
	_shrine_flame.material = VillageArt.additive()
	VillageArt.pool(_under, feet + Vector2(0, -10), Color(Palette.GLOW, 0.5), 130, 0.18)
	_door_light(feet + Vector2(0, 6), Color(Palette.GLOW, 0.45), 90)
	VillageArt.embers(props, feet + Vector2(0, -30), Color(Palette.GLOW, 0.9), 20, 8, 22)
	_lamp("shrine", feet + Vector2(-40, 14), Palette.GLOW)
	_bleed(feet, "owlishmedia-creepy-chanting/chant5.ogg", -18)
	_crackle(feet + Vector2(0, -10))


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
	VillageArt.pool(_under, feet + Vector2(0, -8), Color(VillageArt.SICK, 0.4), 100, 0.15)
	for side in [-1, 1]:
		# The towers' faces catch the sick light of what waits outside.
		var face := VillageArt.pool(props, feet + Vector2(side * 32, -22), Color(VillageArt.SICK, 0.3), 34, 0.25)
		face.z_index = 2
	VillageArt.embers(props, feet + Vector2(0, -6), Color(VillageArt.SICK, 0.6), 30, 6, 12)
	_lamp("gate", Vector2(feet.x - 56, (ROAD_ROW + 1) * TILE - 1), VillageArt.SICK)
	_bleed(feet + Vector2(0, 40), "rubberduck-80-rpg-sfx/creature_monster_02.ogg", -16)


func _tavern_and_shop() -> void:
	var tf := Vector2((TAVERN.position.x + TAVERN.size.x / 2.0) * TILE, TAVERN.end.y * TILE)
	VillageArt.sprite(props, VillageArt.tiles(VillageArt.HOUSES, 0, 0, 4, 3), tf + Vector2(0, 1))
	_buzz(VillageArt.neon(props, "Sign 7/Sign 7 Glow - PINK.png", Vector2i(28, 34), 19, tf + Vector2(22, -50), 10), Color(1.0, 0.4, 0.75), 1.0)
	_door_light(tf + Vector2(-8, 4), Color(1.0, 0.6, 0.25, 0.55), 100)
	_lamp("tavern", tf + Vector2(-26, 14), Color(1.0, 0.6, 0.3), "slate")
	_window(tf + Vector2(-20, -18), Color(1.0, 0.65, 0.3))
	_window(tf + Vector2(12, -18), Color(1.0, 0.65, 0.3))
	_chimney(tf + Vector2(18, -50))
	var cat_at := tf + Vector2(-14, -38)
	_critter_cat(cat_at)
	_bleed(tf, "freesound-cc0-picks/473790_Monk_Chanting.mp3", -26)
	_chatter(tf, ["ninja-adventure/Audio/Sounds/Voice/Voice%d.ogg", 10], -22, Vector2(0.9, 2.6))
	block(TAVERN)
	add_door(TAVERN_DOOR, "tavern", Room.ENTRANCE)
	var sf := Vector2((SHOP.position.x + SHOP.size.x / 2.0) * TILE, SHOP.end.y * TILE)
	VillageArt.sprite(props, VillageArt.tiles(VillageArt.HOUSES, 16, 0, 3, 3), sf + Vector2(0, 1))
	_buzz(VillageArt.neon(props, "Sign 1/Sign 1 Glow - OPEN.png", Vector2i(31, 24), 72, sf + Vector2(0, -52), 12, 18), Color(1.0, 0.85, 0.4), 1.0)
	_door_light(sf + Vector2(0, 4), Color(0.4, 1.0, 0.8, 0.45), 90)
	_window(sf + Vector2(-14, -16), Color(0.5, 1.0, 0.85))
	_chatter(sf, ["kenney-interface-sounds/Audio/tick_00%d.ogg", 1], -26, Vector2(0.95, 1.05), [1, 2, 4])
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
	VillageArt.pool(_under, stone_feet + Vector2(0, -6), Color(VillageArt.BONE, 0.32), 120, 0.08)
	# The week's extra is cut into the stone's face, lit from inside.
	var digits := VillageArt.paint(ledger_stone, "", Vector2(0, -7), VillageArt.BONE, 10)
	digits.name = "Digits"
	VillageArt.carry(digits, "carved")
	var inner := VillageArt.glow(ledger_stone, Vector2(0, -7), Color(VillageArt.BONE, 0.35), 34)
	inner.scale.y *= 0.45
	inner.z_index = 1
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
		VillageArt.pool(_under, at + Vector2(0, -4), Color(1.0, 0.68, 0.38, 0.3), 124)
		VillageArt.pool(head, Vector2(0, -8), Color(1.0, 0.7, 0.4, 0.8), 26, 0.2).z_index = 2
		_lamp_heads.append(at + Vector2(0, -20))
		block(Rect2i(corner, Vector2i.ONE))
	# Cracks and pebbles so the slab reads as stone, not paint.
	for y in range(PLAZA.position.y + 1, PLAZA.end.y - 1):
		for x in range(PLAZA.position.x + 1, PLAZA.end.x - 1):
			var h := absi((x * 92821) ^ (y * 68917)) % 23
			if h < 4 and not LEDGER.grow(2).has_point(Vector2i(x, y)):
				var s := Sprite2D.new()
				s.texture = VillageArt.tiles(VillageArt.FLOOR_DETAIL, [5, 6, 7, 3][h], 0)
				s.centered = false
				s.position = Vector2(x * TILE + (h * 3) % 5 - 2, y * TILE + (h * 7) % 5 - 2)
				s.modulate = Color(0.3, 0.28, 0.36, 0.5)
				s.flip_h = (x + y) % 2 == 0
				s.flip_v = h % 2 == 0
				_under.add_child(s)


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


## The flock's nameless cultists (state.followers.cultists, which grows with the follower
## room the buildings make), five to the square for every four on the commons. Settlers in
## opened parcels count toward it. Without the field: nine, plus the settlers.
func _cultists() -> void:
	_dress_crowd()
	Game.state_changed.connect(_dress_crowd)


## How many cultists the village has: the state's count, capped; -1 when it doesn't say.
static func crowd_size() -> int:
	var f: Variant = Game.state.get("followers")
	if f is Dictionary and (f as Dictionary).get("cultists") != null:
		return clampi(int((f as Dictionary).cultists), 0, CROWD_MAX)
	return -1


func _settled() -> int:
	var n := 0
	for id: String in _settlers:
		n += (_settlers[id] as Array).size()
	return n


func _dress_crowd() -> void:
	var total := crowd_size()
	var want := CROWD_FALLBACK if total < 0 else maxi(0, total - _settled())
	while _crowd.size() < want:
		var i := _crowd.size()
		_crowd.append(_add_cultist(i, PLAZA_ROAM if i % 9 < 5 else COMMONS_ROAM))
	while _crowd.size() > want:
		var c: VillageCultist = _crowd.pop_back()
		cultists.erase(c)
		c.queue_free()


func _add_cultist(look: int, roam: Rect2i, at := Vector2.INF) -> VillageCultist:
	var area := Rect2(Vector2(roam.position * TILE) + Vector2(4, 12), Vector2(roam.size * TILE) - Vector2(8, 12))
	var c := VillageCultist.new()
	c.look = look
	c.area = area
	c.is_walkable = is_walkable
	c.position = at if at != Vector2.INF else area.position + Vector2(randf() * area.size.x, randf() * area.size.y)
	c.leader = leader
	c.shrine = feet_at(Vector2i(SHRINE.position.x + SHRINE.size.x / 2, SHRINE.end.y))
	c.crowd = cultists
	# Each carries a torch: a small warm pool walks with them.
	c.light = VillageArt.pool(_under, c.position, Color(1.0, 0.6, 0.3, 0.26), 40, 0.25)
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
	# With a follower count, settlers come out of it while it lasts.
	var n := SETTLERS_PER_PARCEL
	if crowd_size() >= 0:
		n = clampi(crowd_size() - _settled(), 0, SETTLERS_PER_PARCEL)
	for i in n:
		var at := Vector2(roam.get_center() * TILE) + Vector2((i - 0.5) * 40, 8)
		var c := _add_cultist(cultists.size() + i, roam, at)
		have.append(c)
		if show:
			VillageArt.burst(props, at + Vector2(0, -6), Color(0.85, 0.8, 0.75), 12, 40, 0.5)
			c.poke()
	_settlers[parcel_id] = have
	_dress_crowd()


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
	p.max_distance = 160.0
	p.attenuation = 1.6
	p.bus = "Ambience"
	if db >= -16:
		_loud.append(at)
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
		music.bus = "Music"
		music.autoplay = true
		add_child(music)
		_music = music
	# A night bed under the music: wind over the island.
	var wind_path := VillageArt.PACKS + "ninja-adventure/Audio/Sounds/Ambient/Wind.ogg"
	if ResourceLoader.exists(wind_path):
		var w: AudioStreamOggVorbis = load(wind_path)
		w.loop = true
		var bed := AudioStreamPlayer.new()
		bed.stream = w
		bed.volume_db = -30.0
		bed.bus = "Ambience"
		bed.autoplay = true
		add_child(bed)
	# The flock murmurs around the square.
	_chatter(Vector2((PLAZA.position.x + PLAZA.size.x / 2.0) * TILE, (PLAZA.position.y + PLAZA.size.y / 2.0) * TILE), ["owlishmedia-creepy-chanting/chant%d.ogg", 0], -30, Vector2(0.8, 1.0), [7, 9, 11, 13]).gap = Vector2(3.0, 7.0)


## A looping sound tied to a spot (the river along its bank).
func _loop(at: Vector2, path: String, db: float, reach: float) -> void:
	var full := VillageArt.PACKS + path
	if not ResourceLoader.exists(full):
		return
	var stream: AudioStreamOggVorbis = load(full)
	stream.loop = true
	var p := AudioStreamPlayer2D.new()
	p.stream = stream
	p.volume_db = db
	p.max_distance = reach
	p.attenuation = 1.4
	p.bus = "Ambience"
	p.position = at
	p.autoplay = true
	add_child(p)


## The music steps back near the loud doors so each door owns its patch.
func _duck_music() -> void:
	if _music == null:
		return
	var near := 999.0
	for at in _loud:
		near = minf(near, leader.position.distance_to(at))
	var want := lerpf(-22.0, -18.0, clampf((near - 40.0) / 120.0, 0.0, 1.0))
	_music.volume_db = move_toward(_music.volume_db, want, 0.2)


# --- life and light --------------------------------------------------------------------------

## One slow breath over every pool of light on the island (14 s, about 6% either way).
func _breathe_light() -> void:
	_under.modulate = Color(0.94, 0.94, 0.94)
	var tw := _under.create_tween().set_loops()
	tw.tween_property(_under, "modulate", Color(1.06, 1.06, 1.06), 7.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_under, "modulate", Color(0.94, 0.94, 0.94), 7.0).set_trans(Tween.TRANS_SINE)


## A neon sign at its own size, buzzing: now and then it stutters, and the river mirrors it.
func _buzz(neon: AnimatedSprite2D, color: Color, size := 0.8) -> void:
	neon.scale = Vector2.ONE * size
	_reflections.append([neon.position.x, color])
	var tw := neon.create_tween().set_loops()
	tw.tween_interval(randf_range(2.5, 7.0))
	tw.tween_property(neon, "modulate:a", 0.25, 0.03)
	tw.tween_property(neon, "modulate:a", 1.0, 0.04)
	tw.tween_interval(0.06)
	tw.tween_property(neon, "modulate:a", 0.4, 0.03)
	tw.tween_property(neon, "modulate:a", 1.0, 0.05)


## A lit window: warm glass, and now and then someone walks past inside.
func _window(at: Vector2, color: Color) -> void:
	var g := VillageArt.pool(props, at, Color(color, 0.55), 22, 0.12)
	g.z_index = 1
	var pane := VillageArt.glow(g, Vector2.ZERO, Color(color, 0.7), 10)
	pane.scale = Vector2(0.09, 0.07)
	var tw := g.create_tween().set_loops()
	tw.tween_interval(randf_range(10.0, 20.0))
	tw.tween_property(g, "modulate", Color(0.35, 0.3, 0.35), 0.25)
	tw.tween_property(g, "position:x", at.x + 2.0, 0.5)
	tw.tween_property(g, "modulate", Color.WHITE, 0.3)
	tw.tween_property(g, "position:x", at.x, 0.01)


func _puffs() -> SpriteFrames:
	if _puff_frames == null:
		_puff_frames = SpriteFrames.new()
		_puff_frames.set_animation_speed("default", 7.0)
		_puff_frames.set_animation_loop("default", false)
		for i in 6:
			_puff_frames.add_frame("default", VillageArt.tex(VillageArt.SMOKE, Rect2(i * 32, 0, 32, 32)))
	return _puff_frames


## Chimney smoke: one puff every second and a half, rising and thinning.
func _chimney(at: Vector2) -> void:
	var t := Timer.new()
	t.wait_time = 1.5
	t.autostart = true
	add_child(t)
	t.timeout.connect(func() -> void:
		var puff := VillageArt.anim(props, _puffs(), at, false)
		puff.modulate = Color(0.75, 0.7, 0.8, 0.4)
		puff.scale = Vector2(0.5, 0.5)
		puff.z_index = 4
		var tw := puff.create_tween()
		tw.tween_property(puff, "position", at + Vector2(randf_range(4, 9), -20), 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(puff, "scale", Vector2(0.8, 0.8), 0.85)
		puff.animation_finished.connect(puff.queue_free))


## A critter that keeps its spot and hops off when the leader comes close, then comes back.
class Hopper extends AnimatedSprite2D:
	var village: Level
	var home := Vector2.ZERO
	var away := Vector2(14, -4)
	var near := 36.0
	var sound := ""
	var dives := false  # a frog: hops into the river instead and surfaces later
	var _busy := false

	func _process(_delta: float) -> void:
		if _busy or village == null or not is_instance_valid(village.leader):
			return
		if village.leader.position.distance_to(global_position) < near:
			_hop()

	func _hop() -> void:
		_busy = true
		var side := -1.0 if village.leader.position.x > global_position.x else 1.0
		var to := home + Vector2(away.x * side, away.y)
		flip_h = side < 0.0
		if sound != "":
			VillageArt.sfx(sound, randf_range(0.9, 1.2), -18)
		var tw := create_tween()
		tw.tween_property(self, "position", position.lerp(to, 0.5) + Vector2(0, -6), 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(self, "position", to, 0.14).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		await tw.finished
		if dives:
			VillageArt.sfx("ninja-adventure/Audio/Sounds/Elemental/WaterDrop.ogg", randf_range(0.8, 1.0), -20)
			VillageArt.burst(get_parent(), position + Vector2(0, -2), Color(0.7, 0.85, 1.0), 6, 30, 0.4)
			visible = false
		await VillageArt.wait(self, randf_range(5.0, 9.0))
		while village.leader.position.distance_to(home) < near * 1.6:
			await VillageArt.wait(self, 1.0)
		visible = true
		var back := create_tween()
		back.tween_property(self, "position", home, 0.3).set_trans(Tween.TRANS_QUAD)
		await back.finished
		_busy = false


func _hopper(sheet: String, at: Vector2, away: Vector2, dives := false) -> Hopper:
	var h := Hopper.new()
	h.sprite_frames = VillageArt.frames(sheet, Vector2i(16, 16), 2, 2.0)
	h.offset = Vector2(0, -8)
	h.position = at
	h.home = at
	h.away = away
	h.dives = dives
	h.village = self
	props.add_child(h)
	h.play("default")
	h.frame = randi() % 2
	return h


func _critter_cat(at: Vector2) -> void:
	var cat := _hopper(VillageArt.PACKS + "ninja-adventure/Actor/Animal/CatBlack/SpriteSheet.png", at, Vector2(22, -2))
	cat.z_index = 2
	cat.near = 44.0
	cat.sound = "ninja-adventure/Audio/Sounds/Jump & Bounce/Bounce3.ogg"


## Sounds a place makes now and then (voices in the tavern, the shop's clock), heard only nearby.
class Chatter extends AudioStreamPlayer2D:
	var village: Level
	var streams: Array[AudioStream] = []
	var gap := Vector2(0.8, 2.4)
	var pitch := Vector2(0.9, 1.1)
	var _wait := 1.0

	func _process(delta: float) -> void:
		_wait -= delta
		if _wait > 0.0 or streams.is_empty() or village == null:
			return
		_wait = randf_range(gap.x, gap.y)
		if village.leader.position.distance_to(global_position) > max_distance:
			return
		stream = streams[randi() % streams.size()]
		pitch_scale = randf_range(pitch.x, pitch.y)
		play()


func _chatter(at: Vector2, pattern: Array, db: float, pitch: Vector2, picks: Array = []) -> Chatter:
	var c := Chatter.new()
	c.village = self
	c.position = at
	c.volume_db = db
	c.max_distance = 160.0
	c.attenuation = 1.6
	c.bus = "Ambience"
	c.pitch = pitch
	if pattern.size() > 1 and picks.is_empty():
		picks = range(1, int(pattern[1]) + 1)
	for i: int in picks:
		var path := VillageArt.PACKS + (str(pattern[0]) % i)
		if ResourceLoader.exists(path):
			c.streams.append(load(path))
	if pattern[0] == "kenney-interface-sounds/Audio/tick_00%d.ogg":
		c.gap = Vector2(1.0, 1.0)
	add_child(c)
	return c


## The shrine fire crackles.
func _crackle(at: Vector2) -> void:
	var c := _chatter(at, ["ninja-adventure/Audio/Sounds/Elemental/Fire%s.ogg", 0], -24, Vector2(0.7, 1.0), [])
	c.streams.clear()
	for f in ["Fire", "Fire2", "Fire3"]:
		c.streams.append(load(VillageArt.PACKS + "ninja-adventure/Audio/Sounds/Elemental/%s.ogg" % f))
	c.gap = Vector2(0.35, 1.1)


## Hub villagers stand on the world grid: their 16 px Ninja Adventure walkers, not facesets.
func _fix_npcs() -> void:
	for pair: Array in _npcs:
		var s := pair[0] as Sprite2D
		var sheet := VillageArt.PACKS + "ninja-adventure/Actor/Character/%s/SpriteSheet.png" % pair[1]
		if s == null or not ResourceLoader.exists(sheet):
			continue
		s.texture = VillageArt.tex(sheet, Rect2(0, 0, 16, 16))
		s.hframes = 1
		s.vframes = 1
		s.frame = 0
		s.offset = Vector2(0, -8)
		var shadow := VillageArt.glow(s, Vector2(0, -1), Color(0, 0, 0, 0.5), 14)
		shadow.material = null
		shadow.scale.y *= 0.4
		shadow.show_behind_parent = true
		VillageArt.breathe(s, 0.04, 2.2)
		VillageArt.pool(_under, s.position + Vector2(0, -6), Color(VillageArt.WARM, 0.18), 48, 0.15)


## Fireflies drifting over the grass and moths circling every lamp: single pixels of light,
## drawn in one pass and only where the camera looks.
class Critters extends Node2D:
	const FIREFLY := Color(0.85, 1.0, 0.5)
	const MOTH := Color(1.0, 0.92, 0.78)
	var village: Village
	var _flies: Array[Vector4] = []  # base x, base y, phase, speed
	var _t := 0.0

	func _ready() -> void:
		material = VillageArt.additive()
		z_index = 5
		var tries := 0
		while _flies.size() < 64 and tries < 2000:
			tries += 1
			var cell := Vector2i(randi_range(1, Village.W - 2), randi_range(Village.BANK_ROW + 1, Village.ROAD_ROW - 1))
			if village.map[cell.y][cell.x] != "." or village._blocked.has(cell):
				continue
			_flies.append(Vector4(cell.x * 16 + randf() * 16, cell.y * 16 + randf() * 16, randf() * TAU, randf_range(0.5, 1.1)))

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var view := get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()
		view = view.grow(8)
		for f in _flies:
			var p := Vector2(f.x + sin(_t * 0.4 * f.w + f.z) * 14.0 + sin(_t * 1.3 + f.z * 2.0) * 3.0, f.y + sin(_t * 0.6 * f.w + f.z * 1.7) * 8.0 - absf(sin(_t * 0.25 + f.z)) * 6.0)
			if not view.has_point(p):
				continue
			var blink := clampf(sin(_t * 1.7 * f.w + f.z * 3.0) * 1.6 + 0.4, 0.0, 1.0)
			if blink <= 0.02:
				continue
			p = p.floor()
			draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), Color(FIREFLY, 0.16 * blink))
			draw_rect(Rect2(p, Vector2.ONE), Color(FIREFLY, 0.95 * blink))
		var i := 0
		for head in village._lamp_heads:
			if not view.has_point(head):
				i += 3
				continue
			for k in 3:
				i += 1
				var ph := float(i) * 2.1
				var r := 5.0 + (i % 3) * 2.0
				var p := head + Vector2(cos(_t * (3.0 + k) + ph) * r, sin(_t * (4.1 + k * 0.7) + ph) * r * 0.6 - 2.0)
				draw_rect(Rect2(p.floor(), Vector2.ONE), Color(MOTH, 0.8))


## Life in the grass: flowers and clover grow in clusters, pebbles, worn earth along the paths
## the flock walks, the carved ring under the ledger stone, moss in the square's corners and
## puddles that catch the lamps.
func _ground_life() -> void:
	var flowers := [[5, 2], [5, 2], [6, 2], [7, 2], [0, 2], [1, 2], [2, 2], [3, 2]]
	var stones := [[3, 0], [3, 0]]
	var open_land: Array[Rect2i] = [PARCELS.home.rect, PARCELS.commons.rect]
	for land_rect in open_land:
		for y in range(land_rect.position.y, land_rect.end.y):
			for x in range(land_rect.position.x, land_rect.end.x):
				var cell := Vector2i(x, y)
				var h := absi((x * 92837111) ^ (y * 689287499)) % 997
				if h % 41 != 0 or map[y][x] != "." or _blocked.has(cell) or FIELDS.grow(1).has_point(cell):
					continue
				# A cluster of 3 to 7 around this tile, of one kind.
				var kind: Array = flowers if h % 7 else stones
				var n := (3 + h % 5) if kind == flowers else 2
				for k in n:
					var off := Vector2(((h * (k + 3)) % 23) - 11, ((h * (k + 7)) % 17) - 8)
					var at := Vector2(x * TILE + 8, y * TILE + 8) + off
					var c := Vector2i((at / TILE).floor())
					if c.y < 0 or c.y >= H or map[c.y][c.x] != "." or _blocked.has(c):
						continue
					var pick: Array = kind[(h + k) % kind.size()] if kind == stones else kind[(h / 3 + k % 2) % kind.size()]
					var d := Sprite2D.new()
					d.texture = VillageArt.tiles(VillageArt.FLOOR_DETAIL, pick[0], pick[1])
					d.position = at.floor()
					d.flip_h = (h + k) % 2 == 0
					d.modulate = Color(0.5, 0.48, 0.62) if kind == flowers else Color(0.42, 0.4, 0.5)
					_under.add_child(d)
	# Soft hollows in the grass where the dark pools: big, faint shadows on the noise's low ground.
	for y in range(BANK_ROW + 1, ROAD_ROW, 3):
		for x in range(1, W - 1, 3):
			var n := _noise.get_noise_2d(x + 1.5, y + 1.5)
			if n > -0.12:
				continue
			var shade := VillageArt.glow(_under, Vector2(x * TILE + 24, y * TILE + 24), Color(0.02, 0.0, 0.06, clampf(-n, 0.0, 0.5) * 0.6), 120)
			shade.material = null
			shade.scale.y *= 0.6
			_under.move_child(shade, 0)
	# Worn earth where feet go: from the house and the shop to the square, the fields to the road.
	for path: Array in [[Vector2i(9, 18), Vector2i(13, 18)], [Vector2i(30, 20), Vector2i(31, 21)], [Vector2i(10, 26), Vector2i(20, 26)], [Vector2i(22, 22), Vector2i(22, 22)]]:
		var a: Vector2i = path[0]
		var b: Vector2i = path[1]
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
				if map[y][x] != "." or _blocked.has(Vector2i(x, y)):
					continue
				var d := Sprite2D.new()
				d.texture = VillageArt.tiles(VillageArt.TOWN, 4 + (x + y) % 3, 3)
				d.centered = false
				d.position = Vector2(x * TILE, y * TILE)
				d.modulate = Color(0.42, 0.34, 0.4, 0.55)
				_under.add_child(d)
	_sigil()
	_puddles()


## A ring carved into the square around the ledger stone, its runes faintly lit.
func _sigil() -> void:
	var at := Vector2((LEDGER.position.x + 1) * TILE, LEDGER.end.y * TILE - 4)
	var ring := BuildingSite.Painter.new()
	ring.position = at
	ring.fn = func(c: Node2D) -> void:
		for r: float in [30.0, 25.0]:
			var pts := PackedVector2Array()
			for i in 49:
				var a := TAU * i / 48.0
				pts.append((Vector2(cos(a) * r, sin(a) * r * 0.5)).round())
			c.draw_polyline(pts, Color(0.05, 0.03, 0.08, 0.55), 1.0)
		for i in 12:
			var a := TAU * i / 12.0
			var p := Vector2(cos(a) * 27.5, sin(a) * 13.75).round()
			c.draw_rect(Rect2(p - Vector2(1, 0), Vector2(3, 1)), Color(0.05, 0.03, 0.08, 0.6))
	_under.add_child(ring)
	var runes := BuildingSite.Painter.new()
	runes.position = at
	runes.material = VillageArt.additive()
	runes.fn = func(c: Node2D) -> void:
		for i in 12:
			var a := TAU * i / 12.0
			var p := Vector2(cos(a) * 27.5, sin(a) * 13.75).round()
			c.draw_rect(Rect2(p, Vector2.ONE), Color(VillageArt.BRASS, 0.7))
	_under.add_child(runes)
	var tw := runes.create_tween().set_loops()
	tw.tween_property(runes, "modulate:a", 0.35, 2.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(runes, "modulate:a", 1.0, 2.2).set_trans(Tween.TRANS_SINE)


## Puddles on the square: dark water that throws back the nearest lamp.
func _puddles() -> void:
	for spot: Array in [[Vector2i(16, 15), Color(1.0, 0.7, 0.4)], [Vector2i(27, 19), Color(1.0, 0.7, 0.4)], [Vector2i(25, 14), Color(1.0, 0.45, 0.75)], [Vector2i(17, 20), Color(1.0, 0.7, 0.4)]]:
		var cell: Vector2i = spot[0]
		var at := Vector2(cell.x * TILE + 8, cell.y * TILE + 8)
		var w := 10.0 + (cell.x % 3) * 3.0
		var dark := Polygon2D.new()
		var pts := PackedVector2Array()
		for i in 12:
			var a := TAU * i / 12.0
			pts.append((Vector2(cos(a) * w, sin(a) * w * 0.38) + Vector2(0, (i % 3) * 0.4)).round())
		dark.polygon = pts
		dark.color = Color(0.04, 0.03, 0.1, 0.5)
		dark.position = at
		_under.add_child(dark)
		var shine := VillageArt.pool(_under, at + Vector2(-2, 0), Color(spot[1], 0.35), w * 1.4, 0.3)
		shine.scale.y *= 0.3
		var edge := Polygon2D.new()
		edge.polygon = PackedVector2Array([Vector2(-w * 0.5, -1), Vector2(w * 0.3, -2), Vector2(w * 0.35, -1), Vector2(-w * 0.4, 0)])
		edge.color = Color(spot[1], 0.35)
		edge.material = VillageArt.additive()
		edge.position = at.round()
		_under.add_child(edge)


## The river: a glassy overlay that ripples and drifts downstream, mirrors of every lamp and
## neon, sparkle on the bank line, lilies, reeds, frogs and a fish that jumps now and then.
func _river_glass() -> void:
	var water := ColorRect.new()
	water.position = Vector2(0, 2 * TILE)
	water.size = Vector2(W * TILE, 3 * TILE)
	water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://features/village/river.gdshader")
	mat.set_shader_parameter("size", water.size)
	var xs := PackedFloat32Array()
	var cols := PackedColorArray()
	for r: Array in _reflections.slice(0, 12):
		xs.append(float(r[0]))
		cols.append(r[1])
	for i in range(xs.size(), 12):
		xs.append(-999.0)
		cols.append(Color(0, 0, 0, 0))
	mat.set_shader_parameter("refl_x", xs)
	mat.set_shader_parameter("refl_col", cols)
	water.material = mat
	_under.add_child(water)
	# The moon's cool rim along the near bank, and a fainter one on the far side.
	var rim := VillageArt.glow(_under, Vector2(W * TILE / 2.0, BANK_ROW * TILE - 2), Color(MOON, 0.3), 128)
	rim.scale = Vector2(W * TILE / 100.0, 0.09)
	var far := VillageArt.glow(_under, Vector2(W * TILE / 2.0, 2 * TILE + 2), Color(MOON, 0.18), 128)
	far.scale = Vector2(W * TILE / 100.0, 0.06)
	var sparkle := CPUParticles2D.new()
	sparkle.amount = 14
	sparkle.lifetime = 0.9
	sparkle.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparkle.emission_rect_extents = Vector2(W * TILE / 2.0, 1)
	sparkle.position = Vector2(W * TILE / 2.0, BANK_ROW * TILE - 3)
	sparkle.gravity = Vector2.ZERO
	sparkle.initial_velocity_max = 0.0
	sparkle.material = VillageArt.additive()
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.8, 0.9, 1.0, 0.0))
	ramp.add_point(0.3, Color(0.85, 0.95, 1.0, 0.9))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.8, 0.9, 1.0, 0.0))
	sparkle.color_ramp = ramp
	_under.add_child(sparkle)
	# Leaves drift with the current.
	var drift := CPUParticles2D.new()
	drift.texture = VillageArt.tex(VillageArt.LEAF, Rect2(0, 0, 8, 7))
	drift.amount = 6
	drift.lifetime = 14.0
	drift.preprocess = 14.0
	drift.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	drift.emission_rect_extents = Vector2(4, TILE * 1.2)
	drift.position = Vector2(-8, 3.5 * TILE)
	drift.direction = Vector2.RIGHT
	drift.spread = 4.0
	drift.gravity = Vector2.ZERO
	drift.initial_velocity_min = 60.0
	drift.initial_velocity_max = 80.0
	drift.angular_velocity_min = -20
	drift.angular_velocity_max = 20
	drift.color = Color(0.55, 0.45, 0.6)
	_under.add_child(drift)
	# Lilies and reeds.
	var lily := VillageArt.frames(VillageArt.PACKS + "ninja-adventure/Backgrounds/Animated/Plant/SpriteSheet16x16.png", Vector2i(16, 16), 4, 3.0)
	for x: int in [7, 18, 26, 37, 47, 56]:
		var l := VillageArt.anim(_under, lily, Vector2(x * TILE + 4, (3 + x % 2) * TILE + 6))
		l.modulate = Color(0.55, 0.55, 0.7)
		VillageArt.bob(l, 0.5, 3.0)
	for x in range(1, W - 1):
		var h := (x * 37) % 11
		if h > 3:
			continue
		var reed := VillageArt.sprite(props, VillageArt.tiles(VillageArt.FLOOR_DETAIL, h, 2), Vector2(x * TILE + (h * 5) % 12, BANK_ROW * TILE + 4))
		reed.modulate = Color(0.55, 0.55, 0.65)
		_sway(reed, 0.12)
	# Frogs on the bank.
	for x: int in [8, 24, 44]:
		var frog := _hopper(VillageArt.PACKS + "ninja-adventure/Actor/Animal/Frog/SpriteSheet.png", Vector2(x * TILE + 8, BANK_ROW * TILE + 10), Vector2(10, -14), true)
		frog.modulate = Color(0.75, 0.75, 0.85)
		frog.sound = "ninja-adventure/Audio/Sounds/Jump & Bounce/Bounce%d.ogg" % (1 + x % 5)
	_fish()
	# The water, heard along the bank.
	for x: int in [8, 30, 52]:
		_loop(Vector2(x * TILE, 3 * TILE), "ninja-adventure/Audio/Sounds/Ambient/River.ogg", -16, 170.0)


## Now and then a fish jumps: an arc, a ring and a plop.
func _fish() -> void:
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = randf_range(4.0, 10.0)
	add_child(t)
	t.timeout.connect(func() -> void:
		t.start(randf_range(8.0, 20.0))
		var x := leader.position.x + randf_range(-160, 160)
		x = clampf(x, 24, W * TILE - 24)
		var y := randf_range(2.6, 4.3) * TILE
		var fish := Polygon2D.new()
		fish.polygon = PackedVector2Array([Vector2(-3, 0), Vector2(1, -1), Vector2(3, 0), Vector2(1, 1)])
		fish.color = Color(0.75, 0.85, 1.0)
		fish.position = Vector2(x, y)
		fish.z_index = 3
		add_child(fish)
		var dir := 1.0 if randf() < 0.5 else -1.0
		fish.scale.x = dir
		var tw := fish.create_tween()
		tw.tween_property(fish, "position", Vector2(x + 8 * dir, y - 10), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(fish, "rotation", -0.6 * dir, 0.25)
		tw.tween_property(fish, "position", Vector2(x + 16 * dir, y), 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(fish, "rotation", 0.6 * dir, 0.25)
		tw.tween_callback(func() -> void:
			_ring(Vector2(x + 16 * dir, y))
			VillageArt.sfx("ninja-adventure/Audio/Sounds/Elemental/WaterDrop.ogg", randf_range(0.8, 1.1), -20)
			fish.queue_free())
		_ring(Vector2(x, y)))
	t.start()


## A ring spreading on the water.
func _ring(at: Vector2) -> void:
	var ring := BuildingSite.Painter.new()
	ring.position = at.round()
	ring.material = VillageArt.additive()
	ring.fn = func(c: Node2D) -> void:
		var pts := PackedVector2Array()
		for i in 17:
			var a := TAU * i / 16.0
			pts.append(Vector2(cos(a) * 4.0, sin(a) * 1.6))
		c.draw_polyline(pts, Color(0.75, 0.88, 1.0, 0.8), 1.0)
	ring.z_index = 2
	add_child(ring)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector2(2.6, 2.6), 0.7).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.7)
	tw.tween_callback(ring.queue_free)


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
		VillageArt.number(_door_lamps.casino, " ".join(prices) if not prices.is_empty() else VillageArt.dollars(extra))
	if _door_lamps.has("arcade"):
		# The arcade feature lights a candle per flame over its door; the lamp only counts
		# them when nothing else does.
		var flames: Variant = s.get("minigames", {}).get("flames", {})
		var left := int((flames as Dictionary).get("left", 0)) if flames is Dictionary else 0
		var drawn := Features.for_plot("arcade") != null
		_door_lamps.arcade.label_settings.font_color = VillageArt.BRASS
		VillageArt.number(_door_lamps.arcade, "" if drawn else ("1 flame" if left == 1 else "%d flames" % left))
	if _door_lamps.has("shrine"):
		var days: Variant = s.get("village", {}).get("stats", {}).get("days_since_landing")
		VillageArt.number(_door_lamps.shrine, "" if days == null else ("today" if int(days) == 0 else ("1 day" if int(days) == 1 else "%d days" % int(days))))
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
		_door_lamps.gate.label_settings.font_color = VillageArt.SICK
		VillageArt.number(_door_lamps.gate, VillageArt.dollars(hp) if hp > 0 and not drawn else "")
	if _door_lamps.has("tavern"):
		var t: Dictionary = s.get("tavern", {})
		VillageArt.number(_door_lamps.tavern, "%s/%s" % [VillageArt.dollars(t.get("spent_cents", 0)), VillageArt.dollars(t.get("budget_cents", 0))])
	if _door_lamps.has("shop"):
		var can := int(s.get("shop", {}).get("can_spend_cents", 0))
		VillageArt.number(_door_lamps.shop, VillageArt.dollars(can) if can > 0 else "")
	var digits: Label = ledger_stone.get_node("Digits")
	VillageArt.number(digits, VillageArt.dollars(extra))


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
	# A stake at the field's corner with a tag: spent, then the budget; red only when over.
	var sign_at := Vector2(FIELDS.end.x * TILE + 8, FIELDS.end.y * TILE)
	var stake := BuildingSite.Painter.new()
	stake.position = sign_at
	stake.fn = func(c: Node2D) -> void:
		c.draw_rect(Rect2(-2, -22, 4, 22), VillageArt.INK)
		c.draw_rect(Rect2(-1, -21, 2, 21), VillageArt.WOOD)
		c.draw_rect(Rect2(-1, -21, 1, 21), VillageArt.WOOD_LIGHT)
		c.draw_rect(Rect2(-3, -22, 6, 2), VillageArt.WOOD_DARK)
	dynamic.add_child(stake)
	var spent := int(crops.spent_cents)
	var budget := int(crops.budget_cents)
	var text := "%s/%s" % [VillageArt.dollars(spent), VillageArt.dollars(budget)]
	var tag := VillageArt.paint(stake, text, Vector2(14, -12), VillageArt.BONE, 10)
	tag.z_index = 1
	VillageArt.carry(tag, "tag")
	VillageArt.sway(tag, 0.03, 2.6)
	if spent > budget:
		# Only the part over budget burns red, on top of the same tag.
		var font := tag.label_settings.font
		var full := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var head := font.get_string_size(VillageArt.dollars(spent), HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var red := VillageArt.paint(tag, VillageArt.dollars(spent), Vector2.ZERO, Color("ff7a6a"), 10)
		red.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		red.position = Vector2(floorf((tag.size.x - full) / 2.0), 0)
		red.size.x = head + 2
		VillageArt.pool(stake, Vector2(8, -12), Color(1.0, 0.3, 0.25, 0.3), 30, 0.3)


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
		# Packed: the overflow sleeps it off outside, hooded cultists curled on the ground
		# with a slow z drifting up off each.
		for i in 3:
			var look: Vector2i = VillageCultist.LOOKS[(i * 5 + 1) % VillageCultist.LOOKS.size()]
			var s := Sprite2D.new()
			s.texture = VillageArt.tex(VillageArt.HOODED_A, Rect2(look.x * 16, look.y * 16, 16, 16))
			s.rotation = PI / 2.0 if i % 2 == 0 else -PI / 2.0
			s.position = Vector2((TAVERN.end.x) * TILE + 10 + i * 14, (TAVERN.end.y + 1) * TILE - 5)
			s.modulate = Color(0.85, 0.8, 0.9)
			dynamic.add_child(s)
			var z := VillageArt.paint(dynamic, "z", s.position + Vector2(2, -12), VillageArt.BONE, 10)
			z.modulate.a = 0.0
			var tw := z.create_tween().set_loops()
			tw.tween_interval(0.6 + i * 0.7)
			tw.tween_property(z, "modulate:a", 0.8, 0.3)
			tw.parallel().tween_property(z, "position:y", z.position.y - 8.0, 1.6)
			tw.tween_property(z, "modulate:a", 0.0, 0.4)
			tw.tween_callback(func() -> void: z.position.y += 8.0)


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
		var fresh: bool = d.get("new", false)
		var charged: bool = d.charged_this_week
		var pipe := _pipe(Vector2(x * TILE + 8, BANK_ROW * TILE + 6), fresh, charged)
		# The tag hangs from the pipe: the amount (and the name, while it's new).
		var text := VillageArt.dollars(int(d.amount_cents))
		if fresh:
			text = "%s %s" % [str(d.merchant), text]
		var tag := VillageArt.paint(pipe, text, Vector2(4, 9), VillageArt.BONE, 10)
		tag.z_index = 1
		VillageArt.carry(tag, "tag", Color(1.6, 0.7, 0.65) if fresh else Color.WHITE)
		VillageArt.sway(tag, 0.04, 2.0 + i * 0.3)


## A drain: an iron pipe out of the bank, its mouth over the water, dripping into the river.
## A new one glows red and drips faster.
func _pipe(at: Vector2, fresh: bool, charged: bool) -> Node2D:
	var iron := Color("5a5660") if not fresh else Color("7a3a3a")
	var p := BuildingSite.Painter.new()
	p.position = at
	p.fn = func(c: Node2D) -> void:
		c.draw_rect(Rect2(-3, -11, 6, 14), VillageArt.INK)
		c.draw_rect(Rect2(-2, -10, 4, 12), iron)
		c.draw_rect(Rect2(-2, -10, 1, 12), iron.lightened(0.35))
		c.draw_rect(Rect2(-4, -13, 8, 4), VillageArt.INK)
		c.draw_rect(Rect2(-3, -12, 6, 2), iron.lightened(0.2))
		c.draw_rect(Rect2(-2, -12, 4, 1), Color(0.05, 0.03, 0.06))
		c.draw_rect(Rect2(-3, -2, 6, 1), iron.darkened(0.4))
	dynamic.add_child(p)
	if fresh:
		VillageArt.pool(p, Vector2(0, -8), Color(1.0, 0.25, 0.2, 0.55), 30, 0.4)
	var drip := CPUParticles2D.new()
	drip.amount = 3 if fresh or charged else 1
	drip.lifetime = 0.45 if fresh else 0.9
	drip.position = Vector2(0, -13)
	drip.direction = Vector2.UP
	drip.spread = 0.0
	drip.initial_velocity_min = 4.0
	drip.initial_velocity_max = 6.0
	drip.gravity = Vector2(0, -30)
	drip.color = Color(1.0, 0.45, 0.4, 0.9) if fresh else Color(0.65, 0.8, 1.0, 0.8)
	p.add_child(drip)
	return p


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
			if index == 0:
				index = grass_at(Vector2i(x, y))
			elif index == 4:
				index = _stone_at(Vector2i(x, y))
			set_tile(Vector2i(x, y), index)
			if solid.contains(ch) and not _open.has(Vector2i(x, y)):
				_blocked[Vector2i(x, y)] = true
	_paint_square_edges()
	for id: String in parcels:
		var p: VillageParcel = parcels[id]
		_paint_parcel(p, p.is_open)


## Grass in patches: value noise picks darker hollows, greener swells and plain grass between,
## with tufts here and there (flowers grow in clusters on top, see _ground_life).
func grass_at(cell: Vector2i) -> int:
	var n := _noise.get_noise_2d(cell.x, cell.y)
	var h := absi((cell.x * 73856093) ^ (cell.y * 19349663)) % 7
	if n < -0.18:
		return 21 if h == 0 else 20
	if n > 0.3:
		return 23 if h == 0 else 22
	return 1 if h < 2 else 0


## The square's stone: two or three cuts of it, moss creeping in from the corners.
func _stone_at(cell: Vector2i) -> int:
	var n := _noise.get_noise_2d(cell.x * 2.3 + 40.0, cell.y * 2.3)
	var corner := mini(absi(cell.x - PLAZA.position.x - 1), absi(cell.x - PLAZA.end.x + 2)) + mini(absi(cell.y - PLAZA.position.y - 1), absi(cell.y - PLAZA.end.y + 2))
	var h := absi((cell.x * 92821) ^ (cell.y * 68917)) % 5
	if corner == 0 or (corner == 1 and h < 3):
		return 26
	if n < -0.2:
		return 24
	if n > 0.25:
		return 25
	return 4


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
