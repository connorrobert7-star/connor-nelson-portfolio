class_name Village
extends Level
## The village hub, at night. You pass through it: loud doors around a stone square lead
## to the casino, the arcade, the shrine and the gate; the house builds itself out of the
## House Fund; the town wall is the Emergency Fund; ruined buildings wait behind offering
## tablets. Numbers are painted on things. The only table of numbers is the ledger stone.
## Every state comes from the backend (Game.state); this script only draws it.

const MAP: Array[String] = [
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"T......................................T",
	"T......................................T",
	"T......................................T",
	"T......................................T",
	"T......................................T",
	"T......................................T",
	"T......................................T",
	"T======================================T",
	"T.........###############..............T",
	"T.........###############..............T",
	"T.........###############..............T",
	"T.........###############..............T",
	"T.........###############..............T",
	"T.........###############..............T",
	"T.........###############..............T",
	"T.........###############..............T",
	"T.........###############..............T",
	"T......................................T",
	"T======================================T",
	"wwwwwwwwwwwwwwwwwww==wwwwwwwwwwwwwwwwwww",
	"wwwwwwwwwwwwwwwwwww==wwwwwwwwwwwwwwwwwww",
	"wwwwwwwwwwwwwwwwwww==wwwwwwwwwwwwwwwwwww",
	"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
	"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
	"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
]
## Map char -> ground index (see GROUND).
const LEGEND := {".": 0, ",": 1, "*": 2, "=": 3, "#": 4, "~": 5, "T": 7, "w": 8, "x": 9}
## Ground tiles, all from packs: [sheet, Vector2i(col, row)] on a 16 px grid.
## A third value darkens that tile further at night.
const GROUND := [
	[VillageArt.TOWN, Vector2i(0, 0)],  # 0 grass
	[VillageArt.TOWN, Vector2i(1, 0)],  # 1 grass tufts
	[VillageArt.TOWN, Vector2i(2, 0)],  # 2 flowers
	[VillageArt.FLOOR, Vector2i(17, 16), Color(0.85, 0.8, 0.9)],  # 3 road
	[VillageArt.TOWN, Vector2i(1, 9), Color(0.5, 0.45, 0.62)],  # 4 square stone
	[VillageArt.WATER, Vector2i(11, 1), Color(0.75, 0.7, 1.0)],  # 5 river
	[VillageArt.TOWN, Vector2i(4, 3), Color(0.7, 0.6, 0.6)],  # 6 low river (mud)
	[VillageArt.TOWN, Vector2i(0, 0), Color(0.6, 0.6, 0.7)],  # 7 under trees
	[VillageArt.FLOOR, Vector2i(17, 16), Color(0.6, 0.55, 0.65)],  # 8 under the wall
	[VillageArt.TOWN, Vector2i(5, 3), Color(0.35, 0.3, 0.4)],  # 9 outside the wall
]
const LOW_WATER := 6
const RIVER_EDGE_ROW := 4
const BANK_ROW := 5
const SPAWN := Vector2i(20, 17)
const NIGHT_GROUND := Color(0.36, 0.3, 0.46)

## Plots features build on: plot_id -> {rect, door}. `door` is the tile in the plot's
## bottom row that leads inside once a feature registers a level for it.
const PLOTS := {
	"arcade": {"rect": Rect2i(1, 8, 6, 4), "door": Vector2i(4, 11)},
	"casino": {"rect": Rect2i(13, 7, 10, 5), "door": Vector2i(17, 11), "wide": true},
	"shrine": {"rect": Rect2i(27, 8, 6, 4), "door": Vector2i(29, 11)},
	"gate": {"rect": Rect2i(18, 23, 4, 4), "door": Vector2i(19, 26), "wide": true},
}
## The village's own places.
const TAVERN := Rect2i(8, 8, 4, 4)
const TAVERN_DOOR := Vector2i(9, 11)
const SHOP := Rect2i(25, 19, 3, 3)
const SHOP_DOOR := Vector2i(26, 21)
const HOUSE_PLOT := Rect2i(1, 14, 6, 5)
const FIELDS := Rect2i(1, 20, 7, 2)
const LEDGER := Rect2i(17, 16, 2, 1)
const PLAZA := Rect2i(10, 13, 15, 9)
const WALL_BASE_ROW := 27
const WALL_SPANS := [[0, 16], [23, 39]]
const WALL_POST_X := 15
const RUINS := {
	"granary": {"feet": Vector2i(30, 15), "ruined": [VillageArt.RUINS, 11, 3, 3, 3], "restored": [VillageArt.HOUSES, 23, 0, 3, 3], "tablet": Vector2(-50, 0)},
	"ossuary": {"feet": Vector2i(30, 19), "ruined": [VillageArt.RUINS, 11, 0, 3, 3], "restored": [VillageArt.HOUSES, 29, 0, 4, 3], "tablet": Vector2(56, 0)},
	"bell_tower": {"feet": Vector2i(36, 11), "ruined": [VillageArt.RUINS, 12, 6, 4, 5], "restored": [VillageArt.HOUSES, 25, 14, 4, 5], "tablet": Vector2(0, 46)},
}
const DRAIN_COLS := [2, 8, 24, 31, 37]
const CROP_FRAME := {"bumper": 0, "healthy": 1, "wilting": 2, "withered": 3}

