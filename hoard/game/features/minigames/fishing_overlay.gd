class_name FishingOverlay
extends MinigameOverlay
## Fishing at night: tap the water to cast, wait for the bite, tap to hook, then hold to
## keep the hook inside the fish's glowing zone until the meter fills. Rarer fish twitch.

enum Phase { IDLE, FLYING, WAITING, BITE, REEL, LANDING }

const WATER_Y := 92.0
const DOCK_Y := 152.0
const DOCK_END := 124.0
const ROD_TIP := Vector2(150, 104)
const WATER := ArcadeFx.PACKS + "ninja-adventure/Backgrounds/Tilesets/TilesetWater.png"
const RIVER := preload("res://features/village/river.gdshader")
const DOCK_WOOD := Color("5a3a2a")
const OMG := ArcadeFx.PACKS + "tiopalada-emoji-pack-1/20250405emoticons-SheetOMG.png"
const CURSORS := ArcadeFx.PACKS + "kenney-cursor-pixel-pack/Tilemap/tilemap_packed.png"
const SND_SPLASH := ArcadeFx.PACKS + "fisheefects/splash.ogg"
const SND_BLOOP := ArcadeFx.PACKS + "fisheefects/bloop.ogg"
const SND_REEL := ArcadeFx.PACKS + "fisheefects/reel.ogg"
const SND_POINT := ArcadeFx.PACKS + "fisheefects/point_normal.ogg"
const SND_SPECIAL := ArcadeFx.PACKS + "fisheefects/point_special.ogg"
const SND_UHOH := ArcadeFx.PACKS + "fisheefects/uhoh.ogg"
const SND_CAST := ArcadeFx.PACKS + "ninja-adventure/Audio/Sounds/Whoosh & Slash/Whoosh.ogg"
const BAR_H := 104.0
const BAR_W := 14.0
const MARKER_H := 10.0
const LIFT := 420.0
const FALL := 330.0

var phase := Phase.IDLE
var caught: Array[String] = []

var _rng := RandomNumberGenerator.new()
var _fish: Dictionary = {}
var _wait := 0.0
var _nibble := 0.0
var _window := 0.0
var _clock := 0.0
var _bobber := Node2D.new()
var _bob_home := Vector2.ZERO
var _line := Line2D.new()
var _aim := Node2D.new()
var _leader: AnimatedSprite2D
var _omg: AnimatedSprite2D
var _shadow: Sprite2D
var _bar := Node2D.new()
var _zone := ColorRect.new()
var _zone_fish: Sprite2D
var _zone_glow: Sprite2D
var _marker := ColorRect.new()
var _meter := ColorRect.new()
var _zone_y := 0.0
var _zone_target := 0.0
var _marker_y := 0.0
var _marker_v := 0.0
var _fill := 0.0
var _reel_tick := 0.0
var _hand: Sprite2D
var _ever_held := false
var _catch_x := 14.0


func game_id() -> String:
	return "fishing"


func music_path() -> String:
	return ArcadeFx.PACKS + "ninja-adventure/Audio/Music/18 - Aquatic.ogg"


func setup() -> void:
	_rng.seed = int(run.seed)
	_build_night()
	_build_water()
	_build_dock()
	_build_tackle()
	_build_bar()
	_enter_idle()


