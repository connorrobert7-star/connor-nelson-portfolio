class_name DrawOverlay
extends Overlay
## The weekly draw, up close, in the back room.
##
## The drum turns over a ritual circle with every ticket for the week inside it: the owner's
## in cream (one for every $5 that landed in an own account this week), the cultists' in grey
## (the rest of the hundred). The owner's tickets also hang on a line across the top, so the
## count is something you can see, and the plaque on the dais says it as odds: "23 of 100".
## Seven candles burn down the week to the draw day on the slate. The board on the right
## holds last week's ten winning tickets in prize order (one gold, two purple, three blue,
## four grey): cream ones carry the piece the owner won, grey ones the cultist who won.
##
## The first time a new result is seen, the drum spins and the ten tickets fly to their hooks
## one by one. Tap the drum to turn it; tap a ticket to see what it is; tap the floor to leave.
## Cosmetics only: nothing here moves money. Closes with null.

const PACKS := "res://art/packs/"
const SUMMON := PACKS + "srzolda-magic-summons/green_idle-Sheet.png"
const CANDLES := PACKS + "vk-candles-with-eyes/candles_with_eyes.png"
const NINJA := PACKS + "ninja-adventure/Actor/Character/%s/SpriteSheet.png"
const CULTISTS := ["Monk", "Skeleton", "MaskFrog", "Spirit", "SorcererBlack", "MaskRacoon",
	"Shaman", "Vampire", "Monk2", "NinjaMasked", "OldMan3", "Tengu2"]
const PRIEST := "NinjaMageBlack"
const CHOIR := ["Monk", "SorcererBlack", "Skeleton", "Shaman", "MaskFrog"]

const SND_OPEN := PACKS + "kenney-casino-audio/Audio/cards-pack-take-out-1.ogg"
const SND_CLOSE := PACKS + "kenney-interface-sounds/Audio/close_002.ogg"
const SND_RATCHET := PACKS + "freesound-cc0-picks/376195_toy_ratchet_wav.mp3"
const SND_PAPER := PACKS + "kenney-casino-audio/Audio/card-place-%d.ogg"
const SND_SLIDE := PACKS + "kenney-casino-audio/Audio/card-slide-%d.ogg"
const SND_THUD := PACKS + "kenney-impact-sounds/Audio/impactSoft_medium_00%d.ogg"
const SND_BELL := PACKS + "kenney-impact-sounds/Audio/impactBell_heavy_001.ogg"
const SND_VOICE := PACKS + "ninja-adventure/Audio/Sounds/Voice/Voice%d.ogg"
const SND_CHANT := PACKS + "freesound-cc0-picks/669797_Dark_Chanting_mp3.mp3"
const SND_GLINT := PACKS + "kenney-interface-sounds/Audio/glass_001.ogg"

const CREAM := Color("f6ead2")
const GREY_TICKET := Color("6a6070")
const BRASS := Color("a07a3a")
const BRASS_LIT := Color("f0cf8a")

# Layout, in overlay space (480x270).
const HUB := Vector2(166, 110)
const RADIUS := 56.0
const DAIS := Rect2(94, 180, 144, 14)
const LINE := Rect2(12, 12, 284, 30)
const BOARD := Rect2(306, 8, 166, 204)
const CANDLE0 := Vector2(16, 230)
const SLATE := Rect2(166, 222, 76, 42)
const PRIEST_FEET := Vector2(250, 178)
const SHOWN_MAX := 120

## Session memory of which week's result has been shown (plain data).
static var _seen_week := ""

## Where it is, for the tour: open, look, drawing, closed.
var moment := "open"
var info: Dictionary = {}  # state.casino.draw
var entries := 0
var total := 100
## Last week's ten winning tickets in prize order: [{tier, mine, item}]
var winners: Array[Dictionary] = []

var _items: Dictionary = {}
var _shader: Shader
var _root := Control.new()
var _room: BackRoom
var _drum: Drum
var _line: Clothesline
var _board: Board
var _tickets: Array[BoardTicket] = []
var _priest := Sprite2D.new()
var _priest_holder := Node2D.new()
var _choir: Array[Sprite2D] = []
var _fx := Control.new()
var _busy := false
var _hurry := false
var _t := 0.0


