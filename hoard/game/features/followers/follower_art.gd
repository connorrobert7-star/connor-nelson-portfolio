class_name FollowerArt
## Pack sprites for the flock, cut with AtlasTexture regions and cached. The only drawn
## pieces are grown from the packs by tools/art/followers.py (the lamb's stages, the egg,
## the veil).

const PACKS := "res://art/packs/"
const ART := "res://features/followers/art/"

const LAMB := ART + "lamb_stages.png"
const LAMB_CELL := 56
## The lamb's height at growth stages 1 to 7 (matches tools/art/followers.py).
const LAMB_SIZES: Array[int] = [22, 26, 30, 34, 38, 44, 50]
const LAMB_FRONT := [0, 1, 2]
const LAMB_BLINK := 3
const LAMB_RIGHT := 4
const LAMB_LEFT := 5
const EGG := ART + "egg.png"
const VEIL := ART + "veil.png"

const PENGUIN := PACKS + "grafxkid-critters-penguin/penguin_edit.png"
## Penguin cells (col, row) on the 24x32 grid.
const PENGUIN_IDLE := Vector2i(1, 1)
const PENGUIN_STEP := [Vector2i(0, 1), Vector2i(2, 1)]
const PENGUIN_ARMS_UP := Vector2i(4, 0)
const PENGUIN_WAVE := Vector2i(4, 2)
const PENGUIN_SIDE := Vector2i(3, 2)
const PENGUIN_LIE := Vector2i(3, 1)
const PENGUIN_FLAT := Vector2i(6, 2)

const GLOW := PACKS + "kenney-particle-pack/PNG (Transparent)/light_01.png"
const SOFT := PACKS + "kenney-particle-pack/PNG (Transparent)/circle_05.png"
const SPARK := PACKS + "kenney-particle-pack/PNG (Transparent)/spark_04.png"
const SPECKS := PACKS + "shattered-pixel-dungeon/effects/specks.png"
## Speck indices on SPD's 8x8 specks strip.
const SPECK_HEART := 11
const SPECK_STAR := 1
const SPECK_SPARKLE := 2
const SPECK_NOTE := 9
const SPECK_WOOL := 7
const SPECK_BUBBLE := 12
const SPECK_STEAM := 13
const SPECK_COIN := 14
const SPIRIT := PACKS + "ninja-adventure/FX/Magic/Spirit/SpriteSheet.png"
const RING := PACKS + "ninja-adventure/FX/Magic/Circle/SpriteSheetWhite.png"
const SMOKE := PACKS + "ninja-adventure/FX/Smoke/SmokeCircular/SpriteSheet.png"
const COIN := PACKS + "evercrazy-coin-gem-8x8/SpinningCoin.png"
const BOWL_EMPTY := PACKS + "kyrise-rpg-icons-16/spritesheet/spritesheet_16x16.png"

const FONT_TITLE := PACKS + "google-pixel-fonts-ofl/jacquard12/Jacquard12-Regular.ttf"
const FONT_NUMBERS := PACKS + "google-pixel-fonts-ofl/jersey10/Jersey10-Regular.ttf"
const FONT_TINY := PACKS + "font-m5x7/m5x7.ttf"

