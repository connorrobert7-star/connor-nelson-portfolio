extends RefCounted
## Tour: the three pot machines (docs/POT.md), played through their real overlays by taps and
## drags.
##   1. No pick yet: the plate is blank, the lamp is off, Vex says where to go, and a tap on a
##      book is refused with nothing moved.
##   2. At Marlo's: a tap on the VTI shelf pins it (the brass plate drops on its tag), back to
##      the casino, and the $1 book is played ticket by ticket, scratched by a finger, until a blank and a hit have
##      both come: each pull moves exactly $1 into the Brokerage, a blank shows no triple and a
##      coin drops into the jar, a hit blazes the last lamp and pours the jar into the pick's
##      creature before the cosmetic.
##   3. Wheel: tap the wheel; a blank stops on a dud sliver.
##   4. Claw: aim and press; a blank grab slips and the piece stays in the heap.
##   5. Gold replayed through the wheel and a $5 ticket (tour-only: play() with a stored result,
##      which never moves money) for the cutscenes.
##   6. The week's room spent through the API: the lamp is off, a tap gets "Not this week."
##
##   HOARD_BACKEND=http://127.0.0.1:8304 xvfb-run -a godot --path game --rendering-driver opengl3 \
##     res://dev/tour.tscn -- /tmp/pot-shots res://features/casino/tour_machines.gd

var kit: TourKit
var _catalog: Array = []
var _blank_seen := false
var _hit_seen := false


func run(k: TourKit) -> void:
	kit = k
	var cat: Array = await Game.api.request("GET", "/casino/catalog")
	_catalog = cat[0].get("items", [])
	await _no_pick()
	await _pin_at_the_counter("VTI")
	await _scratch_run()
	await _wheel()
	await _claw()
	await _forced_wheel()
	await _forced_ticket()
	await _refused()


# --- 1 ---------------------------------------------------------------------------------

func _no_pick() -> void:
	var before := _balance("brk_1")
	var box := {"result": null, "closed": false}
	var ov: ScratchOverlay = await _open(ScratchOverlay.new(), box)
	await kit.wait(2.6)
	await kit.shot("p01_no_pick")
	kit.check(ov.dest == "brk_1" and ov.mouth_control("sav_1") == null, "a pot machine pays into the Brokerage only: no House Fund mouth")
	kit.check(ov.plate != null and ov.plate.symbol == "", "the brass plate is blank with no pick")
	kit.check(not ov.lamp_on(), "the lamp is off with no pick")
	kit.check(_said_has(ov, "Pick a stock at Marlo's counter first."), "Vex says where to go: %s" % " | ".join(ov.said))
	await kit.tap_control(ov.book_control(100))
	await kit.wait(0.4)
	await kit.tap_control(ov.book_control(100))
	await kit.until(func() -> bool: return ov.moment == "refused", 6.0)
	await kit.wait(0.9)
	await kit.shot("p02_no_pick_refused")
	kit.check(ov.said.size() > 0 and ov.said[-1] == "Pick a stock at Marlo's counter first.", "the pull is refused: %s" % (ov.said[-1] if ov.said.size() > 0 else ""))
	await kit.until(func() -> bool: return box.closed, 8.0)
	await Game.refresh()
	kit.check(_balance("brk_1") == before, "nothing moved")


# --- 2 ---------------------------------------------------------------------------------

func _pin_at_the_counter(symbol: String) -> void:
	await kit.go_to("shop", Room.ENTRANCE)
	var shop := kit.level() as ShopRoom
	if not kit.check(shop != null, "the shop opens"):
		return
	var tag: ShopRoom.PriceTag = null
	for n: Node in shop.dynamic.get_children():
		if n is ShopRoom.PriceTag and (n as ShopRoom.PriceTag).symbol == symbol:
			tag = n
	if not kit.check(tag != null, "%s has a shelf" % symbol):
		return
	kit.check(not tag.pinned, "nothing is pinned yet")
	await kit.tap_world(tag.position + Vector2(0, -24))
	await kit.until(func() -> bool: return ShopRoom.pick_symbol() == symbol, 12.0)
	await kit.wait(0.15)
	await kit.shot("p00a_counter_plate_drops")
	await kit.wait(0.9)
	await kit.shot("p00b_counter_pinned")
	kit.check(ShopRoom.pick_symbol() == symbol, "a tap on the shelf pins %s as the pick" % symbol)
	var pinned := 0
	for n: Node in (kit.level() as ShopRoom).dynamic.get_children():
		if n is ShopRoom.PriceTag and (n as ShopRoom.PriceTag).pinned:
			pinned += 1
	kit.check(pinned == 1, "exactly one tag carries the brass plate")
	kit.check(str(CasinoPot.pick().get("symbol", "")) == symbol, "the casino's pot knows the pick")
	await kit.go_to("casino", Room.ENTRANCE)


