class_name MineOverlay
extends MinigameOverlay
## The mine: tap a block to swing. Ore pops out and its coins fly to the pouch. Clear the
## top layer and everything drops a level; deeper layers hold better ore. Chain hits fast
## enough and Coin Fever lights the walls brass: one-hit blocks and double coins.

const CELL := 32
const GX := 112.0
const GY := 104.0
const CAVES := ArcadeFx.PACKS + "shattered-pixel-dungeon/environment/tiles_caves.png"
const LEADER := ArcadeFx.PACKS + "0x72-dungeontileset-ii/0x72_DungeonTilesetII_v1.7/0x72_DungeonTilesetII_v1.7.png"
const SND_HIT := ArcadeFx.PACKS + "kenney-impact-sounds/Audio/impactMining_00%d.ogg"
const SND_BREAK := ArcadeFx.PACKS + "themightyglider-breaking-rock/rock_break.ogg"
const SND_ROCKS := ArcadeFx.PACKS + "shattered-pixel-dungeon/sounds/rocks.mp3"
const SND_THUD := ArcadeFx.PACKS + "kenney-impact-sounds/Audio/impactSoft_heavy_000.ogg"
const SND_GEM := ArcadeFx.PACKS + "kenney-interface-sounds/Audio/glass_002.ogg"
const SND_DESCEND := ArcadeFx.PACKS + "shattered-pixel-dungeon/sounds/descend.mp3"
const SMOKE := ArcadeFx.PACKS + "ninja-adventure/FX/Smoke/Smoke/SpriteSheet.png"
const EXPLOSION := ArcadeFx.PACKS + "ninja-adventure/FX/Elemental/Explosion/SpriteSheet.png"
const SPARK := ArcadeFx.PACKS + "ninja-adventure/FX/Magic/Spark/SpriteSheet.png"
const ORE_HUES := {"copper": Color("e08a4a"), "silver": Color("dfe6f0"), "gold": Color("ffd75a"), "gem": Color("c58cff")}

var depth := 0
var ore_counts: Dictionary = {}
var fever_coins := 0
var chain := 0
var fever_left := 0.0

var _rng := RandomNumberGenerator.new()
var _rows: Array = []  ## rows of cells; each cell is a Dictionary or null
var _grid := Node2D.new()
var _marks := Node2D.new()
var _leader: AnimatedSprite2D
var _leader_col := 3
var _last_hit := -10.0
var _clock := 0.0
var _chain_label: Label
var _fever_label: Label
var _fever_rain: CPUParticles2D
var _haul_labels: Dictionary = {}
var _haul_icons: Dictionary = {}
var _depth_label: Label
var _busy_descend := false


func game_id() -> String:
	return "mine"


func music_path() -> String:
	return ArcadeFx.PACKS + "shattered-pixel-dungeon/music/caves_1.ogg"


func _ores() -> Dictionary:
	return catalog.ores


func setup() -> void:
	_rng.seed = int(run.seed)
	for o: Dictionary in _ores().ores:
		ore_counts[o.id] = 0
	_build_cave()
	world.add_child(_marks)
	world.add_child(_grid)
	var rows := int(_ores().layer.rows)
	for r in rows:
		_rows.append(_make_row(r, r))
	_build_leader()
	_build_haul()
	show_hint(Vector2(GX + CELL * 3 + 22, GY + 22))


