class_name MachineOverlay
extends Overlay
## The frame the three side machines share (scratch books, the wheel, the claw): the dark
## room around the machine with the flock humming at the back, Vex at the edge of the light
## saying the price, the place and the exact counts before every pull, the two slot mouths
## (House Fund, Brokerage) with their real balances painted on, and the lamp.
##
## A pull always goes the same way: pay() sends the request, the money lands first (motes
## into the jar, the chant), and only then does the machine play its random part and call
## reveal(), which shows the cosmetic in its rarity's light: glow, outline, flash, beam,
## particles, shake and a slow zoom, with a short cutscene for gold and red. A refusal turns
## the lamp off and Vex says "Not this week." Nothing here does money math: amounts come
## from the API and balances from Game.state.

enum Phase { CHOOSE, BUSY, REVEAL, DONE }

const MIN_GAP_MS := 2500  # money-linked starts are never closer than this
const A := "res://art/packs/"
const LIGHT := A + "kenney-particle-pack/PNG (Transparent)/light_01.png"
const STAR := A + "kenney-particle-pack/PNG (Transparent)/star_06.png"
const JERSEY := A + "google-pixel-fonts-ofl/jersey10/Jersey10-Regular.ttf"
const M5X7 := A + "font-m5x7/m5x7.ttf"
const KYRISE := A + "kyrise-rpg-icons-16/spritesheet/spritesheet_16x16.png"
const CULTISTS := [A + "dawnlike/Characters/Humanoid0.png", A + "dawnlike/Characters/Humanoid1.png"]
const CANDLES := A + "vk-candles-with-eyes/candles_with_eyes.png"
const MOUTH_ICON := {"sav_1": Rect2(192, 240, 16, 16), "brk_1": Rect2(96, 160, 16, 16)}
const MOUTH_NAME := {"sav_1": "House Fund", "brk_1": "Brokerage"}
const BOOK_ICON := Rect2(128, 16, 16, 16)
const TIERS := ["common", "rare", "epic", "legendary", "mythic"]

## The tier marks on tickets, wedges and the claw's tags: [sheet, first frame, frames].
## Pack sprites keep their own colors; the shapes differ too, so a mark reads without color.
const SYMBOL := {
	"common": [KYRISE, Rect2(208, 288, 16, 16), 1],
	"rare": [A + "karsiori-gems/GEM 2/GEM 2 - BLUE - Spritesheet.png", Rect2(0, 0, 23, 27), 10],
	"epic": [A + "karsiori-gems/GEM 1/GEM 1 - PURPLE - Spritesheet.png", Rect2(0, 0, 18, 30), 10],
	"legendary": [A + "karsiori-gems/GEM 3/GEM 3 - GOLD - Spritesheet.png", Rect2(0, 0, 28, 28), 11],
	"mythic": [A + "karsiori-gems/GEM 6/GEM 6 - RED - Spritesheet.png", Rect2(0, 0, 24, 26), 10],
}

## The reveal by tier (docs/INFLUENCES.md, the CS:GO reveal table).
const REVEAL := {
	"common": {"stop": 0.05, "flash": 0.0, "fade": 0.0, "shake": 1.0, "shake_s": 0.12, "sparks": 8, "zoom": 1.6},
	"rare": {"stop": 0.083, "flash": 0.35, "fade": 0.18, "shake": 1.5, "shake_s": 0.15, "sparks": 16, "zoom": 1.8},
	"epic": {"stop": 0.117, "flash": 0.5, "fade": 0.25, "shake": 2.0, "shake_s": 0.25, "sparks": 32, "zoom": 2.0},
	"legendary": {"stop": 0.2, "flash": 0.7, "fade": 0.4, "shake": 4.0, "shake_s": 0.4, "sparks": 64, "zoom": 2.2},
	"mythic": {"stop": 0.2, "flash": 0.9, "fade": 0.6, "shake": 6.0, "shake_s": 0.5, "sparks": 120, "zoom": 2.4},
}
const GLOW := {
	"common": Color("d5d8db"), "rare": Color("9cc4ff"), "epic": Color("d3a3ff"),
	"legendary": Color("ffe08a"), "mythic": Color("ff8a90"),
}
const SHADOW := {
	"common": Color("5d6166"), "rare": Color("1f4f9e"), "epic": Color("5f259c"),
	"legendary": Color("a86a0c"), "mythic": Color("9e141d"),
}

const SND_LAMP := A + "kenney-interface-sounds/Audio/switch_002.ogg"
const SND_SELECT := A + "kenney-interface-sounds/Audio/select_002.ogg"
const SND_LAY := A + "kenney-impact-sounds/Audio/impactWood_heavy_001.ogg"
const SND_COIN_IN := A + "kenney-casino-audio/Audio/chip-lay-2.ogg"
const SND_HUM := A + "owlishmedia-creepy-chanting/ethereal_chant_Subclip_01_01.ogg"
const SND_CHOIR := A + "mumusi-cathedral-of-shadows/Cathedral_of_Shadows_loop.ogg"
const SND_BOOK := A + "kenney-rpg-audio/Audio/bookFlip1.ogg"
const SND_WHOOSH := A + "ninja-adventure/Audio/Sounds/Whoosh & Slash/Whoosh.ogg"
const SND_CLAP := A + "kenney-casino-audio/Audio/chips-collide-3.ogg"
const SND_SIGH := A + "ninja-adventure/Audio/Sounds/Voice/Voice7.ogg"
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

# Drawn parts only (cabinets, trim). Pack sprites keep their own colors.
const BODY := Color("24162a")
const BODY_DARK := Color("160e1b")
const TRIM := Color("6e5146")
const TRIM_LIT := Color("b58d6c")
const GLASS := Color("08050c")
const EYES := Color("d8ff8a")