func _ready() -> void:
	_shader = BookOverlay.flat_shader()
	for n: Control in [_root, _fx]:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n.size = Vector2(480, 270)
	add_child(_root)
	_room = BackRoom.new()
	_root.add_child(_room)
	_drum = Drum.new()
	_root.add_child(_drum)
	_root.add_child(_priest_holder)
	_priest.texture = _region(NINJA % PRIEST, Rect2(32, 0, 16, 16))
	_priest.offset = Vector2(0, -8)
	_priest_holder.position = PRIEST_FEET
	_priest_holder.scale = Vector2(2, 2)
	_priest_holder.add_child(_priest)
	_line = Clothesline.new()
	_root.add_child(_line)
	_board = Board.new()
	_root.add_child(_board)
	_build_choir()
	_root.add_child(_fx)
	_root.modulate.a = 0.0
	_root.create_tween().tween_property(_root, "modulate:a", 1.0, 0.18)
	BookOverlay.sound(SND_OPEN, 1.0, -6.0)
	BookOverlay.segment(self, SND_CHANT, 60.0, -22.0)
	_items = await BookOverlay.load_catalog()
	if Game.state.is_empty():
		await Game.refresh()
	if not is_inside_tree():
		return
	_read()
	_dress()
	moment = "look"
	var last: Variant = info.get("last")
	if last is Dictionary and str(last.get("week", "")) != _seen_week:
		_seen_week = str(last.week)
		await _drawing()


func _read() -> void:
	info = Game.state.get("casino", {}).get("draw", {})
	entries = int(info.get("entries", 0))
	total = maxi(int(info.get("tickets_total", 100)), 1)
	winners.clear()
	var prizes: Array = info.get("prizes", ["legendary", "epic", "epic", "rare", "rare", "rare", "common", "common", "common", "common"])
	var last: Variant = info.get("last")
	var won: Array = (last as Dictionary).get("won", []).duplicate() if last is Dictionary else []
	for tier: Variant in prizes:
		var slot := {"tier": str(tier), "mine": false, "item": {}, "drawn": last is Dictionary}
		for i in won.size():
			var it: Dictionary = _items.get(str(won[i]), {})
			if str(it.get("tier", "")) == str(tier):
				slot.mine = true
				slot.item = it
				won.remove_at(i)
				break
		winners.append(slot)


func _dress() -> void:
	_drum.set_counts(entries, total)
	_line.count = entries
	_line.queue_redraw()
	var plaque := "%d of %d" % [entries, total]
	BookOverlay.words(_root, plaque, DAIS.get_center() + Vector2(0, 1), CREAM, 16).name = "Plaque"
	_room.dress(str(Game.state.get("today", "")), str(info.get("week_start", "")), str(info.get("draws_on", "")))
	_slate()
	_hang_board(false)


## The slate at the end of the candles: the draw day.
func _slate() -> void:
	var on := str(info.get("draws_on", ""))
	var day := _weekday(on)
	BookOverlay.words(_root, day, SLATE.get_center() + Vector2(0, -7), CREAM, 20, BookOverlay.FONT_BIG)
	BookOverlay.words(_root, _month_day(on), SLATE.get_center() + Vector2(0, 9), Color(Palette.MUTED, 0.9), 16)


func _hang_board(empty: bool) -> void:
	for t in _tickets:
		t.queue_free()
	_tickets.clear()
	var last: Variant = info.get("last")
	if last is Dictionary:
		var held := int(last.get("entries", 0))
		var of := maxi(100, held)
		BookOverlay.words(_board, "%d of %d" % [held, of], Vector2(BOARD.size.x / 2.0, 23), Color(CREAM, 0.7), 16).name = "Held"
	for i in winners.size():
		var t := BoardTicket.new()
		t.slot = winners[i]
		t.position = Board.hook(i) + Vector2(-11, 4)
		t.cultist = CULTISTS[i % CULTISTS.size()]
		_board.add_child(t)
		t.setup(_icon_for(winners[i]), _shader)
		t.visible = winners[i].drawn and not empty
		_tickets.append(t)


func _icon_for(slot: Dictionary) -> Texture2D:
	if slot.mine and not (slot.item as Dictionary).is_empty():
		return BookOverlay.icon_of(slot.item)
	return null


func _build_choir() -> void:
	for i in CHOIR.size():
		var s := Sprite2D.new()
		s.texture = _region(NINJA % CHOIR[i], Rect2(0, 0, 16, 16))
		s.offset = Vector2(0, -8)
		s.position = Vector2(300 + i * 30, 264)
		s.scale = Vector2(2, 2)
		s.modulate = Color(0.42, 0.38, 0.5)
		_root.add_child(s)
		_choir.append(s)


static func _region(path: String, rect: Rect2) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = load(path) as Texture2D
	a.region = rect
	a.filter_clip = true
	return a


# --- for the tour --------------------------------------------------------------------

func drum_rect() -> Rect2:
	return Rect2(HUB - Vector2(RADIUS, RADIUS), Vector2(RADIUS, RADIUS) * 2.0)


func board_ticket(i: int) -> Control:
	return _tickets[i] if i < _tickets.size() else null


func line_count() -> int:
	return _line.count


func spin_speed() -> float:
	return _drum.speed


# --- the drawing -----------------------------------------------------------------------

