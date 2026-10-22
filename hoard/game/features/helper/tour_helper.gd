extends RefCounted
## Pip's first five minutes, played by tap from a fresh save (the game opens in the casino):
## he meets the wizard, the case beat (and Vex states the odds), the book, out the door, the
## village, a building's sign, the arcade, the shrine, the gate, then the end line. Every
## step is reached by walking (taps on the floor), and each beat is checked against the
## lines the backend wrote from the owner's numbers. Then: a tap on Pip asks the first idea,
## the backend remembers what was said, and after a demo reset two quick taps skip the tour.
## The world stays free the whole time (Pip never makes the game busy).
##   HOARD_BACKEND=http://127.0.0.1:8302 godot --path game res://dev/tour.tscn -- <out> \
##     res://features/helper/tour_helper.gd

var kit: TourKit
var beats := {}  # beat id -> the beat as the backend wrote it at the start


func run(k: TourKit) -> void:
	kit = k
	HelperFamiliar.heard.clear()
	await kit.until(func() -> bool: return kit.level() != null and not Game.busy, 20.0)
	kit.check(kit.level().place_id == "casino", "a fresh save opens in the casino")
	var h: Dictionary = Game.state.get("helper", {})
	kit.check(h.get("opening", {}).get("active", false), "a fresh save has the opening on")
	for b: Dictionary in h.get("opening", {}).get("beats", []):
		beats[b.id] = b
	var pip := _pip()
	if not kit.check(pip != null, "Pip is in the casino"):
		return
	kit.check(pip.position.distance_to(kit.level().leader.position) < 24.0, "Pip floats beside the wizard")
	await _meet()
	await _case()
	await _book()
	await _out_the_door()
	await _village()
	await _sign_and_arcade()
	await _shrine()
	await _gate()
	await _opening_done()
	await _ask()
	await _skip()
	_two_lines()


# --- the casino ------------------------------------------------------------------------

func _meet() -> void:
	var pip := _pip()
	await _until_beat("meet")
	await kit.wait(0.9)
	await kit.shot("01_meet")
	kit.check(_last(pip) == _text("meet", 0), "meet: Pip says who he is (%s)" % _last(pip))
	kit.check(not Game.busy, "meet: the game is not held while Pip talks")
	# Tap the bubble: the first tap shows the rest of the words, the next moves on.
	var shown := pip.said.size()
	await _tap_bubble(pip)
	await kit.wait(0.3)
	kit.check(pip.bubble.showing() and pip.said.size() == shown, "meet: the first tap shows the whole line")
	await _tap_bubble(pip)
	await kit.until(func() -> bool: return pip.said.size() > shown, 4.0)
	kit.check(_last(pip) == _text("meet", 1), "meet: a tap on the bubble moves to the next line")
	await _wait_done("meet")


func _case() -> void:
	var lv := kit.level()
	var shelf: Node2D = lv.get("shelf")
	await _walk_near(shelf.position + Vector2(-40, 18), 22.0)
	await _until_beat("case")
	var pip := _pip()
	await kit.wait(1.2)
	await kit.shot("02_case")
	kit.check(_said(pip).has(_text("case", 0)), "case: the price goes to your own account first")
	await kit.until(func() -> bool: return _said_by(pip, "vex") != "", 14.0)
	await kit.wait(1.0)
	await kit.shot("03_case_vex_odds")
	var vex: Node = lv.get("vex")
	var odds := _text("case", 2)
	kit.check(_said_by(pip, "vex") == odds and str(vex.get("last_line")) == odds, "case: Vex states the odds (%s)" % odds)
	var left: Dictionary = Game.state.casino.belt.left
	var total := 0
	for t: String in left:
		total += int(left[t])
	kit.check(odds.begins_with("%d shells." % total) and odds.contains("%d blue" % int(left.get("rare", 0))), "case: the odds match the belt")
	var spend := Money.fmt(int(Game.state.casino.can_spend_cents))
	kit.check(_text("case", 3).contains(spend), "case: the week's room is the casino's (%s)" % spend)
	await _wait_done("case")


func _book() -> void:
	var book: Node2D = kit.level().get("book")
	await _walk_near(book.position + Vector2(26, 8), 18.0)
	await _until_beat("book")
	await kit.wait(1.2)
	await kit.shot("04_book")
	kit.check(_said(_pip()).has(_text("book", 0)), "book: Pip explains the book")
	await _wait_done("book")


