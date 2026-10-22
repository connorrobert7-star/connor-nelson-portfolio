class_name ShrineLevel
extends Level
## The shrine: the flame altar (its fire is Faith), the devotion coins piled at its foot, the
## green ritual circle, the feeding cauldron with its food, the wardrobe chest, the Grave of
## Weeks, and the whole flock. No panels: everything is a thing you tap, drag or watch.

const W := 30
const H := 17
const ENTRANCE := Vector2i(15, 14)
const DOOR_TILES: Array[Vector2i] = [Vector2i(14, 16), Vector2i(15, 16)]

const HALLS := "res://art/packs/shattered-pixel-dungeon/environment/tiles_halls.png"
const WHIMSY := "res://art/packs/whimsy-hallow-dungeon/Whimsy_Hallow_Dungeon_Asset_Pack_V1.62.png"
const CANDLES := "res://art/packs/vk-candles-with-eyes/candles_with_eyes.png"
const CIRCLE_IDLE := "res://art/packs/srzolda-magic-summons/green_idle-Sheet.png"
const CIRCLE_SUMMON := "res://art/packs/srzolda-magic-summons/green_summon_Sheet.png"
const CHEST_SHUT := "res://art/packs/dcss-altars-features/dungeon/chest_2_closed.png"
const CHEST_OPEN := "res://art/packs/dcss-altars-features/dungeon/chest_2_open.png"
const KYRISE := "res://art/packs/kyrise-rpg-icons-16/spritesheet/spritesheet_16x16.png"
const FOG := "res://art/packs/ninja-adventure/FX/Environment/Fog.png"
const RAIN := "res://art/packs/ninja-adventure/FX/Particle/Rain.png"
const DECOR := "res://art/packs/dawnlike/Objects/Decor0.png"
const TOWN := "res://art/packs/kenney-tiny-town/Tilemap/tilemap_packed.png"
## DawnLike headstones (Decor0 row 17): plain, lined, skull.
const STONES: Array[Vector2i] = [Vector2i(3, 17), Vector2i(1, 17), Vector2i(2, 17)]

const ALTAR := Vector2(240, 92)
const CIRCLE := Vector2(240, 152)
const CAULDRON := Vector2(62, 196)
const CHEST := Vector2(62, 244)
const GRAVE := Rect2(396, 118, 76, 116)
const FLOCK_AREA := Rect2(108, 104, 264, 128)
const RISERS: Array[Rect2] = [Rect2(36, 50, 140, 30), Rect2(304, 50, 140, 30)]
const PLATES := {"gruel": Vector2(32, 116), "stew": Vector2(62, 104), "favorite": Vector2(92, 116)}

var flock: Flock
var music := AudioStreamPlayer.new()

var _altar := Sprite2D.new()
var _altar_glow: Sprite2D
var _altar_t := 0.0
var _flame_fps := 9.0
var _circle := Sprite2D.new()
var _circle_t := 0.0
var _circle_summon := -1.0
var _cauldron := Sprite2D.new()
var _cauldron_t := 0.0
var _coins := Node2D.new()
var _coin_ring_in := 0.0
var _plates: Dictionary = {}  # food id -> {node, sprite, price}
var _chest := Sprite2D.new()
var _chest_open := false
var _wardrobe := Node2D.new()
var _grave := Node2D.new()
var _candle_glows: Array[Sprite2D] = []
var _fog := Sprite2D.new()
var _rain := CPUParticles2D.new()
var _vignette := Sprite2D.new()
var _music_key := ""
var _entered := false


func _init() -> void:
	post_vignette = 0.0  # the shrine draws its own vignette
	var rows: Array[String] = []
	for y in H:
		if y < 3:
			rows.append("W".repeat(W))
		elif y == H - 1:
			rows.append("W".repeat(14) + "dd" + "W".repeat(W - 16))
		else:
			rows.append("W" + "f".repeat(W - 2) + "W")
	map = rows