var house: VillageHouse
var wall: VillageWall
var ruins: Dictionary = {}  # ruin_id -> VillageRuin
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


func build() -> void:
	map = MAP
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
	add_interactable(feet_at(Vector2i(WALL_POST_X, 23)) + Vector2(0, -4), func() -> String: return "", wall.poke)
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
	add_npc("farmer", Vector2i(11, 12), Vector2i(11, 13))
	add_npc("shrine_keeper", Vector2i(33, 12), Vector2i(33, 13))
	_cultists()
	_ambience()
	Game.event_fired.connect(_on_event)


func _ready() -> void:
	super._ready()
	ground.modulate = NIGHT_GROUND
	# Coming back through a door in the wall (the gate) would land outside it: step inside.
	var tile := Vector2i((leader.position / TILE).floor())
	while tile.y > 12 and (_blocked.has(tile) or _open.has(tile)):
		tile.y -= 1
	leader.position = feet_at(tile)
	# Pop out of the door with a little hop.
	leader.scale = Vector2(1.25, 0.75)
	var tw := leader.create_tween()
	tw.tween_property(leader, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func dress() -> void:
	for plot_id: String in PLOTS:
		var f := Features.for_plot(plot_id)
		if f:
			f.dress_village(self, PLOTS[plot_id].rect)
	_dress_crops()
	_dress_tavern()
	_dress_river()
	_dress_lamps()
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


# --- input -------------------------------------------------------------------------------

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
	# Village things are tapped, not read: no prompt line for them.
	var it := nearest_interactable()
	if not it.is_empty() and (it.label as Callable).call() == "":
		main.show_prompt("")


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
	for x in range(0, 40, 2):
		var t := VillageArt.sprite(props, VillageArt.tiles(VillageArt.NATURE, dead[(x / 2) % 2].x, 0, 2, 2), Vector2(x * TILE + 16, 2 * TILE - 2), x % 4 == 0)
		t.modulate = Color(0.8, 0.75, 0.9)
		_sway(t, 0.035)
	var leaves := CPUParticles2D.new()
	leaves.texture = VillageArt.tex(VillageArt.LEAF, Rect2(0, 0, 8, 7))
	leaves.amount = 10
	leaves.lifetime = 5.0
	leaves.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	leaves.emission_rect_extents = Vector2(320, 4)
	leaves.position = Vector2(20 * TILE, TILE)
	leaves.gravity = Vector2(6, 14)
	leaves.angular_velocity_min = -90
	leaves.angular_velocity_max = 90
	leaves.color = Color(0.75, 0.55, 0.8)
	add_child(leaves)
	for y in range(5, 24, 2):
		for x in [0, 39]:
			_sway(VillageArt.sprite(props, VillageArt.tiles(VillageArt.TOWN, 4 if y % 4 == 1 else 3, 1, 1, 2), Vector2(x * TILE + 8, (y + 1) * TILE)), 0.05)
	for x in [3, 9, 33]:
		VillageArt.sprite(props, VillageArt.tiles(VillageArt.FLOOR_DETAIL, 13 + x % 2, 0), Vector2(x * TILE + 8, 22 * TILE + 12))


## Trees lean in the wind, each on its own beat.
func _sway(s: Sprite2D, amount: float) -> void:
	var tw := s.create_tween().set_loops()
	tw.tween_interval(randf() * 1.5)
	tw.tween_property(s, "rotation", amount, 1.6 + randf()).set_trans(Tween.TRANS_SINE)
	tw.tween_property(s, "rotation", -amount * 0.5, 1.6 + randf()).set_trans(Tween.TRANS_SINE)


## Beyond the wall: dead ground, fog, and the debts waiting outside the gate.
func _outside() -> void:
	var dark := VillageArt.glow(_under, Vector2(20 * TILE, 29 * TILE), Color(0, 0, 0, 0.9), 900)
	dark.material = null
	dark.scale.y = 0.12
	for x in range(1, 40, 3):
		var t := VillageArt.sprite(props, VillageArt.tiles(VillageArt.NATURE, 0 if x % 2 else 2, 5, 2, 3), Vector2(x * TILE + 8, 30 * TILE - 2))
		t.modulate = Color(0.35, 0.3, 0.45)
	var debts: Array = Game.state.get("debts", [])
	for i in mini(3, maxi(1, debts.size())):
		var x: int = [11, 28, 34][i]
		var slime := VillageArt.anim(props, VillageArt.frames(VillageArt.PACKS + "ninja-adventure/Actor/Boss/GiantSlime/Idle.png", Vector2i(62, 52), 5, 5), Vector2(x * TILE, 26 * TILE + 4))
		slime.self_modulate = Color(0.3, 0.18, 0.4, 0.95)
		slime.scale = Vector2.ONE * (1.4 - i * 0.25)
		for ex in [-8, 8]:
			VillageArt.glow(slime, Vector2(ex, 2), Color(VillageArt.SICK, 1.0), 9, 0.6)
		VillageArt.bob(slime, 2.0, 3.0 + i)
	var fog := Sprite2D.new()
	fog.texture = VillageArt.sheet(VillageArt.FOG)
	fog.position = Vector2(20 * TILE, 29 * TILE + 8)
	fog.scale = Vector2(2.2, 0.6)
	fog.modulate = Color(0.55, 0.45, 0.8, 0.12)
	fog.material = VillageArt.additive()
	fog.z_index = 1
	add_child(fog)
	var drift := fog.create_tween().set_loops()
	drift.tween_property(fog, "position:x", 20 * TILE + 40.0, 9.0).set_trans(Tween.TRANS_SINE)
	drift.tween_property(fog, "position:x", 20 * TILE - 40.0, 9.0).set_trans(Tween.TRANS_SINE)


func _river_life() -> void:
	VillageArt.embers(_under, Vector2(20 * TILE, 3.5 * TILE), Color(0.6, 1.0, 0.8, 0.6), 600, 10, 6)


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
	var hall := VillageArt.sprite(props, VillageArt.tiles(VillageArt.HOUSES, 25, 7, 4, 7), feet + Vector2(0, 1))
	hall.z_index = 0
	_door_light(feet + Vector2(0, 6), Color(1.0, 0.35, 0.75, 0.75), 150)
	_door_light(feet + Vector2(0, -40), Color(0.6, 0.3, 1.0, 0.5), 200)
	VillageArt.neon(props, "Sign 15/Sign 15 Glow - PINK.png", Vector2i(53, 53), 18, feet + Vector2(-56, -66), 10, 6)
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
	_door_light(feet + Vector2(0, 4), Color(0.25, 0.6, 1.0, 0.7), 120)
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
	_lamp("gate", Vector2(feet.x - 56, 24 * TILE - 1), VillageArt.SICK)
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


## The square: lamps on the corners, the ledger stone in the middle.
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
	for corner in [Vector2i(10, 13), Vector2i(23, 13), Vector2i(10, 21), Vector2i(23, 21)]:
		var at := feet_at(corner)
		VillageArt.sprite(props, VillageArt.tiles(VillageArt.TOWN, 11, 4), at)
		var head := VillageArt.sprite(props, VillageArt.tiles(VillageArt.HOUSES, 30, 16), at + Vector2(0, -12))
		head.z_index = 1
		VillageArt.glow(_under, at, Color(1.0, 0.7, 0.4, 0.5), 80, 0.3)
		block(Rect2i(corner, Vector2i.ONE))
	var bats := CPUParticles2D.new()
	bats.amount = 24
	bats.lifetime = 6.0
	bats.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	bats.emission_rect_extents = Vector2(300, 160)
	bats.position = Vector2(20 * TILE, 15 * TILE)
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


func _cultists() -> void:
	var area := Rect2(Vector2(PLAZA.position * TILE) + Vector2(12, 12), Vector2(PLAZA.size * TILE) - Vector2(24, 24))
	for i in 9:
		var c := VillageCultist.new()
		c.look = i
		c.area = area
		c.is_walkable = is_walkable
		c.position = area.position + Vector2(randf() * area.size.x, randf() * area.size.y)
		props.add_child(c)
		cultists.append(c)


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
		var flames := int(s.get("minigames", {}).get("flames_left", 3))
		_door_lamps.arcade.text = "%d flames" % flames if flames != 1 else "1 flame"
		_door_lamps.arcade.label_settings.font_color = VillageArt.BRASS
	if _door_lamps.has("shrine"):
		var days: Variant = s.get("village", {}).get("stats", {}).get("days_since_landing")
		_door_lamps.shrine.text = "" if days == null else ("today" if int(days) == 0 else ("1 day" if int(days) == 1 else "%d days" % int(days)))
	if _door_lamps.has("gate"):
		var debts: Array = s.get("debts", [])
		var bal: Dictionary = s.get("balances", {})
		var hp := -1
		for d: Dictionary in debts:
			var b := int(bal.get(d.id, d.balance_cents))
			if b > 0 and (hp < 0 or b < hp):
				hp = b
		_door_lamps.gate.text = VillageArt.dollars(hp) if hp > 0 else ""
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


func _dress_river() -> void:
	var river: Dictionary = Game.state.get("drains", {})
	if river.is_empty():
		return
	var low: bool = river.river == "low"
	for x in MAP[0].length():
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
		var name := ("new " if d.new else "") + str(d.merchant)
		var at := Vector2(x * TILE + 8, BANK_ROW * TILE + 18)
		VillageArt.paint(dynamic, name, at, Color("ff9a8a") if d.new else Palette.MUTED, 16, VillageArt.FONT_SMALL)
		VillageArt.paint(dynamic, Money.fmt(int(d.amount_cents)), at + Vector2(0, 9), VillageArt.BONE, 10)
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
		if g.size() > 2:
			atlas.get_tile_data(g[1], 0).modulate = g[2]
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


var _ground_sources: Dictionary = {}


func set_tile(cell: Vector2i, index: int) -> void:
	var g: Array = GROUND[index]
	ground.set_cell(cell, _ground_sources.get(g[0], 0), g[1])