## Last week's result arriving: the drum spins up, and ten tickets fly out to the hooks in
## prize order. The owner's come out cream and show what they won.
func _drawing() -> void:
	_busy = true
	moment = "drawing"
	_hurry = false
	for t in _tickets:
		t.visible = false
	BookOverlay.sound(SND_BELL, 0.8, -8.0)
	BookOverlay.segment(self, SND_RATCHET, 1.6, -6.0)
	_drum.kick(4.0)
	await _wait(0.9)
	for i in _tickets.size():
		if not is_inside_tree():
			return
		var t := _tickets[i]
		var to := _board.position + t.position
		var flyer := BoardTicket.new()
		flyer.slot = t.slot
		flyer.cultist = t.cultist
		flyer.position = HUB + Vector2(-11, -RADIUS - 10)
		flyer.scale = Vector2(0.4, 0.4)
		flyer.pivot_offset = Vector2(11, 15)
		_fx.add_child(flyer)
		flyer.setup(_icon_for(t.slot), _shader)
		_drum.kick(1.5)
		BookOverlay.sound(SND_SLIDE % (i % 4 + 1), randf_range(0.95, 1.1), -6.0)
		var from := flyer.position
		var seconds := 0.12 if _hurry else 0.32
		var tw := flyer.create_tween().set_parallel()
		tw.tween_method(func(k: float) -> void:
			flyer.position = from.lerp(to, k) + Vector2(0, -sin(k * PI) * 40.0)
			flyer.rotation = sin(k * PI * 2.0) * 0.4, 0.0, 1.0, seconds)
		tw.tween_property(flyer, "scale", Vector2.ONE, seconds)
		await tw.finished
		flyer.queue_free()
		t.visible = true
		t.swing(1.0)
		BookOverlay.sound(SND_PAPER % (i % 4 + 1), 1.0, -4.0)
		if t.slot.mine:
			await _won(t)
		else:
			t.hop()
			BookOverlay.sound(SND_VOICE % (i % 10 + 1), randf_range(0.7, 0.9), -14.0)
			await _wait(0.12 if _hurry else 0.28)
	_busy = false
	moment = "look"


## One of the owner's tickets came up: its piece pops in its rarity's light.
func _won(t: BoardTicket) -> void:
	var tier := str(t.slot.tier)
	var col: Color = Palette.RARITY.get(tier, CREAM)
	var at := _board.position + t.position + Vector2(11, 14)
	Sfx.play("reveal_" + tier)
	CasinoFx.flash(self, col, 0.25 + 0.1 * BookOverlay.TIERS.find(tier), 0.25)
	CasinoFx.burst(_fx, at, col, 16 + 10 * BookOverlay.TIERS.find(tier), 120.0, 0.7)
	BookOverlay.shake(_root, 1.0 + BookOverlay.TIERS.find(tier), 0.2)
	t.pop()
	for s in _choir:
		var tw := s.create_tween()
		tw.tween_property(s, "position:y", 258.0, 0.08)
		tw.tween_property(s, "position:y", 264.0, 0.14)
	var label := str((t.slot.item as Dictionary).get("name", ""))
	if label != "":
		CasinoFx.float_text(_fx, at + Vector2(0, -22), label, col.lightened(0.2), 8)
	await _wait(0.25 if _hurry else 0.7)


func _wait(seconds: float) -> void:
	var held := 0.0
	while held < seconds and is_inside_tree():
		await get_tree().process_frame
		held += get_process_delta_time() * (3.0 if _hurry else 1.0)


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
	if _busy:
		_hurry = true
		_drum.kick(0.6)
		return
	if moment == "open":
		# Still laying the room out: a quick second tap turns the drum, it never closes.
		_drum.kick(0.6)
		BookOverlay.sound(SND_THUD % (randi() % 3), 1.4, -16.0)
		return
	if at.distance_to(HUB) <= RADIUS + 6 or Rect2(PRIEST_FEET - Vector2(16, 34), Vector2(32, 36)).has_point(at):
		_spin()
		return
	for t in _tickets:
		if t.visible and t.get_global_rect().grow(2).has_point(at):
			_poke(t)
			return
	if LINE.has_point(at):
		var i := _line.ticket_at(at)
		if i >= 0:
			_line.swing(i)
			BookOverlay.sound(SND_PAPER % (i % 4 + 1), 1.3, -10.0)
			return
	if BOARD.has_point(at) or DAIS.grow(4).has_point(at) or SLATE.has_point(at) or _t < 0.35:
		# (So soon after opening, it's the tail of the double tap on the drum: a thud, no close.)
		BookOverlay.sound(SND_THUD % (randi() % 3), 1.4, -16.0)
		return
	_close()


## Turn the drum: the priest cranks it, the tickets tumble.
func _spin() -> void:
	_drum.kick(3.0)
	BookOverlay.segment(self, SND_RATCHET, 1.1, -6.0, randf_range(0.95, 1.1))
	var tw := _priest_holder.create_tween()
	for k in 3:
		tw.tween_property(_priest_holder, "position", PRIEST_FEET + Vector2(-2, -3), 0.12)
		tw.tween_property(_priest_holder, "position", PRIEST_FEET, 0.12)