func _out_the_door() -> void:
	var lv := kit.level()
	for attempt in 6:
		if kit.level() != lv:
			break
		await kit.tap_world(Vector2(240, 262))
		await kit.until(func() -> bool: return kit.level() != lv or lv.leader.target == Vector2.INF, 6.0)
		await kit.wait(0.3)
	await kit.until(func() -> bool: return kit.level() != lv and kit.level() is Village and not Game.busy, 10.0)
	kit.check(kit.level() is Village, "out the door to the village")
	kit.check(_pip() != null, "Pip came along to the village")


# --- the village -----------------------------------------------------------------------

func _village() -> void:
	await _until_beat("village")
	await kit.wait(1.0)
	await kit.shot("05_village")
	kit.check(_said(_pip()).has(_text("village", 0)), "village: Pip says what the village is")
	await _wait_done("village")


func _sign_and_arcade() -> void:
	# West along the front road: the tavern's sign, then the arcade's door.
	var lv := kit.level()
	var door: Vector2i = Village.PLOTS.arcade.door
	var arcade_at := lv.feet_at(door) + Vector2(0, 18)
	var sign_seen := false
	for leg in 6:
		await _walk_near(arcade_at, 20.0)
		if _heard("sign") and not sign_seen:
			sign_seen = true
			await kit.wait(1.0)
			await kit.shot("06_sign")
			await _wait_done("sign")
			await _check_sign()
		if _heard("arcade"):
			break
	await _until_beat("arcade")
	await kit.wait(1.0)
	await kit.shot("07_arcade")
	kit.check(_said(_pip()).has(_text("arcade", 1)) or _said(_pip()).has(_text("arcade", 0)), "arcade: coins, never money")
	await _wait_done("arcade")
	if not sign_seen:
		var p := HelperFamiliar.sign_at("arcade")
		await _walk_near(p + Vector2(10, 4), 20.0)
		await _until_beat("sign")
		await kit.shot("06_sign")
		await _wait_done("sign")
		await _check_sign()


## The sign Pip stood by: its first dark lamp's number is the one he said, and Sunday.
func _check_sign() -> void:
	var traced := _pip().trace.filter(func(t: Dictionary) -> bool: return t.beat == "sign")
	var id := str(traced[0].sign) if not traced.is_empty() else ""
	kit.log_line("    sign beat by %s at %s" % [id, traced[0].at if not traced.is_empty() else ""])
	var lines: Array = beats.sign.by_building.get(id, [])
	kit.check(lines.size() > 1 and _said(_pip()).has(str(lines[1].text)), "sign: Pip reads the %s sign's numbers" % id)
	var e := _building(id)
	if not e.is_empty():
		var reqs: Array = e.next.requires
		var dark := reqs.filter(func(r: Dictionary) -> bool: return not r.met_now)
		var req: Dictionary = (dark if not dark.is_empty() else reqs)[0]
		var need := str(BuildingSite.req_text(req)).trim_suffix("w")
		kit.check(_said(_pip()).any(func(t: String) -> bool: return t.contains(need)), "sign: the number on the %s lamp (%s) is the one Pip says" % [id, need])
	kit.check(_said(_pip()).any(func(t: String) -> bool: return t.contains("Sunday")), "sign: the lamps are checked on Sunday")


func _shrine() -> void:
	var lv := kit.level()
	await _walk_near(lv.feet_at(Village.PLOTS.shrine.door) + Vector2(0, 18), 20.0)
	await _until_beat("shrine")
	await kit.wait(1.0)
	await kit.shot("08_shrine")
	await _wait_done("shrine")
	var count := (Game.state.holdings as Array).size()
	kit.check(_said(_pip()).any(func(t: String) -> bool: return t.contains("You hold %d now" % count)), "shrine: Pip counts the real holdings (%d)" % count)


func _gate() -> void:
	var lv := kit.level()
	await _walk_near(lv.feet_at(Village.PLOTS.gate.door) + Vector2(0, -60), 18.0)
	await _until_beat("gate")
	await kit.until(func() -> bool: return _said(_pip()).has(_end()), 30.0)
	await kit.wait(1.0)
	await kit.shot("09_gate_and_end")
	kit.check(_said(_pip()).has(_text("gate", 0)), "gate: the debts wait past the gate")
	kit.check(_said(_pip()).has(_end()), "the last beat ends the tour (%s)" % _end())
	await _wait_done("gate")


func _opening_done() -> void:
	kit.log_line("    beats: %s" % str(_pip().trace))
	for id: String in beats:
		kit.check(_heard(id), "beat %s was played" % id)
	var res: Array = await Game.call_api("GET", "/state")
	var h: Dictionary = res[0].get("helper", {})
	kit.check(not h.get("opening", {}).get("active", true), "the backend has the opening done, so it never repeats")
	await Game.refresh()