func _build_cave() -> void:
	# Shaft walls from the caves tileset, a darker gut in the middle, torches that breathe.
	var gut := ColorRect.new()
	gut.color = Color("0d0812")
	gut.size = Vector2(CELL * 8 + 8, H)
	gut.position = Vector2(GX - 4, 0)
	gut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(gut)
	for y in range(0, int(H) + CELL, CELL):
		for x in range(0, int(GX) - 4, CELL):
			_wall_tile(Vector2(x, y), (x / CELL + y / CELL) % 4)
		for x in range(int(GX + CELL * 8 + 4), int(W) + CELL, CELL):
			_wall_tile(Vector2(x, y), (x / CELL * 3 + y / CELL) % 4)
	for spot: Vector2 in [Vector2(84, 70), Vector2(396, 120), Vector2(84, 200), Vector2(396, 236)]:
		var torch := Sprite2D.new()
		torch.texture = ArcadeFx.tex(ArcadeFx.PACKS + "kenney-roguelike-caves-dungeons/Spritesheet/roguelikeDungeon_transparent.png", [221, 289, 16, 16])
		torch.position = spot
		world.add_child(torch)
		var g := ArcadeFx.glow(world, spot + Vector2(0, -4), Color("ff9a3c"), 34.0, 0.3)
		ArcadeFx.breathe(g, 0.6, 1.0, 0.7 + randf() * 0.5)
	# Dust that never stops falling.
	var dust := CPUParticles2D.new()
	dust.amount = 26
	dust.lifetime = 4.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(CELL * 4, 2)
	dust.position = Vector2(GX + CELL * 4, -4)
	dust.direction = Vector2.DOWN
	dust.spread = 10.0
	dust.initial_velocity_min = 6.0
	dust.initial_velocity_max = 18.0
	dust.gravity = Vector2(0, 8)
	dust.color = Color(Palette.MUTED, 0.35)
	world.add_child(dust)
	# Depth on the wall.
	_depth_label = ArcadeFx.label("0", 32, Palette.CREAM, true, 6)
	_depth_label.position = Vector2(16, 52)
	hud.add_child(_depth_label)
	var pick := Sprite2D.new()
	pick.texture = ArcadeFx.tex(str(_ores().pickaxe.sheet), _ores().pickaxe.rect)
	pick.position = Vector2(22, 46)
	hud.add_child(pick)


func _wall_tile(pos: Vector2, variant: int) -> void:
	var s := Sprite2D.new()
	s.texture = ArcadeFx.tex(CAVES, [variant * 16, 80 + (variant % 2) * 16, 16, 16])
	s.centered = false
	s.position = pos
	s.scale = Vector2(2, 2)
	s.modulate = Color(0.55, 0.5, 0.65)
	world.add_child(s)


func _build_leader() -> void:
	_leader = ArcadeFx.anim_sprite({"rect": [128, 164, 16, 28], "frames": 4, "step": 16}, 8.0, LEADER)
	_leader.offset = Vector2(0, -14)
	_leader.position = Vector2(GX + _leader_col * CELL + CELL / 2.0, GY)
	_leader.z_index = 20
	world.add_child(_leader)
	ArcadeFx.glow(_leader, Vector2(0, -12), Color("ffb05a"), 22.0, 0.22)


func _build_haul() -> void:
	var x := 176.0
	for o: Dictionary in _ores().ores:
		var s := Sprite2D.new()
		s.texture = ArcadeFx.icon(o.icon)
		s.position = Vector2(x, H - 12)
		hud.add_child(s)
		_haul_icons[o.id] = s
		var l := ArcadeFx.label("0", 16, Palette.CREAM)
		l.position = Vector2(x + 8, H - 21)
		hud.add_child(l)
		_haul_labels[o.id] = l
		x += 40.0
	_chain_label = ArcadeFx.label("", 32, ArcadeFx.BRASS, true, 6)
	_chain_label.position = Vector2(GX + CELL * 8 + 14, GY + 8)
	hud.add_child(_chain_label)
	_fever_label = ArcadeFx.label("x2", 40, ArcadeFx.BRASS, true, 8)
	_fever_label.position = Vector2(64, H - 46)
	_fever_label.visible = false
	hud.add_child(_fever_label)
	_fever_rain = CPUParticles2D.new()
	_fever_rain.emitting = false
	_fever_rain.amount = 60
	_fever_rain.lifetime = 1.6
	_fever_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_fever_rain.emission_rect_extents = Vector2(W / 2.0, 2)
	_fever_rain.position = Vector2(W / 2.0, -6)
	_fever_rain.direction = Vector2.DOWN
	_fever_rain.initial_velocity_min = 90.0
	_fever_rain.initial_velocity_max = 180.0
	_fever_rain.gravity = Vector2(0, 120)
	_fever_rain.scale_amount_min = 2.0
	_fever_rain.scale_amount_max = 3.0
	_fever_rain.color = ArcadeFx.BRASS
	world.add_child(_fever_rain)


# --- rows -----------------------------------------------------------------------------

func _row_y(r: int) -> float:
	return GY + r * CELL


