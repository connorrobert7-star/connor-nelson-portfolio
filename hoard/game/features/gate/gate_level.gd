class_name GateLevel
extends Level
## The gate at the edge of the village. Every debt is a boss outside it, smallest in
## front. HP is the real balance, painted on each boss's bar. Tap a boss, press and hold
## a stack of bone-white discs, and the payment goes through the gate as a strike that
## does exactly its dollars of damage. Interest heals a boss once a month, in the open.
## The bank's own payments play as auto-attacks when you come back. Paid off: it dies and
## drops a cosmetic only it carries. Everything here is drawn from Game.state and the
## API's answers; the backend does all the money.

enum Mode { IDLE, AIM, CHARGE, STRIKE, SCENE }

const COLS := 30
const ROWS := 17
const SPAWN := Vector2i(14, 15)
const GATE_SPOT := Vector2(240, 212)  # where the leader stands to pay
const GATE_MOUTH := Vector2(240, 172)
const STACKS_AT := Vector2(240, 250)
const WALL_Y := 160.0
const SLOTS: Array[Vector2] = [
	Vector2(240, 156), Vector2(86, 134), Vector2(394, 134), Vector2(164, 108), Vector2(316, 108),
]
const HOLD_SECONDS := 0.45

const X72 := "res://art/packs/0x72-dungeontileset-ii/0x72_DungeonTilesetII_v1.7/0x72_DungeonTilesetII_v1.7.png"
const HALLS := "res://art/packs/shattered-pixel-dungeon/environment/tiles_halls.png"
const CULTIST := "res://art/villager.png"
const CANDLES := "res://art/packs/vk-candles-with-eyes/candles_with_eyes.png"
const MUSIC_GATE := "res://art/packs/ninja-adventure/Audio/Music/14 - Curse.ogg"
const MUSIC_FIGHT := "res://art/packs/shattered-pixel-dungeon/music/city_boss.ogg"
const MUSIC_FINALE := "res://art/packs/shattered-pixel-dungeon/music/city_boss_finale.ogg"
const HEARTBEAT := "res://art/packs/bart-heartbeat-sounds/heartbeat_slow_0.ogg"
const CHAINS := "res://art/packs/shattered-pixel-dungeon/sounds/chains.mp3"

var _mode := Mode.IDLE
## What is playing right now (intro, heal, bank_hit, strike, death, drop), for the tour.
var beat := ""
var _bosses: Dictionary = {}  # debt_id -> GateBoss
var _target: GateBoss
var _stacks: GateStacks
var _charge := 0.0
var _charge_i := -1
var _arena := Node2D.new()
var _fx := Node2D.new()
var _flock := Node2D.new()
var _trophies := Node2D.new()
var _leaf := Sprite2D.new()
var _gate_lift := 0.0
var _gate_lamps: Array[Sprite2D] = []
var _fountains: Array[Sprite2D] = []
var _cultists: Array[Sprite2D] = []
var _music := AudioStreamPlayer.new()
var _beat := AudioStreamPlayer.new()
var _music_path := ""
var _t := 0.0
var _roar_in := 4.0
var _idle_for := 0.0
var _hinted_boss := false
var _hinted_stack := false
var _boss_hand: Sprite2D
var _beats_running := false
var _intro_done := false
## Beats already played this session, kept across visits so walking out and back in
## before the next /state can't replay one.
static var _played_heals: Dictionary = {}
static var _played_hits: Dictionary = {}
static var _played_kills: Dictionary = {}
var _rng := RandomNumberGenerator.new()
static var _met: Dictionary = {}


func setup(main_node: Node, _spawn_tile: Vector2i) -> void:
	# Every way in (the village door, the tour) arrives at the bottom, by the road home.
	super.setup(main_node, SPAWN)


func build() -> void:
	var rows: Array[String] = []
	for y in ROWS:
		if y >= 12 and y <= 15:
			rows.append("X" + ".".repeat(COLS - 2) + "X")
		elif y == 16:
			rows.append("X".repeat(14) + ".." + "X".repeat(COLS - 16))
		else:
			rows.append("X".repeat(COLS))
	map = rows
	legend = {"X": 9, ".": 8}
	solid = "X"
	follow_camera = false
	ground.visible = false
	props.z_index = 10
	add_door(Vector2i(14, 16), "village", Level.RETURN)
	add_door(Vector2i(15, 16), "village", Level.RETURN)
	_rng.seed = 7041
	_build_sky()
	_build_field()
	_build_wall()
	_build_floor()
	_arena.y_sort_enabled = true
	add_child(_arena)
	_trophies.z_index = 7
	add_child(_trophies)
	_build_flock()
	_build_darkness()
	_fx.z_index = 50
	add_child(_fx)
	add_child(_music)
	_beat.stream = load(HEARTBEAT)
	_beat.volume_db = -4.0
	add_child(_beat)
	_play_music(MUSIC_GATE, -12.0)


# --- the place ---------------------------------------------------------------------

func _layer(sheet: String, z: int) -> TileMapLayer:
	var tex: Texture2D = load(sheet)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	var layer := TileMapLayer.new()
	layer.tile_set = ts
	layer.z_index = z
	add_child(layer)
	return layer


func _put(layer: TileMapLayer, cell: Vector2i, atlas: Vector2i) -> void:
	var src := layer.tile_set.get_source(0) as TileSetAtlasSource
	if not src.has_tile(atlas):
		src.create_tile(atlas)
	layer.set_cell(cell, 0, atlas)