func _build_night() -> void:
	var sky := ColorRect.new()
	sky.color = Color("0b0714")
	sky.size = Vector2(W, WATER_Y)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(sky)
	for i in 40:
		var s := ColorRect.new()
		s.color = Color(Palette.CREAM, randf_range(0.2, 0.8))
		s.size = Vector2.ONE * (2 if randf() < 0.15 else 1)
		s.position = Vector2(randf() * W, randf() * (WATER_Y - 20))
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		world.add_child(s)
		ArcadeFx.breathe(s, 0.2, 1.0, randf_range(0.8, 3.0))
	var moon := ArcadeFx.glow(world, Vector2(372, 34), Palette.CREAM, 30.0, 0.5)
	ArcadeFx.breathe(moon, 0.8, 1.0, 4.0)
	var disc := Sprite2D.new()
	disc.texture = ArcadeFx.tex(ArcadeFx.PACKS + "kenney-particle-pack/PNG (Transparent)/circle_05.png", [0, 0, 0, 0])
	disc.scale = Vector2(0.5, 0.5)
	disc.position = Vector2(372, 34)
	disc.modulate = Color("f6ead2")
	world.add_child(disc)
	# Far shore: low hills and a few crooked trees, black against the sky.
	var hills := Polygon2D.new()
	hills.color = Color("1a1028")
	var pts := PackedVector2Array([Vector2(0, WATER_Y)])
	for x in range(0, int(W) + 24, 24):
		pts.append(Vector2(x, WATER_Y - 10 - 8 * sin(x * 0.021) - 5 * sin(x * 0.067 + 1.0)))
	pts.append(Vector2(W, WATER_Y))
	hills.polygon = pts
	world.add_child(hills)
	var near := Polygon2D.new()
	near.color = Color("0f0918")
	var near_pts := PackedVector2Array([Vector2(160, WATER_Y)])
	for x in range(160, int(W) + 16, 16):
		near_pts.append(Vector2(x, WATER_Y - 4 - 5 * absf(sin(x * 0.05)) - 3 * sin(x * 0.11)))
	near_pts.append(Vector2(W, WATER_Y))
	near.polygon = near_pts
	world.add_child(near)
	# Fireflies drifting over the water.
	var flies := CPUParticles2D.new()
	flies.amount = 14
	flies.lifetime = 5.0
	flies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	flies.emission_rect_extents = Vector2(W / 2.0, 30)
	flies.position = Vector2(W / 2.0, WATER_Y + 10)
	flies.gravity = Vector2.ZERO
	flies.initial_velocity_min = 3.0
	flies.initial_velocity_max = 10.0
	flies.spread = 180.0
	flies.scale_amount_min = 1.0
	flies.scale_amount_max = 2.0
	flies.color = Color("e8ff8a")
	var fly_ramp := Gradient.new()
	fly_ramp.set_color(0, Color(1, 1, 0.6, 0.0))
	fly_ramp.add_point(0.5, Color(1, 1, 0.6, 1.0))
	fly_ramp.set_color(fly_ramp.get_point_count() - 1, Color(1, 1, 0.6, 0.0))
	flies.color_ramp = fly_ramp
	flies.z_index = 30
	world.add_child(flies)


