extends RefCounted
## Tour: the three side machines, played through their real overlays by taps and drags.
##   1. Scratch: tap the $2 book (Vex counts it), tap it again to buy. Exactly $2 lands in the
##      House Fund, then the ticket tears off and a finger drags across the foil until 60% is
##      gone; the three matching marks light and the cosmetic flies out.
##   2. Wheel: tap the Brokerage mouth, tap the wheel. Exactly $5 lands in the Brokerage, the
##      wheel stops on the wedge the house drew, and that wedge is dark the next time.
##   3. Claw: drag the claw over the best plush, nudge the stick, tap the button. Exactly $5
##      lands; the claw takes the piece the house drew to the chute and it pops out the door.
##   4. Gold replayed through the wheel and through a $5 ticket (tour-only: play() with a
##      stored result, which never moves money) for the cutscenes.
##   5. The week's room spent through the API: the lamp is off, a tap gets "Not this week."
##
##   HOARD_BACKEND=http://127.0.0.1:8203 xvfb-run -a godot --path game --rendering-driver opengl3 \
##     res://dev/tour.tscn -- /tmp/machines-shots res://features/casino/tour_machines.gd

var kit: TourKit
var _catalog: Array = []


func run(k: TourKit) -> void:
	kit = k
	var cat: Array = await Game.api.request("GET", "/casino/catalog")
	_catalog = cat[0].get("items", [])
	await _scratch()
	await _wheel()
	await _claw()
	await _forced_wheel()
	await _forced_near()
	await _forced_ticket()
	await _refused()


# --- 1 ---------------------------------------------------------------------------------

func _scratch() -> void:
	var before := _balance("sav_1")
	var other := _balance("brk_1")
	var box := {"result": null, "closed": false}
	var ov: ScratchOverlay = await _open(ScratchOverlay.new(), box)
	kit.check(ov.dest == "sav_1", "the House Fund mouth is picked first")
	await kit.wait(2.4)
	await kit.shot("m01_scratch_books")
	kit.check(_said_money(ov) == "One to the House Fund.", "Vex states the price and the place: %s" % _said_money(ov))
	await kit.tap_control(ov.book_control(200))
	await kit.wait(1.6)
	kit.check(ov.price == 200, "a tap on the $2 book picks it")
	kit.check(_said_money(ov) == "Two to the House Fund.", "Vex names the $2 book: %s" % _said_money(ov))
	var line := str(Game.state.casino.dealer.before.scratch["200"].sav_1)
	kit.check(_said_odds(ov) == line.substr(line.find(". ") + 2), "then the exact count in the book: %s" % _said_odds(ov))
	kit.check(ov.moment == "choose", "a tap alone moves nothing")
	await kit.shot("m02_scratch_pick")

	await kit.tap_control(ov.book_control(200))
	await kit.until(func() -> bool: return ov.moment == "money", 6.0)
	await kit.wait(0.55)
	await kit.shot("m03_scratch_money")
	await kit.until(func() -> bool: return ov.moment == "scratch", 6.0)
	await kit.wait(0.7)
	await kit.shot("m04_scratch_ticket")
	kit.check(ov.symbols.size() == 9, "nine marks under the foil")

	# A finger scratches across the foil, row by row.
	var r := ov.foil_rect()
	var rows: Array[float] = [10.0, 24.0, 38.0, 52.0, 66.0, 80.0, 94.0, 108.0, 118.0]
	for i in rows.size():
		if ov.moment != "scratch":
			break
		var y := r.position.y + rows[i]
		var a := Vector2(r.position.x + 4, y)
		var b := Vector2(r.end.x - 4, y + 6)
		await _drag(ov, [a, b] if i % 2 == 0 else [b, a])
		if i == 3:
			await kit.shot("m05_scratch_half")
	await kit.until(func() -> bool: return ov.moment != "scratch", 3.0)
	kit.check(ov.coverage >= 0.6, "the rest falls away at 60%% scratched (%.0f%%)" % (ov.coverage * 100.0))
	await kit.until(func() -> bool: return ov.moment == "match", 4.0)
	await kit.wait(0.8)
	await kit.shot("m06_scratch_match")
	var tier := str(ov.result.get("tier", ""))
	kit.check(ov.prize_cells.size() == 3, "three %s marks light" % tier)
	await kit.until(func() -> bool: return ov.moment == "reveal" or box.closed, 6.0)
	await kit.wait(0.7)
	await kit.shot("m07_scratch_reveal")
	await kit.until(func() -> bool: return box.closed, 15.0)

	var res: Dictionary = box.result if box.result is Dictionary else {}
	var money: Dictionary = res.get("money", {})
	kit.check(int(money.get("amount_cents", 0)) == 200, "the ticket moved exactly $2")
	kit.check(str(money.get("to_account", "")) == "sav_1", "into the House Fund")
	kit.check(str(res.get("item", {}).get("tier", "")) == tier, "the prize is the mark that showed three times: %s" % str(res.get("item", {}).get("name", "")))
	await Game.refresh()
	kit.check(_balance("sav_1") - before == 200, "the House Fund is up exactly $2 (%d -> %d)" % [before, _balance("sav_1")])
	kit.check(_balance("brk_1") == other, "the Brokerage is untouched")


