class_name TavernRoom
extends Room
## Inside the tavern: stone walls, string lights, a long bar with kegs behind it and a hearth
## whose light breathes on the floor. Bess runs the bar; last week's meals out sit on the
## stools and at the tables (one patron per visit), breathing, raising cups and clinking.
## The slate behind the bar says what was spent against the budget. No panels.

const BESS := Vector2i(2, -2)
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
const BAR_Y := 0  # the bar's front edge
const HEARTH_X := 232.0
## Two tables out on the middle of the floor, two by the walls.
const TABLES: Array[Vector2] = [Vector2(48, 76), Vector2(200, 84), Vector2(-52, 116), Vector2(300, 134)]
## Seats in the order they fill, spread between the bar stools (patrons from behind, facing
## Bess) and the tables (facing each other), so even a quiet week fills the room. [feet, facing]
const SEATS: Array = [
	[Vector2(-48, 14), 1], [Vector2(32, 72), 3], [Vector2(216, 80), 2], [Vector2(96, 14), 1],
	[Vector2(64, 72), 2], [Vector2(-72, 14), 1], [Vector2(184, 80), 3], [Vector2(-68, 112), 3],
	[Vector2(120, 14), 1], [Vector2(316, 130), 2], [Vector2(-24, 14), 1], [Vector2(-36, 112), 2],
	[Vector2(72, 14), 1], [Vector2(284, 130), 3],
]
const FOLK: Array[String] = ["Villager", "Woman", "OldMan", "Villager2", "Boy", "Monk", "Hunter", "Princess", "Villager3", "OldWoman"]
const STONE := Color("3a3040")
## The back wall's stone, warm and dark so the hearth and the string lights pool on it.
const WALL_TINT := Color(0.32, 0.26, 0.28)
const WOOD := Color("4a2a20")
const BULBS: Array[Color] = [Color("ffb26b"), Color("ff7fa0"), Color("7fe8c8"), Color("ffe08a")]
const SND_CLINK := "kenney-impact-sounds/Audio/impactGlass_light_00%d.ogg"
const SND_FIRE := "ninja-adventure/Audio/Sounds/Elemental/Fire.ogg"

var bess: Sprite2D
var _bess_y := 0.0
var _patrons: Array[Dictionary] = []  # {node, cup, base, seed, lift}
var _bulbs: Array[Sprite2D] = []
var _flames: Array[Sprite2D] = []
var _hearth_pool: Sprite2D
var _clink_t := 3.0
var _cat: Sprite2D


func _init() -> void:
	map = MAP
	origin = Vector2i(-7, -6)


func build() -> void:
	super.build()
	block(Rect2i(-6, -2, 15, 2))  # behind the bar and the bar itself
	block(Rect2i(12, -2, 5, 1))  # the hearth
	for t: Vector2 in TABLES:
		block(Rect2i(floori(t.x / 16.0) - 1, floori((t.y - 4) / 16.0), 2, 1))
	room_under.draw.connect(_draw_floor)
	room_walls.draw.connect(_draw_walls)
	_build_bar()
	_build_hearth()
	_build_tables()
	_build_light()


func _available(who: String) -> bool:
	return ResourceLoader.exists(Kit.PACKS + Kit.NINJA % who)


func _build_bar() -> void:
	var back := BackBar.new()
	back.position = Vector2(16, -30)
	props.add_child(back)
	bess = add_npc("tavern_keeper", BESS, Vector2i(2, 2))
	_bess_y = bess.offset.y
	room_hotspot(Rect2(24, -40, 32, 40))
	var bar := Bar.new()
	bar.position = Vector2(16, BAR_Y)
	props.add_child(bar)
	Kit.shadow(room_pools, Vector2(16, BAR_Y + 2), 260, 0.3)
	# The slate: what last week's meals out came to, against the budget.
	var slate := Slate.new()
	slate.position = Vector2(48, -74)
	room_walls.add_child(slate)
	slate.name = "slate"


