class_name VillageArt
## Pack art, painted numbers and small juice helpers for the village hub.
## Every picture is a region of a sheet in res://art/packs; packs keep their own colors.

const PACKS := "res://art/packs/"
const TOWN := PACKS + "kenney-tiny-town/Tilemap/tilemap_packed.png"
const HOUSES := PACKS + "ninja-adventure/Backgrounds/Tilesets/TilesetHouse.png"
const RUINS := PACKS + "ninja-adventure/Backgrounds/Tilesets/TilesetVillageAbandoned.png"
const NATURE := PACKS + "ninja-adventure/Backgrounds/Tilesets/TilesetNature.png"
const TOWERS := PACKS + "ninja-adventure/Backgrounds/Tilesets/TilesetTowers.png"
const FLOOR := PACKS + "ninja-adventure/Backgrounds/Tilesets/TilesetFloor.png"
const FLOOR_DETAIL := PACKS + "ninja-adventure/Backgrounds/Tilesets/TilesetFloorDetail.png"
const FIELD := PACKS + "ninja-adventure/Backgrounds/Tilesets/TilesetField.png"
const WATER := PACKS + "ninja-adventure/Backgrounds/Tilesets/TilesetWater.png"
const FLAG := PACKS + "ninja-adventure/Backgrounds/Animated/Flag/FlagRed16x16.png"
const SMOKE := PACKS + "ninja-adventure/FX/Smoke/Smoke/SpriteSheet.png"
const SPIRIT := PACKS + "ninja-adventure/FX/Magic/Spirit/SpriteSheet.png"
const SPARK_RING := PACKS + "ninja-adventure/FX/Magic/Circle/SpriteSheetSpark.png"
const FLAME := PACKS + "ninja-adventure/FX/Elemental/Flam/SpriteSheet.png"
const FOG := PACKS + "ninja-adventure/FX/Environment/Fog.png"
const LEAF := PACKS + "ninja-adventure/FX/Particle/Leaf.png"
const DCSS := PACKS + "dcss-altars-features/dungeon/"
const HOODED_A := PACKS + "dawnlike/Characters/Humanoid0.png"
const HOODED_B := PACKS + "dawnlike/Characters/Humanoid1.png"
const SPECKS := PACKS + "shattered-pixel-dungeon/effects/specks.png"
const NEON := PACKS + "karsiori-neon-signs/"

const FONT_PRICE := PACKS + "google-pixel-fonts-ofl/jersey10/Jersey10-Regular.ttf"
const FONT_SMALL := PACKS + "font-m5x7/m5x7.ttf"
const FONT_TABLE := PACKS + "font-monogram/ttf/monogram-extended.ttf"

## Bone white is real money; brass is play coins (INFLUENCES, decisions 6 and 7).
const BONE := Color("f6ead2")
const BRASS := Color("e8b04a")
const EMBER := Color("ff8a3d")
const SICK := Color("b6e04a")
const VIOLET := Color("c08cff")
const INK := Color("120c18")

static var _textures: Dictionary = {}
static var _fonts: Dictionary = {}
static var _add: CanvasItemMaterial
static var _soft: GradientTexture2D


## Whole dollars for numbers painted on things ("$8,450"); the stats screen keeps cents.
static func dollars(cents: Variant) -> String:
	var c := int(cents)
	return Money.fmt(c - c % 100).trim_suffix(".00")


static func sheet(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]


## A region of a sheet, in pixels.
static func tex(path: String, rect: Rect2) -> AtlasTexture:
	var key := "%s|%s" % [path, rect]
	if not _textures.has(key):
		var a := AtlasTexture.new()
		a.atlas = sheet(path)
		a.region = rect
		_textures[key] = a
	return _textures[key]


## A block of 16 px tiles from a sheet.
static func tiles(path: String, col: int, row: int, w := 1, h := 1) -> AtlasTexture:
	return tex(path, Rect2(col * 16, row * 16, w * 16, h * 16))


## A sprite whose feet are at `pos` (bottom-center anchored).
static func sprite(parent: Node, t: Texture2D, pos: Vector2, flip := false) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = t
	s.offset = Vector2(0, -t.get_height() / 2.0)
	s.position = pos
	s.flip_h = flip
	parent.add_child(s)
	return s


static func additive() -> CanvasItemMaterial:
	if _add == null:
		_add = CanvasItemMaterial.new()
		_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add


## A smooth radial falloff for pools of light (the Kenney masks have rings that read as
## smudges when they're big and overlap on the dark ground).
static func soft_light() -> Texture2D:
	if _soft == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.25, Color(1, 1, 1, 0.62))
		g.add_point(0.6, Color(1, 1, 1, 0.18))
		_soft = GradientTexture2D.new()
		_soft.gradient = g
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(0.5, 0.0)
		_soft.width = 128
		_soft.height = 128
	return _soft