# --- asking and skipping ---------------------------------------------------------------

func _ask() -> void:
	var pip := _pip()
	var queue: Array = Game.state.helper.queue
	if not kit.check(not queue.is_empty(), "there are ideas to ask about"):
		return
	var first: Dictionary = queue[0]
	await kit.wait(0.6)
	await _tap_pip(pip)
	await kit.until(func() -> bool: return pip.speaking, 3.0)
	await kit.wait(0.4)
	kit.check(_last(pip) == str(first.lines[0]), "a tap on Pip asks the first idea (%s)" % first.id)
	# Read on by tapping Pip, and keep a picture of the line with the owner's numbers.
	var wall: Dictionary = Game.state.village.wall
	var balance := Money.fmt(int(wall.balance_cents))
	var shot_taken := false
	for i in 40:
		if not pip.speaking:
			break
		if _last(pip).contains(balance) and not shot_taken:
			shot_taken = true
			await kit.wait(1.6)
			await kit.shot("10_ask_emergency_fund")
		# One tap at a time, and only on a line that's up: a spare tap would ask the next idea.
		if pip.bubble.showing() and pip.bubble.shown_for > 0.4:
			await _tap_pip(pip)
		await kit.wait(0.2)
	kit.check(_said(pip).any(func(t: String) -> bool: return t.contains(balance)), "the emergency fund idea uses the real fund (%s)" % balance)
	await kit.until(func() -> bool: return not pip.speaking, 8.0)
	var res: Array = await Game.call_api("GET", "/state")
	var left: Array = res[0].helper.queue.map(func(t: Dictionary) -> String: return str(t.id))
	kit.check(not left.has(str(first.id)), "the backend won't say %s again" % first.id)
	# The next tap is the next idea, not the same one.
	await kit.wait(0.5)
	var before := pip.said.size()
	await _tap_pip(pip)
	await kit.until(func() -> bool: return pip.speaking, 3.0)
	await kit.wait(1.8)
	await kit.shot("11_ask_next")
	var next := str(pip.said[before].text) if pip.said.size() > before else ""
	kit.check(next == str(queue[1].lines[0]), "the next tap is the next idea (%s)" % queue[1].id)


func _skip() -> void:
	var res: Array = await Game.call_api("POST", "/helper/reset")
	kit.check(res[1] == "", "demo reset replays the opening")
	HelperFamiliar.heard.clear()
	await Game.refresh()
	await kit.go_to("casino", Room.ENTRANCE)
	var pip := _pip()
	await _until_beat("meet")
	await kit.wait(0.5)
	await _double_tap(pip)
	await kit.until(func() -> bool: return pip.beat == "" and _last(pip) == str(Game.state.helper.opening.skip[0].text), 4.0)
	await kit.wait(1.4)
	await kit.shot("12_skip")
	kit.check(_last(pip) == str(Game.state.helper.opening.skip[0].text), "two taps on Pip skip the tour")
	res = await Game.call_api("GET", "/state")
	kit.check(not res[0].helper.opening.active, "a skipped tour is done for good")
	# Walking near the shelf now plays nothing.
	var n := pip.said.size()
	await kit.wait(2.5)
	await _walk_near((kit.level().get("shelf") as Node2D).position + Vector2(-40, 18), 22.0)
	await kit.wait(1.5)
	kit.check(pip.said.size() == n, "after a skip, no beat plays")


func _two_lines() -> void:
	var pip := _pip()
	if pip == null:
		return
	var long: Array = pip.said.filter(func(s: Dictionary) -> bool: return int(s.lines) > 2)
	kit.check(long.is_empty(), "every bubble fits in two lines %s" % str(long))


# --- helpers -----------------------------------------------------------------------------

func _pip() -> HelperFamiliar:
	var lv := kit.level()
	if lv == null:
		return null
	for c in lv.props.get_children():
		if c is HelperFamiliar:
			return c
	return null


func _text(beat: String, i: int) -> String:
	var lines: Array = beats.get(beat, {}).get("lines", [])
	return str(lines[i].text) if i < lines.size() else ""


func _end() -> String:
	return str(Game.state.helper.opening.end[0].text)


func _building(id: String) -> Dictionary:
	for e: Dictionary in Game.state.buildings.list:
		if e.id == id:
			return e
	return {}


func _heard(beat: String) -> bool:
	return HelperFamiliar.heard.has("beat:" + beat)


