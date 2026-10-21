class_name CasinoRoom
extends Room
## The casino, the front door: a new session opens here. A dark room, one lamp over a felt
## table, Vex behind it saying the counts out loud, the belt as pegs on the felt and the box
## on the wall, the reliquary of sealed cases, the scratch booth, the prize wheel, the claw,
## the collection book on its counter, the weekly draw drum, and the choir on the risers
## chanting faster as the belt empties. No panels and no prompts: tap a thing to use it.
##
## Every line Vex says comes from the backend (state.casino.dealer). Money never moves here;
## each machine's overlay calls the API itself and closes with the result.

const Art := preload("res://features/casino/casino_room_art.gd")
const Props := preload("res://features/casino/casino_room_props.gd")

const MAP: Array[String] = [
	"WWWWWWWWWWWWWWWWWWWWWWWWWWWWWW",
	"wwwwwwwwwwwwwwwwwwwwwwwwwwwwww",
	"wwwwwwwwwwwwwwwwwwwwwwwwwwwwww",
	"wwwwwwwwwwwwwwwwwwwwwwwwwwwwww",
	"WffffffffffffffffffffffffffffW",
	"WffffffffffffffffffffffffffffW",
	"WffffffffffffffffffffffffffffW",
	"WffffffffffffffffffffffffffffW",
	"WffffffffffffffffffffffffffffW",
	"WffffffffffffffffffffffffffffW",
	"WffffffffffffffffffffffffffffW",
	"WffffffffffffffffffffffffffffW",
	"WffffffffffffffffffffffffffffW",
	"WffffffffffffffffffffffffffffW",
	"WffffffffffffffffffffffffffffW",
	"WffffffffffffffffffffffffffffW",
	"WWWWWWWWWWWWWWddWWWWWWWWWWWWWW",
]
## Where you stand when you come in (Room.ENTRANCE maps here): in front of the table.
const ARRIVE := Vector2i(15, 13)
const DOOR_TILES: Array[Vector2i] = [Vector2i(14, 16), Vector2i(15, 16)]
const NOT_THIS_WEEK := "Not this week."

# Where things stand, in room pixels (machines by their feet).
const VEX_AT := Vector2(240, 124)
const TABLE_AT := Vector2(240, 160)
const BOX_AT := Vector2(240, 30)
const SHELF_AT := Vector2(424, 112)
const WHEEL_AT := Vector2(48, 138)
const BOOTH_AT := Vector2(48, 214)
const CLAW_AT := Vector2(432, 222)
const DRUM_AT := Vector2(370, 236)
const BOOK_AT := Vector2(128, 226)
const NEON_AT := Vector2(152, 34)
const ODDS_AT := Vector2(320, 22)
const VEX_STAND := Vector2(240, 180)
const CANDLES := [
	[Vector2(88, 112), 7], [Vector2(168, 113), 2], [Vector2(312, 113), 6], [Vector2(204, 254), 0],
	[Vector2(276, 254), 4], [Vector2(94, 240), 1], [Vector2(404, 254), 3], [Vector2(392, 112), 7],
]
# Blocked floor (tiles): Vex's corner, risers, table, cabinet, wheel, booth, claw, drum, counter.
const SOLID: Array[Rect2i] = [
	Rect2i(13, 4, 4, 3), Rect2i(6, 4, 7, 3), Rect2i(17, 4, 7, 3), Rect2i(10, 6, 10, 4),
	Rect2i(24, 4, 5, 3), Rect2i(1, 4, 4, 5), Rect2i(1, 10, 4, 4), Rect2i(25, 9, 4, 5),
	Rect2i(22, 13, 2, 2), Rect2i(7, 13, 2, 1),
]
const FLOOR_TILES: Array[Vector2i] = [
	Vector2i(1, 7), Vector2i(2, 7), Vector2i(3, 7), Vector2i(4, 7), Vector2i(2, 8), Vector2i(3, 8),
	Vector2i(4, 8), Vector2i(1, 9), Vector2i(2, 9), Vector2i(3, 9), Vector2i(4, 9), Vector2i(1, 10),
	Vector2i(2, 10), Vector2i(3, 10), Vector2i(4, 10), Vector2i(1, 11), Vector2i(2, 11), Vector2i(3, 11),
]

