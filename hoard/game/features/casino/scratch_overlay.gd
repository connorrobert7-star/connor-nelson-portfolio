class_name ScratchOverlay
extends MachineOverlay
## Scratch-off books: $1, $2 and $5, twenty tickets a book, each book's contents counted out
## loud and shown as pips on the counter (one per ticket in a full book; the lit ones are
## still in it). Tap a book and Vex says its count; tap it again to buy the top ticket. The
## price lands in the House Fund or the Brokerage first, then the ticket tears off and you
## scratch its foil with a finger (drag). Nine marks hide under it; the best mark showing
## three times is the prize. At 60% scratched the rest of the foil falls away, the three
## matching marks light in their rarity, and the cosmetic flies out.

const PRICES: Array[int] = [100, 200, 500]
const STACK_X := {100: 168.0, 200: 240.0, 500: 312.0}
const CARDS := A + "kenney-playing-cards/Tilesheet/cardsLarge_tilemap_packed.png"
const CARD_RECT := Rect2(843, 2, 42, 60)
const CURSORS := A + "kenney-cursor-pixel-pack/Tilemap/tilemap_packed.png"
const FINGER := Rect2(272, 96, 16, 16)
const FINGER_TIP := Vector2(6, 1)
const TICKET := Rect2(170, 30, 140, 190)
const FOIL_OFF := Vector2(8, 40)  # the foil's corner inside the ticket
const FOIL_AT := Vector2(178, 70)  # ... and in the room
const FOIL_SIZE := 124
const CELL := 36
const CELL_STEP := 42
const BRUSH := 6.5
const AUTO_AT := 0.6
const SEEN_AT := 0.3  # a cell counts as seen once this much of it is scraped
const COUNTER_Y := 186.0

const SND_SCRATCH := A + "freesound-cc0-picks/274746_Scratching_2_wav.mp3"
const SND_TEAR := A + "kenney-casino-audio/Audio/cards-pack-take-out-1.ogg"
const SND_SLIDE := A + "kenney-casino-audio/Audio/card-slide-1.ogg"
const SND_PICK := A + "kenney-casino-audio/Audio/card-place-1.ogg"
const SND_GLINT := A + "kenney-interface-sounds/Audio/glass_002.ogg"
const SND_PEEL := A + "kenney-casino-audio/Audio/cards-pack-open-1.ogg"
const SND_HEART := A + "bart-heartbeat-sounds/heartbeat_slow_0.ogg"
const SND_SLIP := A + "wobbleboxx-levelup-coin/Downer01.ogg"
const SND_LOCK := A + "kenney-interface-sounds/Audio/confirmation_002.ogg"

## Each book's own stripe (never a rarity color).
const BOOK_COLOR := {100: Palette.TEAL, 200: Palette.PINK, 500: Palette.BILE}
const FOIL_DARK := Color("4a3b57")
const FOIL_LIGHT := Color("a593b8")
const PAPER := Color("dfe5ee")
const PAPER_EDGE := Color("aeb8c6")

static var _last_price := 100

## The book picked (its price in cents), how much foil is gone (0..1), the nine marks once
## a ticket is bought, and which cells hold the prize.
var price := 100
var coverage := 0.0
var symbols: Array = []
var prize_cells: Array[int] = []

var _books: Dictionary = {}  # price -> Book
var _sigil: Sigil
var _ticket: Ticket
var _foil := TextureRect.new()
var _foil_img: Image
var _foil_tex: ImageTexture
var _alive := PackedByteArray()  # 1 where the foil is still on
var _left_px := 0
var _cell_px := PackedInt32Array()
var _seen: Array[bool] = []
var _dirty := false
var _scratching := false
var _last := Vector2.INF
var _quiet := 0.0
var _scratch := AudioStreamPlayer.new()
var _heart := AudioStreamPlayer.new()
var _finger := TextureRect.new()
var _chips := CPUParticles2D.new()
var _ghost := true  # the finger idles over the foil until the first scratch
var _tense := ""  # a tier showing twice that could still come a third time
var _done_scratching := false


