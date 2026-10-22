class_name ArcadeRoom
extends Room
## The arcade, filling the screen: three cabinets glowing against the back wall (the mine,
## fishing, the dungeon), their screens spilling colored light across a cosmic carpet, a
## chase of marquee bulbs running along the top of the wall, two neon zigzags buzzing between
## the cabinets, dead machines sulking by the side walls, the lantern's flames on a stand in
## the middle, and the din of machines. Tap a cabinet to play: the one in reach brightens its
## marquee and bobs it (light, never a word).

const DARK := ArcadeFx.PACKS + "0x72-dungeontileset-ii/dark_kosinaz/DarkDungeon.png"
const CABINETS := "res://features/minigames/art/cabinet.png"
const ICONS := ArcadeFx.PACKS + "kyrise-rpg-icons-16/spritesheet/spritesheet_16x16.png"
const DUNGEON_SHEET := ArcadeFx.PACKS + "0x72-dungeontileset-ii/0x72_DungeonTilesetII_v1.7/0x72_DungeonTilesetII_v1.7.png"
const AMBIENCE := ArcadeFx.PACKS + "freesound-cc0-picks/79088_AkasakaPachinkoParlorLunchtime_4micsStereoExpanded_wav.mp3"
const NEON := ArcadeFx.PACKS + "karsiori-neon-signs/Sign 10/Sign 10 Glow - %s.png"
const TRIM := [Color("ff9a3c"), Color("2ec4b6"), Color("ff6fb5")]
const GAMES := ["mine", "fishing", "dungeon"]
## Each cabinet's footprint: 2 tiles wide and 3 tall, standing a step out from the back
## wall so the marquees clear the HUD's corners.
const SPOTS := [Vector2i(-2, -3), Vector2i(7, -3), Vector2i(16, -3)]
const STAND := Vector2i(7, 3)
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
## The cosmic carpet under the play area, and the dead cabinets by the side walls.
const CARPET := Rect2(-80, -14, 416, 160)
const DEAD: Array[Vector2] = [Vector2(-80, 44), Vector2(-80, 96), Vector2(336, 44), Vector2(336, 96)]

var cabinets: Array[Sprite2D] = []
var _marquees: Array[Node2D] = []
var _marquee_glows: Array[Sprite2D] = []
var _bulbs: Array[Sprite2D] = []
var _neons: Array[Sprite2D] = []
var _neon_frames: Array = []
var _dead_screens: Array[Node2D] = []
var _reach := -1
var _ambience: AudioStreamPlayer


func _init() -> void:
	map = MAP
	origin = Vector2i(-7, -6)


func build() -> void:
	super.build()
	room_under.draw.connect(_draw_floor)
	room_walls.draw.connect(_draw_walls)
	for i in 3:
		_build_cabinet(i)
	# The strip along the back wall is the cabinets' alone: the leader plays from the aisle
	# in front, so a tap on any cabinet is a straight walk with nothing in the way.
	block(Rect2i(-6, -2, 28, 2))
	for d: Vector2 in DEAD:
		block(Rect2i(floori((d.x - 16.0) / TILE), floori((d.y - 8.0) / TILE), 2, 1))
	_build_stand()
	_build_dressing()
	_build_light()
	_ambience = ArcadeFx.music(self, AMBIENCE, -26.0, "Ambience")


func _exit_tree() -> void:
	if _ambience:
		_ambience.stop()


## Footsteps go soft on the carpet and ring on the stone around it.
func surface_at(feet: Vector2) -> String:
	return "carpet" if CARPET.has_point(feet) else "concrete"


# --- the room ---------------------------------------------------------------------------

