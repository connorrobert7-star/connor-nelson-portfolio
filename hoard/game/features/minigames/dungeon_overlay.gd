class_name DungeonOverlay
extends MinigameOverlay
## The daily dungeon: down the stairs past the week's omens, three rooms and a boss. The
## leader and the followers fight on their own; tap an enemy to smite it, tap the bomb once.
## Kills fill the Chips box over the door. At the door the idol shelf fires left to right,
## Chips x Mult slams together and pours into the number carved on the door. Each room pays
## the same coins whatever the omens said; the boss holds the day's cosmetic.

enum Phase { STAIRS, FIGHT, CASCADE, WALK, OVER }

const SHEET_0X72 := ArcadeFx.PACKS + "0x72-dungeontileset-ii/0x72_DungeonTilesetII_v1.7/0x72_DungeonTilesetII_v1.7.png"
const FIREBALL := ArcadeFx.PACKS + "ninja-adventure/FX/Projectile/Fireball.png"
const THUNDER := ArcadeFx.PACKS + "ninja-adventure/FX/Elemental/Thunder/SpriteSheet.png"
const CUT := ArcadeFx.PACKS + "ninja-adventure/FX/Attack/Cut/SpriteSheet.png"
const EXPLOSION := ArcadeFx.PACKS + "ninja-adventure/FX/Elemental/Explosion/SpriteSheet.png"
const SMOKE := ArcadeFx.PACKS + "ninja-adventure/FX/Smoke/Smoke/SpriteSheet.png"
const AURA := ArcadeFx.PACKS + "ninja-adventure/FX/Magic/Aura/SpriteSheet.png"
const SND_HIT := ArcadeFx.PACKS + "ninja-adventure/Audio/Sounds/Hit & Impact/Hit1.ogg"
const SND_SLASH := ArcadeFx.PACKS + "shattered-pixel-dungeon/sounds/hit_slash.mp3"
const SND_STRONG := ArcadeFx.PACKS + "shattered-pixel-dungeon/sounds/hit_strong.mp3"
const SND_ZAP := ArcadeFx.PACKS + "shattered-pixel-dungeon/sounds/lightning.mp3"
const SND_BOLT := ArcadeFx.PACKS + "ninja-adventure/Audio/Sounds/Elemental/Fireball.ogg"
const SND_DIE := ArcadeFx.PACKS + "rubberduck-80-rpg-sfx/creature_die_01.ogg"
const SND_HURT := ArcadeFx.PACKS + "rubberduck-80-rpg-sfx/creature_hurt_01.ogg"
const SND_ROAR := ArcadeFx.PACKS + "rubberduck-80-rpg-sfx/creature_roar_02.ogg"
const SND_SLIME := ArcadeFx.PACKS + "rubberduck-80-rpg-sfx/creature_slime_02.ogg"
const SND_CHARGE := ArcadeFx.PACKS + "shattered-pixel-dungeon/sounds/chargeup.mp3"
const SND_BOSS := ArcadeFx.PACKS + "shattered-pixel-dungeon/sounds/boss.mp3"
const SND_DEATH := ArcadeFx.PACKS + "shattered-pixel-dungeon/sounds/death.mp3"
const SND_DOOR := ArcadeFx.PACKS + "shattered-pixel-dungeon/sounds/door_open.mp3"
const SND_DESCEND := ArcadeFx.PACKS + "shattered-pixel-dungeon/sounds/descend.mp3"
const SND_STEP := ArcadeFx.PACKS + "shattered-pixel-dungeon/sounds/step.mp3"
const SND_THUNK := ArcadeFx.PACKS + "kenney-impact-sounds/Audio/impactPlank_medium_000.ogg"
const SND_SLAM := ArcadeFx.PACKS + "kenney-impact-sounds/Audio/impactPlate_heavy_000.ogg"
const SND_MULT := ArcadeFx.PACKS + "kenney-impact-sounds/Audio/impactPunch_heavy_000.ogg"
const SND_GOOD := ArcadeFx.PACKS + "ninja-adventure/Audio/Sounds/Bonus/Bonus.ogg"
const SND_BAD := ArcadeFx.PACKS + "wobbleboxx-levelup-coin/Downer01.ogg"
const SND_CHEST := ArcadeFx.PACKS + "shattered-pixel-dungeon/sounds/unlock.mp3"

const ICONS := ArcadeFx.PACKS + "kyrise-rpg-icons-16/icons/16x16/"
const DOOR := Vector2(240, 40)
const CHIPS_AT := Vector2(160, 30)
const MULT_AT := Vector2(320, 30)
const BOX := Vector2(46, 16)
const SHELF_X := 372.0
const SHELF_Y := 60.0
const BOMB_AT := Vector2(240, 254)
const UNIT_SCALE := 2.0

## One fighter on either side. Mirrors backend/features/minigames/sim.py.
class Unit:
	extends RefCounted
	var kind := ""
	var node: Node2D
	var sprite: AnimatedSprite2D
	var bar: ColorRect
	var hp := 1.0
	var max_hp := 1.0
	var dmg := 1.0
	var rate := 1.0
	var reach := 22.0
	var speed := 0.0
	var cd := 0.0
	var down := 0.0
	var chips := 0
	var drain := 0.0
	var boss := false
	var radius := 0.0
	var telegraph := 0.0
	var charging := false
	var is_party := false
	var is_leader := false
	var drained := 0.0
	var line: Line2D

	func standing() -> bool:
		return hp > 0.0 and down <= 0.0

	func at() -> Vector2:
		return node.position


var phase := Phase.STAIRS
var mods: Dictionary = {}
var d: Dictionary = {}
var room := 0
var rooms_cleared := 0
var doors_broken := 0
var best_cascade := 0
var chips := 0.0
var party: Array[Unit] = []
var enemies: Array[Unit] = []

var _arena := Node2D.new()
var _units := Node2D.new()
var _door_leaf: Sprite2D
var _door_label: Label
var _door_cracks: Line2D
var _chips_label: Label
var _mult_label: Label
var _chips_box: Node2D
var _mult_box: Node2D
var _fire: Array[CPUParticles2D] = []
var _idols: Array[Node2D] = []
var _bomb: TextureButton
var _boss_bar: ColorRect
var _boss_fill: ColorRect
var _smite_cd := 0.0
var _smite_next: Unit  ## a tap during the cooldown: it strikes the moment the bolt is ready
var _focus: Unit
var _note := 0
var _skip := false
var _vignette: TextureRect


func game_id() -> String:
	return "dungeon"


func music_path() -> String:
	return ArcadeFx.PACKS + "shattered-pixel-dungeon/music/sewers_1.ogg"


func setup() -> void:
	mods = run.get("modifiers", {})
	d = catalog.dungeon
	clock_running = false
	world.add_child(_arena)
	_units.y_sort_enabled = true
	world.add_child(_units)
	_vignette = TextureRect.new()
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.55)
	g.fill_to = Vector2(1.05, 0.55)
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(Palette.NIGHT, 0.65))
	g.gradient = grad
	g.width = 240
	g.height = 135
	_vignette.texture = g
	_vignette.size = Vector2(W, H)
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(_vignette)
	_stairs()


## The stairs are the intro; no countdown down here.
func countdown() -> void:
	await get_tree().create_timer(0.05).timeout


func _speed() -> float:
	return 2.5 if holding or _skip else 1.0


func _wait(seconds_: float) -> void:
	await get_tree().create_timer(seconds_ / _speed()).timeout


# --- the stairs: the week's omens ------------------------------------------------------

