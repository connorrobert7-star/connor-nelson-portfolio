extends RefCounted
## Village tour: the hub, its doors, the ledger stone, the tablets filling from a real
## deposit, a ruin restored by real paydays, the house building a stage and the wall
## losing bricks. Everything by tap. Run on a fresh save (HOARD_TODAY=2026-10-20).


func run(kit: TourKit) -> void:
	await kit.go_to("village", Village.SPAWN)
	var v: Village = kit.level()
	await kit.until(func() -> bool: return not Game.state.is_empty() and v.house != null)
	await kit.wait(1.2)

	# The hub: four plots with doors, no walk-up text panels anywhere.
	for plot in ["casino", "arcade", "gate", "shrine"]:
		kit.check(Village.PLOTS.has(plot) and Village.PLOTS[plot].has("door"), "plot %s has a door" % plot)
	kit.check(v._zones.is_empty(), "no walk-up text panels")
	# A new save's tablets fill in front of you the first time (this week's deposits).
	await kit.wait(1.0)
	await kit.shot("village_first_fill")
	await kit.until(func() -> bool: return not v._beats_running, 20.0)
	await kit.wait(0.3)
	await kit.shot("village_square")
	for tile in [Vector2i(6, 13), Vector2i(18, 13), Vector2i(33, 13), Vector2i(5, 19), Vector2i(31, 19), Vector2i(20, 23)]:
		await kit.stand(tile)
		await kit.wait(0.6)
		kit.check(not kit.main.panel.visible, "no panel at %s" % tile)
		await kit.shot("village_at_%d_%d" % [tile.x, tile.y])

	# Plot doors only open into levels that exist; with no casino feature loaded the
	# casino door stays shut, and walking at it goes nowhere.
	await kit.stand(Vector2i(17, 13))
	await kit.hold("ui_up", 0.8)
	kit.check(kit.level() is Village, "a plot door with no level behind it stays shut")

	# Numbers live on things.
	var h: Dictionary = Game.state.village.house
	kit.check(v.house._balance_label.text == "$8,450", "the house sign shows the House Fund (%s)" % v.house._balance_label.text)
	kit.check(v.house._gap_label.text == "$4,350", "the gap to the roof floats on its ghost (%s)" % v.house._gap_label.text)
	kit.check(str(h.stage.id) == "walls", "the demo house stands at its walls")
	kit.check(v.wall._fund_label.text == "$1,800", "the wall has the Emergency Fund painted on it")
	kit.check(v.ledger_stone.get_node("Digits").text != "", "the ledger stone glows with the week's extra")
	kit.check(v._door_lamps.gate.text == "$1,264", "the gate lamp shows the smallest debt (%s)" % v._door_lamps.gate.text)

	# Tap the ledger stone from across the square: the leader walks over and it opens.
	await kit.stand(Vector2i(13, 18))
	await kit.tap_world(v.ledger_stone.position + Vector2(0, -12))
	await kit.until(func() -> bool: return kit.overlay() is StatsOverlay, 6.0)
	kit.check(kit.overlay() is StatsOverlay, "tapping the ledger stone opens the stats screen")
	await kit.wait(0.8)
	var texts: Array[String] = []
	if kit.overlay():
		for c in kit.overlay().get_children():
			if c is Label:
				texts.append((c as Label).text)
	kit.check(texts.has("$8,450.00") and texts.has("$1,800.00"), "the stats screen has the real balances")
	kit.check(texts.any(func(t: String) -> bool: return t.contains("Green Basket")), "the stats screen has this week's ledger")
	await kit.shot("village_stats")
	if kit.overlay():
		await kit.tap_control((kit.overlay() as StatsOverlay).close_button)
	await kit.until(func() -> bool: return kit.overlay() == null, 3.0)
	kit.check(kit.overlay() == null and not Game.busy, "the stats screen closes with a tap")

	# Tap a cultist: it hops where it stands; the leader doesn't walk off.
	var c: VillageCultist = v.cultists[0]
	for candidate in v.cultists:
		if v._interactables.all(func(it: Dictionary) -> bool: return candidate.position.distance_to(it.pos) > 30.0):
			c = candidate
			break
	var leader_at := v.leader.position
	await kit.tap_world(c.position + Vector2(0, -7))
	await kit.wait(0.1)
	kit.check(c._busy and v.leader.position.distance_to(leader_at) < 2.0, "a tapped cultist hops")

	# Tap the bell tower's tablet: the sockets hop.
	var bell: VillageRuin = v.ruins.bell_tower
	await kit.stand(Vector2i(34, 14))
	await kit.tap_world(bell.position + bell.tablet_at + Vector2(0, 6))
	await kit.wait(0.15)
	await kit.shot("village_tablet_tap")
	kit.check(bell.sockets_filled() == 3, "the bell tower tablet starts with this week's deposits (%d)" % bell.sockets_filled())

	# Buying shares at the shop is not a deposit here: no socket fills, nothing celebrates.
	await _stand(kit, Vector2i(26, 23))
	await kit.hold("ui_up", 1.0)
	await kit.until(func() -> bool: return kit.level() is ShopRoom)
	kit.check(kit.level() is ShopRoom, "the shop door works")
	await kit.wait(0.4)
	await kit.stand(Vector2i(13, 7))
	if await kit.interact():
		await kit.read_on()
		await kit.choose("Buy shares")
		await kit.choose(0)
		await kit.read_on()
		await kit.choose(0)
		await kit.choose("Buy")
		await kit.wait(0.5)
		await kit.read_on()
	while kit.main.dialogue.visible:
		await kit.press("ui_cancel")
		await kit.wait(0.2)
	await kit.stand(Vector2i(7, 9))
	await kit.hold("ui_down", 0.6)
	await kit.until(func() -> bool: return kit.level() is Village, 5.0)
	kit.check(kit.level() is Village and kit.level().leader.position.distance_to(kit.level().feet_at(Village.SHOP_DOOR + Vector2i.DOWN)) < 24, "back out of the shop door")
	v = kit.level()
	await kit.wait(1.5)
	kit.check(not v._beats_running and v.ruins.bell_tower.sockets_filled() == 3, "a stock buy fills no socket")

	# Four weeks of paydays: the tablet fills and the bell tower is restored overnight.
	for i in 4:
		await Game.call_api("POST", "/clock/advance", {"days": 7})
	Game.weeks_ago = 0
	await Game.refresh()
	await kit.wait(0.2)
	v = kit.level()
	kit.check(Game.state.away.any(func(a: Dictionary) -> bool: return a.kind == "ruin_restored"), "the restoration waits in the while-you-were-out queue")
	await kit.until(func() -> bool: return v._beats_running, 4.0)
	await kit.until(func() -> bool: return v.ruins.bell_tower.sockets_filled() > 3, 10.0)
	await kit.wait(0.1)
	await kit.shot("village_socket_fill")
	await kit.until(func() -> bool: return v.ruins.bell_tower._restored_shown, 15.0)
	await kit.wait(0.12)
	await kit.shot("village_restore")
	await kit.until(func() -> bool: return not v._beats_running, 20.0)
	var bell_state: Dictionary = Game.state.village.ruins.filter(func(r: Dictionary) -> bool: return r.id == "bell_tower")[0]
	kit.check(bell_state.restored and not bell_state.fresh, "the bell tower is restored and its cutscene played once")
	await kit.stand(Vector2i(32, 13))
	await kit.wait(0.5)
	await kit.shot("village_restored")

	# The house builds a stage: shown here by replaying what the backend sends when the
	# House Fund crosses a threshold overnight (the backend side is in test_village.py).
	await _replay(kit, func(s: Dictionary) -> void:
		s.village.house.building = true
		s.village.house.seen_index = int(s.village.house.index) - 1)
	await kit.until(func() -> bool: return kit.level()._beats_running, 3.0)
	await kit.wait(1.3)
	await kit.shot("village_house_building")
	await kit.until(func() -> bool: return not kit.level()._beats_running, 12.0)
	await kit.stand(Vector2i(7, 18))
	await kit.wait(0.5)
	await kit.shot("village_house_built")

	# Money left the Emergency Fund: the bricks fall (shown, never caused by the game).
	await _replay(kit, func(s: Dictionary) -> void:
		var w: Dictionary = s.village.wall
		w.seen_cents = int(w.balance_cents) + 120000
		w.seen_courses = int(w.courses) + 3
		w.fell_cents = 120000)
	await kit.until(func() -> bool: return kit.level()._beats_running, 3.0)
	await kit.wait(1.25)
	await kit.shot("village_wall_falls")
	await kit.until(func() -> bool: return not kit.level()._beats_running, 12.0)
	kit.check(int(Game.state.village.wall.fell_cents) == 0, "the wall's change is marked seen")
	# A full wall glows (three months of costs set aside).
	await _replay(kit, func(s: Dictionary) -> void:
		var w: Dictionary = s.village.wall
		w.balance_cents = w.target_cents
		w.seen_cents = w.target_cents
		w.courses = w.courses_total
		w.seen_courses = w.courses_total
		w.months_covered = float(w.months)
		w.full = true)
	await kit.stand(Vector2i(10, 23))
	await kit.wait(0.6)
	kit.check(kit.level().wall._glow.size() > 0, "a full wall glows")
	await kit.shot("village_wall_full")
	await Game.refresh()
	await kit.stand(Village.SPAWN)
	await kit.wait(0.5)
	await kit.shot("village_end")


## Stand somewhere, dropping any walk a tap had started.
func _stand(kit: TourKit, tile: Vector2i) -> void:
	kit.level().leader.target = Vector2.INF
	kit.level()._pending = {}
	await kit.stand(tile)


## Re-dress the village with a changed copy of the real state, as if it had just arrived.
func _replay(kit: TourKit, change: Callable) -> void:
	var s: Dictionary = Game.state.duplicate(true)
	change.call(s)
	Game.state = s
	Game.state_changed.emit()
	await kit.frames(2)