## Arriving through any door (Room.ENTRANCE included) puts you just inside the shrine's door.
func setup(main_node: Node, spawn: Vector2i) -> void:
	super.setup(main_node, ENTRANCE if spawn == Room.ENTRANCE or spawn.y >= H - 1 else spawn)


func build() -> void:
	legend = {"W": 10, "f": 8, "d": 11}
	solid = "W"
	follow_camera = false
	ground.visible = false
	for t in DOOR_TILES:
		add_door(t, "village", Level.RETURN)
	_build_floor()
	_build_wall()
	_build_altar()
	_build_circle()
	_build_cauldron()
	_build_wardrobe()
	_build_grave()
	_build_atmosphere()
	flock = Flock.new("all", FLOCK_AREA)
	flock.shrine_point = CIRCLE + Vector2(0, -6)
	flock.riser_rects = RISERS
	flock.naming_wanted.connect(_on_naming_wanted)
	flock.refused.connect(_on_refused)
	_add_interests()
	props.add_child(flock)
	Game.event_fired.connect(_on_money_event)
	music.volume_db = -14.0
	music.bus = "Music"
	add_child(music)


# --- the room ---------------------------------------------------------------------------------------


func _halls_layer(cells: Array[Vector2i]) -> TileMapLayer:
	var src := TileSetAtlasSource.new()
	src.texture = FollowerArt.tex(HALLS)
	src.texture_region_size = Vector2i(TILE, TILE)
	for c in cells:
		src.create_tile(c)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	var layer := TileMapLayer.new()
	layer.tile_set = ts
	return layer


func _build_floor() -> void:
	var plain: Array[Vector2i] = [Vector2i(0, 0), Vector2i(6, 0), Vector2i(12, 0)]
	var veins: Array[Vector2i] = [Vector2i(1, 0), Vector2i(7, 0)]
	var embers: Array[Vector2i] = [Vector2i(2, 0), Vector2i(8, 0), Vector2i(3, 0)]
	var layer := _halls_layer(plain + veins + embers)
	layer.z_index = -10
	add_child(layer)
	move_child(layer, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6213
	for y in range(3, H):
		for x in W:
			var near := Vector2(x * TILE + 8, y * TILE + 8).distance_to(CIRCLE) < 70.0
			var r := rng.randf()
			var cell: Vector2i = plain[rng.randi() % plain.size()]
			if r < (0.16 if near else 0.04):
				cell = veins[rng.randi() % veins.size()]
			elif r < (0.24 if near else 0.06):
				cell = embers[rng.randi() % embers.size()]
			layer.set_cell(Vector2i(x, y), 0, cell)


func _build_wall() -> void:
	var plain: Array[Vector2i] = [Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(0, 6), Vector2i(2, 6)]
	var glass: Array[Vector2i] = [Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5)]
	var shelves: Array[Vector2i] = [Vector2i(12, 5), Vector2i(13, 5), Vector2i(14, 6), Vector2i(15, 6)]
	var layer := _halls_layer(plain + glass + shelves)
	layer.z_index = -9
	add_child(layer)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for x in W:
		layer.set_cell(Vector2i(x, 1), 0, plain[rng.randi() % plain.size()])
		var cell: Vector2i = plain[rng.randi() % plain.size()]
		if x in [4, 9, 20, 25]:
			cell = glass[rng.randi() % glass.size()]
		elif x in [1, 2, 27, 28]:
			cell = shelves[x % shelves.size()]
		layer.set_cell(Vector2i(x, 2), 0, cell)
	# Stained glass glows a little, like light is coming through from somewhere worse.
	for x in [4, 9, 20, 25]:
		var g := FollowerArt.glow(Color(Palette.PINK, 0.18), 22.0)
		g.position = Vector2(x * TILE + 8, 2 * TILE + 8)
		g.z_index = -8
		add_child(g)
		_candle_glows.append(g)
	# Skull pillars stand guard between the risers and the altar.
	for x in [186.0, 294.0]:
		var p := Sprite2D.new()
		p.texture = FollowerArt.region(HALLS, Rect2(8 * 16, 4 * 16, 16, 16))
		p.offset = Vector2(0, -8)
		p.scale = Vector2(2, 2)
		p.position = Vector2(x, 84)
		props.add_child(p)
		block(Rect2i(int(x / TILE) - 1, 4, 2, 2))