func _build_machine() -> void:
	price = _last_price if _last_price in PRICES else 100
	var counter := Counter.new()
	stage.add_child(counter)
	_sigil = Sigil.new()
	_sigil.position = Vector2(240 - 48, 18)
	stage.add_child(_sigil)
	var books: Array = Game.state.get("casino", {}).get("scratch", [])
	for p: int in PRICES:
		var b := Book.new()
		b.price = p
		b.position = Vector2(float(STACK_X[p]) - 28.0, COUNTER_Y - 90.0)
		for entry: Dictionary in books:
			if int(entry.get("price_cents", 0)) == p:
				b.total = int(entry.get("size", 20))
				b.left = entry.get("left", {})
		stage.add_child(b)
		_books[p] = b
	_mark_selected()

	_ticket = Ticket.new()
	_ticket.visible = false
	stage.add_child(_ticket)
	_foil.position = FOIL_OFF
	_foil.size = Vector2(FOIL_SIZE, FOIL_SIZE)
	_foil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ticket.add_child(_foil)

	_chips.emitting = false
	_chips.amount = 40
	_chips.lifetime = 0.7
	_chips.direction = Vector2.DOWN
	_chips.spread = 70.0
	_chips.initial_velocity_min = 10.0
	_chips.initial_velocity_max = 40.0
	_chips.gravity = Vector2(0, 260)
	_chips.scale_amount_min = 1.0
	_chips.scale_amount_max = 2.0
	_chips.color_ramp = grad([0.0, 1.0], [FOIL_LIGHT, Color(FOIL_DARK, 0.0)])
	_chips.z_index = 20
	stage.add_child(_chips)
	_finger.texture = region(CURSORS, FINGER)
	_finger.size = Vector2(16, 16)
	_finger.visible = false
	_finger.z_index = 21
	_finger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_finger)

	_scratch.stream = looped(SND_SCRATCH)
	_scratch.volume_db = -8.0
	add_child(_scratch)
	_heart.stream = looped(SND_HEART)
	_heart.volume_db = -4.0
	add_child(_heart)


func _dealer_line() -> String:
	var dealer: Dictionary = Game.state.get("casino", {}).get("dealer", {})
	var before: Dictionary = dealer.get("before", {}).get("scratch", {}).get(str(price), {})
	return str(before.get(dest, dealer.get("line", "")))


func _price_cents() -> int:
	return price


func _machine_rect() -> Rect2:
	return Rect2(126, 90, 228, 136)


## The book stack for a price, for taps in the tour.
func book_control(p: int) -> Control:
	return _books.get(p)


## The foil, in room coordinates (480x270), for drags in the tour.
func foil_rect() -> Rect2:
	return Rect2(FOIL_AT, Vector2(FOIL_SIZE, FOIL_SIZE))


# --- picking a book --------------------------------------------------------------------

func _machine_input(event: InputEvent, at: Vector2) -> bool:
	if moment == "choose":
		var mb := event as InputEventMouseButton
		if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			for p: int in _books:
				var b: Book = _books[p]
				if b.hit_rect().has_point(at):
					if p == price:
						_buy()
					else:
						_pick(p)
					return true
		return false
	if moment == "scratch":
		return _scratch_input(event, at)
	return false


func _pick(p: int) -> void:
	price = p
	_last_price = p
	_mark_selected()
	Sfx.play_path(SND_PICK, 1.0 + PRICES.find(p) * 0.08, -6.0)
	update_lamp()
	speak_line(_dealer_line())