func _sprite(sheet: String, region: Rect2, pos: Vector2, z := 0, parent: Node = null) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(sheet)
	s.region_enabled = true
	s.region_rect = region
	s.centered = false
	s.position = pos
	s.z_index = z
	(parent if parent else self).add_child(s)
	return s


func _build_sky() -> void:
	var g := Gradient.new()
	g.set_color(0, Color("07040b"))
	g.set_color(1, Color("2a1236"))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 64
	var sky := Sprite2D.new()
	sky.texture = gt
	sky.centered = false
	sky.scale = Vector2(COLS * TILE / 8.0 + 8, 1.2)
	sky.position = Vector2(-20, -10)
	sky.z_index = -40
	add_child(sky)
	for i in 34:
		var star := ColorRect.new()
		star.color = Palette.CREAM if i % 5 else Palette.MUTED
		star.size = Vector2.ONE * (2 if i % 9 == 0 else 1)
		star.position = Vector2(_rng.randf_range(0, 480), _rng.randf_range(2, 54))
		star.z_index = -39
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(star)
		var tw := star.create_tween().set_loops()
		tw.tween_property(star, "modulate:a", 0.15, _rng.randf_range(0.6, 2.2))
		tw.tween_property(star, "modulate:a", 1.0, _rng.randf_range(0.6, 2.2))
	# A pale moon, low and sick, behind the field.
	var moon := GateFx.glow(Color(0.85, 0.9, 0.7, 0.55), 26, -38)
	moon.position = Vector2(388, 30)
	add_child(moon)
	var disc := Sprite2D.new()
	disc.texture = GateFx.disc(6, Color("d9dcc4"))
	disc.position = Vector2(388, 30)
	disc.z_index = -37
	add_child(disc)