func _scratch_run() -> void:
	for pull in 9:
		if _blank_seen and _hit_seen:
			break
		await _scratch_once(pull)
	kit.check(_blank_seen and _hit_seen, "the $1 run gave a blank and a hit within its lamps")


func _scratch_once(pull: int) -> void:
	var before := _balance("brk_1")
	var house := _balance("sav_1")
	var pot_before := int(CasinoPot.pot().get("total_cents", 0))
	var run_before: Dictionary = CasinoPot.run("scratch_100")
	var box := {"result": null, "closed": false}
	var ov: ScratchOverlay = await _open(ScratchOverlay.new(), box)
	await kit.wait(1.6)
	if ov.price != 100:
		await kit.tap_control(ov.book_control(100))
		await kit.wait(1.4)
	kit.check(ov.lamp_on(), "pull %d: the lamp is on" % pull)
	kit.check(ov.lamps.left == int(run_before.get("left", -1)), "the run's lamps show %d of %d lit" % [ov.lamps.left, ov.lamps.count])
	kit.check(ov.jar.cents == pot_before, "the jar shows the pot: %s" % CasinoPot.dollars(ov.jar.cents))
	if pull == 0:
		await kit.shot("p03_scratch_ready")
	await kit.tap_control(ov.book_control(100))
	await kit.until(func() -> bool: return ov.moment == "scratch", 8.0)
	var r := ov.foil_rect()
	for y: float in [10.0, 30.0, 50.0, 70.0, 90.0, 110.0, 120.0, 20.0, 60.0, 100.0]:
		if ov.moment != "scratch":
			break
		await _drag(ov, [Vector2(r.position.x + 4, r.position.y + y), Vector2(r.end.x - 4, r.position.y + y + 6)])
	var hit := bool(ov.result.get("hit", false))
	var jar_said := -1
	if not hit:
		await _at(ov, ["blank_ticket", "blank", "pot"], 6.0)
		var shown: Dictionary = {}
		for t: String in ov.symbols:
			if t != "dud":
				shown[t] = int(shown.get(t, 0)) + 1
		var triple := false
		for t: String in shown:
			triple = triple or int(shown[t]) >= 3
		kit.check(not triple, "a blank ticket shows no mark three times: %s" % ",".join(ov.symbols))
		if not _blank_seen:
			await kit.wait(0.3)
			await kit.shot("p04_scratch_blank_ticket")
			await _at(ov, ["blank", "pot"], 4.0)
			await kit.wait(0.25)
			await kit.shot("p05_scratch_coin_drops")
		await _at(ov, ["pot"], 6.0)
		if is_instance_valid(ov):
			jar_said = ov.jar.cents
			if not _blank_seen:
				await kit.wait(0.3)
				await kit.shot("p06_scratch_pot")
		await kit.until(func() -> bool: return box.closed, 10.0)
		var res: Dictionary = box.result if box.result is Dictionary else {}
		kit.check(res.get("item") == null, "a blank grants nothing")
		var after := int(res.get("pot", {}).get("total_cents", -1))
		kit.check(after == pot_before + 100, "the pot grew by exactly $1 (%s -> %s)" % [CasinoPot.dollars(pot_before), CasinoPot.dollars(after)])
		kit.check(jar_said == after, "the jar's number is the pot: %s" % CasinoPot.dollars(jar_said))
		_blank_seen = true
	else:
		await _at(ov, ["hit"], 10.0)
		await kit.wait(0.15)
		await kit.shot("p07_scratch_hit_blaze")
		await _at(ov, ["pour"], 4.0)
		await kit.wait(0.35)
		await kit.shot("p08_scratch_pour")
		await _at(ov, ["poured"], 6.0)
		await kit.wait(0.2)
		await kit.shot("p09_scratch_poured")
		await _at(ov, ["reveal", "closed"], 8.0)
		await kit.wait(0.7)
		await kit.shot("p10_scratch_reveal")
		await kit.until(func() -> bool: return box.closed, 15.0)
		var res: Dictionary = box.result if box.result is Dictionary else {}
		var bought: Dictionary = res.get("pot", {}).get("bought", {})
		kit.check(str(bought.get("symbol", "")) == "VTI", "the hit bought the pick: %s" % str(bought.get("symbol", "")))
		kit.check(int(bought.get("amount_cents", 0)) == pot_before + 100, "with the whole pot plus the pull: %s" % CasinoPot.dollars(int(bought.get("amount_cents", 0))))
		kit.check(int(res.get("pot", {}).get("total_cents", -1)) == 0, "and the pot is empty after")
		kit.check(res.get("item") is Dictionary, "a hit drops a cosmetic: %s" % str(res.get("item", {}).get("name", "")))
		_hit_seen = true
	var money: Dictionary = (box.result if box.result is Dictionary else {}).get("money", {})
	kit.check(int(money.get("amount_cents", 0)) == 100 and str(money.get("to_account", "")) == "brk_1", "pull %d moved exactly $1 into the Brokerage" % pull)
	await Game.refresh()
	kit.check(_balance("brk_1") - before == 100, "the Brokerage is up exactly $1 (%d -> %d)" % [before, _balance("brk_1")])
	kit.check(_balance("sav_1") == house, "the House Fund is untouched")