func _build_hearth() -> void:
	var h := Hearth.new()
	h.position = Vector2(HEARTH_X, -28)
	props.add_child(h)
	for k in 3:
		var f := Sprite2D.new()
		f.texture = Kit.region(Kit.EXT, Rect2(128 + 16 * ((k * 3) % 8), 336, 16, 16))
		f.position = Vector2(HEARTH_X - 10 + k * 10, -38)
		f.z_index = 1
		props.add_child(f)
		_flames.append(f)
	var core := Kit.glow(props, Vector2(HEARTH_X, -40), Color("ff9a40"), 26, 0.55)
	core.z_index = 2
	room_flicker(core, 0.25, 7.0)
	_hearth_pool = Kit.glow(room_pools, Vector2(HEARTH_X, 0), Color("ff8a3a"), 110, 0.42, 0.55)
	room_flicker(_hearth_pool, 0.22, 6.0)
	var embers := CPUParticles2D.new()
	embers.position = Vector2(HEARTH_X, -44)
	embers.amount = 10
	embers.lifetime = 1.6
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(12, 2)
	embers.direction = Vector2(0, -1)
	embers.spread = 25.0
	embers.gravity = Vector2(0, -8)
	embers.initial_velocity_min = 6.0
	embers.initial_velocity_max = 14.0
	embers.color = Color("ffb060")
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 0.4, 0.1, 0)])
	embers.color_ramp = ramp
	embers.material = Kit.additive()
	embers.z_index = 2
	props.add_child(embers)


func _build_tables() -> void:
	# The house cat asleep by the fire.
	var cat := Sprite2D.new()
	cat.texture = Kit.region("ninja-adventure/Actor/Animal/Cat/SpriteSheet.png", Rect2(0, 0, 16, 16))
	cat.position = Vector2(HEARTH_X + 36, 14)
	cat.offset = Vector2(0, -7)
	props.add_child(cat)
	Kit.shadow(room_pools, cat.position, 14, 0.4)
	_cat = cat
	for t: Vector2 in TABLES:
		for side: int in [-1, 1]:
			var ch := Kit.put(Kit.indoor(2 if side < 0 else 3, 2), t + Vector2(side * 16, 0), props, true)
			ch.offset = Vector2(0, -8)
		var tb := Table.new()
		tb.position = t
		props.add_child(tb)
		Kit.shadow(room_pools, t, 30, 0.4)
		var c := Kit.glow(room_pools, t + Vector2(0, -2), Kit.WARM, 34, 0.3, 0.6)
		room_flicker(c, 0.2, 8.0)
		var flame := Kit.glow(props, t + Vector2(0, -22), Color("ffd090"), 7, 0.7)
		flame.z_index = 1
		room_flicker(flame, 0.3, 9.0)


func _build_light() -> void:
	room_vignette(Vector2(140, 40), 0.95)
	room_lantern(Vector2(-52, 112), 48, Kit.WARM, 60)
	room_lantern(Vector2(124, 100), 52, Kit.WARM, 64)
	room_lantern(Vector2(300, 128), 46, Kit.WARM, 54)
	# The hearth throws its light up the back wall; the string lights dab color under them.
	var wall_glow := Kit.glow(room_walls, Vector2(HEARTH_X, -58), Color("ff8a3a"), 74, 0.26, 0.8)
	room_flicker(wall_glow, 0.2, 6.0)
	room_flicker(Kit.glow(room_walls, Vector2(48, -60), Kit.WARM, 46, 0.12, 0.8), 0.1, 4.0)
	room_motes(Rect2(-90, -30, 420, 170), Kit.WARM, 14)
	# String lights sagging across the room under the beams.
	var r := room_rect()
	var x := r.position.x + 20
	var i := 0
	while x < r.end.x - 16:
		var u := (x - r.position.x) / r.size.x
		var y := -86.0 + sin(u * PI * 3.0) * -6.0 + 10.0 * sin(u * PI)
		var b := Kit.glow(room_air, Vector2(x, y), BULBS[i % BULBS.size()], 6, 0.9)
		_bulbs.append(b)
		if i % 2 == 0:
			Kit.glow(room_walls, Vector2(x, y + 10), BULBS[i % BULBS.size()], 16, 0.1, 0.7)
		x += 14.0
		i += 1
	var wire := Line2D.new()
	wire.width = 1
	wire.default_color = Color("120c10")
	for b in _bulbs:
		wire.add_point(b.position + Vector2(0, -2))
	room_air.add_child(wire)
	room_air.move_child(wire, 0)


# --- state ------------------------------------------------------------------------------