func _build_water() -> void:
	# Deep night water in whole-pixel bands, lightest at the far shore, then the village's
	# river glass over it: crisp ripples drifting, two slow highlight bands, and a mirror
	# under the moon and the dock lamp.
	var deep := Node2D.new()
	deep.draw.connect(func() -> void:
		var top := Color("1e2a52")
		var low := Color("0a0e22")
		var y := WATER_Y
		var band := 0
		while y < H:
			var hgt := 3.0 + band
			deep.draw_rect(Rect2(0, y, W, hgt), top.lerp(low, clampf((y - WATER_Y) / (H - WATER_Y), 0.0, 1.0)))
			y += hgt
			band += 1
		deep.draw_rect(Rect2(0, WATER_Y, W, 1), Color("5a6aa8"))
	)
	world.add_child(deep)
	var glass := ColorRect.new()
	glass.position = Vector2(0, WATER_Y)
	glass.size = Vector2(W, H - WATER_Y)
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = RIVER
	mat.set_shader_parameter("size", glass.size)
	mat.set_shader_parameter("tint", Color(0.5, 0.66, 1.0))
	var xs := PackedFloat32Array([372.0, 14.0])
	var cols := PackedColorArray([Color(Palette.CREAM, 1.0), Color("ffb05a")])
	for i in range(xs.size(), 12):
		xs.append(-999.0)
		cols.append(Color(0, 0, 0, 0))
	mat.set_shader_parameter("refl_x", xs)
	mat.set_shader_parameter("refl_col", cols)
	glass.material = mat
	world.add_child(glass)
	# The moon on the water: a column of shimmering strokes.
	for i in 14:
		var stroke := ColorRect.new()
		stroke.color = Color(Palette.CREAM, 0.0)
		stroke.size = Vector2(randf_range(6, 16), 1)
		stroke.position = Vector2(372 - stroke.size.x / 2.0 + randf_range(-6, 6), WATER_Y + 6 + i * 7)
		stroke.mouse_filter = Control.MOUSE_FILTER_IGNORE
		world.add_child(stroke)
		var tw := stroke.create_tween().set_loops()
		tw.tween_interval(randf() * 1.5)
		tw.tween_property(stroke, "color:a", 0.55 - i * 0.03, 0.4)
		tw.tween_property(stroke, "color:a", 0.0, 0.6)
	# Rings open on the water now and then, wherever something moved.
	var rings := Timer.new()
	rings.wait_time = 0.7
	rings.autostart = true
	rings.timeout.connect(func() -> void:
		_ring(Vector2(randf_range(170, 470), randf_range(WATER_Y + 12, H - 12)), randf_range(6.0, 14.0)))
	add_child(rings)
	# Shadows of fish that never stop circling.
	for i in 5:
		var s := _fish_shadow()
		s.position = Vector2(randf_range(190, 460), randf_range(WATER_Y + 20, H - 16))
		world.add_child(s)
		_swim(s)


func _fish_shadow() -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = ArcadeFx.tex(ArcadeFx.PACKS + "kenney-particle-pack/PNG (Transparent)/circle_05.png", [0, 0, 0, 0])
	s.scale = Vector2(0.45, 0.16)
	s.modulate = Color(0.0, 0.02, 0.05, 0.55)
	return s


func _swim(s: Sprite2D) -> void:
	var to := Vector2(randf_range(180, 470), randf_range(WATER_Y + 20, H - 14))
	s.scale.x = absf(s.scale.x) * (1.0 if to.x > s.position.x else -1.0)
	var tw := s.create_tween()
	tw.tween_property(s, "position", to, randf_range(2.5, 5.0)).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		if randf() < 0.3:
			ArcadeFx.burst(world, s.position, Color(0.7, 0.85, 1.0, 0.8), 5, 40.0, 0.4)
		_swim(s))