# --- 3 ---------------------------------------------------------------------------------

func _wheel() -> void:
	for pull in 3:
		var before := _balance("brk_1")
		var box := {"result": null, "closed": false}
		var ov: WheelOverlay = await _open(WheelOverlay.new(), box)
		await kit.wait(2.0)
		if pull == 0:
			await kit.shot("p11_wheel")
			kit.check(_said_has(ov, "lamps.") or _said_has(ov, "One lamp."), "Vex names the run: %s" % " | ".join(ov.said))
		await kit.tap_control(ov.wheel_control())
		await kit.until(func() -> bool: return ov.moment == "spin", 8.0)
		await _at(ov, ["dud", "pop"], 14.0)
		var hit := bool(ov.result.get("hit", false))
		if not hit:
			await kit.wait(0.2)
			await kit.shot("p12_wheel_dud")
			var d := int(ov.result.get("dud_index", -1))
			kit.check(ov.landed_dud == d, "a blank stops on dud sliver %d" % d)
			await _at(ov, ["pot"], 6.0)
			await kit.wait(0.4)
			await kit.shot("p13_wheel_pot")
		await kit.until(func() -> bool: return box.closed, 20.0)
		await Game.refresh()
		kit.check(_balance("brk_1") - before == 500, "the wheel moved exactly $5 into the Brokerage (%s)" % ("hit" if hit else "blank"))
		if not hit:
			return


# --- 4 ---------------------------------------------------------------------------------

func _claw() -> void:
	for pull in 3:
		var before := _balance("brk_1")
		var box := {"result": null, "closed": false}
		var ov: ClawOverlay = await _open(ClawOverlay.new(), box)
		await kit.wait(1.6)
		var heap: Array = Game.state.casino.claw.heap
		var aim := ClawOverlay.spot(float(heap[0].x), float(heap[0].y))
		await _drag(ov, [Vector2(ov.claw_x + 6, 120), Vector2(aim.x, 128)])
		await kit.wait(1.0)
		if pull == 0:
			await kit.shot("p20_claw")
		await kit.tap_control(ov.button_control())
		await _at(ov, ["grab"], 10.0)
		var hit := bool(ov.result.get("hit", false))
		if not hit:
			await _at(ov, ["slip"], 6.0)
			await kit.wait(0.12)
			await kit.shot("p21_claw_slip")
			await _at(ov, ["pot"], 6.0)
			await kit.wait(0.4)
			await kit.shot("p22_claw_pot")
		await kit.until(func() -> bool: return box.closed, 20.0)
		var res: Dictionary = box.result if box.result is Dictionary else {}
		await Game.refresh()
		kit.check(_balance("brk_1") - before == 500, "the claw moved exactly $5 into the Brokerage (%s)" % ("hit" if hit else "blank"))
		if not hit:
			var slot := int(res.get("grabbed", {}).get("slot_index", -1))
			var still := false
			for p: Dictionary in Game.state.casino.claw.heap:
				still = still or int(p.slot_index) == slot
			kit.check(still and res.get("grabbed", {}).get("held") == false, "the slipped piece stays in the heap (slot %d)" % slot)
			return


# --- 5 ---------------------------------------------------------------------------------

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
	ov.play({"hit": true, "wedge_index": k, "tier": "legendary", "item": item, "reset": true, "wedges": fresh, "pot": _replay_pot(500), "run": CasinoPot.run("wheel")})
	await kit.until(func() -> bool: return ov.moment == "pop", 12.0)
	await kit.wait(0.2)
	await kit.shot("p30_gold_wedge")
	await kit.until(func() -> bool: return ov.moment == "cutscene", 8.0)
	await kit.wait(0.45)
	await kit.shot("p31_gold_dark")
	await kit.wait(0.8)
	await kit.shot("p32_gold_spin")
	await kit.wait(0.85)
	await kit.shot("p33_gold_landed")
	await kit.until(func() -> bool: return ov.moment == "reset", 10.0)
	await kit.wait(0.35)
	await kit.shot("p34_gold_reset")
	await kit.until(func() -> bool: return box.closed, 10.0)
	kit.check(box.closed, "the gold cutscene ends, the wheel relights, and it closes")