func dress() -> void:
	_patrons.clear()
	var tavern: Dictionary = Game.state.get("tavern", {})
	var slate := room_walls.get_node_or_null("slate") as Slate
	if slate:
		slate.text = "%s / %s" % [_dollars(int(tavern.get("spent_cents", 0))), _dollars(int(tavern.get("budget_cents", 0)))]
		slate.queue_redraw()
		slate.refresh()
	var packed: bool = tavern.get("state", "") == "packed"
	var folk := FOLK.filter(_available)
	for i in mini(int(tavern.get("visits", 0)), SEATS.size()):
		var seat: Array = SEATS[i]
		var feet: Vector2 = seat[0]
		var facing: int = seat[1]
		var n := Node2D.new()
		n.position = feet
		dynamic.add_child(n)
		if facing == 1:
			# A bar stool under them.
			var stool := Node2D.new()
			stool.draw.connect(func() -> void:
				stool.draw_rect(Rect2(-4, -5, 8, 2), WOOD.lightened(0.2))
				stool.draw_rect(Rect2(-3, -3, 1, 4), WOOD)
				stool.draw_rect(Rect2(2, -3, 1, 4), WOOD)
			)
			n.add_child(stool)
		Kit.shadow(n, Vector2(0, 0), 16, 0.45)
		var s := Sprite2D.new()
		s.texture = Kit.ninja(str(folk[i % folk.size()]) if not folk.is_empty() else "Villager", facing)
		s.offset = Vector2(0, -8 - (3 if facing == 1 else 2))
		n.add_child(s)
		var cup := Node2D.new()
		var side := 6.0 if facing != 2 else -6.0
		cup.position = Vector2(side, -9)
		cup.draw.connect(func() -> void:
			cup.draw_rect(Rect2(-2, -3, 4, 5), Color("c8a060"))
			cup.draw_rect(Rect2(-2, -3, 4, 1), Color("fff0c0"))
			cup.draw_rect(Rect2(2, -2, 1, 2), Color("8a6a40"))
		)
		cup.visible = facing != 1 or i % 2 == 0
		n.add_child(cup)
		_patrons.append({"node": s, "cup": cup, "base": s.offset.y, "seed": i * 1.9, "lift": 0.0, "cup_y": cup.position.y})
	_clink_t = 1.2 if packed else 2.5


static func _dollars(cents: int) -> String:
	return "$%d" % (cents / 100) if cents % 100 == 0 else Money.fmt(cents)


func _process(delta: float) -> void:
	super._process(delta)
	if bess:
		bess.offset.y = _bess_y - (1.0 if fmod(_room_t + 0.6, 2.4) < 1.2 else 0.0)
	if _cat:
		var f := 1 if fmod(_room_t, 3.2) < 1.6 else 0
		(_cat.texture as AtlasTexture).region.position.x = f * 16
	var fi := int(_room_t * 10.0)
	for k in _flames.size():
		var f := _flames[k]
		f.texture.region = Rect2(128 + 16 * ((fi + k * 3) % 8), 336, 16, 16)
	for k in _bulbs.size():
		var tw := 0.75 + 0.25 * sin(_room_t * 2.0 - k * 0.6)
		_bulbs[k].modulate.a = tw
	# Patrons breathe; now and then two neighbours raise their cups and clink.
	for p: Dictionary in _patrons:
		var s: Sprite2D = p.node
		var breath := 1.0 if fmod(_room_t + float(p.seed), 2.2) < 1.1 else 0.0
		p.lift = maxf(0.0, float(p.lift) - delta)
		var up := 3.0 if float(p.lift) > 0.0 else 0.0
		s.offset.y = float(p.base) - breath - (1.0 if up > 0 else 0.0)
		(p.cup as Node2D).position.y = float(p.cup_y) - breath - up
	_clink_t -= delta
	if _clink_t <= 0.0 and _patrons.size() > 0:
		var packed: bool = Game.state.get("tavern", {}).get("state", "") == "packed"
		_clink_t = randf_range(1.0, 2.2) if packed else randf_range(2.4, 4.5)
		var a := randi() % _patrons.size()
		var b := (a + 1) % _patrons.size()
		for k: int in [a, b]:
			_patrons[k].lift = 0.6
			(_patrons[k].cup as Node2D).visible = true
		if a != b:
			var at: Vector2 = ((_patrons[a].node as Node2D).global_position + (_patrons[b].node as Node2D).global_position) / 2.0
			_spark(to_local(at) + Vector2(0, -16))
		Kit.play(SND_CLINK % (randi() % 5), randf_range(1.1, 1.4), -20.0)