## The destination Vex names before a pull: the last one the owner chose this session.
static var last_dest := "sav_1"

var vex := CasinoRoomVex.new()
var table := CasinoRoomTable.new()
var box := CasinoRoomBox.new()
var choir := CasinoRoomChoir.new()
var lamp := Props.Lamp.new()
var shelf := CasinoRoomShelf.new()
var wheel := CasinoRoomWheel.new()
var claw := CasinoRoomClaw.new()
var booth := CasinoRoomBooth.new()
var drum := CasinoRoomDrum.new()
var book := CasinoRoomBook.new()
var machines: Array[CasinoRoomMachine] = []
var bpm := 84.0
var beat := 0

var _floor := TileMapLayer.new()
var _shade := Node2D.new()
var _under := Node2D.new()
var _wall := Node2D.new()
var _air := Node2D.new()
var _hotspots: Array[Dictionary] = []  # {rect: Rect2, it: Dictionary, machine: Node}
var _registered: Dictionary = {}
var _phase := 0.0
var _quiet := 0.0
var _greeted := false
var _skippable := false
var _talking := false
var _at_table := false
var _hover: Variant = null
var _bed: AudioStreamPlayer
var _chant: AudioStreamPlayer
var _tone: AudioStreamPlayer
var _drum := AudioStreamPlayer.new()
var _astar := AStarGrid2D.new()
var _route: Array[Vector2] = []
var _seen := {}  # last belt total, box holes used and specials, to read what a pull did


func _init() -> void:
	map = MAP


func setup(main_node: Node, spawn: Vector2i) -> void:
	super.setup(main_node, ARRIVE if spawn == Room.ENTRANCE else spawn)


func build() -> void:
	# Not Room.build(): this room is 30 tiles wide and its door is in the middle of the
	# bottom wall, so the legend, solids and door are set here.
	legend = Room.LEGEND
	solid = "Wwct"
	follow_camera = false
	exit_spawn = Village.SPAWN
	for tile: Vector2i in DOOR_TILES:
		add_door(tile, "village", exit_spawn)
	# One wide doorway across both tiles, so walking down the middle of the runner leads out.
	_doors.append({"rect": Rect2(226, 259, 28, 13), "level": "village", "spawn": exit_spawn, "tile": DOOR_TILES[0]})
	for r: Rect2i in SOLID:
		block(r)
	ground.visible = false
	for layer: Node2D in [_floor, _shade, _under, _wall]:
		add_child(layer)
		move_child(layer, props.get_index())
	add_child(_air)
	_paint_floor()
	_wall.draw.connect(_draw_walls)
	_place_things()
	_place_light()
	_start_audio()


# --- building ----------------------------------------------------------------------

func _paint_floor() -> void:
	var src := TileSetAtlasSource.new()
	src.texture = Art.tex(Art.DARK)
	src.texture_region_size = Vector2i(TILE, TILE)
	var set_ := TileSet.new()
	set_.tile_size = Vector2i(TILE, TILE)
	var wall_tiles: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1), Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 1), Vector2i(6, 2)]
	for c: Vector2i in FLOOR_TILES + wall_tiles:
		if not src.has_tile(c):
			src.create_tile(c)
	set_.add_source(src, 0)
	_floor.tile_set = set_
	_floor.modulate = Color(0.56, 0.5, 0.7)
	for y in map.size():
		for x in map[0].length():
			var cell := Vector2i(x, y)
			var ch := map[y][x]
			var h := absi((x * 73856093) ^ (y * 19349663)) % 97
			if ch == "f" or ch == "d":
				_floor.set_cell(cell, 0, FLOOR_TILES[h % FLOOR_TILES.size()])
			elif y <= 3:
				_floor.set_cell(cell, 0, Vector2i(4 + h % 3, 1 if y == 0 else 2))
			else:
				_floor.set_cell(cell, 0, Vector2i(4 + h % 3, 1))
	# The oxblood runner from the door to the table.
	for y in range(10, 17):
		for x in [14, 15]:
			var col := 16 if x == 14 else 48
			var row := 272 if y == 10 else 288
			var s := Art.sprite(Art.region(Art.EXT, Rect2(col, row, 16, 16)), Vector2(x, y) * TILE, _under, false)
			s.modulate = Color(0.33, 0.13, 0.18)