func _forced_ticket() -> void:
	var item := _first("legendary")
	var box := {"result": null, "closed": false}
	var ov: ScratchOverlay = await _open(ScratchOverlay.new(), box)
	await kit.wait(0.4)
	await kit.tap_control(ov.book_control(500))
	await kit.wait(1.2)
	kit.check(ov.price == 500, "the $5 book is picked")
	await kit.shot("p40_five_book")
	var marks := ["legendary", "rare", "epic", "common", "legendary", "epic", "rare", "common", "legendary"]
	ov.play({"hit": true, "tier": "legendary", "item": item, "symbols": marks, "book": {"price_cents": 500, "size": 20, "left": {"common": 12, "rare": 5, "epic": 2}}, "pot": _replay_pot(500), "run": CasinoPot.run("scratch_500")})
	await kit.until(func() -> bool: return ov.moment == "scratch", 6.0)
	var r := ov.foil_rect()
	# Uncover the top row first: two gold, and the heart starts.
	await _drag(ov, [Vector2(r.position.x + 4, r.position.y + 14), Vector2(r.end.x - 4, r.position.y + 18)])
	await _drag(ov, [Vector2(r.end.x - 4, r.position.y + 26), Vector2(r.position.x + 4, r.position.y + 24)])
	await _drag(ov, [Vector2(r.position.x + 4, r.position.y + 54), Vector2(r.end.x - 4, r.position.y + 58)])
	await _drag(ov, [Vector2(r.end.x - 4, r.position.y + 66), Vector2(r.position.x + 4, r.position.y + 64)])
	await kit.wait(0.2)
	await kit.shot("p41_five_tense")
	for y: float in [86.0, 100.0, 112.0, 120.0, 40.0, 8.0]:
		if ov.moment != "scratch":
			break
		await _drag(ov, [Vector2(r.position.x + 4, r.position.y + y), Vector2(r.end.x - 4, r.position.y + y + 4)])
	await kit.until(func() -> bool: return ov.moment == "match", 6.0)
	await kit.wait(0.85)
	await kit.shot("p42_five_match")
	await kit.until(func() -> bool: return ov.moment == "cutscene", 8.0)
	await kit.wait(1.3)
	await kit.shot("p43_five_cutscene")
	await kit.until(func() -> bool: return box.closed, 12.0)
	kit.check(box.closed, "the ticket's gold cutscene ends and it closes")


# --- 6 ---------------------------------------------------------------------------------

func _refused() -> void:
	# Spend the rest of the week's room on this scratch save, straight through the API.
	for case_id: String in ["case_50", "case_20", "case_10"]:
		for i in 60:
			var r: Array = await Game.api.request("POST", "/casino/case", {}, {"case_id": case_id, "to_account": "sav_1"})
			if r[1] != "":
				break
	for p: int in [500, 200, 100]:
		for i in 60:
			var r: Array = await Game.api.request("POST", "/casino/scratch", {}, {"price_cents": p})
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
	await kit.shot("p50_refused")
	kit.check(ov.said.size() > 0 and ov.said[-1] == "Not this week.", "Vex says it: %s" % (ov.said[-1] if ov.said.size() > 0 else ""))
	await kit.until(func() -> bool: return box.closed, 8.0)
	kit.check(box.result == null, "a refused pull closes with nothing")
	await Game.refresh()
	kit.check(_balance("sav_1") == before and _balance("brk_1") == other, "nothing moved")


# --- helpers ---------------------------------------------------------------------------

## A display-only pot for a replayed hit: the real pot and pick from /state, so the jar shows
## true numbers. The replay never calls the API.
func _replay_pot(price: int) -> Dictionary:
	var total := int(CasinoPot.pot().get("total_cents", 0))
	return {"before_cents": total, "added_cents": price, "total_cents": 0,
		"bought": {"symbol": str(CasinoPot.pick().get("symbol", "")), "amount_cents": total + price, "pick": CasinoPot.pick()}}


## Wait until the overlay reaches one of `moments` (or is gone).
func _at(ov: MachineOverlay, moments: Array, timeout: float) -> void:
	await kit.until(func() -> bool: return not is_instance_valid(ov) or ov.moment in moments or ov.moment == "closed", timeout)


func _said_has(ov: MachineOverlay, text: String) -> bool:
	for line in ov.said:
		if text in line:
			return true
	return false


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