func _make_row(r: int, row_depth: int) -> Array:
	var row: Array = []
	var layer: Dictionary = _ores().layer
	for c in int(layer.width):
		var roll := _rng.randf()
		var keg := float(layer.keg_chance) if row_depth > 0 else 0.0
		var purse := float(layer.purse_chance) if row_depth > 1 else 0.0
		var ore_p := float(layer.ore_chance) + float(layer.ore_chance_per_depth) * row_depth
		var cell: Dictionary
		if roll < keg:
			cell = _cell("keg", "", 1, _special("keg").sprite)
		elif roll < keg + purse:
			cell = _cell("purse", "", 1, _special("purse").sprite)
		elif roll < keg + purse + ore_p:
			var o := _pick_ore(row_depth)
			cell = _cell("ore", str(o.id), int(o.hits) + row_depth / 12, o.block)
		else:
			var b := _pick_block(row_depth)
			cell = _cell(str(b.id), "", int(b.hits) + row_depth / 10, b.sprite)
		cell.depth = row_depth
		_place_cell(cell, c, r)
		row.append(cell)
	_depth_mark(r, row_depth)
	return row


func _special(id: String) -> Dictionary:
	for s: Dictionary in _ores().specials:
		if s.id == id:
			return s
	return {}


func _pick_ore(d: int) -> Dictionary:
	var pool: Array = []
	var total := 0.0
	for o: Dictionary in _ores().ores:
		if d >= int(o.from_depth):
			var w := maxf(0.3, float(o.weight) + float(o.growth) * (d - int(o.from_depth)))
			pool.append([o, w])
			total += w
	var roll := _rng.randf() * total
	for entry: Array in pool:
		roll -= float(entry[1])
		if roll <= 0.0:
			return entry[0]
	return pool[-1][0]


func _pick_block(d: int) -> Dictionary:
	var blocks: Array = _ores().blocks
	if d < 6:
		return blocks[0] if _rng.randf() < 0.6 else blocks[1]
	if d >= 8 and _rng.randf() < 0.35:
		return blocks[2]
	return blocks[1]


func _cell(kind: String, ore: String, hits: int, sprite: Dictionary) -> Dictionary:
	return {"kind": kind, "ore": ore, "hp": hits, "max": hits, "sprite": sprite, "node": null, "cracks": null}


func _place_cell(cell: Dictionary, c: int, r: int) -> void:
	var n := Node2D.new()
	n.position = Vector2(GX + c * CELL + CELL / 2.0, _row_y(r) + CELL / 2.0)
	var s := Sprite2D.new()
	s.texture = ArcadeFx.icon(cell.sprite) if cell.kind in ["ore", "dirt", "stone", "coalstone"] else ArcadeFx.icon(_pick_block(0).sprite)
	s.scale = Vector2(2, 2)
	# Rock sits back in the dark (deeper is darker and more violet) so ore and kegs read first.
	s.modulate = Color(0.58, 0.54, 0.68).darkened(minf(0.35, int(cell.depth) * 0.016)).lerp(Color("7a6a9a"), minf(0.35, int(cell.depth) * 0.012))
	n.add_child(s)
	var edge := Line2D.new()
	edge.width = 1.0
	edge.default_color = Color(Palette.NIGHT, 0.85)
	edge.points = PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16), Vector2(-16, -16)])
	n.add_child(edge)
	if cell.kind == "ore":
		var chunk := Sprite2D.new()
		for o: Dictionary in _ores().ores:
			if o.id == cell.ore:
				chunk.texture = ArcadeFx.icon(o.icon)
		n.add_child(chunk)
	if cell.kind == "purse" or cell.kind == "keg":
		var prop := Sprite2D.new()
		prop.texture = ArcadeFx.icon(cell.sprite)
		prop.scale = Vector2(1.5, 1.5)
		n.add_child(prop)
		if cell.kind == "purse":
			ArcadeFx.breathe(ArcadeFx.glow(n, Vector2.ZERO, ArcadeFx.BRASS, 22.0, 0.5), 0.4, 1.0, 0.8)
		else:
			ArcadeFx.breathe(ArcadeFx.glow(n, Vector2(5, -6), Color("ff9a3c"), 10.0, 0.8), 0.3, 1.0, 0.25)
		ArcadeFx.bob(prop, 1.0, 0.9)
	elif cell.kind == "ore":
		# Ore glints: a white sparkle every so often, never a colored glow.
		var glint := Sprite2D.new()
		glint.texture = ArcadeFx.tex(SPARK, [0, 0, 30, 35])
		glint.scale = Vector2(0.35, 0.35)
		glint.position = Vector2(randf_range(-8, 8), randf_range(-8, 8))
		glint.modulate = Color(1, 1, 1, 0)
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glint.material = m
		n.add_child(glint)
		var tw := glint.create_tween().set_loops()
		tw.tween_interval(0.6 + randf() * 2.2)
		tw.tween_property(glint, "modulate:a", 1.0, 0.08)
		tw.tween_property(glint, "rotation", PI / 2, 0.25)
		tw.parallel().tween_property(glint, "modulate:a", 0.0, 0.25)
	var cracks := Line2D.new()
	cracks.width = 1.0
	cracks.default_color = Color("120c18")
	n.add_child(cracks)
	cell.cracks = cracks
	cell.node = n
	_grid.add_child(n)


