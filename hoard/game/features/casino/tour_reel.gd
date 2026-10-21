extends RefCounted
## Tour: the case reel, played through the real overlay by taps and a held press.
##   1. A $20 case into the House Fund: tap the Brokerage mouth, tap back, hold the bill on
##      the slot. Shots of the hold, the money landing, mid-reel, the near miss, the reveal.
##      Checks that exactly $20 landed in the House Fund.
##   2. A $10 case into the Brokerage, skipped by a tap after the first second.
##   3. Purple, gold and red pulls replayed through the reel (tour-only: a stored reel with its winner
##      swapped, fed to CaseOverlay.play, which never moves money) for the cutscenes.
##   4. The week's room spent through the API, then a pull: the lamp goes off, "Not this week."
##
##   xvfb-run -a godot --path game --rendering-driver opengl3 res://dev/tour.tscn -- /tmp/reel-shots res://features/casino/tour_reel.gd

var kit: TourKit
var _reel: Array = []
var _full_seconds := 0.0


func run(k: TourKit) -> void:
	kit = k
	await _full_pull()
	await _skipped_pull()
	await _forced("epic", "reel_15")
	await _forced("legendary", "reel_16")
	await _forced("mythic", "reel_20")
	await _refused()


# --- 1 -------------------------------------------------------------------------------

func _full_pull() -> void:
	var before := _balance("sav_1")
	var other := _balance("brk_1")
	var box := {"result": null, "closed": false}
	var ov := await _open("case_20", box)
	kit.check(ov.dest == "sav_1", "the House Fund mouth is picked first")
	await kit.wait(2.8)
	await kit.shot("reel_01_machine")
	kit.check(_money_line(ov) == "Twenty to the House Fund.", "the dealer states the price and the place: %s" % _money_line(ov))
	var line := str(Game.state.casino.dealer.before.case.case_20.sav_1)
	var counts := line.substr(line.find(". ") + 2)
	kit.check(_odds_line(ov) == counts, "then the exact counts the house holds: %s" % _odds_line(ov))

	await kit.tap_control(ov.mouth_control("brk_1"))
	await kit.wait(1.0)
	kit.check(ov.dest == "brk_1", "a tap on the Brokerage mouth picks it")
	kit.check(_money_line(ov) == "Twenty to the Brokerage.", "the dealer names the Brokerage: %s" % _money_line(ov))
	kit.check(ov.moment == "choose", "a tap alone moves nothing")
	await kit.shot("reel_02_brokerage")

	await kit.tap_control(ov.mouth_control("sav_1"))
	await kit.wait(0.3)
	kit.check(ov.dest == "sav_1", "a tap on the House Fund mouth picks it back")

	# Press and hold the bill on the slot.
	var up := _press(ov.mouth_control("sav_1"))
	await kit.wait(0.25)
	kit.check(ov.moment == "hold", "holding fills the ring")
	await kit.shot("reel_03_hold")
	await kit.wait(0.3)
	Input.parse_input_event(up)
	await kit.until(func() -> bool: return ov.moment == "money", 6.0)
	await kit.wait(0.5)
	await kit.shot("reel_04_money")
	await kit.until(func() -> bool: return ov.moment == "reel", 6.0)
	_reel = ov.result.get("reel", [])
	await kit.wait(0.6)
	await kit.shot("reel_05_fast")
	await kit.wait(1.0)
	await kit.shot("reel_06_braking")
	var near := str(ov.result.get("near_miss", "")) if ov.result.get("near_miss") != null else ""
	kit.log_line("  near miss: %s %s" % [near, str(ov.result.get("near_miss_tier", ""))])
	if near != "":
		await kit.until(func() -> bool: return ov.moment in ["near_miss", "land", "reveal"], 12.0)
		await kit.wait(0.12)
		kit.check(ov.moment == "near_miss", "the line sits on the %s card" % str(ov.result.get("near_miss_tier", "")))
		await kit.shot("reel_07_near_miss")
	await kit.until(func() -> bool: return ov.moment == "reveal" or box.closed, 14.0)
	kit.log_line("  reel ran %.2fs real time" % ov.reel_seconds)
	_full_seconds = ov.reel_seconds
	kit.check(ov.reel_seconds > 5.0 and ov.reel_seconds < 8.5, "the reel takes about six to seven seconds (%.2fs)" % ov.reel_seconds)
	await kit.wait(0.1)
	await kit.shot("reel_08_flash")
	await kit.wait(0.8)
	await kit.shot("reel_09_reveal")
	await kit.until(func() -> bool: return box.closed, 15.0)

	var res: Dictionary = box.result if box.result is Dictionary else {}
	var money: Dictionary = res.get("money", {})
	kit.check(int(money.get("amount_cents", 0)) == 2000, "the case moved exactly $20")
	kit.check(str(money.get("to_account", "")) == "sav_1", "into the House Fund")
	kit.check(str(res.get("item", {}).get("tier", "")) != "", "a cosmetic came out: %s" % str(res.get("item", {}).get("name", "")))
	await Game.refresh()
	kit.check(_balance("sav_1") - before == 2000, "the House Fund is up exactly $20 (%d -> %d)" % [before, _balance("sav_1")])
	kit.check(_balance("brk_1") == other, "the Brokerage is untouched")
	await kit.wait(0.3)