func _build_altar() -> void:
	_altar_glow = FollowerArt.glow(Color(Palette.GLOW, 0.5), 90.0)
	_altar_glow.position = ALTAR + Vector2(0, -34)
	_altar_glow.z_index = -5
	add_child(_altar_glow)
	_altar.texture = FollowerArt.altar(0)
	_altar.offset = Vector2(0, -16)
	_altar.scale = Vector2(2, 2)
	_altar.position = ALTAR
	props.add_child(_altar)
	block(Rect2i(13, 3, 4, 3))
	# Tall candlesticks and the eye on its stand flank the altar.
	for pair: Array in [[Vector2(200, 94), Rect2(3, 1, 14, 40)], [Vector2(280, 94), Rect2(128, 5, 16, 36)]]:
		_candle(pair[0], pair[1], true)
	_coins.position = ALTAR + Vector2(0, 6)
	props.add_child(_coins)


func _candle(at: Vector2, rect: Rect2, big := false) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = FollowerArt.region(CANDLES, rect)
	s.offset = Vector2(0, -rect.size.y / 2.0)
	s.position = at
	props.add_child(s)
	var g := FollowerArt.glow(Color(Palette.GLOW, 0.35 if big else 0.25), 26.0 if big else 16.0)
	g.position = at + Vector2(0, -rect.size.y + 4)
	g.z_index = 5
	add_child(g)
	_candle_glows.append(g)
	return s


func _build_circle() -> void:
	_circle.texture = FollowerArt.region(CIRCLE_IDLE, Rect2(0, 0, 64, 64))
	_circle.position = CIRCLE
	_circle.scale = Vector2(2, 1.25)
	_circle.z_index = -7
	_circle.modulate = Color(1, 1, 1, 0.55)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_circle.material = add
	add_child(_circle)
	# Small candles around the circle.
	for i in 6:
		var a := TAU * i / 6.0 + PI / 6.0
		_candle(CIRCLE + Vector2(cos(a) * 80.0, sin(a) * 44.0 + 8.0), Rect2(111, 15, 14, 26))


func _build_cauldron() -> void:
	var g := FollowerArt.glow(Color(Palette.BILE, 0.3), 46.0)
	g.position = CAULDRON + Vector2(0, -30)
	g.z_index = -4
	add_child(g)
	_cauldron.texture = FollowerArt.region(WHIMSY, Rect2(1136, 1026, 24, 38))
	_cauldron.offset = Vector2(0, -19)
	_cauldron.scale = Vector2(2, 2)
	_cauldron.position = CAULDRON
	props.add_child(_cauldron)
	block(Rect2i(2, 10, 4, 2))
	for food_id: String in PLATES:
		var holder := Node2D.new()
		holder.position = PLATES[food_id]
		holder.z_index = 20
		add_child(holder)
		var shine := FollowerArt.glow(Color(Palette.CREAM, 0.22), 12.0)
		holder.add_child(shine)
		var s := Sprite2D.new()
		holder.add_child(s)
		var price := FollowerArt.label("", FollowerArt.FONT_NUMBERS, 10, Palette.GLOW)
		price.position = Vector2(-12, 7)
		price.size = Vector2(24, 12)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		holder.add_child(price)
		_plates[food_id] = {"node": holder, "sprite": s, "price": price}


func _build_wardrobe() -> void:
	_chest.texture = FollowerArt.tex(CHEST_SHUT)
	_chest.offset = Vector2(0, -16)
	_chest.position = CHEST
	props.add_child(_chest)
	block(Rect2i(3, 14, 2, 1))
	_wardrobe.position = CHEST + Vector2(0, -28)
	_wardrobe.z_index = 25
	add_child(_wardrobe)