## Near-black stone under a cosmic carpet: deep violet with neon squiggles, stars and rings
## in the cabinets' colors, the kind every arcade floor has.
func _draw_floor() -> void:
	var tex := Kit.tex(Kit.DARK)
	var r := room_rect()
	for y in range(int(r.position.y) + 64, int(r.end.y) - 16, 16):
		for x in range(int(r.position.x) + 16, int(r.end.x) - 16, 16):
			var v := absi((x / 16) * 7 + (y / 16) * 13) % 5
			room_under.draw_texture_rect_region(tex, Rect2(x, y, 16, 16), Rect2(16 + (v % 4) * 16, 128 + (v / 4) * 16, 16, 16), Color(0.85, 0.8, 0.95))
	var c := CARPET
	room_under.draw_rect(c.grow(2), Color("0e0818"))
	room_under.draw_rect(c, Color("1c1034"))
	room_under.draw_rect(Rect2(c.position + Vector2(3, 3), c.size - Vector2(6, 6)), Color("231440"))
	var inks: Array[Color] = [TRIM[0], TRIM[1], TRIM[2], Color("8f7fff"), Color("f6e27a")]
	for gy in range(int(c.position.y) + 6, int(c.end.y) - 6, 12):
		for gx in range(int(c.position.x) + 6, int(c.end.x) - 6, 12):
			var h := absi((gx * 73856093) ^ (gy * 19349663)) % 97
			if h % 3 == 0:
				continue
			var col: Color = inks[h % inks.size()]
			col.a = 0.45
			var o := Vector2(gx + h % 5, gy + (h / 5) % 5)
			match h % 4:
				0:  # a little star
					room_under.draw_rect(Rect2(o + Vector2(1, 0), Vector2(1, 3)), col)
					room_under.draw_rect(Rect2(o + Vector2(0, 1), Vector2(3, 1)), col)
				1:  # a squiggle
					for k in 5:
						room_under.draw_rect(Rect2(o + Vector2(k, (k % 2)), Vector2.ONE), col)
				2:  # a ring
					room_under.draw_rect(Rect2(o, Vector2(3, 1)), col)
					room_under.draw_rect(Rect2(o + Vector2(0, 2), Vector2(3, 1)), col)
					room_under.draw_rect(Rect2(o + Vector2(0, 1), Vector2.ONE), col)
					room_under.draw_rect(Rect2(o + Vector2(2, 1), Vector2.ONE), col)
				_:  # a dot
					room_under.draw_rect(Rect2(o, Vector2(2, 2)), col)


## A dark brick back wall under a black ceiling, the side walls, and the doorway.
func _draw_walls() -> void:
	var r := room_rect()
	var x0 := r.position.x
	var x1 := r.end.x
	Kit.bricks(room_walls, Rect2(x0, -80, r.size.x, 48), Color(0.62, 0.52, 0.78))
	room_walls.draw_rect(Rect2(x0, -96, r.size.x, 16), Color("0c0812"))
	for i in 18:
		room_walls.draw_rect(Rect2(x0, -80 + i, r.size.x, 1), Color(0.02, 0.0, 0.04, 0.55 * (1.0 - i / 18.0)))
	room_walls.draw_rect(Rect2(x0, -35, r.size.x, 3), Color("2a1a3a"))
	room_walls.draw_rect(Rect2(x0, -35, r.size.x, 1), Color("4a3a66"))
	for i in 6:
		room_walls.draw_rect(Rect2(x0, -32 + i, r.size.x, 1), Color(0, 0, 0, 0.3 - i * 0.05))
	room_walls.draw_rect(Rect2(x0, -32, 16, 192), Color("0c0812"))
	room_walls.draw_rect(Rect2(x0 + 15, -32, 1, 192), Color("2e2440"))
	room_walls.draw_rect(Rect2(x1 - 16, -32, 16, 192), Color("0c0812"))
	room_walls.draw_rect(Rect2(x1 - 16, -32, 1, 192), Color("2e2440"))
	room_walls.draw_rect(Rect2(x0, 160, 112 - x0, 16), Color("0c0812"))
	room_walls.draw_rect(Rect2(144, 160, x1 - 144, 16), Color("0c0812"))
	room_walls.draw_rect(Rect2(x0 + 16, 160, 112 - x0 - 16, 1), Color("2e2440"))
	room_walls.draw_rect(Rect2(144, 160, x1 - 160, 1), Color("2e2440"))
	room_walls.draw_rect(Rect2(112, 160, 32, 16), Color("140c18"))
	room_walls.draw_rect(Rect2(110, 156, 2, 20), Color("3a2a4a"))
	room_walls.draw_rect(Rect2(144, 156, 2, 20), Color("3a2a4a"))


