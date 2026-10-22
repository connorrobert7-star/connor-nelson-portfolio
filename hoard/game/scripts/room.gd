class_name Room
extends Level
## Interiors. Every room has its door in the bottom wall and you arrive just inside.
## W wall top, w wall face, f floor, c counter, t table, r rug, d door.
##
## A room that fills the screen (the shop, the tavern) starts its map up and to the left of
## tile (0, 0): `origin` is where map[0][0] sits. The door, the counter and the arrival spot
## keep their old tiles, and the walls, shelves and hearth spend the extra space. Those rooms
## draw themselves from pack sheets: a dark floor, warm pools of light, dust in the air.

const ENTRANCE := Vector2i(7, 9)
const LEGEND := {"W": 10, "w": 9, "f": 8, "c": 12, "t": 13, "r": 14, "d": 11}

var exit_spawn := Level.RETURN
## Where map[0][0] sits, in tiles. Zero for the small rooms.
var origin := Vector2i.ZERO
## Layers of a drawn room, back to front: the floor, light pools on it, the dark that closes
## in (under the props, so lit things glow out of it), the walls; and the air over it all.
var room_under := Node2D.new()
var room_pools := Node2D.new()
var room_shade := Node2D.new()
var room_walls := Node2D.new()
var room_air := Node2D.new()

var _room_hot: Array[Dictionary] = []  # {rect: Rect2, it: Dictionary}: tap a thing, not its spot
var _room_flicker: Array[Dictionary] = []  # {node, alpha, amount, speed, seed}
var _room_t := 0.0
var _room_route: Array[Vector2] = []


func build() -> void:
	legend = LEGEND
	solid = "Wwct"
	follow_camera = false
	for x in [7, 8]:
		add_door(Vector2i(x, origin.y + map.size() - 1), "village", exit_spawn)


func _ready() -> void:
	if origin != Vector2i.ZERO:
		for layer: Node2D in [room_under, room_pools, room_shade, room_walls]:
			add_child(layer)
	super._ready()
	if origin != Vector2i.ZERO:
		add_child(room_air)
		camera.position = Vector2(room_rect().get_center())
		leader.arrived.connect(func() -> void:
			if not _room_route.is_empty() and not Game.busy:
				leader.walk_to(_room_route.pop_front())
		)


func _process(delta: float) -> void:
	super._process(delta)
	if not _room_route.is_empty() and Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") != Vector2.ZERO:
		_room_route.clear()
	_room_t += delta
	for f: Dictionary in _room_flicker:
		var n: CanvasItem = f.node
		if not is_instance_valid(n):
			continue
		var s: float = f.seed
		var k := sin(_room_t * f.speed + s) * 0.5 + sin(_room_t * f.speed * 2.3 + s * 1.7) * 0.3 + sin(_room_t * 13.0 + s) * 0.2
		n.modulate.a = float(f.alpha) * (1.0 + float(f.amount) * k)


## The room in pixels, walls included.
func room_rect() -> Rect2:
	return Rect2(Vector2(origin * TILE), Vector2(map[0].length(), map.size()) * TILE)


func _paint() -> void:
	if origin == Vector2i.ZERO:
		super._paint()
		return
	ground.visible = false
	for y in map.size():
		for x in map[y].length():
			var cell := Vector2i(x, y) + origin
			if solid.contains(map[y][x]) and not _open.has(cell):
				_blocked[cell] = true


func is_walkable(feet: Rect2) -> bool:
	if origin == Vector2i.ZERO:
		return super.is_walkable(feet)
	var bounds := Rect2i(origin, Vector2i(map[0].length(), map.size()))
	var a := Vector2i((feet.position / TILE).floor())
	var b := Vector2i((feet.end / TILE).floor())
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			if not bounds.has_point(Vector2i(x, y)) or _blocked.has(Vector2i(x, y)):
				return false
	return true


## Tapping anywhere on a thing (a shelf, Marlo, a tag) walks to its spot and uses it.
func _on_tap(point: Vector2) -> void:
	var to := point
	for h: Dictionary in _room_hot:
		if (h.rect as Rect2).has_point(point):
			to = (h.it as Dictionary).pos
			break
	_room_route.clear()
	super._on_tap(to)
	if origin != Vector2i.ZERO and leader.target != Vector2.INF:
		_room_route = _room_path(leader.position, to)
		if not _room_route.is_empty():
			leader.walk_to(_room_route.pop_front())