func _poke(t: BoardTicket) -> void:
	t.swing(0.8)
	if t.slot.mine:
		t.pop()
		var col: Color = Palette.RARITY.get(str(t.slot.tier), CREAM)
		var at := t.global_position + Vector2(11, -6)
		CasinoFx.float_text(_fx, at, str((t.slot.item as Dictionary).get("name", "")), col.lightened(0.2), 8)
		BookOverlay.sound(SND_GLINT, 1.0 + 0.1 * BookOverlay.TIERS.find(str(t.slot.tier)), -8.0)
	else:
		t.hop()
		BookOverlay.sound(SND_VOICE % (randi() % 10 + 1), randf_range(0.7, 0.9), -12.0)


func _close() -> void:
	if moment == "closed":
		return
	moment = "closed"
	BookOverlay.sound(SND_CLOSE, 1.0, -8.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	await tw.finished
	close(null)


func _process(delta: float) -> void:
	_t += delta
	# The choir sways, half on each beat, faster while the drum turns.
	var bpm := 84.0 + _drum.speed * 14.0
	var beat := _t * bpm / 60.0
	for i in _choir.size():
		var up := int(beat + (i % 2) * 0.5) % 2 == 0
		_choir[i].position.y = 264.0 - (1.0 if up else 0.0)
	_priest.rotation = sin(_t * 2.0) * 0.03


# --- dates ---------------------------------------------------------------------------------

static func _date(iso: String) -> Dictionary:
	var p := iso.split("-")
	if p.size() < 3:
		return {}
	return {"year": int(p[0]), "month": int(p[1]), "day": int(p[2])}


static func _weekday(iso: String) -> String:
	var d := _date(iso)
	if d.is_empty():
		return ""
	var unix := Time.get_unix_time_from_datetime_dict({"year": d.year, "month": d.month, "day": d.day, "hour": 12})
	var wd: int = Time.get_datetime_dict_from_unix_time(unix).weekday
	return ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][wd]


static func _month_day(iso: String) -> String:
	const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var d := _date(iso)
	return "" if d.is_empty() else "%s %d" % [MONTHS[int(d.month) - 1], int(d.day)]


static func _days_between(a: String, b: String) -> int:
	var da := _date(a)
	var db := _date(b)
	if da.is_empty() or db.is_empty():
		return 0
	var ua := Time.get_unix_time_from_datetime_dict({"year": da.year, "month": da.month, "day": da.day, "hour": 12})
	var ub := Time.get_unix_time_from_datetime_dict({"year": db.year, "month": db.month, "day": db.day, "hour": 12})
	return roundi((ub - ua) / 86400.0)


# --- pieces of the room ----------------------------------------------------------------------