func _spark(at: Vector2) -> void:
	var g := Kit.glow(room_air, at, Color("fff0b0"), 6, 0.9)
	var t := g.create_tween()
	t.tween_property(g, "scale", g.scale * 1.8, 0.25)
	t.parallel().tween_property(g, "modulate:a", 0.0, 0.3)
	t.tween_callback(g.queue_free)


# --- drawing ----------------------------------------------------------------------------

func _draw_floor() -> void:
	var r := room_rect()
	Kit.planks(room_under, Rect2(r.position.x + 16, -32, r.size.x - 32, 192), Color("4e3226"), 8)
	# A rag rug before the hearth.
	room_under.draw_rect(Rect2(HEARTH_X - 30, 8, 60, 22), Color("3a2430"))
	room_under.draw_rect(Rect2(HEARTH_X - 28, 10, 56, 18), Color("6a3040"))
	for k in 6:
		room_under.draw_rect(Rect2(HEARTH_X - 26, 12 + k * 3, 52, 1), Color("8a4a50") if k % 2 == 0 else Color("4a2836"))


func _draw_walls() -> void:
	var r := room_rect()
	var x0 := r.position.x
	var x1 := r.end.x
	Kit.bricks(room_walls, Rect2(x0, -96, r.size.x, 64), WALL_TINT)
	# The stone darkens up toward the ceiling beam, out of reach of the lamps.
	for i in 26:
		room_walls.draw_rect(Rect2(x0, -89 + i, r.size.x, 1), Color(0.03, 0.01, 0.03, 0.5 * (1.0 - i / 26.0)))
	# Timber: a top beam, posts every few tiles, a skirting board.
	Kit.beam(room_walls, x0, x1, -96, Color("2e1a14"))
	for px: float in [x0 + 16, -8.0, 168.0, 296.0, x1 - 20]:
		room_walls.draw_rect(Rect2(px, -90, 5, 58), Color("2e1a14"))
		room_walls.draw_rect(Rect2(px, -90, 1, 58), Color("4a2e22"))
	room_walls.draw_rect(Rect2(x0, -36, r.size.x, 4), Color("2e1a14"))
	for i in 6:
		room_walls.draw_rect(Rect2(x0, -32 + i, r.size.x, 1), Color(0, 0, 0, 0.3 - i * 0.05))
	# Side and bottom walls.
	room_walls.draw_rect(Rect2(x0, -32, 16, 192), Color("120c12"))
	room_walls.draw_rect(Rect2(x0 + 15, -32, 1, 192), Color("3a2a26"))
	room_walls.draw_rect(Rect2(x1 - 16, -32, 16, 192), Color("120c12"))
	room_walls.draw_rect(Rect2(x1 - 16, -32, 1, 192), Color("3a2a26"))
	room_walls.draw_rect(Rect2(x0, 160, 112 - x0, 16), Color("120c12"))
	room_walls.draw_rect(Rect2(144, 160, x1 - 144, 16), Color("120c12"))
	room_walls.draw_rect(Rect2(x0 + 16, 160, 112 - x0 - 16, 1), Color("3a2a26"))
	room_walls.draw_rect(Rect2(144, 160, x1 - 160, 1), Color("3a2a26"))
	room_walls.draw_rect(Rect2(112, 160, 32, 16), Color("1c1418"))
	room_walls.draw_rect(Rect2(110, 156, 2, 20), WOOD)
	room_walls.draw_rect(Rect2(144, 156, 2, 20), WOOD)
	_draw_dressing()