func _said(pip: HelperFamiliar) -> Array:
	return pip.said.map(func(s: Dictionary) -> String: return str(s.text)) if pip else []


func _said_by(pip: HelperFamiliar, who: String) -> String:
	for s: Dictionary in pip.said:
		if s.who == who:
			return str(s.text)
	return ""


func _last(pip: HelperFamiliar) -> String:
	return str(pip.said[-1].text) if pip and not pip.said.is_empty() else ""


func _until_beat(id: String) -> void:
	var ok := await kit.until(func() -> bool: return _heard(id), 12.0)
	kit.check(ok, "beat %s starts when the wizard gets there" % id)


## Let a beat play out, tapping its bubble along once each line has been up a moment.
func _wait_done(id: String) -> void:
	var pip := _pip()
	for i in 80:
		if pip == null or not is_instance_valid(pip) or (pip.beat != id and not pip.speaking):
			return
		if pip.bubble.showing() and pip.bubble.shown_for > 0.6:
			await _tap_bubble(pip)
		await kit.wait(0.15)


func _tap_bubble(pip: HelperFamiliar) -> void:
	var r := pip.bubble.hit_rect()
	if r.has_area():
		await kit.tap_world(r.get_center())


func _tap_pip(pip: HelperFamiliar) -> void:
	await kit.tap_world(pip.global_position + pip._pivot.position + Vector2(0, -7))


## Two taps on Pip as fast as a thumb does them: down, up, down, up, a frame apart.
func _double_tap(pip: HelperFamiliar) -> void:
	var vp := kit.get_viewport()
	var at := vp.get_screen_transform() * vp.get_canvas_transform() * (pip.global_position + pip._pivot.position + Vector2(0, -7))
	for i in 4:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = i % 2 == 0
		ev.position = at
		ev.global_position = at
		Input.parse_input_event(ev)
		await kit.frames(1)
	await kit.frames(2)


func _view() -> Rect2:
	var cam := kit.level().camera
	var half := Vector2(240, 135) / cam.zoom
	return Rect2(cam.get_screen_center_position() - half, half * 2.0)


## Tap the floor toward `aim` (on screen, clear of things to use, doors and Pip) until the
## wizard stands within `radius` of it.
func _walk_near(aim: Vector2, radius: float) -> bool:
	var lv := kit.level()
	for attempt in 14:
		if lv.leader.position.distance_to(aim) < radius:
			return true
		var p := _on_screen_toward(aim)
		await kit.tap_world(p)
		var from := lv.leader.position
		var still := 0.0
		for f in 400:
			await kit.frames(1)
			if not is_instance_valid(lv) or kit.level() != lv:
				return false
			if lv.leader.position.distance_to(aim) < radius:
				break
			still = still + kit.get_process_delta_time() if lv.leader.position.distance_to(from) < 0.05 else 0.0
			from = lv.leader.position
			if still > 0.35:
				break
	return lv.leader.position.distance_to(aim) < radius


func _on_screen_toward(aim: Vector2) -> Vector2:
	var v := _view()
	var view := Rect2(v.position + Vector2(8, 48), v.size - Vector2(16, 52))
	var lv := kit.level()
	var pip := _pip()
	var best := lv.leader.position
	var best_d := INF
	var y := view.position.y
	while y < view.end.y:
		var x := view.position.x
		while x < view.end.x:
			var p := Vector2(x, y)
			var d := p.distance_to(aim)
			if d < best_d and lv.is_walkable(Rect2(p + Leader.FOOT.position, Leader.FOOT.size)) and _bare(lv, p, pip):
				best = p
				best_d = d
			x += 6.0
		y += 6.0
	return best


func _bare(lv: Level, p: Vector2, pip: HelperFamiliar) -> bool:
	for it: Dictionary in lv._interactables:
		if p.distance_to(it.pos) < Level.TAP_RADIUS + 4:
			return false
	for door: Dictionary in lv._doors:
		if (door.rect as Rect2).grow(10).has_point(p):
			return false
	if not lv._facade_door(p).is_empty():
		return false
	var spots: Variant = lv.get("_hotspots")
	if spots is Array:
		for h: Dictionary in spots:
			if (h.rect as Rect2).grow(4).has_point(p):
				return false
	if lv is Village:
		for c: VillageCultist in (lv as Village).cultists:
			if p.distance_to(c.position + Vector2(0, -7)) < 16:
				return false
	if pip and (pip.bubble.hit_rect().grow(4).has_point(p) or p.distance_to(pip.global_position + pip._pivot.position) < 16):
		return false
	return true