const VEX_AT := Vector2(8, 44)  # the bust's top-left
const BUBBLE_AT := Vector2(124, 42)
const CENTER := Vector2(240, 112)  # where a revealed item hangs
const BOOK_AT := Vector2(436, 232)

static var _cache: Dictionary = {}
static var _last_dest := "sav_1"
static var _last_start_ms := -100000

## Where the moment is, for the tour and anyone listening: choose, paying, money, then the
## machine's own beats, then land, reveal, cutscene, book, closed (or refused, closed).
var moment := "choose"
## Everything Vex has said, in order.
var said: PackedStringArray = []
var dest := "sav_1"
var result: Dictionary = {}
var phase := Phase.CHOOSE

var stage := Control.new()  # the machine builds itself here
var _room := Control.new()  # everything that shakes
var _back := Control.new()
var _fx := Control.new()
var _dark := ColorRect.new()  # the room going dark behind a reveal
var _cine := Control.new()  # cutscene beams and the falling item
var _bubble := SpeechBubble.new()
var _vex: CasinoRoomVex.Bust
var _lamp: Lamp
var _cone: Cone
var _mouths: Dictionary = {}  # dest -> Mouth
var _book := TextureRect.new()
var _cultists: Array[TextureRect] = []
var _flames: Array[TextureRect] = []
var _hum := AudioStreamPlayer.new()
var _choir := AudioStreamPlayer.new()
var _speech := 0
var _t := 0.0
var _tapped := false


# --- for machines to fill in ----------------------------------------------------------

## Build the machine into `stage` (480x270, drawn under the lamp's light).
func _build_machine() -> void:
	pass


## What Vex says before the pull, from /state (casino.dealer.before).
func _dealer_line() -> String:
	return str(Game.state.get("casino", {}).get("dealer", {}).get("line", ""))


## The price of the pull about to happen, for the lamp.
func _price_cents() -> int:
	return 0


## Taps outside this close the machine while nothing is happening.
func _machine_rect() -> Rect2:
	return Rect2(100, 20, 280, 214)


## The machine's own input (drags, taps on its parts), in room coordinates. Return true when
## it used the event.
func _machine_input(_event: InputEvent, _at: Vector2) -> bool:
	return false


func _lamp_x() -> float:
	return 240.0


# --- building ----------------------------------------------------------------------------

func _ready() -> void:
	dest = _last_dest if _last_dest in MOUTH_NAME else "sav_1"
	_build_frame()
	_build_machine()
	_build_front()
	_select(dest, false)
	_room.pivot_offset = Vector2(240, 135)
	_room.scale = Vector2(0.92, 0.92)
	_room.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_room, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_property(_room, "modulate:a", 1.0, 0.2)
	Sfx.play_path(SND_LAMP, 1.2, -10.0)
	_hum.stream = looped(SND_HUM)
	_hum.volume_db = -26.0
	add_child(_hum)
	_hum.play()
	_choir.stream = looped(SND_CHOIR)
	add_child(_choir)


func _exit_tree() -> void:
	_hum.stop()
	_choir.stop()


func _build_frame() -> void:
	CasinoFx.room_dim(self, Vector2(_lamp_x(), 140))
	_room.size = Vector2(480, 270)
	_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_room)
	_back.size = Vector2(480, 270)
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room.add_child(_back)
	_build_crowd()
	# Candles at the edges, an eye on a stand by the dealer.
	for spot: Array in [[Vector2(8, 196), 0], [Vector2(454, 196), 3], [Vector2(90, 150), 7]]:
		var stand := TextureRect.new()
		stand.texture = region(CANDLES, Rect2(int(spot[1]) * 18, 0, 18, 41))
		stand.position = spot[0]
		stand.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var flame_at: Vector2 = spot[0] + Vector2(9, 16 if int(spot[1]) == 7 else 6)
		_flames.append(glow(_back, flame_at, Color(Palette.CREAM, 0.3), 16.0))
		_back.add_child(stand)
	_vex = CasinoRoomVex.Bust.new()
	_vex.position = VEX_AT
	_vex.rail = true
	_back.add_child(_vex)
	stage.size = Vector2(480, 270)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room.add_child(stage)


func _build_front() -> void:
	var casino: Dictionary = Game.state.get("casino", {})
	for id: String in ["sav_1", "brk_1"]:
		var m := Mouth.new()
		m.dest = id
		m.position = Vector2(110 if id == "sav_1" else 250, 236)
		m.size = Vector2(120, 28)
		_room.add_child(m)
		m.setup(_account_name(casino, id), _balance(id), region(KYRISE, MOUTH_ICON[id]))
		_mouths[id] = m
	_book.texture = region(KYRISE, BOOK_ICON)
	_book.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_book.size = Vector2(32, 32)
	_book.position = BOOK_AT
	_book.pivot_offset = Vector2(16, 32)
	_book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room.add_child(_book)
	_cone = Cone.new()
	_cone.x = _lamp_x()
	_room.add_child(_cone)
	_lamp = Lamp.new()
	_lamp.position = Vector2(_lamp_x() - 20, 0)
	_room.add_child(_lamp)
	_fx.size = Vector2(480, 270)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room.add_child(_fx)
	_bubble.position = BUBBLE_AT
	_bubble.tail_x = -66.0  # the tail drops toward his hood
	_room.add_child(_bubble)
	_dark.color = Color(0, 0, 0, 0)
	_dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dark.z_index = 40
	add_child(_dark)
	_cine.size = Vector2(480, 270)
	_cine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cine.z_index = 41
	add_child(_cine)