func _build_dock() -> void:
	# The dock, drawn board by board: weathered planks with lit ends and dark seams, a front
	# beam in shadow, posts going down into the water with rings where they meet it.
	var dock := Node2D.new()
	dock.draw.connect(func() -> void:
		var end := DOCK_END + 8.0
		var x := 0.0
		var k := 0
		while x < end:
			var w := minf(8.0, end - x)
			var h := absi(k * 73856093) % 7
			var c := DOCK_WOOD.lerp(DOCK_WOOD.darkened(0.3), float(h % 4) / 5.0)
			dock.draw_rect(Rect2(x, DOCK_Y, w - 1, 20), c)
			dock.draw_rect(Rect2(x, DOCK_Y, w - 1, 1), c.lightened(0.3))
			dock.draw_rect(Rect2(x + w - 1, DOCK_Y, 1, 20), Color("1a100c"))
			if h % 3 == 0:
				dock.draw_rect(Rect2(x + 3, DOCK_Y + 3, 1, 1), Color("1a100c"))
				dock.draw_rect(Rect2(x + 3, DOCK_Y + 16, 1, 1), Color("1a100c"))
			if h == 5:
				dock.draw_rect(Rect2(x + 1, DOCK_Y + 9, w - 3, 1), c.darkened(0.25))
			x += w
			k += 1
		dock.draw_rect(Rect2(0, DOCK_Y + 20, end, 8), DOCK_WOOD.darkened(0.55))
		dock.draw_rect(Rect2(0, DOCK_Y + 20, end, 1), DOCK_WOOD.darkened(0.2))
		dock.draw_rect(Rect2(0, DOCK_Y + 28, end, 2), Color(0, 0, 0, 0.45))
		for px in range(10, int(end), 32):
			dock.draw_rect(Rect2(px, DOCK_Y + 28, 5, 34), Color("24160f"))
			dock.draw_rect(Rect2(px, DOCK_Y + 28, 1, 34), Color("3e281c"))
			dock.draw_rect(Rect2(px - 3, DOCK_Y + 62, 11, 1), Color(0.6, 0.75, 1.0, 0.35))
	)
	world.add_child(dock)
	var lamp := Sprite2D.new()
	lamp.texture = ArcadeFx.tex(ArcadeFx.PACKS + "kenney-roguelike-caves-dungeons/Spritesheet/roguelikeDungeon_transparent.png", [221, 289, 16, 16])
	lamp.position = Vector2(14, DOCK_Y - 8)
	world.add_child(lamp)
	ArcadeFx.breathe(ArcadeFx.glow(world, Vector2(14, DOCK_Y - 12), Color("ffb05a"), 56.0, 0.5), 0.7, 1.0, 1.1)
	_leader = ArcadeFx.anim_sprite({"rect": [128, 164, 16, 28], "frames": 4, "step": 16}, 6.0,
		ArcadeFx.PACKS + "0x72-dungeontileset-ii/0x72_DungeonTilesetII_v1.7/0x72_DungeonTilesetII_v1.7.png")
	_leader.offset = Vector2(0, -14)
	_leader.position = Vector2(DOCK_END, DOCK_Y + 4)
	_leader.z_index = 10
	world.add_child(_leader)
	_omg = ArcadeFx.anim_sprite({"rect": [0, 32, 32, 32], "frames": 5, "step": 32}, 12.0, OMG)
	_omg.position = Vector2(DOCK_END, DOCK_Y - 40)
	_omg.visible = false
	_omg.z_index = 40
	world.add_child(_omg)


func _build_tackle() -> void:
	var rod := Line2D.new()
	rod.width = 1.5
	rod.default_color = Color("8a5a3a")
	rod.points = PackedVector2Array([Vector2(DOCK_END + 4, DOCK_Y - 10), ROD_TIP])
	rod.z_index = 11
	world.add_child(rod)
	_line.width = 1.0
	_line.default_color = Color(Palette.CREAM, 0.7)
	_line.z_index = 11
	world.add_child(_line)
	var red := ColorRect.new()
	red.color = Color("e0304e")
	red.size = Vector2(5, 3)
	red.position = Vector2(-2.5, -3)
	red.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bobber.add_child(red)
	var white := ColorRect.new()
	white.color = Palette.CREAM
	white.size = Vector2(5, 2)
	white.position = Vector2(-2.5, 0)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bobber.add_child(white)
	ArcadeFx.glow(_bobber, Vector2.ZERO, Palette.CREAM, 8.0, 0.4)
	_bobber.z_index = 12
	world.add_child(_bobber)
	# Where a cast lands if you tap the sky: a ring that breathes on the water.
	var ring := Line2D.new()
	ring.width = 1.0
	ring.default_color = Color(Palette.CREAM, 0.7)
	var pts := PackedVector2Array()
	for i in 17:
		pts.append(Vector2(cos(i * TAU / 16) * 10, sin(i * TAU / 16) * 4))
	ring.points = pts
	_aim.add_child(ring)
	_aim.position = Vector2(300, 178)
	world.add_child(_aim)
	var tw := _aim.create_tween().set_loops()
	tw.tween_property(_aim, "scale", Vector2(1.4, 1.4), 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_aim, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)


