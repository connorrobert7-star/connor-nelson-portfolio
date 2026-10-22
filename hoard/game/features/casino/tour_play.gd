extends RefCounted
## Playtest: the casino played like the owner on a phone, through real touches (Godot makes a
## click from each one too, like on the phone), from the room every time: walk to a machine,
## hear Vex out, play it, and check the state after each step. Money moves are checked to the
## cent, every tap must be answered by a sound or something drawn that frame, and nothing may
## be left stuck after a machine closes (Game.busy, an overlay, the time scale).
##   1. The floor answers a tap; a touch on a case walks there and Vex says the price whole.
##   2. Cases $10, $20 (into the Brokerage) and $50 (skipped by a tap), each held on the slot.
##   3. Scratch $1, $2 and $5, picked and bought by touch, scratched with a finger.
##   4. The wheel and the claw (dragged by finger, the button pressed).
##   5. The book: a quick tap while it opens, ribbons flipped, a piece worn, a trade-up.
##   6. The week's room spent: "Not this week." in the room, twice, and nothing stuck.
##   7. The weekly draw: the dial lets the days pass to Sunday, the ticket plate shows, and
##      the drum plays the draw; a ticket and the drum answer taps; the floor leaves.
##   godot --path game res://dev/tour.tscn -- <out> res://features/casino/tour_play.gd

var kit: TourKit
var room: CasinoRoom
var opened: Array[Overlay] = []
## What the last overlay closed with (the overlay itself is freed after its outro).
var last_result: Variant = null


func run(k: TourKit) -> void:
	kit = k
	await kit.go_to("casino", Room.ENTRANCE)
	room = kit.level() as CasinoRoom
	if not kit.check(room != null, "the casino opens"):
		return
	kit.main._overlays.child_entered_tree.connect(func(n: Node) -> void:
		if n is Overlay and not opened.has(n):
			opened.append(n)
			(n as Overlay).closed.connect(func(r: Variant) -> void: last_result = r))
	await kit.until(func() -> bool: return room.vex.spoken > 0 and not room.vex.speaking, 10.0)
	await _floor()
	await _case("case_10", "sav_1", false)
	await _case("case_20", "brk_1", false)
	await _case("case_50", "sav_1", true)
	for p: int in [100, 200, 500]:
		await _scratch(p)
	await _wheel()
	await _claw()
	await _book()
	await _refused()
	await _draw()


# --- 1 ---------------------------------------------------------------------------------

func _floor() -> void:
	await _idle()
	var at := room.leader.position + Vector2(-40, 10)
	var t := Time.get_ticks_msec()
	await touch_down(_world(at))
	var rings := room.get_children().filter(func(n: Node) -> bool: return n is TapMarker)
	kit.check(rings.size() == 1, "one touch on the floor leaves one ring (%d)" % rings.size())
	kit.check(_heard(t), "and clicks")
	await touch_up(_world(at))
	await kit.wait(0.8)
	kit.check(room.leader.position.distance_to(at) < 20.0, "and the leader walks there")


# --- 2 ---------------------------------------------------------------------------------