func _build_cabinet(i: int) -> void:
	var spot: Vector2i = SPOTS[i]
	var rect := Rect2i(spot, Vector2i(2, 3))
	var trim: Color = TRIM[i]
	var cx := (spot.x + 1) * TILE
	var base := rect.end.y * TILE
	# A pool of the cabinet's light on the carpet, and its screen's glow spilling down to it.
	var pool := Kit.glow(room_pools, Vector2(cx, base + 26), trim, 62, 0.34, 0.55)
	room_flicker(pool, 0.12, 2.0 + i * 0.4)
	var spill := Polygon2D.new()
	spill.polygon = PackedVector2Array([Vector2(cx - 9, base - 30), Vector2(cx + 9, base - 30), Vector2(cx + 34, base + 52), Vector2(cx - 34, base + 52)])
	spill.vertex_colors = PackedColorArray([Color(trim, 0.2), Color(trim, 0.2), Color(trim, 0.0), Color(trim, 0.0)])
	spill.material = Kit.additive()
	room_pools.add_child(spill)
	var cab := place(ArcadeFx.tex(CABINETS, [i * 32, 0, 32, 48]), rect)
	cab.name = "Cabinet_%s" % GAMES[i]
	cabinets.append(cab)
	Kit.shadow(room_pools, cab.position, 34, 0.5)
	var screen := Node2D.new()
	screen.position = Vector2(0, -28)
	cab.add_child(screen)
	_attract(i, screen)
	# The game's sign glows on the wall above, flickering now and then.
	var marquee := Node2D.new()
	marquee.position = Vector2(0, -58)
	cab.add_child(marquee)
	var mg := ArcadeFx.glow(marquee, Vector2.ZERO, trim, 22.0, 0.55)
	ArcadeFx.breathe(mg, 0.55, 1.0, 1.1 + i * 0.3)
	_marquee_glows.append(mg)
	_marquees.append(marquee)
	var pict := Sprite2D.new()
	pict.texture = _pictogram(i)
	marquee.add_child(pict)
	_flicker(marquee)
	add_interactable(
		# The cabinet's coin slot, from the aisle: tap anywhere on the cabinet to play.
		Vector2(cx, base + 8),
		func() -> String: return "",
		func() -> void: _play(i)
	)
	room_hotspot(Rect2(cx - 18, base - 76, 36, 80))


## The dressing: a chase of marquee bulbs along the top of the wall, two neon zigzags
## between the cabinets, and dead machines by the side walls with static on their screens.
func _build_dressing() -> void:
	var r := room_rect()
	var x := r.position.x + 22.0
	var k := 0
	while x < r.end.x - 20.0:
		var b := Kit.glow(room_walls, Vector2(x, -76), TRIM[k % 3], 5, 0.8)
		_bulbs.append(b)
		x += 12.0
		k += 1
	for side in 2:
		var frames: Array[Texture2D] = []
		var sheet: Texture2D = load(NEON % ("PINK" if side == 0 else "RED"))
		for f in 24:
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2((f % 12) * 67, (f / 12) * 34, 67, 34)
			frames.append(at)
		var n := Sprite2D.new()
		n.texture = frames[0]
		n.position = Vector2(56.0 if side == 0 else 200.0, -52)
		n.flip_h = side == 1
		room_walls.add_child(n)
		_neons.append(n)
		_neon_frames.append(frames)
		var halo := Kit.glow(room_walls, n.position, Color("ff4fa0") if side == 0 else Color("ff4f5f"), 40, 0.16, 0.6)
		room_flicker(halo, 0.15, 3.0)
	for d: Vector2 in DEAD:
		var dead := Sprite2D.new()
		dead.texture = ArcadeFx.tex(CABINETS, [(int(d.y) / 52 % 3) * 32, 0, 32, 48])
		dead.offset = Vector2(0, -24)
		dead.position = d
		dead.modulate = Color(0.32, 0.28, 0.4)
		props.add_child(dead)
		Kit.shadow(room_pools, d, 30, 0.45)
		var st := Node2D.new()
		st.position = Vector2(0, -28)
		st.draw.connect(func() -> void:
			var seed := int(_room_t * 12.0)
			for yy in 8:
				for xx in 12:
					var h := absi((xx * 73856093) ^ (yy * 19349663) ^ (seed * 83492791)) % 7
					if h < 2:
						st.draw_rect(Rect2(-6 + xx, -4 + yy, 1, 1), Color(0.7, 0.7, 0.85, 0.35))
		)
		dead.add_child(st)
		_dead_screens.append(st)