func _build_field() -> void:
	var field := _layer(HALLS, -30)
	var plain := [Vector2i(0, 0), Vector2i(6, 0)]
	var marked := [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(7, 0), Vector2i(8, 0), Vector2i(9, 0)]
	field.modulate = Color(0.78, 0.7, 0.82)
	for y in range(3, 10):
		for x in COLS:
			var cell: Vector2i = marked[_rng.randi() % marked.size()] if _rng.randf() < 0.14 else plain[_rng.randi() % plain.size()]
			_put(field, Vector2i(x, y), cell)
	# Distance: the field fades into the night toward the horizon.
	var g := Gradient.new()
	g.set_color(0, Color(Palette.NIGHT, 1.0))
	g.set_color(1, Color(Palette.NIGHT, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 64
	var fade := Sprite2D.new()
	fade.texture = gt
	fade.centered = false
	fade.position = Vector2(-20, 44)
	fade.scale = Vector2(65, 1.3)
	fade.z_index = -29
	add_child(fade)
	# Skull piles and bones scattered on the field.
	for spot: Vector2 in [Vector2(20, 120), Vector2(440, 112), Vector2(150, 76), Vector2(332, 70), Vector2(30, 70), Vector2(458, 140)]:
		var r := Rect2(Vector2(8 + _rng.randi() % 2, 4) * TILE, Vector2(TILE, TILE)) if _rng.randf() < 0.6 else Rect2(Vector2(_rng.randi() % 2, 8) * TILE, Vector2(TILE, TILE))
		var s := _sprite(HALLS, r, spot, -28)
		s.modulate = Color(0.7, 0.65, 0.75)
	# Low fog drifting across.
	for i in 5:
		var fog := GateFx.glow(Color(0.42, 0.3, 0.5, 0.22), 90, -27)
		fog.position = Vector2(_rng.randf_range(0, 480), _rng.randf_range(70, 150))
		fog.scale.y *= 0.35
		add_child(fog)
		var tw := fog.create_tween().set_loops()
		var dx := _rng.randf_range(40, 90)
		tw.tween_property(fog, "position:x", fog.position.x + dx, _rng.randf_range(7, 12)).set_trans(Tween.TRANS_SINE)
		tw.tween_property(fog, "position:x", fog.position.x, _rng.randf_range(7, 12)).set_trans(Tween.TRANS_SINE)
	# Embers and ash rising off the field.
	var embers := CPUParticles2D.new()
	embers.amount = 40
	embers.lifetime = 6.0
	embers.preprocess = 6.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(240, 30)
	embers.position = Vector2(240, 150)
	embers.direction = Vector2.UP
	embers.spread = 20.0
	embers.gravity = Vector2(4, -6)
	embers.initial_velocity_min = 4.0
	embers.initial_velocity_max = 14.0
	embers.color = Color(0.85, 0.75, 0.9, 0.55)
	embers.z_index = 26
	add_child(embers)


func _build_wall() -> void:
	var wall := _layer(X72, 2)
	var top_row := int(WALL_Y / TILE)
	for x in COLS:
		_put(wall, Vector2i(x, top_row), Vector2i(2, 0))
		_put(wall, Vector2i(x, top_row + 1), Vector2i(2, 1))
	# Banners and the two lava fountains on the wall face.
	for x: int in [3, 11, 18, 26]:
		var banner := Vector2i(1, 3) if x % 2 == 1 else Vector2i(2, 2)
		_put(wall, Vector2i(x, top_row + 1), banner)
	for x: int in [8, 21]:
		_sprite(X72, Rect2(64, 0, 16, 16), Vector2(x * TILE, WALL_Y), 3)
		var mid := _sprite(X72, Rect2(64, 16, 16, 16), Vector2(x * TILE, WALL_Y + TILE), 3)
		var basin := _sprite(X72, Rect2(64, 32, 16, 16), Vector2(x * TILE, WALL_Y + 2 * TILE), 3)
		_fountains.append(mid)
		_fountains.append(basin)
		var glow := GateFx.glow(Color(1.0, 0.45, 0.2, 0.5), 30, 4)
		glow.position = Vector2(x * TILE + 8, WALL_Y + 24)
		add_child(glow)
		var tw := glow.create_tween().set_loops()
		tw.tween_property(glow, "modulate:a", 0.3, 0.35 + x * 0.01)
		tw.tween_property(glow, "modulate:a", 0.55, 0.3)
	# The gatehouse: a dark doorway, the leaf that lifts, the frame around it.
	var gx := 224.0
	var mouth := GateFx.glow(Color(0.6, 0.45, 0.75, 0.0), 26, 3)
	mouth.position = Vector2(240, WALL_Y + 16)
	mouth.name = "Mouth"
	add_child(mouth)
	_sprite(X72, Rect2(80, 240, 32, 32), Vector2(gx, WALL_Y), 3)
	_leaf = _sprite(X72, Rect2(32, 240, 32, 32), Vector2(gx, WALL_Y), 4)
	_sprite(X72, Rect2(16, 240, 16, 32), Vector2(gx - 16, WALL_Y), 5)
	_sprite(X72, Rect2(64, 240, 16, 32), Vector2(gx + 32, WALL_Y), 5)
	_sprite(X72, Rect2(32, 224, 32, 16), Vector2(gx, WALL_Y - 16), 5)


func _build_floor() -> void:
	var floor_layer := _layer(X72, -10)
	var cells := [Vector2i(1, 4), Vector2i(1, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(1, 6), Vector2i(2, 6)]
	for y in range(12, ROWS):
		for x in COLS:
			_put(floor_layer, Vector2i(x, y), cells[_rng.randi() % cells.size()])
	floor_layer.modulate = Color(0.62, 0.56, 0.68)
	# The lit path home, down to the village.
	for y in range(13, ROWS):
		var light := GateFx.glow(Color(0.7, 0.55, 0.45, 0.22), 18, -9)
		light.position = Vector2(240, y * TILE + 8)
		add_child(light)
	var spot := GateFx.glow(Color(0.85, 0.75, 0.95, 0.35), 70, -9)
	spot.position = Vector2(240, 228)
	add_child(spot)


## The cult lines the battlements and chants when a payment goes through. Decoration
## until the flock (Step 3) can stand here instead.
func _build_flock() -> void:
	_flock.z_index = 11
	_flock.y_sort_enabled = true
	add_child(_flock)
	var tex: Texture2D = load(CULTIST)
	var spots: Array[Vector2] = [
		Vector2(56, 222), Vector2(92, 236), Vector2(128, 222), Vector2(40, 256), Vector2(76, 266), Vector2(116, 258),
	]
	for side in 2:
		for spot: Vector2 in spots:
			var s := Sprite2D.new()
			s.texture = tex
			s.hframes = 2
			s.scale = Vector2(2, 2)
			s.offset = Vector2(0, -8)
			s.position = spot if side == 0 else Vector2(480 - spot.x, spot.y)
			s.flip_h = side == 1
			s.modulate = Color(0.82, 0.76, 0.88)
			s.set_meta("base_y", s.position.y)
			_flock.add_child(s)
			_cultists.append(s)
	# Candles with eyes along the road home, and the eye on its stand by the gate.
	for spot: Vector2 in [Vector2(196, 214), Vector2(284, 214), Vector2(16, 214), Vector2(464, 214)]:
		var col := 1 if spot.x < 240 else 2
		_candle(Rect2(col * 18, 0, 18, 41), spot)
	_candle(Rect2(126, 0, 18, 41), Vector2(170, 204))
	_candle(Rect2(126, 0, 18, 41), Vector2(310, 204))


func _candle(region: Rect2, feet: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = load(CANDLES)
	s.region_enabled = true
	s.region_rect = region
	s.offset = Vector2(0, -region.size.y / 2.0)
	s.position = feet
	_flock.add_child(s)
	var flame := GateFx.glow(Color(1.0, 0.7, 0.35, 0.55), 16, 1)
	flame.position = feet + Vector2(0, -region.size.y + 4)
	add_child(flame)
	flame.z_index = 12
	if absf(feet.x - 240.0) < 60.0:
		_gate_lamps.append(flame)  # the gate's lamps

	var tw := flame.create_tween().set_loops()
	tw.tween_property(flame, "modulate:a", 0.3, randf_range(0.12, 0.3))
	tw.tween_property(flame, "modulate:a", 0.6, randf_range(0.12, 0.3))


func _build_darkness() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(Palette.NIGHT, 0.0))
	g.set_color(1, Color(Palette.NIGHT, 0.88))
	g.add_point(0.55, Color(Palette.NIGHT, 0.15))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.55)
	gt.fill_to = Vector2(1.05, 0.55)
	gt.width = 120
	gt.height = 68
	var dark := Sprite2D.new()
	dark.texture = gt
	dark.centered = false
	dark.scale = Vector2(4.2, 4.2)
	dark.position = Vector2(-12, -8)
	dark.z_index = 25
	add_child(dark)


func _play_music(path: String, db: float) -> void:
	if _music_path == path:
		return
	_music_path = path
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = path != MUSIC_FINALE
	_music.stream = stream
	_music.volume_db = db
	_music.play()


# --- state --------------------------------------------------------------------------

func bosses_state() -> Array:
	return Game.state.get("gate", {}).get("bosses", [])


func boss_node(debt_id: String) -> GateBoss:
	return _bosses.get(debt_id)


func front_boss() -> GateBoss:
	for b: Dictionary in _standing():
		return _bosses.get(str(b.debt_id))
	return null


func mode() -> int:
	return _mode


func stacks() -> GateStacks:
	return _stacks


## Bosses still standing: alive ones, and ones paid off while you were away whose death
## hasn't played yet. Smallest first.
func _standing() -> Array:
	var out := bosses_state().filter(func(b: Dictionary) -> bool:
		if not bool(b.defeated):
			return true
		var kill: Variant = b.get("kill")
		return kill is Dictionary and not bool(kill.shown) and not _played_kills.has(str(b.debt_id))
	)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.hp_cents) < int(b.hp_cents))
	return out


