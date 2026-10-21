class_name BookOverlay
extends Overlay
## The collection book on the casino counter, up close.
##
## One two-page spread per set: grey and blue on the left page, purple, gold and red on the
## right, each piece in its own pocket. What you own sits in color inside its rarity's glow
## and outline, with a count when there's more than one; what you're missing is a dark
## silhouette. Ribbons on the edge flip between sets.
##
## After the casino's sets come the trophy shelves, one spread per other catalog (the gate's
## boss drops, the undercroft's, the flock's), each on its own colored ribbon: owned pieces in
## color in brass-cornered pockets (big ones for the gate's eight), missing ones as
## silhouettes. They can be worn; they never go in the press.
##
## Tap a piece you own and the leader on the stage below (the 0x72 wizard) puts it on
## (POST /casino/equip).
## Tap the press and its rail opens: tap ten pieces of one color into it, pull the lever, and
## the press stamps them into one piece of the next color (POST /casino/tradeup), which pops
## out in its rarity's light and lands in its pocket. Gold and red bounce off the rail.
##
## Closes with {equipped, traded} if anything changed, else null. Nothing here moves money.

enum Mode { LOOK, FEED, BUSY }

const PACKS := "res://art/packs/"
const FONT_SMALL := PACKS + "font-m5x7/m5x7.ttf"
const FONT_BIG := PACKS + "google-pixel-fonts-ofl/jersey10/Jersey10-Regular.ttf"
const GLOW_TEX := PACKS + "kenney-particle-pack/PNG (Transparent)/circle_05.png"
const STAR_TEX := PACKS + "kenney-particle-pack/PNG (Transparent)/star_06.png"
const SMOKE_TEX := PACKS + "kenney-particle-pack/PNG (Transparent)/smoke_04.png"

const TIERS := ["common", "rare", "epic", "legendary", "mythic"]
const NEXT := {"common": "rare", "rare": "epic", "epic": "legendary"}
const SET_COLORS := [Palette.TEAL, Palette.PINK]
# Trophy shelves' ribbons: rusted bronze for the gate, bile for the undercroft, bone for the flock.
const SHELF_COLORS := {"gate": Color("b0703a"), "minigames": Palette.BILE, "followers": Color("d8cbb2")}
const LAMP := Color("ffe6c4")
const BRASS := Color("a07a3a")
const BRASS_LIT := Color("f0cf8a")
const IRON := Color("2b2733")
const IRON_DARK := Color("17141c")

# Layout, in overlay space (480x270).
const BOOK := Rect2(36, 4, 408, 184)
const PAGE_L := Rect2(42, 9, 196, 174)
const PAGE_R := Rect2(242, 9, 196, 174)
const PITCH := 36.0
const BIG_PITCH := 72.0
const TAB := Vector2(18, 27)
const TAB_TOP := 30.0
const TAB_GAP := 3.0
const STAGE := Rect2(2, 194, 98, 76)
const FEET := Vector2(50, 262)
const RAIL := Rect2(104, 222, 218, 36)
const SLOT0 := Vector2(112, 233)
const SLOT_PITCH := 20.0
const PRESS := Rect2(318, 186, 106, 84)
const LEVER := Rect2(424, 196, 56, 74)
const OUT := Vector2(372, 260)
const PIVOT := Vector2(440, 258)

# The owner's character on the book's stage: the 0x72 wizard (wizzard_m idle, 4 frames).
const WIZARD := PACKS + "0x72-dungeontileset-ii/0x72_DungeonTilesetII_v1.7/0x72_DungeonTilesetII_v1.7.png"
const WIZARD_IDLE := Rect2(128, 164, 16, 28)
const FIG_SCALE := 3.0

# Where each worn piece sits (1x, feet at 0,0), how many pixels wide it is, and its glow.
# The aura goes behind the body. WORLD is the walking leader; STAGE the wizard in the book.
const WORLD_LOOK := {
	"aura": {"at": Vector2(0, -11), "px": 28.0, "glow": 28.0, "back": true},
	"cloak": {"at": Vector2(0, -4), "px": 10.0, "glow": 9.0},
	"hat": {"at": Vector2(1, -17), "px": 13.0, "glow": 11.0},
	"charm": {"at": Vector2(12, -10), "px": 11.0, "glow": 10.0},
}
const STAGE_LOOK := {
	"aura": {"at": Vector2(1, -9), "px": 24.0, "glow": 16.0, "back": true},
	"cloak": {"at": Vector2(-3, -7), "px": 14.0, "glow": 8.0, "back": true},
	"hat": {"at": Vector2(1, -16), "px": 12.0, "glow": 8.0},
	"charm": {"at": Vector2(-10, -14), "px": 7.0, "glow": 6.0},
	"follower_skin": {"at": Vector2(13, -4), "px": 9.0, "glow": 7.0},
}

# What each tier's reveal does (docs/INFLUENCES.md, the CS:GO reveal table).
const REVEAL := {
	"common": {"stop": 0.05, "flash": 0.0, "fade": 0.0, "shake": 1.0, "shake_s": 0.12, "sparks": 6,
		"veil": 0.35, "rays": 0.0, "glow": 0.3, "zoom": 1.03, "hold": 1.4},
	"rare": {"stop": 0.083, "flash": 0.35, "fade": 0.18, "shake": 1.0, "shake_s": 0.15, "sparks": 16,
		"veil": 0.45, "rays": 0.16, "glow": 0.5, "zoom": 1.05, "hold": 1.6},
	"epic": {"stop": 0.117, "flash": 0.5, "fade": 0.25, "shake": 2.0, "shake_s": 0.25, "sparks": 32,
		"veil": 0.55, "rays": 0.26, "glow": 0.65, "zoom": 1.06, "hold": 2.0},
	"legendary": {"stop": 0.2, "flash": 0.7, "fade": 0.4, "shake": 4.0, "shake_s": 0.4, "sparks": 64,
		"veil": 0.84, "rays": 0.36, "glow": 0.85, "zoom": 1.2, "hold": 3.5},
	"mythic": {"stop": 0.2, "flash": 0.9, "fade": 0.6, "shake": 6.0, "shake_s": 0.5, "sparks": 120,
		"veil": 0.94, "rays": 0.45, "glow": 1.0, "zoom": 1.3, "hold": 5.0},
}

# Sounds from the packs.
const SND_OPEN := PACKS + "kenney-rpg-audio/Audio/bookOpen.ogg"
const SND_CLOSE := PACKS + "kenney-rpg-audio/Audio/bookClose.ogg"
const SND_FLIP := PACKS + "kenney-rpg-audio/Audio/bookFlip%d.ogg"
const SND_PLACE := PACKS + "kenney-rpg-audio/Audio/bookPlace1.ogg"
const SND_CLOTH := PACKS + "kenney-rpg-audio/Audio/cloth%d.ogg"
const SND_THUD := PACKS + "kenney-impact-sounds/Audio/impactSoft_medium_00%d.ogg"
const SND_CLUNK := PACKS + "kenney-impact-sounds/Audio/impactMetal_light_00%d.ogg"
const SND_BOUNCE := PACKS + "kenney-impact-sounds/Audio/impactMetal_medium_002.ogg"
const SND_LATCH := PACKS + "kenney-rpg-audio/Audio/metalLatch.ogg"
const SND_CLICK := PACKS + "kenney-rpg-audio/Audio/metalClick.ogg"
const SND_CREAK := PACKS + "kenney-rpg-audio/Audio/creak1.ogg"
const SND_STAMP := PACKS + "kenney-impact-sounds/Audio/impactMetal_heavy_002.ogg"
const SND_BOOM := PACKS + "kenney-impact-sounds/Audio/impactPlate_heavy_000.ogg"
const SND_BANG := PACKS + "ignisforge-sfx-sampler/explosion_01.ogg"
const SND_HEAT := PACKS + "wobbleboxx-levelup-coin/Rise03.ogg"
const SND_POP := PACKS + "kenney-casino-audio/Audio/cards-pack-open-1.ogg"
const SND_WHOOSH := PACKS + "ninja-adventure/Audio/Sounds/Whoosh & Slash/Whoosh.ogg"
const SND_CHOIR := PACKS + "mumusi-cathedral-of-shadows/Cathedral_of_Shadows_loop.ogg"
const SND_ERROR := PACKS + "kenney-interface-sounds/Audio/error_004.ogg"
const SND_GLINT := PACKS + "kenney-interface-sounds/Audio/glass_001.ogg"
const STINGER := {
	"common": PACKS + "kenney-music-jingles/Audio/Pizzicato jingles/jingles_PIZZI00.ogg",
	"rare": PACKS + "kenney-music-jingles/Audio/Steel jingles/jingles_STEEL00.ogg",
	"epic": PACKS + "kenney-music-jingles/Audio/Sax jingles/jingles_SAX00.ogg",
	"legendary": PACKS + "kenney-music-jingles/Audio/Hit jingles/jingles_HIT00.ogg",
	"mythic": PACKS + "kenney-music-jingles/Audio/Hit jingles/jingles_HIT00.ogg",
}

# A 3x5 pixel font for counts.
const GLYPHS := {
	"0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
	"2": ["111", "001", "111", "100", "111"], "3": ["111", "001", "011", "001", "111"],
	"4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"],
	"6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
	"8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "111"],
	"x": ["000", "101", "010", "101", "000"],
}

