class_name CaseOverlay
extends Overlay
## The case machine up close: the front door's main event.
##
## Tap a slot mouth (House Fund or Brokerage, each with its real balance painted on it), hold
## the bill on the slot for 0.45 s, and POST /casino/case. The money lands first, every time:
## stamp, motes into the jar, "+$20 House Fund", the chant. Then a breath, the bang, and the
## CS:GO reel built by the backend (reel, winner_index, near_miss): it brakes unevenly, catches
## on each peg, hangs on the near miss, lands, and the reveal plays in the rarity's light.
## Legendary and mythic get a short cutscene. Closes with the API result, or null if backed
## out or refused ("Not this week." with the lamp off). Nothing here decides money.

enum Phase { CHOOSE, HOLD, PAYING, REEL, REVEAL, DONE }

const HOLD_SECONDS := 0.45
const MIN_GAP_MS := 2500  # case starts are never closer than this

# The reel window and cards, in overlay space (480x270).
const WIN := Rect2(20, 94, 440, 64)
const LINE := 220.0  # the center line, in window space
const PITCH := 40.0
const CARD := Vector2(36, 50)
const START_CARD := 5

# Motion on an internal clock (seconds). Position depends only on the clock, so the reel
# lands to the pixel; catches and the near miss only stretch time.
const T_WIND := 0.12
const T_LAUNCH := 0.25
const T_CRUISE := 0.45
const T_BRAKE := 3.3
const T_CRAWL := 1.25
const V_CRAWL := 46.0
const WIND_BACK := 6.0
const STEP := 1.0 / 240.0
const CATCH_BELOW := 220.0  # px/s: slower than this, the reel catches on each peg
const SKIP_AFTER := 1.0
const SKIP_TO := 0.68  # a skip fast-forwards to this far through the brake
const TICK_GAP := 0.03

const REVEAL := {
	"common": {"stop": 0.05, "flash": 0.0, "fade": 0.0, "shake": 1.0, "shake_s": 0.12, "sparks": 6},
	"rare": {"stop": 0.083, "flash": 0.35, "fade": 0.18, "shake": 1.0, "shake_s": 0.15, "sparks": 16},
	"epic": {"stop": 0.117, "flash": 0.5, "fade": 0.25, "shake": 2.0, "shake_s": 0.25, "sparks": 32},
	"legendary": {"stop": 0.2, "flash": 0.7, "fade": 0.4, "shake": 4.0, "shake_s": 0.4, "sparks": 64},
	"mythic": {"stop": 0.2, "flash": 0.9, "fade": 0.6, "shake": 6.0, "shake_s": 0.5, "sparks": 120},
}

# Pack sprites (AtlasTexture regions) and sounds (Sfx.play_path or our own players).
const KYRISE := "res://art/packs/kyrise-rpg-icons-16/spritesheet/spritesheet_16x16.png"
const CHESTS := "res://art/packs/whimsy-hallow-chests/15_Ready_to_use_Treasure_Chests_Spritesheet.png"
const CHEST_ROW := {"case_10": 5, "case_20": 9, "case_50": 8}
const CULTISTS := ["res://art/packs/dawnlike/Characters/Humanoid0.png", "res://art/packs/dawnlike/Characters/Humanoid1.png"]
const CANDLES := "res://art/packs/vk-candles-with-eyes/candles_with_eyes.png"
const MOUTH_ICON := {"sav_1": Rect2(192, 240, 16, 16), "brk_1": Rect2(96, 160, 16, 16)}
const BOOK_ICON := Rect2(128, 16, 16, 16)
const MOUTH_X := {"sav_1": 132.0, "brk_1": 348.0}
const MOUTH_NAME := {"sav_1": "House Fund", "brk_1": "Brokerage"}

const A := "res://art/packs/"
const SND_TICK := A + "kenney-interface-sounds/Audio/tick_001.ogg"
const SND_PEG := A + "kenney-interface-sounds/Audio/tick_002.ogg"
const SND_SELECT := A + "kenney-interface-sounds/Audio/select_002.ogg"
const SND_HEART := A + "bart-heartbeat-sounds/heartbeat_slow_0.ogg"
const SND_SLIDE := A + "kenney-casino-audio/Audio/card-slide-1.ogg"
const SND_STAMP := A + "kenney-impact-sounds/Audio/impactPunch_heavy_000.ogg"
const SND_TUBE := A + "ninja-adventure/Audio/Sounds/Whoosh & Slash/Whoosh.ogg"
const SND_BANG := A + "ignisforge-sfx-sampler/explosion_05.ogg"
const SND_BANG_BODY := A + "kenney-impact-sounds/Audio/impactMetal_heavy_000.ogg"
const SND_CRACK := A + "kenney-casino-audio/Audio/cards-pack-open-1.ogg"
const SND_HUM := A + "owlishmedia-creepy-chanting/ethereal_chant_Subclip_01_01.ogg"
const SND_GLINT := A + "kenney-interface-sounds/Audio/glass_001.ogg"
const SND_OOH := A + "ninja-adventure/Audio/Sounds/Voice/Voice3.ogg"
const SND_SLIP := A + "wobbleboxx-levelup-coin/Downer01.ogg"
const SND_SIGH := A + "ninja-adventure/Audio/Sounds/Voice/Voice7.ogg"
const SND_CLAP := A + "kenney-casino-audio/Audio/chips-collide-3.ogg"
const SND_BOOK := A + "kenney-rpg-audio/Audio/bookFlip1.ogg"
const SND_LAMP := A + "kenney-interface-sounds/Audio/switch_002.ogg"
const SND_LAY := A + "kenney-impact-sounds/Audio/impactWood_heavy_001.ogg"
const SND_CHOIR := A + "mumusi-cathedral-of-shadows/Cathedral_of_Shadows_loop.ogg"
const SND_JACKPOT := A + "ignisforge-sfx-sampler/jackpot_01.ogg"
const SND_DREAD := A + "ignisforge-sfx-sampler/stinger_01.ogg"
const SND_BOOM := A + "kenney-impact-sounds/Audio/impactPlate_heavy_000.ogg"
const STINGER := {
	"common": A + "kenney-music-jingles/Audio/Pizzicato jingles/jingles_PIZZI00.ogg",
	"rare": A + "kenney-music-jingles/Audio/Steel jingles/jingles_STEEL00.ogg",
	"epic": A + "kenney-music-jingles/Audio/Sax jingles/jingles_SAX00.ogg",
	"legendary": A + "kenney-music-jingles/Audio/Hit jingles/jingles_HIT00.ogg",
	"mythic": A + "kenney-music-jingles/Audio/Hit jingles/jingles_HIT00.ogg",
}

# Cabinet colors (drawn parts only; pack sprites keep their own colors).
const BODY := Color("24162a")
const BODY_DARK := Color("160e1b")
const TRIM := Color("6e5146")
const TRIM_LIT := Color("b58d6c")
const GLASS := Color("08050c")
const CARD_BODY := Color("1b1222")
const EYES := Color("d8ff8a")

static var _catalog: Dictionary = {}  # item_id -> item, from GET /casino/catalog (static)
static var _last_dest := "sav_1"
static var _last_start_ms := -100000

## Where the moment is, for the tour and anyone listening: choose, hold, paying, money,
## bang, reel, near_miss, land, reveal, cutscene, book, refused, closed.
var moment := "choose"
## Every line Vex has said in this overlay, in order (the tour reads it).
var said: PackedStringArray = []
var case_id := ""
var dest := "sav_1"
var result: Dictionary = {}

var _phase := Phase.CHOOSE
var _price := 0
var _hold := 0.0
var _tapped := false
var _t := 0.0

# Nodes
var _root := Control.new()   # everything on the machine; shakes and pushes in
var _back := Control.new()
var _cabinet: Cabinet
var _clip := Control.new()
var _reel: ReelView
var _glass_top: GlassTop
var _chest := TextureRect.new()
var _price_label: Label
var _mouths: Dictionary = {}  # dest -> Mouth
var _bill: Bill
var _ring: HoldRing
var _book := TextureRect.new()
var _lamp: Lamp
var _cone: Cone
var _fx := Control.new()
var _bubble := SpeechBubble.new()
var _vex: CasinoRoomVex.Bust
var _cultists: Array[TextureRect] = []
var _flames: Array[TextureRect] = []
var _speech := 0
var _dark := ColorRect.new()  # the room going dark for cutscenes
var _vignette := TextureRect.new()  # closes in during the crawl
var _cine := Control.new()  # beams, rays and the spinning item live here

# Sound
var _ticks: Array[AudioStreamPlayer] = []
var _tick_i := 0
var _last_tick := -1.0
var _hum := AudioStreamPlayer.new()
var _choir := AudioStreamPlayer.new()