## What the bar should show before the waiting beats play: undo this month's heal if it
## hasn't been shown, and add back the bank's hits that haven't played.
func _waiting(b: Dictionary) -> Dictionary:
	var heal: Variant = b.get("heal")
	if heal is Dictionary and _played_heals.has(int(heal.id)):
		heal = null
	var hits: Array = []
	for a: Dictionary in Game.state.get("away", []):
		if str(a.kind) == "gate_hit" and str(a.payload.get("debt_id", "")) == str(b.debt_id) and not _played_hits.has(int(a.id)):
			hits.append(a)
	var kill: Variant = b.get("kill")
	var dying := bool(b.defeated) and kill is Dictionary and not bool(kill.shown) and not _played_kills.has(str(b.debt_id))
	var start := float(b.hp_cents)
	for h: Dictionary in hits:
		start += float(h.payload.amount_cents)
	if heal is Dictionary:
		start -= float(heal.amount_cents)
	return {"heal": heal, "hits": hits, "dying": dying, "start": maxf(0.0, start)}


func dress() -> void:
	_sync_bosses()
	# A new day can change what's affordable: re-deal the stacks if they're out.
	if _mode == Mode.AIM and _target and is_instance_valid(_target) and _stacks and _stacks.amounts != _target.data.get("amounts", []):
		_show_stacks()
	_queue_beats.call_deferred()


func _sync_bosses() -> void:
	var standing := _standing()
	var keep: Dictionary = {}
	for i in mini(standing.size(), SLOTS.size()):
		var b: Dictionary = standing[i]
		var id := str(b.debt_id)
		keep[id] = true
		var px := int(b.look.get("scale", 3))
		if i > 0:
			px = maxi(1, px - 1)
		var pend := _waiting(b)
		var node: GateBoss = _bosses.get(id)
		if node and (node.px != px or node.front != (i == 0)) and not node.busy:
			_bosses.erase(id)
			_retire(node)
			node = null
		if node == null:
			node = GateBoss.new()
			node.setup(b, px, i == 0)
			node.shown_hp = float(pend.start)
			node.position = SLOTS[i]
			_arena.add_child(node)
			_bosses[id] = node
			if _intro_done:
				_step_forward(node)
		else:
			node.refresh(b)
			if not node.busy and (not pend.hits.is_empty() or pend.heal != null or pend.dying):
				node._set_shown(float(pend.start))
			if node.position != SLOTS[i]:
				var tw := node.create_tween()
				tw.tween_property(node, "position", SLOTS[i], 0.6).set_trans(Tween.TRANS_QUAD)
	for id: String in _bosses.keys():
		if not keep.has(id) and not (_bosses[id] as GateBoss).busy:
			_retire(_bosses[id])
			_bosses.erase(id)
	if _target and not is_instance_valid(_target):
		_target = null
	_dress_trophies()


func _retire(node: GateBoss) -> void:
	if node == _target:
		_target = null
		_fold_stacks()
	var tw := node.create_tween()
	tw.tween_property(node, "modulate:a", 0.0, 0.25)
	tw.tween_callback(node.queue_free)