# --- 2 ---------------------------------------------------------------------------------

func _wheel() -> void:
	var before := _balance("brk_1")
	var house := _balance("sav_1")
	var box := {"result": null, "closed": false}
	var ov: WheelOverlay = await _open(WheelOverlay.new(), box)
	kit.check(ov.dest == "sav_1", "the last mouth used is picked")
	await kit.wait(2.4)
	await kit.shot("m10_wheel")
	await kit.tap_control(ov.mouth_control("brk_1"))
	await kit.wait(1.4)
	kit.check(ov.dest == "brk_1", "a tap on the Brokerage mouth picks it")
	kit.check(_said_money(ov) == "Five to the Brokerage.", "Vex names the Brokerage: %s" % _said_money(ov))
	kit.check(ov.moment == "choose", "a tap on a mouth moves nothing")
	await kit.shot("m11_wheel_brokerage")
	await kit.tap_control(ov.wheel_control())
	await kit.until(func() -> bool: return ov.moment == "money", 6.0)
	await kit.wait(0.55)
	await kit.shot("m12_wheel_money")
	await kit.until(func() -> bool: return ov.moment == "spin", 6.0)
	await kit.wait(0.6)
	await kit.shot("m13_wheel_fast")
	await kit.wait(2.4)
	await kit.shot("m14_wheel_slowing")
	kit.log_line("  near miss: %s" % ov.near_miss)
	if ov.near_miss != "":
		await kit.until(func() -> bool: return ov.moment in ["near_miss", "pop", "land", "reveal"], 8.0)
		if ov.moment == "near_miss":
			await kit.wait(0.15)
			await kit.shot("m15_wheel_near_miss")
	await kit.until(func() -> bool: return ov.moment == "pop", 10.0)
	await kit.wait(0.25)
	await kit.shot("m16_wheel_landed")
	var k := int(ov.result.get("wedge_index", -1))
	kit.log_line("  spin took %.2fs" % ov.spin_seconds)
	kit.check(ov.landed_index == k, "the pointer rests on wedge %d, the one the house drew (%d)" % [k, ov.landed_index])
	kit.check(ov.spin_seconds > 4.5 and ov.spin_seconds < 9.0, "the spin takes about six seconds (%.2fs)" % ov.spin_seconds)
	await kit.until(func() -> bool: return ov.moment == "reveal" or box.closed, 6.0)
	await kit.wait(0.7)
	await kit.shot("m17_wheel_reveal")
	await kit.until(func() -> bool: return box.closed, 15.0)

	var res: Dictionary = box.result if box.result is Dictionary else {}
	var money: Dictionary = res.get("money", {})
	kit.check(int(money.get("amount_cents", 0)) == 500, "the wheel moved exactly $5")
	kit.check(str(money.get("to_account", "")) == "brk_1", "into the Brokerage")
	kit.check(str(res.get("item", {}).get("tier", "")) == str(res.get("tier", "")), "the cosmetic is the wedge's color")
	await Game.refresh()
	kit.check(_balance("brk_1") - before == 500, "the Brokerage is up exactly $5 (%d -> %d)" % [before, _balance("brk_1")])
	kit.check(_balance("sav_1") == house, "the House Fund is untouched")

	# Open it again: the won wedge is off the wheel (unless gold reset it).
	var box2 := {"result": null, "closed": false}
	var again: WheelOverlay = await _open(WheelOverlay.new(), box2)
	await kit.wait(0.6)
	var reset := bool(res.get("reset", false))
	kit.check(bool(again.wedges[k].taken) != reset, "the won wedge is %s" % ("back after the reset" if reset else "dark until the wheel resets"))
	await kit.shot("m18_wheel_taken")
	await kit.tap_screen(_screen(again, Vector2(30, 250)))
	await kit.until(func() -> bool: return box2.closed, 3.0)
	kit.check(box2.result == null, "a tap outside the machine closes it with nothing")


# --- 3 ---------------------------------------------------------------------------------