func _draw_walls() -> void:
	var w := map[0].length() * TILE
	# Night over the bricks, darker toward the floor line; the side walls and the bottom
	# wall are just dark edges.
	_wall.draw_rect(Rect2(0, 0, w, 64), Color(0.07, 0.04, 0.10, 0.55))
	for i in 8:
		_wall.draw_rect(Rect2(0, 48 + i * 2, w, 2), Color(0.03, 0.02, 0.05, 0.08 * i))
	_wall.draw_rect(Rect2(0, 63, w, 1), Color("4a3a2a"))
	_wall.draw_rect(Rect2(0, 64, 16, 192), Color("0b0710"))
	_wall.draw_rect(Rect2(15, 64, 1, 192), Color("2a2030"))
	_wall.draw_rect(Rect2(w - 16, 64, 16, 192), Color("0b0710"))
	_wall.draw_rect(Rect2(w - 16, 64, 1, 192), Color("2a2030"))
	_wall.draw_rect(Rect2(0, 256, 224, 16), Color("0b0710"))
	_wall.draw_rect(Rect2(256, 256, w - 256, 16), Color("0b0710"))
	_wall.draw_rect(Rect2(16, 256, 208, 1), Color("2a2030"))
	_wall.draw_rect(Rect2(256, 256, w - 272, 1), Color("2a2030"))


func _place_things() -> void:
	vex.position = VEX_AT
	props.add_child(vex)
	table.position = TABLE_AT
	props.add_child(table)
	box.position = BOX_AT
	_wall.add_child(box)
	choir.position = Vector2(0, 112)
	props.add_child(choir)
	var neon := Props.Neon.new()
	neon.position = NEON_AT
	_wall.add_child(neon)
	var odds := Props.Odds.new()
	odds.position = ODDS_AT
	_wall.add_child(odds)
	_add_machine(shelf, SHELF_AT, Art.LAMP, 40, 0.10)
	_add_machine(wheel, WHEEL_AT, Palette.TEAL, 38, 0.13)
	_add_machine(booth, BOOTH_AT, Palette.PINK, 40, 0.12)
	_add_machine(claw, CLAW_AT, Palette.PINK, 42, 0.14)
	_add_machine(drum, DRUM_AT, Palette.TEAL, 40, 0.12)
	_add_machine(book, BOOK_AT, Art.LAMP, 30, 0.12)
	for c: Array in CANDLES:
		var candle := Props.Candle.new(int(c[1]))
		candle.position = c[0]
		candle.watch = leader
		props.add_child(candle)
		Art.glow(_under, c[0] + Vector2(0, -2), Art.CANDLE, 22, 0.10, 0.5)
	var door := Props.Door.new()
	door.position = Vector2(240, 256)
	props.add_child(door)


func _add_machine(m: CasinoRoomMachine, at: Vector2, color: Color, radius: float, alpha: float) -> void:
	m.position = at
	props.add_child(m)
	m.make_pool(_under, Vector2(0, -6), color, radius, alpha)
	machines.append(m)


func _place_light() -> void:
	lamp.position = Vector2(240, 0)
	props.add_child(lamp)
	lamp.z_index = 2
	var v := Sprite2D.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0.02, 0.0, 0.04, 0.32), Color(0.02, 0.0, 0.04, 0.8)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.42)
	gt.fill_to = Vector2(1.05, 0.42)
	gt.width = 64
	gt.height = 64
	v.texture = gt
	v.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	v.centered = false
	v.scale = Vector2(map[0].length() * TILE / 64.0, map.size() * TILE / 64.0)
	# The dark closes in on the floor and walls only, so machines and candles glow out of it.
	_shade.add_child(v)


