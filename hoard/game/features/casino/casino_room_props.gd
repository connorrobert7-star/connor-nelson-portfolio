class_name CasinoRoomProps
## The small living things in the casino room: candles with eyes, the neon sign, the lamp
## over the table, the moonlit door, and the odds painted on the wall.

const Art := preload("res://features/casino/casino_room_art.gd")


## A candle from the vk sheet (columns 0-6), or the eye on a stand (column 7), which blinks
## and watches the leader. Position is its feet.
class Candle:
	extends Node2D

	var column := 0
	var watch: Node2D  # the leader, for the eye
	var pool: Sprite2D  # its light on the floor (the room makes it), flickering with the flame
	var _glow: Sprite2D
	var _halo: Sprite2D
	var _eye: Sprite2D
	var _t := 0.0
	var _blink := 2.0
	var _seed := randf() * 10.0

	func _init(col: int) -> void:
		column = col

	func _ready() -> void:
		var x := column * 18.0
		if column == 7:
			Art.sprite(Art.region(Art.CANDLES, Rect2(127, 22, 18, 19)), Vector2(-9, -19), self, false)
			_eye = Art.sprite(Art.region(Art.CANDLES, Rect2(129, 4, 15, 18)), Vector2(0, -28), self)
			_glow = Art.glow(self, Vector2(0, -28), Color("e8e0ff"), 12, 0.25)
		else:
			Art.sprite(Art.region(Art.CANDLES, Rect2(x, 0, 18, 41)), Vector2(-9, -41), self, false)
			var tops: Array[int] = [1, 9, 15, 3, 1, 8, 15, 5]
			var flame_y: float = -41.0 + tops[column] + 4.0
			_glow = Art.glow(self, Vector2(0, flame_y), Art.CANDLE, 9, 0.55)
			_halo = Art.glow(self, Vector2(0, flame_y), Art.CANDLE, 30, 0.10)
		_glow.z_index = 3

	func _process(delta: float) -> void:
		_t += delta
		var flick := 0.85 + 0.15 * sin(_t * 13.0 + _seed) * sin(_t * 7.3 + _seed * 2.0)
		if pool:
			# Two frequencies: a slow sway of the flame and a quick shiver.
			var sway := 0.12 * sin(_t * 2.3 + _seed) + 0.07 * sin(_t * 17.0 + _seed * 3.0)
			pool.modulate.a = 0.15 * (0.85 + sway)
			pool.scale.x = pool.scale.y * 2.0 * (1.0 + sway * 0.25)
		if _halo:
			_glow.modulate.a = 0.5 * flick
			_halo.modulate.a = 0.11 * flick
			_glow.scale = Vector2.ONE * (18.0 / 64.0) * (0.9 + flick * 0.15)
		if _eye:
			_blink -= delta
			if _blink <= 0.0:
				_blink = randf_range(2.5, 6.0)
			var shut := _blink < 0.13
			_eye.scale.y = 0.15 if shut else 1.0
			_glow.modulate.a = 0.0 if shut else 0.22 + 0.06 * sin(_t * 2.0)
			if watch and is_instance_valid(watch):
				var d := watch.global_position - global_position
				_eye.position = Vector2(0, -28) + Vector2(clampf(roundf(d.x / 90.0), -1, 1), clampf(roundf(d.y / 90.0), -1, 1))