func _build_crowd() -> void:
	# The flock at the back: hooded shapes on the risers, nothing lit but their eyes.
	var spots: Array[Vector2] = []
	for x: int in [112, 140, 168, 196, 284, 312, 340, 368, 396, 424, 452]:
		spots.append(Vector2(x, 22))
	for x: int in [126, 154, 182, 298, 326, 354, 382, 410, 438, 466]:
		spots.append(Vector2(x, 34))
	var cells := [Rect2(0, 272, 16, 16), Rect2(16, 272, 16, 16), Rect2(32, 272, 16, 16)]
	for i in spots.size():
		var cell: Rect2 = cells[i % cells.size()]
		_cultists.append(CasinoFx.cultist(_back, spots[i], CULTISTS[0], cell, spots[i].y > 30, i % 3 == 1))


static func _account_name(casino: Dictionary, id: String) -> String:
	for d: Dictionary in casino.get("destinations", []):
		if str(d.get("id", "")) == id:
			return str(d.get("name", MOUTH_NAME.get(id, id)))
	return MOUTH_NAME.get(id, id)


static func _balance(id: String) -> int:
	for d: Dictionary in Game.state.get("casino", {}).get("destinations", []):
		if str(d.get("id", "")) == id:
			return int(d.get("balance_cents", 0))
	return 0


## The slot mouth for a destination ("sav_1" or "brk_1"), for taps in the tour.
func mouth_control(id: String) -> Control:
	return _mouths.get(id)


## The lamp over the slot: on while the week's room covers the price.
func lamp_on() -> bool:
	return _lamp.on


# --- per frame ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	var beat := int(_t * 1.4)
	for i in _cultists.size():
		var c := _cultists[i]
		var cell: Rect2 = c.get_meta("cell")
		c.texture = region(CULTISTS[(beat + i) % 2], cell)
	for i in _flames.size():
		_flames[i].modulate.a = 0.26 + 0.1 * sin(_t * 9.0 + i * 1.7) + 0.05 * sin(_t * 23.0 + i)
	CasinoFx.blink(_cultists, delta)


# --- input -------------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var at := to_room(event)
	if phase == Phase.CHOOSE or phase == Phase.BUSY:
		if _machine_input(event, at):
			accept_event()
			return
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	accept_event()
	match phase:
		Phase.CHOOSE:
			for id: String in _mouths:
				var m: Mouth = _mouths[id]
				if m.get_rect().has_point(at):
					if id != dest:
						_select(id, true)
					else:
						m.poke()
						Sfx.play_path(SND_SELECT, 1.2, -14.0)
					return
			if not _machine_rect().has_point(at) and _t >= 0.35:
				back_out()  # (sooner than that, it's the tail of the double tap that opened it)
			else:
				Sfx.ui("tap")  # on the machine but on no part of it: a soft click all the same
		_:
			_tapped = true
			Sfx.ui("tap")  # it hurries what's playing; the click says the tap landed


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and phase == Phase.CHOOSE:
		back_out()


## An input event's position in room coordinates (480x270).
func to_room(event: InputEvent) -> Vector2:
	var me := event as InputEventMouse
	if me == null:
		return Vector2(-1, -1)
	return _room.get_transform().affine_inverse() * me.position


func back_out() -> void:
	phase = Phase.DONE
	moment = "closed"
	Sfx.play_path(SND_LAMP, 0.9, -12.0)
	close(null)


func _select(id: String, speak: bool) -> void:
	dest = id
	for k: String in _mouths:
		(_mouths[k] as Mouth).selected = k == id
	if speak:
		Sfx.play_path(SND_SELECT, 1.0, -8.0)
		(_mouths[id] as Mouth).poke()
	update_lamp()
	speak_line(_dealer_line())


## The lamp is on while the week's room (from /state) covers the price.
func update_lamp() -> void:
	var can := int(Game.state.get("casino", {}).get("can_spend_cents", 0))
	var on := can >= _price_cents()
	if on != _lamp.on:
		_lamp.on = on
		_cone.visible = on


## Vex says a line in two breaths: the money, then the counts.
func speak_line(line: String) -> void:
	if line == "":
		return
	_speech += 1
	var mine := _speech
	var cut := line.find(". ")
	var parts := [line] if cut < 0 else [line.substr(0, cut + 1), line.substr(cut + 2)]
	for i in parts.size():
		if mine != _speech or not is_inside_tree():
			return
		_vex.speak()
		said.append(str(parts[i]))
		await _bubble.say(str(parts[i]), 0.35 if i < parts.size() - 1 else 4.0)


func hush() -> void:
	_speech += 1
	_bubble.hide_now()


# --- paying ------------------------------------------------------------------------------

## One paid pull. The money moves first, in full, or not at all: the request goes out, the
## money lands (motes from `slot` into the jar), and only then is the result handed back for
## the machine to play. On a refusal the lamp goes off, Vex says so, the overlay closes, and
## this returns {}.
func pay(path: String, body: Dictionary, slot: Vector2) -> Dictionary:
	phase = Phase.BUSY
	moment = "paying"
	hush()
	_last_dest = dest
	var wait_ms := MIN_GAP_MS - (Time.get_ticks_msec() - _last_start_ms)
	if wait_ms > 0:
		await get_tree().create_timer(wait_ms / 1000.0).timeout
	_last_start_ms = Time.get_ticks_msec()
	var full := body.duplicate()
	full["to_account"] = dest
	var res: Array = await Game.api.request("POST", path, {}, full)
	if res[1] != "":
		await refuse(str(res[1]))
		return {}
	result = res[0]
	Game.refresh()
	await _money(result, slot)
	# A breath with the money in before anything random happens.
	await get_tree().create_timer(0.6).timeout
	return result