func _stairs() -> void:
	phase = Phase.STAIRS
	var tiles: String = d.rooms[2].tiles
	var steps := 6
	for i in steps:
		for k in 4:
			var t := Sprite2D.new()
			t.texture = ArcadeFx.tex(tiles, [16, 16, 16, 16])
			t.centered = false
			t.scale = Vector2(2, 2)
			t.position = Vector2(20 + i * 70 + k * 16, 70 + i * 28)
			t.modulate = Color(0.75, 0.7, 0.8).darkened(i * 0.08)
			_arena.add_child(t)
	var torch := ArcadeFx.glow(_arena, Vector2(60, 60), Color("ffb05a"), 70.0, 0.4)
	ArcadeFx.breathe(torch, 0.7, 1.0, 0.8)
	_spawn_party(Vector2(40, 88))
	var omens: Array = mods.get("omens", [])
	var step := 1
	for id: Variant in omens:
		var spec: Dictionary = d.omens.get(str(id), {})
		if spec.is_empty():
			continue
		await _drop_omen(str(id), spec, Vector2(20 + step * 70 + 32, 66 + step * 28))
		if done:
			return
		step += 1
	if omens.is_empty():
		await _wait(0.6)
	# Down they go.
	ArcadeFx.sfx(SND_DESCEND, 1.0, -4.0)
	for u in party:
		var tw := u.node.create_tween()
		tw.tween_property(u.node, "position", u.node.position + Vector2(380, 150), 1.1 / _speed()).set_trans(Tween.TRANS_SINE)
	await _wait(0.9)
	if done:
		return
	ArcadeFx.flash(hud, Palette.NIGHT, 1.0, 0.5)
	_enter_room(0)


func _drop_omen(id: String, spec: Dictionary, at: Vector2) -> void:
	var good := bool(spec.get("good", false))
	var color := Palette.CREAM if good else Palette.BILE
	var o := Node2D.new()
	o.position = at + Vector2(0, -80)
	o.z_index = 30
	_arena.add_child(o)
	ArcadeFx.breathe(ArcadeFx.glow(o, Vector2.ZERO, color, 22.0, 0.6), 0.5, 1.0, 0.9)
	var s := Sprite2D.new()
	s.texture = ArcadeFx.icon(spec.icon)
	s.scale = Vector2(2, 2)
	o.add_child(s)
	var tw := o.create_tween()
	tw.tween_property(o, "position", at, 0.28 / _speed()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	ArcadeFx.sfx(SND_THUNK, randf_range(0.9, 1.1), -4.0)
	ArcadeFx.squash(o)
	ArcadeFx.burst(_arena, at + Vector2(0, 12), Palette.MUTED, 8, 50.0, 0.4)
	ArcadeFx.shake(world, 1.5, 0.1)
	# Each omen acts out what it does to the run.
	match id:
		"packed":
			ArcadeFx.sfx(SND_ROAR, 1.3, -8.0)
			for i in 3:
				var ghost := _enemy_sprite("goblin")
				ghost.position = Vector2(W + 20, 200 + i * 14)
				ghost.flip_h = true
				ghost.modulate = Color(0.3, 0.2, 0.3, 0.8)
				_arena.add_child(ghost)
				var run_tw := ghost.create_tween()
				run_tw.tween_interval(i * 0.08)
				run_tw.tween_property(ghost, "position:x", -30.0, 0.5)
				run_tw.tween_callback(ghost.queue_free)
		"wilting", "withered":
			ArcadeFx.sfx(SND_BAD, 1.0, -6.0)
			for u in party:
				_set_hp(u, u.hp * float(mods.get("party_hp", 1.0)))
				ArcadeFx.burst(_units, u.at() + Vector2(0, -20), Palette.BILE, 6, 40.0, 0.5)
		"leech":
			ArcadeFx.sfx(SND_SLIME, 1.0, -4.0)
			var leech := _enemy_sprite("leech")
			leech.position = at + Vector2(-20, 14)
			_arena.add_child(leech)
			var crawl := leech.create_tween()
			crawl.tween_property(leech, "position:x", at.x + 30, 0.8)
		"landed":
			ArcadeFx.sfx(ArcadeFx.SND_CHANT, 1.0, -6.0)
			ArcadeFx.sfx(SND_GOOD, 1.0, -6.0)
			for u in party:
				_aura(u)
		"streak":
			ArcadeFx.sfx(SND_GOOD, 1.2, -6.0)
	await _wait(0.45)


# --- rooms ----------------------------------------------------------------------------

func _enter_room(index: int) -> void:
	room = index
	phase = Phase.WALK
	for c in _arena.get_children():
		c.queue_free()
	for u in party:
		u.node.queue_free()
	party.clear()
	enemies.clear()
	_idols.clear()
	_fire.clear()
	chips = 0.0
	var spec: Dictionary = d.rooms[index]
	_paint_room(str(spec.tiles))
	_build_door()
	_build_boxes()
	_build_shelf()
	if music_player:
		var path := str(spec.music)
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path)
			if stream is AudioStreamOggVorbis:
				(stream as AudioStreamOggVorbis).loop = true
			music_player.stream = stream
			music_player.play()
	var spots: Dictionary = d.spots
	_spawn_party(Vector2(-40, 170))
	var i := 0
	for u in party:
		var home: Vector2 = Vector2(spots.leader[0], spots.leader[1]) if u.is_leader else Vector2(spots.followers[i - 1][0], spots.followers[i - 1][1])
		var tw := u.node.create_tween()
		tw.tween_property(u.node, "position", home, 0.6).set_trans(Tween.TRANS_SINE)
		i += 1
		if bool(mods.get("buff", false)):
			_aura(u)
	if index == 0 and not _bomb:
		_build_bomb()
	await get_tree().create_timer(0.5).timeout
	if done:
		return
	_spawn_enemies(spec)
	if spec.get("boss", false):
		ArcadeFx.sfx(SND_BOSS, 1.0, -2.0)
		ArcadeFx.shake(world, 3.0, 0.7)
		_boss_intro()
	phase = Phase.FIGHT
	clock_running = true
	if index == 0:
		# The first time: a hand taps the nearest enemy, once, and goes away on any tap.
		await get_tree().create_timer(0.7).timeout
		var first: Unit = _nearest(party[0], enemies) if not party.is_empty() else null
		if first and phase == Phase.FIGHT:
			show_hint(first.at() + Vector2(6, -10))


func _paint_room(tiles: String) -> void:
	var floor_ := Node2D.new()
	_arena.add_child(floor_)
	for y in range(48, int(H), 16):
		for x in range(0, int(W), 16):
			var t := Sprite2D.new()
			var v := (x / 16 * 7 + y / 16 * 11) % 13
			t.texture = ArcadeFx.tex(tiles, [16 * (v % 3) if v < 3 else 0, 0, 16, 16])
			t.centered = false
			t.position = Vector2(x, y)
			t.modulate = Color(0.62, 0.58, 0.7)
			floor_.add_child(t)
	for x in range(0, int(W), 16):
		for row in 2:
			var t := Sprite2D.new()
			t.texture = ArcadeFx.tex(tiles, [((x / 16) % 4) * 16, 80 + row * 16, 16, 16])
			t.centered = false
			t.position = Vector2(x, 16 + row * 16)
			t.modulate = Color(0.55, 0.5, 0.62)
			floor_.add_child(t)
	var top := ColorRect.new()
	top.color = Color("07040b")
	top.size = Vector2(W, 16)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floor_.add_child(top)
	for x: float in [40.0, 440.0]:
		var torch := Sprite2D.new()
		torch.texture = ArcadeFx.tex(ArcadeFx.PACKS + "kenney-roguelike-caves-dungeons/Spritesheet/roguelikeDungeon_transparent.png", [221, 289, 16, 16])
		torch.position = Vector2(x, 36)
		floor_.add_child(torch)
		ArcadeFx.breathe(ArcadeFx.glow(floor_, Vector2(x, 34), Color("ffb05a"), 64.0, 0.4), 0.65, 1.0, 0.6 + randf() * 0.4)
		# Each torch throws a warm pool across the flagstones below it.
		ArcadeFx.breathe(ArcadeFx.glow(floor_, Vector2(x + (24.0 if x < W / 2.0 else -24.0), 92), Color("ff9a3c"), 110.0, 0.3), 0.75, 1.0, 0.7 + randf() * 0.3)
	# The middle of the room is lit from the door; the far corners fall to black.
	ArcadeFx.glow(floor_, Vector2(W / 2.0, 150), Color("b89aff"), 150.0, 0.1)
	for corner in 2:
		var dark := Polygon2D.new()
		var cx := 0.0 if corner == 0 else W
		var k := 1.0 if corner == 0 else -1.0
		dark.polygon = PackedVector2Array([Vector2(cx, H), Vector2(cx + 120 * k, H), Vector2(cx, H - 90)])
		dark.vertex_colors = PackedColorArray([Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0)])
		floor_.add_child(dark)