func _build_bar() -> void:
	_bar.visible = false
	_bar.z_index = 50
	world.add_child(_bar)
	var frame := ColorRect.new()
	frame.color = Palette.MUTED
	frame.size = Vector2(BAR_W + 4, BAR_H + 4)
	frame.position = Vector2(-2, -2)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(frame)
	var inner := ColorRect.new()
	inner.color = Color("0b0714")
	inner.size = Vector2(BAR_W, BAR_H)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(inner)
	_zone_glow = ArcadeFx.glow(_bar, Vector2(BAR_W / 2.0, 0), Palette.CREAM, 16.0, 0.5)
	_zone.color = Color(Palette.TEAL, 0.55)
	_zone.size = Vector2(BAR_W, 20)
	_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(_zone)
	_zone_fish = Sprite2D.new()
	_zone_fish.scale = Vector2(0.75, 0.75)
	_bar.add_child(_zone_fish)
	_marker.color = Palette.CREAM
	_marker.size = Vector2(BAR_W + 6, 3)
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(_marker)
	var meter_back := ColorRect.new()
	meter_back.color = Color("0b0714")
	meter_back.size = Vector2(5, BAR_H)
	meter_back.position = Vector2(BAR_W + 5, 0)
	meter_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(meter_back)
	_meter.color = Palette.BILE
	_meter.size = Vector2(5, 0)
	_meter.position = Vector2(BAR_W + 5, BAR_H)
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(_meter)
	_hand = Sprite2D.new()
	_hand.texture = ArcadeFx.tex(CURSORS, [272, 96, 16, 16])
	_hand.position = Vector2(BAR_W + 22, BAR_H - 12)
	_bar.add_child(_hand)


# --- the cast -------------------------------------------------------------------------

func _enter_idle() -> void:
	phase = Phase.IDLE
	_bar.visible = false
	_omg.visible = false
	_aim.visible = true
	_bobber.position = ROD_TIP + Vector2(4, 30)
	_bobber.visible = true
	_bob_home = _bobber.position


func press(pos: Vector2) -> void:
	match phase:
		Phase.IDLE:
			var to := pos if pos.y > WATER_Y + 10 and pos.x > 170 else _aim.position
			to.x = clampf(to.x, 180, 456)
			to.y = clampf(to.y, WATER_Y + 16, H - 22)
			_cast(to)
		Phase.WAITING:
			# Too early: the bobber jerks and the wait starts over a little.
			_bobber.position.y -= 3
			_wait += 0.4
			ArcadeFx.sfx(SND_BLOOP, 0.7, -10.0)
		Phase.BITE:
			_hook()
		Phase.REEL:
			_ever_held = true
			_hand.visible = false


func _cast(to: Vector2) -> void:
	phase = Phase.FLYING
	_aim.visible = false
	ArcadeFx.sfx(SND_CAST, 1.2, -6.0)
	ArcadeFx.squash(_leader)
	var from := ROD_TIP
	var mid := (from + to) / 2.0 + Vector2(0, -60)
	var tw := _bobber.create_tween()
	tw.tween_method(func(t: float) -> void:
		_bobber.position = from.lerp(mid, t).lerp(mid.lerp(to, t), t), 0.0, 1.0, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		_bob_home = to
		ArcadeFx.sfx(SND_SPLASH, randf_range(0.95, 1.1), -6.0)
		ArcadeFx.burst(world, to, Color(0.7, 0.85, 1.0), 12, 70.0, 0.45)
		_ring(to, 18.0)
		_fish = _pick_fish()
		_wait = _rng.randf_range(float(catalog.fish.bite.wait_min_s), float(catalog.fish.bite.wait_max_s))
		_nibble = _rng.randf_range(0.3, 0.8)
		phase = Phase.WAITING
		_approach()
	)


func _pick_fish() -> Dictionary:
	var total := 0.0
	for f: Dictionary in catalog.fish.fish:
		total += float(f.weight)
	var roll := _rng.randf() * total
	for f: Dictionary in catalog.fish.fish:
		roll -= float(f.weight)
		if roll <= 0.0:
			return f
	return catalog.fish.fish[0]