## What hangs on the back wall: two cult banners by the hearth, a mug rack, and a horned
## skull on a plaque.
func _draw_dressing() -> void:
	var w := room_walls
	# Banners on the posts either side of the hearth: plum cloth, a brass coin, a fringe.
	for bx: float in [180.0, 284.0]:
		w.draw_rect(Rect2(bx - 7, -86, 14, 2), WOOD.lightened(0.2))
		w.draw_rect(Rect2(bx - 6, -84, 12, 22), Color("4a1f3a"))
		w.draw_rect(Rect2(bx - 6, -84, 1, 22), Color("6a2f52"))
		w.draw_rect(Rect2(bx + 5, -84, 1, 22), Color("2e1024"))
		for k in 6:
			w.draw_rect(Rect2(bx - 6 + k * 2, -62, 1, 2 + (k % 2)), Color("c9a24a").darkened(0.2))
		w.draw_circle(Vector2(bx, -74), 3.5, Color("c9a24a"))
		w.draw_circle(Vector2(bx, -74), 2.0, Color("8a6a2a"))
		w.draw_rect(Rect2(bx - 1, -76, 1, 1), Color("fff0b0"))
	# A mug rack: a plank on pegs, mugs hanging by their handles.
	var mx := 302.0
	w.draw_rect(Rect2(mx, -70, 40, 3), WOOD.lightened(0.15))
	w.draw_rect(Rect2(mx, -70, 40, 1), WOOD.lightened(0.4))
	for k in 4:
		var x := mx + 4 + k * 9
		w.draw_rect(Rect2(x + 2, -67, 1, 2), Color("2a1a14"))
		w.draw_rect(Rect2(x, -65, 5, 6), Color("c8a060").darkened(0.1 * (k % 2)))
		w.draw_rect(Rect2(x, -65, 5, 1), Color("fff0c0"))
		w.draw_rect(Rect2(x + 5, -64, 1, 3), Color("8a6a40"))
	# The horned skull on its plaque, over the keg rack.
	var sx := -52.0
	w.draw_rect(Rect2(sx - 9, -86, 18, 16), WOOD.darkened(0.1))
	w.draw_rect(Rect2(sx - 9, -86, 18, 1), WOOD.lightened(0.3))
	w.draw_rect(Rect2(sx - 8, -71, 16, 1), Color(0, 0, 0, 0.4))
	var bone := Color("e8dcc0")
	for p: Vector2 in [Vector2(-8, -88), Vector2(-9, -90), Vector2(-10, -92), Vector2(7, -88), Vector2(8, -90), Vector2(9, -92)]:
		w.draw_rect(Rect2(Vector2(sx, 0) + p, Vector2(1, 2)), bone.darkened(0.15))
	w.draw_rect(Rect2(sx - 5, -84, 10, 7), bone)
	w.draw_rect(Rect2(sx - 4, -77, 8, 3), bone.darkened(0.1))
	w.draw_rect(Rect2(sx - 3, -82, 2, 2), Color("1a0c10"))
	w.draw_rect(Rect2(sx + 1, -82, 2, 2), Color("1a0c10"))
	w.draw_rect(Rect2(sx - 1, -79, 2, 1), Color("1a0c10"))
	w.draw_rect(Rect2(sx - 5, -84, 10, 1), Color.WHITE.lerp(bone, 0.4))


# --- pieces -----------------------------------------------------------------------------

## Behind the bar: a rack of kegs and a shelf of bottles against the wall.
class BackBar extends Node2D:
	func _ready() -> void:
		for k in 6:
			var g := Rect2(288 + (k % 4) * 16, 336 + (k / 4) * 16, 16, 16)
			Room.Kit.put(Room.Kit.region(Room.Kit.SHEET, g), Vector2(70 + k * 11, -44), self)

	func _draw() -> void:
		var w := TavernRoom.WOOD
		# Keg rack.
		draw_rect(Rect2(-108, -10, 92, 4), w.lightened(0.1))
		for k in 4:
			var c := Vector2(-96 + k * 22, -20)
			draw_circle(c, 10.0, Color("5a3422"))
			draw_circle(c, 8.0, Color("6e4228"))
			draw_arc(c, 9.0, 0, TAU, 18, Color("2a2224"), 1.0)
			draw_circle(c, 2.0, Color("2a1a14"))
			draw_rect(Rect2(c.x - 1, c.y + 6, 2, 5), Color("b8893a"))
		# Bottle shelf.
		draw_rect(Rect2(66, -28, 70, 3), w.lightened(0.1))
		draw_rect(Rect2(66, -25, 70, 1), Color(0, 0, 0, 0.5))