## The back room: dark stone, the ritual circle under the drum, the dais, the seven candles
## of the week (spent ones burnt down, today's lit, the rest waiting) and the slate.
class BackRoom extends Control:
	var _circle := Sprite2D.new()
	var _frames: Array[Texture2D] = []
	var _flames: Array[TextureRect] = []
	var _today_index := 0
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(480, 270)

	func _ready() -> void:
		for i in 43:
			_frames.append(DrawOverlay._region(DrawOverlay.SUMMON, Rect2(i * 64, 0, 64, 64)))
		_circle.texture = _frames[0]
		_circle.position = Vector2(DrawOverlay.HUB.x, 202)
		_circle.scale = Vector2(2.6, 0.62)
		_circle.modulate = Color(1, 1, 1, 0.8)
		add_child(_circle)
		BookOverlay.glow(self, DrawOverlay.HUB + Vector2(0, -10), Color("ffe6c4"), 150.0, 0.13)
		BookOverlay.glow(self, Vector2(DrawOverlay.HUB.x, 200), Palette.BILE, 70.0, 0.12)

	## Today's place in the week, from the dates /state gives.
	func dress(today: String, week_start: String, draws_on: String) -> void:
		_today_index = clampi(DrawOverlay._days_between(week_start, today), 0, 6)
		for f in _flames:
			f.queue_free()
		_flames.clear()
		for c in get_children():
			if c is TextureRect and c.has_meta("candle"):
				c.queue_free()
		for i in 7:
			var region: Rect2
			var top_y := 0.0
			if i < _today_index:
				region = Rect2(36, 23, 18, 18)  # burnt down to a stub, out
				top_y = 14.0
			elif i == _today_index:
				region = Rect2(18, 9, 18, 32)  # lit
			else:
				region = Rect2(18, 17, 18, 24)  # waiting
				top_y = 8.0
			var r := TextureRect.new()
			r.texture = DrawOverlay._region(DrawOverlay.CANDLES, region)
			r.position = DrawOverlay.CANDLE0 + Vector2(i * 20, top_y)
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			r.set_meta("candle", true)
			add_child(r)
			if i == _today_index:
				_flames.append(BookOverlay.glow(self, r.position + Vector2(9, 5), Color("ffb98a"), 26.0, 0.5))
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		_circle.texture = _frames[int(_t * 10.0) % _frames.size()]
		for f in _flames:
			f.modulate.a = 0.45 + 0.08 * sin(_t * 9.0) + 0.05 * sin(_t * 21.0)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("100b14"))
		# Stone courses on the back wall.
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		var y := 0.0
		var row := 0
		while y < 176.0:
			draw_rect(Rect2(0, y, 480, 1), Color("0a070d"))
			var x := -float(row % 2) * 14.0
			while x < 480.0:
				draw_rect(Rect2(x, y + 1, 1, 15), Color("0a070d"))
				draw_rect(Rect2(x + 1, y + 1, 27, 1), Color("1b1422").lerp(Color("231a2b"), rng.randf()))
				x += 28.0
			y += 16.0
			row += 1
		# The floor.
		draw_rect(Rect2(0, 176, 480, 94), Color("0d0910"))
		draw_rect(Rect2(0, 176, 480, 1), Color("2a2030"))
		# A step for the priest at the crank.
		draw_rect(Rect2(DrawOverlay.PRIEST_FEET + Vector2(-18, 0), Vector2(34, 6)), Color("2a2230"))
		draw_rect(Rect2(DrawOverlay.PRIEST_FEET + Vector2(-18, 0), Vector2(34, 1)), Color("4a3e55"))
		# The slate for the draw day.
		var s := DrawOverlay.SLATE
		draw_rect(s.grow(2), Color("3a2218"))
		draw_rect(s, Color("1e2422"))
		draw_rect(Rect2(s.position, Vector2(s.size.x, 1)), Color("2c3532"))
		draw_line(s.position + Vector2(s.size.x / 2.0, -2), s.position + Vector2(s.size.x / 2.0, -10), Color("6b4a22"), 1.0)
		# Chalk ticks under the candles: one for each day of the week gone.
		for i in 7:
			var base := DrawOverlay.CANDLE0 + Vector2(i * 20 + 9, 36)
			if i < _today_index:
				draw_rect(Rect2(base + Vector2(-3, 0), Vector2(6, 1)), Color(1, 1, 1, 0.25))
		# A line of chalk from the last candle to the slate.
		var a := DrawOverlay.CANDLE0 + Vector2(7 * 20 - 2, 30)
		var b := Vector2(s.position.x - 4, 30 + DrawOverlay.CANDLE0.y)
		var x2 := a.x
		while x2 < b.x:
			draw_rect(Rect2(x2, a.y, 2, 1), Color(1, 1, 1, 0.22))
			x2 += 4.0