## The neon chalice on the wall (karsiori Sign 7, pink), flickering through its own frames.
class Neon:
	extends Node2D

	const FRAME := Vector2(28, 34)
	const COUNT := 19

	var _frames: Array[Texture2D] = []
	var _bright: Array[float] = []
	var _sprite := Sprite2D.new()
	var _glow: Sprite2D
	var _wall: Sprite2D  # pink spilling over the bricks
	var _floor: Sprite2D  # and down onto the risers and the floor below
	var _t := 0.0
	var _i := 0
	var _hold := 0.0
	var _lit := 1.0

	func _ready() -> void:
		_frames = Art.strip(Art.NEON, Rect2(Vector2.ZERO, FRAME), COUNT)
		var img := Art.tex(Art.NEON).get_image()
		for i in COUNT:
			var sum := 0.0
			for y in range(0, int(FRAME.y), 2):
				for x in range(0, int(FRAME.x), 2):
					var c := img.get_pixel(i * int(FRAME.x) + x, y)
					sum += c.a * c.get_luminance()
			_bright.append(sum)
		var top: float = _bright.max()
		for i in COUNT:
			_bright[i] = _bright[i] / maxf(top, 0.001)
		_sprite.texture = _frames[0]
		add_child(_sprite)
		_glow = Art.glow(self, Vector2(0, 2), Palette.PINK, 30, 0.0)
		_glow.z_index = 3
		_sprite.z_index = 3
		_wall = Art.glow(self, Vector2(0, 4), Palette.PINK, 100, 0.0, 0.8)
		_floor = Art.glow(self, Vector2(4, 70), Palette.PINK, 84, 0.0, 0.45)
		_floor.z_index = 3

	func _process(delta: float) -> void:
		_t += delta
		_hold -= delta
		if _hold <= 0.0:
			_i = (_i + 1) % COUNT
			# Mostly lit, with the sign's own stutter, and now and then a long buzz on.
			_hold = 0.09 if _bright[_i] < 0.6 else randf_range(0.09, 0.7)
			# The tube drops out with a buzz.
			if _bright[_i] < 0.45 and _lit >= 0.45:
				Art.play("kenney-interface-sounds/Audio/glitch_00%d.ogg" % (1 + randi() % 4), randf_range(0.8, 1.2), -30.0)
			_lit = _bright[_i]
		_sprite.texture = _frames[_i]
		var hum := 0.02 * sin(_t * 40.0)
		_glow.modulate.a = 0.34 * _bright[_i] + hum
		_wall.modulate.a = 0.20 * _bright[_i] + hum * 0.5
		_floor.modulate.a = 0.07 * _bright[_i]


## The one hanging lamp over the table: a brass shade, a cone of light that sways a little,
## dust turning in it. It takes the special shell's color during the tell.
class Lamp:
	extends Node2D

	const SHADE_Y := 52.0
	const CONE_H := 118.0

	var tint := Color.TRANSPARENT
	var _cone := Sprite2D.new()
	var _bulb: Sprite2D
	var _pool: Sprite2D
	var _dust := CPUParticles2D.new()
	var _t := 0.0
	var _color := Art.LAMP

	func _ready() -> void:
		_cone.texture = Art.cone(10, 156, CONE_H)
		_cone.material = Art.additive()
		_cone.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_cone.centered = false
		_cone.position = Vector2(-_cone.texture.get_width() / 2.0, SHADE_Y + 5)
		_cone.z_index = 2
		add_child(_cone)
		_pool = Art.glow(self, Vector2(0, SHADE_Y + 84), Art.LAMP, 86, 0.16, 0.45)
		_pool.z_index = 2
		_bulb = Art.glow(self, Vector2(0, SHADE_Y + 5), Art.LAMP, 12, 0.8)
		_bulb.z_index = 4
		_dust.amount = 38
		_dust.lifetime = 5.0
		_dust.preprocess = 5.0
		_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		_dust.emission_rect_extents = Vector2(40, 40)
		_dust.position = Vector2(0, SHADE_Y + 60)
		_dust.direction = Vector2(0.3, -1)
		_dust.spread = 60.0
		_dust.gravity = Vector2.ZERO
		_dust.initial_velocity_min = 1.0
		_dust.initial_velocity_max = 4.0
		_dust.scale_amount_min = 1.0
		_dust.scale_amount_max = 1.0
		# Motes twinkle in and out as they turn through the light.
		_dust.color_ramp = _twinkle()
		_dust.color = Color(Art.LAMP, 0.8)
		_dust.material = Art.additive()
		_dust.z_index = 2
		add_child(_dust)

	func _process(delta: float) -> void:
		_t += delta
		rotation = sin(_t * 0.7) * 0.012
		var want := Art.LAMP if tint.a == 0.0 else Art.LAMP.lerp(tint, 0.85)
		_color = _color.lerp(want, minf(1.0, delta * 2.0))
		var flick := 1.0 + 0.04 * sin(_t * 23.0) * sin(_t * 3.1)
		var hot := 1.0 if tint.a == 0.0 else 1.5
		_cone.modulate = Color(_color, 0.30 * flick * hot)
		_pool.modulate = Color(_color, 0.16 * flick * hot)
		_bulb.modulate = Color(_color, 0.95)
		_dust.color = Color(_color, 0.8)
		queue_redraw()

	static func _twinkle() -> Gradient:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.2, 0.45, 0.6, 0.8, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.3), Color(1, 1, 1, 1), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0)])
		return g

	func _draw() -> void:
		# The cord fades up into the dark; the shade is a brass dish.
		for y in range(0, int(SHADE_Y), 2):
			var a := clampf((float(y) - SHADE_Y + 18.0) / 18.0, 0.0, 1.0)
			draw_rect(Rect2(0, y, 1, 2), Color(0.25, 0.2, 0.18, a))
		var s := PackedVector2Array([Vector2(-3, SHADE_Y), Vector2(4, SHADE_Y), Vector2(9, SHADE_Y + 6), Vector2(-8, SHADE_Y + 6)])
		draw_colored_polygon(s, Color("7a5a2a"))
		draw_line(Vector2(-8, SHADE_Y + 6), Vector2(9, SHADE_Y + 6), Color("c99a4a"), 1.0)
		draw_rect(Rect2(-2, SHADE_Y + 6, 5, 2), _color.lightened(0.3))