func _case(id: String, dest: String, skip: bool) -> void:
	var price := 0
	for c: Dictionary in room.casino().get("cases", []):
		if c.id == id:
			price = int(c.price_cents)
	var bal := _balance(dest)
	var ov := await _walk_up(id) as CaseOverlay
	if not kit.check(ov != null, "%s opens its reel" % id):
		return
	await kit.until(func() -> bool: return ov.moment == "choose" and ov._root.modulate.a > 0.99, 4.0)
	await kit.wait(0.3)
	if ov.dest != dest:
		await touch(_ctl(ov.mouth_control(dest)))
		await kit.wait(0.3)
		kit.check(ov.dest == dest, "a touch on the %s mouth picks it" % dest)
		kit.check(ov.moment == "choose", "and moves nothing")
	# Press and hold the bill on the slot.
	await touch_down(_ctl(ov.mouth_control(dest)))
	await kit.wait(0.25)
	kit.check(ov.moment == "hold", "holding fills the ring")
	await kit.wait(0.35)
	await touch_up(_ctl(ov.mouth_control(dest)))
	await kit.until(func() -> bool: return ov.moment == "reel", 8.0)
	if skip:
		await kit.wait(1.2)
		var t := Time.get_ticks_msec()
		await touch(_screen(Vector2(240, 60)))
		await kit.until(func() -> bool: return ov.moment in ["land", "reveal", "near_miss", "book", "closed"], 6.0)
		kit.check(Time.get_ticks_msec() - t < 4500, "a tap after the first second hurries the reel")
	await kit.until(func() -> bool: return ov.moment == "reveal", 14.0)
	await kit.shot("play_%s_reveal" % id)
	# Taps during the reveal hurry it along; it closes on its own.
	await touch(_screen(Vector2(240, 135)))
	await kit.until(func() -> bool: return kit.overlay() == null, 15.0)
	await _closed_clean(id)
	var res: Dictionary = last_result if last_result is Dictionary else {}
	kit.check(int(res.get("money", {}).get("amount_cents", 0)) == price, "%s moved exactly %d cents" % [id, price])
	await kit.until(func() -> bool: return _balance(dest) == bal + price, 5.0)
	kit.check(_balance(dest) == bal + price, "the %s is up exactly that (%d -> %d)" % [dest, bal, _balance(dest)])
	await kit.until(func() -> bool: return _toast("item"), 4.0)
	kit.check(_toast("item"), "the piece shows as a plate once the reel is gone")


# --- 3 ---------------------------------------------------------------------------------

func _scratch(p: int) -> void:
	var bal := _balance("sav_1")
	var ov := await _walk_up("scratch") as ScratchOverlay
	if not kit.check(ov != null, "the booth opens"):
		return
	await kit.wait(0.6)
	if ov.dest != "sav_1":
		await touch(_ctl(ov.mouth_control("sav_1")))
		await kit.wait(0.3)
	if ov.price != p:
		await touch(_ctl(ov.book_control(p)))
		await kit.wait(0.4)
		kit.check(ov.price == p and ov.moment == "choose", "a touch on the $%d book picks it and buys nothing" % (p / 100))
	await touch(_ctl(ov.book_control(p)))
	kit.check(ov.moment != "choose", "a touch on the picked book buys its top ticket")
	await kit.until(func() -> bool: return ov.moment == "scratch", 8.0)
	await kit.wait(0.5)
	var r := ov.foil_rect()
	for i in 12:
		if ov.moment != "scratch":
			break
		var y := r.position.y + 6.0 + i * 11.0
		var a := Vector2(r.position.x + 4, y)
		var b := Vector2(r.end.x - 4, y + 5)
		await touch_drag(ov, [a, b] if i % 2 == 0 else [b, a])
	await kit.until(func() -> bool: return ov.moment != "scratch", 3.0)
	kit.check(ov.coverage >= 0.6, "a finger scratches the foil away (%.0f%%)" % (ov.coverage * 100.0))
	await kit.until(func() -> bool: return kit.overlay() == null, 20.0)
	await _closed_clean("$%d ticket" % (p / 100))
	kit.check(_moved() == p, "the ticket moved exactly %d cents" % p)
	await kit.until(func() -> bool: return _balance("sav_1") == bal + p, 5.0)
	kit.check(_balance("sav_1") == bal + p, "the House Fund is up exactly that")


# --- 4 ---------------------------------------------------------------------------------

func _wheel() -> void:
	var bal := _balance("sav_1")
	var ov := await _walk_up("wheel") as WheelOverlay
	if not kit.check(ov != null, "the wheel opens"):
		return
	await kit.wait(0.6)
	await touch(_ctl(ov.wheel_control()))
	kit.check(ov.moment != "choose", "a touch on the wheel pulls it")
	await kit.until(func() -> bool: return ov.moment == "spin", 8.0)
	await kit.until(func() -> bool: return ov.moment in ["pop", "land", "reveal", "book", "closed"], 15.0)
	kit.check(ov.landed_index == int(ov.result.get("wedge_index", -2)), "the wheel stops on the wedge the house drew")
	var dest := ov.dest
	await kit.until(func() -> bool: return kit.overlay() == null, 25.0)
	await _closed_clean("the wheel")
	kit.check(_moved() == 500, "the wheel moved exactly $5")
	await kit.until(func() -> bool: return dest != "sav_1" or _balance("sav_1") == bal + 500, 5.0)
	kit.check(dest != "sav_1" or _balance("sav_1") == bal + 500, "into the House Fund")