## The next boss stomps up into the front slot and roars.
func _step_forward(node: GateBoss) -> void:
	node.modulate.a = 0.0
	var to := node.position
	node.position = to + Vector2(0, -24)
	var tw := node.create_tween()
	tw.tween_property(node, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(node, "position", to, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		GateFx.burst(_fx, to, GateFx.ASH, 24, 90.0, 0.7)
		if node.front:
			main.shake(3.0, 0.3)
			node.roar(node.line("meet"))
	)


## Paid-off bosses lie by the wall as skull piles, each with a little light.
func _dress_trophies() -> void:
	for c in _trophies.get_children():
		c.queue_free()
	var i := 0
	for b: Dictionary in bosses_state():
		if not bool(b.defeated) or _bosses.has(str(b.debt_id)):
			continue
		# On spikes along the wall top, either side of the gate.
		var x: float = [196.0, 284.0, 172.0, 308.0, 148.0, 332.0][i % 6]
		var glow := GateFx.glow(Color(Palette.CREAM, 0.45), 20, 0)
		glow.position = Vector2(x, WALL_Y - 12)
		_trophies.add_child(glow)
		var spike := ColorRect.new()
		spike.color = Color("3a2f45")
		spike.size = Vector2(2, 14)
		spike.position = Vector2(x - 1, WALL_Y - 12)
		_trophies.add_child(spike)
		var skull := _sprite(X72, Rect2(288, 432, 16, 16), Vector2(x - 16, WALL_Y - 40), 0, _trophies)
		skull.scale = Vector2(2, 2)
		i += 1


# --- every frame -------------------------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	var f := int(_t * 8.0) % 3
	for i in _fountains.size():
		var s := _fountains[i]
		s.region_rect.position.x = 64 + f * 16
	for i in _cultists.size():
		var c := _cultists[i]
		c.position.y = float(c.get_meta("base_y")) - absf(roundf(sin(_t * TAU / 0.65 + i * 0.7) * 1.0))
		c.frame = 1 if fmod(_t + i * 1.37, 4.1) < 0.14 else 0
	_leaf.region_rect = Rect2(32, 240 + _gate_lift, 32, 32 - _gate_lift)
	if (_mode == Mode.SCENE or _mode == Mode.STRIKE) and not Game.busy:
		Game.busy = true  # going through a door clears it; a beat is still playing
	if _mode == Mode.CHARGE:
		_charge = minf(1.0, _charge + delta / HOLD_SECONDS)
		if _stacks:
			_stacks.set_charge(_charge_i, _charge)
		if _charge >= 1.0:
			_fire()
	if _mode == Mode.IDLE or _mode == Mode.AIM:
		_idle_for += delta
		_roar_in -= delta
		if _roar_in <= 0.0 and not _beats_running:
			_roar_in = randf_range(5.0, 9.0)
			_random_roar()
		if _mode == Mode.IDLE and _idle_for > 3.0 and not _hinted_boss:
			_hint_boss()
		if _mode == Mode.AIM and _idle_for > 1.6 and not _hinted_stack and _stacks:
			_hinted_stack = true
			_stacks.show_hint()


func _random_roar() -> void:
	var nodes: Array = _bosses.values().filter(func(n: GateBoss) -> bool: return not n.busy)
	if nodes.is_empty():
		return
	var n: GateBoss = nodes.pick_random()
	if randf() < 0.5:
		var f := front_boss()
		if f and not f.busy:
			n = f
	n.roar(n.line("idle"), n.front)


## A pointing hand taps the front boss, once, to show where to start.
func _hint_boss() -> void:
	_hinted_boss = true
	var f := front_boss()
	if f == null:
		return
	var at := AtlasTexture.new()
	at.atlas = load(GateStacks.HAND_SHEET)
	at.region = GateStacks.HAND_RECT
	_boss_hand = Sprite2D.new()
	_boss_hand.texture = at
	_boss_hand.scale = Vector2(2, 2)
	_boss_hand.z_index = 95
	var at_pos := f.chest() + Vector2(10, 10)
	_boss_hand.position = at_pos + Vector2(24, 24)
	_fx.add_child(_boss_hand)
	var tw := _boss_hand.create_tween().set_loops(3)
	tw.tween_property(_boss_hand, "position", at_pos, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_boss_hand, "scale", Vector2(1.7, 1.7), 0.07)
	tw.tween_property(_boss_hand, "scale", Vector2(2, 2), 0.1)
	tw.tween_property(_boss_hand, "position", at_pos + Vector2(24, 24), 0.35)
	tw.tween_interval(0.3)
	tw.finished.connect(func() -> void:
		if is_instance_valid(_boss_hand):
			_boss_hand.queue_free()
	)


# --- input -------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var is_button := event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	var is_touch := event is InputEventScreenTouch
	if not (is_button or is_touch):
		if _mode == Mode.AIM and event.is_action_pressed("ui_cancel"):
			_cancel_aim()
			get_viewport().set_input_as_handled()
			return
		super._unhandled_input(event)
		return
	if not event.is_pressed():
		if _mode == Mode.CHARGE:
			get_viewport().set_input_as_handled()
			_let_go()
		return
	if _mode == Mode.STRIKE or _mode == Mode.SCENE or _mode == Mode.CHARGE:
		get_viewport().set_input_as_handled()
		return
	if Game.busy or Game.state.is_empty():
		return
	var local := make_input_local(event)
	var p: Vector2 = (local as InputEventMouseButton).position if is_button else (local as InputEventScreenTouch).position
	_idle_for = 0.0
	if _mode == Mode.AIM and _stacks:
		var i := _stacks.index_at(p)
		if i >= 0:
			get_viewport().set_input_as_handled()
			_begin_charge(i)
			return
	var boss := _boss_at(p)
	if boss:
		get_viewport().set_input_as_handled()
		aim(boss)
		return
	if _mode == Mode.AIM:
		_cancel_aim()
	super._unhandled_input(event)


func _boss_at(p: Vector2) -> GateBoss:
	var best: GateBoss = null
	for n: GateBoss in _bosses.values():
		if n.busy:
			continue
		if n.hit_rect().has_point(p) and float(n.data.hp_cents) > 0:
			if best == null or n.position.y > best.position.y:
				best = n
	return best


## Take aim at a boss: it gets the reticle, the stacks come out, the leader steps up.
func aim(boss: GateBoss) -> void:
	if _boss_hand and is_instance_valid(_boss_hand):
		_boss_hand.queue_free()
	if _target and is_instance_valid(_target) and _target != boss:
		_target.set_target(false)
	var same := _target == boss and _stacks != null
	_target = boss
	boss.set_target(true)
	_mode = Mode.AIM
	_idle_for = 0.0
	if same:
		return
	Sfx.play_path("res://art/packs/shattered-pixel-dungeon/sounds/alert.mp3", 1.0, -8.0)
	_show_stacks()
	leader.walk_to(GATE_SPOT)


func _show_stacks() -> void:
	_fold_stacks()
	if _target == null:
		return
	_stacks = GateStacks.new()
	_stacks.position = STACKS_AT
	_stacks.z_index = 35
	add_child(_stacks)
	_stacks.build(_target.data.get("amounts", []))


func _fold_stacks() -> void:
	if _stacks and is_instance_valid(_stacks):
		_stacks.fold()
	_stacks = null


func _cancel_aim() -> void:
	if _target and is_instance_valid(_target):
		_target.set_target(false)
	_target = null
	_fold_stacks()
	_mode = Mode.IDLE


func _begin_charge(i: int) -> void:
	_mode = Mode.CHARGE
	_charge = 0.0
	_charge_i = i
	_beat.play()
	Sfx.play_path("res://art/packs/lrsf-coins-library/Coins_Single/Coins_Single_00.ogg", 0.9, -6.0)
	if _target:
		_target.brace()
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -24.0, 0.2)
	tw.parallel().tween_property(camera, "zoom", Vector2(1.05, 1.05), HOLD_SECONDS)