# --- 2 -------------------------------------------------------------------------------

func _skipped_pull() -> void:
	var before := _balance("brk_1")
	var box := {"result": null, "closed": false}
	var ov := await _open("case_10", box)
	kit.check(ov.dest == "sav_1", "the last mouth used is picked")
	var up := _press(ov.mouth_control("brk_1"))
	await kit.wait(0.6)
	Input.parse_input_event(up)
	await kit.until(func() -> bool: return ov.moment == "money", 6.0)
	await kit.wait(0.5)
	await kit.shot("reel_10_brokerage_money")
	await kit.until(func() -> bool: return ov.moment == "reel", 6.0)
	await kit.wait(0.4)
	await kit.tap_control(ov)
	await kit.wait(0.1)
	kit.check(ov.moment != "land" and ov.moment != "reveal", "a tap in the first second does nothing")
	await kit.wait(0.7)
	var start := Time.get_ticks_msec()
	await kit.tap_control(ov)
	await kit.until(func() -> bool: return ov.moment in ["land", "reveal", "book", "closed"] or box.closed, 10.0)
	var took := (Time.get_ticks_msec() - start) / 1000.0
	kit.log_line("  landed %.2fs after the skip tap; %.2fs of reel skipped; the reel ran %.2fs (the full pull ran %.2fs)" % [took, ov.skipped_seconds, ov.reel_seconds, _full_seconds])
	kit.check(ov.skipped_seconds > 1.0, "a tap after the first second fast-forwards to the late brake")
	kit.check(took > 1.5, "the crawl still plays out after a skip")
	await kit.until(func() -> bool: return box.closed, 15.0)
	await Game.refresh()
	kit.check(_balance("brk_1") - before == 1000, "the Brokerage is up exactly $10")


# --- 3 -------------------------------------------------------------------------------