func _start_audio() -> void:
	_bed = _loop(Art.SND_BED, -19.0)
	_chant = _loop(Art.SND_CHANT, -22.0)
	_tone = _loop(Art.SND_ROOM, -31.0)
	_drum.volume_db = -20.0
	add_child(_drum)


func _loop(path: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load(Art.PACKS + path)
	p.volume_db = -50.0
	p.finished.connect(p.play)
	add_child(p)
	p.play()
	p.create_tween().tween_property(p, "volume_db", db, 1.6)
	return p


# --- state -----------------------------------------------------------------------------

func dress() -> void:
	var cz: Dictionary = Game.state.get("casino", {})
	if cz.is_empty():
		return
	_read_pull(cz)
	table.dress(cz)
	box.dress(cz)
	for m in machines:
		m.dress(cz)
	_sync_spots()
	var belt: Dictionary = cz.get("belt", {})
	var left := 0
	for k: String in belt.get("left", {}):
		left += int(belt.left[k])
	var size := maxi(1, int(belt.get("size", 25)))
	# The chant follows the belt: 84 BPM on a fresh belt, 140 on the last shells.
	bpm = 84.0 + 56.0 * (1.0 - float(left) / float(size))
	var tell := box.tell_color()
	vex.set_tell(tell)
	lamp.tint = tell
	choir.set_mode("stare" if box.is_tell() else "chant")
	if _chant:
		_chant.volume_db = -60.0 if box.is_tell() else -22.0
	if not _greeted:
		_greeted = true
		_greet()


## A case used a hole but the belt and the announced specials look the same: the purple
## fired and a fresh belt was loaded. Play the reload.
func _read_pull(cz: Dictionary) -> void:
	var belt_total := 0
	for k: String in cz.get("belt", {}).get("left", {}):
		belt_total += int(cz.belt.left[k])
	var box_: Dictionary = cz.get("box", {})
	var now := {"belt": belt_total, "used": int(box_.get("used", 0)), "specials": (box_.get("specials", []) as Array).size()}
	if not _seen.is_empty() and now.used == _seen.used + 1 and now.belt == _seen.belt and now.specials == _seen.specials:
		table.reload()
		choir.hush(1.5)
	_seen = now


func casino() -> Dictionary:
	return Game.state.get("casino", {})


## What Vex says right now: the counts (the backend's line).
func line() -> String:
	return str(casino().get("dealer", {}).get("line", ""))


func _dest(cz: Dictionary) -> String:
	var ids: Array = cz.get("destinations", []).map(func(d: Dictionary) -> String: return str(d.id))
	if ids.has(last_dest):
		return last_dest
	return str(ids[0]) if not ids.is_empty() else last_dest


## The line Vex says before a pull: the price, where it lands, and the exact counts.
func before_line(kind: String, key := "") -> String:
	var cz := casino()
	var before: Dictionary = cz.get("dealer", {}).get("before", {})
	var lines: Variant = before.get(kind, {})
	if key != "" and lines is Dictionary:
		lines = (lines as Dictionary).get(key, {})
	var dest := _dest(cz)
	if lines is Dictionary and (lines as Dictionary).has(dest):
		return str(lines[dest])
	return line()


func _greet() -> void:
	await get_tree().create_timer(0.7).timeout
	if is_inside_tree() and not Game.busy:
		_say(line())


func _say(text: String, hold := SpeechBubble.HOLD_SECONDS) -> void:
	_quiet = 0.0
	vex.say(text, hold)


# --- taps and spots -------------------------------------------------------------------

func _sync_spots() -> void:
	if not _registered.has("vex"):
		_register("vex", vex.hit_rect(), VEX_STAND, vex, _talk_to_vex)
	for m in machines:
		for s: Dictionary in m.spots:
			var id: String = s.id
			if _registered.has(id):
				continue
			var hit: Rect2 = s.hit
			_register(id, Rect2(m.position + hit.position, hit.size), m.position + (s.stand as Vector2), m, _action(id, m))


func _register(id: String, rect: Rect2, stand: Vector2, owner_node: Node, action: Callable) -> void:
	add_interactable(stand, func() -> String: return "", action)
	_hotspots.append({"id": id, "rect": rect, "it": _interactables[-1], "machine": owner_node})
	_registered[id] = true


func _action(id: String, m: CasinoRoomMachine) -> Callable:
	match id:
		"scratch":
			return func() -> void: _pull_scratch(m)
		"wheel":
			return func() -> void: _pull(int(casino().get("wheel", {}).get("price_cents", 500)), before_line("wheel"), func() -> Overlay: return WheelOverlay.new(), m)
		"claw":
			return func() -> void: _pull(int(casino().get("claw", {}).get("price_cents", 500)), before_line("claw"), func() -> Overlay: return ClawOverlay.new(), m)
		"book":
			return func() -> void: _open_free(func() -> Overlay: return BookOverlay.new(), m)
		"draw":
			return func() -> void: _open_free(func() -> Overlay: return DrawOverlay.new(), m)
	return func() -> void: _pull_case(id, m)


## The world rect a spot answers to (the tour taps these).
func spot_rect(id: String) -> Rect2:
	for h: Dictionary in _hotspots:
		if h.id == id:
			return h.rect
	return Rect2()


func _on_tap(point: Vector2) -> void:
	for h: Dictionary in _hotspots:
		if (h.rect as Rect2).has_point(point):
			_pending = h.it
			if leader.position.distance_to(h.it.pos) < REACH:
				_use_pending()
			else:
				_walk(h.it.pos)
			return
	_pending = {}
	_walk(point)


# --- walking around the furniture -------------------------------------------------------

func _ready() -> void:
	super._ready()
	_astar.region = Rect2i(0, 0, map[0].length(), map.size())
	_astar.cell_size = Vector2(TILE, TILE)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for cell: Vector2i in _blocked:
		if _astar.is_in_boundsv(cell):
			_astar.set_point_solid(cell)
	leader.arrived.connect(_next_waypoint)


## Walk to a point the long way round if the straight line is blocked: an A* route over the
## tiles, pulled tight so the leader cuts corners where nothing is in the way.
func _walk(point: Vector2) -> void:
	_route.clear()
	var from := Vector2i((leader.position / TILE).floor())
	var to := Vector2i((point / TILE).floor())
	if _clear(leader.position, point) or not _astar.is_in_boundsv(from) or not _astar.is_in_boundsv(to) \
			or _astar.is_point_solid(from) or _astar.is_point_solid(to):
		leader.walk_to(point)
		return
	var cells := _astar.get_id_path(from, to)
	var points: Array[Vector2] = []
	for i in range(1, cells.size() - 1):
		points.append(Vector2(cells[i]) * TILE + Vector2(TILE / 2.0, TILE - 3.0))
	points.append(point)
	var at := leader.position
	var i := 0
	while i < points.size():
		var far := i
		for j in range(points.size() - 1, i, -1):
			if _clear(at, points[j]):
				far = j
				break
		_route.append(points[far])
		at = points[far]
		i = far + 1
	leader.walk_to(_route.pop_front())


func _next_waypoint() -> void:
	if not _route.is_empty() and not Game.busy:
		leader.walk_to(_route.pop_front())


func _clear(a: Vector2, b: Vector2) -> bool:
	var steps := maxi(1, int(a.distance_to(b) / 3.0))
	for s in steps + 1:
		var p := a.lerp(b, float(s) / steps)
		if not is_walkable(Rect2(p + Leader.FOOT.position, Leader.FOOT.size)):
			return false
	return true


func _unhandled_input(event: InputEvent) -> void:
	# A tap while Vex states the odds before a pull hurries him along.
	if _skippable and vex.speaking and _is_tap(event):
		get_viewport().set_input_as_handled()
		vex.hush()
		return
	super._unhandled_input(event)


func _process(delta: float) -> void:
	super._process(delta)
	if main:
		main.show_prompt("")  # no text prompts in here; the machine in reach glows instead
	_quiet += delta
	if not _route.is_empty() and Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") != Vector2.ZERO:
		_route.clear()
	_update_focus()
	_tempo(delta)
	# Walk up to the table and he says the counts again, if he's been quiet a while.
	var at_table := leader.position.distance_to(VEX_STAND) < 40.0
	if at_table and not _at_table and not Game.busy and not vex.speaking and _quiet > 6.0:
		_say(line())
	_at_table = at_table


func _update_focus() -> void:
	var near := nearest_interactable()
	var mouse := get_global_mouse_position()
	var hover: Variant = null
	for h: Dictionary in _hotspots:
		if not Game.busy and (h.rect as Rect2).has_point(mouse):
			hover = h
	for h: Dictionary in _hotspots:
		var m: Node = h.machine
		if m is CasinoRoomMachine:
			(m as CasinoRoomMachine).want_focus(h.it == near or (hover != null and hover.machine == m))
	if (hover != null) != (_hover != null):
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hover != null else Input.CURSOR_ARROW)
	_hover = hover