## Waypoints around the furniture from `from` to `to` (empty: walk straight).
func _room_path(from: Vector2, to: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(origin, Vector2i(map[0].length(), map.size()))
	grid.cell_size = Vector2(TILE, TILE)
	grid.offset = Vector2(TILE, TILE) / 2.0
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for cell: Vector2i in _blocked:
		if grid.is_in_boundsv(cell):
			grid.set_point_solid(cell)
	var a := Vector2i(((from - Vector2(0, 2)) / TILE).floor())
	var b := Vector2i(((to - Vector2(0, 2)) / TILE).floor())
	if not grid.is_in_boundsv(a) or not grid.is_in_boundsv(b) or grid.is_point_solid(a) or grid.is_point_solid(b):
		return out
	var path := grid.get_point_path(a, b)
	if path.size() <= 2:
		return out
	var last_dir := Vector2.ZERO
	for i in range(1, path.size() - 1):
		var d := (path[i + 1] - path[i]).normalized()
		if d != last_dir:
			out.append(path[i] + Vector2(0, 4))
		last_dir = d
	out.append(to)
	return out


## The last interactable added also answers taps anywhere in `rect`, and shows no prompt.
func room_hotspot(rect: Rect2) -> void:
	var it: Dictionary = _interactables[-1]
	it.label = func() -> String: return ""
	_room_hot.append({"rect": rect, "it": it})


# --- drawing kit ------------------------------------------------------------------------

## A light that breathes like a flame: its alpha wobbles around `alpha` by `amount`.
func room_flicker(node: CanvasItem, amount := 0.18, speed := 5.0) -> void:
	_room_flicker.append({"node": node, "alpha": node.modulate.a, "amount": amount, "speed": speed, "seed": randf() * 50.0})


## The dark closing in from the edges, over the floor and walls only.
func room_vignette(center: Vector2, strength := 0.9) -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0.02, 0.0, 0.04, 0.38 * strength), Color(0.01, 0.0, 0.03, strength)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	var r := room_rect()
	gt.fill_from = (center - r.position) / r.size
	gt.fill_to = gt.fill_from + Vector2(0.62, 0)
	gt.width = 96
	gt.height = 64
	var v := Sprite2D.new()
	v.texture = gt
	v.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	v.centered = false
	v.position = r.position
	v.scale = r.size / Vector2(96, 64)
	room_shade.add_child(v)


## Dust drifting through the light: a few slow motes, warm by default.
func room_motes(rect: Rect2, color := Kit.WARM, amount := 14) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.position = rect.get_center()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = rect.size / 2.0
	p.direction = Vector2(0.3, -1)
	p.spread = 60.0
	p.gravity = Vector2(0, -1.5)
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 4.0
	p.color = Color(color, 0.55)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	p.color_ramp = ramp
	p.material = Kit.additive()
	room_air.add_child(p)
	return p


## A lantern hanging on a chain from the top of the room, with its halo and floor pool.
func room_lantern(floor_at: Vector2, height: float, color := Kit.WARM, pool := 64.0) -> Node2D:
	var top := room_rect().position.y
	var lamp := Node2D.new()
	lamp.position = floor_at - Vector2(0, height)
	lamp.z_index = 3
	room_air.add_child(lamp)
	# The chain hangs behind the shelves and tags (under the props), the lamp in front.
	var chain := Line2D.new()
	chain.points = PackedVector2Array([Vector2(lamp.position.x, top), lamp.position + Vector2(0, -14)])
	chain.width = 1
	chain.default_color = Color("1a1210")
	room_walls.add_child(chain)
	var body := Node2D.new()
	lamp.add_child(body)
	body.draw.connect(func() -> void:
		var iron := Color("1c1418")
		body.draw_rect(Rect2(-1, -14, 2, 2), iron)
		body.draw_rect(Rect2(-4, -12, 8, 2), iron)
		body.draw_rect(Rect2(-3, -10, 6, 8), color.lerp(Color.WHITE, 0.2))
		body.draw_rect(Rect2(-1, -8, 2, 4), Color("fff4d0"))
		body.draw_rect(Rect2(-4, -10, 1, 8), iron)
		body.draw_rect(Rect2(3, -10, 1, 8), iron)
		body.draw_rect(Rect2(-5, -2, 10, 2), iron)
		body.draw_rect(Rect2(-3, -12, 6, 1), Color(1, 1, 1, 0.15))
	)
	var halo := Kit.glow(lamp, Vector2(0, -6), color, 22.0, 0.6)
	room_flicker(halo, 0.12, 6.0)
	var p := Kit.glow(room_pools, floor_at, color, pool, 0.42, 0.55)
	room_flicker(p, 0.08, 4.0)
	return lamp