func _let_go() -> void:
	if _mode != Mode.CHARGE:
		return
	_mode = Mode.AIM
	_beat.stop()
	if _stacks:
		_stacks.drain()
	_unzoom()


func _unzoom() -> void:
	var tw := create_tween()
	tw.tween_property(camera, "zoom", Vector2.ONE, 0.15)
	tw.parallel().tween_property(_music, "volume_db", -12.0, 0.4)


# --- the strike -------------------------------------------------------------------

func _fire() -> void:
	if _mode != Mode.CHARGE or _stacks == null or _target == null:
		return
	_mode = Mode.STRIKE
	Game.busy = true
	_beat.stop()
	var boss := _target
	var i := _charge_i
	var amount := _stacks.amount(i)
	var from := _stacks.stack_pos(i)
	_unzoom()
	# The stack and the gate wait for the answer: nothing leaves until the money moved.
	var res: Array = await Game.call_api("POST", "/gate/attack", {"debt_id": boss.debt_id, "amount_cents": amount})
	if not is_inside_tree():
		Game.busy = false
		return
	var refused: bool = res[1] != ""
	if refused:
		await _refuse(i, boss)
	else:
		if _stacks:
			_stacks.spend(i)
		_open_gate()
		# The leader throws it: a hop toward the gate.
		var y0 := leader.position.y
		var lt := leader.create_tween()
		lt.tween_property(leader, "position:y", y0 - 7.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		lt.tween_property(leader, "position:y", y0, 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		await _strike(boss, from, res[0])
	await Game.refresh()
	if not is_inside_tree():
		return
	beat = ""
	Game.busy = false
	_mode = Mode.IDLE
	if boss and is_instance_valid(boss) and _bosses.values().has(boss) and float(boss.data.hp_cents) > 0:
		if not refused:
			_target = null
		aim(boss)  # after a refusal the same stacks stay out
		if refused and _stacks and _stacks.amounts != boss.data.get("amounts", []):
			_show_stacks()
	else:
		_cancel_aim()
	_queue_beats()


func _strike(boss: GateBoss, from: Vector2, res: Dictionary) -> void:
	beat = "strike"
	_play_music(MUSIC_FIGHT, -12.0)
	var amount := int(res.damage_cents)
	await _motes(from, boss, amount)
	_close_gate()
	_chant_all()
	if bool(res.killed):
		await boss.hit(amount, 0, "")
		await _death(boss, res.get("drop"))
	else:
		await boss.hit(amount, int(res.hp_cents))
	await get_tree().create_timer(0.15).timeout


## Real money as bone-white motes, each worth an exact piece of the payment, streaming
## out of the stack, through the gate, into the boss. A rising tick per mote.
func _motes(from: Vector2, boss: GateBoss, amount: int) -> void:
	var sizes := mote_sizes(amount)
	var n := sizes.size()
	var gap := minf(0.035, 1.2 / n)
	var target := boss.chest()
	for k in n:
		var size: int = sizes[k]
		var m := ColorRect.new()
		m.color = Palette.CREAM
		m.size = Vector2(size, size)
		m.pivot_offset = m.size / 2.0
		m.position = from - m.size / 2.0
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.z_index = 5
		_fx.add_child(m)
		var halo := GateFx.glow(Color(Palette.CREAM, 0.35), size * 2.0 + 4, -1)
		halo.position = m.size / 2.0
		m.add_child(halo)
		var up := from + Vector2(randf_range(-34, 34), randf_range(-36, -14))
		var end := target + Vector2(randf_range(-10, 10), randf_range(-12, 12))
		var tw := m.create_tween()
		tw.tween_interval(k * gap)
		tw.tween_property(m, "position", up - m.size / 2.0, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_method(func(t: float) -> void:
			var a := up.lerp(GATE_MOUTH, t)
			var b := GATE_MOUTH.lerp(end, t)
			m.position = a.lerp(b, t) - m.size / 2.0, 0.0, 1.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			Sfx.play("tick", GateFx.pent(k))
			GateFx.burst(_fx, end, Palette.CREAM, 4, 50.0, 0.3)
			if k % 5 == 4:
				_chant_one(k)
			m.queue_free()
		)
	await get_tree().create_timer((n - 1) * gap + 0.7).timeout
	Sfx.play("cash")


## The motes for a payment, each worth an exact piece: $100 hearts (9 px), $25 orbs (7),
## $5 shards (5), $1 motes (3), 25-cent motes (2). The biggest piece is the largest that
## still makes at least six, so every payment is a stream; at most 30 (the rest rides on
## the last one). Bigger payments throw bigger motes.
static func mote_sizes(amount_cents: int) -> Array[int]:
	const UNITS := [[10000, 9], [2500, 7], [500, 5], [100, 3], [25, 2]]
	var out: Array[int] = []
	var left := amount_cents
	var start := UNITS.size() - 1
	for k in UNITS.size():
		if amount_cents / int(UNITS[k][0]) >= 6:
			start = k
			break
	for k in range(start, UNITS.size()):
		var u: Array = UNITS[k]
		while left >= int(u[0]) and out.size() < 30:
			out.append(int(u[1]))
			left -= int(u[0])
	if out.is_empty():
		out.append(2)
	return out


func _open_gate() -> void:
	Sfx.play_path(CHAINS, 1.15, -4.0)
	var mouth := get_node_or_null("Mouth") as Sprite2D
	var tw := create_tween()
	tw.tween_property(self, "_gate_lift", 26.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if mouth:
		tw.parallel().tween_property(mouth, "modulate:a", 0.7, 0.16)


func _close_gate() -> void:
	var mouth := get_node_or_null("Mouth") as Sprite2D
	var tw := create_tween()
	tw.tween_interval(0.1)
	tw.tween_property(self, "_gate_lift", 0.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if mouth:
		tw.parallel().tween_property(mouth, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		Sfx.play_path("res://art/packs/kenney-impact-sounds/Audio/impactPlate_heavy_001.ogg", 0.8, -4.0)
		GateFx.burst(_fx, Vector2(240, WALL_Y + 32), Color(0.6, 0.55, 0.6), 10, 60.0, 0.5)
		main.shake(1.0, 0.12)
	)


## "Not this week." The stack shakes where it stands and the boss shrugs. The gate stays
## shut and nothing else changes.
func _refuse(i: int, boss: GateBoss) -> void:
	beat = "refused"
	if _stacks:
		_stacks.refuse(i)
	if boss and is_instance_valid(boss):
		boss.shrug()
	await get_tree().create_timer(0.7).timeout


func _chant_one(k: int) -> void:
	if _cultists.is_empty():
		return
	var c := _cultists[k % _cultists.size()]
	Sfx.play("chant", [0.9, 1.0, 1.12][k % 3])
	_hop(c)


func _chant_all() -> void:
	Sfx.play_path("res://art/packs/owlishmedia-creepy-chanting/chant%d.ogg" % randi_range(1, 11), 1.0, -12.0)
	for i in _cultists.size():
		var c := _cultists[i]
		var tw := c.create_tween()
		tw.tween_interval(i * 0.04)
		tw.tween_callback(func() -> void: _hop(c))


func _hop(c: Sprite2D) -> void:
	var tw := c.create_tween()
	tw.tween_property(c, "offset:y", -12.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "offset:y", -8.0, 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


# --- death and the drop -------------------------------------------------------------

func _death(boss: GateBoss, drop: Variant) -> void:
	_play_music(MUSIC_FINALE, -10.0)
	if boss == _target:
		_fold_stacks()
	beat = "death"
	await boss.die(boss.line("death"))
	var at := boss.position + Vector2(0, -20)
	if drop is Dictionary:
		beat = "drop"
		await _reveal_drop(drop, at)
	_bosses.erase(boss.debt_id)
	_played_kills[boss.debt_id] = true
	boss.queue_free()
	if _target == boss:
		_target = null
	_chant_all()
	_play_music(MUSIC_GATE, -12.0)


## The cosmetic only that boss carried: a beam in its rarity's color, two bounces, then it
## flies to the leader.
func _reveal_drop(drop: Dictionary, at: Vector2) -> void:
	var tier := str(drop.get("tier", "legendary"))
	var color: Color = Palette.RARITY.get(tier, Palette.CREAM)
	var holder := Node2D.new()
	holder.position = at
	holder.z_index = 40
	_fx.add_child(holder)
	var beam := GateFx.glow(Color(color, 0.85), 40, 0)
	beam.scale = Vector2(0.7, 8.0)
	beam.position = Vector2(0, -60)
	holder.add_child(beam)
	var rays := Node2D.new()
	holder.add_child(rays)
	for k in 8:
		var ray := Polygon2D.new()
		ray.polygon = PackedVector2Array([Vector2(-4, 0), Vector2(4, 0), Vector2(0, -70)])
		ray.color = Color(color, 0.28)
		ray.rotation = k * TAU / 8.0
		rays.add_child(ray)
	var glow := GateFx.glow(Color(color, 0.9), 26, 1)
	holder.add_child(glow)
	var at_tex := AtlasTexture.new()
	at_tex.atlas = load(str(drop.icon.sheet))
	var r: Array = drop.icon.rect
	at_tex.region = Rect2(r[0], r[1], r[2], r[3])
	var icon := Sprite2D.new()
	icon.texture = at_tex
	icon.scale = Vector2(2, 2)
	icon.z_index = 3
	holder.add_child(icon)
	# A 2 px outline in the rarity's color: four flat copies behind the icon.
	var outline_mat := GateFx.solid_material(color)
	for off: Vector2 in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		var edge := Sprite2D.new()
		edge.texture = at_tex
		edge.material = outline_mat
		edge.position = off / 2.0
		edge.z_index = -1
		icon.add_child(edge)
	Sfx.play("reveal_" + tier)
	GateFx.flash(_fx, color, 0.35, 0.3)
	GateFx.burst(_fx, at, color, 40, 180.0, 1.0)
	var item_y := 0.0
	var tw := holder.create_tween()
	tw.tween_property(icon, "position:y", -36.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(icon, "position:y", item_y, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(icon, "position:y", item_y - 12.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(icon, "position:y", item_y, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(icon, "position:y", item_y - 4.0, 0.08)
	tw.tween_property(icon, "position:y", item_y, 0.08)
	var spin := rays.create_tween().set_loops()
	spin.tween_property(rays, "rotation", TAU, 6.0).from(0.0)
	await tw.finished
	Sfx.play_path("res://art/packs/shattered-pixel-dungeon/sounds/item.mp3", 1.0, -4.0)
	await get_tree().create_timer(1.6).timeout
	# It flies to the leader and lands on them.
	var to := leader.position + Vector2(0, -20) - holder.position
	var fly := holder.create_tween()
	fly.tween_property(beam, "modulate:a", 0.0, 0.2)
	fly.parallel().tween_property(rays, "modulate:a", 0.0, 0.2)
	fly.tween_method(func(t: float) -> void:
		var p := Vector2(0, 0).lerp(to, t) + Vector2(0, -60.0 * sin(t * PI))
		icon.position = p
		glow.position = p, 0.0, 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	await fly.finished
	Sfx.play("pop")
	GateFx.puff(_fx, leader.position + Vector2(0, -16), 0.8)
	GateFx.burst(_fx, leader.position + Vector2(0, -16), color, 20, 90.0, 0.6)
	holder.queue_free()


# --- while you were out -------------------------------------------------------------

## Heals, the bank's hits and deaths that happened while you were away play in order.
func _queue_beats() -> void:
	if _beats_running or _mode == Mode.CHARGE or _mode == Mode.STRIKE or not is_inside_tree():
		return
	if Game.state.is_empty() or Game.weeks_ago != 0:
		return
	var todo: Array = []
	for b: Dictionary in _standing():
		var pend := _waiting(b)
		if pend.heal != null or not (pend.hits as Array).is_empty() or bool(pend.dying):
			todo.append([b, pend])
	if _intro_done and todo.is_empty():
		return
	_beats_running = true
	var was := _mode
	_mode = Mode.SCENE
	Game.busy = true
	if not _intro_done:
		_intro_done = true
		beat = "intro"
		await _intro()
	var away_ids: Array = []
	var heal_ids: Array = []
	var kill_ids: Array = []
	for pair: Array in todo:
		var b: Dictionary = pair[0]
		var pend: Dictionary = pair[1]
		var node: GateBoss = _bosses.get(str(b.debt_id))
		if node == null:
			continue
		var cur := float(pend.start)
		node._set_shown(cur)
		if pend.heal is Dictionary:
			var heal: Dictionary = pend.heal
			_played_heals[int(heal.id)] = true
			heal_ids.append(int(heal.id))
			cur += float(heal.amount_cents)
			beat = "heal"
			await node.heal(int(heal.amount_cents), int(cur), str(heal.line))
		for a: Dictionary in pend.hits:
			_played_hits[int(a.id)] = true
			away_ids.append(int(a.id))
			cur -= float(a.payload.amount_cents)
			beat = "bank_hit"
			await _bank_hit(node, int(a.payload.amount_cents), int(maxf(0.0, cur)))
		if bool(pend.dying):
			kill_ids.append(str(b.debt_id))
			await _death(node, b.get("drop"))
	# Marked seen before anything else reads /state again, then reloaded, so the
	# while-you-were-out scene doesn't play the same heal or death a second time.
	if not away_ids.is_empty():
		await Game.call_api("POST", "/away/seen", {"ids": away_ids})
	if not heal_ids.is_empty() or not kill_ids.is_empty():
		await Game.call_api("POST", "/gate/seen", {"heals": heal_ids, "kills": kill_ids})
	if not away_ids.is_empty() or not heal_ids.is_empty() or not kill_ids.is_empty():
		await Game.refresh()
	if not is_inside_tree():
		return
	_beats_running = false
	beat = ""
	_mode = was if was != Mode.SCENE else Mode.IDLE
	if _mode == Mode.AIM and (_target == null or not is_instance_valid(_target)):
		_mode = Mode.IDLE
	Game.busy = false
	if not kill_ids.is_empty():
		_sync_bosses()


func _intro() -> void:
	var f := front_boss()
	if f == null:
		return
	Sfx.play_path("res://art/packs/shattered-pixel-dungeon/sounds/boss.mp3", 1.0, -6.0)
	var first := not _met.has(f.debt_id)
	_met[f.debt_id] = true
	await f.roar(f.line("meet") if first else f.line("idle"))
	await get_tree().create_timer(0.3).timeout


## The bank paid on its own: a bell, a bolt out of the sky, and the hit.
func _bank_hit(node: GateBoss, amount: int, to_hp: int) -> void:
	Sfx.play_path("res://art/packs/kenney-impact-sounds/Audio/impactBell_heavy_00%d.ogg" % randi_range(0, 4), 1.0, -4.0)
	var bolt := Line2D.new()
	var top := Vector2(node.position.x + randf_range(-40, 40), -10)
	var end := node.chest()
	var pts := PackedVector2Array([top])
	for k in range(1, 6):
		pts.append(top.lerp(end, k / 6.0) + Vector2(randf_range(-8, 8), 0))
	pts.append(end)
	bolt.points = pts
	bolt.width = 3.0
	bolt.default_color = Palette.CREAM
	bolt.z_index = 60
	_fx.add_child(bolt)
	GateFx.flash(_fx, Palette.CREAM, 0.25, 0.1)
	var tw := bolt.create_tween()
	tw.tween_property(bolt, "width", 1.0, 0.18)
	tw.parallel().tween_property(bolt, "modulate:a", 0.0, 0.25)
	tw.tween_callback(bolt.queue_free)
	_chant_all()
	await node.hit(amount, to_hp, "", true)
	await get_tree().create_timer(0.25).timeout
