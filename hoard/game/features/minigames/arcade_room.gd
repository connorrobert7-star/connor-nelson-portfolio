class_name ArcadeRoom
extends Room
## The arcade: three cabinets glowing in the dark (the mine, fishing, the dungeon), the
## lantern's flames on a stand in the middle, and the din of machines. Tap a cabinet to play.

const DARK := ArcadeFx.PACKS + "0x72-dungeontileset-ii/dark_kosinaz/DarkDungeon.png"
const CABINETS := "res://features/minigames/art/cabinet.png"
const ICONS := ArcadeFx.PACKS + "kyrise-rpg-icons-16/spritesheet/spritesheet_16x16.png"
const DUNGEON_SHEET := ArcadeFx.PACKS + "0x72-dungeontileset-ii/0x72_DungeonTilesetII_v1.7/0x72_DungeonTilesetII_v1.7.png"
const AMBIENCE := ArcadeFx.PACKS + "freesound-cc0-picks/79088_AkasakaPachinkoParlorLunchtime_4micsStereoExpanded_wav.mp3"
const TRIM := [Color("ff9a3c"), Color("2ec4b6"), Color("ff6fb5")]
const GAMES := ["mine", "fishing", "dungeon"]
## Each cabinet's footprint: 2 tiles wide, standing on rows 2-3 against the back wall.
const SPOTS := [Vector2i(2, 1), Vector2i(7, 1), Vector2i(12, 1)]
const STAND := Vector2i(7, 6)

var cabinets: Array[Sprite2D] = []
var _ambience: AudioStreamPlayer


func _init() -> void:
	map = [
		"WWWWWWWWWWWWWWWW",
		"WwwwwwwwwwwwwwwW",
		"WffffffffffffffW",
		"WffffffffffffffW",
		"WffffffffffffffW",
		"WffffffffffffffW",
		"WffffffffffffffW",
		"WffffffffffffffW",
		"WffffffffffffffW",
		"WffffffffffffffW",
		"WWWWWWWddWWWWWWW",
	]


func build() -> void:
	super.build()
	_paint_room()
	for i in 3:
		_build_cabinet(i)
	# The strip along the back wall is the cabinets' alone: the leader plays from the aisle,
	# so a tap on any cabinet is a straight walk with nothing in the way.
	block(Rect2i(1, 2, 14, 2))
	_build_stand()
	_ambience = ArcadeFx.music(self, AMBIENCE, -26.0, "Ambience")


func _exit_tree() -> void:
	if _ambience:
		_ambience.stop()


func _paint_room() -> void:
	# Pack tiles over the placeholder ground: a near-black stone floor and a brick wall.
	var deco := Node2D.new()
	add_child(deco)
	move_child(deco, 1)
	for y in map.size():
		for x in map[y].length():
			var ch := map[y][x]
			var s := Sprite2D.new()
			s.centered = false
			s.position = Vector2(x, y) * TILE
			if ch == "f" or ch == "d":
				var v := (x * 7 + y * 13) % 5
				s.texture = ArcadeFx.tex(DARK, [16 + (v % 4) * 16, 128 + (v / 4) * 16, 16, 16])
			elif y == 1 and x > 0 and x < 15:
				s.texture = ArcadeFx.tex(DARK, [80 + (x % 4) * 16, 112, 16, 16])
			else:
				s.texture = ArcadeFx.tex(DARK, [16, 16, 16, 16])
				s.modulate = Color(0.45, 0.4, 0.55)
			deco.add_child(s)
	# The door lets a little village light in.
	ArcadeFx.breathe(ArcadeFx.glow(deco, Vector2(8, 10.5) * TILE, Color("ffd38a"), 34.0, 0.25), 0.7, 1.0, 2.4)
	# Haze over everything so the machines are the brightest things in the room.
	var haze := CPUParticles2D.new()
	haze.amount = 30
	haze.lifetime = 6.0
	haze.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	haze.emission_rect_extents = Vector2(120, 70)
	haze.position = Vector2(128, 96)
	haze.direction = Vector2.UP
	haze.spread = 40.0
	haze.initial_velocity_min = 2.0
	haze.initial_velocity_max = 6.0
	haze.gravity = Vector2.ZERO
	haze.scale_amount_min = 1.0
	haze.scale_amount_max = 1.0
	haze.color = Color(Palette.MUTED, 0.25)
	add_child(haze)


func _build_cabinet(i: int) -> void:
	var spot: Vector2i = SPOTS[i]
	var rect := Rect2i(spot, Vector2i(2, 3))
	var trim: Color = TRIM[i]
	# A pool of the cabinet's light on the floor, under everything.
	var pool := ArcadeFx.glow(props, Vector2((spot.x + 1) * TILE, (spot.y + 3.4) * TILE), trim, 40.0, 0.35)
	ArcadeFx.breathe(pool, 0.6, 1.0, 1.3 + i * 0.21)
	var cab := place(ArcadeFx.tex(CABINETS, [i * 32, 0, 32, 48]), rect)
	cab.name = "Cabinet_%s" % GAMES[i]
	cabinets.append(cab)
	block(Rect2i(spot.x, spot.y + 1, 2, 2))
	var screen := Node2D.new()
	screen.position = Vector2(0, -28)
	cab.add_child(screen)
	_attract(i, screen)
	# The game's sign glows on the wall above, flickering now and then.
	var marquee := Node2D.new()
	marquee.position = Vector2(0, -58)
	cab.add_child(marquee)
	ArcadeFx.breathe(ArcadeFx.glow(marquee, Vector2.ZERO, trim, 22.0, 0.55), 0.55, 1.0, 1.1 + i * 0.3)
	var pict := Sprite2D.new()
	pict.texture = _pictogram(i)
	marquee.add_child(pict)
	_flicker(marquee)
	add_interactable(
		# The cabinet's coin door: tap anywhere on the cabinet and the leader walks up to play.
		Vector2((spot.x + 1) * TILE, (spot.y + 3) * TILE - 8),
		func() -> String: return ["Mine", "Fishing", "Dungeon"][i],
		func() -> void: _play(i)
	)


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
	# The lantern's stand: one candle per flame left today.
	var base := Sprite2D.new()
	base.texture = ArcadeFx.tex(DUNGEON_SHEET, [80, 80, 16, 48])
	base.position = feet_at(STAND) + Vector2(TILE / 2.0, 0)
	base.offset = Vector2(0, -12)
	base.scale = Vector2(1, 0.5)
	props.add_child(base)
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