## Pack regions, light and words for drawn rooms. Static, so subclasses never collide.
class Kit:
	const PACKS := "res://art/packs/"
	const INDOOR := "kenney-roguelike-indoors/Tilesheets/roguelikeIndoor_transparent.png"
	const DARK := "0x72-dungeontileset-ii/dark_kosinaz/DarkDungeon.png"
	const EXT := "0x72-dungeontileset-ii/extended_niji/dungeontileset-extended.png"
	const SHEET := "0x72-dungeontileset-ii/0x72_DungeonTilesetII_v1.7/0x72_DungeonTilesetII_v1.7.png"
	const NINJA := "ninja-adventure/Actor/Character/%s/SpriteSheet.png"
	const FONT := "font-m5x7/m5x7.ttf"
	const WARM := Color("ffb26b")
	const BONE := Color("f6ead2")
	const INK := Color("2b1a16")
	const MOON := Color("9fb7ff")

	static func region(path: String, rect: Rect2) -> AtlasTexture:
		var a := AtlasTexture.new()
		a.atlas = load(PACKS + path) as Texture2D
		a.region = rect
		a.filter_clip = true
		return a


	## One 16x16 tile of Kenney's Roguelike Indoors sheet (1px gaps between tiles).
	static func indoor(col: int, row: int) -> AtlasTexture:
		return region(INDOOR, Rect2(col * 17, row * 17, 16, 16))


	static func put(t: Texture2D, pos: Vector2, parent: Node, centered := false) -> Sprite2D:
		var s := Sprite2D.new()
		s.texture = t
		s.centered = centered
		s.position = pos
		parent.add_child(s)
		return s


	## A block of Kenney tiles laid edge to edge (the sheet's gaps left out).
	static func indoor_block(col: int, row: int, w: int, h: int, pos: Vector2, parent: Node) -> Node2D:
		var n := Node2D.new()
		n.position = pos
		parent.add_child(n)
		for y in h:
			for x in w:
				put(indoor(col + x, row + y), Vector2(x, y) * 16, n)
		return n


	static func additive() -> CanvasItemMaterial:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		return m


	static func radial(soft := true) -> GradientTexture2D:
		var g := Gradient.new()
		if soft:
			g.offsets = PackedFloat32Array([0.0, 0.3, 0.65, 1.0])
			g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.16), Color(1, 1, 1, 0)])
		else:
			g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
			g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		return t


	## Additive light: a soft disc (squashed into a floor pool when squash < 1).
	static func glow(parent: Node, pos: Vector2, color: Color, radius: float, alpha := 0.4, squash := 1.0) -> Sprite2D:
		var s := Sprite2D.new()
		s.texture = radial()
		s.material = additive()
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		s.scale = Vector2(1.0, squash) * (radius * 2.0 / 64.0)
		s.modulate = Color(color, alpha)
		s.position = pos
		parent.add_child(s)
		return s


	## m5x7 as the HUD imports it: no antialiasing, no hinting, whole-pixel glyphs.
	static func pixel_font() -> FontFile:
		return load("res://art/ui/fonts/m5x7.ttf") as FontFile


	## Words written on a thing (a tag, a slate), centered on `pos`, crisp at 1x.
	static func write(parent: Node, text: String, pos: Vector2, color := INK, shadow := Color(0, 0, 0, 0)) -> Label:
		var ls := LabelSettings.new()
		ls.font = pixel_font()
		ls.font_size = 16
		ls.font_color = color
		ls.line_spacing = -4
		if shadow.a > 0:
			ls.shadow_size = 0
			ls.shadow_color = shadow
			ls.shadow_offset = Vector2(1, 1)
		var l := Label.new()
		l.text = text
		l.label_settings = ls
		# Left-aligned at a whole pixel: centering an odd width lands glyphs on half pixels.
		var tw := ls.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size = Vector2(ceilf(tw) + 2, 12)
		l.position = Vector2(roundf(pos.x - tw / 2.0), roundf(pos.y - 6.0))
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(l)
		return l


	## Dark plank flooring over `rect`: rows of boards with staggered seams and a few nails.
	static func planks(ci: CanvasItem, rect: Rect2, base: Color, row_h := 8) -> void:
		ci.draw_rect(rect, base.darkened(0.55))
		var rows := int(rect.size.y / row_h)
		for r in rows:
			var y := rect.position.y + r * row_h
			var x := rect.position.x - float((r * 37) % 48)
			var i := 0
			while x < rect.end.x:
				var h := absi((r * 73856093) ^ (i * 19349663)) % 97
				var w := 40.0 + float(h % 4) * 12.0
				var a := maxf(x, rect.position.x)
				var b := minf(x + w - 1, rect.end.x)
				if b > a:
					var c := base.lerp(base.darkened(0.25), float(h % 5) / 6.0)
					ci.draw_rect(Rect2(a, y, b - a, row_h - 1), c)
					ci.draw_rect(Rect2(a, y, b - a, 1), c.lightened(0.12))
					if h % 7 == 0 and b - a > 20:
						ci.draw_rect(Rect2(a + 6, y + 3, 6, 1), c.darkened(0.2))
					if h % 3 == 0:
						ci.draw_rect(Rect2(a + 2, y + row_h / 2 - 1, 1, 1), c.darkened(0.45))
						ci.draw_rect(Rect2(b - 3, y + row_h / 2 - 1, 1, 1), c.darkened(0.45))
				x += w
				i += 1


	## Bricks of the dark dungeon sheet across `rect`, tinted.
	static func bricks(ci: CanvasItem, rect: Rect2, tint: Color) -> void:
		var tex: Texture2D = load(PACKS + DARK)
		var y := rect.position.y
		var j := 0
		while y < rect.end.y:
			var x := rect.position.x
			var i := 0
			while x < rect.end.x:
				var h := absi((i * 73856093) ^ (j * 19349663)) % 97
				var src := Rect2(64 + (h % 3) * 16, 16 + (1 if j % 2 == 0 else 0) * 16, 16, 16)
				ci.draw_texture_rect_region(tex, Rect2(x, y, 16, 16), src, tint)
				x += 16
				i += 1
			y += 16
			j += 1


	## A ceiling beam across the top of a room, with its shadow.
	static func beam(ci: CanvasItem, x0: float, x1: float, y: float, wood: Color) -> void:
		ci.draw_rect(Rect2(x0, y, x1 - x0, 7), wood)
		ci.draw_rect(Rect2(x0, y, x1 - x0, 1), wood.lightened(0.25))
		ci.draw_rect(Rect2(x0, y + 6, x1 - x0, 1), wood.darkened(0.4))
		ci.draw_rect(Rect2(x0, y + 7, x1 - x0, 3), Color(0, 0, 0, 0.35))
		var x := x0 + 10.0
		while x < x1:
			ci.draw_rect(Rect2(x, y + 3, 1, 1), wood.darkened(0.5))
			x += 37.0


	## A ground shadow under something standing on the floor.
	static func shadow(parent: Node, pos: Vector2, w: float, alpha := 0.35) -> Sprite2D:
		var s := Sprite2D.new()
		s.texture = radial(false)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		s.scale = Vector2(w / 64.0, w * 0.35 / 64.0)
		s.modulate = Color(0, 0, 0, alpha)
		s.position = pos
		parent.add_child(s)
		return s


	## A villager from the Ninja Adventure pack: `facing` 0 down, 1 up, 2 left, 3 right.
	static func ninja(who: String, facing := 0) -> AtlasTexture:
		return region(NINJA % who, Rect2(facing * 16, 0, 16, 16))


	static func play(path: String, pitch := 1.0, db := -8.0) -> void:
		Sfx.play_path(PACKS + path, pitch, db)