# Reel motion
var _table := PackedFloat32Array()
var _s := 0.0
var _end_s := 0.0
var _pos0 := 0.0
var _end_pos := 0.0
var _final_pos := 0.0
var _vmax := 0.0
var _settle := 0.0
var _settling := false
var _hang := 0.0
var _hang_rate := 1.0
var _ff := false
var _reel_time := 0.0
var _win := 38
var _near := ""
var _near_index := -1
var _near_boundary := -1
## Real seconds from the reel's start to its stop, and reel time a tap fast-forwarded past
## (the tour reads both).
var reel_seconds := 0.0
var skipped_seconds := 0.0


func _init(id: String = "") -> void:
	super._init()
	case_id = id


func _ready() -> void:
	var casino: Dictionary = Game.state.get("casino", {})
	for c: Dictionary in casino.get("cases", []):
		if str(c.get("id", "")) == case_id:
			_price = int(c.get("price_cents", 0))
	dest = _last_dest
	_build()
	_select(dest, false)
	_root.pivot_offset = Vector2(240, 135)
	_root.scale = Vector2(0.9, 0.9)
	_root.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_root, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_property(_root, "modulate:a", 1.0, 0.2)
	Sfx.play_path(SND_LAMP, 1.2, -10.0)
	_load_catalog()


func _exit_tree() -> void:
	_hum.stop()
	_choir.stop()


# --- building the machine ----------------------------------------------------------

func _build() -> void:
	CasinoFx.room_dim(self, Vector2(240, 150))
	var top := TextureRect.new()
	top.texture = _top_shade()
	top.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	top.size = Vector2(480, 64)
	top.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_root.size = Vector2(480, 270)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_back)
	_build_crowd()
	_vex = CasinoRoomVex.Bust.new()
	_vex.position = Vector2(22, 8)
	_vex.ledge = 58.0  # his hands hook over the cabinet's top edge
	_back.add_child(_vex)

	_cabinet = Cabinet.new()
	_root.add_child(_cabinet)
	# His hands come out in front of the cabinet.
	_vex.hands.z_index = 0
	_vex.hands.reparent(_root)
	# Eyes on stands either side of the crown, candles at the corners.
	for spot: Array in [[Vector2(144, 24), 7], [Vector2(318, 24), 7], [Vector2(14, 24), 0], [Vector2(448, 24), 0]]:
		var stand := TextureRect.new()
		stand.texture = CasinoFx.region(CANDLES, Rect2(int(spot[1]) * 18, 0, 18, 43))
		stand.size = Vector2(18, 43)
		stand.position = spot[0]
		stand.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var flame := CasinoFx.glow(_root, spot[0] + Vector2(9, 8 if int(spot[1]) == 0 else 16), Color(Palette.CREAM, 0.35), 14.0)
		_flames.append(flame)
		_root.add_child(stand)

	_clip.position = WIN.position
	_clip.size = WIN.size
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_clip)
	_reel = ReelView.new()
	_reel.size = WIN.size
	_reel.visible = false
	_clip.add_child(_reel)
	_glass_top = GlassTop.new()
	_glass_top.position = WIN.position
	_glass_top.size = WIN.size
	_root.add_child(_glass_top)

	var row: int = CHEST_ROW.get(case_id, 9)
	_chest.texture = CasinoFx.region(CHESTS, Rect2(0, row * 40, 48, 40))
	_chest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_chest.size = Vector2(96, 80)
	_chest.position = Vector2(240 - 48, WIN.get_center().y - 46)
	_chest.pivot_offset = Vector2(48, 80)
	_chest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chest_glow := CasinoFx.glow(_root, WIN.get_center() + Vector2(0, 4), Color(Palette.CREAM, 0.18), 46.0)
	chest_glow.name = "ChestGlow"
	_root.add_child(_chest)

	_price_label = CasinoFx.label(CasinoFx.dollars(_price) if _price > 0 else "", Palette.CREAM, 20)
	_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_price_label.size = Vector2(80, 22)
	_price_label.position = Vector2(200, 61)
	_root.add_child(_price_label)

	for id: String in ["sav_1", "brk_1"]:
		var m := Mouth.new()
		m.dest = id
		m.position = Vector2(MOUTH_X[id] - 74, 176)
		m.size = Vector2(148, 60)
		_root.add_child(m)
		m.setup(_account_name(id), _balance(id), CasinoFx.region(KYRISE, MOUTH_ICON[id]))
		_mouths[id] = m

	_bill = Bill.new()
	_bill.text = CasinoFx.dollars(_price)
	_root.add_child(_bill)
	_ring = HoldRing.new()
	_root.add_child(_ring)

	_book.texture = CasinoFx.region(KYRISE, BOOK_ICON)
	_book.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_book.size = Vector2(32, 32)
	_book.position = Vector2(436, 234)
	_book.pivot_offset = Vector2(16, 32)
	_book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_book)

	_cone = Cone.new()
	_root.add_child(_cone)
	_lamp = Lamp.new()
	_root.add_child(_lamp)

	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.size = Vector2(480, 270)
	_root.add_child(_fx)
	_bubble.position = Vector2(166, 30)
	_bubble.tail_x = -96.0  # the tail drops toward his hood
	_root.add_child(_bubble)

	_vignette.texture = _vignette_tex()
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.size = Vector2(480, 270)
	_vignette.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_vignette.modulate.a = 0.0
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)

	_dark.color = Color(0, 0, 0, 0)
	_dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dark.z_index = 40
	add_child(_dark)
	_cine.size = Vector2(480, 270)
	_cine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cine.z_index = 41
	add_child(_cine)

	for i in 4:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_ticks.append(p)
	_hum.stream = _looped(SND_HUM)
	add_child(_hum)
	_choir.stream = _looped(SND_CHOIR)
	add_child(_choir)


func _build_crowd() -> void:
	# The flock at the back: hooded shapes on the risers, nothing lit but their eyes.
	var spots: Array[Vector2] = []
	for x: int in [150, 178, 206, 274, 302, 330, 358, 386, 414, 442]:
		spots.append(Vector2(x, 34))
	for x: int in [164, 192, 288, 316, 344, 372, 400, 428, 456]:
		spots.append(Vector2(x, 47))
	var cells := [Rect2(0, 272, 16, 16), Rect2(16, 272, 16, 16), Rect2(32, 272, 16, 16)]
	for i in spots.size():
		var cell: Rect2 = cells[i % cells.size()]
		_cultists.append(CasinoFx.cultist(_back, spots[i], CULTISTS[0], cell, spots[i].y > 40, i % 3 == 1))


static func _vignette_tex() -> Texture2D:
	var key := "_case_vignette"
	if not CasinoFx._cache.has(key):
		var tex := GradientTexture2D.new()
		tex.gradient = CasinoFx.grad([0.0, 0.55, 1.0], [Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 1)])
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.47)
		tex.fill_to = Vector2(1.05, 0.47)
		tex.width = 240
		tex.height = 135
		CasinoFx._cache[key] = tex
	return CasinoFx._cache[key]


static func _top_shade() -> Texture2D:
	var key := "_case_top"
	if not CasinoFx._cache.has(key):
		var tex := GradientTexture2D.new()
		tex.gradient = CasinoFx.grad([0.0, 0.6, 1.0], [Color(Palette.NIGHT, 1.0), Color(Palette.NIGHT, 0.97), Color(Palette.NIGHT, 0.0)])
		tex.fill_from = Vector2(0, 0)
		tex.fill_to = Vector2(0, 1)
		tex.width = 4
		tex.height = 64
		CasinoFx._cache[key] = tex
	return CasinoFx._cache[key]


static func _looped(path: String) -> AudioStream:
	var s: Resource = CasinoFx.res(path)
	if s == null:
		return null
	var copy: Resource = s.duplicate()
	if copy is AudioStreamOggVorbis:
		(copy as AudioStreamOggVorbis).loop = true
	return copy as AudioStream


func _load_catalog() -> void:
	if not _catalog.is_empty():
		return
	var res: Array = await Game.api.request("GET", "/casino/catalog")
	if res[1] != "":
		return
	for item: Dictionary in res[0].get("items", []):
		_catalog[str(item.id)] = item


func _account_name(id: String) -> String:
	for d: Dictionary in Game.state.get("casino", {}).get("destinations", []):
		if str(d.get("id", "")) == id:
			return str(d.get("name", MOUTH_NAME.get(id, id)))
	return MOUTH_NAME.get(id, id)


func _balance(id: String) -> int:
	for d: Dictionary in Game.state.get("casino", {}).get("destinations", []):
		if str(d.get("id", "")) == id:
			return int(d.get("balance_cents", 0))
	return 0


func _dealer_line() -> String:
	var dealer: Dictionary = Game.state.get("casino", {}).get("dealer", {})
	var before: Dictionary = dealer.get("before", {}).get("case", {}).get(case_id, {})
	return str(before.get(dest, dealer.get("line", "")))