func _claw() -> void:
	var ov := await _walk_up("claw") as ClawOverlay
	if not kit.check(ov != null, "the claw opens"):
		return
	await kit.wait(0.6)
	var heap: Array = Game.state.casino.claw.heap
	var best: Dictionary = heap[0]
	for p: Dictionary in heap:
		if MachineOverlay.TIERS.find(str(p.tier)) > MachineOverlay.TIERS.find(str(best.tier)):
			best = p
	var aim := ClawOverlay.spot(float(best.x), float(best.y))
	await touch_drag(ov, [Vector2(ov.claw_x + 6, 120), Vector2(lerpf(ov.claw_x, aim.x, 0.5), 124), Vector2(aim.x, 128)])
	await kit.wait(1.2)
	kit.check(absf(ov.claw_x - aim.x) < 2.0, "a finger drags the claw over the %s plush" % str(best.tier))
	var at := ov.claw_x
	await touch(_screen(ov.get_global_transform() * (ClawOverlay.STICK + Vector2(12, 0))))
	await kit.wait(0.4)
	kit.check(ov.claw_x > at + 4.0, "a touch on the stick nudges it once (%.1f -> %.1f)" % [at, ov.claw_x])
	await touch(_ctl(ov.button_control()))
	kit.check(ov.moment != "choose", "a touch on the button drops the claw")
	await kit.until(func() -> bool: return kit.overlay() == null, 30.0)
	await _closed_clean("the claw")
	kit.check(_moved() == 500, "the claw moved exactly $5")


# --- 5 ---------------------------------------------------------------------------------