## The long bar, drawn in front of Bess.
class Bar extends Node2D:
	func _draw() -> void:
		var w := TavernRoom.WOOD
		draw_rect(Rect2(-112, -16, 248, 16), w)
		draw_rect(Rect2(-114, -21, 252, 6), w.lightened(0.2))
		draw_rect(Rect2(-114, -21, 252, 1), w.lightened(0.45))
		for k in 15:
			draw_rect(Rect2(-108 + k * 16, -12, 12, 8), w.darkened(0.18))
			draw_rect(Rect2(-108 + k * 16, -12, 12, 1), w.darkened(0.4))
		draw_rect(Rect2(-112, -2, 248, 2), Color("b8893a").darkened(0.3))
		# Mugs and a towel on the bar top.
		for x: int in [-90, -50, 70, 110]:
			draw_rect(Rect2(x, -25, 4, 5), Color("c8a060"))
			draw_rect(Rect2(x, -25, 4, 1), Color("fff0c0"))
		draw_rect(Rect2(10, -22, 10, 2), Color("d8d0c0"))


## The chalk slate behind the bar: spent / budget, in chalk.
class Slate extends Node2D:
	var text := ""
	var _label: Label

	func refresh() -> void:
		if _label:
			_label.queue_free()
		_label = Room.Kit.write(self, text, Vector2(0, 0), Color(0.93, 0.92, 0.86, 0.92))

	func _draw() -> void:
		var w := maxf(56.0, text.length() * 6.0 + 10.0)
		draw_rect(Rect2(-w / 2 - 3, -10, w + 6, 20), TavernRoom.WOOD.lightened(0.1))
		draw_rect(Rect2(-w / 2, -8, w, 16), Color("1e2a26"))
		draw_rect(Rect2(-w / 2 + 2, 5, 6, 1), Color(1, 1, 1, 0.25))
		draw_rect(Rect2(w / 2 - 10, -6, 5, 1), Color(1, 1, 1, 0.15))
		draw_line(Vector2(-10, -10), Vector2(0, -16), Color("8a7a60"), 1.0)
		draw_line(Vector2(10, -10), Vector2(0, -16), Color("8a7a60"), 1.0)


## The hearth: a stone surround, a black firebox (the flames sit in it), a mantel.
class Hearth extends Node2D:
	func _draw() -> void:
		var stone := TavernRoom.STONE
		draw_rect(Rect2(-30, -62, 60, 62), stone)
		for y in range(-60, 0, 6):
			for x in range(-30 + (3 if (y / 6) % 2 == 0 else 0), 30, 10):
				draw_rect(Rect2(x, y, 9, 5), stone.lightened(0.12 + 0.05 * float(absi(x * 7 + y) % 3)))
		draw_rect(Rect2(-18, -26, 36, 26), Color("0c0608"))
		draw_rect(Rect2(-18, -26, 36, 2), Color("2a1010"))
		draw_rect(Rect2(-34, -32, 68, 5), TavernRoom.WOOD.lightened(0.15))
		draw_rect(Rect2(-34, -32, 68, 1), TavernRoom.WOOD.lightened(0.4))
		draw_rect(Rect2(-14, -4, 28, 3), Color("2a2024"))
		draw_rect(Rect2(-24, -38, 4, 6), Color("d8d0c0"))
		draw_rect(Rect2(18, -38, 5, 6), Color("b8893a"))


## A round table with a candle stub.
class Table extends Node2D:
	func _draw() -> void:
		var w := TavernRoom.WOOD
		draw_rect(Rect2(-8, -8, 2, 8), w.darkened(0.35))
		draw_rect(Rect2(6, -8, 2, 8), w.darkened(0.35))
		draw_rect(Rect2(-12, -12, 24, 4), w.darkened(0.15))
		draw_rect(Rect2(-12, -18, 24, 7), w.lightened(0.12))
		draw_rect(Rect2(-12, -18, 24, 1), w.lightened(0.4))
		draw_rect(Rect2(-1, -21, 2, 4), Color("e8e0d0"))
		draw_rect(Rect2(0, -23, 1, 2), Color("ffd090"))
		draw_rect(Rect2(-9, -16, 4, 3), Color("c8a060"))
		draw_rect(Rect2(5, -16, 3, 2), Color("d8d0c0"))