## The slot mouth for a destination ("sav_1" or "brk_1"), for taps in the tour.
func mouth_control(id: String) -> Control:
	return _mouths.get(id)


# --- input ---------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_press(mb.position)
		else:
			_release()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _phase == Phase.CHOOSE:
		_back_out()


func _press(at: Vector2) -> void:
	match _phase:
		Phase.CHOOSE:
			for id: String in _mouths:
				var m: Mouth = _mouths[id]
				if m.get_rect().has_point(at):
					if id != dest:
						_select(id, true)
					_phase = Phase.HOLD
					moment = "hold"
					_hold = 0.0
					CasinoFx.loud(self, SND_HEART, 1.0, -6.0)
					return
			if not _cabinet.get_rect().has_point(at) or at.y < 52:
				_back_out()
		Phase.REEL:
			if _reel_time >= SKIP_AFTER and _s < _skip_s():
				_ff = true
		_:
			_tapped = true


func _release() -> void:
	if _phase == Phase.HOLD and _hold < HOLD_SECONDS:
		_phase = Phase.CHOOSE
		moment = "choose"


func _back_out() -> void:
	_phase = Phase.DONE
	moment = "closed"
	Sfx.play_path(SND_LAMP, 0.9, -12.0)
	close(null)


func _select(id: String, speak: bool) -> void:
	dest = id
	for k: String in _mouths:
		(_mouths[k] as Mouth).selected = k == id
	var m: Mouth = _mouths[id]
	_bill.home = m.position + Vector2(84, 33)
	if speak:
		Sfx.play_path(SND_SELECT, 1.0, -8.0)
		var tw := _bill.create_tween()
		tw.tween_property(_bill, "position", _bill.home, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_bill.position = _bill.home
	_speak(_dealer_line())


## Vex says the line in two breaths: the money, then the counts.
func _speak(line: String) -> void:
	_speech += 1
	var mine := _speech
	var cut := line.find(". ")
	var parts := [line] if cut < 0 else [line.substr(0, cut + 1), line.substr(cut + 2)]
	for i in parts.size():
		if mine != _speech:
			return
		_vex.speak()
		said.append(str(parts[i]))
		await _bubble.say(str(parts[i]), 0.35 if i < parts.size() - 1 else 4.0)


func _hush() -> void:
	_speech += 1
	_bubble.hide_now()


# --- per frame ---------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	_animate_room(delta)
	match _phase:
		Phase.HOLD:
			_hold += delta
			_ring.progress = clampf(_hold / HOLD_SECONDS, 0.0, 1.0)
			_root.scale = Vector2.ONE * lerpf(1.0, 1.045, _ring.progress)
			_bill.shiver = _ring.progress
			_chest_frame(2 + int(_t * 18.0) % 8)
			if _hold >= HOLD_SECONDS:
				_feed()
		Phase.CHOOSE:
			_ring.progress = maxf(0.0, _ring.progress - delta / 0.15)
			if _root.scale.x > 1.0 and _t > 0.4:
				_root.scale = Vector2.ONE * maxf(1.0, _root.scale.x - delta * 0.3)
			_bill.shiver = 0.0
			_chest_frame(0)
		Phase.REEL:
			_advance(delta)
		Phase.PAYING:
			if moment == "money":
				_chest_frame(2 + int(_t * 14.0) % 8)
	_ring.position = _bill.position + Vector2(12, 5)
	_vex.look = _bill.position + Vector2(12, 5) if _phase in [Phase.CHOOSE, Phase.HOLD, Phase.PAYING] else Vector2(240, 126)


func _animate_room(delta: float) -> void:
	var beat := int(_t * (2.4 if _phase == Phase.REEL else 1.4))
	for i in _cultists.size():
		var c := _cultists[i]
		var cell: Rect2 = c.get_meta("cell")
		c.texture = CasinoFx.region(CULTISTS[(beat + i) % 2], cell)
		var home: Vector2 = c.get_meta("home")
		var lean := 0.0
		if _phase == Phase.REEL and _reel.speed < 150.0:
			lean = 2.0
		var wide := moment == "near_miss"
		if wide:
			lean = 2.0 + sin(_t * 30.0 + i)
		c.position.y = lerpf(c.position.y, home.y + lean, minf(1.0, delta * 12.0))
		c.position.x = lerpf(c.position.x, home.x + signf(240.0 - home.x) * minf(lean, 1.0), minf(1.0, delta * 8.0))
		for eye: Node in c.get_children():
			if eye is ColorRect:
				(eye as ColorRect).size = Vector2(1, 2) if wide else Vector2(1, 1)
	_cabinet.chase += delta * (2.0 + (_reel.speed / 40.0 if _phase == Phase.REEL else 0.0))
	for i in _flames.size():
		_flames[i].modulate.a = 0.28 + 0.1 * sin(_t * 9.0 + i * 1.7) + 0.05 * sin(_t * 23.0 + i)
	CasinoFx.blink(_cultists, delta)


func _chest_frame(frame: int) -> void:
	var row: int = CHEST_ROW.get(case_id, 9)
	_chest.texture = CasinoFx.region(CHESTS, Rect2(frame * 48, row * 40, 48, 40))


# --- paying ------------------------------------------------------------------------

func _feed() -> void:
	_phase = Phase.PAYING
	moment = "paying"
	_hush()
	_ring.progress = 1.0
	_root.create_tween().tween_property(_root, "scale", Vector2.ONE, 0.2)
	_last_dest = dest
	var wait_ms := MIN_GAP_MS - (Time.get_ticks_msec() - _last_start_ms)
	if wait_ms > 0:
		await get_tree().create_timer(wait_ms / 1000.0).timeout
	_last_start_ms = Time.get_ticks_msec()
	# The bill noses into the slot while the house answers.
	var nose := _bill.create_tween()
	nose.tween_property(_bill, "position", _bill.home + Vector2(0, 4), 0.12)
	var res: Array = await Game.api.request("POST", "/casino/case", {}, {"case_id": case_id, "to_account": dest})
	if res[1] != "":
		await _refuse(res[1])
		return
	result = res[0]
	Game.refresh()
	await _money(result)
	play(result)


func _money(data: Dictionary) -> void:
	moment = "money"
	var money: Dictionary = data.get("money", {})
	var m: Mouth = _mouths.get(str(money.get("to_account", dest)), _mouths[dest])
	# Stamp, then into the slot, then up the tube.
	_bill.stamped = true
	Sfx.play_path(SND_STAMP, 1.0, -6.0)
	CasinoFx.shake(_root, 2.0, 0.12)
	await get_tree().create_timer(0.16).timeout
	Sfx.play_path(SND_SLIDE, 1.0, -4.0)
	var slot := m.position + Vector2(96, 49)
	var tw := _bill.create_tween().set_parallel(true)
	tw.tween_property(_bill, "position", slot - Vector2(12, 6), 0.2).set_ease(Tween.EASE_IN)
	tw.tween_property(_bill, "squash", 1.0, 0.2).set_ease(Tween.EASE_IN)
	await tw.finished
	_ring.progress = 0.0
	Sfx.play_path(SND_TUBE, 1.3, -10.0)
	for e: Dictionary in data.get("_events", []):
		if str(e.get("kind", "")) == "money_moved":
			Game.event_fired.emit(e)
	var jar := m.position + Vector2(22, 22)
	# Honest about the demo: a "simulated" chip rides beside the amount when no real dollars moved.
	var tag := "simulated" if str(money.get("status", "")) == "simulated" else ""
	var amount := int(money.get("amount_cents", _price))
	await CasinoFx.money_landed(_fx, slot, jar, amount, m.account, tag, m.position + Vector2(m.size.x / 2.0, -8))
	m.pulse()
	CasinoFx.stamp(_fx, m.position + Vector2(m.size.x - 18, 8), CasinoFx.dollars(amount), m)
	await CasinoFx.hit_stop(get_tree(), 0.08)
	_count_up(m)


## Count the painted balance up to what /state now says (formatting only, no money math).
func _count_up(m: Mouth) -> void:
	var from := m.balance
	var waited := 0.0
	while _balance(m.dest) == from and waited < 1.5:
		await get_tree().process_frame
		waited += get_process_delta_time()
	var to := _balance(m.dest)
	if to == from or not is_instance_valid(m):
		return
	await CasinoFx.count_up(m, m._bal, from, to, m.show_balance)
	m.pulse()


func _refuse(message: String) -> void:
	_phase = Phase.DONE
	moment = "refused"
	_lamp.flicker_off()
	Sfx.play_path(SND_LAMP, 0.8, -4.0)
	_cone.visible = false
	_bill.refused = true
	_ring.visible = false
	var out := _bill.create_tween()
	out.tween_property(_bill, "position", _bill.home, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var dim := _root.create_tween()
	dim.tween_property(_root, "modulate", Color(0.55, 0.55, 0.6), 0.3)
	await get_tree().create_timer(0.35).timeout
	Sfx.play_path(SND_LAY, 0.8, -6.0)
	_speech += 1
	_vex.speak()
	said.append(message)
	await _bubble.say(message, 1.4)
	moment = "closed"
	close(null)


# --- the pull ------------------------------------------------------------------------

## Play a pull's result from the bang through the reveal, then close with it. _feed calls
## this once the money has landed; it never moves money itself.
func play(data: Dictionary) -> void:
	result = data
	_phase = Phase.PAYING
	_hush()
	await _bang()
	_start_reel(data)


func _bang() -> void:
	moment = "bang"
	# The breath: everything stops and the room dims.
	_hum.stop()
	CasinoFx.hush(get_tree())
	_root.modulate = Color(0.7, 0.7, 0.72)
	await get_tree().create_timer(0.15).timeout
	_root.modulate = Color.WHITE
	Sfx.play_path(SND_BANG, 0.9, -2.0)
	Sfx.play_path(SND_BANG_BODY, 0.7, -4.0)
	CasinoFx.flash(self, Palette.CREAM, 0.8, 0.12)
	CasinoFx.shake(_root, 3.0, 0.22)
	CasinoFx.smoke(_fx, WIN.get_center() + Vector2(0, 10), 9)
	_chest_frame(11)
	await CasinoFx.hit_stop(get_tree(), 0.09)
	Sfx.play_path(SND_CRACK, 1.0, -4.0)
	var light := CasinoFx.glow(_fx, WIN.get_center(), Color(Palette.CREAM, 0.9), 60.0)
	var lt := light.create_tween()
	lt.tween_property(light, "modulate:a", 0.0, 0.5)
	lt.tween_callback(light.queue_free)
	for f: int in [12, 13, 14, 15, 16]:
		_chest_frame(f)
		await get_tree().create_timer(0.035).timeout
	var tw := _chest.create_tween().set_parallel(true)
	tw.tween_property(_chest, "position:y", _chest.position.y - 40, 0.3).set_ease(Tween.EASE_IN)
	tw.tween_property(_chest, "modulate:a", 0.0, 0.3)
	var glow := _root.get_node_or_null("ChestGlow")
	if glow:
		tw.tween_property(glow, "modulate:a", 0.0, 0.3)


func _start_reel(data: Dictionary) -> void:
	var cards: Array = []
	for c: Dictionary in data.get("reel", []):
		var item: Dictionary = _catalog.get(str(c.get("item_id", "")), {})
		cards.append({"tier": str(c.get("tier", "common")), "tex": CasinoFx.icon(item)})
	_win = int(data.get("winner_index", cards.size() - 7))
	var winner: Dictionary = data.get("item", {})
	if _win < cards.size() and not winner.is_empty():
		cards[_win] = {"tier": str(winner.get("tier", "common")), "tex": CasinoFx.icon(winner)}
	_near = str(data.get("near_miss", "")) if data.get("near_miss") != null else ""
	_near_index = int(data.get("near_miss_index", -1)) if data.get("near_miss_index") != null else -1
	match _near:
		"fell":
			_near_boundary = _win
		"tease":
			_near_boundary = _near_index + 1
		_:
			_near_boundary = -1
	_reel.cards = cards
	_build_motion()
	_reel.pos = _pos0
	_reel.visible = true
	_reel.modulate.a = 0.0
	_reel.create_tween().tween_property(_reel, "modulate:a", 1.0, 0.12)
	_s = 0.0
	_reel_time = 0.0
	_settle = 0.0
	_settling = false
	_ff = false
	_hum.volume_db = -26.0
	_hum.pitch_scale = 1.0
	_hum.play()
	_phase = Phase.REEL
	moment = "reel"


## Precompute position against the internal clock: windup, launch, cruise (with a small
## wobble), brake, crawl. Then scale so the strip lands exactly where it should.
func _build_motion() -> void:
	_pos0 = (START_CARD + 0.5) * PITCH
	match _near:
		"short":
			# Crawls to the edge of the gold card, sits there, then rocks back onto the winner.
			_end_pos = (_win + 1) * PITCH - 0.5
			_final_pos = (_win + 1) * PITCH - randf_range(7.0, 11.0)
		"fell":
			# Hangs half on the gold card, then slips onto the winner.
			_final_pos = _win * PITCH + randf_range(5.0, 9.0)
			_end_pos = _final_pos
		_:
			_final_pos = _win * PITCH + PITCH / 2.0 + randf_range(-12.0, 12.0)
			_end_pos = _final_pos + 2.0
	var start := _pos0 - WIND_BACK
	var dist := _end_pos - start
	var a := _integrate(1.0, 0.0)
	var b := _integrate(0.0, 1.0)
	_vmax = maxf(200.0, (dist - V_CRAWL * b) / a)
	var total := T_WIND + T_LAUNCH + T_CRUISE + T_BRAKE + T_CRAWL
	var n := int(ceil(total / STEP)) + 1
	_table.resize(n)
	var p := start
	for i in n:
		var s := i * STEP
		if s <= T_WIND:
			_table[i] = _pos0 - WIND_BACK * sin(PI / 2.0 * s / T_WIND)
		else:
			p += _v_shape(s - T_WIND - STEP / 2.0, _vmax, V_CRAWL) * STEP
			_table[i] = p
	var got := _table[n - 1] - start
	var k := dist / got if got > 0.0 else 1.0
	for i in n:
		if i * STEP > T_WIND:
			_table[i] = start + (_table[i] - start) * k
	_vmax *= k
	_end_s = (n - 1) * STEP


func _integrate(vmax: float, vc: float) -> float:
	var total := T_LAUNCH + T_CRUISE + T_BRAKE + T_CRAWL
	var sum := 0.0
	var t := STEP / 2.0
	while t < total:
		sum += _v_shape(t, vmax, vc) * STEP
		t += STEP
	return sum


static func _v_shape(t: float, vmax: float, vc: float) -> float:
	if t < 0.0:
		return 0.0
	if t < T_LAUNCH:
		var f := t / T_LAUNCH
		return vmax * f * f
	t -= T_LAUNCH
	if t < T_CRUISE:
		return vmax * (1.0 + 0.03 * sin(TAU * 7.0 * t))
	t -= T_CRUISE
	if t < T_BRAKE:
		var u := t / T_BRAKE
		var k := pow(1.0 - u, 2.5)
		return vmax * k + vc * (1.0 - k)
	t -= T_BRAKE
	if t < T_CRAWL:
		return vc * (1.0 - t / T_CRAWL)
	return 0.0


func _pos_at(s: float) -> float:
	var f := clampf(s / STEP, 0.0, _table.size() - 1.0)
	var i := int(f)
	if i >= _table.size() - 1:
		return _table[_table.size() - 1]
	return lerpf(_table[i], _table[i + 1], f - i)


func _skip_s() -> float:
	return T_WIND + T_LAUNCH + T_CRUISE + T_BRAKE * SKIP_TO


func _advance(delta: float) -> void:
	_reel_time += delta
	var rate := 1.0
	if _hang > 0.0:
		_hang -= delta
		rate = _hang_rate
		if _hang <= 0.0:
			_glass_top.kink = 0.0
			if moment == "near_miss":
				moment = "reel"
				_reel.glint = -1
				if _near == "fell":
					Sfx.play_path(SND_SLIP, 1.0, -8.0)
	elif _ff:
		rate = 7.0
		skipped_seconds += delta * (rate - 1.0)
	var before := _pos_at(_s)
	_s = minf(_s + delta * rate, _end_s)
	if _ff and _s >= _skip_s():
		_ff = false
	var now := _pos_at(_s)
	var v := (_pos_at(minf(_s + STEP, _end_s)) - now) / STEP
	_reel.pos = now + _settle
	_reel.speed = v
	var slow := clampf(1.0 - v / _vmax, 0.0, 1.0)
	var crawl := smoothstep(0.82, 0.97, slow)
	_root.pivot_offset = WIN.get_center()
	_root.scale = Vector2.ONE * (1.0 + 0.06 * crawl)
	_vignette.modulate.a = 0.55 * crawl
	_hum.volume_db = lerpf(-26.0, -9.0, slow)
	_hum.pitch_scale = lerpf(1.0, 1.12, clampf((slow - 0.8) / 0.2, 0.0, 1.0))
	if now > before:
		var b0 := int(floor(before / PITCH))
		var b1 := int(floor(now / PITCH))
		for b in range(b0 + 1, b1 + 1):
			_on_boundary(b, v)
	if _s >= _end_s and not _settling:
		_settling = true
		_settle_and_land()


func _on_boundary(b: int, v: float) -> void:
	var slow := clampf(1.0 - v / _vmax, 0.0, 1.0)
	if b == _near_boundary and moment != "near_miss":
		_near_hang(b - 1, 0.45 if _near == "fell" else 0.3)
		_tick(SND_PEG, 0.85, -2.0)
		return
	if v < CATCH_BELOW and _hang <= 0.0:
		# Tick, hang, tick: the strip catches on the peg for a moment.
		_hang = lerpf(0.05, 0.12, clampf(1.0 - v / CATCH_BELOW, 0.0, 1.0))
		_hang_rate = 0.1
		_glass_top.kink = 1.0
		_tick(SND_PEG, 0.8 + slow * 0.5, lerpf(-12.0, -2.0, slow))
	else:
		_tick(SND_TICK, lerpf(0.9, 1.45, slow) + randf_range(-0.03, 0.03), lerpf(-14.0, -4.0, slow))


func _near_hang(card: int, seconds: float) -> void:
	moment = "near_miss"
	_hang = seconds
	_hang_rate = 0.03
	_glass_top.kink = 1.0
	_reel.glint = card
	_reel.glint_t = 0.0
	Sfx.play_path(SND_GLINT, 1.0, -6.0)
	Sfx.play_path(SND_OOH, 0.55, -8.0)
	_vex.speak()


func _tick(path: String, pitch: float, db: float) -> void:
	if _t - _last_tick < TICK_GAP:
		return  # extras are dropped, never queued
	_last_tick = _t
	var stream: AudioStream = CasinoFx.res(path) as AudioStream
	if stream == null:
		return
	var p := _ticks[_tick_i % _ticks.size()]
	_tick_i += 1
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = db
	p.play()


func _settle_and_land() -> void:
	if _near == "short":
		_near_hang(_win + 1, 0.0)
		await get_tree().create_timer(0.45).timeout
		Sfx.play_path(SND_SLIP, 1.0, -8.0)
		var tw := create_tween()
		tw.tween_method(func(v: float) -> void:
			_settle = v
			_reel.pos = _end_pos + v, 0.0, _final_pos - _end_pos, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tw.finished
		_reel.glint = -1
		_glass_top.kink = 0.0
	elif absf(_final_pos - _end_pos) > 0.1:
		var tw := create_tween()
		tw.tween_method(func(v: float) -> void:
			_settle = v
			_reel.pos = _end_pos + v, 0.0, _final_pos - _end_pos, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tw.finished
	_reel.speed = 0.0
	reel_seconds = _reel_time
	_reveal()


# --- the reveal ----------------------------------------------------------------------

func _reveal() -> void:
	_phase = Phase.REVEAL
	moment = "land"
	_hum.stop()
	var item: Dictionary = result.get("item", {})
	var tier := str(item.get("tier", "common"))
	var cfg: Dictionary = REVEAL.get(tier, REVEAL.common)
	var color := CasinoFx.rarity_color(tier)
	var high := tier == "legendary" or tier == "mythic"
	var card_pos := WIN.position + Vector2(_win * PITCH + 2.0 - _reel.pos + LINE, (WIN.size.y - CARD.y) / 2.0)
	var center := card_pos + CARD / 2.0
	_reel.focus = _win
	_reel.create_tween().tween_property(_reel, "dim", 1.0, 0.3)
	var ease_out := create_tween().set_parallel(true)
	ease_out.tween_property(_root, "scale", Vector2.ONE, 0.25)
	ease_out.tween_property(_vignette, "modulate:a", 0.0, 0.25)

	if tier == "mythic":
		# The room goes black except the card's red glow.
		_dark.color = Color(0, 0, 0, 0.97)
		var g := CasinoFx.rarity_glow(_cine, center, tier, 34.0)
		Sfx.play_path(SND_BOOM, 0.5, 0.0)
		await get_tree().create_timer(0.5).timeout
		g.queue_free()
		_dark.color.a = 0.0
	if high:
		await CasinoFx.hit_stop(get_tree(), float(cfg.stop))
	moment = "reveal"
	Sfx.play_path(STINGER[tier], 1.0, -2.0)
	if tier == "legendary":
		Sfx.play_path(SND_JACKPOT, 1.0, -6.0)
	elif tier == "mythic":
		Sfx.play_path(SND_DREAD, 1.0, -2.0)
	if high:
		CasinoFx.flash(self, color, float(cfg.flash), float(cfg.fade))
		CasinoFx.shake(_root, float(cfg.shake), float(cfg.shake_s))
		CasinoFx.sparks(_fx, center, tier, int(cfg.sparks))
		CasinoFx.ring(_fx, center, color, 30.0 + int(cfg.sparks) * 0.4, 0.5)
	else:
		CasinoFx.burst(_fx, center, color, 6, 60.0, 0.5)
	_cabinet.flash_color = color
	_cabinet.flash_until = _t + 1.2
	_crowd_react(tier)

	var hero := HeroCard.new()
	hero.tier = tier
	hero.tex = CasinoFx.icon(item)
	hero.position = card_pos
	hero.size = CARD
	hero.pivot_offset = CARD / 2.0
	hero.z_index = 75
	add_child(hero)
	_reel.hidden_index = _win
	var halo := CasinoFx.rarity_glow(_fx, center, tier, 52.0 + 12.0 * Palette.RARITY.keys().find(tier))
	var lift := Vector2(240, 106) - CARD / 2.0
	var stage_fx: Control = null
	var sway: Tween = null
	var name_label: Label
	if high:
		var pop := hero.create_tween()
		pop.tween_property(hero, "scale", Vector2(1.3, 1.3), 0.07).set_ease(Tween.EASE_OUT)
		pop.tween_property(hero, "scale", Vector2(1.15, 1.15), 0.1)
		await pop.finished
		# The slow zoom.
		var zoom := hero.create_tween().set_parallel(true)
		zoom.tween_property(hero, "scale", Vector2(1.9, 1.9), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		zoom.tween_property(hero, "position", lift, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		halo.create_tween().tween_property(halo, "position", lift + CARD / 2.0 - halo.size / 2.0, 0.9)
		name_label = CasinoFx.label(str(item.get("name", "")), color, 20)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.size = Vector2(300, 24)
		name_label.position = Vector2(90, 156)
		name_label.z_index = 80
		name_label.modulate.a = 0.0
		await _cutscene(tier, item, hero, halo, name_label)
	else:
		# Out of the reel and up into the lamp, turning over on the way; it lands on its rung.
		var up := hero.create_tween().set_parallel(true)
		up.tween_property(hero, "position", lift, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		halo.create_tween().tween_property(halo, "position", lift + CARD / 2.0 - halo.size / 2.0, 0.3)
		CasinoFx.flip_in(hero, Vector2(1.9, 1.9), 0.3)
		await get_tree().create_timer(0.28).timeout
		stage_fx = await CasinoFx.reveal(_fx, Vector2(240, 106), tier, _root)
		sway = CasinoFx.wobble(hero)
		name_label = CasinoFx.type_name(self, str(item.get("name", "")), tier, Vector2(240, 168))
		await _beat(1.5 if tier == "common" else 1.9)
	name_label.create_tween().tween_property(name_label, "modulate:a", 0.0, 0.25)
	if sway:
		sway.kill()
		hero.rotation = 0.0
	CasinoFx.fade_stage(stage_fx)
	await _to_book(hero, halo, tier)
	for e: Dictionary in result.get("_events", []):
		if str(e.get("kind", "")) == "item":
			Game.event_fired.emit(e)
	_phase = Phase.DONE
	moment = "closed"
	close(result)


func _crowd_react(tier: String) -> void:
	if tier == "common":
		Sfx.play_path(SND_SIGH, 0.6, -10.0)
		var c := _cultists[randi() % _cultists.size()]
		var home: Vector2 = c.get_meta("home")
		var tw := c.create_tween()
		tw.tween_property(c, "position:y", home.y + 2, 0.3)
		tw.tween_property(c, "position:y", home.y, 0.6)
		return
	Sfx.play_path(SND_CLAP, 1.0, -8.0)
	var height := 3.0 if tier == "rare" else 6.0
	for i in _cultists.size():
		var c := _cultists[i]
		var home: Vector2 = c.get_meta("home")
		var tw := c.create_tween()
		tw.tween_interval(randf_range(0.0, 0.15))
		tw.tween_property(c, "position:y", home.y - height, 0.12).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "position:y", home.y, 0.18).set_ease(Tween.EASE_IN)
		if tier != "rare":
			tw.tween_property(c, "position:y", home.y - height * 0.6, 0.12).set_ease(Tween.EASE_OUT)
			tw.tween_property(c, "position:y", home.y, 0.18).set_ease(Tween.EASE_IN)


## The legendary and mythic cutscene, about 3 s: the room goes dark, a beam opens, the choir
## comes in, and the item spins down the beam into the light. Taps hurry it after 1 s.
func _cutscene(tier: String, item: Dictionary, hero: HeroCard, halo: TextureRect, name_label: Label) -> void:
	moment = "cutscene"
	Sfx.duck(-14.0, 2.6)  # the room's music and air fall away under the choir
	var color := CasinoFx.rarity_color(tier)
	var center := Vector2(240, 104)
	_tapped = false
	var dark := create_tween()
	dark.tween_property(_dark, "color", Color(0.02, 0.0, 0.03, 0.94), 0.3)
	var fade_hero := hero.create_tween().set_parallel(true)
	fade_hero.tween_property(hero, "modulate:a", 0.0, 0.25)
	fade_hero.tween_property(halo, "modulate:a", 0.0, 0.25)
	_choir.volume_db = -14.0
	_choir.play()
	_choir.create_tween().tween_property(_choir, "volume_db", -3.0, 0.8)
	var beam := CasinoFx.beam(_cine, center.x, 170.0, tier, 40.0, 0.0)
	var rays := Rays.new()
	rays.color = color
	rays.position = center
	rays.modulate.a = 0.0
	_cine.add_child(rays)
	rays.create_tween().tween_property(rays, "modulate:a", 0.55, 0.6)
	var specks := CasinoFx.flakes(_cine, Rect2(0, 0, 480, 270), tier, 3.2)
	var glow := CasinoFx.rarity_glow(_cine, center, tier, 52.0)
	glow.modulate.a = 0.0

	var big := TextureRect.new()
	big.texture = CasinoFx.icon(item)
	big.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	big.size = Vector2(64, 64)
	big.pivot_offset = Vector2(32, 32)
	big.position = Vector2(center.x - 32, -80)
	big.z_index = 72
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cine.add_child(big)
	# A rarity outline: the sprite's silhouette, nudged out on four sides behind it.
	for off: Vector2 in [Vector2(-3, 0), Vector2(3, 0), Vector2(0, -3), Vector2(0, 3)]:
		var o := TextureRect.new()
		o.texture = big.texture
		o.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		o.size = big.size
		o.position = off
		o.material = CasinoFx.silhouette(CasinoFx.glow_color(tier) if off.y < 0 else color)
		o.show_behind_parent = true
		o.mouse_filter = Control.MOUSE_FILTER_IGNORE
		big.add_child(o)
	await get_tree().create_timer(0.3).timeout
	var fall := big.create_tween().set_parallel(true)
	fall.tween_property(big, "position:y", center.y - 32, 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fall.tween_method(func(ph: float) -> void: big.scale.x = cos(ph), 0.0, 6.0 * PI, 1.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	glow.create_tween().tween_property(glow, "modulate:a", 0.9, 1.3)
	await _beat(1.3, 0.7)
	if fall.is_running():
		fall.kill()
		big.position.y = center.y - 32
		big.scale = Vector2.ONE
	# The landing.
	Sfx.play_path(SND_JACKPOT, 0.8 if tier == "mythic" else 1.0, -4.0)
	if tier == "mythic":
		Sfx.play_path(SND_BOOM, 0.45, 0.0)
	CasinoFx.flash(self, color, 0.6, 0.3)
	CasinoFx.ring(_cine, center, color, 70.0, 0.6)
	CasinoFx.ring(_cine, center, CasinoFx.glow_color(tier), 44.0, 0.4)
	CasinoFx.sparks(_cine, center, tier, 48)
	CasinoFx.shake(_cine, 3.0, 0.3)
	_crowd_react(tier)
	var slam := big.create_tween()
	slam.tween_property(big, "scale", Vector2(1.25, 0.8), 0.06)
	slam.tween_property(big, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	name_label.position = Vector2(90, 146)
	add_child(name_label)
	name_label.z_index = 80
	name_label.create_tween().tween_property(name_label, "modulate:a", 1.0, 0.3)
	if tier == "mythic":
		var flicker := _dark.create_tween().set_loops(4)
		flicker.tween_property(_dark, "color", Color(0.3, 0.0, 0.03, 0.9), 0.08)
		flicker.tween_property(_dark, "color", Color(0.02, 0.0, 0.03, 0.94), 0.12)
	await _beat(1.5, 0.0)
	# Out of the dark: the item becomes the card that goes to the book.
	var out := create_tween().set_parallel(true)
	out.tween_property(_dark, "color", Color(0, 0, 0, 0), 0.4)
	out.tween_property(beam, "width", 0.0, 0.4)
	out.tween_property(rays, "modulate:a", 0.0, 0.4)
	out.tween_property(glow, "modulate:a", 0.0, 0.4)
	out.tween_property(_choir, "volume_db", -40.0, 0.6)
	out.tween_property(big, "modulate:a", 0.0, 0.3)
	hero.position = center - CARD / 2.0
	hero.scale = Vector2(1.9, 1.9)
	out.tween_property(hero, "modulate:a", 1.0, 0.3)
	halo.position = center - halo.size / 2.0
	out.tween_property(halo, "modulate:a", 1.0, 0.3)
	await out.finished
	_choir.stop()
	for n: Node in [beam, rays, glow, big, specks]:
		if is_instance_valid(n):
			n.queue_free()


## The item arcs into the collection book on the counter; the book squashes.
func _to_book(hero: Control, halo: Control, tier: String) -> void:
	moment = "book"
	var from := hero.position
	var to := _book.position + Vector2(16, 14) - CARD / 2.0
	var peak := from.lerp(to, 0.5) + Vector2(0, -60)
	Sfx.play_path(SND_TUBE, 1.6, -12.0)
	var tw := hero.create_tween().set_parallel(true)
	tw.tween_method(func(t: float) -> void:
		hero.position = from.lerp(peak, t).lerp(peak.lerp(to, t), t), 0.0, 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(hero, "scale", Vector2(0.35, 0.35), 0.5).set_ease(Tween.EASE_IN)
	tw.tween_property(halo, "modulate:a", 0.0, 0.3)
	await tw.finished
	hero.queue_free()
	halo.queue_free()
	Sfx.play_path(SND_BOOK, 1.0, -4.0)
	CasinoFx.burst(_fx, _book.position + Vector2(16, 12), CasinoFx.rarity_color(tier), 14, 70.0, 0.5)
	var squash := _book.create_tween()
	squash.tween_property(_book, "scale", Vector2(1.25, 0.75), 0.06)
	squash.tween_property(_book, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.45).timeout


## Wait `seconds`, or less if the player taps once `tap_after` seconds have passed.
func _beat(seconds: float, tap_after := 0.0) -> void:
	_tapped = false
	var waited := 0.0
	while waited < seconds:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if _tapped and waited >= tap_after:
			return
		if waited < tap_after:
			_tapped = false


# --- drawn pieces ------------------------------------------------------------------

## One reel card: a dark card, the rarity rising from its floor, a 3 px rarity bar, and the
## item's pack icon (or, for gold and red, only an eye).
static func draw_card(ci: CanvasItem, r: Rect2, tier: String, tex: Texture2D, k: float, t: float, eye_only: bool) -> void:
	var col := CasinoFx.rarity_color(tier)
	var high := tier == "legendary" or tier == "mythic"
	var body := CARD_BODY.lerp(CasinoFx.shadow_color(tier), 0.35 if high else 0.0)
	ci.draw_rect(r, Color(body, k))
	ci.draw_texture_rect(_floor_glow(), Rect2(r.position.x, r.position.y + r.size.y * 0.3, r.size.x, r.size.y * 0.7), false, Color(col, (0.75 if high else 0.5) * k))
	ci.draw_rect(Rect2(r.position.x, r.end.y - 3, r.size.x, 3), Color(col, k))
	ci.draw_rect(r, Color(CasinoFx.shadow_color(tier), k), false, 1.0)
	var icon_rect := Rect2(r.position.x + (r.size.x - 32) / 2.0, r.position.y + 5, 32, 32)
	if high and eye_only:
		_draw_eye(ci, icon_rect.get_center(), tier, k, t)
	elif tex:
		ci.draw_texture_rect(tex, icon_rect, false, Color(1, 1, 1, k))


static func _draw_eye(ci: CanvasItem, c: Vector2, tier: String, k: float, t: float) -> void:
	var col := CasinoFx.rarity_color(tier)
	var pulse := 0.75 + 0.25 * sin(t * 6.0)
	ci.draw_texture_rect(CasinoFx.res(CasinoFx.LIGHT) as Texture2D, Rect2(c - Vector2(20, 20), Vector2(40, 40)), false, Color(col, 0.55 * k * pulse))
	var lid := PackedVector2Array()
	for j in 20:
		var a := TAU * j / 20.0
		lid.append(c + Vector2(cos(a) * 12.0, sin(a) * 7.0 * (0.45 + 0.55 * absf(sin(a)))))
	ci.draw_colored_polygon(lid, Color(CasinoFx.shadow_color(tier), k))
	ci.draw_circle(c, 5.0, Color(col, k))
	ci.draw_rect(Rect2(c.x - 1, c.y - 4, 2, 8), Color(Palette.NIGHT, k))
	ci.draw_rect(Rect2(c.x + 2, c.y - 3, 1, 1), Color(Palette.CREAM, k))
	lid.append(lid[0])
	ci.draw_polyline(lid, Color(CasinoFx.glow_color(tier), k), 1.0)


static func _floor_glow() -> Texture2D:
	var key := "_card_floor"
	if not CasinoFx._cache.has(key):
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0))
		g.set_color(1, Color(1, 1, 1, 1))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill_from = Vector2(0, 0)
		tex.fill_to = Vector2(0, 1)
		tex.width = 4
		tex.height = 32
		CasinoFx._cache[key] = tex
	return CasinoFx._cache[key]


class ReelView:
	extends Control
	var cards: Array = []
	var pos := 0.0
	var speed := 0.0
	var dim := 0.0
	var focus := -1
	var hidden_index := -1
	var glint := -1
	var glint_t := 0.0
	var t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		t += delta
		glint_t += delta
		queue_redraw()

	func _draw() -> void:
		if cards.is_empty():
			return
		var first := maxi(0, int(floor((pos - LINE) / PITCH)) - 1)
		var last := mini(cards.size() - 1, int(ceil((pos + size.x - LINE) / PITCH)) + 1)
		var ghost := speed > 380.0
		var y := (size.y - CARD.y) / 2.0
		for i in range(first, last + 1):
			if i == hidden_index:
				continue
			var x := i * PITCH + 2.0 - pos + LINE
			var k := 1.0
			if dim > 0.0 and i != focus:
				k = 1.0 - dim * 0.75
			var c: Dictionary = cards[i]
			var tex: Texture2D = c.get("tex")
			if ghost:
				CaseOverlay.draw_card(self, Rect2(x + speed * 0.02, y, CARD.x, CARD.y), c.tier, tex, 0.14 * k, t, true)
				CaseOverlay.draw_card(self, Rect2(x + speed * 0.01, y, CARD.x, CARD.y), c.tier, tex, 0.3 * k, t, true)
			CaseOverlay.draw_card(self, Rect2(x, y, CARD.x, CARD.y), c.tier, tex, k, t, true)
			if i == glint:
				_draw_glint(Rect2(x, y, CARD.x, CARD.y), str(c.tier))

	func _draw_glint(r: Rect2, tier: String) -> void:
		# A light sweep across the card that almost was, and its outline burning.
		var col := CasinoFx.glow_color(tier)
		var sweep := fmod(glint_t * 1.6, 1.4) - 0.2
		var x := r.position.x + sweep * (r.size.x + 20) - 10
		var pts := PackedVector2Array([
			Vector2(x, r.position.y), Vector2(x + 6, r.position.y),
			Vector2(x - 4, r.end.y), Vector2(x - 10, r.end.y)])
		draw_colored_polygon(pts, Color(col, 0.35))
		draw_rect(r.grow(1), Color(CasinoFx.rarity_color(tier), 0.6 + 0.4 * sin(glint_t * 20.0)), false, 1.0)


class GlassTop:
	extends Control
	## Edge darkness over the reel and the center line with its triangles.
	var kink := 0.0:
		set(v):
			kink = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		# Two faint streaks of glass.
		for gx: float in [96.0, 118.0]:
			draw_colored_polygon(PackedVector2Array([Vector2(gx, 0), Vector2(gx + 10, 0), Vector2(gx - 14, size.y), Vector2(gx - 24, size.y)]), Color(Palette.CREAM, 0.03))
		var fade := _edge()
		draw_texture_rect(fade, Rect2(0, 0, 70, size.y), false)
		draw_texture_rect(fade, Rect2(size.x, 0, -70, size.y), false)
		var x := LINE + kink
		draw_rect(Rect2(x - 1, 0, 3, size.y), Color(Palette.CREAM, 0.16))
		draw_rect(Rect2(x, 0, 1, size.y), Palette.CREAM)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 4.5, 0), Vector2(x + 5.5, 0), Vector2(x + 0.5, 5)]), Palette.CREAM)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 4.5, size.y), Vector2(x + 5.5, size.y), Vector2(x + 0.5, size.y - 5)]), Palette.CREAM)

	static func _edge() -> Texture2D:
		var key := "_reel_edge"
		if not CasinoFx._cache.has(key):
			var g := Gradient.new()
			g.set_color(0, Color(GLASS, 1.0))
			g.set_color(1, Color(GLASS, 0.0))
			var tex := GradientTexture2D.new()
			tex.gradient = g
			tex.width = 32
			tex.height = 4
			CasinoFx._cache[key] = tex
		return CasinoFx._cache[key]