func _build_light() -> void:
	room_vignette(Vector2(128, 40), 0.9)
	room_motes(Rect2(-90, -30, 420, 170), Color("b89aff"), 12)
	# Haze over everything so the machines are the brightest things in the room.
	var haze := CPUParticles2D.new()
	haze.amount = 24
	haze.lifetime = 6.0
	haze.preprocess = 6.0
	haze.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	haze.emission_rect_extents = Vector2(200, 80)
	haze.position = Vector2(128, 60)
	haze.direction = Vector2.UP
	haze.spread = 40.0
	haze.initial_velocity_min = 2.0
	haze.initial_velocity_max = 6.0
	haze.gravity = Vector2.ZERO
	haze.color = Color(Palette.MUTED, 0.2)
	room_air.add_child(haze)
	# The door lets a little village light in.
	ArcadeFx.breathe(Kit.glow(room_pools, Vector2(128, 158), Color("ffd38a"), 36.0, 0.22, 0.6), 0.7, 1.0, 2.4)


func _pictogram(i: int) -> Texture2D:
	match i:
		0:
			return ArcadeFx.tex(ArcadeFx.PACKS + "shattered-pixel-dungeon/sprites/items.png", [208, 112, 16, 16])
		1:
			return ArcadeFx.tex(ICONS, [0, 144, 16, 16])
	return ArcadeFx.tex(ArcadeFx.PACKS + "shattered-pixel-dungeon/sprites/items.png", [0, 32, 16, 16])


func _flicker(node: CanvasItem) -> void:
	var tw := node.create_tween().set_loops()
	tw.tween_interval(randf_range(3.0, 7.0))
	tw.tween_property(node, "modulate:a", 0.25, 0.03)
	tw.tween_property(node, "modulate:a", 1.0, 0.03)
	tw.tween_property(node, "modulate:a", 0.4, 0.05)
	tw.tween_property(node, "modulate:a", 1.0, 0.04)