func _book() -> void:
	# Enough commons for a trade-up: real $1 tickets bought straight through the API (setup).
	await BookOverlay.load_catalog()
	var commons := 0
	for i in 40:
		commons = _owned_of("common")
		if commons >= 10:
			break
		await Game.call_api("POST", "/casino/scratch", {"price_cents": 100, "to_account": "sav_1"})
		await Game.refresh()
	kit.check(_owned_of("common") >= 10, "ten commons to trade (%d)" % _owned_of("common"))
	var ov := await _walk_up("book", false) as BookOverlay
	if not kit.check(ov != null, "the book opens"):
		return
	# A quick second tap while it opens never closes it.
	await touch(_screen(Vector2(460, 10)))
	await kit.wait(0.1)
	kit.check(kit.overlay() == ov, "a quick tap while the book opens leaves it open")
	await kit.until(func() -> bool: return ov.moment == "look", 10.0)
	await kit.wait(0.4)
	# Flip by ribbon and back.
	var first := ov.page
	var other := 1 if first == 0 else 0
	await touch(_ctl(ov.tab_control(other)))
	await kit.until(func() -> bool: return ov.moment == "look" and ov.page == other, 3.0)
	kit.check(ov.page == other, "a touch on a ribbon flips the page")
	kit.check(_count_leaves(ov) == 0, "the flipping leaf is gone after the flip")
	await touch(_ctl(ov.tab_control(first)))
	await kit.until(func() -> bool: return ov.moment == "look" and ov.page == first, 3.0)
	# Two touches on two ribbons in a row: it lands on the second.
	if ov.sets.size() > 2:
		await touch(_ctl(ov.tab_control(1)))
		await touch(_ctl(ov.tab_control(2)))
		await kit.until(func() -> bool: return ov.moment == "look", 3.0)
		await kit.wait(0.3)
		kit.check(ov.page == 2 or ov.page == 1, "quick ribbon touches land on a page (%d)" % ov.page)
		await touch(_ctl(ov.tab_control(first)))
		await kit.until(func() -> bool: return ov.moment == "look" and ov.page == first, 3.0)
	await kit.shot("play_book")
	# Wear an owned piece that isn't worn yet.
	var wear := ""
	for id: String in ov.items_on_page():
		var it: Dictionary = ov.items[id]
		if ov.count_of(id) > 0 and str(ov.equipped.get(str(it.slot), "")) != id and not BookOverlay.is_trophy(it):
			wear = id
			break
	if kit.check(wear != "", "an owned piece to wear on this page"):
		var slot := str(ov.items[wear].slot)
		await touch(_ctl(ov.cell_control(wear)))
		await kit.until(func() -> bool: return ov.moment == "look", 5.0)
		await kit.until(func() -> bool: return str(Game.state.casino.equipped.get(slot, "")) == wear, 5.0)
		kit.check(str(Game.state.casino.equipped.get(slot, "")) == wear, "a touch on a piece wears it (%s)" % wear)
		kit.check(ov.piece_on_leader(slot) != null, "and it shows on the figure")
	# The trade-up: open the press, feed ten commons, pull the lever.
	await touch(_screen(BookOverlay.PRESS.get_center()))
	await kit.until(func() -> bool: return ov.moment == "feed", 3.0)
	kit.check(ov.moment == "feed", "a touch on the press opens its mouth")
	var before := _owned_of("common")
	for pg in ov.sets.size():
		if ov.rail.size() >= 10:
			break
		if pg != ov.page:
			await touch(_ctl(ov.tab_control(pg)))
			await kit.until(func() -> bool: return ov.page == pg and ov.mode != BookOverlay.Mode.BUSY, 3.0)
		for id: String in ov.items_on_page():
			var it: Dictionary = ov.items[id]
			if str(it.tier) != "common" or BookOverlay.is_trophy(it):
				continue
			while ov.rail.size() < 10 and ov.count_of(id) > _fed(ov, id):
				var n := ov.rail.size()
				await touch(_ctl(ov.cell_control(id)))
				await kit.wait(0.25)
				if ov.rail.size() != n + 1:
					kit.check(false, "each touch feeds one piece (%d -> %d)" % [n, ov.rail.size()])
					break
	kit.check(ov.rail.size() == 10, "ten commons on the rail (%d)" % ov.rail.size())
	await kit.shot("play_book_rail")
	await touch(_screen(BookOverlay.LEVER.get_center()))
	await kit.until(func() -> bool: return ov.moment in ["reveal", "landed", "look"] and ov.traded == 1, 15.0)
	await kit.until(func() -> bool: return ov.moment == "look", 15.0)
	kit.check(ov.traded == 1, "the lever trades ten up")
	await Game.refresh()
	kit.check(_owned_of("common") == before - 10, "ten commons are gone (%d -> %d)" % [before, _owned_of("common")])
	await kit.shot("play_book_traded")
	# Leave by touching the floor outside the book.
	await touch(_screen(Vector2(240, 262)))
	await kit.until(func() -> bool: return kit.overlay() == null, 5.0)
	await _closed_clean("the book")


# --- 6 ---------------------------------------------------------------------------------

func _refused() -> void:
	for case_id: String in ["case_50", "case_20", "case_10"]:
		for i in 80:
			var r: Array = await Game.api.request("POST", "/casino/case", {}, {"case_id": case_id, "to_account": "sav_1"})
			if r[1] != "":
				break
	for p: int in [500, 200, 100]:
		for i in 80:
			var r: Array = await Game.api.request("POST", "/casino/scratch", {}, {"price_cents": p, "to_account": "sav_1"})
			if r[1] != "":
				break
	await Game.refresh()
	await kit.wait(0.4)
	var bal := _balance("sav_1")
	for n in 2:
		await _idle()
		var count := opened.size()
		await _go_to_spot("case_10")
		await touch(_world(room.spot_rect("case_10").get_center()))
		await kit.until(func() -> bool: return room.vex.last_line == CasinoRoom.NOT_THIS_WEEK, 5.0)
		kit.check(room.vex.last_line == CasinoRoom.NOT_THIS_WEEK, "a spent week: Vex says Not this week. (%d)" % (n + 1))
		await kit.wait(0.4)
		kit.check(opened.size() == count, "and no machine opens")
		kit.check(not Game.busy, "and nothing is left waiting")
		room.vex.last_line = ""
	await kit.shot("play_refused")
	kit.check(_balance("sav_1") == bal, "nothing moved")
	# A free machine still opens after a refusal.
	var ov := await _walk_up("book", false)
	kit.check(ov is BookOverlay, "the book still opens after a refusal")
	if ov:
		await kit.until(func() -> bool: return (ov as BookOverlay).moment == "look", 8.0)
		await kit.wait(0.5)  # a person looks before they leave (a tap sooner is read as a double tap)
		await touch(_screen(Vector2(240, 262)))
		await kit.until(func() -> bool: return kit.overlay() == null, 5.0)
		await _closed_clean("the book")