## The fish's shadow drifts toward the bobber while you wait.
func _approach() -> void:
	if _shadow:
		_shadow.queue_free()
	_shadow = _fish_shadow()
	_shadow.position = _bob_home + Vector2(_rng.randf_range(-60, 60), _rng.randf_range(20, 40))
	var sizes := {"common": 0.0, "rare": 0.3, "epic": 0.6, "legendary": 1.1}
	var big: float = 1.0 + float(sizes.get(str(_fish.tier), 0.0))
	_shadow.scale = Vector2(0.45, 0.16) * big
	world.add_child(_shadow)
	var tw := _shadow.create_tween()
	tw.tween_property(_shadow, "position", _bob_home + Vector2(0, 6), maxf(0.5, _wait - 0.2)).set_trans(Tween.TRANS_SINE)


func _ring(at: Vector2, radius: float) -> void:
	var ring := Line2D.new()
	ring.width = 1.0
	ring.default_color = Color(0.8, 0.9, 1.0, 0.8)
	var pts := PackedVector2Array()
	for i in 17:
		pts.append(Vector2(cos(i * TAU / 16) * radius / 4.0, sin(i * TAU / 16) * radius / 10.0))
	ring.points = pts
	ring.position = at
	world.add_child(ring)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector2(4, 4), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.6)
	tw.tween_callback(ring.queue_free)


func _bite() -> void:
	phase = Phase.BITE
	_window = float(catalog.fish.bite.hook_window_s)
	ArcadeFx.sfx(SND_SPLASH, 0.8, -2.0)
	ArcadeFx.sfx(SND_SPECIAL, 1.0, -6.0)
	ArcadeFx.burst(world, _bob_home, Color(0.8, 0.9, 1.0), 20, 110.0, 0.5)
	_ring(_bob_home, 26.0)
	_omg.visible = true
	_omg.play("default")
	ArcadeFx.pop(_omg, 0.5)
	ArcadeFx.shake(world, 2.0, 0.15)