## The drum: a brass wire cage on a horizontal axle with every ticket of the week tumbling in
## it. Cream for the owner's, grey for the cultists'.
class Drum extends Control:
	var speed := 0.0
	var spin := 0.0
	var _cream := 0
	var _all := 0
	var _tickets: Array[Dictionary] = []  # {rest: Vector2, a: float, r: float, rot: float, mine: bool, w: float}
	var _t := 0.0
	var _agitation := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(480, 270)

	func set_counts(mine: int, total: int) -> void:
		var shown := mini(total, DrawOverlay.SHOWN_MAX)
		_all = shown
		_cream = clampi(roundi(float(mine) / maxf(1.0, total) * shown), 1 if mine > 0 else 0, shown)
		_tickets.clear()
		var rng := RandomNumberGenerator.new()
		rng.seed = 21
		var hub := DrawOverlay.HUB
		var r := DrawOverlay.RADIUS - 6.0
		for i in shown:
			# A heap in the bottom of the drum.
			var p := Vector2.ZERO
			for tries in 20:
				p = Vector2(rng.randf_range(-r, r), rng.randf_range(r * 0.15, r))
				if p.length() < r and p.y > r * 0.15 + absf(p.x) * 0.1:
					break
			_tickets.append({
				"rest": hub + p, "a": rng.randf() * TAU, "r": rng.randf_range(8.0, r),
				"rot": rng.randf_range(-0.8, 0.8), "mine": i < _cream, "w": rng.randf_range(0.7, 1.4),
			})
		# Cream tickets mixed through the heap, not stacked in one place.
		_tickets.shuffle()

	func kick(strength: float) -> void:
		speed = maxf(speed, strength)

	func _process(delta: float) -> void:
		_t += delta
		speed = move_toward(speed, 0.25, delta * 1.1)
		spin += delta * speed
		_agitation = move_toward(_agitation, clampf((speed - 0.4) / 2.0, 0.0, 1.0), delta * 3.0)
		queue_redraw()

	func _draw() -> void:
		var hub := DrawOverlay.HUB
		var rad := DrawOverlay.RADIUS
		var brass := DrawOverlay.BRASS
		var lit := DrawOverlay.BRASS_LIT
		# The dais, over the ritual circle, with a plate for the odds.
		var d := DrawOverlay.DAIS
		draw_rect(Rect2(d.position + Vector2(-4, d.size.y - 2), Vector2(d.size.x + 8, 6)), Color("17121c"))
		draw_rect(d, Color("2a2230"))
		draw_rect(Rect2(d.position, Vector2(d.size.x, 1)), Color("4a3e55"))
		draw_rect(Rect2(d.get_center() - Vector2(30, 6), Vector2(60, 12)), Color("120d16"))
		draw_rect(Rect2(d.get_center() - Vector2(30, 6), Vector2(60, 1)), brass)
		draw_rect(Rect2(d.get_center() + Vector2(-30, 5), Vector2(60, 1)), Color("5a3f20"))
		# The legs: an A-frame each side up to the axle.
		for side: int in [-1, 1]:
			var top := hub + Vector2(side * (rad + 6), 0)
			draw_line(top, Vector2(hub.x + side * (rad - 10), DrawOverlay.DAIS.position.y), Color("3a2218"), 3.0)
			draw_line(top, Vector2(hub.x + side * (rad + 22), DrawOverlay.DAIS.position.y), Color("3a2218"), 3.0)
			draw_line(top, Vector2(hub.x + side * (rad - 10), DrawOverlay.DAIS.position.y), Color("5c3626"), 1.0)
			draw_rect(Rect2(top - Vector2(3, 3), Vector2(6, 6)), brass)
			draw_rect(Rect2(top - Vector2(2, 3), Vector2(3, 1)), lit)
		# The inside of the cage, dark, so the tickets read against it.
		_disc(hub, rad, Color(0.06, 0.03, 0.07, 0.92))
		# The back wires (dim).
		for k in 6:
			var ry := cos(spin + k * PI / 6.0) * rad
			if ry < 0.0:
				_ellipse(hub, rad, absf(ry), Color(0.55, 0.42, 0.22, 0.35))
		# The tickets.
		for tk: Dictionary in _tickets:
			var orbit: Vector2 = hub + Vector2(cos(tk.a + spin * tk.w * 2.0), sin(tk.a + spin * tk.w * 2.0) * 0.85) * tk.r
			var p: Vector2 = (tk.rest as Vector2).lerp(orbit, _agitation)
			var rot: float = tk.rot + spin * tk.w * _agitation * 3.0
			var c := DrawOverlay.CREAM if tk.mine else DrawOverlay.GREY_TICKET
			draw_set_transform(p.round(), rot, Vector2.ONE)
			draw_rect(Rect2(-3, -1.5, 6, 3), c)
			if tk.mine:
				draw_rect(Rect2(-3, -1.5, 6, 1), Color.WHITE)
			else:
				draw_rect(Rect2(-3, 0.5, 6, 1), c.darkened(0.3))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# The front wires.
		for k in 6:
			var ry := cos(spin + k * PI / 6.0) * rad
			if ry >= 0.0:
				_ellipse(hub, rad, ry, Color(0.82, 0.62, 0.32, 0.45 + 0.4 * ry / rad))
		_ring(hub, rad, Color("c99a4a"))
		_ring(hub, rad + 1.0, Color("5a3f20"))
		_ring(hub, rad - 1.0, Color(lit, 0.35))
		# The hatch on top, where tickets come out.
		draw_rect(Rect2(hub + Vector2(-8, -rad - 3), Vector2(16, 5)), brass)
		draw_rect(Rect2(hub + Vector2(-8, -rad - 3), Vector2(16, 1)), lit)
		# The axle and the crank the priest turns.
		var crank := hub + Vector2(rad + 14, 0)
		draw_line(hub + Vector2(rad + 6, 0), crank, Color("6b4a22"), 2.0)
		var arm := crank + Vector2.from_angle(spin * 2.0) * 9.0
		draw_line(crank, arm, Color("c99a4a"), 2.0)
		draw_rect(Rect2(arm - Vector2(2, 2), Vector2(4, 4)), Color("e8dcc4"))
		draw_rect(Rect2(hub - Vector2(4, 4), Vector2(8, 8)), Color("c99a4a"))
		draw_rect(Rect2(hub - Vector2(4, 4), Vector2(4, 1)), lit)

	func _disc(c: Vector2, r: float, color: Color) -> void:
		for y in range(-int(r), int(r) + 1):
			var half := floorf(sqrt(maxf(0.0, r * r - y * y)))
			draw_rect(Rect2(c.x - half, c.y + y, half * 2.0 + 1.0, 1), color)

	func _ring(c: Vector2, r: float, color: Color) -> void:
		var steps := int(r * 7.0)
		for i in steps:
			var a := TAU * i / steps
			draw_rect(Rect2((c + Vector2(cos(a), sin(a)) * r).floor(), Vector2.ONE), color)

	func _ellipse(c: Vector2, rx: float, ry: float, color: Color) -> void:
		var steps := int(maxf(rx, ry) * 6.0) + 4
		for i in steps:
			var a := TAU * i / steps
			draw_rect(Rect2((c + Vector2(cos(a) * rx, sin(a) * ry)).floor(), Vector2.ONE), color)


