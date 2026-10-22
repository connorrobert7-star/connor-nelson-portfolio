extends RefCounted
## The casino room, played by tap: the game opens in the dark room and Vex says the counts;
## the choir moves between two frames; every machine opens its overlay when tapped (after Vex
## states the odds for the paid ones); a refusal turns the slot lamp off with "Not this week.";
## the gold tell turns the choir and the lamp; tapping Vex makes him talk; the door leads out
## to the village.

const MACHINES := [
	["case_10", "CaseOverlay", true], ["case_20", "CaseOverlay", true], ["case_50", "CaseOverlay", true],
	["scratch", "ScratchOverlay", true], ["wheel", "WheelOverlay", true], ["claw", "ClawOverlay", true],
	["book", "BookOverlay", false], ["draw", "DrawOverlay", false],
]

var opened: Array[String] = []
var case_ids: Array[String] = []


func run(kit: TourKit) -> void:
	kit.main._overlays.child_entered_tree.connect(_on_overlay)
	if not (kit.level() is CasinoRoom):
		kit.check(false, "the game opens in the casino (was %s)" % kit.level().get_class())
		await kit.go_to("casino", Room.ENTRANCE)
	var room := kit.level() as CasinoRoom
	if room == null:
		return
	await kit.until(func() -> bool: return room.vex.spoken > 0, 6.0)
	kit.check(room.vex.last_line == room.line() and room.line() != "", "Vex says the counts on arrival: %s" % room.vex.last_line)
	await kit.wait(0.6)
	await kit.shot("room_arrive")

	# The choir chants: two frames a beat apart are not the same.
	var a := room.choir.snapshot()
	await kit.shot("room_choir_a")
	await kit.wait(0.37)
	await kit.shot("room_choir_b")
	var b := room.choir.snapshot()
	kit.check(a != b and room.choir.beats > 0, "the choir moves in time (%d beats at %d BPM)" % [room.choir.beats, int(room.bpm)])
	kit.check(_differs(kit.out + "/room_choir_a.png", kit.out + "/room_choir_b.png", Rect2(96, 60, 288, 52)), "the risers look different between the two screenshots")
	kit.check(room.bpm >= 84.0 and room.bpm <= 140.0, "chant tempo follows the belt (%d BPM)" % int(room.bpm))

	# Every machine by tap: walk there, Vex states the odds for paid pulls, the overlay opens.
	for m: Array in MACHINES:
		await _use(kit, room, m[0], m[1], m[2])
	kit.check(case_ids == ["case_10", "case_20", "case_50"], "each case opens its own reel (%s)" % str(case_ids))

	# A real pull, the way the case overlay makes it: the money lands (simulated), a shell
	# fires, the box uses a hole, a peg drops, and the chant picks up as the belt empties.
	await kit.until(func() -> bool: return not Game.busy, 8.0)
	var used_before := room.box.used
	var left_before := room.table._total_left()
	var bpm_before := room.bpm
	var res: Array = await Game.act("/casino/case", {"case_id": "case_10", "to_account": "sav_1"})
	kit.check(res[1] == "", "a $10 case pull goes through the API (%s)" % res[1])
	await kit.wait(0.2)
	await kit.shot("room_after_pull")
	var shell: Dictionary = res[0].get("shell", {}) if res[1] == "" else {}
	kit.check(room.box.used != used_before, "the box on the wall darkens a hole (%d used)" % room.box.used)
	if shell.get("source", "") == "belt" and str(shell.get("tier", "")) != "epic":
		kit.check(room.table._total_left() == left_before - 1, "a peg drops on the belt (%d left)" % room.table._total_left())
		kit.check(room.bpm > bpm_before, "the chant speeds up (%d to %d BPM)" % [int(bpm_before), int(room.bpm)])

	# Tap Vex: he talks.
	await kit.until(func() -> bool: return not Game.busy and not room.vex.speaking, 8.0)
	var n := room.vex.spoken
	await kit.tap_world(room.vex.hit_rect().get_center())
	await kit.until(func() -> bool: return room.vex.spoken > n, 8.0)
	kit.check(room.vex.spoken > n, "tapping Vex makes him say the counts")
	await kit.wait(0.5)
	await kit.shot("room_vex_talks")

	# The week's extra is gone (the state the backend sends then): lamp off, a refusal.
	await kit.until(func() -> bool: return not Game.busy and not room.vex.speaking, 8.0)
	var broke: Dictionary = Game.state.duplicate(true)
	broke.casino.can_spend_cents = 0
	broke.casino.dealer.line = "Not this week."
	for c: Dictionary in broke.casino.cases:
		c.affordable = false
	Game.state = broke
	Game.state_changed.emit()
	await kit.wait(0.3)
	kit.check(not room.table.lamp_on, "the slot lamp is off when the week's extra is gone")
	opened.clear()
	await kit.tap_world(room.spot_rect("case_20").get_center())
	await kit.until(func() -> bool: return room.vex.last_line == "Not this week.", 8.0)
	kit.check(room.vex.last_line == "Not this week.", "Vex says Not this week.")
	await kit.wait(0.5)
	kit.check(opened.is_empty(), "no overlay opens when the week can't cover it")
	await kit.shot("room_not_this_week")
	await Game.refresh()
	await kit.wait(0.3)
	kit.check(room.table.lamp_on, "the slot lamp comes back with the real state")

	# The gold tell: a special shell is next.
	var tell: Dictionary = Game.state.duplicate(true)
	tell.casino.box.next_is_special = true
	tell.casino.box.next_tier = "legendary"
	Game.state = tell
	Game.state_changed.emit()
	await kit.wait(1.2)
	kit.check(room.box.is_tell() and room.choir.mode == "stare" and room.vex.standing(), "the tell: lamp gold, choir turns to the box, Vex stands")
	await kit.shot("room_tell")
	await Game.refresh()
	await kit.wait(0.6)
	kit.check(room.choir.mode == "chant", "the choir chants again after the tell")

	# Out the door to the village.
	await kit.until(func() -> bool: return not Game.busy, 6.0)
	await kit.tap_world(Vector2(240, 264))
	await kit.until(func() -> bool: return kit.level() is Village, 12.0)
	kit.check(kit.level() is Village, "the door leads out to the village")
	await kit.wait(0.5)
	if kit.level() is Village:
		kit.check(kit.level().leader.position.distance_to(kit.level().door_front("casino")) < 4.0, "you come out in front of the casino's door")
	await kit.shot("room_out_village")

	# The village has no casino plot yet; try the hook on a patch of grass so it's ready.
	var f := Features.for_plot("casino")
	kit.check(f != null and f.door_level() == "casino", "the casino feature claims the casino plot")
	if f != null and kit.level() is Village:
		var village := kit.level()
		var before := village.props.get_child_count()
		f.build_village(village, Rect2i(30, 20, 4, 3))
		f.dress_village(village, Rect2i(30, 20, 4, 3))
		kit.check(village.props.get_child_count() > before + 2, "the casino hall builds on a plot")
		await kit.wait(0.5)
		await kit.shot("room_hall_in_village")