# --- 7 ---------------------------------------------------------------------------------

func _draw() -> void:
	# The dial lets the days pass to the Sunday draw.
	var draws_on := str(Game.state.casino.draw.get("draws_on", ""))
	for i in 8:
		if str(Game.state.today) >= draws_on:
			break
		await _idle()
		await kit.until(func() -> bool: return kit.main._day_button.visible, 5.0)
		var day := str(Game.state.today)
		await touch(_ctl(kit.main._day_button))
		await kit.until(func() -> bool: return str(Game.state.today) != day, 8.0)
		await kit.wait(0.3)
	kit.check(str(Game.state.today) >= draws_on, "the dial reaches draw day (%s)" % str(Game.state.today))
	await kit.until(func() -> bool: return _toast("ticket"), 6.0)
	kit.check(_toast("ticket"), "the draw shows as a ticket plate")
	await kit.until(func() -> bool: return kit.level() is CasinoRoom and not Game.busy, 8.0)
	room = kit.level() as CasinoRoom
	var drum_at := _world(room.spot_rect("draw").get_center())
	var ov := await _walk_up("draw", false) as DrawOverlay
	if not kit.check(ov != null, "the drum opens the back room"):
		return
	# The second half of a double tap on the drum lands in the back room: it stays open.
	await touch(drum_at)
	await kit.wait(0.1)
	kit.check(kit.overlay() == ov, "a double tap on the drum doesn't close the back room it opened")
	await kit.until(func() -> bool: return ov.moment != "open", 8.0)
	kit.check(ov.winners.size() == 10, "last week's ten winning tickets (%d)" % ov.winners.size())
	# The draw plays; taps hurry it along.
	await kit.wait(0.8)
	await touch(_screen(Vector2(240, 250)))
	await kit.until(func() -> bool: return not ov._busy, 20.0)
	kit.check(not ov._busy and kit.overlay() == ov, "the draw plays out and a tap during it never closes the room")
	await kit.shot("play_draw")
	await kit.wait(1.5)
	var spin := ov._drum.speed
	await touch(_screen(DrawOverlay.HUB))
	kit.check(ov._drum.speed > spin + 1.0, "a touch on the drum turns it (%.1f -> %.1f)" % [spin, ov._drum.speed])
	var t := 0
	for tk in ov._tickets:
		if tk.visible:
			t = Time.get_ticks_msec()
			await touch(_ctl(tk))
			kit.check(_heard(t), "a touch on a ticket answers")
			break
	await touch(_screen(Vector2(460, 250)))
	await kit.until(func() -> bool: return kit.overlay() == null, 5.0)
	await _closed_clean("the draw")


# --- the room --------------------------------------------------------------------------

## Stand near a machine's spot, then touch it the way a phone does. Vex states the odds for a
## paid machine and must not be cut off by the second half of the touch.
func _walk_up(id: String, paid := true) -> Overlay:
	await _idle()
	var count := opened.size()
	var spoken := room.vex.spoken
	await _go_to_spot(id)
	await touch(_world(room.spot_rect(id).get_center()))
	if paid:
		await kit.until(func() -> bool: return room.vex.spoken > spoken, 8.0)
		var line := room.vex.last_line
		var t := Time.get_ticks_msec()
		await kit.until(func() -> bool: return not room.vex.speaking or opened.size() > count, 15.0)
		var held := (Time.get_ticks_msec() - t) / 1000.0
		kit.check(line.contains(" to the ") and held > 0.8, "Vex says the whole price line before %s (%.1fs): %s" % [id, held, line])
	await kit.until(func() -> bool: return opened.size() > count, 10.0)
	await kit.wait(0.1)
	kit.check(opened.size() == count + 1, "one touch opens %s once (%d)" % [id, opened.size() - count])
	kit.check(Game.busy, "the room waits while %s is open" % id)
	return opened[-1] if opened.size() > count else null