func _build_door() -> void:
	var door := Node2D.new()
	door.position = DOOR
	_arena.add_child(door)
	var frame := Sprite2D.new()
	frame.texture = ArcadeFx.tex(SHEET_0X72, [32, 224, 32, 16])
	frame.scale = Vector2(1.5, 1.5)
	frame.position = Vector2(0, -36)
	door.add_child(frame)
	_door_leaf = Sprite2D.new()
	_door_leaf.texture = ArcadeFx.tex(SHEET_0X72, [32, 240, 32, 32])
	_door_leaf.scale = Vector2(1.5, 1.5)
	door.add_child(_door_leaf)
	for side: float in [-1.0, 1.0]:
		var post := Sprite2D.new()
		post.texture = ArcadeFx.tex(SHEET_0X72, [16 if side < 0 else 64, 240, 16, 32])
		post.scale = Vector2(1.5, 1.5)
		post.position = Vector2(side * 36, 0)
		door.add_child(post)
	_door_cracks = Line2D.new()
	_door_cracks.width = 1.5
	_door_cracks.default_color = Color("ffd38a")
	door.add_child(_door_cracks)
	_door_label = ArcadeFx.label(_number(_target()), 24, Color("d8c8a8"), true, 6)
	_door_label.reset_size()
	_door_label.position = Vector2(-_door_label.size.x / 2.0, -14)
	door.add_child(_door_label)


func _build_boxes() -> void:
	_chips_box = _box(CHIPS_AT, Palette.CREAM)
	_mult_box = _box(MULT_AT, Palette.BILE)
	_chips_label = _chips_box.get_child(_chips_box.get_child_count() - 1) as Label
	_mult_label = _mult_box.get_child(_mult_box.get_child_count() - 1) as Label
	_chips_label.text = "0"
	_mult_label.text = str(_base_mult())
	var x_mark := ArcadeFx.label("x", 24, Palette.MUTED, true, 4)
	x_mark.position = (CHIPS_AT + MULT_AT) / 2.0 + Vector2(-52, -14)
	_arena.add_child(x_mark)