const AUDIO := {
	"chant": [
		PACKS + "owlishmedia-creepy-chanting/chant3.ogg",
		PACKS + "owlishmedia-creepy-chanting/chant7.ogg",
		PACKS + "owlishmedia-creepy-chanting/chant12.ogg",
		PACKS + "owlishmedia-creepy-chanting/chant18.ogg",
	],
	"ethereal": PACKS + "owlishmedia-creepy-chanting/ethereal_chant_Subclip_01_01.ogg",
	"bleat": PACKS + "shattered-pixel-dungeon/sounds/sheep.mp3",
	"eat": PACKS + "shattered-pixel-dungeon/sounds/eat.mp3",
	"growl": [
		PACKS + "rubberduck-80-rpg-sfx/creature_misc_01.ogg",
		PACKS + "rubberduck-80-rpg-sfx/creature_misc_03.ogg",
		PACKS + "rubberduck-80-rpg-sfx/creature_misc_05.ogg",
	],
	"voice": [
		PACKS + "ninja-adventure/Audio/Sounds/Voice/Voice1.ogg",
		PACKS + "ninja-adventure/Audio/Sounds/Voice/Voice3.ogg",
		PACKS + "ninja-adventure/Audio/Sounds/Voice/Voice5.ogg",
		PACKS + "ninja-adventure/Audio/Sounds/Voice/Voice7.ogg",
		PACKS + "ninja-adventure/Audio/Sounds/Voice/Voice9.ogg",
	],
	"bell": PACKS + "kenney-impact-sounds/Audio/impactBell_heavy_000.ogg",
	"toll": PACKS + "kenney-impact-sounds/Audio/impactBell_heavy_001.ogg",
	"pop": PACKS + "kenney-interface-sounds/Audio/pluck_001.ogg",
	"no": PACKS + "kenney-interface-sounds/Audio/error_004.ogg",
	"crack": PACKS + "kenney-impact-sounds/Audio/impactPlate_light_002.ogg",
	"hatch": PACKS + "ninja-adventure/Audio/Jingles/Success2.ogg",
	"grow": PACKS + "ninja-adventure/Audio/Jingles/LevelUp1.ogg",
	"level": PACKS + "shattered-pixel-dungeon/sounds/levelup.mp3",
	"coin": PACKS + "juhani-512-retro-sfx/General Sounds/Coins/sfx_coin_single1.ogg",
	"coins": PACKS + "rubberduck-80-rpg-sfx/item_coins_02.ogg",
	"motes": PACKS + "lrsf-coins-library/Coins_Pouring/Coins_Pouring_00.ogg",
	"dress": PACKS + "kenney-rpg-audio/Audio/cloth1.ogg",
	"chest": PACKS + "kenney-rpg-audio/Audio/doorOpen_1.ogg",
	"dirge": PACKS + "ninja-adventure/Audio/Jingles/GameOver.ogg",
	"ghost": PACKS + "shattered-pixel-dungeon/sounds/ghost.mp3",
	"bubble": PACKS + "ninja-adventure/Audio/Sounds/Elemental/Bubble.ogg",
	"whoosh": PACKS + "ninja-adventure/Audio/Sounds/Magic & Skill/Spirit.ogg",
	"shrine_bed": PACKS + "mumusi-cathedral-of-shadows/Cathedral_of_Shadows_loop.ogg",
	"mourning_bed": PACKS + "ninja-adventure/Audio/Music/7 - Sad Theme.ogg",
	"away_bed": PACKS + "nihilex-dark-ambient/06.There_In_Spirit.ogg",
}

## A follower's body wearing a cloak: from the shoulder row down to just above the feet,
## every pixel but the outline takes the cloak's dark, mid or light by how bright it was
## (`bands` are the body's own two luminance cut points, so a black penguin and a white lamb
## both come out shaded), and the shoulder row is the cloak's lit edge.
const CLOAK_SHADER := """
shader_type canvas_item;
uniform float region_top = 0.0;
uniform float shoulder = 8.0;
uniform float hem = 99.0;
uniform vec3 bands = vec3(0.1, 0.4, 0.7);
uniform vec4 cloak_dark : source_color = vec4(0.2, 0.2, 0.3, 1.0);
uniform vec4 cloak_mid : source_color = vec4(0.4, 0.4, 0.5, 1.0);
uniform vec4 cloak_light : source_color = vec4(0.7, 0.7, 0.8, 1.0);
varying vec4 tint;
void vertex() {
	tint = COLOR;
}
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float row = floor(UV.y / TEXTURE_PIXEL_SIZE.y + 0.001) - region_top;
	if (row >= shoulder && row < hem && c.a > 0.5) {
		float l = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
		if (l > bands.x) {
			vec3 k = l < bands.y ? cloak_dark.rgb : (l < bands.z ? cloak_mid.rgb : cloak_light.rgb);
			if (row < shoulder + 1.0) {
				k = cloak_light.rgb;
			}
			c.rgb = k;
		}
	}
	COLOR = c * tint;
}
"""

static var _cache: Dictionary = {}
static var _cloak_shader: Shader


static func cloak_material() -> ShaderMaterial:
	if _cloak_shader == null:
		_cloak_shader = Shader.new()
		_cloak_shader.code = CLOAK_SHADER
	var m := ShaderMaterial.new()
	m.shader = _cloak_shader
	return m
static var _images: Dictionary = {}  # sheet path -> Image, read back once
static var _shapes: Dictionary = {}  # texture key -> shape()