## Walk next to a spot first (a touch from across the room walks there and uses it; the
## tour stands close so each step starts the same way).
func _go_to_spot(id: String) -> void:
	for h: Dictionary in room._hotspots:
		if h.id == id:
			room.leader.position = (h.it as Dictionary).pos + Vector2(0, 2)
			room.leader.target = Vector2.INF
	await kit.frames(3)


func _idle() -> void:
	await kit.until(func() -> bool: return not Game.busy and kit.overlay() == null and not room.vex.speaking, 15.0)
	await kit.wait(0.2)


func _closed_clean(what: String) -> void:
	await kit.until(func() -> bool: return not Game.busy, 8.0)
	kit.check(kit.overlay() == null and not Game.busy, "%s closes and frees the room" % what)
	kit.check(Engine.time_scale == 1.0, "time runs at full speed after %s (%.2f)" % [what, Engine.time_scale])
	await kit.wait(0.4)
	kit.check(kit.main._closing.get_child_count() == 0, "%s is gone after its outro" % what)


# --- input, the way a phone sends it ---------------------------------------------------

func touch(p: Vector2) -> void:
	await touch_down(p)
	await touch_up(p)


func touch_down(p: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = true
	ev.position = p
	Input.parse_input_event(ev)
	await kit.frames(1)


func touch_up(p: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = false
	ev.position = p
	Input.parse_input_event(ev)
	await kit.frames(2)


## A finger pressed at the first overlay point, dragged through the rest, lifted at the last.
func touch_drag(ov: Overlay, points: Array) -> void:
	var prev := _screen(ov.get_global_transform() * (points[0] as Vector2))
	await touch_down(prev)
	for i in range(1, points.size()):
		var a: Vector2 = points[i - 1]
		var b: Vector2 = points[i]
		var n := maxi(1, int(a.distance_to(b) / 5.0))
		for j in n:
			var p := _screen(ov.get_global_transform() * a.lerp(b, float(j + 1) / n))
			var ev := InputEventScreenDrag.new()
			ev.index = 0
			ev.position = p
			ev.relative = p - prev
			Input.parse_input_event(ev)
			prev = p
			await kit.frames(1)
	await touch_up(prev)


func _heard(since: int) -> bool:
	for p: Variant in Sfx._started:
		if int(Sfx._started[p]) >= since:
			return true
	return false


func _screen(p: Vector2) -> Vector2:
	return kit.get_viewport().get_screen_transform() * p


func _world(p: Vector2) -> Vector2:
	var vp := kit.get_viewport()
	return vp.get_screen_transform() * vp.get_canvas_transform() * p


func _ctl(c: Control) -> Vector2:
	return _screen(c.get_global_rect().get_center())


# --- reading state ---------------------------------------------------------------------

## The cents the last machine moved, from what it closed with.
func _moved() -> int:
	var r: Dictionary = last_result if last_result is Dictionary else {}
	return int(r.get("money", {}).get("amount_cents", 0))


func _balance(id: String) -> int:
	for d: Dictionary in Game.state.get("casino", {}).get("destinations", []):
		if str(d.get("id", "")) == id:
			return int(d.get("balance_cents", 0))
	return 0


func _toast(kind: String) -> bool:
	for c in kit.main._toasts.get_children():
		if c is Toast and (c as Toast).kind == kind:
			return true
	return false


func _owned_of(tier: String) -> int:
	var cat := BookOverlay._catalog
	var n := 0
	var owned: Dictionary = Game.state.get("casino", {}).get("owned", {})
	for id: String in owned:
		if cat.has(id) and str(cat[id].tier) == tier and not BookOverlay.is_trophy(cat[id]):
			n += int(owned[id])
	return n


func _fed(ov: BookOverlay, id: String) -> int:
	var n := 0
	for r: Dictionary in ov.rail:
		if r.item_id == id:
			n += 1
	return n


func _count_leaves(ov: BookOverlay) -> int:
	return ov._root.get_children().filter(func(n: Node) -> bool: return n is BookOverlay.Leaf).size()