func _hook() -> void:
	phase = Phase.REEL
	_omg.visible = false
	ArcadeFx.sfx(SND_REEL, 1.0, -4.0)
	ArcadeFx.hit_stop(get_tree(), 0.05)
	ArcadeFx.shake(world, 3.0, 0.15)
	_fill = float(catalog.fish.bite.start_fill)
	_zone.size.y = float(_fish.zone) * 2.0
	_zone_y = BAR_H - _zone.size.y - 10.0
	_zone_target = _rng.randf_range(0.0, BAR_H - _zone.size.y)
	_marker_y = BAR_H - MARKER_H
	_marker_v = 0.0
	_zone_fish.texture = ArcadeFx.icon(_fish.icon)
	var tier := str(_fish.tier)
	_zone_glow.modulate = Color(ArcadeFx.rarity_color(tier), 0.6 if tier != "common" else 0.25)
	_bar.position = Vector2(clampf(_bob_home.x + 26, 200, W - 40), clampf(_bob_home.y - BAR_H / 2.0, 22, H - BAR_H - 26))
	_bar.visible = true
	_bar.scale = Vector2(0.2, 1.0)
	var tw := _bar.create_tween()
	tw.tween_property(_bar, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hand.visible = not _ever_held


func release(_pos: Vector2) -> void:
	pass


# --- every frame ----------------------------------------------------------------------

func tick(delta: float) -> void:
	_clock += delta
	_draw_line()
	match phase:
		Phase.IDLE:
			_bobber.position = _bob_home + Vector2(0, sin(_clock * 3.0) * 1.0)
		Phase.WAITING:
			_wait -= delta
			_nibble -= delta
			var dip := 0.0
			if _nibble <= 0.0:
				_nibble = _rng.randf_range(0.5, 1.2)
				dip = 2.0
				ArcadeFx.sfx(SND_BLOOP, randf_range(0.9, 1.2), -12.0)
				_ring(_bob_home, 8.0)
			_bobber.position = _bob_home + Vector2(0, sin(_clock * 3.0) * 1.0 + dip)
			if _wait <= 0.0:
				_bite()
		Phase.BITE:
			_window -= delta
			_bobber.position = _bob_home + Vector2(randf_range(-1, 1), 4 + sin(_clock * 40.0) * 2.0)
			if _window <= 0.0:
				_escape()
		Phase.REEL:
			_reel(delta)


func _draw_line() -> void:
	var a := ROD_TIP
	var b := _bobber.position
	var taut := phase == Phase.REEL or phase == Phase.BITE
	var sag := 0.0 if taut else 14.0
	var pts := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		pts.append(a.lerp(b, t) + Vector2(0, sin(t * PI) * sag))
	_line.points = pts


func _reel(delta: float) -> void:
	# The zone wanders; a twitchy fish darts.
	var speed := float(_fish.speed)
	if _rng.randf() < float(_fish.twitch) * delta * 10.0:
		_zone_target = _rng.randf_range(0.0, BAR_H - _zone.size.y)
		speed *= 3.0
	elif absf(_zone_y - _zone_target) < 2.0:
		_zone_target = _rng.randf_range(0.0, BAR_H - _zone.size.y)
	_zone_y = move_toward(_zone_y, _zone_target, speed * delta)
	_zone.position.y = _zone_y
	_zone_fish.position = Vector2(BAR_W / 2.0 + sin(_clock * 20.0), _zone_y + _zone.size.y / 2.0)
	_zone_glow.position = _zone_fish.position
	# Hold to lift the hook; let go and it sinks.
	_marker_v += (-LIFT if holding else FALL) * delta
	_marker_v = clampf(_marker_v, -160.0, 160.0)
	_marker_y += _marker_v * delta
	if _marker_y < 0.0:
		_marker_y = 0.0
		_marker_v = 0.0
	elif _marker_y > BAR_H - MARKER_H:
		_marker_y = BAR_H - MARKER_H
		_marker_v = 0.0
	_marker.position = Vector2(-3, _marker_y + MARKER_H / 2.0 - 1.5)
	var inside := _marker_y + MARKER_H > _zone_y and _marker_y < _zone_y + _zone.size.y
	var bite: Dictionary = catalog.fish.bite
	if inside:
		_fill += delta / float(bite.fill_s)
		_zone.color = Color(Palette.TEAL, 0.85 + 0.15 * sin(_clock * 30.0))
		_reel_tick -= delta
		if _reel_tick <= 0.0:
			_reel_tick = 0.09
			ArcadeFx.sfx(ArcadeFx.SND_TICK, 0.8 + _fill * 0.8, -14.0)
	else:
		_fill -= delta / float(bite.drain_s)
		_zone.color = Color(Palette.TEAL, 0.4)
	_fill = clampf(_fill, 0.0, 1.0)
	_meter.size.y = _fill * BAR_H
	_meter.position.y = BAR_H - _meter.size.y
	_meter.color = Palette.BILE.lerp(Palette.CREAM, _fill)
	# The bobber thrashes on the surface.
	_bobber.position = _bob_home + Vector2(sin(_clock * 23.0) * 3.0, sin(_clock * 31.0) * 2.0)
	if randf() < delta * 6.0:
		ArcadeFx.burst(world, _bob_home, Color(0.7, 0.85, 1.0, 0.9), 4, 60.0, 0.35)
	_hand.texture = ArcadeFx.tex(CURSORS, [272, 112 if int(_clock * 4.0) % 2 == 0 else 96, 16, 16])
	if _fill >= 1.0:
		_land()
	elif _fill <= 0.0:
		_escape()


func _escape() -> void:
	phase = Phase.LANDING
	_bar.visible = false
	_omg.visible = false
	ArcadeFx.sfx(SND_UHOH, 1.0, -6.0)
	if _shadow:
		var tw := _shadow.create_tween()
		tw.tween_property(_shadow, "position", _shadow.position + Vector2(80, 30), 0.4)
		tw.parallel().tween_property(_shadow, "modulate:a", 0.0, 0.4)
	_reel_in(0.4)


func _land() -> void:
	phase = Phase.LANDING
	_bar.visible = false
	var tier := str(_fish.tier)
	var color := ArcadeFx.rarity_color(tier)
	var value := int(_fish.coins)
	caught.append(str(_fish.id))
	if _shadow:
		_shadow.queue_free()
		_shadow = null
	ArcadeFx.sfx(SND_SPLASH, 0.9, -2.0)
	ArcadeFx.sfx(SND_POINT if tier == "common" else SND_SPECIAL, 1.0, -4.0)
	ArcadeFx.sfx(ArcadeFx.STINGERS.get(tier, ArcadeFx.STINGERS.common), 1.0, -8.0)
	ArcadeFx.burst(world, _bob_home, Color(0.8, 0.9, 1.0), 26, 140.0, 0.6)
	# The fish leaps out, flips over the dock and lands in the row of the day's catch.
	var fish := Sprite2D.new()
	fish.texture = ArcadeFx.icon(_fish.icon)
	fish.position = _bob_home
	fish.z_index = 60
	fish.scale = Vector2(2, 2)
	world.add_child(fish)
	var halo := ArcadeFx.glow(fish, Vector2.ZERO, color, 14.0, 0.8 if tier != "common" else 0.3)
	ArcadeFx.breathe(halo, 0.5, 1.0, 0.3)
	var from := _bob_home
	var to := Vector2(_catch_x, DOCK_Y + 8)
	_catch_x = _catch_x + 12.0 if _catch_x < DOCK_END - 20 else 14.0
	var mid := Vector2((from.x + to.x) / 2.0, minf(from.y, to.y) - 80.0)
	if tier == "epic" or tier == "legendary":
		ArcadeFx.hit_stop(get_tree(), 0.12)
		ArcadeFx.flash(hud, color, 0.4 if tier == "legendary" else 0.25, 0.4)
		ArcadeFx.shake(world, 4.0 if tier == "legendary" else 3.0, 0.3)
		ArcadeFx.burst(world, from, color, 40, 180.0, 0.9)
	var tw := fish.create_tween()
	tw.tween_method(func(t: float) -> void:
		fish.position = from.lerp(mid, t).lerp(mid.lerp(to, t), t)
		fish.rotation = t * TAU * 1.5, 0.0, 1.0, 0.75 if tier in ["epic", "legendary"] else 0.55)
	tw.parallel().tween_property(fish, "scale", Vector2.ONE, 0.55)
	tw.tween_callback(func() -> void:
		fish.rotation = 0.0
		ArcadeFx.squash(fish)
		ArcadeFx.sfx(ArcadeFx.PACKS + "kenney-impact-sounds/Audio/impactSoft_medium_000.ogg", 1.2, -8.0)
		ArcadeFx.bob(fish, 1.0, 0.5 + randf() * 0.4)
	)
	ArcadeFx.float_text(world, from + Vector2(0, -16), "+%d" % value, ArcadeFx.BRASS, 16)
	earn(value, from)
	_reel_in(0.8)


func _reel_in(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not playing:
		return
	var tw := _bobber.create_tween()
	var start := _bobber.position
	tw.tween_method(func(t: float) -> void:
		_bobber.position = start.lerp(ROD_TIP + Vector2(4, 30), t), 0.0, 1.0, 0.3)
	await tw.finished
	if playing:
		_enter_idle()


func result() -> Dictionary:
	return {"caught": caught}


func haul() -> Array:
	var counts: Dictionary = {}
	for id in caught:
		counts[id] = int(counts.get(id, 0)) + 1
	var out: Array = []
	for f: Dictionary in catalog.fish.fish:
		if counts.has(f.id):
			out.append({"texture": ArcadeFx.icon(f.icon), "count": counts[f.id]})
	return out