## The way out: a gap in the bottom wall with moonlight and fog leaking in from the village.
class Door:
	extends Node2D

	var _fog := CPUParticles2D.new()
	var _glow: Sprite2D
	var _t := 0.0

	func _ready() -> void:
		_glow = Art.glow(self, Vector2(0, 2), Art.MOON, 30, 0.30, 0.6)
		_glow.z_index = 2
		_fog.amount = 14
		_fog.lifetime = 4.0
		_fog.preprocess = 4.0
		_fog.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		_fog.emission_rect_extents = Vector2(14, 2)
		_fog.direction = Vector2(0, -1)
		_fog.spread = 35.0
		_fog.gravity = Vector2.ZERO
		_fog.initial_velocity_min = 3.0
		_fog.initial_velocity_max = 7.0
		_fog.scale_amount_min = 2.0
		_fog.scale_amount_max = 4.0
		_fog.color = Color(Art.MOON, 0.10)
		_fog.material = Art.additive()
		_fog.z_index = 2
		add_child(_fog)

	func _process(delta: float) -> void:
		_t += delta
		_glow.modulate.a = 0.26 + 0.05 * sin(_t * 1.7)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(-16, -2, 32, 18), Color("06040a"))
		draw_rect(Rect2(-17, -2, 1, 18), Color("4a3a2a"))
		draw_rect(Rect2(16, -2, 1, 18), Color("4a3a2a"))
		for i in 5:
			var a := 0.10 - i * 0.018
			draw_rect(Rect2(-15, 13 - i * 3, 30, 3), Color(Art.MOON, a))