## A body texture's outline, for dressing it: `used` (its opaque box, in texture pixels) and
## per row of the texture the leftmost and rightmost opaque column (-1 for an empty row).
## Each texture is read back once a session.
static func shape(t: Texture2D) -> Dictionary:
	if t == null:
		return {}
	var key := ""
	var path := t.resource_path
	var region := Rect2()
	if t is AtlasTexture:
		path = (t as AtlasTexture).atlas.resource_path
		region = (t as AtlasTexture).region
	key = "%s|%s" % [path, region]
	if path == "":
		key = str(t.get_instance_id())
	if _shapes.has(key):
		return _shapes[key]
	var img: Image = null
	if path != "" and t is AtlasTexture:
		if not _images.has(path):
			var whole := (t as AtlasTexture).atlas.get_image()
			if whole and whole.is_compressed():
				whole.decompress()
			if whole:
				whole.convert(Image.FORMAT_RGBA8)
			_images[path] = whole
		var sheet: Image = _images[path]
		if sheet:
			img = sheet.get_region(Rect2i(region))
	else:
		img = t.get_image()
		if img and img.is_compressed():
			img.decompress()
	var out := {}
	if img and not img.is_empty():
		var left := PackedInt32Array()
		var right := PackedInt32Array()
		var lums: Array[float] = []
		for y in img.get_height():
			var l := -1
			var r := -1
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a >= 0.5:
					if l < 0:
						l = x
					r = x
					lums.append(c.get_luminance())
			left.append(l)
			right.append(r)
		# Its outline (the darkest shade) and two cut points that split the rest in thirds.
		lums.sort()
		var bands := Vector3(0.1, 0.4, 0.7)
		if not lums.is_empty():
			var floor_l: float = lums[0] + 0.02
			var rest: Array = lums.filter(func(v: float) -> bool: return v > floor_l)
			if rest.size() >= 3:
				bands = Vector3(floor_l, rest[rest.size() / 3], rest[rest.size() * 2 / 3])
		out = {"used": img.get_used_rect(), "left": left, "right": right, "size": img.get_size(), "bands": bands}
	_shapes[key] = out
	return out


static func tex(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


static func region(path: String, rect: Rect2) -> AtlasTexture:
	var key := "%s|%s" % [path, rect]
	if not _cache.has(key):
		var a := AtlasTexture.new()
		a.atlas = tex(path)
		a.region = rect
		_cache[key] = a
	return _cache[key]


## {sheet, rect: [x, y, w, h]} from a catalog or the backend.
static func icon(def: Dictionary) -> Texture2D:
	if def.is_empty() or not def.has("sheet"):
		return null
	var r: Array = def.get("rect", [])
	if r.size() < 4:
		return tex(str(def.sheet))
	return region(str(def.sheet), Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])))


static func lamb(stage: int, frame: int) -> AtlasTexture:
	var s := clampi(stage, 1, LAMB_SIZES.size())
	return region(LAMB, Rect2(frame * LAMB_CELL, (s - 1) * LAMB_CELL, LAMB_CELL, LAMB_CELL))


static func lamb_size(stage: int) -> int:
	return LAMB_SIZES[clampi(stage, 1, LAMB_SIZES.size()) - 1]


static func egg(frame: int) -> AtlasTexture:
	return region(EGG, Rect2(frame * 16, 0, 16, 20))


static func penguin(cell: Vector2i) -> AtlasTexture:
	return region(PENGUIN, Rect2(cell.x * 24, cell.y * 32, 24, 32))


## SPD's specks are 7x7 cells (see SPECKS_INDEX.txt).
static func speck(i: int) -> AtlasTexture:
	return region(SPECKS, Rect2(i * 7, 0, 7, 7))


static func coin(frame: int) -> AtlasTexture:
	return region(COIN, Rect2((frame % 18) * 8, 0, 8, 8))


## The tiopalada emoji bubbles: 15 frames of 32x32 (pop in 0-4, idle 5-9, pop out 10-14).
static func bubble(sheet: String, frame: int) -> AtlasTexture:
	return region(sheet, Rect2((frame % 5) * 32, (frame / 5) * 32, 32, 32))


static func altar(frame: int) -> Texture2D:
	return tex(PACKS + "dcss-altars-features/dungeon/altars/altar_makhleb_flame_%d.png" % (frame % 8 + 1))


## A Label in a pack font with an ink outline, for numbers painted on things.
static func label(text: String, font_path := FONT_NUMBERS, size := 10, color := Palette.CREAM) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font = load(font_path) as Font
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = 3
	ls.outline_color = Palette.NIGHT
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Play a pack sound. A list picks one at random.
static func play(name: String, pitch := 1.0, volume_db := -6.0) -> void:
	var entry: Variant = AUDIO.get(name, "")
	var path := ""
	if entry is Array:
		path = str((entry as Array).pick_random())
	else:
		path = str(entry)
	if path != "":
		Sfx.play_path(path, pitch, volume_db)


## An additive glow sprite (Kenney light mask) for halos, pools of light and auras.
static func glow(color: Color, radius_px: float, path := GLOW) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex(path)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	s.modulate = color
	s.scale = Vector2.ONE * (radius_px * 2.0 / 128.0)
	return s