## The owner's tickets this week, pegged on a line across the top: one per $5 landed.
## Past twenty they're bundled in tens with a band.
class Clothesline extends Control:
	var count := 0
	var _swing: Dictionary = {}  # index -> amount
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(480, 270)

	func swing(i: int) -> void:
		_swing[i] = 1.0

	## [{x, bundle}] for each ticket or bundle on the line.
	func layout() -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		var bundles := count / 10 if count > 40 else 0
		var singles := count - bundles * 10
		var n := bundles + singles
		if n == 0:
			return out
		var line := DrawOverlay.LINE
		var pitch := clampf((line.size.x - 20.0) / n, 6.0, 13.0)
		var x := line.position.x + 10.0
		for i in bundles:
			out.append({"x": x, "bundle": true})
			x += pitch
		for i in singles:
			out.append({"x": x, "bundle": false})
			x += pitch
		return out

	func ticket_at(at: Vector2) -> int:
		var l := layout()
		for i in l.size():
			if Rect2(l[i].x - 1, _sag(l[i].x) + 2, 11, 15).has_point(at):
				return i
		return -1

	func _sag(x: float) -> float:
		var line := DrawOverlay.LINE
		var k := (x - line.position.x) / line.size.x
		return line.position.y + sin(k * PI) * 5.0

	func _process(delta: float) -> void:
		_t += delta
		for k: int in _swing.keys():
			_swing[k] = move_toward(_swing[k], 0.0, delta * 0.8)
		queue_redraw()

	func _draw() -> void:
		var line := DrawOverlay.LINE
		# Two nails and the string between them.
		var prev := Vector2(line.position.x, _sag(line.position.x))
		var x := line.position.x
		while x <= line.end.x:
			var p := Vector2(x, _sag(x))
			draw_line(prev, p, Color("8a7a66"), 1.0)
			prev = p
			x += 4.0
		for nx: float in [line.position.x, line.end.x]:
			draw_rect(Rect2(nx - 2, _sag(nx) - 2, 4, 4), Color("5a5460"))
		var l := layout()
		for i in l.size():
			var tx: float = l[i].x
			var top := _sag(tx + 4.5)
			var sw: float = _swing.get(i, 0.0)
			var ang := sin(_t * 1.3 + i * 0.7) * 0.04 + sin(_t * 14.0) * 0.35 * sw
			draw_set_transform(Vector2(tx + 4.5, top), ang, Vector2.ONE)
			var bundle: bool = l[i].bundle
			if bundle:
				for k in 3:
					draw_rect(Rect2(-4.5 + k, 2 + k, 9, 13), DrawOverlay.CREAM.darkened(0.25 - k * 0.1))
			draw_rect(Rect2(-4.5, 2, 9, 13), DrawOverlay.CREAM)
			draw_rect(Rect2(-4.5, 2, 9, 1), Color.WHITE)
			# Perforations and a stamped eye.
			for k in 4:
				draw_rect(Rect2(-4.5 + k * 2 + 1, 12, 1, 1), DrawOverlay.CREAM.darkened(0.35))
			draw_rect(Rect2(-2.5, 6, 5, 3), Color("3a2a1c"))
			draw_rect(Rect2(-0.5, 6, 1, 3), DrawOverlay.CREAM)
			if bundle:
				draw_rect(Rect2(-4.5, 9, 9, 2), DrawOverlay.BRASS)
				BookOverlay.draw_digits(self, "10", Vector2(-3.5, 15.5), DrawOverlay.CREAM)
			# The peg.
			draw_rect(Rect2(-1.5, -1, 3, 5), Color("6b4a22"))
			draw_rect(Rect2(-1.5, -1, 3, 1), Color("a07a3a"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Last week's board: ten hooks in a pyramid, one gold at the top down to four grey, each with
## its prize's gem.
class Board extends Control:
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		position = DrawOverlay.BOARD.position
		size = DrawOverlay.BOARD.size

	func _ready() -> void:
		BookOverlay.words(self, "Last week", Vector2(size.x / 2.0, 12), Color(Palette.MUTED, 0.95), 16)

	## Where hook i hangs, in board space.
	static func hook(i: int) -> Vector2:
		var row := 0
		var first := 0
		while i >= first + row + 1:
			first += row + 1
			row += 1
		var k := i - first
		return Vector2(DrawOverlay.BOARD.size.x / 2.0 + (k - row / 2.0) * 38.0, 40.0 + row * 42.0)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2(3, 4), size), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(Vector2.ZERO, size), Color("2a1a14"))
		draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), Color("21140f"))
		var y := 8.0
		while y < size.y - 4:
			draw_rect(Rect2(4, y, size.x - 8, 1), Color("1a100c"))
			y += 11.0
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 1)), Color("4a3226"))
		for i in 10:
			var h := hook(i)
			var tier: String = ["legendary", "epic", "epic", "rare", "rare", "rare", "common", "common", "common", "common"][i]
			var col: Color = Palette.RARITY[tier]
			# The prize's gem over the hook, then the brass hook.
			var pulse := 0.7 + 0.3 * sin(_t * 2.0 + i)
			draw_rect(Rect2(h + Vector2(-2, -9), Vector2(4, 4)), col.lerp(Color.WHITE, 0.15 * pulse))
			draw_rect(Rect2(h + Vector2(-2, -9), Vector2(2, 1)), Color(1, 1, 1, 0.7))
			draw_rect(Rect2(h + Vector2(-1, -4), Vector2(2, 5)), DrawOverlay.BRASS)
			draw_rect(Rect2(h + Vector2(-1, 1), Vector2(4, 1)), DrawOverlay.BRASS)
			# An empty hook's outline, where a ticket will hang.
			var r := Rect2(h + Vector2(-11, 4), Vector2(22, 30))
			for k in range(0, 22, 3):
				draw_rect(Rect2(r.position + Vector2(k, 0), Vector2(1, 1)), Color(1, 1, 1, 0.08))
				draw_rect(Rect2(r.position + Vector2(k, 29), Vector2(1, 1)), Color(1, 1, 1, 0.08))