func _build_grave() -> void:
	var dirt := FollowerArt.glow(Color(0.25, 0.1, 0.18, 0.5), 52.0, FollowerArt.SOFT)
	dirt.position = GRAVE.get_center()
	dirt.scale.y *= 1.4
	dirt.z_index = -6
	add_child(dirt)
	add_child(_grave)
	_grave.z_index = 0
	# A heap of bones and a bare candle: the plot is waiting.
	var bones := Sprite2D.new()
	bones.texture = FollowerArt.region(HALLS, Rect2(0, 8 * 16, 16, 16))
	bones.position = Vector2(GRAVE.end.x - 8, GRAVE.end.y - 4)
	bones.offset = Vector2(0, -8)
	props.add_child(bones)


func _build_atmosphere() -> void:
	_fog.texture = FollowerArt.tex(FOG)
	_fog.centered = false
	_fog.scale = Vector2(1.6, 1.6)
	_fog.modulate = Color(0.55, 0.45, 0.7, 0.05)
	_fog.z_index = 150
	add_child(_fog)
	_rain.texture = FollowerArt.region(RAIN, Rect2(16, 0, 8, 8))
	_rain.amount = 90
	_rain.lifetime = 1.2
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.emission_rect_extents = Vector2(260, 4)
	_rain.position = Vector2(240, -6)
	_rain.direction = Vector2(0.15, 1)
	_rain.spread = 4.0
	_rain.gravity = Vector2(0, 0)
	_rain.initial_velocity_min = 200.0
	_rain.initial_velocity_max = 260.0
	_rain.color = Color(0.7, 0.72, 0.8, 0.5)
	_rain.z_index = 160
	_rain.emitting = false
	add_child(_rain)
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(Palette.NIGHT, 0.85))
	grad.add_point(0.55, Color(0, 0, 0, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 240
	tex.height = 136
	_vignette.texture = tex
	_vignette.centered = false
	_vignette.scale = Vector2(2, 2)
	_vignette.z_index = 170
	add_child(_vignette)


func _add_interests() -> void:
	flock.add_interest("candles", Vector2(200, 60))
	flock.add_interest("candles", Vector2(280, 60))
	flock.add_interest("skulls", Vector2(186, 70))
	flock.add_interest("skulls", Vector2(294, 70))
	flock.add_interest("shiny", ALTAR)
	flock.add_interest("bones", Vector2(GRAVE.end.x - 8, GRAVE.end.y - 8))
	flock.add_interest("plants", GRAVE.get_center())


# --- state ------------------------------------------------------------------------------------------


func dress() -> void:
	var f: Dictionary = Game.state.get("followers", {})
	if f.is_empty():
		return
	var band := str(f.faith.band)
	var mourning := bool(f.get("mourning", false)) or band == "mourning"
	var bands: Dictionary = f.get("bands", {})
	_flame_fps = float(bands.get(band, {}).get("flame_fps", 9))
	var glow := float(f.faith.glow)
	_altar.modulate = Color(0.55, 0.5, 0.65) if mourning else Color.WHITE
	_altar_glow.modulate = Color(Palette.GLOW, 0.12 + glow * 0.5)
	_altar_glow.scale = Vector2.ONE * ((50.0 + glow * 70.0) * 2.0 / 128.0)
	_circle.modulate = Color(0.6, 0.6, 0.7, 0.25) if mourning else Color(1, 1, 1, 0.3 + glow * 0.4)
	_rain.emitting = mourning
	_fog.modulate.a = 0.1 if mourning else 0.04
	_dress_coins(f.get("devotion", {}))
	_dress_plates(f.get("foods", []))
	_dress_grave(f.get("graves", []), f.get("mourning_week"))
	if _chest_open:
		_fill_wardrobe(f.get("wearables", []))
	_dress_music(mourning, band)
	if not _entered:
		_entered = true
		_on_enter(mourning)


func _on_enter(mourning: bool) -> void:
	if mourning:
		FollowerArt.play("toll", 0.9, -4.0)
		FollowerArt.play("dirge", 1.0, -8.0)
	else:
		FollowerArt.play("bell", 1.0, -8.0)
	# Anything still waiting from while you were out plays here.
	var feature := FollowersFeature.instance
	if feature:
		feature.play_away_now.call_deferred(main)


func _dress_music(mourning: bool, band: String) -> void:
	var key := "mourning_bed" if mourning else "shrine_bed"
	music.pitch_scale = 0.94 if band == "doubting" else 1.0
	if key == _music_key:
		return
	_music_key = key
	var stream := load(str(FollowerArt.AUDIO[key])) as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	music.stream = stream
	music.volume_db = -30.0
	music.play()
	create_tween().tween_property(music, "volume_db", -14.0, 1.5)


## The devotion pile: brass coins heaped at the altar's foot, one per 3 devotion, in rows of
## 9, 7, 5, 3 and 1. At the day's cap a brass ring pulses around it.
func _dress_coins(devotion: Dictionary) -> void:
	for c in _coins.get_children():
		c.queue_free()
	var amount := int(devotion.get("amount", 0))
	var n := mini(25, ceili(amount / 3.0))
	var rows := [9, 7, 5, 3, 1]
	var i := 0
	for r in rows.size():
		for k in rows[r]:
			if i >= n:
				break
			var s := Sprite2D.new()
			s.position = Vector2((k - (rows[r] - 1) / 2.0) * 5.0, -r * 3.0)
			s.texture = FollowerArt.coin(i * 3)
			s.set_meta("phase", i * 3)
			_coins.add_child(s)
			i += 1
	_coin_ring_in = 0.0 if amount >= int(devotion.get("daily_cap", 60)) else -1.0


func _dress_plates(foods: Array) -> void:
	var coins := int(Game.state.get("coins", 0))
	for food: Dictionary in foods:
		var plate: Dictionary = _plates.get(str(food.id), {})
		if plate.is_empty():
			continue
		(plate.sprite as Sprite2D).texture = FollowerArt.icon(food.get("icon", {}))
		(plate.price as Label).text = str(int(food.price))
		var can := coins >= int(food.price)
		(plate.node as Node2D).modulate = Color.WHITE if can else Color(0.5, 0.45, 0.55, 0.8)
		plate.food = food


## The Grave of Weeks: a headstone for every missed week with its date cut in, a candle that
## never goes out, and a flower once money landed after it. No stones yet: an open plot.
func _dress_grave(graves: Array, mourning_week: Variant) -> void:
	for c in _grave.get_children():
		c.queue_free()
	if graves.is_empty():
		var scythe := Sprite2D.new()
		scythe.texture = FollowerArt.region(TOWN, Rect2(9 * 16, 10 * 16, 16, 16))
		scythe.offset = Vector2(0, -8)
		scythe.rotation = 0.35
		scythe.position = GRAVE.get_center() + Vector2(10, 18)
		_grave.add_child(scythe)
		var stub := Sprite2D.new()
		stub.texture = FollowerArt.region(CANDLES, Rect2(111, 15, 14, 26))
		stub.offset = Vector2(0, -13)
		stub.modulate = Color(0.55, 0.5, 0.6)
		stub.position = GRAVE.get_center() + Vector2(-14, 22)
		_grave.add_child(stub)
		return
	var newest: Array = graves.duplicate()
	newest.reverse()
	for i in mini(newest.size(), 9):
		var g: Dictionary = newest[i]
		var col := i % 3
		var row := i / 3
		var at := Vector2(GRAVE.position.x + 14 + col * 26 + (row % 2) * 6, GRAVE.end.y - 6 - row * 34)
		var fresh: bool = mourning_week is Dictionary and str(mourning_week.get("week_start", "")) == str(g.week_start)
		var stone := Sprite2D.new()
		var cell: Vector2i = STONES[i % STONES.size()]
		stone.texture = FollowerArt.region(DECOR, Rect2(cell.x * 16, cell.y * 16, 16, 16))
		stone.offset = Vector2(0, -8)
		stone.scale = Vector2(2, 2)
		stone.position = at
		_grave.add_child(stone)
		var date := FollowerArt.label(_short_day(str(g.week_start)), FollowerArt.FONT_TINY, 8, Palette.CREAM if fresh else Palette.MUTED)
		date.position = at + Vector2(-16, -20)
		date.size = Vector2(32, 8)
		date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_grave.add_child(date)
		var candle := Sprite2D.new()
		candle.texture = FollowerArt.region(CANDLES, Rect2(111, 15, 14, 26))
		candle.offset = Vector2(0, -13)
		candle.scale = Vector2(0.75, 0.75)
		candle.position = at + Vector2(12, 2)
		_grave.add_child(candle)
		var flame := FollowerArt.glow(Color(Palette.GLOW, 0.55 if fresh else 0.35), 14.0 if fresh else 9.0)
		flame.position = candle.position + Vector2(0, -18)
		_grave.add_child(flame)
		_candle_glows.append(flame)
		if bool(g.get("flower", false)):
			var flower := Sprite2D.new()
			flower.texture = FollowerArt.region(KYRISE, Rect2((1 + i % 2) * 16, 9 * 16, 16, 16))
			flower.offset = Vector2(0, -8)
			flower.position = at + Vector2(-12, 3)
			_grave.add_child(flower)
		if fresh:
			FlockFx.pop_in(stone, Vector2(2, 2))


static func _short_day(iso: String) -> String:
	const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var p := iso.split("-")
	if p.size() < 3:
		return iso
	return "%s %d" % [MONTHS[int(p[1]) - 1], int(p[2])]


# --- the living room ----------------------------------------------------------------------------------


func _process(delta: float) -> void:
	super._process(delta)
	_altar_t += delta
	_altar.texture = FollowerArt.altar(int(_altar_t * _flame_fps))
	_circle_t += delta
	if _circle_summon >= 0.0:
		_circle_summon += delta
		var f := int(_circle_summon * 18.0)
		if f >= 31:
			_circle_summon = -1.0
		else:
			_circle.texture = FollowerArt.region(CIRCLE_SUMMON, Rect2(f * 64, 0, 64, 64))
	else:
		_circle.texture = FollowerArt.region(CIRCLE_IDLE, Rect2((int(_circle_t * 10.0) % 43) * 64, 0, 64, 64))
	_cauldron_t += delta
	_cauldron.texture = FollowerArt.region(WHIMSY, Rect2(1136 + (int(_cauldron_t * 7.0) % 6) * 32, 1026, 24, 38))
	for food_id: String in _plates:
		var node: Node2D = _plates[food_id].node
		node.position.y = (PLATES[food_id] as Vector2).y + sin(_cauldron_t * 2.2 + node.position.x) * 2.0
	for c: Node in _coins.get_children():
		var s := c as Sprite2D
		s.texture = FollowerArt.coin(int(_altar_t * 12.0) + int(s.get_meta("phase", 0)))
	if _coin_ring_in >= 0.0:
		_coin_ring_in -= delta
		if _coin_ring_in <= 0.0:
			_coin_ring_in = 2.0
			FlockFx.ring(self, _coins.position + Vector2(0, -2), Palette.GLOW, 22.0, 0.9)
	for i in _candle_glows.size():
		var g := _candle_glows[i]
		if is_instance_valid(g):
			g.modulate.a = clampf(g.modulate.a + randf_range(-0.03, 0.03), 0.12, 0.6)
	_fog.position = Vector2(-16.0 + sin(_altar_t * 0.07) * 16.0, -8.0 + cos(_altar_t * 0.05) * 6.0)


func _unhandled_input(event: InputEvent) -> void:
	if Game.busy or not Level._is_tap(event) or flock.carrying():
		super._unhandled_input(event)
		return
	var p := (make_input_local(event) as InputEventMouseButton).position if event is InputEventMouseButton else (make_input_local(event) as InputEventScreenTouch).position
	# The food over the cauldron: press to pick it up.
	for food_id: String in _plates:
		var plate: Dictionary = _plates[food_id]
		if plate.has("food") and (plate.node as Node2D).position.distance_to(p) < 11.0:
			get_viewport().set_input_as_handled()
			_pick_food(plate)
			return
	# The wardrobe's spilled clothes.
	for item_node: Node in _wardrobe.get_children():
		var n := item_node as Node2D
		if n.has_meta("item") and (_wardrobe.position + n.position).distance_to(p) < 10.0:
			get_viewport().set_input_as_handled()
			flock.carry("item", n.get_meta("item"), (n.get_child(1) as Sprite2D).texture, _wardrobe.position + n.position)
			return
	if Rect2(CHEST - Vector2(16, 30), Vector2(32, 32)).has_point(p):
		get_viewport().set_input_as_handled()
		_toggle_wardrobe()
		return
	if Rect2(ALTAR - Vector2(34, 66), Vector2(68, 74)).has_point(p):
		get_viewport().set_input_as_handled()
		_collect()
		return
	if GRAVE.has_point(p) and not _grave.get_children().is_empty():
		get_viewport().set_input_as_handled()
		FollowerArt.play("toll", randf_range(0.9, 1.05), -8.0)
		for g in _candle_glows:
			if is_instance_valid(g) and g.get_parent() == _grave:
				g.modulate.a = 0.9
		return
	if CAULDRON.distance_to(p) < 16.0:
		get_viewport().set_input_as_handled()
		FollowerArt.play("bubble", randf_range(0.8, 1.2), -8.0)
		FlockFx.burst(self, CAULDRON + Vector2(0, -26), Palette.BILE, 8, 40.0, 0.5, 60.0)
		return
	super._unhandled_input(event)


func _pick_food(plate: Dictionary) -> void:
	var food: Dictionary = plate.food
	if int(Game.state.get("coins", 0)) < int(food.price):
		# Not enough coins: the price shakes and flashes. Coins come from play.
		var price: Label = plate.price
		FollowerArt.play("no", 1.0, -10.0)
		var tw := price.create_tween()
		for i in 3:
			tw.tween_property(price, "position:x", -10.0, 0.04)
			tw.tween_property(price, "position:x", -14.0, 0.04)
		tw.tween_property(price, "position:x", -12.0, 0.04)
		price.modulate = Color(2, 0.6, 0.6)
		tw.tween_property(price, "modulate", Color.WHITE, 0.3)
		return
	var node: Node2D = plate.node
	flock.carry("food", food, (plate.sprite as Sprite2D).texture, node.position)


func _toggle_wardrobe() -> void:
	_chest_open = not _chest_open
	_chest.texture = FollowerArt.tex(CHEST_OPEN if _chest_open else CHEST_SHUT)
	FollowerArt.play("chest", 1.0 if _chest_open else 0.8, -6.0)
	var tw := create_tween()
	tw.tween_property(_chest, "scale", Vector2(1.15, 0.85), 0.05)
	tw.tween_property(_chest, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if _chest_open:
		_fill_wardrobe(Game.state.get("followers", {}).get("wearables", []))
	else:
		for c in _wardrobe.get_children():
			var n := c as Node2D
			var back := n.create_tween()
			back.tween_property(n, "position", Vector2(0, 20), 0.15).set_ease(Tween.EASE_IN)
			back.parallel().tween_property(n, "scale", Vector2.ZERO, 0.15)
			back.tween_callback(n.queue_free)


## The chest spills what the owner has won: anything with a hat, cloak, aura or skin slot.
func _fill_wardrobe(wearables: Array) -> void:
	for c in _wardrobe.get_children():
		c.queue_free()
	if wearables.is_empty():
		FlockFx.puff(self, CHEST + Vector2(0, -24), Palette.MUTED)
		FlockFx.specks(self, CHEST + Vector2(0, -24), FollowerArt.SPECK_WOOL, 2, 6.0, Palette.MUTED)
		return
	var n := mini(wearables.size(), 9)
	for i in n:
		var item: Dictionary = wearables[i]
		var holder := Node2D.new()
		holder.set_meta("item", item)
		var a := lerpf(-PI * 0.95, -PI * 0.05, (i + 0.5) / n) if n > 1 else -PI / 2.0
		var target := Vector2(cos(a) * 34.0 + 18.0, sin(a) * 24.0)
		var tier_color: Color = Palette.RARITY.get(str(item.get("tier", "common")), Palette.COMMON)
		var g := FollowerArt.glow(Color(tier_color, 0.55), 11.0)
		holder.add_child(g)
		var s := Sprite2D.new()
		s.texture = FollowerArt.icon(item.get("icon", {}))
		holder.add_child(s)
		if not (item.get("worn_by", []) as Array).is_empty():
			s.modulate = Color(1, 1, 1, 0.55)
		_wardrobe.add_child(holder)
		var tw := holder.create_tween()
		tw.tween_interval(i * 0.04)
		tw.tween_property(holder, "position", target, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		FlockFx.pop_in(holder)


## Tap the altar: the devotion your loyal flock piled up flies to you as coins.
func _collect() -> void:
	var amount := int(Game.state.get("followers", {}).get("devotion", {}).get("amount", 0))
	var tw := create_tween()
	tw.tween_property(_altar, "scale", Vector2(2.2, 1.8), 0.05)
	tw.tween_property(_altar, "scale", Vector2(2, 2), 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if amount <= 0:
		FollowerArt.play("bell", 0.7, -12.0)
		return
	var coins := _coins.get_children()
	for i in coins.size():
		var s := coins[i] as Sprite2D
		var from := _coins.position + s.position
		var to := leader.position + Vector2(0, -16)
		var mid := (from + to) / 2.0 + Vector2(randf_range(-30, 30), -40)
		s.reparent(self)
		s.position = from
		s.z_index = 90
		var t := s.create_tween()
		t.tween_interval(i * 0.025)
		t.tween_method(func(k: float) -> void:
			if is_instance_valid(s):
				s.position = from.lerp(mid, k).lerp(mid.lerp(to, k), k), 0.0, 1.0, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		t.tween_callback(func() -> void:
			FollowerArt.play("coin", 1.0 + minf(1.0, i / 12.0), -10.0))
		t.tween_callback(s.queue_free)
	await get_tree().create_timer(0.25 + coins.size() * 0.025).timeout
	await Game.act("/followers/collect")


func _on_naming_wanted(_body: FollowerBody) -> void:
	var p: Dictionary = Game.state.get("followers", {}).get("personal", {})
	var names: Array = p.get("offered_names", [])
	if names.is_empty() or Game.busy:
		return
	await main.open_overlay(NamingOverlay.new(names, int(p.get("stage", 1))))


func _on_refused(_body: FollowerBody, reason: String) -> void:
	if reason == "coins":
		for food_id: String in _plates:
			var price: Label = _plates[food_id].price
			price.modulate = Color(2, 0.6, 0.6)
			price.create_tween().tween_property(price, "modulate", Color.WHITE, 0.4)


## Money landed: the circle flares into its summoning animation, the fire leaps, motes
## stream in from the door to the altar.
func _on_money_event(e: Dictionary) -> void:
	if str(e.get("kind", "")) == "money_moved" and Flock.lands(e):
		flare_circle()


func flare_circle() -> void:
	_circle_summon = 0.0
	var tw := create_tween()
	tw.tween_property(_altar, "scale", Vector2(2.4, 2.9), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_altar, "scale", Vector2(2, 2), 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var glow := create_tween()
	glow.tween_property(_altar_glow, "modulate:a", 0.95, 0.1)
	glow.tween_property(_altar_glow, "modulate:a", 0.6, 1.2)
	FlockFx.motes(self, Vector2(240, 262), ALTAR + Vector2(0, -30), 28, 0.7)
	FlockFx.ring(self, CIRCLE, Palette.CREAM, 70.0, 0.7)