func _money(data: Dictionary, slot: Vector2) -> void:
	moment = "money"
	var money: Dictionary = data.get("money", {})
	var m: Mouth = _mouths.get(str(money.get("to_account", dest)), _mouths[dest])
	Sfx.play_path(SND_COIN_IN, 1.0, -4.0)
	for e: Dictionary in data.get("_events", []):
		if str(e.get("kind", "")) == "money_moved":
			Game.event_fired.emit(e)
	# Into the mouth: the motes land on its lip, and the amount rises above it.
	var lip := m.position + Vector2(m.size.x / 2.0, -2)
	# Honest about the demo: a "simulated" chip rides beside the amount when no real dollars moved.
	var tag := "simulated" if str(money.get("status", "")) == "simulated" else ""
	var amount := int(money.get("amount_cents", 0))
	await CasinoFx.money_landed(_fx, slot, lip, amount, m.account, tag, lip + Vector2(0, -26))
	m.pulse()
	CasinoFx.stamp(_fx, m.position + Vector2(m.size.x - 22, 2), CasinoFx.dollars(amount), m)
	await CasinoFx.hit_stop(get_tree(), 0.08)
	_count_up(m)


## Count the painted balance up to what /state now says (formatting only, no money math).
func _count_up(m: Mouth) -> void:
	var from := m.balance
	var waited := 0.0
	while _balance(m.dest) == from and waited < 1.5 and is_inside_tree():
		await get_tree().process_frame
		waited += get_process_delta_time()
	var to := _balance(m.dest)
	if to == from or not is_instance_valid(m):
		return
	await m.roll(from, to)


## The lamp over the slot clicks off, Vex lays it down and says it, and the machine closes
## with nothing moved.
func refuse(message: String) -> void:
	phase = Phase.DONE
	moment = "refused"
	_lamp.flicker_off()
	Sfx.play_path(SND_LAMP, 0.8, -4.0)
	_cone.visible = false
	var dim := stage.create_tween()
	dim.tween_property(stage, "modulate", Color(0.55, 0.55, 0.6), 0.3)
	await get_tree().create_timer(0.35).timeout
	Sfx.play_path(SND_LAY, 0.8, -6.0)
	_speech += 1
	_vex.speak()
	said.append(message)
	await _bubble.say(message, 1.4)
	moment = "closed"
	close(null)


## Close with the pull's result once the machine has finished its last beat.
func finish() -> void:
	phase = Phase.DONE
	moment = "closed"
	close(result)


# --- the reveal --------------------------------------------------------------------------