func _claw() -> void:
	var before := _balance("brk_1")
	var box := {"result": null, "closed": false}
	var ov: ClawOverlay = await _open(ClawOverlay.new(), box)
	kit.check(ov.dest == "brk_1", "the last mouth used is picked")
	await kit.wait(2.4)
	await kit.shot("m20_claw")
	var heap: Array = Game.state.casino.claw.heap
	kit.check(ov.plushes.size() == heap.size(), "the glass holds the heap from the house: %d" % heap.size())
	var best: Dictionary = heap[0]
	for p: Dictionary in heap:
		if MachineOverlay.TIERS.find(str(p.tier)) > MachineOverlay.TIERS.find(str(best.tier)):
			best = p
	var aim := ClawOverlay.spot(float(best.x), float(best.y))
	await _drag(ov, [Vector2(ov.claw_x + 6, 120), Vector2(lerpf(ov.claw_x, aim.x, 0.5), 124), Vector2(aim.x, 128)])
	await kit.wait(1.2)
	kit.check(absf(ov.claw_x - aim.x) < 2.0, "dragging on the glass moves the claw over the %s plush" % str(best.tier))
	await kit.shot("m21_claw_aimed")
	var at := ov.claw_x
	await kit.tap_screen(_screen(ov, ClawOverlay.STICK + Vector2(12, 0)))
	await kit.wait(0.4)
	kit.check(ov.claw_x > at + 4.0, "a tap on the stick's right side nudges it right")
	var right := ov.claw_x
	await kit.tap_screen(_screen(ov, ClawOverlay.STICK + Vector2(-12, 0)))
	await kit.wait(0.4)
	kit.check(absf(ov.claw_x - at) < 3.0, "and the left side nudges it back (%.1f -> %.1f -> %.1f)" % [at, right, ov.claw_x])

	await kit.tap_control(ov.button_control())
	await kit.until(func() -> bool: return ov.moment == "money", 6.0)
	await kit.wait(0.55)
	await kit.shot("m22_claw_money")
	await kit.until(func() -> bool: return ov.moment == "drop", 6.0)
	await kit.wait(0.8)
	await kit.shot("m23_claw_drop")
	await kit.until(func() -> bool: return ov.moment == "grab", 6.0)
	await kit.wait(0.2)
	await kit.shot("m24_claw_grab")
	await kit.until(func() -> bool: return ov.moment == "shudder", 6.0)
	await kit.wait(0.25)
	await kit.shot("m25_claw_shudder")
	await kit.until(func() -> bool: return ov.moment == "carry", 6.0)
	await kit.wait(0.45)
	await kit.shot("m26_claw_carry")
	await kit.until(func() -> bool: return ov.moment == "door", 6.0)
	await kit.wait(0.4)
	await kit.shot("m27_claw_door")
	await kit.until(func() -> bool: return ov.moment == "reveal" or box.closed, 6.0)
	await kit.wait(0.7)
	await kit.shot("m28_claw_reveal")
	var dropped_at := ov.drop_x
	await kit.until(func() -> bool: return box.closed, 15.0)

	var res: Dictionary = box.result if box.result is Dictionary else {}
	var money: Dictionary = res.get("money", {})
	var grabbed: Dictionary = res.get("grabbed", {})
	kit.check(int(money.get("amount_cents", 0)) == 500, "the claw moved exactly $5")
	kit.check(absf(dropped_at - float(best.x)) < 0.02, "drop_x is where the claw was (%.3f, aimed %.3f)" % [dropped_at, float(best.x)])
	var took: Dictionary = {}
	for p: Dictionary in heap:
		if int(p.slot_index) == int(grabbed.get("slot_index", -1)):
			took = p
	kit.check(not took.is_empty() and absf(float(took.get("x", 9.0)) - dropped_at) < 0.1, "it took a piece under the drop: slot %s (%s)" % [str(grabbed.get("slot_index", "")), str(grabbed.get("tier", ""))])
	kit.check(str(res.get("item", {}).get("tier", "")) == str(grabbed.get("tier", "")), "the cosmetic is the plush's color")
	await Game.refresh()
	kit.check(_balance("brk_1") - before == 500, "the Brokerage is up exactly $5 (%d -> %d)" % [before, _balance("brk_1")])
	var still := false
	for p: Dictionary in Game.state.casino.claw.heap:
		if int(p.slot_index) == int(grabbed.get("slot_index", -1)):
			still = true
	kit.check(not still or Game.state.casino.claw.heap.size() == 15, "the piece left the glass")


# --- 4 ---------------------------------------------------------------------------------