func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _tempo(delta: float) -> void:
	_phase += delta * bpm / 60.0
	if _phase < 1.0:
		return
	_phase -= 1.0
	beat += 1
	choir.beat(beat, 60.0 / bpm)
	if choir.mode != "chant":
		return
	var accent := beat % 4 == 0
	_drum.stream = load(Art.PACKS + Art.SND_DRUM % (beat % 5))
	_drum.pitch_scale = 0.62 if accent else 0.8
	_drum.volume_db = -15.0 if accent else -22.0
	_drum.play()


# --- the machines ---------------------------------------------------------------------

func _pull_case(case_id: String, m: CasinoRoomMachine) -> void:
	var price := 0
	for c: Dictionary in casino().get("cases", []):
		if c.id == case_id:
			price = int(c.price_cents)
	await _pull(price, before_line("case", case_id), func() -> Overlay: return CaseOverlay.new(case_id), m)


func _pull_scratch(m: CasinoRoomMachine) -> void:
	var price := booth.cheapest()
	await _pull(price, before_line("scratch", str(price)), func() -> Overlay: return ScratchOverlay.new(), m)


## Every paid machine: check the week's extra, have Vex state the price, the destination and
## the counts, then open the machine's overlay (it calls the API and plays the moment).
func _pull(price: int, said: String, make: Callable, m: CasinoRoomMachine) -> void:
	if Game.busy or casino().is_empty():
		return
	m.poke()
	if price <= 0 or price > int(casino().get("can_spend_cents", 0)):
		_refuse()
		return
	Game.busy = true
	_skippable = true
	await vex.say(said, 0.6)
	_quiet = 0.0
	_skippable = false
	if not is_inside_tree():
		Game.busy = false
		return
	var result: Variant = await main.open_overlay(make.call())
	await _after(result)