func _depth_mark(r: int, row_depth: int) -> void:
	if row_depth % 5 != 0 or row_depth == 0:
		return
	var l := ArcadeFx.label(str(row_depth), 16, Color(Palette.MUTED, 0.8))
	l.position = Vector2(GX - 26, _row_y(r) + 8)
	l.set_meta("row_depth", row_depth)
	_marks.add_child(l)


# --- swinging -------------------------------------------------------------------------

func press(pos: Vector2) -> void:
	var c := int(floor((pos.x - GX) / CELL))
	var r := int(floor((pos.y - GY) / CELL))
	_swing_fx(pos)
	if c < 0 or c >= 8 or r < 0 or r >= _rows.size():
		ArcadeFx.burst(world, pos, Palette.MUTED, 4, 30.0, 0.3)
		return
	var cell: Variant = _rows[r][c]
	if cell == null:
		ArcadeFx.burst(world, pos, Palette.MUTED, 4, 30.0, 0.3)
		return
	_chain_hit()
	_hit(cell as Dictionary, c, r, 99 if fever_left > 0.0 else 1)


func _swing_fx(pos: Vector2) -> void:
	var pick := Sprite2D.new()
	pick.texture = ArcadeFx.tex(str(_ores().pickaxe.sheet), _ores().pickaxe.rect)
	pick.scale = Vector2(1.5, 1.5)
	pick.position = pos + Vector2(10, -10)
	pick.rotation = -1.3
	pick.z_index = 50
	world.add_child(pick)
	var tw := pick.create_tween()
	tw.tween_property(pick, "rotation", 0.5, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.05)
	tw.tween_property(pick, "modulate:a", 0.0, 0.1)
	tw.tween_callback(pick.queue_free)
	# The leader hops over to the column and swings with you.
	var col := clampi(int(floor((pos.x - GX) / CELL)), 0, 7)
	if col != _leader_col:
		_leader_col = col
		var to := GX + col * CELL + CELL / 2.0
		_leader.flip_h = to < _leader.position.x
		var mv := _leader.create_tween()
		mv.tween_property(_leader, "position:x", to, 0.07)
	ArcadeFx.squash(_leader)


func _chain_hit() -> void:
	var gap := float(_ores().fever.chain_gap_s)
	chain = chain + 1 if _clock - _last_hit <= gap else 1
	_last_hit = _clock
	if chain >= 3:
		_chain_label.text = "x%d" % chain
		_chain_label.modulate.a = 1.0
		ArcadeFx.pop(_chain_label, 0.25 + minf(0.3, chain * 0.02))
	if chain == int(_ores().fever.chain) and fever_left <= 0.0:
		_start_fever(float(_ores().fever.seconds))


func _hit(cell: Dictionary, c: int, r: int, dmg: int) -> void:
	cell.hp = int(cell.hp) - dmg
	var n: Node2D = cell.node
	if int(cell.hp) > 0:
		ArcadeFx.sfx(SND_HIT % (randi() % 5), randf_range(0.9, 1.15), -4.0)
		ArcadeFx.burst(world, n.position, _chip_color(cell), 6, 70.0, 0.35)
		var cracks: Line2D = cell.cracks
		var p := Vector2(randf_range(-10, 10), randf_range(-10, 10))
		for i in 4:
			cracks.add_point(p)
			p += Vector2(randf_range(-7, 7), randf_range(-7, 7))
		var tw := n.create_tween()
		tw.tween_property(n, "position:x", n.position.x + 2, 0.02)
		tw.tween_property(n, "position:x", n.position.x - 2, 0.03)
		tw.tween_property(n, "position:x", n.position.x, 0.02)
		ArcadeFx.shake(world, 1.0, 0.06)
		return
	_break(cell, c, r)