func _use(kit: TourKit, room: CasinoRoom, id: String, expect: String, paid: bool) -> void:
	await kit.until(func() -> bool: return not Game.busy and kit.overlay() == null, 8.0)
	await kit.wait(0.2)
	opened.clear()
	var r := room.spot_rect(id)
	if not kit.check(r.has_area(), "%s has a spot to tap" % id):
		return
	var spoken := room.vex.spoken
	await kit.tap_world(r.get_center())
	var ok := await kit.until(func() -> bool: return opened.has(expect), 14.0)
	kit.check(ok, "tapping %s walks there and opens %s" % [id, expect])
	if paid:
		kit.check(room.vex.spoken > spoken and room.vex.last_line.contains(" to the "), "Vex states the odds before the %s pull: %s" % [id, room.vex.last_line])
	await kit.frames(3)
	var ov := kit.overlay()
	if ov != null:
		await kit.wait(0.8)
		await kit.shot("room_%s_open" % id)
		ov.close(null)
	await kit.until(func() -> bool: return not Game.busy, 8.0)
	if id == "case_20" or id == "wheel":
		await kit.shot("room_after_%s" % id)


func _on_overlay(n: Node) -> void:
	var kinds := {
		"CaseOverlay": CaseOverlay, "ScratchOverlay": ScratchOverlay, "WheelOverlay": WheelOverlay,
		"ClawOverlay": ClawOverlay, "BookOverlay": BookOverlay, "DrawOverlay": DrawOverlay,
	}
	for k: String in kinds:
		if is_instance_of(n, kinds[k]):
			opened.append(k)
	if n is CaseOverlay:
		case_ids.append((n as CaseOverlay).case_id)


## Whether the same patch of the room (room pixels) differs between two screenshots.
func _differs(path_a: String, path_b: String, room_rect: Rect2) -> bool:
	var ia := Image.load_from_file(path_a)
	var ib := Image.load_from_file(path_b)
	if ia == null or ib == null or ia.get_size() != ib.get_size():
		return false
	var k := float(ia.get_width()) / 480.0
	var changed := 0
	for y in range(int(room_rect.position.y * k), int(room_rect.end.y * k), 2):
		for x in range(int(room_rect.position.x * k), int(room_rect.end.x * k), 2):
			if not ia.get_pixel(x, y).is_equal_approx(ib.get_pixel(x, y)):
				changed += 1
	return changed > 40