## Each screen plays its game on a loop, like an attract mode.
func _attract(i: int, screen: Node2D) -> void:
	ArcadeFx.breathe(ArcadeFx.glow(screen, Vector2.ZERO, TRIM[i], 14.0, 0.35), 0.5, 1.0, 0.5)
	match i:
		0:
			var ore := Sprite2D.new()
			ore.texture = ArcadeFx.tex(ArcadeFx.PACKS + "kenney-roguelike-caves-dungeons/Spritesheet/roguelikeDungeon_transparent.png", [187, 204, 16, 16])
			ore.position = Vector2(2, 3)
			ore.scale = Vector2(0.75, 0.75)
			screen.add_child(ore)
			var pick := Sprite2D.new()
			pick.texture = ArcadeFx.tex(ArcadeFx.PACKS + "shattered-pixel-dungeon/sprites/items.png", [208, 112, 16, 16])
			pick.position = Vector2(-3, -2)
			pick.scale = Vector2(0.7, 0.7)
			screen.add_child(pick)
			var tw := pick.create_tween().set_loops()
			tw.tween_property(pick, "rotation", -1.1, 0.25)
			tw.tween_property(pick, "rotation", 0.4, 0.07)
			tw.tween_callback(func() -> void: ArcadeFx.burst(screen, Vector2(2, 2), Color("ffd75a"), 4, 30.0, 0.3))
		1:
			var water := ColorRect.new()
			water.color = Color(TRIM[1], 0.7)
			water.size = Vector2(18, 1)
			water.position = Vector2(-9, 4)
			screen.add_child(water)
			var fish := Sprite2D.new()
			fish.texture = ArcadeFx.tex(ICONS, [224, 128, 16, 16])
			fish.scale = Vector2(0.6, 0.6)
			screen.add_child(fish)
			var tw := fish.create_tween().set_loops()
			tw.tween_method(func(t: float) -> void:
				fish.position = Vector2(lerpf(-7, 7, t), 4 - sin(t * PI) * 10)
				fish.rotation = lerpf(-0.8, 0.8, t), 0.0, 1.0, 0.7)
			tw.tween_interval(0.5)
		2:
			var boss := ArcadeFx.anim_sprite({"rect": [16, 428, 32, 36], "frames": 4, "step": 32}, 6.0, DUNGEON_SHEET)
			boss.scale = Vector2(0.45, 0.45)
			boss.position = Vector2(0, 0)
			screen.add_child(boss)
			var tw := boss.create_tween().set_loops()
			tw.tween_interval(1.2)
			tw.tween_property(boss, "modulate", Color(3, 3, 3), 0.04)
			tw.tween_property(boss, "modulate", Color.WHITE, 0.08)


func _build_stand() -> void:
	# The lantern's stand: one candle per flame left today, on a pillar in the middle.
	var base := Sprite2D.new()
	base.texture = ArcadeFx.tex(DUNGEON_SHEET, [80, 80, 16, 48])
	base.position = feet_at(STAND) + Vector2(TILE / 2.0, 0)
	base.offset = Vector2(0, -12)
	base.scale = Vector2(1, 0.5)
	props.add_child(base)
	Kit.shadow(room_pools, base.position, 30, 0.5)
	room_flicker(Kit.glow(room_pools, base.position + Vector2(0, -2), Color("ffb05a"), 54, 0.3, 0.6), 0.15, 6.0)
	block(Rect2i(STAND, Vector2i(2, 1)))


func dress() -> void:
	var mg: Dictionary = Game.state.get("minigames", {})
	var flames: Dictionary = mg.get("flames", {"max": 3, "left": 3})
	var left := int(flames.get("left", 3))
	var center := feet_at(STAND) + Vector2(TILE / 2.0, -16)
	for i in int(flames.get("max", 3)):
		var lit := i < left
		var c := Sprite2D.new()
		c.texture = ArcadeFx.tex(ICONS, [64 if lit else 48, 80, 16, 16])
		c.position = center + Vector2((i - 1) * 10, absi(i - 1) * 2)
		dynamic.add_child(c)
		if lit:
			var g := ArcadeFx.glow(dynamic, c.position + Vector2(0, -5), Color("ffb05a"), 26.0, 0.55)
			ArcadeFx.breathe(g, 0.55, 1.0, 0.5 + i * 0.17)
			var flick := c.create_tween().set_loops()
			flick.tween_property(c, "scale", Vector2(1.0, 1.08), 0.12 + i * 0.03)
			flick.tween_property(c, "scale", Vector2(1.0, 0.95), 0.1)
		else:
			c.modulate = Color(0.55, 0.55, 0.6)
	# Best runs painted on each cabinet's coin door.
	var best: Dictionary = mg.get("best", {})
	for i in cabinets.size():
		var n := int(best.get(GAMES[i], 0))
		var l := ArcadeFx.label(str(n), 16, TRIM[i], false, 2)
		l.position = cabinets[i].position + Vector2(-12, -14)
		l.size = Vector2(24, 10)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.z_index = 5
		dynamic.add_child(l)
	# The dungeon's omens hang beside its cabinet, and its relic glints while it waits.
	var omens: Array = mg.get("omens", [])
	var dungeon_cab := cabinets[2]
	var catalog := MinigameOverlay._catalog_cache
	for j in omens.size():
		var spec: Dictionary = catalog.get("dungeon", {}).get("omens", {}).get(str(omens[j]), {})
		if spec.is_empty():
			continue
		var o := Sprite2D.new()
		o.texture = ArcadeFx.icon(spec.icon)
		o.scale = Vector2(0.6, 0.6)
		o.position = dungeon_cab.position + Vector2(22, -44 + j * 11)
		o.modulate = Palette.CREAM if bool(spec.get("good", false)) else Palette.BILE
		dynamic.add_child(o)
		ArcadeFx.bob(o, 1.0, 1.0 + j * 0.2)
	if bool(mg.get("relic_waiting", false)):
		var glint := ArcadeFx.glow(dynamic, dungeon_cab.position + Vector2(0, -28), Palette.CREAM, 10.0, 0.8)
		ArcadeFx.breathe(glint, 0.2, 1.0, 0.9)