class Cabinet:
	extends Control
	## The machine body: wood, bronze trim, the crown, the reel bezel and its chase bulbs.
	var chase := 0.0
	var flash_color := Palette.CREAM
	var flash_until := -1.0
	var _t := 0.0

	func _init() -> void:
		position = Vector2(8, 58)
		size = Vector2(464, 214)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var o := -position
		# Body and inner panel.
		draw_rect(Rect2(0, 8, size.x, size.y), BODY)
		draw_rect(Rect2(0, 8, size.x, size.y), TRIM, false, 2.0)
		draw_rect(Rect2(6, 14, size.x - 12, size.y - 12), BODY_DARK, false, 1.0)
		# Crown with the price plate.
		var crown := PackedVector2Array([Vector2(160, 8), Vector2(176, 0), Vector2(288, 0), Vector2(304, 8)])
		draw_colored_polygon(crown, BODY)
		draw_polyline(crown, TRIM, 2.0)
		draw_rect(Rect2(186, 3, 92, 24), BODY_DARK)
		draw_rect(Rect2(186, 3, 92, 24), TRIM_LIT, false, 1.0)
		# Reel bezel.
		var bez := Rect2(WIN.position + o, WIN.size).grow(6)
		draw_rect(bez, BODY_DARK)
		draw_rect(bez, TRIM_LIT, false, 1.0)
		draw_rect(Rect2(WIN.position + o, WIN.size), GLASS)
		# Chase bulbs above and below the window.
		var flashing := _t < flash_until
		var n := int(bez.size.x / 10.0)
		for i in n:
			var x := bez.position.x + 5 + i * 10
			for y: float in [bez.position.y - 4, bez.end.y + 3]:
				var lit := (i + int(chase)) % 4 == 0
				var c := Palette.CREAM if not flashing else flash_color
				var a := 1.0 if (lit or flashing and int(_t * 12.0) % 2 == 0) else 0.22
				draw_rect(Rect2(x - 1, y - 1, 2, 2), Color(c, a))
		# Counter lip under the mouths.
		draw_rect(Rect2(0, size.y - 34, size.x, 2), TRIM)
		# The brass bill tray along the bottom: a dark trough with a brass lip, the lamp's
		# light sliding along its rim.
		var tray := Rect2(20, size.y - 22, 400, 14)
		draw_rect(tray.grow(2), Color("3a2614"))
		draw_rect(tray.grow(1), Color("8a6a3a"))
		draw_rect(tray, Color("0b0710"))
		draw_rect(Rect2(tray.position.x, tray.position.y, tray.size.x, 2), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(tray.position.x - 1, tray.position.y - 1, tray.size.x + 2, 1), Color("c99a4a"))
		draw_rect(Rect2(tray.position.x, tray.end.y - 1, tray.size.x, 1), Color("2a1a10"))
		var sweep := fposmod(_t * 60.0, tray.size.x + 120.0) - 60.0
		for i in 24:
			var x := tray.position.x + sweep + i - 12
			if x >= tray.position.x and x < tray.end.x:
				draw_rect(Rect2(x, tray.position.y - 1, 1, 1), Color(Palette.CREAM, 0.6 * (1.0 - absf(i - 12) / 12.0)))
		draw_texture_rect(CasinoFx.res(CasinoFx.LIGHT) as Texture2D, Rect2(Vector2(232, tray.position.y - 10) - Vector2(60, 0), Vector2(120, 34)), false, Color(Palette.CREAM, 0.06))
		for x: float in [tray.position.x + 4, tray.end.x - 5]:
			draw_rect(Rect2(x, tray.get_center().y - 1, 2, 2), Color("c99a4a"))