## A winning ticket on the board: cream with the owner's piece, or grey with the cultist who
## won it.
class BoardTicket extends Control:
	var slot: Dictionary = {}
	var cultist := "Monk"
	var _swing := 0.0
	var _t := 0.0
	var _home := Vector2.ZERO
	var _art: Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(22, 30)
		pivot_offset = Vector2(11, 0)

	func setup(icon: Texture2D, shader: Shader) -> void:
		_home = position
		var mine: bool = slot.get("mine", false)
		var tier := str(slot.get("tier", "common"))
		var col: Color = Palette.RARITY.get(tier, Palette.COMMON)
		_art = Control.new()
		_art.size = Vector2(16, 16)
		_art.position = Vector2(3, 9)
		_art.pivot_offset = Vector2(8, 8)
		_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_art)
		if mine and icon:
			BookOverlay.glow(_art, Vector2(8, 8), col, 22.0, 0.55)
			var mat := BookOverlay.flat(shader, col)
			for d: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
				_rect(icon, d, mat)
			_rect(icon, Vector2.ZERO, null)
		else:
			_rect(DrawOverlay._region(DrawOverlay.NINJA % cultist, Rect2(0, 0, 16, 16)), Vector2.ZERO, null)

	func _rect(tex: Texture2D, offset: Vector2, mat: Material) -> void:
		var r := TextureRect.new()
		r.texture = tex
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.size = Vector2(16, 16)
		r.position = offset
		r.material = mat
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_art.add_child(r)

	func swing(amount: float) -> void:
		_swing = maxf(_swing, amount)

	func pop() -> void:
		var tw := _art.create_tween()
		tw.tween_property(_art, "scale", Vector2(1.6, 1.6), 0.08)
		tw.tween_property(_art, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func hop() -> void:
		var tw := _art.create_tween()
		tw.tween_property(_art, "position:y", 5.0, 0.08)
		tw.tween_property(_art, "position:y", 9.0, 0.12)

	func _process(delta: float) -> void:
		_t += delta
		_swing = move_toward(_swing, 0.0, delta * 0.9)
		rotation = sin(_t * 1.1 + _home.x * 0.1) * 0.03 + sin(_t * 12.0) * 0.3 * _swing

	func _draw() -> void:
		var mine: bool = slot.get("mine", false)
		var paper := DrawOverlay.CREAM if mine else DrawOverlay.GREY_TICKET
		draw_rect(Rect2(1, 2, 22, 30), Color(0, 0, 0, 0.4))
		draw_rect(Rect2(Vector2.ZERO, size), paper)
		draw_rect(Rect2(0, 0, size.x, 1), paper.lightened(0.3))
		# The punched hole it hangs by, and the perforated stub.
		draw_rect(Rect2(9, 2, 4, 3), Color("21140f"))
		for k in range(1, 22, 2):
			draw_rect(Rect2(k, 6, 1, 1), paper.darkened(0.3))
		# The prize's color along the bottom edge.
		var col: Color = Palette.RARITY.get(str(slot.get("tier", "common")), Palette.COMMON)
		draw_rect(Rect2(2, 27, 18, 2), col if mine else col.darkened(0.45))