func _mark_selected() -> void:
	for p: int in _books:
		var b: Book = _books[p]
		b.selected = p == price
		var tw := b.create_tween()
		tw.tween_property(b, "lift", 5.0 if p == price else 0.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		b.modulate = Color.WHITE if p == price else Color(0.72, 0.7, 0.76)
	if _sigil:
		_sigil.look = Vector2(float(STACK_X[price]), COUNTER_Y - 40.0)


func _buy() -> void:
	var b: Book = _books[price]
	var data := await pay("/casino/scratch", {"price_cents": price}, b.position + b.face_rect().get_center())
	if data.is_empty():
		return
	await play(data)


## Hand over a bought ticket: it tears off the book and waits to be scratched. _buy calls
## this once the money has landed; it never moves money itself.
func play(data: Dictionary) -> void:
	result = data
	phase = Phase.BUSY
	hush()
	symbols = data.get("symbols", [])
	await _tear(_books[price], data)
	_start_scratch()


## The top ticket tears off the book and comes up to the light, growing into the ticket.
func _tear(b: Book, data: Dictionary) -> void:
	moment = "tear"
	Sfx.play_path(SND_TEAR, 1.0, -4.0)
	var from := b.face_rect()
	from.position += b.position
	b.left = data.get("book", {}).get("left", b.left)
	_ticket.price = price
	_ticket.symbols = symbols
	# The footer lights the marks that were in the book when this ticket came off it.
	var marks: Dictionary = {str(data.get("tier", "common")): true}
	var left: Dictionary = data.get("book", {}).get("left", {})
	for t: String in left:
		if int(left[t]) > 0:
			marks[t] = true
	_ticket.marks = marks
	_ticket.reset()
	_make_foil()
	_ticket.position = from.position
	_ticket.size = TICKET.size
	_ticket.pivot_offset = Vector2.ZERO
	_ticket.scale = from.size / TICKET.size
	_ticket.rotation = -0.08
	_ticket.visible = true
	for p: int in _books:
		var other: Book = _books[p]
		other.create_tween().tween_property(other, "modulate:a", 0.0, 0.25)
	var tw := _ticket.create_tween().set_parallel(true)
	tw.tween_property(_ticket, "position", TICKET.position, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_ticket, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_ticket, "rotation", 0.0, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.2).timeout
	Sfx.play_path(SND_SLIDE, 1.1, -6.0)
	await tw.finished
	shake(_room, 1.0, 0.1)


# --- the foil ------------------------------------------------------------------------------

## A plum-silver foil with a sheen, flecks, and an eye pressed over each of the nine cells.
func _make_foil() -> void:
	_foil_img = Image.create(FOIL_SIZE, FOIL_SIZE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in FOIL_SIZE:
		for x in FOIL_SIZE:
			var band := 0.5 + 0.5 * sin((x * 0.6 + y) * 0.2)
			var c := FOIL_DARK.lerp(FOIL_LIGHT, 0.3 + 0.38 * band + 0.18 * rng.randf())
			if rng.randf() < 0.02:
				c = c.lightened(0.45)
			if x == 0 or y == 0 or x == FOIL_SIZE - 1 or y == FOIL_SIZE - 1:
				c = FOIL_DARK.darkened(0.35)
			_foil_img.set_pixel(x, y, c)
	for i in 9:
		var cc := _cell_center_local(i)
		for j in 48:
			var a := TAU * j / 48.0
			var p := cc + Vector2(cos(a) * 9.0, sin(a) * 5.0 * (0.4 + 0.6 * absf(sin(a))))
			_foil_img.set_pixelv(p.round(), FOIL_DARK.darkened(0.2))
		for d: Vector2 in [Vector2.ZERO, Vector2(1, 0), Vector2(0, 1), Vector2(1, 1), Vector2(-1, 0), Vector2(0, -1)]:
			_foil_img.set_pixelv((cc + d).round(), FOIL_DARK.darkened(0.4))
	_foil_tex = ImageTexture.create_from_image(_foil_img)
	_foil.texture = _foil_tex
	_foil.modulate.a = 1.0
	_alive.resize(FOIL_SIZE * FOIL_SIZE)
	_alive.fill(1)
	_left_px = FOIL_SIZE * FOIL_SIZE
	_cell_px.resize(9)
	_cell_px.fill(0)
	_seen.clear()
	_seen.resize(9)
	_seen.fill(false)
	coverage = 0.0


static func _cell_center_local(i: int) -> Vector2:
	return Vector2(2 + CELL / 2.0 + (i % 3) * CELL_STEP, 2 + CELL / 2.0 + (i / 3) * CELL_STEP)


func _cell_center_room(i: int) -> Vector2:
	return FOIL_AT + _cell_center_local(i)


static func _cell_at(x: int, y: int) -> int:
	var cx := x - 2
	var cy := y - 2
	if cx < 0 or cy < 0:
		return -1
	var c := cx / CELL_STEP
	var r := cy / CELL_STEP
	if c > 2 or r > 2 or cx % CELL_STEP >= CELL or cy % CELL_STEP >= CELL:
		return -1
	return r * 3 + c


func _start_scratch() -> void:
	moment = "scratch"
	phase = Phase.BUSY
	_ghost = true
	_finger.visible = true


func _scratch_input(event: InputEvent, at: Vector2) -> bool:
	var local := at - FOIL_AT
	var near := Rect2(Vector2(-10, -10), Vector2(FOIL_SIZE + 20, FOIL_SIZE + 20)).has_point(local)
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed and near:
			_scratching = true
			_ghost = false
			_last = local
			_finger_to(at)
			_stroke(local, local)
		elif not mb.pressed:
			_scratching = false
			_last = Vector2.INF
			_chips.emitting = false
		return true
	var mm := event as InputEventMouseMotion
	if mm:
		if not _ghost or near:
			_ghost = false
			_finger_to(at)
		var held := (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
		if held and not _scratching and near:
			_scratching = true
			_last = local
		if _scratching and held:
			_stroke(_last, local)
			_last = local
			_chips.position = at
			_chips.emitting = true
			_quiet = 0.1
			if not _scratch.playing:
				_scratch.play(randf_range(0.0, 10.0))
			_scratch.pitch_scale = clampf(0.85 + mm.relative.length() * 0.04, 0.85, 1.4)
		return true
	return false


func _finger_to(at: Vector2) -> void:
	_finger.position = (at - FINGER_TIP).round()


func _stroke(from: Vector2, to: Vector2) -> void:
	var steps := maxi(1, int(from.distance_to(to) / 2.0))
	for i in steps + 1:
		_scrape(from.lerp(to, float(i) / steps))
	coverage = 1.0 - float(_left_px) / float(FOIL_SIZE * FOIL_SIZE)
	if coverage >= AUTO_AT and not _done_scratching:
		_finish_scratch()


func _scrape(p: Vector2) -> void:
	var x0 := maxi(0, int(p.x - BRUSH - 1.0))
	var x1 := mini(FOIL_SIZE - 1, int(p.x + BRUSH + 1.0))
	var y0 := maxi(0, int(p.y - BRUSH - 1.0))
	var y1 := mini(FOIL_SIZE - 1, int(p.y + BRUSH + 1.0))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var idx := y * FOIL_SIZE + x
			if _alive[idx] == 0:
				continue
			# Rough edges: each pixel has its own reach.
			var jitter := float(((x * 73856093) ^ (y * 19349663)) & 7) / 7.0 * 2.0
			if Vector2(x + 0.5, y + 0.5).distance_to(p) > BRUSH - jitter:
				continue
			_alive[idx] = 0
			_foil_img.set_pixel(x, y, Color(0, 0, 0, 0))
			_left_px -= 1
			var cell := _cell_at(x, y)
			if cell >= 0:
				_cell_px[cell] += 1
				if not _seen[cell] and _cell_px[cell] >= int(CELL * CELL * SEEN_AT):
					_cell_seen(cell)
	_dirty = true


## A mark shows through: it glints, its rarity glows under it, and two of a kind that could
## still make three starts the heart going.
func _cell_seen(i: int) -> void:
	_seen[i] = true
	_ticket.seen[i] = true
	var tier := str(symbols[i]) if i < symbols.size() else "common"
	Sfx.play_path(SND_GLINT, 0.8 + 0.18 * TIERS.find(tier), -10.0)
	if tier != "common":
		_ticket.lit[i] = 0.45
		CasinoFx.burst(_fx, _cell_center_room(i), CasinoFx.rarity_color(tier), 6, 50.0, 0.5)
	_check_tension()


func _check_tension() -> void:
	var counts: Dictionary = {}
	for j in 9:
		if _seen[j]:
			var t := str(symbols[j])
			counts[t] = int(counts.get(t, 0)) + 1
	var pair := ""
	for t: String in TIERS:
		if t == "common":
			continue
		if int(counts.get(t, 0)) >= 3:
			# Three showing: that's the prize, locked in.
			if _tense != "":
				_heart.stop()
				_tense = ""
			for j in 9:
				if str(symbols[j]) == t:
					_ticket.lit[j] = 1.0
			Sfx.play_path(SND_LOCK, 1.0, -6.0)
			return
		if int(counts.get(t, 0)) == 2:
			pair = t
	if pair != "" and pair != _tense:
		_tense = pair
		_heart.play()
		_ticket.tense = pair


func _process(delta: float) -> void:
	super._process(delta)
	if _dirty and _foil_tex:
		_foil_tex.update(_foil_img)
		_dirty = false
	if _quiet > 0.0:
		_quiet -= delta
		if _quiet <= 0.0:
			_scratch.stop()
			_chips.emitting = false
	if moment == "scratch" and _ghost:
		# A finger scratching at nothing over the foil, until yours takes over.
		var c := FOIL_AT + Vector2(FOIL_SIZE * 0.5, FOIL_SIZE * 0.55)
		_finger.position = (c + Vector2(sin(_t * 7.0) * 14.0, cos(_t * 3.5) * 5.0) - FINGER_TIP).round()


## At 60%: the rest of the foil falls away, the near miss (if any) slips, the three matching
## marks light one after another in their rarity, and the cosmetic flies out of them.
func _finish_scratch() -> void:
	_done_scratching = true
	moment = "revealed"
	_scratching = false
	_scratch.stop()
	_chips.emitting = false
	_finger.visible = false
	Sfx.play_path(SND_PEEL, 1.0, -4.0)
	var fall := _foil.create_tween()
	fall.tween_property(_foil, "modulate:a", 0.0, 0.3)
	for k in 6:
		CasinoFx.burst(_fx, FOIL_AT + Vector2(randf_range(10, FOIL_SIZE - 10), randf_range(10, FOIL_SIZE - 10)), FOIL_LIGHT, 10, 70.0, 0.7)
	for j in 9:
		_seen[j] = true
		_ticket.seen[j] = true
	await get_tree().create_timer(0.35).timeout
	var tier := str(result.get("tier", result.get("item", {}).get("tier", "common")))
	prize_cells.clear()
	# Three of the prize mark light (a grey ticket can carry more than three skulls).
	for j in 9:
		if j < symbols.size() and str(symbols[j]) == tier and prize_cells.size() < 3:
			prize_cells.append(j)
	if _tense != "" and _tense != tier:
		# Two of them, never a third.
		Sfx.play_path(SND_SLIP, 1.0, -6.0)
		_ticket.tense = ""
		await get_tree().create_timer(0.5).timeout
	_heart.stop()
	_tense = ""
	_ticket.tense = ""
	for j in 9:
		if j not in prize_cells:
			_ticket.lit[j] = 0.0
			_ticket.create_tween().tween_method(func(v: float) -> void: _ticket.dim[j] = v, 0.0, 0.65, 0.3)
	moment = "match"
	var color := CasinoFx.rarity_color(tier)
	for k in prize_cells.size():
		var j := prize_cells[k]
		_ticket.lit[j] = 1.0
		_ticket.pop[j] = 1.0
		ring(_fx, _cell_center_room(j), color, 26.0, 0.35)
		Sfx.play_path(SND_GLINT, [1.0, 1.26, 1.5][mini(k, 2)], -4.0)
		CasinoFx.burst(_fx, _cell_center_room(j), color, 10, 80.0, 0.5)
		await get_tree().create_timer(0.24).timeout
	# The three join up.
	_ticket.link_cells = prize_cells
	_ticket.link_tier = tier
	Sfx.play_path(SND_LOCK, 1.0, -4.0)
	_ticket.create_tween().tween_property(_ticket, "links", 1.0, 0.25)
	await get_tree().create_timer(0.6).timeout
	var at := Vector2.ZERO
	for j in prize_cells:
		at += _cell_center_room(j)
	at = at / maxf(1.0, prize_cells.size()) if not prize_cells.is_empty() else FOIL_AT + Vector2(62, 62)
	var dim := _ticket.create_tween()
	dim.tween_property(_ticket, "modulate", Color(0.6, 0.6, 0.65), 0.4)
	await reveal(result.get("item", {}), at)
	finish()


# --- drawn pieces ------------------------------------------------------------------------

## The playing card the tickets are cut from, as a nine-slice.
static func card_box() -> StyleBoxTexture:
	if not MachineOverlay._cache.has("_card_box"):
		var sb := StyleBoxTexture.new()
		sb.texture = MachineOverlay.res(CARDS) as Texture2D
		sb.region_rect = CARD_RECT
		sb.texture_margin_left = 5
		sb.texture_margin_right = 5
		sb.texture_margin_top = 5
		sb.texture_margin_bottom = 5
		MachineOverlay._cache["_card_box"] = sb
	return MachineOverlay._cache["_card_box"]


class Sigil:
	extends Control
	## An eye in a triangle painted on the back wall in the lamp's spill, faintly pink, a
	## little wrong: it drips, and its pupil follows the book you're on.
	var look := Vector2(168, 150)
	var _t := 0.0

	func _init() -> void:
		size = Vector2(96, 84)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var light := MachineOverlay.res(MachineOverlay.LIGHT) as Texture2D
		var c := Vector2(size.x / 2.0, 46)
		var paint := Color("4a3358")
		draw_texture_rect(light, Rect2(c - Vector2(64, 60), Vector2(128, 120)), false, Color(Palette.PINK, 0.07 + 0.04 * sin(_t * 1.3)))
		var tri := PackedVector2Array([c + Vector2(0, -40), c + Vector2(42, 30), c + Vector2(-42, 30), c + Vector2(0, -40)])
		draw_polyline(tri, paint, 2.0)
		for i in 7:
			var a := -PI / 2.0 + (i - 3) * 0.32
			var d := Vector2(cos(a), sin(a))
			draw_line(c + d * 50.0, c + d * (58.0 + 3.0 * sin(_t * 2.0 + i)), Color(paint, 0.8), 1.0)
		for k in 3:
			var x := c.x - 24.0 + k * 21.0
			var drip := 4.0 + 5.0 * absf(sin(_t * 0.4 + k * 1.7))
			draw_line(Vector2(x, c.y + 31), Vector2(x, c.y + 31 + drip), paint, 1.0)
		var e := c + Vector2(0, 10)
		var lid := PackedVector2Array()
		for j in 18:
			var a := TAU * j / 18.0
			lid.append(e + Vector2(cos(a) * 15.0, sin(a) * 8.0 * (0.4 + 0.6 * absf(sin(a)))))
		draw_colored_polygon(lid, Color("2a1d33"))
		var dir := (look - (position + e)).normalized()
		draw_circle(e + dir * 4.0, 4.5, Color(Palette.PINK, 0.55))
		draw_circle(e + dir * 4.5, 2.0, Palette.NIGHT)
		lid.append(lid[0])
		draw_polyline(lid, paint, 1.0)


class Counter:
	extends Control
	## The felt counter the books stand on.
	func _init() -> void:
		size = Vector2(480, 270)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := ScratchOverlay.COUNTER_Y
		draw_rect(Rect2(118, y - 4, 244, 6), Color("2c1d33"))
		draw_rect(Rect2(118, y + 2, 244, 30), MachineOverlay.BODY)
		draw_rect(Rect2(118, y - 4, 244, 1), MachineOverlay.TRIM_LIT)
		draw_rect(Rect2(118, y + 2, 244, 1), MachineOverlay.TRIM)
		draw_rect(Rect2(118, y + 31, 244, 1), MachineOverlay.TRIM)
		draw_rect(Rect2(122, y + 6, 236, 22), MachineOverlay.BODY_DARK, false, 1.0)


class Book:
	extends Control
	## A book of tickets: one edge for every ticket still in it, the top ticket's face with
	## its price, and the pips on the counter: one per ticket in a full book, lit in the
	## color of each ticket still in, highest first (counts only; the order stays hidden).
	var price := 100
	var total := 20
	var left: Dictionary = {}:
		set(v):
			left = v
			queue_redraw()
	var selected := false:
		set(v):
			selected = v
			queue_redraw()
	var lift := 0.0:
		set(v):
			lift = v
			queue_redraw()
	var _t := 0.0

	func _init() -> void:
		size = Vector2(56, 106)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func count() -> int:
		var n := 0
		for t: String in left:
			n += int(left[t])
		return n

	func face_rect() -> Rect2:
		return Rect2(4, 90.0 - count() * 2.0 - 34.0 - lift, 48, 34)

	func hit_rect() -> Rect2:
		var top := face_rect().position.y - 4.0
		return Rect2(position + Vector2(0, top), Vector2(size.x, size.y - top))

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var light := MachineOverlay.res(MachineOverlay.LIGHT) as Texture2D
		var by := 90.0
		var n := count()
		draw_texture_rect(light, Rect2(-8, by - 9, 72, 18), false, Color(0, 0, 0, 0.7))
		if selected:
			draw_texture_rect(light, Rect2(-22, by - 78, 100, 100), false, Color(Palette.CREAM, 0.1 + 0.04 * sin(_t * 3.0)))
		var stripe: Color = ScratchOverlay.BOOK_COLOR.get(price, Palette.CREAM)
		for i in n:
			var y := by - 2.0 - i * 2.0
			var jx := float((i * 7) % 3) - 1.0  # stacked by hand
			var c := ScratchOverlay.PAPER if i % 2 == 0 else ScratchOverlay.PAPER_EDGE
			draw_rect(Rect2(4 + jx, y, 48, 2), c)
			draw_rect(Rect2(4 + jx, y + 1, 48, 1), c.darkened(0.35))
			draw_rect(Rect2(4 + jx, y, 2, 2), stripe.darkened(0.25))
		var f := face_rect()
		if n > 0:
			draw_style_box(ScratchOverlay.card_box(), f)
			# The price on a dark band, in bone white (a real-dollar number).
			draw_rect(Rect2(f.position + Vector2(3, 4), Vector2(22, 14)), Palette.INK)
			draw_rect(Rect2(f.position + Vector2(3, 18), Vector2(22, 2)), stripe)
			draw_rect(Rect2(f.position + Vector2(1, 1), Vector2(2, f.size.y - 2)), stripe)
			var font := MachineOverlay.res(MachineOverlay.JERSEY) as Font
			draw_string(font, f.position + Vector2(5, 16), MachineOverlay.price_text(price), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.CREAM)
			var foil := Rect2(f.position + Vector2(28, 5), Vector2(17, 24))
			draw_rect(foil, ScratchOverlay.FOIL_DARK.lerp(ScratchOverlay.FOIL_LIGHT, 0.5))
			for k in 3:
				var sy := foil.position.y + 3 + k * 8 + int(_t * 6.0) % 8
				if sy < foil.end.y - 1:
					draw_rect(Rect2(foil.position.x + 1, sy, foil.size.x - 2, 1), Color(ScratchOverlay.FOIL_LIGHT.lightened(0.3), 0.6))
			draw_rect(Rect2(f.position + Vector2(5, 21), Vector2(18, 1)), Color(Palette.INK, 0.4))
			draw_rect(Rect2(f.position + Vector2(5, 24), Vector2(14, 1)), Color(Palette.INK, 0.4))
		# The pips.
		var tiers: Array[String] = []
		for t: String in ["mythic", "legendary", "epic", "rare", "common"]:
			for k in int(left.get(t, 0)):
				tiers.append(t)
		for j in total:
			var r := Rect2(3 + (j % 10) * 5, by + 6 + (j / 10) * 5, 4, 4)
			if j < tiers.size():
				var col := CasinoFx.rarity_color(tiers[j])
				if tiers[j] != "common":
					var pulse := 0.25 + 0.15 * sin(_t * 4.0 + j)
					draw_texture_rect(light, r.grow(4), false, Color(col, pulse))
				draw_rect(r, col)
				draw_rect(Rect2(r.position, Vector2(4, 1)), col.lightened(0.35))
			else:
				draw_rect(r, Color("120c18"))
				draw_rect(r, Color(MachineOverlay.TRIM, 0.5), false, 1.0)


class Ticket:
	extends Control
	## The bought ticket: the card, its price on a dark band, the nine cells (marks under the
	## foil), and along the bottom the five marks this kind of book can hold, lit or dark.
	var price := 100
	var symbols: Array = []
	var marks: Dictionary = {}
	var seen: Array[bool] = []
	var lit: Array[float] = []
	var dim: Array[float] = []
	var pop: Array[float] = []
	var tense := ""
	var link_cells: Array[int] = []
	var link_tier := "common"
	var links := 0.0
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func reset() -> void:
		link_cells = []
		links = 0.0
		seen.resize(9)
		seen.fill(false)
		lit.resize(9)
		lit.fill(0.0)
		dim.resize(9)
		dim.fill(0.0)
		pop.resize(9)
		pop.fill(0.0)
		tense = ""

	func _process(delta: float) -> void:
		_t += delta
		for i in pop.size():
			pop[i] = maxf(0.0, pop[i] - delta * 3.0)
		queue_redraw()

	func _draw() -> void:
		var light := MachineOverlay.res(MachineOverlay.LIGHT) as Texture2D
		var font := MachineOverlay.res(MachineOverlay.JERSEY) as Font
		draw_texture_rect(light, Rect2(Vector2(-30, -20), size + Vector2(60, 40)), false, Color(Palette.CREAM, 0.08))
		draw_style_box(ScratchOverlay.card_box(), Rect2(Vector2.ZERO, size))
		# Header: the price in bone white on a dark band, an eye either side.
		draw_rect(Rect2(8, 7, size.x - 16, 27), Palette.INK)
		var stripe: Color = ScratchOverlay.BOOK_COLOR.get(price, Palette.CREAM)
		draw_rect(Rect2(8, 34, size.x - 16, 2), stripe)
		draw_rect(Rect2(3, 8, 2, size.y - 16), stripe)
		draw_rect(Rect2(size.x - 5, 8, 2, size.y - 16), stripe)
		draw_string(font, Vector2(0, 30), MachineOverlay.price_text(price), HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, Palette.CREAM)
		for ex: float in [22.0, size.x - 22.0]:
			_eye(Vector2(ex, 20))
		# The well under the foil and its nine cells.
		var well := Rect2(ScratchOverlay.FOIL_OFF, Vector2(ScratchOverlay.FOIL_SIZE, ScratchOverlay.FOIL_SIZE))
		draw_rect(well, Color("1a1220"))
		for i in 9:
			var c := ScratchOverlay.FOIL_OFF + ScratchOverlay._cell_center_local(i)
			var r := Rect2(c - Vector2(18, 18), Vector2(36, 36))
			draw_rect(r, Color("2a1d33"))
			draw_rect(r, Color("3b2a47"), false, 1.0)
			if i >= symbols.size():
				continue
			var tier := str(symbols[i])
			var col := CasinoFx.rarity_color(tier)
			var glow := lit[i] if i < lit.size() else 0.0
			if tense == tier and seen[i]:
				glow = maxf(glow, 0.55 + 0.35 * sin(_t * 10.0))
			if glow > 0.0:
				draw_texture_rect(light, r.grow(10), false, Color(col, 0.75 * glow))
				draw_rect(r.grow(1), Color(col, glow), false, 2.0)
				draw_rect(r.grow(-1), Color(MachineOverlay.GLOW.get(tier, col), 0.6 * glow), false, 1.0)
			var frame := int(_t * 12.0 + i * 5) % 30 if seen[i] else 0
			var k := 1.0 + 0.35 * (pop[i] if i < pop.size() else 0.0)
			var fade := 1.0 - (dim[i] if i < dim.size() else 0.0)
			MachineOverlay.draw_symbol(self, c, tier, mini(frame, MachineOverlay.symbol_frames(tier) - 1), k, Color(fade, fade, fade, 1.0))
		# The winning three, joined by a line of their light.
		if links > 0.0 and link_cells.size() >= 2:
			var col := CasinoFx.rarity_color(link_tier)
			var pts := PackedVector2Array()
			for j in link_cells:
				pts.append(ScratchOverlay.FOIL_OFF + ScratchOverlay._cell_center_local(j))
			pts.append(pts[0])
			draw_polyline(pts, Color(col, 0.45 * links), 5.0)
			draw_polyline(pts, Color(MachineOverlay.GLOW.get(link_tier, col), 0.9 * links), 1.0)
		# Footer: the marks this book held, lit; the rest dark.
		for j in MachineOverlay.TIERS.size():
			var t: String = MachineOverlay.TIERS[j]
			var c := Vector2(size.x / 2.0 + (j - 2) * 22.0, size.y - 13.0)
			var on: bool = marks.has(t)
			MachineOverlay.draw_symbol(self, c, t, 0, 0.5, Color.WHITE if on else Color(0.2, 0.18, 0.24, 0.9))

	func _eye(c: Vector2) -> void:
		var lid := PackedVector2Array()
		for j in 16:
			var a := TAU * j / 16.0
			lid.append(c + Vector2(cos(a) * 7.0, sin(a) * 4.0 * (0.45 + 0.55 * absf(sin(a)))))
		draw_colored_polygon(lid, Palette.PANEL)
		draw_circle(c + Vector2(sin(_t * 1.3) * 1.5, 0), 2.0, Palette.CREAM)
		draw_rect(Rect2(c + Vector2(sin(_t * 1.3) * 1.5, 0) - Vector2(0.5, 1), Vector2(1, 2)), Palette.NIGHT)