func _box(at: Vector2, color: Color) -> Node2D:
	var n := Node2D.new()
	n.position = at
	_arena.add_child(n)
	var fire := CPUParticles2D.new()
	fire.emitting = false
	fire.amount = 24
	fire.lifetime = 0.5
	fire.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fire.emission_rect_extents = Vector2(BOX.x / 2.0, 2)
	fire.position = Vector2(0, -BOX.y / 2.0)
	fire.direction = Vector2.UP
	fire.spread = 15.0
	fire.initial_velocity_min = 20.0
	fire.initial_velocity_max = 40.0
	fire.gravity = Vector2(0, -20)
	fire.scale_amount_min = 1.0
	fire.scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.set_color(0, Palette.CREAM)
	ramp.set_color(1, Color(Palette.BILE, 0.0))
	fire.color_ramp = ramp
	n.add_child(fire)
	_fire.append(fire)
	# A dark plate lit from behind in the tally's own color, its icon poking out on the left.
	var halo := ArcadeFx.glow(n, Vector2.ZERO, color, 30.0, 0.22)
	ArcadeFx.breathe(halo, 0.6, 1.0, 1.6)
	var plate := ArcadeFx.plate(n, Rect2(-BOX.x / 2.0 - 10, -BOX.y / 2.0 - 4, BOX.x + 16, BOX.y + 8))
	plate.self_modulate = Color(0.6, 0.55, 0.7).lerp(color, 0.15)
	var icon := Sprite2D.new()
	icon.texture = load(ICONS + ("sword_01a.png" if color == Palette.CREAM else "crystal_01a.png"))
	icon.position = Vector2(-BOX.x / 2.0 - 8, 0)
	n.add_child(icon)
	var l := ArcadeFx.label("0", 24, color, true, 4)
	l.size = Vector2(BOX.x, 18)
	l.position = Vector2(-BOX.x / 2.0, -BOX.y / 2.0 - 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.add_child(l)
	return n


func _build_shelf() -> void:
	var plank := ColorRect.new()
	plank.color = Color("3a2418")
	var idols: Array = mods.get("idols", [])
	plank.size = Vector2(maxf(24.0, idols.size() * 20.0 + 4.0), 3)
	plank.position = Vector2(SHELF_X - 2, SHELF_Y + 10)
	plank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena.add_child(plank)
	for i in idols.size():
		var idol: Dictionary = idols[i]
		var spec: Dictionary = d.idols.get(str(idol.id), {})
		var n := Node2D.new()
		n.position = Vector2(SHELF_X + 8 + i * 20, SHELF_Y)
		_arena.add_child(n)
		var glow := ArcadeFx.glow(n, Vector2.ZERO, Palette.CREAM if bool(idol.get("week", true)) else Palette.MUTED, 12.0, 0.4)
		if bool(idol.get("week", true)):
			ArcadeFx.breathe(glow, 0.75, 1.0, 1.6)
		var s := Sprite2D.new()
		s.texture = ArcadeFx.icon(spec.icon) if spec.has("icon") else null
		n.add_child(s)
		var glyph := ArcadeFx.label(_glyph(idol), 16, Palette.BILE if str(idol.kind) != "chips" else Palette.CREAM, false, 3)
		glyph.reset_size()
		glyph.position = Vector2(-glyph.size.x / 2.0, 6)
		n.add_child(glyph)
		_idols.append(n)
		# The Monday deal: idols drop onto the shelf one after another.
		n.position.y -= 40
		n.modulate.a = 0.0
		var tw := n.create_tween()
		tw.tween_interval(0.12 + i * 0.12)
		tw.tween_property(n, "modulate:a", 1.0, 0.05)
		tw.parallel().tween_property(n, "position:y", SHELF_Y, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			ArcadeFx.sfx(SND_THUNK, 1.0 + i * 0.06, -10.0)
			ArcadeFx.squash(n)
		)


func _glyph(idol: Dictionary) -> String:
	var v := float(idol.value)
	var num := str(int(v)) if is_equal_approx(v, round(v)) else str(snappedf(v, 0.1))
	match str(idol.kind):
		"chips":
			return "+" + num
		"mult":
			return "+" + num
		"mult_per_follower":
			return "+" + num
	return "x" + num


func _build_bomb() -> void:
	var spec: Dictionary = d.party.bomb
	_bomb = TextureButton.new()
	_bomb.texture_normal = ArcadeFx.icon(spec.sprite)
	_bomb.ignore_texture_size = true
	_bomb.stretch_mode = TextureButton.STRETCH_SCALE
	_bomb.size = Vector2(28, 28)
	_bomb.position = BOMB_AT - Vector2(14, 18)
	_bomb.focus_mode = Control.FOCUS_NONE
	_bomb.name = "Bomb"
	_bomb.pivot_offset = Vector2(14, 14)
	hud.add_child(_bomb)
	ArcadeFx.breathe(ArcadeFx.glow(hud, BOMB_AT - Vector2(0, 4), Color("ff9a3c"), 18.0, 0.5), 0.4, 1.0, 0.5)
	var tw := _bomb.create_tween().set_loops()
	tw.tween_property(_bomb, "rotation", 0.15, 0.3)
	tw.tween_property(_bomb, "rotation", -0.15, 0.3)
	_bomb.pressed.connect(_throw_bomb)


# --- units ----------------------------------------------------------------------------

func _spawn_party(at: Vector2) -> void:
	var p: Dictionary = d.party
	var hp_k := float(mods.get("party_hp", 1.0)) if phase != Phase.STAIRS else 1.0
	var dmg_k := float(p.buff_dmg) if bool(mods.get("buff", false)) else 1.0
	var lead := Unit.new()
	lead.kind = "leader"
	lead.is_party = true
	lead.is_leader = true
	_stats(lead, p.leader, hp_k, dmg_k)
	_make_node(lead, ArcadeFx.anim_sprite(p.leader.sprite, 7.0), at)
	BookOverlay.wear_on(lead.sprite)  # the wizard leads in what the book put on him
	party.append(lead)
	var count := int(mods.get("followers", 2))
	for i in count:
		var f := Unit.new()
		f.kind = str(p.followers[i].id)
		f.is_party = true
		_stats(f, p.follower, hp_k, dmg_k)
		_make_node(f, ArcadeFx.anim_sprite(p.followers[i].sprite, 5.0), at + Vector2(20 + i * 14, (i % 2) * 14 - 6))
		party.append(f)


func _stats(u: Unit, s: Dictionary, hp_k: float, dmg_k: float) -> void:
	u.max_hp = float(s.hp) * hp_k
	u.hp = u.max_hp
	u.dmg = float(s.dmg) * dmg_k
	u.rate = float(s.rate)
	u.reach = float(s.get("range", d.melee))
	u.speed = float(s.speed)


func _make_node(u: Unit, sprite: AnimatedSprite2D, at: Vector2) -> void:
	u.node = Node2D.new()
	u.node.position = at
	u.sprite = sprite
	var h := sprite.sprite_frames.get_frame_texture("default", 0).get_height()
	sprite.offset = Vector2(0, -h / 2.0)
	sprite.scale = Vector2(UNIT_SCALE, UNIT_SCALE) * (1.0 if not u.boss else 1.0)
	u.node.add_child(sprite)
	# A pixel shadow under the feet, as wide as the body (a boss stands 1.5x).
	var shadow := Node2D.new()
	var w := float(sprite.sprite_frames.get_frame_texture("default", 0).get_width()) * UNIT_SCALE * (1.5 if u.boss else 1.0)
	var rx := maxi(4, roundi(w * 0.38))
	shadow.draw.connect(func() -> void:
		PixelDraw.ellipse(shadow, Vector2(0, 1), rx, maxi(1, rx / 3), Color(0, 0, 0, 0.4))
		PixelDraw.ellipse(shadow, Vector2(0, 1), maxi(2, rx - 3), maxi(1, rx / 4), Color(0, 0, 0, 0.25)))
	u.node.add_child(shadow)
	u.node.move_child(shadow, 0)  # under the body, but over the floor (a negative z hid it)
	u.bar = ColorRect.new()
	u.bar.color = Palette.BILE if u.is_party else Palette.CREAM
	u.bar.size = Vector2(16, 2)
	u.bar.position = Vector2(-8, 3)
	u.bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	u.bar.visible = u.is_party
	u.node.add_child(u.bar)
	_units.add_child(u.node)


func _enemy_sprite(kind: String) -> AnimatedSprite2D:
	var e: Dictionary = d.enemies[kind]
	var s := ArcadeFx.anim_sprite(e.sprite, 8.0, str(d.enemy_sheet))
	var h := float(e.sprite.rect[3])
	s.offset = Vector2(0, -h / 2.0)
	s.scale = Vector2(UNIT_SCALE, UNIT_SCALE)
	return s


func _spawn_enemies(spec: Dictionary) -> void:
	var names: Array = spec.enemies.duplicate()
	if bool(mods.get("leech", false)) and room == int(d.leech_room):
		names.append("leech")
	var spots: Dictionary = d.spots
	var y0 := float(spots.enemy_y[0])
	var y1 := float(spots.enemy_y[1])
	for i in names.size():
		var kind := str(names[i])
		var e: Dictionary = d.enemies[kind]
		var u := Unit.new()
		u.kind = kind
		u.max_hp = float(e.hp)
		u.hp = u.max_hp
		u.dmg = float(e.dmg)
		u.rate = float(e.rate)
		u.speed = float(e.speed)
		u.chips = int(e.chips)
		u.drain = float(e.get("drain", 0.0))
		u.boss = bool(e.get("boss", false))
		u.radius = float(e.get("slam_radius", 0.0))
		u.telegraph = float(e.get("telegraph_s", 0.0))
		u.reach = u.radius * 0.6 if u.boss else float(d.melee)
		u.cd = u.rate if u.boss else 0.0
		var home := Vector2(float(spots.enemy_x) + (i % 3) * 24.0, y0 + float((i * 37) % int(y1 - y0)))
		if u.boss:
			home = Vector2(360, 160)
		var s := _enemy_sprite(kind)
		s.flip_h = true
		_make_node(u, s, home + Vector2(120, 0))
		if u.boss:
			s.scale = Vector2(UNIT_SCALE, UNIT_SCALE) * 1.5
			_boss_ui(u)
		var tw := u.node.create_tween()
		tw.tween_interval(i * 0.15)
		tw.tween_property(u.node, "position", home, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		enemies.append(u)
		if u.drain > 0.0:
			u.line = Line2D.new()
			u.line.width = 1.5
			u.line.default_color = Color(Palette.BILE, 0.7)
			u.line.z_index = 20
			_arena.add_child(u.line)


## The boss walks in under a letterbox: black bars close top and bottom for a beat, a red pool
## opens on the floor where it stands, and its bar fills from empty. Nothing waits on it.
func _boss_intro() -> void:
	for top: bool in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color("07040b")
		bar.size = Vector2(W, 18)
		bar.position = Vector2(0, -18.0 if top else H)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.z_index = 60
		hud.add_child(bar)
		var tw := bar.create_tween()
		tw.tween_property(bar, "position:y", 0.0 if top else H - 18.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(1.1)
		tw.tween_property(bar, "position:y", -18.0 if top else H, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(bar.queue_free)
	var pool := ArcadeFx.glow(_arena, Vector2(360, 162), Color("ff4f5f"), 100.0, 0.0)
	pool.scale.y *= 0.45
	var pt := pool.create_tween()
	pt.tween_property(pool, "modulate:a", 0.32, 0.6)
	pt.tween_callback(func() -> void: ArcadeFx.breathe(pool, 0.6, 1.0, 1.3))
	ArcadeFx.flash(hud, Color("ff4f5f"), 0.25, 0.3)
	var boss: Unit = null
	for e in enemies:
		if e.boss:
			boss = e
	if _boss_fill and boss:
		_boss_fill.size.x = 0.0
		_boss_fill.create_tween().tween_method(func(k: float) -> void:
			if is_instance_valid(_boss_fill):
				_boss_fill.size.x = 198.0 * k * maxf(0.0, boss.hp) / boss.max_hp, 0.0, 1.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _boss_ui(u: Unit) -> void:
	_boss_bar = ColorRect.new()
	_boss_bar.color = Color("07040b")
	_boss_bar.size = Vector2(200, 6)
	_boss_bar.position = Vector2(140, 60)
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena.add_child(_boss_bar)
	_boss_fill = ColorRect.new()
	_boss_fill.color = Palette.BILE
	_boss_fill.size = Vector2(198, 4)
	_boss_fill.position = Vector2(1, 1)
	_boss_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar.add_child(_boss_fill)
	u.bar.visible = false


func _set_hp(u: Unit, value: float) -> void:
	u.hp = clampf(value, 0.0, u.max_hp)
	u.bar.size.x = 16.0 * u.hp / maxf(1.0, u.max_hp)
	if u.boss and _boss_fill:
		_boss_fill.size.x = 198.0 * u.hp / u.max_hp


func _aura(u: Unit) -> void:
	var a := ArcadeFx.anim_sprite({"rect": [0, 0, 25, 24], "frames": 5, "step": 25}, 10.0, AURA)
	a.position = Vector2(0, -16)
	a.modulate = Color(1.0, 0.9, 0.7, 0.3)
	a.z_index = -1
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	a.material = m
	u.node.add_child(a)
	var g := ArcadeFx.glow(u.node, Vector2(0, -14), Palette.CREAM, 16.0, 0.25)
	g.z_index = -1


# --- the fight ------------------------------------------------------------------------

func tick(delta: float) -> void:
	_smite_cd -= delta
	if phase != Phase.FIGHT:
		_smite_next = null
		return
	if _smite_next != null and _smite_cd <= 0.0:
		var queued := _smite_next
		_smite_next = null
		if queued.hp > 0.0:
			_smite(queued)
	var k := float(mods.get("enemy_speed", 1.0))
	for u in party:
		_party_step(u, delta)
	for e in enemies:
		if e.hp > 0.0:
			_enemy_step(e, delta, k)
	_update_fire()
	var alive := 0
	for e in enemies:
		if e.hp > 0.0:
			alive += 1
	if alive == 0:
		_room_cleared()


func _nearest(me: Unit, others: Array[Unit]) -> Unit:
	var best: Unit = null
	var best_d := INF
	for o in others:
		if not o.standing():
			continue
		var dist := me.at().distance_to(o.at())
		if dist < best_d:
			best_d = dist
			best = o
	return best


func _party_step(u: Unit, delta: float) -> void:
	if u.down > 0.0:
		u.down -= delta
		if u.down <= 0.0:
			_set_hp(u, u.max_hp * 0.5)
			u.sprite.rotation = 0.0
			u.sprite.modulate = Color.WHITE
			ArcadeFx.squash(u.node)
			ArcadeFx.burst(_units, u.at() + Vector2(0, -12), Palette.CREAM, 8, 40.0, 0.4)
		return
	u.cd -= delta
	var target := _focus if _focus != null and _focus.hp > 0.0 and not u.is_leader else _nearest(u, enemies)
	if target == null:
		return
	var dist := u.at().distance_to(target.at())
	if dist > u.reach:
		if u.speed > 0.0:
			u.node.position = u.node.position.move_toward(target.at(), u.speed * delta)
			u.sprite.flip_h = target.at().x < u.at().x
	elif u.cd <= 0.0:
		u.cd = u.rate
		if u.is_leader:
			_bolt(u, target)
		else:
			_melee(u, target)


func _enemy_step(e: Unit, delta: float, k: float) -> void:
	e.cd -= delta * k
	if e.drain > 0.0:
		var took := minf(chips, e.drain * delta)
		chips -= took
		e.drained += took
		e.sprite.scale = Vector2(UNIT_SCALE, UNIT_SCALE) * (1.0 + minf(0.6, e.drained / 30.0))
		_chips_label.text = str(int(chips))
		if e.line:
			var from := e.at() + Vector2(0, -16)
			var to := CHIPS_AT + Vector2(0, 8)
			var pts := PackedVector2Array()
			for i in 7:
				var t := i / 6.0
				pts.append(from.lerp(to, t) + Vector2(0, sin(t * PI + _clock() * 8.0) * 6.0))
			e.line.points = pts
	var target := _nearest(e, party)
	if target == null:
		return
	var dist := e.at().distance_to(target.at())
	e.sprite.flip_h = target.at().x < e.at().x
	if dist > e.reach:
		e.node.position = e.node.position.move_toward(target.at(), e.speed * k * delta)
		return
	if e.boss:
		if not e.charging and e.cd <= e.telegraph:
			_telegraph(e)
		if e.cd <= 0.0:
			e.cd = e.rate
			e.charging = false
			_slam(e)
		return
	if e.cd <= 0.0:
		e.cd = e.rate
		_lunge(e.node, target.at())
		_hurt_party(target, e.dmg)


func _clock() -> float:
	return Time.get_ticks_msec() / 1000.0


func _bolt(u: Unit, target: Unit) -> void:
	ArcadeFx.sfx(SND_BOLT, randf_range(1.1, 1.3), -14.0)
	var b := ArcadeFx.anim_sprite({"rect": [0, 0, 16, 16], "frames": 4, "step": 16}, 14.0, FIREBALL)
	b.position = u.at() + Vector2(10, -30)
	b.z_index = 40
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	b.material = m
	_arena.add_child(b)
	var to := target.at() + Vector2(0, -14)
	b.rotation = (to - b.position).angle()
	var tw := b.create_tween()
	tw.tween_property(b, "position", to, b.position.distance_to(to) / 320.0)
	tw.tween_callback(func() -> void:
		b.queue_free()
		if target.hp > 0.0:
			_hurt_enemy(target, u.dmg, false)
	)


func _melee(u: Unit, target: Unit) -> void:
	_lunge(u.node, target.at())
	ArcadeFx.one_shot(_arena, target.at() + Vector2(0, -14), CUT, 32, 32, 4, 24.0, Color.WHITE, 1.0)
	ArcadeFx.sfx(SND_SLASH, randf_range(0.9, 1.2), -12.0)
	_hurt_enemy(target, u.dmg, false)


func _lunge(n: Node2D, toward: Vector2) -> void:
	var home := n.position
	var step := (toward - home).normalized() * 6.0
	var tw := n.create_tween()
	tw.tween_property(n, "position", home + step, 0.05)
	tw.tween_property(n, "position", home, 0.08)


func _hurt_enemy(e: Unit, amount: float, big: bool) -> void:
	if e.hp <= 0.0:
		return
	_set_hp(e, e.hp - amount)
	e.bar.visible = not e.boss
	e.sprite.modulate = Color(4, 4, 4)
	var tw := e.sprite.create_tween()
	tw.tween_property(e.sprite, "modulate", Color.WHITE, 0.08)
	ArcadeFx.float_text(_arena, e.at() + Vector2(randf_range(-6, 6), -36), str(int(amount)), Palette.CREAM, 24 if big else 16)
	ArcadeFx.sfx(SND_HIT, randf_range(0.9, 1.2), -10.0)
	if e.hp <= 0.0:
		_kill(e)


func _hurt_party(u: Unit, amount: float) -> void:
	if not u.standing():
		return
	_set_hp(u, u.hp - amount)
	u.sprite.modulate = Color(3, 1.2, 1.2)
	var tw := u.sprite.create_tween()
	tw.tween_property(u.sprite, "modulate", Color.WHITE, 0.1)
	if u.hp <= 0.0:
		u.hp = 0.0
		u.down = float(d.party.down_s)
		u.sprite.rotation = PI / 2.0
		u.sprite.modulate = Color(0.5, 0.5, 0.6)
		ArcadeFx.sfx(SND_HURT, 1.4, -8.0)
		ArcadeFx.burst(_units, u.at(), Palette.MUTED, 10, 50.0, 0.5)


func _kill(e: Unit) -> void:
	e.node.z_index = 5
	if e.line:
		e.line.queue_free()
		e.line = null
	if _focus == e:
		_focus = null
	var at := e.at()
	ArcadeFx.sfx(SND_DIE, randf_range(0.9, 1.3), -8.0)
	ArcadeFx.one_shot(_arena, at + Vector2(0, -14), SMOKE, 32, 32, 6, 20.0, Color(1, 1, 1, 0.9), 1.2)
	ArcadeFx.burst(_arena, at + Vector2(0, -12), Palette.CREAM, 14, 120.0, 0.5)
	ArcadeFx.shake(world, 2.0, 0.1)
	var tw := e.node.create_tween()
	tw.tween_property(e.node, "scale", Vector2(1.3, 0.4), 0.08)
	tw.tween_property(e.node, "modulate:a", 0.0, 0.12)
	tw.tween_callback(e.node.queue_free)
	if e.boss:
		_boss_death(e)
		return
	# The kill's chips fly up into the box over the door.
	chips += e.chips + int(e.drained)
	_pip(at + Vector2(0, -20), CHIPS_AT, func() -> void:
		_chips_label.text = str(int(chips))
		ArcadeFx.pop(_chips_box, 0.25)
		ArcadeFx.sfx(ArcadeFx.SND_NOTE, ArcadeFx.scale_pitch(_note), -8.0)
		_note += 1
	)


func _pip(from: Vector2, to: Vector2, landed: Callable) -> void:
	var p := ColorRect.new()
	p.color = Palette.CREAM
	p.size = Vector2(3, 3)
	p.position = from
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.z_index = 70
	_arena.add_child(p)
	ArcadeFx.glow(p, Vector2(1.5, 1.5), Palette.CREAM, 6.0, 0.7)
	var mid := (from + to) / 2.0 + Vector2(randf_range(-40, 40), -30)
	var tw := p.create_tween()
	tw.tween_method(func(t: float) -> void:
		p.position = from.lerp(mid, t).lerp(mid.lerp(to, t), t), 0.0, 1.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		p.queue_free()
		landed.call()
	)


func _telegraph(e: Unit) -> void:
	e.charging = true
	ArcadeFx.sfx(SND_CHARGE, 0.8, -4.0)
	var ring := Line2D.new()
	ring.width = 2.0
	ring.default_color = Color(Palette.BILE, 0.0)
	var pts := PackedVector2Array()
	for i in 25:
		pts.append(Vector2(cos(i * TAU / 24.0), sin(i * TAU / 24.0) * 0.5) * e.radius)
	ring.points = pts
	e.node.add_child(ring)
	var base := e.sprite.scale
	var tw := e.sprite.create_tween()
	tw.tween_property(e.sprite, "scale", base * 1.15, e.telegraph * 0.25)
	tw.tween_property(e.sprite, "scale", base, e.telegraph * 0.25)
	tw.tween_callback(func() -> void: ArcadeFx.sfx(SND_CHARGE, 1.0, -4.0))
	tw.tween_property(e.sprite, "scale", base * 1.25, e.telegraph * 0.25)
	tw.tween_property(e.sprite, "scale", base, e.telegraph * 0.25)
	var rt := ring.create_tween()
	rt.tween_property(ring, "default_color:a", 0.9, e.telegraph * 0.8)
	rt.tween_callback(ring.queue_free)


func _slam(e: Unit) -> void:
	ArcadeFx.sfx(ArcadeFx.SND_BOOM, 0.8, -2.0)
	ArcadeFx.sfx(SND_ROAR, 0.9, -6.0)
	ArcadeFx.shake(world, 4.0, 0.3)
	ArcadeFx.burst(_arena, e.at(), Color("8a7a6a"), 30, 160.0, 0.6)
	ArcadeFx.one_shot(_arena, e.at(), SMOKE, 32, 32, 6, 16.0, Color(1, 1, 1, 0.7), 3.0)
	for u in party:
		if u.standing() and e.at().distance_to(u.at()) <= e.radius:
			_hurt_party(u, e.dmg)


## Tap an enemy: the leader calls lightning down on it, and the followers turn on it too.
func press(pos: Vector2) -> void:
	if phase == Phase.STAIRS:
		_skip = true
		nudge(pos)
		return
	if phase != Phase.FIGHT:
		nudge(pos)  # at the door or between rooms: holding hurries it along
		return
	var best: Unit = null
	var best_d := 26.0
	for e in enemies:
		if e.hp <= 0.0:
			continue
		var dist := pos.distance_to(e.at() + Vector2(0, -16 * (2.0 if e.boss else 1.0)))
		if dist < best_d + (24.0 if e.boss else 0.0):
			best_d = dist
			best = e
	if best == null:
		ArcadeFx.burst(_arena, pos, Palette.MUTED, 4, 30.0, 0.25)
		return
	if _smite_cd > 0.0:
		# Still charging from the last bolt: this one is kept, and the spot sparks now.
		_smite_next = best
		_focus = best
		ArcadeFx.burst(_arena, best.at() + Vector2(0, -16), Color("ffe9a8"), 5, 50.0, 0.2, 0.0)
		ArcadeFx.sfx(ArcadeFx.SND_TICK, 1.3, -12.0)
		return
	_smite(best)


## The leader's lightning on one enemy.
func _smite(best: Unit) -> void:
	_smite_cd = float(d.party.smite.cooldown)
	_focus = best
	var at := best.at()
	ArcadeFx.one_shot(_arena, at + Vector2(0, -34), THUNDER, 20, 28, 8, 26.0, Color(1.0, 0.95, 0.8), 2.0, true)
	ArcadeFx.sfx(SND_ZAP, randf_range(1.0, 1.2), -8.0)
	ArcadeFx.sfx(SND_STRONG, randf_range(0.9, 1.1), -8.0)
	ArcadeFx.hit_stop(get_tree(), 0.04)
	ArcadeFx.shake(world, 2.0, 0.08)
	ArcadeFx.burst(_arena, at + Vector2(0, -14), Color("ffe9a8"), 10, 100.0, 0.35)
	_hurt_enemy(best, float(d.party.smite.dmg), true)


func _throw_bomb() -> void:
	if _bomb == null or not _bomb.visible:
		return
	if phase != Phase.FIGHT or not playing:
		# Nothing to throw it at yet: it rattles and waits for the next room.
		ArcadeFx.sfx(ArcadeFx.SND_CLICK, 0.7, -8.0)
		ArcadeFx.pop(_bomb, 0.3, 0.3)
		return
	var spec: Dictionary = d.party.bomb
	var radius := float(spec.radius)
	var best := Vector2(380, 160)
	var best_n := -1
	for e in enemies:
		if e.hp <= 0.0:
			continue
		var n := 0
		for o in enemies:
			if o.hp > 0.0 and o.at().distance_to(e.at()) <= radius:
				n += 1
		if n > best_n:
			best_n = n
			best = e.at()
	_bomb.visible = false
	ArcadeFx.sfx(ArcadeFx.SND_CLICK, 1.0, -4.0)
	var b := Sprite2D.new()
	b.texture = ArcadeFx.icon(spec.sprite)
	b.scale = Vector2(1.5, 1.5)
	var from := BOMB_AT
	b.position = from
	b.z_index = 60
	_arena.add_child(b)
	var mid := (from + best) / 2.0 + Vector2(0, -90)
	var tw := b.create_tween()
	tw.tween_method(func(t: float) -> void:
		b.position = from.lerp(mid, t).lerp(mid.lerp(best, t), t)
		b.rotation = t * 8.0, 0.0, 1.0, 0.45)
	await tw.finished
	b.queue_free()
	ArcadeFx.one_shot(_arena, best, EXPLOSION, 40, 40, 9, 18.0, Color.WHITE, 2.5)
	ArcadeFx.sfx(ArcadeFx.SND_BOOM, 1.0, 0.0)
	ArcadeFx.flash(hud, Color("ffd38a"), 0.5, 0.25)
	ArcadeFx.shake(world, 5.0, 0.35)
	ArcadeFx.hit_stop(get_tree(), 0.09)
	ArcadeFx.burst(_arena, best, Color("ffb05a"), 40, 200.0, 0.7)
	for e in enemies:
		if e.hp > 0.0 and e.at().distance_to(best) <= radius:
			_hurt_enemy(e, float(spec.dmg), true)


# --- the door -------------------------------------------------------------------------

func _base_mult() -> float:
	return float(mods.get("base_mult", 1))


func _target() -> int:
	var targets: Array = mods.get("targets", d.targets)
	return int(targets[mini(room, targets.size() - 1)])


func _standing_followers() -> int:
	var n := 0
	for u in party:
		if not u.is_leader and u.standing():
			n += 1
	return n


## What the shelf would make of the chips right now: exact, because every idol is fixed.
func _preview() -> float:
	var c := chips
	var m := _base_mult()
	for idol: Dictionary in mods.get("idols", []):
		match str(idol.kind):
			"chips":
				c += float(idol.value)
			"mult":
				m += float(idol.value)
			"mult_per_follower":
				m += float(idol.value) * _standing_followers()
			"xmult":
				m *= float(idol.value)
	return c * m


func _update_fire() -> void:
	var f := clampf(log(maxf(1.0, _preview() / maxf(1.0, _target()))) / log(10.0), 0.0, 3.0)
	var lit := _preview() >= _target()
	for p in _fire:
		p.emitting = lit
		p.initial_velocity_max = 30.0 + 20.0 * f
		p.scale_amount_max = 2.0 + f


func _room_cleared() -> void:
	phase = Phase.CASCADE
	clock_running = false
	_focus = null
	rooms_cleared += 1  # cleared the moment the last enemy falls, even if the player leaves now
	await get_tree().create_timer(0.5).timeout
	if done:
		return
	# Everyone gathers under the door.
	var i := 0
	for u in party:
		if u.down > 0.0:
			u.down = 0.01
		var spot := DOOR + Vector2(-60 + i * 30, 120 + (i % 2) * 10)
		var tw := u.node.create_tween()
		tw.tween_property(u.node, "position", spot, 0.5).set_trans(Tween.TRANS_SINE)
		u.sprite.flip_h = false
		i += 1
	await _wait(0.55)
	await _cascade()
	if done:
		return
	earn(int(d.room_coins[room]), DOOR + Vector2(0, 10))
	await _wait(0.6)
	if done:
		return
	if room < d.rooms.size() - 1:
		for u in party:
			var tw := u.node.create_tween()
			tw.tween_property(u.node, "position", DOOR + Vector2(0, 16), 0.35)
			tw.parallel().tween_property(u.node, "modulate:a", 0.0, 0.35)
		ArcadeFx.sfx(SND_STEP, 1.0, -6.0)
		await _wait(0.4)
		if done:
			return
		ArcadeFx.flash(hud, Palette.NIGHT, 1.0, 0.45)
		_enter_room(room + 1)
	else:
		phase = Phase.OVER
		end_run()


## Balatro's cascade: the shelf fires left to right, the boxes slam, the number pours in.
func _cascade() -> void:
	var c := chips
	var m := _base_mult()
	_note = 0
	var step := 0.30
	var idols: Array = mods.get("idols", [])
	for i in idols.size():
		var idol: Dictionary = idols[i]
		var node: Node2D = _idols[i] if i < _idols.size() else null
		await _wait(step)
		step = maxf(0.12, step - 0.025)
		if node:
			ArcadeFx.pop(node, 0.35)
		var v := float(idol.value)
		match str(idol.kind):
			"chips":
				c += v
				_fly_number(node, "+%d" % int(v), Palette.CREAM, CHIPS_AT)
				_chips_label.text = str(int(c))
				ArcadeFx.pop(_chips_box, 0.3)
				ArcadeFx.sfx(ArcadeFx.SND_NOTE, ArcadeFx.scale_pitch(_note), -6.0)
			"mult", "mult_per_follower":
				var add := v * (_standing_followers() if str(idol.kind) == "mult_per_follower" else 1)
				m += add
				if str(idol.kind) == "mult_per_follower":
					for u in party:
						if not u.is_leader and u.standing():
							ArcadeFx.squash(u.node)
				_fly_number(node, "+%d" % int(add), Palette.BILE, MULT_AT)
				_mult_label.text = _number(m)
				ArcadeFx.pop(_mult_box, 0.3)
				ArcadeFx.sfx(ArcadeFx.SND_NOTE, ArcadeFx.scale_pitch(_note + 7), -9.0)
			"xmult":
				m *= v
				_fly_number(node, "x" + _glyph(idol).substr(1), Palette.BILE, MULT_AT, 32)
				_mult_label.text = _number(m)
				ArcadeFx.hit_stop(get_tree(), 0.07)
				ArcadeFx.pop(_mult_box, 0.4)
				ArcadeFx.shake(world, 2.0, 0.15)
				ArcadeFx.sfx(SND_MULT, 0.85 + 0.05 * i, -4.0)
				ArcadeFx.sfx(ArcadeFx.SND_CHANT, 1.0, -12.0)
				for u in party:
					var hop := u.node.create_tween()
					hop.tween_property(u.node, "position:y", u.node.position.y - 6, 0.08)
					hop.tween_property(u.node, "position:y", u.node.position.y, 0.12)
		_note += 1
	await _wait(0.25)
	# The slam.
	var product := c * m
	var ct := _chips_box.create_tween()
	ct.tween_property(_chips_box, "position:x", CHIPS_AT.x + 6, 0.1)
	var mt := _mult_box.create_tween()
	mt.tween_property(_mult_box, "position:x", MULT_AT.x - 6, 0.1)
	await mt.finished
	ArcadeFx.flash(hud, Palette.CREAM, 0.5, 0.08)
	ArcadeFx.sfx(SND_SLAM, 1.0, -2.0)
	ArcadeFx.shake(world, 2.5, 0.12)
	var target := _target()
	var total := ArcadeFx.label("0", 32, Palette.CREAM, true, 8)
	total.z_index = 80
	_arena.add_child(total)
	var tally := create_tween()
	var last_tick := [0]
	tally.tween_method(func(v: float) -> void:
		total.text = _number(v)
		total.reset_size()
		total.position = DOOR + Vector2(-total.size.x / 2.0, 44)
		var now := Time.get_ticks_msec()
		if now - int(last_tick[0]) > 30:
			last_tick[0] = now
			ArcadeFx.sfx(ArcadeFx.SND_TICK, 1.0 + 0.5 * minf(1.0, v / maxf(1.0, product)), -10.0), 0.0, product, 0.6 / _speed()).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await tally.finished
	best_cascade = maxi(best_cascade, int(product))
	if product >= target:
		doors_broken += 1
		ArcadeFx.sfx(ArcadeFx.SND_BOOM, 1.0, 0.0)
		ArcadeFx.flash(hud, Palette.CREAM, 0.7, 0.12)
		ArcadeFx.shake(world, 4.0, 0.3)
		ArcadeFx.hit_stop(get_tree(), 0.08)
		for k in 3:
			_door_cracks.add_point(Vector2(randf_range(-20, 20), randf_range(-22, 22)))
		_door_leaf.texture = ArcadeFx.tex(SHEET_0X72, [80, 240, 32, 32])
		ArcadeFx.burst(_arena, DOOR, Color("c8b8a0"), 24, 160.0, 0.7)
		ArcadeFx.one_shot(_arena, DOOR, SMOKE, 32, 32, 6, 18.0, Color(1, 1, 1, 0.8), 2.0)
		ArcadeFx.pop(total, 0.5)
		_door_label.add_theme_color_override("font_color", Palette.CREAM)
		ArcadeFx.pop(_door_label, 0.5)
		var f := clampf(log(product / maxf(1.0, target)) / log(10.0), 0.0, 3.0)
		if f >= 1.0:
			ArcadeFx.burst(_arena, DOOR + Vector2(0, -10), Palette.CREAM, int(8 + 24 * f), 60.0 + 30.0 * f, 0.8, -60.0)
			ArcadeFx.sfx(ArcadeFx.SND_CHANT, 1.12, -6.0)
	else:
		ArcadeFx.sfx(SND_DOOR, 0.8, -4.0)
		_door_leaf.texture = ArcadeFx.tex(SHEET_0X72, [80, 240, 32, 32])
	var fade := total.create_tween()
	fade.tween_interval(0.6)
	fade.tween_property(total, "modulate:a", 0.0, 0.3)


func _fly_number(from_node: Node2D, text: String, color: Color, to: Vector2, size := 24) -> void:
	var start := from_node.position if from_node else to + Vector2(0, -20)
	var l := ArcadeFx.label(text, size, color, true, 5)
	l.z_index = 75
	_arena.add_child(l)
	l.reset_size()
	l.position = start - l.size / 2.0
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2(1.6, 1.6)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position", to - l.size / 2.0 + Vector2(0, 12), 0.18 / _speed()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)


static func _number(v: float) -> String:
	if v >= 1e9:
		var e := floori(log(v) / log(10.0))
		return "%.1fe%d" % [v / pow(10.0, e), e]
	var s := str(int(round(v)))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


# --- the boss -------------------------------------------------------------------------

func _boss_death(e: Unit) -> void:
	var at := e.at()
	chips += e.chips
	ArcadeFx.sfx(SND_DEATH, 1.0, 0.0)
	Sfx.play("boss_down")
	ArcadeFx.hit_stop(get_tree(), 0.15)
	ArcadeFx.flash(hud, Palette.CREAM, 0.8, 0.5)
	ArcadeFx.shake(world, 5.0, 0.8)
	if _boss_bar:
		_boss_bar.queue_free()
		_boss_bar = null
	for i in 5:
		var spot := at + Vector2(randf_range(-30, 30), randf_range(-60, 0))
		ArcadeFx.one_shot(_arena, spot, EXPLOSION, 40, 40, 9, 20.0, Color.WHITE, 1.5)
		ArcadeFx.sfx(ArcadeFx.SND_BOOM, randf_range(0.8, 1.2), -6.0)
		await get_tree().create_timer(0.14).timeout
	_pip(at + Vector2(0, -40), CHIPS_AT, func() -> void:
		_chips_label.text = str(int(chips))
		ArcadeFx.pop(_chips_box, 0.4)
		ArcadeFx.sfx(ArcadeFx.SND_NOTE, ArcadeFx.scale_pitch(_note), -6.0)
	)


## The day's cosmetic: a chest drops where the boss fell, wobbles, leaks light, and opens.
func reveal(body: Dictionary) -> void:
	var items: Array = body.get("items", [])
	if items.is_empty():
		return
	var item: Dictionary = items[0]
	var tier := str(item.tier)
	var color := ArcadeFx.rarity_color(tier)
	var spot := Vector2(300, 170)
	var chest := Sprite2D.new()
	chest.texture = ArcadeFx.tex(SHEET_0X72, [304, 416, 16, 16])
	chest.scale = Vector2(3, 3)
	chest.position = spot + Vector2(0, -160)
	chest.z_index = 70
	_arena.add_child(chest)
	var fall := chest.create_tween()
	fall.tween_property(chest, "position", spot, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fall.finished
	ArcadeFx.sfx(SND_THUNK, 0.8, 0.0)
	ArcadeFx.squash(chest, Vector2(3, 3))
	ArcadeFx.burst(_arena, spot + Vector2(0, 20), Palette.MUTED, 12, 70.0, 0.5)
	ArcadeFx.shake(world, 1.5, 0.1)
	var beams := Node2D.new()
	beams.position = spot
	beams.z_index = 65
	_arena.add_child(beams)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in 5:
		var beam := ColorRect.new()
		beam.color = Color(color, 0.0)
		beam.size = Vector2(3, 70)
		beam.position = Vector2(-1.5, -70)
		beam.material = m
		beam.pivot_offset = Vector2(1.5, 70)
		beam.rotation = -0.6 + i * 0.3
		beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
		beams.add_child(beam)
		beam.create_tween().tween_property(beam, "color:a", 0.55, 0.5)
	var wob := chest.create_tween()
	for i in 6:
		wob.tween_property(chest, "rotation", 0.12 if i % 2 == 0 else -0.12, 0.05)
	wob.tween_property(chest, "rotation", 0.0, 0.05)
	await wob.finished
	ArcadeFx.sfx(SND_CHEST, 1.0, -2.0)
	chest.texture = ArcadeFx.tex(SHEET_0X72, [336, 416, 16, 16])
	ArcadeFx.flash(hud, color, 0.5, 0.25)
	ArcadeFx.hit_stop(get_tree(), 0.08)
	ArcadeFx.burst(_arena, spot, color, 36, 180.0, 0.9)
	ArcadeFx.sfx(ArcadeFx.STINGERS.get(tier, ArcadeFx.STINGERS.common), 1.0, -2.0)
	if tier == "legendary" or tier == "mythic":
		ArcadeFx.sfx(ArcadeFx.SND_JACKPOT, 1.0, -4.0)
		ArcadeFx.shake(world, 4.0, 0.4)
	var pillar := ColorRect.new()
	pillar.color = Color(ArcadeFx.rarity_color(tier), 0.5)
	pillar.size = Vector2(18, 220)
	pillar.position = spot + Vector2(-9, -220)
	pillar.material = m
	pillar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena.add_child(pillar)
	var icon := Sprite2D.new()
	icon.texture = ArcadeFx.icon(item.icon)
	icon.position = spot + Vector2(0, -10)
	icon.z_index = 90
	_arena.add_child(icon)
	ArcadeFx.breathe(ArcadeFx.glow(icon, Vector2.ZERO, color, 26.0, 0.9), 0.6, 1.0, 0.5)
	var rise := icon.create_tween()
	rise.tween_property(icon, "position", spot + Vector2(0, -60), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise.parallel().tween_property(icon, "scale", Vector2(3, 3), 0.5)
	await get_tree().create_timer(1.6).timeout
	var out := icon.create_tween()
	out.tween_property(icon, "scale", Vector2(1.5, 1.5), 0.3)
	out.parallel().tween_property(pillar, "color:a", 0.0, 0.4)
	out.parallel().tween_property(beams, "modulate:a", 0.0, 0.4)


func result() -> Dictionary:
	return {"rooms_cleared": rooms_cleared, "doors_broken": doors_broken, "best_cascade": best_cascade}


func haul() -> Array:
	var out: Array = []
	out.append({"texture": ArcadeFx.tex(SHEET_0X72, [80, 240, 32, 32]), "count": rooms_cleared})
	return out