## Show the cosmetic coming out of the machine at `from`: hit stop, the rarity flash,
## sparks, a ring, shake, the flock reacting, the item in its rarity glow and outline with a
## slow zoom, a beam for purple, a cutscene for gold and red, then into the book.
func reveal(item: Dictionary, from: Vector2) -> void:
	phase = Phase.REVEAL
	moment = "land"
	_hum.stop()
	var tier := str(item.get("tier", "common"))
	var cfg: Dictionary = REVEAL.get(tier, REVEAL.common)
	var color := CasinoFx.rarity_color(tier)
	var high := tier == "legendary" or tier == "mythic"
	_vex.look = CENTER
	if tier == "mythic":
		# The room goes black except the red glow where it came out.
		_dark.color = Color(0, 0, 0, 0.97)
		var g := rarity_glow(_cine, from, tier, 34.0)
		Sfx.play_path(SND_BOOM, 0.5, 0.0)
		await get_tree().create_timer(0.5).timeout
		g.queue_free()
	if high:
		await CasinoFx.hit_stop(get_tree(), float(cfg.stop))
	moment = "reveal"
	Sfx.play("reveal_" + tier)
	Sfx.play_path(STINGER[tier], 1.0, -4.0)
	if tier == "legendary":
		Sfx.play_path(SND_JACKPOT, 1.0, -6.0)
	elif tier == "mythic":
		Sfx.play_path(SND_DREAD, 1.0, -2.0)
	if high:
		CasinoFx.flash(self, color, float(cfg.flash), float(cfg.fade))
		shake(_room, float(cfg.shake), float(cfg.shake_s))
		sparks(_fx, from, tier, int(cfg.sparks))
		ring(_fx, from, color, 26.0 + int(cfg.sparks) * 0.35, 0.5)
	else:
		# It pops out of the machine; the stage waits for it in the light.
		CasinoFx.burst(_cine, from, color, 8, 70.0, 0.5)
	_crowd_react(tier)
	var behind := create_tween()
	behind.tween_property(_dark, "color", Color(0.02, 0.0, 0.03, 0.72), 0.3)

	var hero := make_item(item, 32.0)
	hero.position = from - hero.size / 2.0
	hero.scale = Vector2(0.3, 0.3)
	hero.z_index = 60
	add_child(hero)
	var halo := rarity_glow(self, from, tier, 40.0 + 10.0 * TIERS.find(tier))
	halo.z_index = 59
	var lift := CENTER - hero.size / 2.0
	var peak := (hero.position + lift) / 2.0 + Vector2(0, -36)
	var start := hero.position
	var fly := hero.create_tween().set_parallel(true)
	fly.tween_method(func(t: float) -> void:
		hero.position = start.lerp(peak, t).lerp(peak.lerp(lift, t), t)
		halo.position = hero.position + hero.size / 2.0 - halo.size / 2.0, 0.0, 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fly.tween_property(hero, "scale", Vector2(1.4, 1.4) if high else Vector2(0.9, 0.9), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play_path(SND_WHOOSH, 1.4, -10.0)
	await fly.finished

	if high:
		ring(_fx, CENTER, color, 40.0, 0.4)
		# The slow zoom.
		var zoom := hero.create_tween()
		zoom.tween_property(hero, "scale", Vector2.ONE * float(cfg.zoom), 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		halo.create_tween().tween_property(halo, "scale", Vector2(1.3, 1.3), 1.1)
		var name_label := label(str(item.get("name", "")), color, 20)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.size = Vector2(300, 24)
		name_label.position = Vector2(90, CENTER.y + 34)
		name_label.z_index = 61
		name_label.modulate.a = 0.0
		await _cutscene(tier, item, hero, halo, name_label)
		name_label.create_tween().tween_property(name_label, "modulate:a", 0.0, 0.25)
	else:
		# The rung for its tier: the card turns in and lands, the stage answers above the dark.
		CasinoFx.flip_in(hero, Vector2.ONE * float(cfg.zoom), 0.3)
		await get_tree().create_timer(0.28).timeout
		halo.create_tween().tween_property(halo, "scale", Vector2(1.3, 1.3), 0.6)
		var stage_fx := await CasinoFx.reveal(_cine, CENTER, tier, _room)
		var sway := CasinoFx.wobble(hero)
		_pulse_outline(hero)
		var name_label := CasinoFx.type_name(self, str(item.get("name", "")), tier, CENTER + Vector2(0, 48))
		await _beat(1.5 if tier == "common" else 1.9, 0.6)
		name_label.create_tween().tween_property(name_label, "modulate:a", 0.0, 0.25)
		CasinoFx.fade_stage(stage_fx)
		sway.kill()
		hero.rotation = 0.0
	var back := create_tween()
	back.tween_property(_dark, "color", Color(0, 0, 0, 0), 0.35)
	await _to_book(hero, halo, tier)
	for e: Dictionary in result.get("_events", []):
		if str(e.get("kind", "")) == "item":
			Game.event_fired.emit(e)


## The rarity outline around a revealed item breathes while it waits.
static func _pulse_outline(hero: Control) -> void:
	for i in mini(4, hero.get_child_count()):
		var o := hero.get_child(i) as CanvasItem
		var tw := o.create_tween().set_loops()
		tw.tween_property(o, "modulate:a", 0.45, 0.45).set_trans(Tween.TRANS_SINE)
		tw.tween_property(o, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)


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


## Gold and red: the room goes dark, a beam opens, the choir comes in, and the item spins down
## the beam into the light. About 3 s; taps hurry it after the first second.
func _cutscene(tier: String, item: Dictionary, hero: Control, halo: TextureRect, name_label: Label) -> void:
	moment = "cutscene"
	var color := CasinoFx.rarity_color(tier)
	var center := CENTER
	_tapped = false
	var dark := create_tween()
	dark.tween_property(_dark, "color", Color(0.02, 0.0, 0.03, 0.95), 0.3)
	var fade := hero.create_tween().set_parallel(true)
	fade.tween_property(hero, "modulate:a", 0.0, 0.25)
	fade.tween_property(halo, "modulate:a", 0.0, 0.25)
	_choir.volume_db = -14.0
	_choir.play()
	_choir.create_tween().tween_property(_choir, "volume_db", -3.0, 0.8)
	var light := beam(_cine, center.x, 200.0, tier, 42.0, 0.0)
	var rays := Rays.new()
	rays.color = color
	rays.position = center
	rays.modulate.a = 0.0
	_cine.add_child(rays)
	rays.create_tween().tween_property(rays, "modulate:a", 0.55, 0.6)
	var specks := flakes(_cine, Rect2(0, 0, 480, 270), tier, 3.4)
	var core := rarity_glow(_cine, center, tier, 56.0)
	core.modulate.a = 0.0

	var big := make_item(item, 64.0, 3.0)
	big.position = Vector2(center.x - 32, -80)
	big.z_index = 2
	_cine.add_child(big)
	await get_tree().create_timer(0.3).timeout
	var fall := big.create_tween().set_parallel(true)
	fall.tween_property(big, "position:y", center.y - 32, 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fall.tween_method(func(ph: float) -> void: big.scale.x = cos(ph), 0.0, 6.0 * PI, 1.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	core.create_tween().tween_property(core, "modulate:a", 0.9, 1.3)
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
	ring(_cine, center, color, 74.0, 0.6)
	ring(_cine, center, GLOW[tier], 46.0, 0.4)
	sparks(_cine, center, tier, 48)
	shake(_cine, 3.0, 0.3)
	_crowd_react(tier)
	var slam := big.create_tween()
	slam.tween_property(big, "scale", Vector2(1.25, 0.8), 0.06)
	slam.tween_property(big, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	name_label.position = Vector2(90, center.y + 40)
	name_label.z_index = 80
	add_child(name_label)
	name_label.create_tween().tween_property(name_label, "modulate:a", 1.0, 0.3)
	if tier == "mythic":
		var flicker := _dark.create_tween().set_loops(4)
		flicker.tween_property(_dark, "color", Color(0.3, 0.0, 0.03, 0.9), 0.08)
		flicker.tween_property(_dark, "color", Color(0.02, 0.0, 0.03, 0.95), 0.12)
	await _beat(1.5, 0.0)
	# Out of the dark: the item shrinks back into the one that goes to the book.
	var out := create_tween().set_parallel(true)
	out.tween_property(_dark, "color", Color(0.02, 0.0, 0.03, 0.72), 0.4)
	out.tween_property(light, "width", 0.0, 0.4)
	out.tween_property(rays, "modulate:a", 0.0, 0.4)
	out.tween_property(core, "modulate:a", 0.0, 0.4)
	out.tween_property(_choir, "volume_db", -40.0, 0.6)
	out.tween_property(big, "modulate:a", 0.0, 0.3)
	hero.position = center - hero.size / 2.0
	out.tween_property(hero, "modulate:a", 1.0, 0.3)
	halo.position = center - halo.size / 2.0
	out.tween_property(halo, "modulate:a", 1.0, 0.3)
	await out.finished
	_choir.stop()
	for n: Node in [light, rays, core, big, specks]:
		if is_instance_valid(n):
			n.queue_free()


## The item arcs into the collection book in the corner; the book squashes.
func _to_book(hero: Control, halo: Control, tier: String) -> void:
	moment = "book"
	var from := hero.position
	var to := _book.position + Vector2(16, 14) - hero.size / 2.0
	var peak := from.lerp(to, 0.5) + Vector2(0, -60)
	Sfx.play_path(SND_WHOOSH, 1.6, -12.0)
	var tw := hero.create_tween().set_parallel(true)
	tw.tween_method(func(t: float) -> void:
		hero.position = from.lerp(peak, t).lerp(peak.lerp(to, t), t), 0.0, 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(hero, "scale", Vector2(0.4, 0.4), 0.5).set_ease(Tween.EASE_IN)
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
	while waited < seconds and is_inside_tree():
		await get_tree().process_frame
		waited += get_process_delta_time()
		if _tapped and waited >= tap_after:
			return
		if waited < tap_after:
			_tapped = false


# --- shared pieces -----------------------------------------------------------------------

## A cosmetic in its rarity: a glow behind, a 1 px (source pixel) outline in the rarity
## color on four sides, the pack icon on top. `size` is the drawn icon size.
static func make_item(item: Dictionary, size: float, outline := 2.0) -> Control:
	var tier := str(item.get("tier", "common"))
	var root := Control.new()
	root.size = Vector2(size, size)
	root.pivot_offset = root.size / 2.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := icon(item)
	for off: Vector2 in [Vector2(-outline, 0), Vector2(outline, 0), Vector2(0, -outline), Vector2(0, outline)]:
		var o := TextureRect.new()
		o.texture = tex
		o.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		o.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		o.size = root.size
		o.position = off
		o.material = silhouette(GLOW[tier] if off.y < 0 else CasinoFx.rarity_color(tier))
		o.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(o)
	var front := TextureRect.new()
	front.texture = tex
	front.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	front.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	front.size = root.size
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(front)
	return root


## A tier mark (frame `frame` of its glint loop).
static func symbol(tier: String, frame := 0) -> AtlasTexture:
	var s: Array = SYMBOL.get(tier, SYMBOL.common)
	var r: Rect2 = s[1]
	var n: int = s[2]
	return region(str(s[0]), Rect2(r.position.x + (frame % n) * r.size.x, r.position.y, r.size.x, r.size.y))


static func symbol_frames(tier: String) -> int:
	return int((SYMBOL.get(tier, SYMBOL.common) as Array)[2])


## Draw a tier mark centered at `c` (16 px marks at 2x, gems at 1x, times `k`).
static func draw_symbol(ci: CanvasItem, c: Vector2, tier: String, frame := 0, k := 1.0, tint := Color.WHITE) -> void:
	var tex := symbol(tier, frame)
	var sz := tex.region.size * (2.0 if tex.region.size.x <= 16 else 1.0) * k
	ci.draw_texture_rect(tex, Rect2((c - sz / 2.0).round(), sz.round()), false, tint)


static func res(path: String) -> Resource:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


## One cell of a pack sheet.
static func region(sheet: String, rect: Rect2) -> AtlasTexture:
	var key := "%s@%s" % [sheet, rect]
	if not _cache.has(key):
		var a := AtlasTexture.new()
		a.atlas = res(sheet) as Texture2D
		a.region = rect
		_cache[key] = a
	return _cache[key]


## The icon of a catalog item ({icon: {sheet, rect}}).
static func icon(item: Dictionary) -> AtlasTexture:
	var i: Dictionary = item.get("icon", {})
	var r: Array = i.get("rect", [0, 0, 16, 16])
	return region(str(i.get("sheet", KYRISE)), Rect2(r[0], r[1], r[2], r[3]))


static func label(text: String, color: Color, size := 10, path := JERSEY) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", res(path) as Font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Palette.NIGHT)
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## "$5" for whole dollars, "$5.50" otherwise. Formatting only.
static func price_text(cents: int) -> String:
	return "$%d" % (cents / 100) if cents % 100 == 0 else Money.fmt(cents)


static func additive() -> CanvasItemMaterial:
	if not _cache.has("_add"):
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_cache["_add"] = m
	return _cache["_add"]


## Draws a sprite as a flat shape in `color` (outlines, silhouettes).
static func silhouette(color: Color) -> ShaderMaterial:
	var key := "_sil%s" % color.to_html()
	if not _cache.has(key):
		if not _cache.has("_sil_shader"):
			var sh := Shader.new()
			sh.code = "shader_type canvas_item;\nuniform vec4 tint : source_color;\nvoid fragment() {\n\tCOLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * tint.a * COLOR.a);\n}\n"
			_cache["_sil_shader"] = sh
		var m := ShaderMaterial.new()
		m.shader = _cache["_sil_shader"]
		m.set_shader_parameter("tint", color)
		_cache[key] = m
	return _cache[key]


static func looped(path: String) -> AudioStream:
	var s: Resource = res(path)
	if s == null:
		return null
	var copy: Resource = s.duplicate()
	if copy is AudioStreamOggVorbis:
		(copy as AudioStreamOggVorbis).loop = true
	elif copy is AudioStreamMP3:
		(copy as AudioStreamMP3).loop = true
	return copy as AudioStream


static func grad(offsets: Array, colors: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	return g


## A soft round light. Additive unless `add` is false.
static func glow(parent: Node, pos: Vector2, color: Color, radius := 16.0, add := true) -> TextureRect:
	var t := TextureRect.new()
	t.texture = res(LIGHT) as Texture2D
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.size = Vector2(radius, radius) * 2.0
	t.position = pos - Vector2(radius, radius)
	t.pivot_offset = Vector2(radius, radius)
	t.modulate = color
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if add:
		t.material = additive()
	parent.add_child(t)
	return t


## A rarity glow that breathes until freed.
static func rarity_glow(parent: Node, pos: Vector2, tier: String, radius := 24.0) -> TextureRect:
	var g := glow(parent, pos, Color(CasinoFx.rarity_color(tier), 0.8), radius)
	var tw := g.create_tween().set_loops()
	tw.tween_property(g, "modulate:a", 0.45, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(g, "modulate:a", 0.85, 0.6).set_trans(Tween.TRANS_SINE)
	return g


## Streaks shooting out in the rarity's ramp, with a slower cloud of pixels behind.
static func sparks(parent: Node, pos: Vector2, tier: String, amount := 16) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.75
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 190.0 + amount
	p.damping_min = 40.0
	p.damping_max = 90.0
	p.gravity = Vector2(0, 140)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.5
	p.color_ramp = grad([0.0, 0.25, 1.0], [Color.WHITE, GLOW.get(tier, Palette.CREAM), Color(CasinoFx.rarity_color(tier), 0.0)])
	p.position = pos
	p.z_index = 8
	parent.add_child(p)
	p.emitting = true
	p.get_tree().create_timer(1.0).timeout.connect(p.queue_free)
	CasinoFx.burst(parent, pos, CasinoFx.rarity_color(tier), maxi(6, amount / 2), 110.0, 0.9)


## Gold flakes drifting down (legendary) or red embers rising (mythic).
static func flakes(parent: Node, area: Rect2, tier: String, seconds := 2.6) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	var rising := tier == "mythic"
	p.amount = 120 if rising else 70
	p.lifetime = 2.4
	p.preprocess = 0.6
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(area.size.x / 2.0, 4)
	p.position = Vector2(area.get_center().x, area.end.y if rising else area.position.y)
	p.direction = Vector2.UP if rising else Vector2.DOWN
	p.spread = 25.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 70.0 if rising else 45.0
	p.gravity = Vector2(0, -30) if rising else Vector2(0, 26)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.5
	p.color_ramp = grad([0.0, 0.5, 1.0], [GLOW[tier], CasinoFx.rarity_color(tier), Color(SHADOW[tier], 0.0)])
	p.z_index = 6
	parent.add_child(p)
	p.emitting = true
	p.get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.emitting = false
			p.get_tree().create_timer(p.lifetime).timeout.connect(p.queue_free)
	)
	return p


## A ring that grows and fades.
static func ring(parent: Node, pos: Vector2, color: Color, radius := 40.0, seconds := 0.45) -> void:
	var r := Ring.new()
	r.color = color
	r.position = pos
	r.z_index = 7
	parent.add_child(r)
	var tw := r.create_tween().set_parallel(true)
	tw.tween_property(r, "radius", radius, seconds).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(r, "width", 0.5, seconds)
	tw.tween_property(r, "modulate:a", 0.0, seconds).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(r.queue_free)


## A vertical beam of light at x from the top down to `bottom`. It fades itself out after
## `seconds` (0 keeps it until freed).
static func beam(parent: Node, x: float, bottom: float, tier: String, width := 16.0, seconds := 0.6) -> Beam:
	var b := Beam.new()
	b.color = CasinoFx.rarity_color(tier)
	b.core = GLOW.get(tier, Palette.CREAM)
	b.position = Vector2(x, 0)
	b.height = bottom
	b.z_index = 5
	parent.add_child(b)
	var tw := b.create_tween()
	tw.tween_property(b, "width", width, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if seconds > 0.0:
		tw.tween_interval(seconds)
		tw.tween_property(b, "width", 0.0, 0.3)
		tw.tween_callback(b.queue_free)
	return b


## Shake a control around where it rests.
static func shake(node: Control, strength := 3.0, seconds := 0.25) -> void:
	if not node.has_meta("rest"):
		node.set_meta("rest", node.position)
	var rest: Vector2 = node.get_meta("rest")
	var tw := node.create_tween()
	var steps := maxi(2, int(seconds / 0.03))
	for i in steps:
		var f := strength * (1.0 - float(i) / steps)
		tw.tween_property(node, "position", rest + Vector2(randf_range(-f, f), randf_range(-f, f)).round(), 0.03)
	tw.tween_property(node, "position", rest, 0.03)


# --- drawn pieces ------------------------------------------------------------------------

class Ring:
	extends Node2D
	var color := Color.WHITE
	var radius := 4.0:
		set(v):
			radius = v
			queue_redraw()
	var width := 3.0

	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, color, width)


class Beam:
	extends Control
	## A column of light, soft at its edges, its core in the rarity's glow step.
	var color := Color.WHITE
	var core := Color.WHITE
	var height := 200.0
	var width := 0.0:
		set(v):
			width = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		material = MachineOverlay.additive()

	func _draw() -> void:
		if width <= 0.5:
			return
		var h := height
		var w := width
		var pts := PackedVector2Array([Vector2(-w, 0), Vector2(w, 0), Vector2(w * 0.7, h), Vector2(-w * 0.7, h)])
		draw_polygon(pts, PackedColorArray([Color(color, 0.0), Color(color, 0.0), Color(color, 0.0), Color(color, 0.0)]))
		for i in 3:
			var k := 1.0 - i * 0.3
			var a := 0.18 + i * 0.12
			var p := PackedVector2Array([Vector2(-w * k, 0), Vector2(w * k, 0), Vector2(w * k * 0.6, h), Vector2(-w * k * 0.6, h)])
			var c := color if i < 2 else core
			draw_polygon(p, PackedColorArray([Color(c, a), Color(c, a), Color(c, 0.0), Color(c, 0.0)]))


class Rays:
	extends Control
	## God rays turning slowly behind the item.
	var color := Color.WHITE
	var _a := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		material = MachineOverlay.additive()

	func _process(delta: float) -> void:
		_a += delta * 0.5
		queue_redraw()

	func _draw() -> void:
		for i in 12:
			var a := _a + TAU * i / 12.0
			var w := 0.09
			var far := 240.0
			var pts := PackedVector2Array([Vector2.ZERO, Vector2(cos(a - w), sin(a - w)) * far, Vector2(cos(a + w), sin(a + w)) * far])
			draw_polygon(pts, PackedColorArray([Color(color, 0.5), Color(color, 0.0), Color(color, 0.0)]))


class Lamp:
	extends Control
	## The lamp over the machine. Off means not this week.
	var on := true:
		set(v):
			on = v
			queue_redraw()

	func _init() -> void:
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
		draw_line(Vector2(20, 0), Vector2(20, 6), MachineOverlay.TRIM, 1.0)
		var shade := PackedVector2Array([Vector2(14, 6), Vector2(26, 6), Vector2(31, 13), Vector2(9, 13)])
		draw_colored_polygon(shade, MachineOverlay.TRIM)
		draw_polyline(shade, MachineOverlay.TRIM_LIT, 1.0)
		if on:
			draw_texture_rect(MachineOverlay.res(MachineOverlay.LIGHT) as Texture2D, Rect2(4, -2, 32, 32), false, Color(Palette.CREAM, 0.6))
			draw_rect(Rect2(17, 13, 6, 2), Palette.CREAM)
		else:
			draw_rect(Rect2(17, 13, 6, 2), Palette.INK)


class Cone:
	extends Control
	## The lamp's cone falling over the machine.
	var x := 240.0

	func _init() -> void:
		size = Vector2(480, 270)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		material = MachineOverlay.additive()

	func _draw() -> void:
		var pts := PackedVector2Array([Vector2(x - 10, 14), Vector2(x + 10, 14), Vector2(x + 170, 236), Vector2(x - 170, 236)])
		var top := Color(Palette.CREAM, 0.12)
		var bottom := Color(Palette.CREAM, 0.0)
		draw_polygon(pts, PackedColorArray([top, top, bottom, bottom]))


class Mouth:
	extends Control
	## A slot mouth: the account's icon sitting on the counter, its name, its real balance,
	## and a brass-rimmed slot with a lamp glow inside and the paper's edge peeking out.
	## The chosen mouth's rim pulses in the lamp's color; the other sits back in the dark.
	const BRASS := Color("c99a4a")
	const BRASS_DARK := Color("6b4a22")
	const LAMP := Color("ffe6c4")
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
	var _poke := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func setup(account_name: String, balance_cents: int, tex: Texture2D) -> void:
		account = account_name
		# The icon at 2x with a 1 px night outline, standing on the counter's lip.
		_icon.size = Vector2(32, 32)
		_icon.position = Vector2(-2, -9)
		_icon.pivot_offset = Vector2(16, 32)
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for off: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2.ZERO]:
			var t := TextureRect.new()
			t.texture = tex
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.size = Vector2(32, 32)
			t.position = off
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if off != Vector2.ZERO:
				t.material = MachineOverlay.silhouette(Palette.NIGHT)
			_icon.add_child(t)
		add_child(_icon)
		_name = MachineOverlay.label(account_name, Palette.MUTED, 16, MachineOverlay.M5X7)
		_name.add_theme_constant_override("outline_size", 0)
		_name.position = Vector2(32, -3)
		add_child(_name)
		_bal = MachineOverlay.label("", Palette.CREAM, 16)
		_bal.add_theme_constant_override("outline_size", 0)
		_bal.position = Vector2(32, 8)
		add_child(_bal)
		show_balance(balance_cents)

	func show_balance(cents: int) -> void:
		balance = cents
		_bal.text = Money.fmt(cents)

	## Roll the painted balance from `from` to `to` (exactly), then squash the icon.
	func roll(from: int, to: int) -> void:
		await CasinoFx.count_up(self, _bal, from, to, show_balance)
		pulse()

	func pulse() -> void:
		var tw := _icon.create_tween()
		tw.tween_property(_icon, "scale", Vector2(1.3, 0.75), 0.06)
		tw.tween_property(_icon, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	## Chosen: the paper noses into the slot and the icon squashes.
	func poke() -> void:
		_poke = 1.0
		pulse()

	func _process(delta: float) -> void:
		_t += delta
		_poke = maxf(0.0, _poke - delta * 3.0)
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var light := MachineOverlay.res(MachineOverlay.LIGHT) as Texture2D
		if selected:
			draw_texture_rect(light, Rect2(-10, -16, size.x + 20, size.y + 30), false, Color(LAMP, 0.10))
		draw_rect(r, Color(MachineOverlay.BODY_DARK, 0.96))
		draw_rect(Rect2(1, 1, size.x - 2, 1), Color(1, 1, 1, 0.05))
		if selected:
			var a := 0.55 + 0.3 * sin(_t * 4.0)
			draw_rect(r.grow(1), Color(LAMP, a * 0.3), false, 3.0)
			draw_rect(r, Color(LAMP, a), false, 1.0)
		else:
			draw_rect(r, Color(MachineOverlay.TRIM, 0.6), false, 1.0)
		# The slot: a brass rim, a black throat with lamp light inside, the paper's edge.
		var slot := Rect2(size.x - 16, 5, 6, size.y - 10)
		draw_rect(slot.grow(2), BRASS_DARK)
		draw_rect(slot.grow(1), BRASS if selected else BRASS.darkened(0.35))
		draw_rect(Rect2(slot.position.x - 1, slot.position.y - 1, slot.size.x + 2, 1), BRASS.lightened(0.4) if selected else BRASS)
		draw_rect(slot, Color(0, 0, 0))
		var glow_a := (0.35 + 0.15 * sin(_t * 3.0)) if selected else 0.08
		for i in int(slot.size.y):
			var k := 1.0 - float(i) / slot.size.y
			draw_rect(Rect2(slot.position.x + 1, slot.end.y - 1 - i, slot.size.x - 2, 1), Color(LAMP, glow_a * k * k))
		if selected:
			# A bill's edge waiting in the throat; it noses in when the mouth is chosen.
			var dip := roundf(_poke * 4.0)
			draw_rect(Rect2(slot.position.x + 1, slot.position.y - 3 + dip, slot.size.x - 2, 3), Palette.CREAM)
			draw_rect(Rect2(slot.position.x + 1, slot.position.y - 3 + dip, slot.size.x - 2, 1), Palette.CREAM.darkened(0.15))