class Mouth:
	extends Control
	## A slot mouth: the account's icon, its name, its real balance, and the slit.
	var dest := ""
	var account := ""
	var balance := 0
	var selected := false:
		set(v):
			selected = v
			if is_inside_tree():
				create_tween().tween_property(self, "_dim", 1.0 if v else 0.6, 0.2)
			else:
				_dim = 1.0 if v else 0.6
			queue_redraw()
	var _dim := 1.0:
		set(v):
			_dim = v
			self_modulate = Color(v, v, v)
			for c: Node in get_children():
				(c as CanvasItem).modulate = Color(v, v, v)
	var _icon := Control.new()
	var _name: Label
	var _bal: Label
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func setup(account_name: String, balance_cents: int, icon: Texture2D) -> void:
		account = account_name
		# The icon at 2x with a 1 px night outline.
		_icon.size = Vector2(32, 32)
		_icon.position = Vector2(6, 8)
		_icon.pivot_offset = Vector2(16, 32)
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for off: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2.ZERO]:
			var t := TextureRect.new()
			t.texture = icon
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.size = Vector2(32, 32)
			t.position = off
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if off != Vector2.ZERO:
				t.material = CasinoFx.silhouette(Palette.NIGHT)
			_icon.add_child(t)
		add_child(_icon)
		_name = CasinoFx.label(account_name, Palette.MUTED, 16, CasinoFx.M5X7)
		_name.position = Vector2(44, 2)
		add_child(_name)
		_bal = CasinoFx.label("", Palette.CREAM, 20)
		_bal.position = Vector2(44, 13)
		add_child(_bal)
		show_balance(balance_cents)

	func show_balance(cents: int) -> void:
		balance = cents
		_bal.text = Money.fmt(cents)

	func pulse() -> void:
		var tw := _icon.create_tween()
		tw.tween_property(_icon, "scale", Vector2(1.3, 0.8), 0.06)
		tw.tween_property(_icon, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _process(delta: float) -> void:
		_t += delta
		if selected:
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var lamp := Color("ffe6c4")
		var brass := Color("c99a4a")
		if selected:
			draw_texture_rect(CasinoFx.res(CasinoFx.LIGHT) as Texture2D, Rect2(-14, -18, size.x + 28, size.y + 36), false, Color(lamp, 0.08))
		draw_rect(r, Color(BODY_DARK, 0.96))
		draw_rect(Rect2(1, 1, size.x - 2, 1), Color(1, 1, 1, 0.05))
		if selected:
			var a := 0.55 + 0.3 * sin(_t * 4.0)
			draw_rect(r.grow(1), Color(lamp, a * 0.3), false, 3.0)
			draw_rect(r, Color(lamp, a), false, 1.0)
		else:
			draw_rect(r, Color(TRIM, 0.6), false, 1.0)
		# The slit the bill goes into: a brass rim, a black throat with lamp light inside.
		var slit := Rect2(64, 46, 64, 6)
		draw_rect(slit.grow(3), Color("6b4a22"))
		draw_rect(slit.grow(2), brass if selected else brass.darkened(0.35))
		draw_rect(Rect2(slit.position.x - 2, slit.position.y - 2, slit.size.x + 4, 1), brass.lightened(0.4) if selected else brass)
		draw_rect(slit, Color(0, 0, 0))
		var glow_a := (0.4 + 0.15 * sin(_t * 3.0)) if selected else 0.08
		for i in int(slit.size.y):
			var k := float(i) / slit.size.y
			draw_rect(Rect2(slit.position.x + 1, slit.position.y + i, slit.size.x - 2, 1), Color(lamp, glow_a * k * k))
		for x in range(int(slit.position.x) + 4, int(slit.end.x) - 2, 8):
			draw_rect(Rect2(x, slit.end.y + 3, 1, 1), Color(brass, 0.5))


class Bill:
	extends Control
	## The bill on the slot: cream paper, its amount, the stamp once it's paid.
	var home := Vector2.ZERO
	var text := ""
	var stamped := false:
		set(v):
			stamped = v
			queue_redraw()
	var refused := false:
		set(v):
			refused = v
			queue_redraw()
	var shiver := 0.0
	var squash := 0.0:
		set(v):
			squash = v
			queue_redraw()
	var _t := 0.0

	func _init() -> void:
		size = Vector2(24, 11)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var paper := Palette.MUTED.darkened(0.3) if refused else Palette.CREAM
		var h := size.y * (1.0 - squash)
		var bob := 0.0 if stamped or refused else roundf(sin(_t * 3.0))
		var jit := Vector2(randf_range(-1, 1), 0).round() * shiver if shiver > 0.3 else Vector2.ZERO
		var r := Rect2(Vector2(0, size.y - h + bob) + jit, Vector2(size.x, h))
		if not refused:
			draw_texture_rect(CasinoFx.res(CasinoFx.LIGHT) as Texture2D, r.grow(8), false, Color(Palette.CREAM, 0.18))
		draw_rect(r, paper)
		draw_rect(r.grow(-2), Color(Palette.NIGHT, 0.5), false, 1.0)
		if h > 7:
			var f := CasinoFx.font()
			draw_string(f, r.position + Vector2(6, 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Palette.NIGHT)
		if stamped and h > 5:
			draw_arc(r.position + Vector2(18, 5.5), 3.5, 0, TAU, 12, Color(Palette.INK, 0.85), 1.0)
			draw_rect(Rect2(r.position + Vector2(17, 4.5), Vector2(2, 2)), Color(Palette.INK, 0.85))


class HoldRing:
	extends Node2D
	## Fills around the bill while it's held on the slot.
	var progress := 0.0:
		set(v):
			progress = v
			queue_redraw()

	func _draw() -> void:
		if progress <= 0.0:
			return
		draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 32, Color(Palette.NIGHT, 0.6), 3.0)
		draw_arc(Vector2.ZERO, 15.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 32, Palette.CREAM, 2.0)


class Lamp:
	extends Control
	## The lamp over the machine. Off means not this week.
	var on := true:
		set(v):
			on = v
			queue_redraw()

	func _init() -> void:
		position = Vector2(220, 0)
		size = Vector2(40, 24)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func flicker_off() -> void:
		var tw := create_tween()
		for i in 3:
			tw.tween_callback(func() -> void: on = false)
			tw.tween_interval(0.05)
			tw.tween_callback(func() -> void: on = true)
			tw.tween_interval(0.04)
		tw.tween_callback(func() -> void: on = false)

	func _draw() -> void:
		draw_line(Vector2(20, 0), Vector2(20, 8), TRIM, 1.0)
		var shade := PackedVector2Array([Vector2(14, 8), Vector2(26, 8), Vector2(31, 15), Vector2(9, 15)])
		draw_colored_polygon(shade, TRIM)
		draw_polyline(shade, TRIM_LIT, 1.0)
		if on:
			draw_texture_rect(CasinoFx.res(CasinoFx.LIGHT) as Texture2D, Rect2(4, 0, 32, 32), false, Color(Palette.CREAM, 0.6))
			draw_rect(Rect2(17, 15, 6, 2), Palette.CREAM)
		else:
			draw_rect(Rect2(17, 15, 6, 2), Palette.INK)


class Cone:
	extends Control
	## The lamp's cone of light falling over the machine.
	func _init() -> void:
		size = Vector2(480, 270)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		material = CasinoFx.additive()

	func _draw() -> void:
		var pts := PackedVector2Array([Vector2(230, 16), Vector2(250, 16), Vector2(420, 270), Vector2(60, 270)])
		var top := Color(Palette.CREAM, 0.13)
		var bottom := Color(Palette.CREAM, 0.0)
		draw_polygon(pts, PackedColorArray([top, top, bottom, bottom]))


class HeroCard:
	extends Control
	## The winning card lifted out of the reel for the reveal and the arc to the book.
	var tier := "common"
	var tex: Texture2D
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var col := CasinoFx.rarity_color(tier)
		draw_rect(r.grow(2), Color(col, 0.35 + 0.2 * sin(_t * 5.0)), false, 2.0)
		CaseOverlay.draw_card(self, r, tier, tex, 1.0, _t, false)
		draw_rect(r.grow(1), CasinoFx.glow_color(tier), false, 1.0)


class Rays:
	extends Control
	## God rays turning slowly behind the item.
	var color := Color.WHITE
	var _a := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		material = CasinoFx.additive()

	func _process(delta: float) -> void:
		_a += delta * 0.5
		queue_redraw()

	func _draw() -> void:
		for i in 12:
			var a := _a + TAU * i / 12.0
			var w := 0.09
			var far := 230.0
			var pts := PackedVector2Array([Vector2.ZERO, Vector2(cos(a - w), sin(a - w)) * far, Vector2(cos(a + w), sin(a + w)) * far])
			var cols := PackedColorArray([Color(color, 0.5), Color(color, 0.0), Color(color, 0.0)])
			draw_polygon(pts, cols)