func _forced(tier: String, prefix: String) -> void:
	var cat: Array = await Game.api.request("GET", "/casino/catalog")
	var item: Dictionary = {}
	for i: Dictionary in cat[0].get("items", []):
		if str(i.tier) == tier:
			item = i
			break
	if not kit.check(not item.is_empty() and not _reel.is_empty(), "a stored reel to replay, its winner made %s" % tier):
		return
	var reel := _reel.duplicate(true)
	reel[38] = {"item_id": item.id, "tier": tier}
	var fake := {"item": item, "reel": reel, "winner_index": 38, "near_miss": null}
	var box := {"result": null, "closed": false}
	var ov := await _open("case_50", box)
	await kit.wait(0.4)
	ov.play(fake)
	await kit.until(func() -> bool: return ov.moment == "reel", 4.0)
	await kit.wait(4.4)
	await kit.shot("%s_%s_crawl" % [prefix, tier])
	if tier == "epic":
		await kit.until(func() -> bool: return ov.moment == "reveal", 12.0)
		await kit.wait(0.15)
		await kit.shot("%s_%s_flash" % [prefix, tier])
		await kit.wait(0.75)
		await kit.shot("%s_%s_reveal" % [prefix, tier])
		await kit.until(func() -> bool: return ov.moment == "book", 8.0)
		await kit.wait(0.3)
		await kit.shot("%s_%s_book" % [prefix, tier])
		await kit.until(func() -> bool: return box.closed, 8.0)
		kit.check(box.closed, "the epic reveal ends and the overlay closes")
		return
	await kit.until(func() -> bool: return ov.moment == "cutscene", 12.0)
	await kit.wait(0.45)
	await kit.shot("%s_%s_dark" % [prefix, tier])
	await kit.wait(0.75)
	await kit.shot("%s_%s_spin" % [prefix, tier])
	await kit.wait(0.85)
	await kit.shot("%s_%s_landed" % [prefix, tier])
	await kit.until(func() -> bool: return box.closed, 12.0)
	kit.check(box.closed, "the %s cutscene ends and the overlay closes" % tier)


# --- 4 -------------------------------------------------------------------------------

func _refused() -> void:
	# Spend the rest of the week's room on this scratch save, straight through the API.
	for case_id: String in ["case_50", "case_20", "case_10"]:
		for i in 40:
			var r: Array = await Game.api.request("POST", "/casino/case", {}, {"case_id": case_id, "to_account": "sav_1"})
			if r[1] != "":
				break
	await Game.refresh()
	var before := _balance("sav_1")
	var box := {"result": null, "closed": false}
	var ov := await _open("case_20", box)
	var up := _press(ov.mouth_control("sav_1"))
	await kit.wait(0.6)
	Input.parse_input_event(up)
	await kit.until(func() -> bool: return ov.moment == "refused", 6.0)
	await kit.wait(0.9)
	await kit.shot("reel_30_refused")
	kit.check(not ov._lamp.on, "the lamp over the slot is off")
	kit.check(ov.said.size() > 0 and ov.said[-1] == "Not this week.", "the dealer says it: %s" % (ov.said[-1] if ov.said.size() > 0 else ""))
	await kit.until(func() -> bool: return box.closed, 8.0)
	kit.check(box.result == null, "a refused pull closes with nothing")
	await Game.refresh()
	kit.check(_balance("sav_1") == before, "nothing moved")


# --- helpers -------------------------------------------------------------------------

func _open(case_id: String, box: Dictionary) -> CaseOverlay:
	var ov := CaseOverlay.new(case_id)
	ov.closed.connect(func(r: Variant) -> void:
		box.result = r
		box.closed = true
	)
	kit.main.open_overlay(ov)
	await kit.wait(0.5)
	return ov


## Press the mouse down on a control (a finger on the slot) and return the release event.
func _press(c: Control) -> InputEventMouseButton:
	var r := c.get_global_rect()
	var screen := kit.get_viewport().get_screen_transform() * (r.position + r.size / 2.0)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = screen
	down.global_position = screen
	Input.parse_input_event(down)
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	return up


## The last money half of what Vex said ("Twenty to the House Fund.").
func _money_line(ov: CaseOverlay) -> String:
	for i in range(ov.said.size() - 1, -1, -1):
		if " to the " in ov.said[i]:
			return ov.said[i]
	return ""


## The last counts half ("Twenty-five shells. Six blue. One purple.").
func _odds_line(ov: CaseOverlay) -> String:
	for i in range(ov.said.size() - 1, -1, -1):
		if " to the " not in ov.said[i]:
			return ov.said[i]
	return ""


func _balance(id: String) -> int:
	for d: Dictionary in Game.state.get("casino", {}).get("destinations", []):
		if str(d.get("id", "")) == id:
			return int(d.get("balance_cents", 0))
	return 0