func _forced_wheel() -> void:
	var item := _first("legendary")
	var box := {"result": null, "closed": false}
	var ov: WheelOverlay = await _open(WheelOverlay.new(), box)
	await kit.wait(0.6)
	var k := -1
	for i in ov.wedges.size():
		if str(ov.wedges[i].tier) == "legendary" and not bool(ov.wedges[i].taken):
			k = i
	if not kit.check(k >= 0 and not item.is_empty(), "a gold wedge on the wheel to replay"):
		return
	var fresh: Array = []
	for w: Dictionary in ov.wedges:
		fresh.append({"tier": w.tier, "taken": false})
	ov.play({"wedge_index": k, "tier": "legendary", "item": item, "reset": true, "wedges": fresh})
	await kit.until(func() -> bool: return ov.moment == "pop", 12.0)
	await kit.wait(0.2)
	await kit.shot("m30_gold_wedge")
	await kit.until(func() -> bool: return ov.moment == "cutscene", 8.0)
	await kit.wait(0.45)
	await kit.shot("m31_gold_dark")
	await kit.wait(0.8)
	await kit.shot("m32_gold_spin")
	await kit.wait(0.85)
	await kit.shot("m33_gold_landed")
	await kit.until(func() -> bool: return ov.moment == "reset", 10.0)
	await kit.wait(0.35)
	await kit.shot("m34_gold_reset")
	await kit.until(func() -> bool: return box.closed, 10.0)
	kit.check(box.closed, "the gold cutscene ends, the wheel relights, and it closes")


## A grey wedge next to the gold one, replayed with the near miss always staged: the wheel
## hangs on the peg by the gold, then settles on grey.
func _forced_near() -> void:
	var box := {"result": null, "closed": false}
	var ov: WheelOverlay = await _open(WheelOverlay.new(), box)
	await kit.wait(0.6)
	var k := -1
	for i in ov.wedges.size():
		var after: Dictionary = ov.wedges[(i + 11) % 12]
		if str(ov.wedges[i].tier) == "common" and str(after.tier) == "legendary":
			k = i
	if not kit.check(k >= 0, "a grey wedge just before the gold one"):
		return
	# Tour-only and display-only: if the real pull took that wedge, put it back for the replay.
	ov.wedges[k].taken = false
	ov.near_chance = 1.0
	ov.play({"wedge_index": k, "tier": "common", "item": _first("common"), "reset": false})
	await kit.until(func() -> bool: return ov.moment == "near_miss", 12.0)
	await kit.wait(0.2)
	await kit.shot("m35_near_miss")
	kit.check(ov.near_miss == "short", "it stops just short of the gold")
	await kit.until(func() -> bool: return ov.moment == "pop", 6.0)
	kit.check(ov.landed_index == k, "and lands on the grey wedge it was always going to (%d)" % ov.landed_index)
	await kit.shot("m36_near_landed")
	await kit.until(func() -> bool: return box.closed, 12.0)


func _forced_ticket() -> void:
	var item := _first("legendary")
	var box := {"result": null, "closed": false}
	var ov: ScratchOverlay = await _open(ScratchOverlay.new(), box)
	await kit.wait(0.4)
	await kit.tap_control(ov.book_control(500))
	await kit.wait(1.2)
	kit.check(ov.price == 500, "the $5 book is picked")
	await kit.shot("m40_five_book")
	var marks := ["legendary", "rare", "epic", "common", "legendary", "epic", "rare", "common", "legendary"]
	ov.play({"tier": "legendary", "item": item, "symbols": marks, "book": {"price_cents": 500, "size": 20, "left": {"common": 12, "rare": 5, "epic": 2}}})
	await kit.until(func() -> bool: return ov.moment == "scratch", 6.0)
	var r := ov.foil_rect()
	# Uncover the top row first: two gold, and the heart starts.
	await _drag(ov, [Vector2(r.position.x + 4, r.position.y + 14), Vector2(r.end.x - 4, r.position.y + 18)])
	await _drag(ov, [Vector2(r.end.x - 4, r.position.y + 26), Vector2(r.position.x + 4, r.position.y + 24)])
	await _drag(ov, [Vector2(r.position.x + 4, r.position.y + 54), Vector2(r.end.x - 4, r.position.y + 58)])
	await _drag(ov, [Vector2(r.end.x - 4, r.position.y + 66), Vector2(r.position.x + 4, r.position.y + 64)])
	await kit.wait(0.2)
	await kit.shot("m41_five_tense")
	for y: float in [86.0, 100.0, 112.0, 120.0, 40.0, 8.0]:
		if ov.moment != "scratch":
			break
		await _drag(ov, [Vector2(r.position.x + 4, r.position.y + y), Vector2(r.end.x - 4, r.position.y + y + 4)])
	await kit.until(func() -> bool: return ov.moment == "match", 6.0)
	await kit.wait(0.85)
	await kit.shot("m42_five_match")
	await kit.until(func() -> bool: return ov.moment == "cutscene", 8.0)
	await kit.wait(1.3)
	await kit.shot("m43_five_cutscene")
	await kit.until(func() -> bool: return box.closed, 12.0)
	kit.check(box.closed, "the ticket's gold cutscene ends and it closes")