func _open_free(make: Callable, m: CasinoRoomMachine) -> void:
	if Game.busy:
		return
	m.poke()
	var result: Variant = await main.open_overlay(make.call())
	if result != null and is_inside_tree():
		await Game.refresh()


func _after(result: Variant) -> void:
	if not (result is Dictionary):
		return
	var money: Dictionary = (result as Dictionary).get("money", {})
	if money.has("to_account"):
		last_dest = str(money.to_account)
	await Game.refresh()
	if is_inside_tree():
		_say(line())


## The week's extra or caps can't cover it: the slot lamp clicks off and Vex says so.
## Nothing else changes.
func _refuse() -> void:
	var cz := casino()
	var can := int(cz.get("can_spend_cents", 0))
	table.click_off(can >= table._cheapest(cz))
	choir.hush(2.5)
	Art.play(Art.SND_THUNK, 0.8, -6.0)
	_say(NOT_THIS_WEEK)


func _talk_to_vex() -> void:
	if _talking or Game.busy:
		return
	_talking = true
	var lines: Array = Game.state.get("dialogue", {}).get("croupier", {}).get("lines", [])
	if lines.is_empty():
		lines = [line()]
	for l: Variant in lines:
		if not is_inside_tree():
			break
		_quiet = 0.0
		await vex.say(str(l), 1.2)
	_talking = false