## A soft pool of light, added on top. `size` is its diameter in px.
static func glow(parent: Node, pos: Vector2, color: Color, size := 48.0, breathe := 0.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = soft_light()
	s.material = additive()
	s.modulate = color
	s.position = pos
	s.scale = Vector2.ONE * size / 128.0
	parent.add_child(s)
	if breathe > 0.0:
		var tw := s.create_tween().set_loops()
		tw.tween_property(s, "modulate:a", color.a * (1.0 - breathe), 0.7 + randf() * 0.7).set_trans(Tween.TRANS_SINE)
		tw.tween_property(s, "modulate:a", color.a, 0.7 + randf() * 0.7).set_trans(Tween.TRANS_SINE)
	return s


## An animation from equal frames laid out in a grid (left to right, top to bottom).
static func frames(path: String, frame: Vector2i, count: int, fps := 8.0, cols := 0, origin := Vector2i.ZERO) -> SpriteFrames:
	var key := "frames|%s|%s|%d|%s|%s" % [path, frame, count, cols, origin]
	if _textures.has(key):
		return _textures[key]
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", fps)
	var t := sheet(path)
	var per_row := cols if cols > 0 else (t.get_width() - origin.x) / frame.x if t else 1
	for i in count:
		var c := i % per_row
		var r := i / per_row
		sf.add_frame("default", tex(path, Rect2(origin + Vector2i(c * frame.x, r * frame.y), frame)))
	_textures[key] = sf
	return sf


static func anim(parent: Node, sf: SpriteFrames, pos: Vector2, random_start := true) -> AnimatedSprite2D:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = sf
	a.position = pos
	parent.add_child(a)
	a.play("default")
	if random_start:
		a.frame = randi() % maxi(1, sf.get_frame_count("default"))
	return a


## An animated karsiori neon sign, flickering on its own timing.
static func neon(parent: Node, file: String, frame: Vector2i, count: int, pos: Vector2, fps := 10.0, cols := 0) -> AnimatedSprite2D:
	var a := anim(parent, frames(NEON + file, frame, count, fps, cols), pos)
	a.material = additive()
	return a


static func font(path: String) -> FontFile:
	if not _fonts.has(path):
		var f: FontFile = load(path)
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f.hinting = TextServer.HINTING_NONE
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_fonts[path] = f
	return _fonts[path]


## A number or word painted onto a thing in the world, centered on `pos`.
static func paint(parent: Node, text: String, pos: Vector2, color := BONE, size := 10, path := FONT_PRICE, outline := 2) -> Label:
	var ls := LabelSettings.new()
	ls.font = font(path)
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = INK
	var l := Label.new()
	l.label_settings = ls
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(120, size + 4)
	l.position = pos - l.size / 2.0
	l.pivot_offset = l.size / 2.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## Gentle idle bob on anything.
static func bob(n: CanvasItem, amount := 1.0, period := 1.6, phase := -1.0) -> Tween:
	var base: float = n.position.y
	var tw := n.create_tween().set_loops()
	if phase < 0.0:
		phase = randf() * period
	tw.tween_interval(phase * 0.25)
	tw.tween_property(n, "position:y", base - amount, period / 2.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "position:y", base, period / 2.0).set_trans(Tween.TRANS_SINE)
	return tw


## Breathe a node's scale around its current scale.
static func breathe(n: CanvasItem, amount := 0.02, period := 2.4) -> Tween:
	var base: Vector2 = n.scale
	var tw := n.create_tween().set_loops()
	tw.tween_property(n, "scale", base * (1.0 + amount), period / 2.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "scale", base, period / 2.0).set_trans(Tween.TRANS_SINE)
	return tw


## Squash and pop back, for taps and landings.
static func squash(n: CanvasItem, to := Vector2(1.2, 0.8), seconds := 0.18) -> void:
	var base: Vector2 = n.scale
	var tw := n.create_tween()
	tw.tween_property(n, "scale", base * to, seconds * 0.35)
	tw.tween_property(n, "scale", base, seconds * 0.65).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## A one-shot spray of square pixels in world space.
static func burst(parent: Node, pos: Vector2, color: Color, amount := 16, speed := 60.0, life := 0.6, gravity := 160.0) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.95
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = color
	p.position = pos
	p.z_index = 20
	parent.add_child(p)
	p.emitting = true
	p.create_tween().tween_interval(life + 0.3).finished.connect(p.queue_free)


## Floating embers or motes rising forever from a spot.
static func embers(parent: Node, pos: Vector2, color: Color, width := 16.0, amount := 6, rise := 18.0) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = 2.2
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(width / 2.0, 2)
	p.direction = Vector2.UP
	p.spread = 25.0
	p.initial_velocity_min = rise * 0.5
	p.initial_velocity_max = rise
	p.gravity = Vector2.ZERO
	p.color = color
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color, 0.0))
	p.color_ramp = ramp
	p.position = pos
	p.material = additive()
	parent.add_child(p)
	return p


## A short pack sound; the village never uses brass coin sounds for real money.
static func sfx(path: String, pitch := 1.0, db := -8.0) -> void:
	Sfx.play_path(PACKS + path, pitch, db)


## Wait on a tween bound to `n`: if `n` leaves the game first, the wait just never ends
## (a scene timer would resume a function whose object is gone).
static func wait(n: Node, seconds: float) -> void:
	await n.create_tween().tween_interval(seconds).finished


## Hold the game still for a beat. Real time, so it can't get stuck.
static func hit_stop(tree: SceneTree, seconds := 0.07) -> void:
	Engine.time_scale = 0.05
	await tree.create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0