# --- 5 ---------------------------------------------------------------------------------

func _refused() -> void:
	# Spend the rest of the week's room on this scratch save, straight through the API.
	for case_id: String in ["case_50", "case_20", "case_10"]:
		for i in 60:
			var r: Array = await Game.api.request("POST", "/casino/case", {}, {"case_id": case_id, "to_account": "sav_1"})
			if r[1] != "":
				break
	for p: int in [500, 200, 100]:
		for i in 60:
			var r: Array = await Game.api.request("POST", "/casino/scratch", {}, {"price_cents": p, "to_account": "sav_1"})
			if r[1] != "":
				break
	await Game.refresh()
	var before := _balance("sav_1")
	var other := _balance("brk_1")
	var box := {"result": null, "closed": false}
	var ov: WheelOverlay = await _open(WheelOverlay.new(), box)
	await kit.wait(0.8)
	kit.check(not ov.lamp_on(), "with the week's room spent, the lamp over the slot is already off")
	await kit.tap_control(ov.wheel_control())
	await kit.until(func() -> bool: return ov.moment == "refused", 6.0)
	await kit.wait(1.0)
	await kit.shot("m50_refused")
	kit.check(ov.said.size() > 0 and ov.said[-1] == "Not this week.", "Vex says it: %s" % (ov.said[-1] if ov.said.size() > 0 else ""))
	await kit.until(func() -> bool: return box.closed, 8.0)
	kit.check(box.result == null, "a refused pull closes with nothing")
	await Game.refresh()
	kit.check(_balance("sav_1") == before and _balance("brk_1") == other, "nothing moved")


# --- helpers ---------------------------------------------------------------------------

func _open(ov: Overlay, box: Dictionary) -> Overlay:
	ov.closed.connect(func(r: Variant) -> void:
		box.result = r
		box.closed = true
	)
	kit.main.open_overlay(ov)
	await kit.wait(0.5)
	return ov


## A room point (480x270) on screen, for this overlay.
func _screen(ov: Overlay, p: Vector2) -> Vector2:
	return kit.get_viewport().get_screen_transform() * (ov.get_global_transform() * p)


## A finger pressed at the first point, dragged through the rest, lifted at the last.
func _drag(ov: Overlay, points: Array) -> void:
	var start := _screen(ov, points[0])
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	down.position = start
	down.global_position = start
	Input.parse_input_event(down)
	await kit.frames(1)
	var prev: Vector2 = points[0]
	for i in range(1, points.size()):
		var a: Vector2 = points[i - 1]
		var b: Vector2 = points[i]
		var n := maxi(1, int(a.distance_to(b) / 5.0))
		for j in n:
			var p := a.lerp(b, float(j + 1) / n)
			var mm := InputEventMouseMotion.new()
			mm.button_mask = MOUSE_BUTTON_MASK_LEFT
			mm.position = _screen(ov, p)
			mm.global_position = mm.position
			mm.relative = _screen(ov, p) - _screen(ov, prev)
			Input.parse_input_event(mm)
			prev = p
			await kit.frames(1)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = _screen(ov, prev)
	up.global_position = up.position
	Input.parse_input_event(up)
	await kit.frames(2)


func _first(tier: String) -> Dictionary:
	for i: Dictionary in _catalog:
		if str(i.get("tier", "")) == tier:
			return i
	return {}


## The last money half of what Vex said ("Two to the House Fund.").
func _said_money(ov: MachineOverlay) -> String:
	for i in range(ov.said.size() - 1, -1, -1):
		if " to the " in ov.said[i]:
			return ov.said[i]
	return ""


## The counts half that followed it.
func _said_odds(ov: MachineOverlay) -> String:
	for i in range(ov.said.size() - 1, -1, -1):
		if " to the " not in ov.said[i]:
			return ov.said[i]
	return ""


func _balance(id: String) -> int:
	for d: Dictionary in Game.state.get("casino", {}).get("destinations", []):
		if str(d.get("id", "")) == id:
			return int(d.get("balance_cents", 0))
	return 0