func _chip_color(cell: Dictionary) -> Color:
	match str(cell.kind):
		"dirt":
			return Color("a0703f")
		"ore":
			return ORE_HUES.get(cell.ore, Palette.MUTED)
	return Color("8f8a99")


func _break(cell: Dictionary, c: int, r: int) -> void:
	_rows[r][c] = null
	var n: Node2D = cell.node
	var at := n.position
	ArcadeFx.sfx(SND_BREAK, randf_range(0.9, 1.2), -3.0)
	ArcadeFx.one_shot(world, at, SMOKE, 32, 32, 6, 22.0, Color(1, 1, 1, 0.8))
	ArcadeFx.burst(world, at, _chip_color(cell), 14, 110.0, 0.5)
	ArcadeFx.shake(world, 2.0, 0.1)
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector2(1.25, 1.25), 0.05)
	tw.tween_property(n, "scale", Vector2(0.2, 0.2), 0.08)
	tw.tween_callback(n.queue_free)
	match str(cell.kind):
		"ore":
			_pop_ore(str(cell.ore), at)
		"purse":
			ArcadeFx.sfx(ArcadeFx.SND_JACKPOT, 1.0, -4.0)
			ArcadeFx.burst(world, at, ArcadeFx.BRASS, 40, 160.0, 0.9)
			_start_fever(float(_ores().fever.purse_seconds))
		"keg":
			_blow(c, r)
	_check_layer()