func _ready() -> void:
	super._ready()
	if MinigameOverlay._catalog_cache.is_empty():
		await MinigameOverlay.load_catalog()
		if is_inside_tree() and not Game.state.is_empty():
			_redress()


func _process(delta: float) -> void:
	super._process(delta)
	# The cabinet in reach lights its marquee up and bobs it.
	var near := nearest_interactable()
	_reach = -1
	for i in cabinets.size():
		if not near.is_empty() and (near.pos as Vector2).distance_to(Vector2(cabinets[i].position.x, cabinets[i].position.y + 8)) < 1.0:
			_reach = i
	for i in _marquees.size():
		var on := i == _reach
		var m := _marquees[i]
		m.position.y = -58.0 - (roundf(1.0 + sin(_room_t * 6.0) * 1.5) if on else 0.0)
		_marquee_glows[i].scale = Vector2.ONE * (22.0 / 24.0) * (1.6 if on else 1.0)
	# The bulbs chase along the wall, three colors round and round.
	var step := int(_room_t * 9.0)
	for k in _bulbs.size():
		var lit := (k + step) % 4 == 0
		_bulbs[k].modulate.a = 0.95 if lit else 0.22
	# The neon zigzags play their own buzz and stutter.
	for n in _neons.size():
		var frames: Array = _neon_frames[n]
		var f := int(_room_t * 8.0 + n * 7) % frames.size()
		_neons[n].texture = frames[f]
	for st in _dead_screens:
		st.queue_redraw()


## A finger on a phone sends a touch and the click Godot makes from it: answer it once.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and Input.is_emulating_mouse_from_touch():
		return
	super._unhandled_input(event)


func _play(i: int) -> void:
	if Game.busy:
		return
	var cab := cabinets[i]
	ArcadeFx.squash(cab)
	ArcadeFx.sfx(ArcadeFx.PACKS + "kenney-casino-audio/Audio/chips-collide-1.ogg", 1.0, -4.0)
	var overlay: MinigameOverlay
	match i:
		0:
			overlay = MineOverlay.new()
		1:
			overlay = FishingOverlay.new()
		_:
			overlay = DungeonOverlay.new()
	if _ambience:
		_ambience.volume_db = -40.0
	var out: Variant = await main.open_overlay(overlay)
	if _ambience:
		_ambience.volume_db = -26.0
	if out is Dictionary and int((out as Dictionary).get("coins", 0)) > 0:
		ArcadeFx.burst(props, cab.position + Vector2(0, -30), ArcadeFx.BRASS, 24, 120.0, 0.8)
		ArcadeFx.pop(cab, 0.15)
