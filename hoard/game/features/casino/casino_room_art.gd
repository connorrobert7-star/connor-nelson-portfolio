class_name CasinoRoomArt
## Pack regions, soft light and painted words for the casino room. Every sprite is a region
## of a sheet in res://art/packs (packs keep their own colors); light and glow are additive
## sprites, so the room stays dark and machines sit in pools of light.

const PACKS := "res://art/packs/"

# Sheets the room uses (paths under PACKS).
const DARK := "0x72-dungeontileset-ii/dark_kosinaz/DarkDungeon.png"
const EXT := "0x72-dungeontileset-ii/extended_niji/dungeontileset-extended.png"
const NECRO := "shattered-pixel-dungeon/sprites/necromancer.png"
const CHESTS := "whimsy-hallow-chests/15_Ready_to_use_Treasure_Chests_Spritesheet.png"
const CANDLES := "vk-candles-with-eyes/candles_with_eyes.png"
const NEON := "karsiori-neon-signs/Sign 7/Sign 7 Glow - PINK.png"
const WHEEL := "draganas-prize-wheel-64/wheel_texture.png"
const CARDS := "kenney-playing-cards/Tilesheet/cardsMedium_tilemap_packed.png"
const ICONS := "kyrise-rpg-icons-16/spritesheet/spritesheet_16x16.png"
const SUMMON := "srzolda-magic-summons/green_idle-Sheet.png"
const PENGUIN := "grafxkid-critters-penguin/penguin_edit.png"
const NINJA := "ninja-adventure/Actor/Character/%s/SpriteSheet.png"
const ANIMAL := "ninja-adventure/Actor/Animal/%s/SpriteSheet.png"
const FONT := "font-m5x7/m5x7.ttf"
const FONT_BIG := "google-pixel-fonts-ofl/jersey10/Jersey10-Regular.ttf"

# Sounds (pack audio, played with Sfx.play_path or the room's own players).
const SND_BED := "nihilex-dark-ambient/04.Those_Who_Wait.ogg"
const SND_CHANT := "freesound-cc0-picks/669797_Dark_Chanting_mp3.mp3"
const SND_ROOM := "freesound-cc0-picks/79088_AkasakaPachinkoParlorLunchtime_4micsStereoExpanded_wav.mp3"
const SND_DRUM := "kenney-impact-sounds/Audio/impactSoft_heavy_00%d.ogg"
const SND_RATTLE := "kenney-impact-sounds/Audio/impactWood_light_00%d.ogg"
const SND_LAMP_OFF := "kenney-interface-sounds/Audio/switch_002.ogg"
const SND_LAMP_ON := "kenney-interface-sounds/Audio/switch_005.ogg"
const SND_THUNK := "kenney-impact-sounds/Audio/impactPlank_medium_001.ogg"
const SND_PEG := "kenney-casino-audio/Audio/chip-lay-2.ogg"
const SND_CLACK := "kenney-casino-audio/Audio/chips-collide-1.ogg"
const SND_CARD := "kenney-casino-audio/Audio/card-slide-3.ogg"
const SND_BOOK := "kenney-rpg-audio/Audio/bookFlip1.ogg"
const SND_WHEEL := "kenney-ui-audio/Audio/switch1.ogg"
const SND_CLAW := "kenney-rpg-audio/Audio/metalLatch.ogg"
const SND_BELL := "kenney-impact-sounds/Audio/impactBell_heavy_001.ogg"

# Bone white for real dollars, paint and light. Rarity colors only for rarity.
const BONE := Color("f6ead2")
const LAMP := Color("ffe6c4")
const CANDLE := Color("ffb98a")
const MOON := Color("b9a7c4")
const PAINT := Color(0.96, 0.92, 0.82, 0.78)

static func tex(path: String) -> Texture2D:
	return load(PACKS + path) as Texture2D


static func region(path: String, rect: Rect2) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex(path)
	a.region = rect
	a.filter_clip = true
	return a


## `count` frames starting at `first`, stepping by `step` (default: one frame to the right).
static func strip(path: String, first: Rect2, count: int, step := Vector2.ZERO) -> Array[Texture2D]:
	var d := step if step != Vector2.ZERO else Vector2(first.size.x, 0)
	var out: Array[Texture2D] = []
	for i in count:
		out.append(region(path, Rect2(first.position + d * i, first.size)))
	return out


static func sprite(t: Texture2D, pos: Vector2, parent: Node, centered := true) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = t
	s.centered = centered
	s.position = pos
	parent.add_child(s)
	return s


# Nothing here is cached in static vars: Godot keeps those alive past its exit check, so
# each glow gets its own small gradient and material.
static func additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


static func radial() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
	g.colors = PackedColorArray([
		Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.14), Color(1, 1, 1, 0)
	])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


## A soft additive glow: light that adds to whatever is under it.
static func glow(parent: Node, pos: Vector2, color: Color, radius: float, alpha := 0.5, squash := 1.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = radial()
	s.material = additive()
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.scale = Vector2(1.0, squash) * (radius * 2.0 / 64.0)
	s.modulate = Color(color, alpha)
	s.position = pos
	parent.add_child(s)
	return s


## A pool of light on the floor: flatter than a glow, with a soft but readable edge, so a
## machine or a candle stands in its own circle of color.
static func pool(parent: Node, pos: Vector2, color: Color, radius: float, alpha := 0.3, squash := 0.55) -> Sprite2D:
	var s := glow(parent, pos, color, radius, alpha, squash)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 0.78, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.82), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	s.texture = t
	return s


## A cone of lamp light, `top` wide at the shade and `bottom` wide at the floor.
static func cone(top: float, bottom: float, height: float) -> ImageTexture:
	var w := int(bottom) + 8
	var h := int(height)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var t := float(y) / float(h)
		var half := lerpf(top, bottom, t) / 2.0
		var fall := pow(1.0 - t, 0.6) * 0.85 + 0.15 * (1.0 - t)
		for x in w:
			var dx := absf(x - w / 2.0)
			var edge := clampf((half - dx) / maxf(3.0, half * 0.35), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, edge * edge * fall))
	return ImageTexture.create_from_image(img)


static func font(path := FONT) -> FontFile:
	var f: FontFile = (load(PACKS + path) as FontFile).duplicate()
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return f


## Words painted on a wall or a tag: centered on `pos`. Real dollar figures use BONE.
static func paint(parent: Node, text: String, pos: Vector2, color := PAINT, size := 16, path := FONT) -> Label:
	var ls := LabelSettings.new()
	ls.font = font(path)
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = 0
	ls.shadow_size = 1
	ls.shadow_color = Color(0, 0, 0, 0.6)
	ls.shadow_offset = Vector2(1, 1)
	var l := Label.new()
	l.text = text
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(64, 16)
	l.position = pos - l.size / 2.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


static func rarity(tier: String) -> Color:
	return Palette.RARITY.get(tier, Palette.COMMON)


static func dollars(cents: int) -> String:
	return "$%d" % (cents / 100) if cents % 100 == 0 else Money.fmt(cents)


static func play(path: String, pitch := 1.0, db := -8.0) -> void:
	Sfx.play_path(PACKS + path, pitch, db)