## The published odds, painted straight on the wall: each tier's gem and its average rate.
## (The exact odds of the next pull are the pegs and the box, and Vex says them.)
class Odds:
	extends Node2D

	## Average rates over 100,000 cases (backend/features/casino/test_casino.py checks them).
	const RATES := [["common", "67%"], ["rare", "22%"], ["epic", "7.5%"], ["legendary", "2.2%"], ["mythic", "0.7%"]]
	const PITCH := 9.0

	var _t := 0.0
	var _glows: Array[Sprite2D] = []

	func _ready() -> void:
		for i in RATES.size():
			var y := i * PITCH
			var l := Art.paint(self, str(RATES[i][1]), Vector2(12, y + 2), Art.PAINT, 10, Art.FONT_BIG)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			l.position.x = 2
			var g := Art.glow(self, Vector2(-6, y + 3.5), Art.rarity(RATES[i][0]), 7, 0.2 + i * 0.05)
			g.z_index = 3
			_glows.append(g)

	func _process(delta: float) -> void:
		_t += delta
		for i in _glows.size():
			_glows[i].modulate.a = (0.18 + i * 0.05) * (0.85 + 0.15 * sin(_t * 2.0 + i))
		queue_redraw()

	func _draw() -> void:
		for i in RATES.size():
			var c := Art.rarity(RATES[i][0])
			var p := Vector2(-6, i * PITCH + 3.5)
			var gem := PackedVector2Array([p + Vector2(0, -3), p + Vector2(3, 0), p + Vector2(0, 3), p + Vector2(-3, 0)])
			draw_colored_polygon(gem, c)
			draw_rect(Rect2(p + Vector2(-1, -2), Vector2(1, 1)), c.lightened(0.6))
			# Drips under the paint, a little wrong.
			if i % 2 == 1:
				draw_rect(Rect2(p + Vector2(14 + i * 2, 4), Vector2(1, 2 + i)), Color(Art.PAINT, 0.35))


## A low haze: two banks of fog drifting across the floor in opposite directions, so the
## light pools have air to hang in.
class Haze:
	extends Node2D

	const FOG := "ninja-adventure/FX/Environment/Fog.png"
	var _banks: Array[Sprite2D] = []
	var _t := 0.0

	func _ready() -> void:
		for i in 2:
			var s := Sprite2D.new()
			s.texture = Art.tex(FOG)
			s.centered = false
			s.scale = Vector2(2, 1)
			s.material = Art.additive()
			s.modulate = Color(Art.MOON, 0.04)
			s.flip_h = i == 1
			s.z_index = 2
			add_child(s)
			_banks.append(s)

	func _process(delta: float) -> void:
		_t += delta
		var w := 640.0
		for i in _banks.size():
			var dir := 1.0 if i == 0 else -1.0
			var x := fposmod(_t * (5.0 + i * 2.0) * dir + i * 220.0, w) - w / 2.0
			_banks[i].position = Vector2(roundf(x), 92.0 + i * 46.0 + roundf(sin(_t * 0.3 + i) * 4.0))
			_banks[i].modulate.a = 0.035 + 0.01 * sin(_t * 0.5 + i * 2.0)


## A slow pink sheen sliding down the oxblood runner: the sign's light on the pile.
class Sheen:
	extends Node2D

	const RUNNER := Rect2(224, 160, 32, 96)
	var _t := 0.0

	func _init() -> void:
		material = Art.additive()

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		# A diagonal streak a few pixels wide, one pass every 6 s, fading at both ends.
		var k := fmod(_t, 6.0) / 6.0
		var head := RUNNER.position.y - 20.0 + k * (RUNNER.size.y + 60.0)
		for row in int(RUNNER.size.y):
			var y := RUNNER.position.y + row
			var x := RUNNER.position.x + (head - y) * 1.6
			var fade := sin(clampf((y - RUNNER.position.y) / RUNNER.size.y, 0.0, 1.0) * PI)
			var lo := maxf(x, RUNNER.position.x)
			var hi := minf(x + 6.0, RUNNER.end.x)
			if hi > lo:
				draw_rect(Rect2(lo, y, hi - lo, 1), Color(Palette.PINK, 0.10 * fade))
			# A fainter second line just behind it.
			var lo2 := maxf(x - 9.0, RUNNER.position.x)
			var hi2 := minf(x - 7.0, RUNNER.end.x)
			if hi2 > lo2:
				draw_rect(Rect2(lo2, y, hi2 - lo2, 1), Color(Palette.PINK, 0.06 * fade))