const FLAT_CODE := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	COLOR = vec4(tint.rgb, COLOR.a * tint.a);
}
"""

# Plain data only: Godot keeps static objects alive past its exit check.
static var _catalog: Dictionary = {}
static var _sets: Array = []

## Where the book is, for the tour and anyone listening: open, look, flip, equip, feed,
## pull, stamp, reveal, landed, closed.
var moment := "open"
var mode := Mode.LOOK
var items: Dictionary = {}  # item_id -> item
var sets: Array = []
var page := 0
var owned: Dictionary = {}  # item_id -> count
var inventory: Array = []  # [{inventory_id, item_id}]
var equipped: Dictionary = {}  # slot -> item_id
var rail: Array[Dictionary] = []  # {inventory_id, item_id, tier, node}
var traded := 0
## The last trade-up's API result.
var last_trade: Dictionary = {}

var _changed := false
var _root := Control.new()
var _bookart: BookArt
var _spreads: Array[Control] = []
var _cells: Dictionary = {}  # item_id -> Cell
var _cell_set: Dictionary = {}  # item_id -> spread index
var _tabs: Array[Tab] = []
var _stage: StageArt
var _figure := Node2D.new()
var _fig_back := Node2D.new()
var _fig_front := Node2D.new()
var _fig_sprite := Sprite2D.new()
var _fig_frames: Array[Texture2D] = []
var _fig_t := 0.0
var _fig_pieces: Dictionary = {}
var _press: PressArt
var _rail_layer := Control.new()
var _fx := Control.new()
var _shader: Shader
var _mats: Dictionary = {}
var _tex: Dictionary = {}


func _ready() -> void:
	add_child(Counter.new())
	_shader = BookOverlay.flat_shader()
	for n: Control in [_root, _rail_layer, _fx]:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n.size = Vector2(480, 270)
	add_child(_root)
	# A warm pool of lamp light over the counter.
	BookOverlay.glow(_root, Vector2(240, 104), LAMP, 260.0, 0.12)
	_bookart = BookArt.new()
	_root.add_child(_bookart)
	_build_stage()
	_press = PressArt.new()
	_root.add_child(_press)
	_root.add_child(_rail_layer)
	_root.add_child(_fx)
	_root.pivot_offset = Vector2(240, 135)
	_root.scale = Vector2(0.94, 0.94)
	_root.modulate.a = 0.0
	var tw := _root.create_tween().set_parallel()
	tw.tween_property(_root, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_root, "modulate:a", 1.0, 0.15)
	BookOverlay.sound(SND_OPEN, 1.0, -6.0)
	await _load()


func _load() -> void:
	items = await BookOverlay.load_catalog()
	if Game.state.is_empty():
		await Game.refresh()
	if not is_inside_tree():
		return
	sets = BookOverlay.catalog_sets()
	_read_state()
	_build_spreads()
	page = _newest_set()
	_show_page(page)
	_dress_figure()
	_refresh()
	moment = "look"


func _read_state() -> void:
	var cz: Dictionary = Game.state.get("casino", {})
	owned = (cz.get("owned", {}) as Dictionary).duplicate()
	owned.merge(cz.get("trophies", {}) as Dictionary)
	inventory = (cz.get("inventory", []) as Array).duplicate()
	equipped = (cz.get("equipped", {}) as Dictionary).duplicate()


# --- for the tour -------------------------------------------------------------------

func cell_control(item_id: String) -> Control:
	return _cells.get(item_id)


func tab_control(set_index: int) -> Control:
	return _tabs[set_index] if set_index < _tabs.size() else null


func showing_set() -> String:
	return str(sets[page].id) if page < sets.size() else ""


func piece_on_leader(slot: String) -> Node2D:
	var p: Variant = _fig_pieces.get(slot)
	return p if p is Node2D and is_instance_valid(p) else null


func count_of(item_id: String) -> int:
	return int(owned.get(item_id, 0))


## Item ids on the showing spread, in pocket order.
func items_on_page() -> Array[String]:
	var out: Array[String] = []
	for id: String in _cells:
		if _cell_set[id] == page:
			out.append(id)
	return out


# --- building ------------------------------------------------------------------------

func _build_spreads() -> void:
	var casino_sets := 0
	for st: Dictionary in sets:
		if not st.get("trophy", false):
			casino_sets += 1
	for si in sets.size():
		var set_id := str(sets[si].id)
		var trophy: bool = sets[si].get("trophy", false)
		var spread := SpreadArt.new()
		spread.size = Vector2(480, 270)
		spread.visible = false
		_root.add_child(spread)
		_root.move_child(spread, _bookart.get_index() + 1)
		_spreads.append(spread)
		var head := BookOverlay.words(spread, str(sets[si].get("name", set_id)), Vector2(PAGE_L.get_center().x, PAGE_L.position.y + 7), Color(Palette.MUTED, 0.85))
		head.name = "Heading"
		# Each color is a block of pockets, five to a row; the blocks split across the two
		# pages as evenly as the rows allow. A small trophy shelf (the gate's eight) gets big
		# mounted pockets, two to a row, if they fit.
		var on_shelf := 0
		for id: String in items:
			if BookOverlay.page_key(items[id]) == set_id:
				on_shelf += 1
		var blocks := _blocks(set_id, 2)
		var split := BookOverlay.split_blocks(blocks)
		var big := trophy and on_shelf <= 8 and _fits(blocks, split, BIG_PITCH)
		if not big:
			blocks = _blocks(set_id, 5)
			split = BookOverlay.split_blocks(blocks)
		var pitch := BIG_PITCH if big else PITCH
		for b in blocks.size():
			var pg: Rect2 = PAGE_L if b < split else PAGE_R
			var first_on_page := b == 0 or b == split
			if first_on_page:
				var rows_here := 0
				for k in range(0 if b < split else split, split if b < split else blocks.size()):
					rows_here += int(blocks[k].rows)
				var on_page := split if b < split else blocks.size() - split
				var room := pg.size.y - 16.0
				var used := rows_here * pitch + (on_page - 1) * 4.0
				blocks[b]["y"] = pg.position.y + 16.0 + (maxf(0.0, room - used) / 2.0 if trophy else 0.0)
			else:
				blocks[b]["y"] = float(blocks[b - 1].y) + int(blocks[b - 1].rows) * pitch + 4.0
			var ids: Array[String] = []
			ids.assign(blocks[b].ids)
			var tier := str(blocks[b].tier)
			var y: float = blocks[b].y
			var rows := int(blocks[b].rows)
			var cols := ceili(float(ids.size()) / rows)
			spread.markers.append({"pos": Vector2(pg.position.x + 4, y + rows * pitch / 2.0 - 5), "tier": tier})
			for i in ids.size():
				var r := i / cols
				var c := i % cols
				var in_row := mini(cols, ids.size() - r * cols)
				var x0 := pg.get_center().x - in_row * pitch / 2.0
				var cell := Cell.new()
				cell.position = Vector2(x0 + (c + 0.5) * pitch, y + (r + 0.5) * pitch) - Vector2(16, 16)
				cell.base = 2.0 if big else 1.0
				cell.scale = Vector2.ONE * cell.base
				spread.add_child(cell)
				cell.setup(items[ids[i]], _icon(ids[i]), _mat(tier), _mat("sil"), _mat("rim"))
				_cells[ids[i]] = cell
				_cell_set[ids[i]] = si
		# A ribbon for each spread on the book's edge, the trophies' a little apart.
		var tab := Tab.new()
		tab.index = si
		tab.color = SHELF_COLORS.get(set_id, Palette.MUTED) if trophy else SET_COLORS[si % SET_COLORS.size()]
		tab.position = Vector2(BOOK.end.x - 4, TAB_TOP + si * (TAB.y + TAB_GAP) + (6.0 if si >= casino_sets else 0.0))
		tab.size = TAB
		var emblem := _emblem(set_id)
		if not emblem.is_empty():
			tab.set_emblem(_icon(str(emblem.id)), _mat("emblem"))
		_root.add_child(tab)
		_root.move_child(tab, _bookart.get_index())
		_tabs.append(tab)


## A spread's pockets by color, `per_row` to a row at most: [{tier, ids, rows}].
func _blocks(set_id: String, per_row: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for tier: String in TIERS:
		var ids: Array[String] = []
		for id: String in items:
			var it: Dictionary = items[id]
			if BookOverlay.page_key(it) == set_id and str(it.tier) == tier:
				ids.append(id)
		if not ids.is_empty():
			out.append({"tier": tier, "ids": ids, "rows": ceili(ids.size() / float(per_row))})
	return out


## Whether both pages hold their blocks at this pitch.
static func _fits(blocks: Array[Dictionary], split: int, pitch: float) -> bool:
	var left := 0.0
	var right := 0.0
	for b in blocks.size():
		var h := int(blocks[b].rows) * pitch + 4.0
		if b < split:
			left += h
		else:
			right += h
	return maxf(left, right) - 4.0 <= PAGE_L.size.y - 16.0


## Where the left page ends: the index of the first block on the right page, chosen so the
## two pages hold as close to the same number of rows as they can (cheaper colors left).
static func split_blocks(blocks: Array[Dictionary]) -> int:
	if blocks.size() <= 1:
		return blocks.size()
	var total := 0
	for b in blocks:
		total += int(b.rows)
	var best := 1
	var best_gap := 1 << 20
	var left := 0
	for k in range(1, blocks.size()):
		left += int(blocks[k - 1].rows)
		var gap := absi(total - 2 * left)
		if gap < best_gap:
			best_gap = gap
			best = k
	return best


func _emblem(set_id: String) -> Dictionary:
	var best: Dictionary = {}
	for id: String in items:
		var it: Dictionary = items[id]
		if BookOverlay.page_key(it) == set_id and (best.is_empty() or TIERS.find(it.tier) > TIERS.find(best.tier)):
			best = it
	return best


func _build_stage() -> void:
	_stage = StageArt.new()
	_stage.position = STAGE.position
	_stage.size = STAGE.size
	_root.add_child(_stage)
	_figure.position = FEET - STAGE.position
	_figure.scale = Vector2(FIG_SCALE, FIG_SCALE)
	_stage.add_child(_figure)
	_figure.add_child(_fig_back)
	for i in 4:
		var a := AtlasTexture.new()
		a.atlas = load(WIZARD)
		a.region = Rect2(WIZARD_IDLE.position + Vector2(i * 16, 0), WIZARD_IDLE.size)
		a.filter_clip = true
		_fig_frames.append(a)
	_fig_sprite.texture = _fig_frames[0]
	_fig_sprite.offset = Vector2(0, -WIZARD_IDLE.size.y / 2.0)
	_figure.add_child(_fig_sprite)
	_figure.add_child(_fig_front)


func _icon(item_id: String) -> AtlasTexture:
	if not _tex.has(item_id):
		_tex[item_id] = BookOverlay.icon_of(items[item_id])
	return _tex[item_id]


func _mat(key: String) -> ShaderMaterial:
	if not _mats.has(key):
		var col: Color
		match key:
			"sil":
				col = Color("07040a")
			"rim":
				col = Color("43354e")
			"emblem":
				col = Color(Palette.NIGHT, 0.85)
			_:
				col = Palette.RARITY.get(key, Palette.CREAM)
		_mats[key] = BookOverlay.flat(_shader, col)
	return _mats[key]


func _newest_set() -> int:
	var newest := -1
	var at := 0
	for row: Dictionary in inventory:
		var id := str(row.item_id)
		if int(row.inventory_id) > newest and _cell_set.has(id):
			newest = int(row.inventory_id)
			at = _cell_set[id]
	return at


# --- showing state -------------------------------------------------------------------

func _refresh() -> void:
	var worn: Array = equipped.values()
	var rail_tier := str(rail[0].tier) if not rail.is_empty() else ""
	for id: String in _cells:
		var c: Cell = _cells[id]
		var fed := 0
		for r: Dictionary in rail:
			if r.item_id == id:
				fed += 1
		var dim := false
		if mode == Mode.FEED:
			var left := int(owned.get(id, 0)) - fed
			dim = c.trophy or not NEXT.has(c.tier) or left <= 0 or (rail_tier != "" and rail_tier != c.tier) or rail.size() >= 10
		c.show_state(int(owned.get(id, 0)), fed, worn.has(id), dim)
	_press.open_target = 1.0 if mode != Mode.LOOK or not rail.is_empty() else 0.0
	_press.rail_on = mode == Mode.FEED
	var lamps: Array[Color] = []
	for r: Dictionary in rail:
		lamps.append(Palette.RARITY[r.tier])
	_press.lamps = lamps
	_press.heat_target = rail.size() / 10.0 * 0.6
	var full := rail.size() == 10 and NEXT.has(rail_tier)
	_press.full = full
	_press.full_color = Palette.RARITY[NEXT[rail_tier]] if full else LAMP
	_press.heat_color = Palette.RARITY[NEXT[rail_tier]] if rail_tier != "" and NEXT.has(rail_tier) else LAMP
	_press.hint = mode == Mode.LOOK and _tradeable_tier() != ""
	_press.hint_color = Palette.RARITY[NEXT[_tradeable_tier()]] if _press.hint else LAMP
	_stage.modulate = Color(0.45, 0.42, 0.5) if mode == Mode.FEED else Color.WHITE
	_refresh_worn()
	for t: Tab in _tabs:
		t.active = t.index == page
		t.queue_redraw()


## A worn piece whose last copy sits on the rail fades on the leader: it's about to go.
func _refresh_worn() -> void:
	for slot: String in _fig_pieces:
		var p: Variant = _fig_pieces[slot]
		if not (p is Node2D and is_instance_valid(p)):
			continue
		var id := str(equipped.get(slot, ""))
		var fed := 0
		for r: Dictionary in rail:
			if r.item_id == id:
				fed += 1
		(p as Node2D).modulate.a = 0.3 if fed > 0 and fed >= int(owned.get(id, 0)) else 1.0


## A tier with ten or more owned, if any (the press breathes in the next color).
func _tradeable_tier() -> String:
	var per: Dictionary = {}
	for id: String in owned:
		if items.has(id) and not BookOverlay.is_trophy(items[id]):
			var tier := str(items[id].tier)
			per[tier] = int(per.get(tier, 0)) + int(owned[id])
	for tier: String in ["epic", "rare", "common"]:
		if int(per.get(tier, 0)) >= 10:
			return tier
	return ""


func _show_page(index: int) -> void:
	page = index
	for i in _spreads.size():
		_spreads[i].visible = i == index
	for t: Tab in _tabs:
		t.active = t.index == page
		t.queue_redraw()


func _flip_to(index: int) -> void:
	if index == page or index >= _spreads.size():
		return
	var was := mode
	var was_moment := moment
	mode = Mode.BUSY
	moment = "flip"
	BookOverlay.sound(SND_FLIP % (randi() % 3 + 1), randf_range(0.95, 1.08), -4.0)
	# A page sweeps over the spine: it covers the right page, folds to nothing at the spine,
	# then unfolds across the left page and lets go.
	var leaf := Leaf.new()
	leaf.position = PAGE_R.position
	leaf.size = PAGE_R.size
	leaf.pivot_offset = Vector2(0, PAGE_R.size.y / 2.0)
	_root.add_child(leaf)
	_root.move_child(leaf, _spreads[page].get_index() + 1)
	var tw := leaf.create_tween()
	tw.tween_property(leaf, "scale:x", 0.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	_show_page(index)
	_root.move_child(leaf, _spreads[page].get_index() + 1)
	leaf.position = PAGE_L.position
	leaf.pivot_offset = Vector2(PAGE_L.size.x, PAGE_L.size.y / 2.0)
	tw = leaf.create_tween()
	tw.tween_property(leaf, "scale:x", 1.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(leaf, "modulate:a", 0.0, 0.12)
	await tw.finished
	leaf.queue_free()
	mode = was
	moment = was_moment
	_refresh()


func _dress_figure() -> void:
	_fig_pieces = BookOverlay.dress_pieces(_fig_back, _fig_front, equipped, items, STAGE_LOOK)
	_refresh_worn()


func _process(delta: float) -> void:
	_fig_t += delta
	if not _fig_frames.is_empty():
		_fig_sprite.texture = _fig_frames[int(_fig_t * 7.0) % _fig_frames.size()]
	var charm := piece_on_leader("charm")
	if charm:
		charm.position.y = STAGE_LOOK.charm.at.y + roundf(sin(_fig_t * 2.2) * 1.0)
	var aura := piece_on_leader("aura")
	if aura and aura.has_node("Turn"):
		(aura.get_node("Turn") as Node2D).rotation = _fig_t * 0.8


# --- input ---------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_tap(mb.position)
	elif mb and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		_close()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()


func _tap(at: Vector2) -> void:
	if mode == Mode.BUSY:
		return
	if items.is_empty():
		_close()
		return
	for t: Tab in _tabs:
		if t.get_global_rect().has_point(at):
			_flip_to(t.index)
			return
	for id: String in _cells:
		var c: Cell = _cells[id]
		if _cell_set[id] == page and c.get_global_rect().grow(2.0 * c.base).has_point(at):
			_tap_cell(c)
			return
	if mode == Mode.FEED:
		for i in rail.size():
			if Rect2(BookOverlay.slot_pos(i) - Vector2(2, 2), Vector2(20, 20)).has_point(at):
				_unfeed(i)
				return
	if LEVER.has_point(at):
		_pull()
		return
	if PRESS.has_point(at) or RAIL.has_point(at):
		_toggle_feed()
		return
	if STAGE.has_point(at):
		_hop()
		return
	if BOOK.has_point(at):
		BookOverlay.sound(SND_FLIP % 2, 1.4, -18.0)
		return
	_close()


func _tap_cell(c: Cell) -> void:
	if mode == Mode.FEED:
		_feed(c)
		return
	if c.count <= 0:
		c.shiver()
		BookOverlay.sound(SND_THUD % (randi() % 3), 1.2, -12.0)
		return
	if equipped.get(str(c.item.slot), "") == str(c.item.id):
		c.wiggle()
		_name_at(c)
		BookOverlay.sound(SND_CLOTH % (randi() % 4 + 1), 1.2, -10.0)
		return
	_equip(c)


func _name_at(c: Cell) -> void:
	var col: Color = Palette.RARITY[c.tier]
	var r := c.get_global_rect()
	CasinoFx.float_text(_fx, Vector2(r.get_center().x, r.position.y - 6), str(c.item.name), col, 8)


# --- wearing -------------------------------------------------------------------------

func _equip(c: Cell) -> void:
	mode = Mode.BUSY
	moment = "equip"
	var slot := str(c.item.slot)
	var res: Array = await Game.call_api("POST", "/casino/equip", {"item_id": str(c.item.id)})
	if res[1] != "":
		_refuse(c.global_position + Vector2(16, -4), res[1])
		c.shiver()
		mode = Mode.LOOK
		moment = "look"
		return
	equipped = (res[0].get("equipped", equipped) as Dictionary).duplicate()
	_changed = true
	c.wiggle()
	_name_at(c)
	BookOverlay.sound(SND_WHOOSH, 1.2, -12.0)
	var to: Vector2 = _figure.global_position + (STAGE_LOOK.get(slot, {}).get("at", Vector2(0, -10)) as Vector2) * FIG_SCALE
	var fly := await _fly(_icon(str(c.item.id)), c.get_global_rect(), Rect2(to - Vector2(16, 16), Vector2(32, 32)), 0.32, 26.0)
	fly.queue_free()
	_dress_figure()
	var piece := piece_on_leader(slot)
	if piece:
		piece.scale = Vector2(0.2, 0.2)
		var tw := piece.create_tween()
		tw.tween_property(piece, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	CasinoFx.burst(_fx, to, Palette.RARITY[c.tier], 14, 90.0, 0.5)
	BookOverlay.sound(SND_CLOTH % (randi() % 4 + 1), 1.0, -4.0)
	Sfx.play("pop")
	_hop()
	_refresh()
	Game.refresh()
	mode = Mode.LOOK
	moment = "look"


func _hop() -> void:
	var home := FEET - STAGE.position
	var tw := _figure.create_tween()
	tw.tween_property(_figure, "position", home + Vector2(0, -6), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_figure, "position", home, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_figure, "scale", Vector2(FIG_SCALE * 1.1, FIG_SCALE * 0.9), 0.05)
	tw.tween_property(_figure, "scale", Vector2(FIG_SCALE, FIG_SCALE), 0.08)


# --- the trade-up press --------------------------------------------------------------

func _toggle_feed() -> void:
	if mode == Mode.FEED:
		for i in range(rail.size() - 1, -1, -1):
			_unfeed(i)
		mode = Mode.LOOK
		moment = "look"
		BookOverlay.sound(SND_LATCH, 0.8, -8.0)
	else:
		mode = Mode.FEED
		moment = "feed"
		BookOverlay.sound(SND_LATCH, 1.0, -6.0)
		_press.kick(1.0)
	_refresh()


func _feed(c: Cell) -> void:
	var tier := c.tier
	var col: Color = Palette.RARITY[tier]
	if c.trophy or not NEXT.has(tier):
		# The mouth is welded shut for gold, red and trophies: they fly at it and bounce off.
		_bounce(c, true)
		return
	var fed := 0
	for r: Dictionary in rail:
		if r.item_id == c.item.id:
			fed += 1
	if c.count - fed <= 0:
		c.shiver()
		BookOverlay.sound(SND_THUD % (randi() % 3), 1.2, -12.0)
		return
	if rail.size() >= 10 or (not rail.is_empty() and str(rail[0].tier) != tier):
		_bounce(c, false)
		return
	var inv_id := _free_copy(str(c.item.id))
	if inv_id < 0:
		c.shiver()
		return
	var node := RailPiece.new()
	node.setup(_icon(str(c.item.id)), col)
	_rail_layer.add_child(node)
	var i := rail.size()
	rail.append({"inventory_id": inv_id, "item_id": str(c.item.id), "tier": tier, "node": node})
	node.position = c.global_position + Vector2(8, 8)
	var to := BookOverlay.slot_pos(i)
	var tw := node.create_tween()
	tw.tween_method(func(k: float) -> void:
		node.position = (c.global_position + Vector2(8, 8)).lerp(to, k) + Vector2(0, -sin(k * PI) * 22.0), 0.0, 1.0, 0.2)
	tw.tween_callback(func() -> void:
		BookOverlay.sound(SND_CLUNK % (i % 5), pow(2.0, i / 12.0), -6.0)
		_press.kick(0.4 + i * 0.06)
		CasinoFx.burst(_rail_layer, to + Vector2(8, 8), col, 4 + i, 50.0, 0.35)
		if rail.size() == 10:
			BookOverlay.sound(SND_HEAT, 1.0, -8.0)
	)
	_refresh()


func _free_copy(item_id: String) -> int:
	var used: Array = []
	for r: Dictionary in rail:
		used.append(int(r.inventory_id))
	var ids: Array[int] = []
	for row: Dictionary in inventory:
		if str(row.item_id) == item_id and not used.has(int(row.inventory_id)):
			ids.append(int(row.inventory_id))
	if ids.is_empty():
		return -1
	ids.sort()
	# Feed the newest copy first, so the worn one (the oldest) stays on longest.
	return ids[-1]


func _unfeed(i: int) -> void:
	if i < 0 or i >= rail.size():
		return
	var r: Dictionary = rail[i]
	rail.remove_at(i)
	var node: RailPiece = r.node
	var c: Cell = _cells.get(str(r.item_id))
	var to := c.global_position + Vector2(8, 8) if c and _cell_set[str(r.item_id)] == page else Vector2(node.position.x, -20)
	var tw := node.create_tween()
	var from := node.position
	tw.tween_method(func(k: float) -> void:
		node.position = from.lerp(to, k) + Vector2(0, -sin(k * PI) * 18.0), 0.0, 1.0, 0.18)
	tw.tween_callback(node.queue_free)
	BookOverlay.sound(SND_CLICK, 1.3, -10.0)
	for k in range(i, rail.size()):
		var n: RailPiece = rail[k].node
		n.create_tween().tween_property(n, "position", BookOverlay.slot_pos(k), 0.1)
	_refresh()


func _bounce(c: Cell, welded: bool) -> void:
	var col: Color = Palette.RARITY[c.tier]
	var from := c.global_position + Vector2(8, 8)
	var at := Vector2(PRESS.position.x - 4, 232) if welded else BookOverlay.slot_pos(mini(rail.size(), 9))
	var ghost := RailPiece.new()
	ghost.setup(_icon(str(c.item.id)), col)
	_fx.add_child(ghost)
	ghost.position = from
	var tw := ghost.create_tween()
	tw.tween_method(func(k: float) -> void:
		ghost.position = from.lerp(at, k) + Vector2(0, -sin(k * PI) * 24.0), 0.0, 1.0, 0.18)
	tw.tween_callback(func() -> void:
		BookOverlay.sound(SND_BOUNCE, 1.1 if welded else 1.4, -6.0)
		CasinoFx.burst(_fx, at + Vector2(8, 8), Palette.CREAM, 6, 70.0, 0.3)
		_press.kick(0.6)
		for r: Dictionary in rail:
			(r.node as RailPiece).rattle()
	)
	tw.tween_method(func(k: float) -> void:
		ghost.position = at.lerp(from, k) + Vector2(0, -sin(k * PI) * 30.0), 0.0, 1.0, 0.26)
	tw.tween_callback(ghost.queue_free)
	c.shiver()


func _pull() -> void:
	if mode == Mode.BUSY:
		return
	if mode != Mode.FEED or rail.size() < 10:
		_press.jiggle()
		BookOverlay.sound(SND_CLICK, 0.7, -6.0)
		if mode == Mode.LOOK:
			_toggle_feed()
		return
	mode = Mode.BUSY
	moment = "pull"
	var tier := str(rail[0].tier)
	var next: String = NEXT[tier]
	var ids: Array = []
	for r: Dictionary in rail:
		ids.append(int(r.inventory_id))
	# The lever comes down.
	BookOverlay.sound(SND_CREAK, 1.1, -6.0)
	var tw := _press.create_tween()
	tw.tween_property(_press, "lever", 1.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tw.finished
	BookOverlay.sound(SND_LATCH, 0.9, -4.0)
	BookOverlay.shake(_root, 1.0, 0.1)
	var res: Array = await Game.call_api("POST", "/casino/tradeup", {"inventory_ids": ids})
	if res[1] != "":
		_refuse(OUT + Vector2(0, -60), res[1])
		_press.create_tween().tween_property(_press, "lever", 0.0, 0.3)
		_press.cough()
		mode = Mode.FEED
		moment = "feed"
		_toggle_feed()
		return
	last_trade = res[0]
	traded += 1
	_changed = true
	var won: Dictionary = res[0].get("item", {})
	# Ten clunks, a semitone apart, and the press heats toward the next color.
	_press.heat_color = Palette.RARITY[next]
	for i in rail.size():
		var node: RailPiece = rail[i].node
		var t2 := node.create_tween().set_parallel()
		t2.tween_property(node, "position", Vector2(PRESS.position.x + 2, 234), 0.12 + (9 - i) * 0.012).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t2.tween_property(node, "scale", Vector2(0.4, 0.4), 0.14)
		t2.chain().tween_callback(node.queue_free)
	for i in 10:
		BookOverlay.sound(SND_CLUNK % (i % 5), pow(2.0, i / 12.0), -5.0)
		_press.lamps = _press.lamps.slice(0, 9 - i)
		_press.heat_target = 0.6 + i * 0.04
		_press.kick(0.3 + i * 0.08)
		BookOverlay.shake(_root, 0.5 + i * 0.12, 0.06)
		await get_tree().create_timer(0.085).timeout
	rail.clear()
	moment = "stamp"
	BookOverlay.sound(SND_HEAT, 0.9, -4.0)
	_press.rumble = 1.0
	await get_tree().create_timer(0.55).timeout
	# The stamp.
	_press.rumble = 0.0
	var down := _press.create_tween()
	down.tween_property(_press, "ram", 1.0, 0.06).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await down.finished
	BookOverlay.sound(SND_STAMP, 0.8, -2.0)
	BookOverlay.sound(SND_BOOM, 0.7, -4.0)
	BookOverlay.sound(SND_BANG, 0.8, -12.0)
	CasinoFx.flash(self, Palette.CREAM, 0.6, 0.15)
	BookOverlay.shake(_root, 3.0, 0.25)
	_press.smoke_burst()
	CasinoFx.burst(_fx, Vector2(372, 250), Palette.RARITY[next], 24, 140.0, 0.6)
	await CasinoFx.hit_stop(get_tree(), 0.09)
	_press.heat_target = 1.0
	var up := _press.create_tween().set_parallel()
	up.tween_property(_press, "ram", 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	up.tween_property(_press, "lever", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.25).timeout
	# The piece pops out of the window in its rarity's light.
	moment = "reveal"
	await _reveal(won, OUT)
	_press.heat_target = 0.0
	await Game.refresh()
	if not is_inside_tree():
		return
	_read_state()
	mode = Mode.LOOK
	_refresh()
	_dress_figure()
	moment = "landed"
	await get_tree().create_timer(0.2).timeout
	moment = "look"


## The showcase: the piece pops up big in its rarity's light (cutscene for gold and red),
## then arcs into its pocket in the book and the silhouette fills from the bottom.
func _reveal(won: Dictionary, from: Vector2) -> void:
	if won.is_empty() or not items.has(str(won.get("id", ""))):
		return
	var id := str(won.id)
	var sc := Showcase.new(won, _icon(id), _shader)
	add_child(sc)
	await sc.play(from, _root)
	if not is_inside_tree():
		return
	var start := sc.icon_rect()
	sc.fade_out()
	if _cell_set[id] != page:
		await _flip_to(_cell_set[id])
		mode = Mode.BUSY
	var c: Cell = _cells[id]
	c.count = 0
	c.show_state(0, 0, false, false)
	var fly := await _fly(_icon(id), start, Rect2(c.global_position, Vector2(32, 32)), 0.5, 40.0)
	fly.queue_free()
	BookOverlay.sound(SND_PLACE, 1.0, -4.0)
	Sfx.play("pop")
	c.show_state(int(owned.get(id, 0)) + 1, 0, equipped.values().has(id), false)
	c.fill(0.3)
	CasinoFx.burst(_fx, c.global_position + Vector2(16, 16), Palette.RARITY[c.tier], 18, 80.0, 0.5)
	_bookart.squash()
	for s in _spreads:
		s.pivot_offset = Vector2(240, BOOK.end.y)
	var sq := _spreads[page].create_tween()
	sq.tween_property(_spreads[page], "scale", Vector2(1.02, 0.97), 0.06)
	sq.tween_property(_spreads[page], "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.35).timeout


func _fly(tex: Texture2D, from: Rect2, to: Rect2, seconds: float, arc: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = from.position
	r.size = from.size
	_fx.add_child(r)
	var tw := r.create_tween()
	tw.tween_method(func(k: float) -> void:
		var e := ease(k, 0.6)
		r.position = from.position.lerp(to.position, e) + Vector2(0, -sin(k * PI) * arc)
		r.size = from.size.lerp(to.size, e), 0.0, 1.0, seconds)
	await tw.finished
	return r


## The backend said no: a dull clank and its words, floating.
func _refuse(at: Vector2, message: String) -> void:
	BookOverlay.sound(SND_ERROR, 0.8, -8.0)
	CasinoFx.float_text(_fx, at, message, Palette.MUTED, 8)


func _close() -> void:
	if mode == Mode.BUSY or moment == "closed":
		return
	moment = "closed"
	BookOverlay.sound(SND_CLOSE, 1.0, -6.0)
	var result: Variant = {"equipped": equipped, "traded": traded} if _changed else null
	var tw := _root.create_tween().set_parallel()
	tw.tween_property(_root, "scale", Vector2(0.94, 0.94), 0.12)
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	await tw.finished
	close(result)


# --- shared helpers (the draw overlay and the leader use these too) -------------------

## Every piece the book shows, by id: the casino's own and the trophy shelves' (those carry
## a `shelf`, the feature they come from).
static func load_catalog() -> Dictionary:
	if _catalog.is_empty():
		var res: Array = await Game.call_api("GET", "/casino/catalog")
		if res[1] == "" and _catalog.is_empty():
			for it: Dictionary in res[0].get("items", []):
				_catalog[str(it.id)] = it
			_sets = (res[0].get("sets", []) as Array).duplicate()
			for shelf: Dictionary in res[0].get("trophies", []):
				_sets.append({"id": str(shelf.id), "name": str(shelf.get("name", "")), "trophy": true})
				for it: Dictionary in shelf.get("items", []):
					_catalog[str(it.id)] = it
	return _catalog


## The book's spreads in order: the casino's sets, then a trophy shelf per other catalog.
static func catalog_sets() -> Array:
	return _sets


## Which spread a piece lives on.
static func page_key(item: Dictionary) -> String:
	return str(item.get("shelf", item.get("set", "")))


static func is_trophy(item: Dictionary) -> bool:
	return item.has("shelf")


static func icon_of(item: Dictionary) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = load(str(item.icon.sheet)) as Texture2D
	var r: Array = item.icon.rect
	a.region = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	a.filter_clip = true
	return a


static func flat_shader() -> Shader:
	var s := Shader.new()
	s.code = FLAT_CODE
	return s


## A material that paints a sprite one flat color (outlines, silhouettes).
static func flat(shader: Shader, color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("tint", color)
	return m


static func additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


## Soft additive light (Kenney's particle blob, tinted) centered on `center`.
static func glow(parent: Node, center: Vector2, color: Color, radius: float, alpha := 0.5) -> TextureRect:
	var g := TextureRect.new()
	g.texture = load(GLOW_TEX)
	g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	g.stretch_mode = TextureRect.STRETCH_SCALE
	g.size = Vector2(radius, radius) * 2.0
	g.position = center - g.size / 2.0
	g.material = additive()
	g.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	g.modulate = Color(color, alpha)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(g)
	return g


static func glow_sprite(parent: Node, pos: Vector2, color: Color, radius: float, alpha := 0.5) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(GLOW_TEX)
	s.material = additive()
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.scale = Vector2.ONE * radius * 2.0 / 128.0
	s.modulate = Color(color, alpha)
	s.position = pos
	parent.add_child(s)
	return s


## The pack font, crisp. Set on the shared resource, as the other features do: a duplicate
## shares the glyph cache and paints the wrong letters.
static func font(path: String) -> FontFile:
	var f: FontFile = load(path)
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return f


## Words painted in pixel type, centered on `center`.
static func words(parent: Node, text: String, center: Vector2, color: Color, px := 16, path := FONT_SMALL, outline := 0) -> Label:
	var ls := LabelSettings.new()
	ls.font = font(path)
	ls.font_size = px
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = Palette.NIGHT
	ls.shadow_size = 0 if outline > 0 else 1
	ls.shadow_color = Color(0, 0, 0, 0.55)
	ls.shadow_offset = Vector2(1, 1)
	var l := Label.new()
	l.text = text
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(200, px)
	l.position = center - l.size / 2.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## Counts in a 3x5 pixel font. Returns the width drawn.
static func draw_digits(ci: CanvasItem, text: String, at: Vector2, color: Color) -> float:
	var x := at.x
	for ch in text:
		var rows: Array = GLYPHS.get(ch, [])
		for y in rows.size():
			var row: String = rows[y]
			for i in row.length():
				if row[i] == "1":
					ci.draw_rect(Rect2(x + i, at.y + y, 1, 1), color)
		x += 4.0
	return x - at.x - 1.0


## A belt shell, 3x8: rarity color with bands (grey plain, blue one, purple two, gold three
## and a glint, red three and a pulse), on a brass base.
static func draw_shell(ci: CanvasItem, at: Vector2, tier: String, t: float) -> void:
	var col: Color = Palette.RARITY.get(tier, Palette.COMMON)
	if tier == "mythic":
		col = col.lerp(Color.WHITE, 0.25 * (0.5 + 0.5 * sin(t * TAU / 0.6)))
	var band := col.darkened(0.5)
	ci.draw_rect(Rect2(at, Vector2(3, 6)), col)
	ci.draw_rect(Rect2(at + Vector2(0, 6), Vector2(3, 2)), BRASS)
	ci.draw_rect(Rect2(at + Vector2(0, 7), Vector2(3, 1)), BRASS.darkened(0.4))
	var bands: int = {"rare": 1, "epic": 2, "legendary": 3, "mythic": 3}.get(tier, 0)
	for b in bands:
		ci.draw_rect(Rect2(at + Vector2(0, 1 + b * 2), Vector2(3, 1)), band)
	if tier == "legendary":
		ci.draw_rect(Rect2(at + Vector2(0, 0), Vector2(1, 1)), Color.WHITE)


static func slot_pos(i: int) -> Vector2:
	return SLOT0 + Vector2(i * SLOT_PITCH, 0)


static func sound(path: String, pitch := 1.0, db := -8.0) -> void:
	Sfx.play_path(path, pitch, db)


## A slice of a long pack sound on its own player under `parent`: it fades out after
## `seconds` and stops for good when `parent` goes away.
static func segment(parent: Node, path: String, seconds: float, db := -8.0, pitch := 1.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = db
	p.pitch_scale = pitch
	parent.add_child(p)
	p.play()
	var tw := p.create_tween()
	tw.tween_interval(maxf(0.0, seconds - 0.4))
	tw.tween_property(p, "volume_db", -60.0, 0.4)
	tw.tween_callback(p.queue_free)
	return p


static func shake(c: Control, strength: float, seconds: float) -> void:
	if c == null or strength <= 0.0:
		return
	var tw := c.create_tween()
	var steps := maxi(2, int(seconds / 0.03))
	for i in steps:
		var f := strength * (1.0 - float(i) / steps)
		tw.tween_property(c, "position", Vector2(randf_range(-f, f), randf_range(-f, f)).round(), 0.03)
	tw.tween_property(c, "position", Vector2.ZERO, 0.03)


## Put the worn pieces on a figure of the leader: `back` draws behind the leader's sprite,
## `front` over it, placed by `look` (WORLD_LOOK or STAGE_LOOK). Returns slot -> piece.
static func dress_pieces(back: Node2D, front: Node2D, worn: Dictionary, catalog: Dictionary, look: Dictionary) -> Dictionary:
	for n: Node in back.get_children() + front.get_children():
		n.queue_free()
	var made: Dictionary = {}
	for slot: String in ["aura", "cloak", "follower_skin", "hat", "charm"]:
		var it: Dictionary = catalog.get(str(worn.get(slot, "")), {})
		if it.is_empty() or not look.has(slot):
			continue
		var spec: Dictionary = look[slot]
		var col: Color = Palette.RARITY.get(str(it.tier), Palette.CREAM)
		var tex := icon_of(it)
		var fit: float = float(spec.px) / tex.region.size.x
		var holder := Node2D.new()
		holder.position = spec.at
		(back if spec.get("back", false) else front).add_child(holder)
		if slot == "aura":
			glow_sprite(holder, Vector2(0, float(spec.px) / 8.0), col, float(spec.glow), 0.55)
		else:
			glow_sprite(holder, Vector2.ZERO, col, float(spec.glow), 0.35)
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2(fit, fit)
		if slot == "aura":
			# An aura is light: its pack colors glow (additive), its dark pixels vanish, and it turns.
			s.material = additive()
			s.modulate = Color(1, 1, 1, 0.6)
			s.name = "Turn"
		holder.add_child(s)
		made[slot] = holder
	return made


## The one platform hook: the leader calls this from its _ready so what the book put on
## shows in the world too.
static func dress_leader(leader: Node2D, sprite: Node2D) -> void:
	var w := Worn.new()
	leader.add_child(w)
	leader.move_child(w, sprite.get_index())
	leader.add_child(w.front)


# --- the leader in the world -----------------------------------------------------------

## Worn pieces on the walking leader. It is the "back" layer (under the sprite); `front` is
## added after the sprite by dress_leader. Redresses whenever /state changes.
class Worn extends Node2D:
	var front := Node2D.new()
	var _last: Dictionary = {}
	var _t := 0.0
	var _pieces: Dictionary = {}

	func _ready() -> void:
		Game.state_changed.connect(_redress)
		_redress()

	func _redress() -> void:
		var eq: Dictionary = Game.state.get("casino", {}).get("equipped", {})
		if eq == _last:
			return
		_last = eq.duplicate()
		var catalog: Dictionary = await BookOverlay.load_catalog()
		if not is_inside_tree():
			return
		_pieces = BookOverlay.dress_pieces(self, front, _last, catalog, BookOverlay.WORLD_LOOK)

	func _process(delta: float) -> void:
		_t += delta
		var charm: Variant = _pieces.get("charm")
		if charm is Node2D and is_instance_valid(charm):
			(charm as Node2D).position.y = BookOverlay.WORLD_LOOK.charm.at.y + roundf(sin(_t * 2.2) * 1.5)
		var aura: Variant = _pieces.get("aura")
		if aura is Node2D and is_instance_valid(aura) and (aura as Node2D).has_node("Turn"):
			((aura as Node2D).get_node("Turn") as Node2D).rotation = _t * 0.8


# --- pieces of the book ------------------------------------------------------------------

## The leather, the two pages, the gutter and the brass corners.
class BookArt extends Control:
	var _squash := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(480, 270)

	func squash() -> void:
		_squash = 1.0

	func _process(delta: float) -> void:
		if _squash > 0.0:
			_squash = maxf(0.0, _squash - delta * 5.0)
			queue_redraw()

	func _draw() -> void:
		var b := BookOverlay.BOOK
		var leather := Color("3a1823")
		var leather_dark := Color("1f0b13")
		# Shadow on the counter.
		draw_rect(Rect2(b.position + Vector2(4, 5), b.size), Color(0, 0, 0, 0.5))
		draw_rect(b, leather)
		draw_rect(Rect2(b.position, Vector2(b.size.x, 1)), Color("5c2a37"))
		draw_rect(Rect2(b.position + Vector2(0, b.size.y - 2), Vector2(b.size.x, 2)), leather_dark)
		# Stitching just inside the leather.
		var inner := b.grow(-3)
		var x := inner.position.x
		while x < inner.end.x:
			draw_rect(Rect2(x, inner.position.y, 2, 1), Color("7a4a3f"))
			draw_rect(Rect2(x, inner.end.y - 1, 2, 1), Color("7a4a3f"))
			x += 4
		# Page stacks peeking out at the outer edges and the bottom.
		for k in 3:
			var c := Color("4b3d55").darkened(k * 0.18)
			draw_rect(Rect2(BookOverlay.PAGE_L.position + Vector2(-1 - k, 1 + k), BookOverlay.PAGE_L.size), c)
			draw_rect(Rect2(BookOverlay.PAGE_R.position + Vector2(1 + k, 1 + k), BookOverlay.PAGE_R.size), c)
		for pg: Rect2 in [BookOverlay.PAGE_L, BookOverlay.PAGE_R]:
			draw_rect(pg, Color("2b2133"))
			# Faint ruled lines, like an old ledger.
			var y := pg.position.y + 15.0
			while y < pg.end.y - 4:
				draw_rect(Rect2(pg.position.x + 6, y, pg.size.x - 12, 1), Color("31263a"))
				y += 9.0
			draw_rect(Rect2(pg.position, Vector2(pg.size.x, 1)), Color("3b2f45"))
		# The gutter: the paper darkens into the spine.
		var spine := BookOverlay.PAGE_L.end.x
		for k in 10:
			var a := 0.42 * (1.0 - k / 10.0)
			draw_rect(Rect2(spine - 1 - k, BookOverlay.PAGE_L.position.y, 1, BookOverlay.PAGE_L.size.y), Color(0, 0, 0, a))
			draw_rect(Rect2(spine + 4 + k, BookOverlay.PAGE_R.position.y, 1, BookOverlay.PAGE_R.size.y), Color(0, 0, 0, a))
		draw_rect(Rect2(spine, b.position.y + 2, 4, b.size.y - 4), Color("140810"))
		var yy := b.position.y + 8
		while yy < b.end.y - 8:
			draw_rect(Rect2(spine + 1, yy, 2, 2), Color("6b3a3a"))
			yy += 10
		# Brass corners.
		for cx: float in [b.position.x, b.end.x - 8]:
			for cy: float in [b.position.y, b.end.y - 8]:
				draw_rect(Rect2(cx, cy, 8, 8), BookOverlay.BRASS)
				draw_rect(Rect2(cx + 1, cy + 1, 6, 6), Color("c99a4a"))
				draw_rect(Rect2(cx + 2, cy + 2, 2, 2), BookOverlay.BRASS_LIT)
				draw_rect(Rect2(cx + 5, cy + 5, 1, 1), Color("6b4a22"))


## A page that sweeps over the spine when the book flips to another set.
class Leaf extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("362a40"))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 1)), Color("4b3d55"))
		for k in 6:
			draw_rect(Rect2(k * size.x / 6.0, 0, 1, size.y), Color(0, 0, 0, 0.12))


## One set's spread: its heading, the tier shells beside each block, and its pockets.
class SpreadArt extends Control:
	var markers: Array = []
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		if visible:
			queue_redraw()

	func _draw() -> void:
		for m: Dictionary in markers:
			BookOverlay.draw_shell(self, m.pos, m.tier, _t)


## A ribbon on the book's edge for one set; the set's best piece pressed into it.
class Tab extends Control:
	var index := 0
	var color := Palette.TEAL
	var active := false
	var _emblem: TextureRect

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_emblem(tex: AtlasTexture, mat: Material) -> void:
		_emblem = TextureRect.new()
		_emblem.texture = tex
		_emblem.material = mat
		_emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_emblem.stretch_mode = TextureRect.STRETCH_SCALE
		_emblem.size = Vector2(12, 12)
		_emblem.position = Vector2(5, 9)
		_emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_emblem)

	func _draw() -> void:
		var c := color if active else color.darkened(0.55)
		var w := size.x if active else size.x - 4
		draw_rect(Rect2(0, 0, w, size.y - 4), c)
		# A notched tail.
		draw_rect(Rect2(0, size.y - 4, w / 2.0 - 1, 4), c)
		draw_rect(Rect2(w / 2.0 + 1, size.y - 4, w / 2.0 - 1, 4), c)
		draw_rect(Rect2(0, 0, w, 1), c.lightened(0.3))
		draw_rect(Rect2(w - 1, 0, 1, size.y - 4), c.darkened(0.35))
		draw_rect(Rect2(0, 0, 3, size.y), Color(0, 0, 0, 0.35))
		if _emblem:
			_emblem.modulate.a = 1.0 if active else 0.55


## One pocket in the book.
class Cell extends Control:
	var item: Dictionary = {}
	var tier := ""
	var trophy := false
	## 2 for a small trophy shelf's big mounted pockets, else 1.
	var base := 1.0
	var count := 0
	var fed := 0
	var worn := false
	var dim := false
	var _t := 0.0
	var _home := Vector2.ZERO
	var _glow: TextureRect
	var _rays: BookOverlay.Rays
	var _outline: Array[TextureRect] = []
	var _rim: Array[TextureRect] = []
	var _sil: TextureRect
	var _clip := Control.new()
	var _icon: TextureRect
	var _over := BookOverlay.CellOver.new()
	var _motes: CPUParticles2D

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(32, 32)
		pivot_offset = Vector2(16, 16)

	func setup(it: Dictionary, tex: Texture2D, outline_mat: Material, sil_mat: Material, rim_mat: Material) -> void:
		item = it
		tier = str(it.tier)
		trophy = BookOverlay.is_trophy(it)
		_home = position
		var col: Color = Palette.RARITY[tier]
		var big := tier == "legendary" or tier == "mythic"
		if big:
			_rays = BookOverlay.Rays.new()
			_rays.color = Color(col, 0.22 if tier == "legendary" else 0.3)
			_rays.radius = 26.0
			_rays.count = 10
			_rays.spin = 0.35 if tier == "legendary" else -0.5
			_rays.position = Vector2(16, 16) - Vector2(26, 26)
			_rays.size = Vector2(52, 52)
			add_child(_rays)
		_glow = BookOverlay.glow(self, Vector2(16, 16), col, 46.0, 0.3)
		for d: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			_rim.append(_tex_rect(tex, d, rim_mat, self))
		for d: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			_outline.append(_tex_rect(tex, d, outline_mat, self))
		_sil = _tex_rect(tex, Vector2.ZERO, sil_mat, self)
		_clip.clip_contents = true
		_clip.size = size
		_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_clip)
		_icon = _tex_rect(tex, Vector2.ZERO, null, _clip)
		if big:
			_motes = CPUParticles2D.new()
			_motes.amount = 6 if tier == "legendary" else 9
			_motes.lifetime = 1.6
			_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			_motes.emission_rect_extents = Vector2(12, 8)
			_motes.position = Vector2(16, 18)
			_motes.direction = Vector2(0, -1) if tier == "mythic" else Vector2(0, 1)
			_motes.spread = 20.0
			_motes.gravity = Vector2.ZERO
			_motes.initial_velocity_min = 6.0
			_motes.initial_velocity_max = 12.0
			_motes.color = Color(col.lightened(0.3), 0.9)
			_motes.material = BookOverlay.additive()
			add_child(_motes)
		_over.cell = self
		_over.size = size
		add_child(_over)

	func _tex_rect(tex: Texture2D, offset: Vector2, mat: Material, parent: Control) -> TextureRect:
		var r := TextureRect.new()
		r.texture = tex
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.size = Vector2(32, 32)
		r.position = offset
		r.material = mat
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(r)
		return r

	func show_state(n: int, on_rail: int, is_worn: bool, is_dim: bool) -> void:
		count = n
		fed = on_rail
		worn = is_worn
		dim = is_dim
		var have := count > 0
		var left := count - fed
		_glow.visible = have and left > 0
		if _rays:
			_rays.visible = have and left > 0
		if _motes:
			_motes.emitting = have and left > 0
		for o in _outline:
			o.visible = have and left > 0
		for r in _rim:
			r.visible = not have
		_sil.visible = not have
		_clip.visible = have
		_icon.modulate.a = 1.0 if left > 0 else 0.28
		_over.queue_redraw()
		queue_redraw()

	## The silhouette fills with color from the bottom.
	func fill(seconds: float) -> void:
		var tw := create_tween()
		tw.tween_method(func(v: float) -> void:
			_clip.position.y = 32.0 - v
			_clip.size.y = v
			_icon.position.y = -(32.0 - v), 0.0, 32.0, seconds)
		var pop := create_tween()
		pop.tween_property(self, "scale", Vector2.ONE * 1.3 * base, 0.08)
		pop.tween_property(self, "scale", Vector2.ONE * base, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func shiver() -> void:
		var tw := create_tween()
		for k in 4:
			tw.tween_property(self, "position", _home + Vector2(1.0 if k % 2 == 0 else -1.0, 0), 0.04)
		tw.tween_property(self, "position", _home, 0.04)

	func wiggle() -> void:
		var tw := create_tween()
		tw.tween_property(self, "rotation", 0.18, 0.06)
		tw.tween_property(self, "rotation", -0.14, 0.08)
		tw.tween_property(self, "rotation", 0.0, 0.08)
		var s := create_tween()
		s.tween_property(self, "scale", Vector2.ONE * 1.15 * base, 0.06)
		s.tween_property(self, "scale", Vector2.ONE * base, 0.16)

	func _process(delta: float) -> void:
		_t += delta
		if count > 0 and _glow.visible:
			var rank := BookOverlay.TIERS.find(tier)
			var base: float = [0.14, 0.4, 0.55, 0.62, 0.72][maxi(rank, 0)]
			var amp := 0.0 if rank <= 0 else 0.06 + 0.04 * rank
			_glow.modulate.a = base + amp * sin(_t * (1.4 + rank * 0.5) + _home.x * 0.05)

	func _draw() -> void:
		var col: Color = Palette.RARITY[tier]
		var have := count > 0
		draw_rect(Rect2(-1, -1, 34, 34), Color("150e1a"))
		draw_rect(Rect2(-1, -1, 34, 1), Color("0b0710"))
		draw_rect(Rect2(-1, -1, 1, 34), Color("0b0710"))
		draw_rect(Rect2(-1, 32, 34, 1), Color("3a2d44"))
		draw_rect(Rect2(32, -1, 1, 34), Color("3a2d44"))
		# The rarity bar along the bottom, like the reel's cards.
		draw_rect(Rect2(1, 30, 30, 2), Color(col, 0.95 if have else 0.3))
		if trophy:
			# Mounted: brass brackets on the corners of a trophy's pocket.
			var b := BookOverlay.BRASS if have else BookOverlay.BRASS.darkened(0.55)
			for corner: Vector2 in [Vector2(-2, -2), Vector2(30, -2), Vector2(-2, 30), Vector2(30, 30)]:
				var hy := corner.y if corner.y < 0 else corner.y + 3
				var vx := corner.x if corner.x < 0 else corner.x + 3
				draw_rect(Rect2(corner.x, hy, 4, 1), b)
				draw_rect(Rect2(vx, corner.y, 1, 4), b)
				if have:
					draw_rect(Rect2(vx, hy, 1, 1), BookOverlay.BRASS_LIT)
		if worn:
			draw_rect(Rect2(-2, -2, 36, 1), Palette.CREAM)
			draw_rect(Rect2(-2, 33, 36, 1), Palette.CREAM)
			draw_rect(Rect2(-2, -2, 1, 36), Palette.CREAM)
			draw_rect(Rect2(33, -2, 1, 36), Palette.CREAM)


## Over the pocket: the count, the worn pin, and the dimming while the press is fed.
class CellOver extends Control:
	var cell: BookOverlay.Cell

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if cell == null:
			return
		if cell.dim:
			draw_rect(Rect2(-1, -1, 34, 34), Color(0.03, 0.02, 0.05, 0.66))
		var left := cell.count - cell.fed
		if left >= 2 or (cell.fed > 0 and left >= 1):
			var text := "x%d" % left
			var w := text.length() * 4.0 - 1.0
			draw_rect(Rect2(31 - w - 2, 21, w + 3, 8), Color(Palette.NIGHT, 0.92))
			draw_rect(Rect2(31 - w - 2, 21, w + 3, 1), Color("3a2d44"))
			BookOverlay.draw_digits(self, text, Vector2(31 - w - 0.5, 22), Palette.CREAM)
		if cell.worn:
			var d := ["00100", "01110", "11111", "01110", "00100"]
			draw_rect(Rect2(0, 0, 7, 7), Color(Palette.NIGHT, 0.9))
			for y in 5:
				for x in 5:
					if d[y][x] == "1":
						draw_rect(Rect2(1 + x, 1 + y, 1, 1), Palette.CREAM)


## Rotating light rays (additive), for gold and red.
class Rays extends Control:
	var color := Color.WHITE
	var radius := 24.0
	var count := 8
	var spin := 0.4
	var width := 0.13
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		material = BookOverlay.additive()

	func _process(delta: float) -> void:
		_t += delta
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		for i in count:
			var a := _t * spin + TAU * i / count
			var pts := PackedVector2Array([c, c + Vector2.from_angle(a - width) * radius, c + Vector2.from_angle(a + width) * radius])
			draw_polygon(pts, PackedColorArray([color, Color(color, 0.0), Color(color, 0.0)]))


## The leader's stage: a lamp cone and a round dais.
class StageArt extends Control:
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		var cone := BookOverlay.StageCone.new()
		cone.size = size
		add_child(cone)
		move_child(cone, 0)

	func _draw() -> void:
		var f := BookOverlay.FEET - position
		draw_rect(Rect2(f.x - 32, f.y - 1, 64, 7), Color("2a2230"))
		draw_rect(Rect2(f.x - 32, f.y - 2, 64, 1), Color("4a3e55"))
		draw_rect(Rect2(f.x - 28, f.y + 6, 56, 2), Color("17121c"))
		draw_rect(Rect2(f.x - 20, f.y - 2, 40, 1), Color("6a5878"))


## The lamp's cone of light over the stage (additive).
class StageCone extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		material = BookOverlay.additive()

	func _draw() -> void:
		var f := BookOverlay.FEET - BookOverlay.STAGE.position
		var top := 2.0
		var pts := PackedVector2Array([Vector2(f.x - 7, top), Vector2(f.x + 7, top), Vector2(f.x + 36, f.y + 2), Vector2(f.x - 36, f.y + 2)])
		var a := Color(BookOverlay.LAMP, 0.16)
		var b := Color(BookOverlay.LAMP, 0.04)
		draw_polygon(pts, PackedColorArray([a, a, b, b]))


## A piece sitting on the press's rail.
class RailPiece extends Control:
	var _icon := TextureRect.new()
	var _glow: TextureRect

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(16, 16)
		pivot_offset = Vector2(8, 8)

	func setup(tex: Texture2D, col: Color) -> void:
		_glow = BookOverlay.glow(self, Vector2(8, 8), col, 18.0, 0.45)
		_icon.texture = tex
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.stretch_mode = TextureRect.STRETCH_SCALE
		_icon.size = Vector2(16, 16)
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_icon)

	func rattle() -> void:
		var tw := create_tween()
		tw.tween_property(self, "rotation", 0.25, 0.04)
		tw.tween_property(self, "rotation", -0.2, 0.05)
		tw.tween_property(self, "rotation", 0.0, 0.05)


## The trade-up press, its rail of ten sockets with lamps, and the lever. Drawn in overlay
## space. Its numbers are animated by the overlay; it only draws them.
class PressArt extends Control:
	var open := 0.0
	var open_target := 0.0
	var ram := 0.0
	var lever := 0.0
	var heat := 0.0
	var heat_target := 0.0
	var heat_color := BookOverlay.LAMP
	var full := false
	var full_color := BookOverlay.LAMP
	var hint := false
	var hint_color := BookOverlay.LAMP
	var lamps: Array[Color] = []
	var rail_on := false
	var rumble := 0.0
	var _blink := 0.0
	var _jiggle := 0.0
	var _kick := 0.0
	var _t := 0.0
	var _wheel := 0.0
	var _window_glow: TextureRect
	var _ram_glow: TextureRect
	var _knob_glow: TextureRect
	var _smoke := CPUParticles2D.new()
	var _sparks := CPUParticles2D.new()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(480, 270)

	func _ready() -> void:
		_ram_glow = BookOverlay.glow(self, Vector2(372, 244), BookOverlay.LAMP, 60.0, 0.0)
		_window_glow = BookOverlay.glow(self, BookOverlay.OUT, BookOverlay.LAMP, 26.0, 0.0)
		_knob_glow = BookOverlay.glow(self, Vector2(450, 220), BookOverlay.LAMP, 22.0, 0.0)
		_smoke.texture = load(BookOverlay.SMOKE_TEX)
		_smoke.amount = 10
		_smoke.lifetime = 2.4
		_smoke.position = Vector2(417, 192)
		_smoke.direction = Vector2(0.2, -1)
		_smoke.spread = 14.0
		_smoke.gravity = Vector2(4, -6)
		_smoke.initial_velocity_min = 6.0
		_smoke.initial_velocity_max = 12.0
		_smoke.scale_amount_min = 0.05
		_smoke.scale_amount_max = 0.12
		_smoke.color = Color(0.45, 0.4, 0.5, 0.22)
		_smoke.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(_smoke)
		_sparks.amount = 14
		_sparks.lifetime = 0.5
		_sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		_sparks.emission_rect_extents = Vector2(26, 1)
		_sparks.position = Vector2(372, 250)
		_sparks.direction = Vector2(0, -1)
		_sparks.spread = 60.0
		_sparks.gravity = Vector2(0, 160)
		_sparks.initial_velocity_min = 30.0
		_sparks.initial_velocity_max = 70.0
		_sparks.material = BookOverlay.additive()
		_sparks.emitting = false
		add_child(_sparks)

	func kick(strength: float) -> void:
		_kick = maxf(_kick, strength)

	func jiggle() -> void:
		_jiggle = 1.0
		_blink = 1.0

	func cough() -> void:
		smoke_burst()
		_kick = 1.0

	func smoke_burst() -> void:
		var p := CPUParticles2D.new()
		p.texture = load(BookOverlay.SMOKE_TEX)
		p.one_shot = true
		p.amount = 14
		p.lifetime = 1.0
		p.explosiveness = 0.9
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(30, 2)
		p.position = Vector2(372, 250)
		p.direction = Vector2(0, -1)
		p.spread = 80.0
		p.gravity = Vector2(0, -10)
		p.initial_velocity_min = 20.0
		p.initial_velocity_max = 50.0
		p.scale_amount_min = 0.08
		p.scale_amount_max = 0.2
		p.color = Color(0.6, 0.55, 0.62, 0.45)
		p.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(p)
		p.emitting = true
		get_tree().create_timer(1.3).timeout.connect(p.queue_free)

	func _process(delta: float) -> void:
		_t += delta
		open = move_toward(open, open_target, delta * 6.0)
		heat = move_toward(heat, heat_target, delta * 1.5)
		_kick = move_toward(_kick, 0.0, delta * 4.0)
		_jiggle = move_toward(_jiggle, 0.0, delta * 2.5)
		_blink = move_toward(_blink, 0.0, delta * 1.2)
		_wheel += delta * (0.6 + heat * 6.0 + rumble * 8.0)
		var hint_a := (0.12 + 0.08 * sin(_t * 2.4)) if hint else 0.0
		_ram_glow.modulate = Color(heat_color if heat > 0.01 else hint_color, maxf(heat * 0.75, hint_a))
		_window_glow.modulate = Color(heat_color if heat > 0.01 else hint_color, maxf(heat, hint_a * 2.0))
		var knob := _knob_pos()
		_knob_glow.position = knob - _knob_glow.size / 2.0
		_knob_glow.modulate = Color(full_color, (0.55 + 0.3 * sin(_t * 7.0)) if full else 0.0)
		_sparks.color = heat_color.lightened(0.3)
		_sparks.emitting = heat > 0.55
		_smoke.speed_scale = 1.0 + heat * 2.0
		queue_redraw()

	func _shake() -> Vector2:
		var s := _kick * 1.5 + rumble * 1.2
		if s <= 0.05:
			return Vector2.ZERO
		return Vector2(randf_range(-s, s), randf_range(-s * 0.5, s * 0.5)).round()

	func _lever_angle() -> float:
		var a := lerpf(-1.78, 0.12, lever)
		if full and lever < 0.01:
			a += sin(_t * 18.0) * 0.05
		a += sin(_t * 40.0) * 0.12 * _jiggle
		return a

	func _knob_pos() -> Vector2:
		return BookOverlay.PIVOT + Vector2.from_angle(_lever_angle()) * 34.0

	func _draw() -> void:
		var iron := BookOverlay.IRON
		var dark := BookOverlay.IRON_DARK
		var brass := BookOverlay.BRASS
		var lit := BookOverlay.BRASS_LIT
		# --- the rail: a brass trough with ten sockets and a lamp over each ---
		var r := BookOverlay.RAIL
		draw_rect(Rect2(r.position.x, 229, r.size.x, 23), Color("1b1620"))
		draw_rect(Rect2(r.position.x, 228, r.size.x, 1), brass)
		draw_rect(Rect2(r.position.x, 252, r.size.x, 2), Color("6b4a22"))
		draw_rect(Rect2(r.position.x, 251, r.size.x, 1), Color("c99a4a"))
		for x: float in [r.position.x + 6, r.position.x + 108, r.position.x + 206]:
			draw_rect(Rect2(x, 254, 3, 14), Color("2a2230"))
			draw_rect(Rect2(x - 2, 267, 7, 2), Color("17121c"))
		for i in 10:
			var p := BookOverlay.slot_pos(i)
			draw_rect(Rect2(p - Vector2(1, 1), Vector2(18, 18)), Color("0d0a10"))
			draw_rect(Rect2(p + Vector2(-1, 17), Vector2(18, 1)), Color("3a2e44"))
			var lamp := Rect2(p + Vector2(5, -10), Vector2(6, 4))
			draw_rect(lamp.grow(1), dark)
			var on := i < lamps.size()
			var c := Color("3a2a1c")
			if on:
				c = lamps[i].lightened(0.15)
			elif _blink > 0.0 and int(_t * 10.0) % 2 == 0:
				c = Palette.CREAM
			elif rail_on:
				c = Color(BookOverlay.LAMP, 0.35)
			draw_rect(lamp, c)
			if on:
				draw_rect(Rect2(lamp.position, Vector2(2, 1)), Color.WHITE)
		# --- the press ---
		var o := _shake()
		var ry := 220.0 + ram * 16.0
		# Screw and flywheel above the crossbeam (the screw sinks as the ram comes down).
		var screw_top := 194.0 + ram * 8.0
		draw_rect(Rect2(Vector2(369, screw_top) + o, Vector2(6, 210 - screw_top)), Color("5a5460"))
		var yy := screw_top
		while yy < 208:
			draw_rect(Rect2(Vector2(369, yy) + o, Vector2(6, 1)), Color("8a8290"))
			yy += 3
		var half := absf(cos(_wheel)) * 22.0 + 2.0
		draw_rect(Rect2(Vector2(372 - half, screw_top - 2) + o, Vector2(half * 2.0, 3)), brass)
		draw_rect(Rect2(Vector2(372 - half, screw_top - 2) + o, Vector2(half * 2.0, 1)), lit)
		for s: float in [-1.0, 1.0]:
			draw_rect(Rect2(Vector2(372 + s * half - 2, screw_top - 4) + o, Vector2(4, 6)), Color("6b4a22"))
			draw_rect(Rect2(Vector2(372 + s * half - 1, screw_top - 4) + o, Vector2(2, 1)), lit)
		# Smokestack.
		draw_rect(Rect2(Vector2(414, 196) + o, Vector2(7, 12)), iron)
		draw_rect(Rect2(Vector2(413, 195) + o, Vector2(9, 2)), brass)
		# Crossbeam.
		draw_rect(Rect2(Vector2(322, 208) + o, Vector2(100, 10)), iron)
		draw_rect(Rect2(Vector2(322, 208) + o, Vector2(100, 1)), lit)
		draw_rect(Rect2(Vector2(322, 209) + o, Vector2(100, 1)), brass)
		draw_rect(Rect2(Vector2(322, 217) + o, Vector2(100, 1)), dark)
		for k in 8:
			draw_rect(Rect2(Vector2(327 + k * 13, 212) + o, Vector2(1, 1)), lit)
		# Pillars.
		for px: float in [328.0, 408.0]:
			draw_rect(Rect2(Vector2(px, 218) + o, Vector2(8, 32)), iron)
			draw_rect(Rect2(Vector2(px, 218) + o, Vector2(1, 32)), Color("4a4454"))
			draw_rect(Rect2(Vector2(px + 7, 218) + o, Vector2(1, 32)), dark)
		# The ram, its die plate with an eye cut in it, hot as the press heats.
		var ram_col := iron.lerp(heat_color, heat * 0.5)
		draw_rect(Rect2(Vector2(342, ry) + o, Vector2(60, 14)), ram_col)
		draw_rect(Rect2(Vector2(342, ry) + o, Vector2(60, 1)), Color("4a4454"))
		draw_rect(Rect2(Vector2(344, ry + 11) + o, Vector2(56, 3)), brass.lerp(heat_color, heat * 0.6))
		draw_rect(Rect2(Vector2(368, ry + 5) + o, Vector2(8, 3)), dark)
		draw_rect(Rect2(Vector2(371, ry + 5) + o, Vector2(2, 3)), heat_color if heat > 0.2 else Color("5a5460"))
		# The bed and its output window.
		draw_rect(Rect2(Vector2(322, 250) + o, Vector2(100, 20)), iron)
		draw_rect(Rect2(Vector2(322, 250) + o, Vector2(100, 2)), brass)
		draw_rect(Rect2(Vector2(322, 250) + o, Vector2(100, 1)), lit)
		draw_rect(Rect2(Vector2(322, 268) + o, Vector2(100, 2)), dark)
		for k in 8:
			draw_rect(Rect2(Vector2(327 + k * 13, 254) + o, Vector2(1, 1)), lit)
		var win := Rect2(Vector2(358, 256) + o, Vector2(28, 8))
		draw_rect(win.grow(1), brass)
		draw_rect(win, Color("08050a").lerp(heat_color, heat * 0.45))
		# The mouth where the rail goes in, and its shutter.
		draw_rect(Rect2(Vector2(318, 228) + o, Vector2(10, 24)), dark)
		var sh := Rect2(Vector2(318, 228 - open * 20.0) + o, Vector2(10, 24))
		draw_rect(sh, Color("4a4252"))
		draw_rect(Rect2(sh.position + Vector2(0, 4), Vector2(10, 1)), brass)
		draw_rect(Rect2(sh.position + Vector2(0, 18), Vector2(10, 1)), brass)
		# --- the lever ---
		var pv := BookOverlay.PIVOT
		draw_rect(Rect2(pv + Vector2(-8, -8), Vector2(18, 20)), iron)
		draw_rect(Rect2(pv + Vector2(-8, -8), Vector2(18, 1)), lit)
		draw_rect(Rect2(pv + Vector2(-2, -6), Vector2(4, 14)), dark)
		var knob := _knob_pos()
		draw_line(pv, knob, Color("6b4a22"), 3.0)
		draw_line(pv, knob, brass, 1.0)
		draw_rect(Rect2(pv - Vector2(2, 2), Vector2(4, 4)), lit)
		var kc := Color("e8dcc4") if not full else Color("e8dcc4").lerp(full_color, 0.5 + 0.3 * sin(_t * 7.0))
		draw_rect(Rect2(knob - Vector2(4, 4), Vector2(8, 8)), Color("3a2a1c"))
		draw_rect(Rect2(knob - Vector2(3, 3), Vector2(6, 6)), kc)
		draw_rect(Rect2(knob - Vector2(2, 3), Vector2(2, 1)), Color.WHITE)


## The reveal: the piece pops up big in its rarity's light. Gold and red get a short
## cutscene (the room goes dark, a beam, falling flakes or rising embers, a slow zoom).
## Tapping hurries it along after the first half second.
class Showcase extends Control:
	const CENTER := Vector2(240, 104)
	const SIZE := 64.0
	var item: Dictionary
	var tier := ""
	var tapped := false
	var _tex: Texture2D
	var _shader: Shader
	var _veil := ColorRect.new()
	var _holder := Control.new()
	var _rays: BookOverlay.Rays
	var _glow: TextureRect
	var _beam: TextureRect
	var _name: Label
	var _t := 0.0
	var _spin := false

	func _init(it: Dictionary, tex: Texture2D, shader: Shader) -> void:
		item = it
		tier = str(it.get("tier", "common"))
		_tex = tex
		_shader = shader
		size = Vector2(480, 270)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb and mb.pressed:
			tapped = true
			accept_event()

	func _ready() -> void:
		var col: Color = Palette.RARITY.get(tier, Palette.CREAM)
		_veil.color = Color(Palette.NIGHT, 0.0)
		_veil.size = size
		_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_veil)
		_beam = TextureRect.new()
		_beam.texture = load(BookOverlay.GLOW_TEX)
		_beam.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_beam.stretch_mode = TextureRect.STRETCH_SCALE
		_beam.material = BookOverlay.additive()
		_beam.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_beam.size = Vector2(56, 360)
		_beam.position = Vector2(CENTER.x - 28, -90)
		_beam.modulate = Color(col, 0.0)
		_beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_beam)
		_rays = BookOverlay.Rays.new()
		_rays.color = Color(col, 0.0)
		_rays.radius = 90.0
		_rays.count = 12
		_rays.spin = 0.25
		_rays.position = CENTER - Vector2(90, 90)
		_rays.size = Vector2(180, 180)
		add_child(_rays)
		_glow = BookOverlay.glow(self, CENTER, col, 80.0, 0.0)
		_holder.size = Vector2(SIZE, SIZE)
		_holder.pivot_offset = Vector2(SIZE, SIZE) / 2.0
		_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_holder)
		var mat := BookOverlay.flat(_shader, col)
		for d: Vector2 in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
			_rect(d, mat)
		_rect(Vector2.ZERO, null)
		_name = BookOverlay.words(self, str(item.get("name", "")), CENTER + Vector2(0, SIZE / 2.0 + 14), col.lightened(0.25), 20, BookOverlay.FONT_BIG, 4)
		_name.modulate.a = 0.0

	func _rect(offset: Vector2, mat: Material) -> void:
		var r := TextureRect.new()
		r.texture = _tex
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.size = Vector2(SIZE, SIZE)
		r.position = offset
		r.material = mat
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_holder.add_child(r)

	func icon_rect() -> Rect2:
		var s := _holder.scale.x
		return Rect2(_holder.position + _holder.size * (1.0 - s) / 2.0, _holder.size * s)

	func fade_out() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_holder.visible = false
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.25)
		tw.tween_callback(queue_free)

	func _process(delta: float) -> void:
		_t += delta
		if _spin:
			_holder.scale.x = absf(_holder.scale.y) * cos(_t * 5.0)

	func play(from: Vector2, root: Control) -> void:
		var col: Color = Palette.RARITY.get(tier, Palette.CREAM)
		var spec: Dictionary = BookOverlay.REVEAL.get(tier, BookOverlay.REVEAL.common)
		var big := tier == "legendary" or tier == "mythic"
		_holder.position = from - _holder.size / 2.0
		_holder.scale = Vector2(0.25, 0.25)
		if tier == "mythic":
			# Everything goes black but a red glow, then the sub boom.
			var dark := create_tween()
			dark.tween_property(_veil, "color:a", 1.0, 0.15)
			_glow.modulate.a = 0.5
			await get_tree().create_timer(0.5).timeout
		BookOverlay.sound(BookOverlay.SND_WHOOSH, 0.9, -6.0)
		var tw := create_tween().set_parallel()
		tw.tween_property(_holder, "position", CENTER - _holder.size / 2.0, 0.34).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.tween_property(_holder, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_veil, "color:a", float(spec.veil), 0.3)
		await tw.finished
		# The hit.
		Sfx.play("reveal_" + tier)
		BookOverlay.sound(BookOverlay.STINGER.get(tier, ""), 1.0, -10.0)
		if float(spec.flash) > 0.0:
			CasinoFx.flash(self, col, float(spec.flash), float(spec.fade))
		CasinoFx.burst(self, CENTER, col, int(spec.sparks), 170.0, 0.9)
		CasinoFx.burst(self, CENTER, Palette.CREAM, int(spec.sparks) / 4 + 2, 120.0, 0.6)
		BookOverlay.shake(root, float(spec.shake), float(spec.shake_s))
		BookOverlay.shake(self, float(spec.shake) * 0.5, float(spec.shake_s))
		var punch := _holder.create_tween()
		punch.tween_property(_holder, "scale", Vector2(1.25, 1.25), 0.07)
		punch.tween_property(_holder, "scale", Vector2(1.1, 1.1), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var lights := create_tween().set_parallel()
		lights.tween_property(_rays, "color:a", float(spec.rays), 0.2)
		lights.tween_property(_glow, "modulate:a", float(spec.glow), 0.15)
		if tier in ["epic", "legendary", "mythic"]:
			var beam := create_tween()
			beam.tween_property(_beam, "modulate:a", 0.55 if big else 0.4, 0.12)
			if not big:
				beam.tween_interval(0.45)
				beam.tween_property(_beam, "modulate:a", 0.0, 0.3)
		await CasinoFx.hit_stop(get_tree(), float(spec.stop))
		if big:
			BookOverlay.segment(self, BookOverlay.SND_CHOIR, 3.4, -10.0)
			_fall(col, tier == "mythic")
			_spin = true
			var stop_spin := create_tween()
			stop_spin.tween_interval(1.2)
			stop_spin.tween_callback(func() -> void: _spin = false)
			stop_spin.tween_method(func(k: float) -> void: _holder.scale.x = lerpf(_holder.scale.x, _holder.scale.y, k), 0.0, 1.0, 0.15)
		if float(spec.zoom) > 1.0:
			var z := _holder.create_tween()
			z.tween_property(_holder, "scale", Vector2.ONE * 1.1 * float(spec.zoom), 0.8 if tier != "mythic" else 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		var nm := create_tween()
		nm.tween_interval(0.15)
		nm.tween_property(_name, "modulate:a", 1.0, 0.25)
		tapped = false
		var held := 0.0
		var hold := float(spec.hold)
		while held < hold and not (tapped and held > (1.0 if big else 0.5)):
			await get_tree().process_frame
			held += get_process_delta_time()

	## Gold flakes fall, or red embers rise, for the length of the cutscene.
	func _fall(col: Color, rise: bool) -> void:
		var p := CPUParticles2D.new()
		p.amount = 60 if rise else 40
		p.lifetime = 2.6
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(200, 2)
		p.position = Vector2(240, 280 if rise else -6)
		p.direction = Vector2(0, -1 if rise else 1)
		p.spread = 15.0
		p.gravity = Vector2(0, -12 if rise else 20)
		p.initial_velocity_min = 30.0
		p.initial_velocity_max = 70.0
		p.scale_amount_min = 1.0
		p.scale_amount_max = 2.0
		p.color = col.lightened(0.2)
		p.material = BookOverlay.additive()
		add_child(p)
		move_child(p, 1)


## The casino counter under the book: dark planks, the lamp's pool, a candle and an eye.
class Counter extends Control:
	const CANDLES := "res://art/packs/vk-candles-with-eyes/candles_with_eyes.png"
	var _flames: Array[TextureRect] = []
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(480, 270)

	func _ready() -> void:
		# A tall candle on the left, an eye on a stand on the right (vk, CC0).
		for spec: Array in [[Rect2(0, 0, 18, 41), Vector2(9, 74), true], [Rect2(126, 0, 18, 41), Vector2(460, 126), false]]:
			var a := AtlasTexture.new()
			a.atlas = load(CANDLES)
			a.region = spec[0]
			var r := TextureRect.new()
			r.texture = a
			r.position = spec[1]
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(r)
			if spec[2]:
				_flames.append(BookOverlay.glow(self, (spec[1] as Vector2) + Vector2(9, 5), Color("ffb98a"), 30.0, 0.45))
			else:
				_flames.append(BookOverlay.glow(self, (spec[1] as Vector2) + Vector2(9, 12), Palette.MUTED, 22.0, 0.25))

	func _process(delta: float) -> void:
		_t += delta
		if not _flames.is_empty():
			_flames[0].modulate.a = 0.4 + 0.08 * sin(_t * 9.0) + 0.05 * sin(_t * 23.0)
		if _flames.size() > 1:
			_flames[1].modulate.a = 0.18 + 0.1 * maxf(0.0, sin(_t * 0.9))

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("140c0a"))
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var y := 0.0
		while y < 270.0:
			draw_rect(Rect2(0, y, 480, 1), Color("0a0605"))
			draw_rect(Rect2(0, y + 1, 480, 1), Color("21140f"))
			for k in 12:
				draw_rect(Rect2(rng.randf_range(0, 470), y + rng.randi_range(4, 19), rng.randf_range(10, 60), 1), Color("1c110c"))
			y += 22.0
		for k in 28:
			var a := 0.5 * pow(1.0 - k / 28.0, 2.0)
			draw_rect(Rect2(k, k, 480 - 2 * k, 270 - 2 * k), Color(0, 0, 0, a), false, 1.0)