func _pop_ore(ore_id: String, at: Vector2) -> void:
	var spec: Dictionary = {}
	for o: Dictionary in _ores().ores:
		if o.id == ore_id:
			spec = o
	var value := int(spec.coins)
	ore_counts[ore_id] = int(ore_counts[ore_id]) + 1
	if fever_left > 0.0:
		fever_coins += value
	var paid := value * (2 if fever_left > 0.0 else 1)
	# The chunk pops up and spins, then drops into the haul.
	var chunk := Sprite2D.new()
	chunk.texture = ArcadeFx.icon(spec.icon)
	chunk.position = at
	chunk.z_index = 55
	world.add_child(chunk)
	var slot: Sprite2D = _haul_icons[ore_id]
	var top := at + Vector2(randf_range(-14, 14), -30)
	var tw := chunk.create_tween()
	tw.tween_property(chunk, "position", top, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(chunk, "rotation", TAU, 0.18)
	tw.parallel().tween_property(chunk, "scale", Vector2(1.6, 1.6), 0.18)
	tw.tween_property(chunk, "position", slot.position, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(chunk, "scale", Vector2.ONE, 0.3)
	tw.tween_callback(func() -> void:
		chunk.queue_free()
		(_haul_labels[ore_id] as Label).text = str(ore_counts[ore_id])
		ArcadeFx.pop(slot, 0.4)
	)
	ArcadeFx.float_text(world, at + Vector2(0, -10), "+%d" % paid, ArcadeFx.BRASS, 16)
	if ore_id == "gem":
		ArcadeFx.sfx(SND_GEM, 1.0, -2.0)
		ArcadeFx.burst(world, at, Palette.CREAM, 24, 140.0, 0.7)
		ArcadeFx.one_shot(world, at, SPARK, 30, 35, 9, 20.0, Color.WHITE, 1.0, true)
		ArcadeFx.hit_stop(get_tree(), 0.05)
	elif ore_id == "gold":
		ArcadeFx.one_shot(world, at, SPARK, 30, 35, 9, 24.0, Color.WHITE, 0.7, true)
	earn(paid, at)


func _blow(c: int, r: int) -> void:
	var at := Vector2(GX + c * CELL + CELL / 2.0, _row_y(r) + CELL / 2.0)
	ArcadeFx.one_shot(world, at, EXPLOSION, 40, 40, 9, 20.0, Color.WHITE, 1.8)
	ArcadeFx.sfx(ArcadeFx.SND_BOOM, randf_range(0.9, 1.1), -2.0)
	ArcadeFx.flash(hud, Color("ffd38a"), 0.35, 0.18)
	ArcadeFx.shake(world, 5.0, 0.3)
	ArcadeFx.hit_stop(get_tree(), 0.07)
	ArcadeFx.burst(world, at, Color("ffb05a"), 30, 180.0, 0.6)
	await get_tree().create_timer(0.08).timeout
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var rr: int = r + dy
			var cc: int = c + dx
			if rr < 0 or rr >= _rows.size() or cc < 0 or cc >= 8:
				continue
			var other: Variant = _rows[rr][cc]
			if other != null:
				_break(other as Dictionary, cc, rr)


func _check_layer() -> void:
	if _busy_descend or _rows.is_empty():
		return
	for cell: Variant in _rows[0]:
		if cell != null:
			return
	_descend()


func _descend() -> void:
	_busy_descend = true
	depth += 1
	_rows.pop_front()
	for mark: Node in _marks.get_children():
		var l := mark as Label
		var tw2 := l.create_tween()
		tw2.tween_property(l, "position:y", l.position.y - CELL, 0.16)
		if l.position.y < GY:
			tw2.tween_callback(l.queue_free)
	var new_depth := depth + _rows.size()
	_rows.append(_make_row(_rows.size(), new_depth))
	# The new row rises in from below; everything else drops into the gap.
	for r in _rows.size():
		for cell: Variant in _rows[r]:
			if cell == null:
				continue
			var n: Node2D = (cell as Dictionary).node
			var target_y := _row_y(r) + CELL / 2.0
			if r == _rows.size() - 1:
				n.position.y = target_y + CELL
				n.modulate.a = 0.0
				n.create_tween().tween_property(n, "modulate:a", 1.0, 0.2)
			var tw := n.create_tween()
			tw.tween_property(n, "position:y", target_y, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# The leader drops a level and lands with a thud.
	_leader.position.y = GY - 18
	var land := _leader.create_tween()
	land.tween_property(_leader, "position:y", GY, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	land.tween_callback(func() -> void:
		ArcadeFx.sfx(SND_THUD, randf_range(0.9, 1.1), -4.0)
		ArcadeFx.burst(world, _leader.position, Color("a0703f"), 10, 60.0, 0.4)
		ArcadeFx.squash(_leader)
	)
	_depth_label.text = str(depth)
	ArcadeFx.pop(_depth_label, 0.5)
	ArcadeFx.shake(world, 2.5, 0.15)
	if depth % 5 == 0:
		ArcadeFx.sfx(SND_DESCEND, 1.0, -6.0)
		ArcadeFx.flash(hud, Palette.TEAL, 0.2, 0.3)
		edge_glow(Palette.TEAL, 0.6, 0.8)
	await get_tree().create_timer(0.18).timeout
	_busy_descend = false
	_check_layer()


func _start_fever(add_s: float) -> void:
	var cap := float(_ores().fever.seconds)
	var was := fever_left > 0.0
	fever_left = minf(cap, fever_left + add_s)
	if was:
		return
	ArcadeFx.sfx(ArcadeFx.SND_JACKPOT, 1.1, -2.0)
	ArcadeFx.sfx(ArcadeFx.SND_RISE, 1.0, -4.0)
	ArcadeFx.flash(hud, ArcadeFx.BRASS, 0.4, 0.3)
	ArcadeFx.shake(world, 4.0, 0.25)
	_fever_label.visible = true
	_fever_rain.emitting = true
	if music_player:
		music_player.pitch_scale = 1.12


func _end_fever() -> void:
	fever_left = 0.0
	_fever_label.visible = false
	_fever_rain.emitting = false
	edge_hold(ArcadeFx.BRASS, 0.0)
	if music_player:
		music_player.pitch_scale = 1.0


func tick(delta: float) -> void:
	_clock += delta
	if _clock - _last_hit > float(_ores().fever.chain_gap_s) and chain > 0:
		chain = 0
		var tw := _chain_label.create_tween()
		tw.tween_property(_chain_label, "modulate:a", 0.0, 0.2)
	if fever_left > 0.0:
		fever_left -= delta
		var pulse := 0.35 + 0.25 * sin(_clock * 14.0)
		edge_hold(ArcadeFx.BRASS, pulse)
		_fever_label.scale = Vector2.ONE * (1.0 + 0.08 * sin(_clock * 18.0))
		if fever_left <= 0.0:
			_end_fever()


func result() -> Dictionary:
	return {"ore": ore_counts, "fever": fever_coins, "depth": depth}


func haul() -> Array:
	var out: Array = []
	for o: Dictionary in _ores().ores:
		if int(ore_counts[o.id]) > 0:
			out.append({"texture": ArcadeFx.icon(o.icon), "count": ore_counts[o.id]})
	return out
