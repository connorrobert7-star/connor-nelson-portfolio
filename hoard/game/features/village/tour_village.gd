extends RefCounted
## Village tour: the hub on its bigger island, its doors, the commons, the three parcels
## still behind rope lines, the ledger stone, the tablets filling from a real deposit, a ruin
## restored by real paydays, the house building a stage, the wall losing bricks, and the land
## opening (faked land tier 4) with its reveal. Everything by tap. Run on a fresh save
## (HOARD_TODAY=2026-10-20).


func run(kit: TourKit) -> void:
	await kit.go_to("village", Village.SPAWN)
	var v: Village = kit.level()
	await kit.until(func() -> bool: return not Game.state.is_empty() and v.house != null)
	await kit.wait(1.2)

	# The island: about twice the old 38x19 of land, home and commons open, three parcels gated.
	kit.check(v.map.size() == Village.H and v.map[0].length() == Village.W, "the map is %dx%d" % [Village.W, Village.H])
	var land := 0
	for id: String in Village.PARCELS:
		var r: Rect2i = Village.PARCELS[id].rect
		land += r.get_area()
	kit.check(land >= 2 * 38 * 19, "the island has about twice the land (%d tiles)" % land)
	kit.check(v.parcels.size() == 3 and v.parcels.keys().all(func(id: String) -> bool: return not v.parcel_open(id)), "east, south and north wait behind rope lines")
	kit.check(v.parcel_open("home") and v.parcel_open("commons"), "home and the commons are open from day one")
	for id: String in v.parcels:
		var p: VillageParcel = v.parcels[id]
		kit.check(not v.is_walkable(Rect2(p.center() + Vector2(-5, -4), Vector2(10, 4))), "%s is not walkable while it's closed" % id)
	var commons: Rect2i = Village.PARCELS.commons.rect
	kit.check(v.cultists.any(func(c: VillageCultist) -> bool: return commons.has_point(Vector2i((c.area.get_center() / Level.TILE).floor()))), "cultists roam the commons")

	# The building sites: each has a footprint on open land and clear ground beside it.
	for id in ["house", "shrine", "arcade", "tavern", "lodge"]:
		kit.check(Village.BUILDING_PLOTS.has(id), "building plot %s exists" % id)
		var plot: Dictionary = Village.building_plot(id)
		var parcel: Rect2i = Village.PARCELS[plot.parcel].rect
		kit.check(parcel.encloses(plot.rect), "%s's footprint is on its parcel" % id)
		for key in ["sign", "flag"]:
			var t: Vector2i = plot[key]
			kit.check(not plot.rect.has_point(t) and not v._blocked.has(t), "%s's %s tile %s is clear ground" % [id, key, t])

	# The hub: four plots with doors, no walk-up text panels and no key prompts anywhere.
	for plot in ["casino", "arcade", "gate", "shrine"]:
		kit.check(Village.PLOTS.has(plot) and Village.PLOTS[plot].has("door"), "plot %s has a door" % plot)
	kit.check(v._zones.is_empty(), "no walk-up text panels")
	# A new save's tablets fill in front of you the first time (this week's deposits).
	await kit.wait(1.0)
	await kit.shot("village_first_fill")
	await kit.until(func() -> bool: return not v._beats_running, 25.0)
	await kit.wait(0.3)
	await _stand(kit, Village.SPAWN)
	await kit.wait(0.5)
	await kit.shot("village_square")
	var spots := {
		"arcade": Vector2i(8, 13), "casino": Vector2i(22, 13), "shrine": Vector2i(34, 13),
		"house": Vector2i(8, 20), "shop": Vector2i(34, 21), "commons": Vector2i(20, 28),
		"fields": Vector2i(12, 28), "gate": Vector2i(22, 32), "east_edge": Vector2i(40, 18),
		"south_edge": Vector2i(40, 29), "north_edge": Vector2i(41, 8),
	}
	for name: String in spots:
		var tile: Vector2i = spots[name]
		await _stand(kit, tile)
		await kit.wait(0.6)
		kit.check(not kit.main.panel.visible, "no panel at %s" % name)
		kit.check(kit.main.prompt_label.text == "", "no key prompt at %s (%s)" % [name, kit.main.prompt_label.text])
		await kit.shot("village_at_%s" % name)
	# Talking still works by tap: Wren stands by the fields now.
	await _stand(kit, Vector2i(14, 29))
	await kit.wait(0.8)  # let the camera settle on the leader before tapping the world
	await kit.tap_world(v.feet_at(Vector2i(13, 26)) + Vector2(0, -8))
	await kit.until(func() -> bool: return kit.dialogue_open(), 6.0)
	kit.check(kit.dialogue_open(), "tapping Wren walks over and she talks")
	await kit.read_on()
	while kit.main.dialogue.visible:
		await kit.press("ui_cancel")
		await kit.wait(0.2)

	# The gate in the bottom wall opens on foot, and coming back puts you inside the wall.
	if Features.level_script("gate"):
		await _stand(kit, Vector2i(21, 33))
		await kit.hold("ui_down", 1.5)
		await kit.until(func() -> bool: return not (kit.level() is Village), 5.0)
		kit.check(not (kit.level() is Village), "the gate door leads out to the gate")
		await kit.wait(0.4)
		await kit.stand(Vector2i(14, 15))
		await kit.hold("ui_down", 0.3)
		await kit.until(func() -> bool: return kit.level() is Village, 5.0)
		v = kit.level()
		await kit.wait(0.4)
		kit.check(kit.level() is Village and v.leader.position.y < (Village.ROAD_ROW + 1) * Level.TILE, "back through the gate, inside the wall (%s)" % v.leader.position)
		await kit.shot("village_back_from_gate")

	# Walking at a gated parcel goes nowhere: the rope holds.
	await _stand(kit, Vector2i(41, 18))
	await kit.hold("ui_right", 1.0)
	kit.check(v.leader.position.x < 43 * Level.TILE, "the rope line holds at the east reach")

	# Numbers live on things, and each number shows once.
	var h: Dictionary = Game.state.village.house
	kit.check(v.house._balance_label.text == "$8,450", "the house sign shows the House Fund (%s)" % v.house._balance_label.text)
	kit.check(v.house._gap_label.text == "$4,350", "the gap to the roof floats on its ghost (%s)" % v.house._gap_label.text)
	kit.check(str(h.stage.id) == "walls", "the demo house stands at its walls")
	kit.check(v.wall._fund_label.text == "$1,800", "the wall has the Emergency Fund painted on it")
	kit.check(v.ledger_stone.get_node("Digits").text != "", "the ledger stone glows with the week's extra")
	var arcade_drawn := Features.for_plot("arcade") != null
	var flames := int(Game.state.minigames.flames.left)
	kit.check(v._door_lamps.arcade.text == ("" if arcade_drawn else "%d flames" % flames), "the arcade lamp leaves the flames to the candles (%s)" % v._door_lamps.arcade.text)
	var gate_drawn := Features.for_plot("gate") != null
	kit.check(v._door_lamps.gate.text == ("" if gate_drawn else "$1,264"), "the gate's debt shows once (%s)" % v._door_lamps.gate.text)
	var drain_names := v.dynamic.get_children().filter(func(n: Node) -> bool: return n is Label and (n as Label).text in ["Iron Gym", "Netflix", "Spotify"])
	kit.check(drain_names.is_empty(), "old drains show their amount only")

	# The HUD's corners stay clear: a painted number under the purse fades.
	await _stand(kit, Vector2i(30, 13))
	await kit.wait(0.5)
	var under: Array[Label] = []
	for l: Variant in v._labels:
		if is_instance_valid(l) and (l as Label).text != "" and (l as Label).is_visible_in_tree():
			var p := v.get_viewport().get_canvas_transform() * ((l as Label).global_position + (l as Label).size / 2.0)
			if p.y < 26 and p.x > 480 - 130:
				under.append(l)
	kit.check(not under.is_empty() and under.all(func(l: Label) -> bool: return l.self_modulate.a < 0.5), "labels under the purse fade (%d)" % under.size())
	await kit.shot("village_hud_clear")

	# Tap the ledger stone from across the square: the leader walks over and it opens.
	await _stand(kit, Vector2i(17, 18))
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
	await _stand(kit, Vector2i((c.position / Level.TILE).floor()) + Vector2i(2, 0))
	await kit.wait(0.8)  # let the camera settle on the leader before tapping the world
	var leader_at := v.leader.position
	await kit.tap_world(c.position + Vector2(0, -7))
	await kit.wait(0.1)
	kit.check(c._busy and v.leader.position.distance_to(leader_at) < 2.0, "a tapped cultist hops")

	# Tap the bell tower's tablet: the sockets hop.
	var bell: VillageRuin = v.ruins.bell_tower
	await _stand(kit, Vector2i(38, 15))
	await kit.tap_world(bell.position + bell.tablet_at + Vector2(0, 6))
	await kit.wait(0.15)
	await kit.shot("village_tablet_tap")
	kit.check(bell.sockets_filled() == 3, "the bell tower tablet starts with this week's deposits (%d)" % bell.sockets_filled())

	# Buying shares at the shop is not a deposit here: no socket fills, nothing celebrates.
	await _stand(kit, Village.SHOP_DOOR + Vector2i(0, 2))
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
	await _stand(kit, Vector2i(38, 15))
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
	await _stand(kit, Vector2i(8, 20))
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
	await _stand(kit, Vector2i(10, 32))
	await kit.wait(0.6)
	kit.check(kit.level().wall._glow.size() > 0, "a full wall glows")
	await kit.shot("village_wall_full")
	await Game.refresh()

	# The land opens: land tier 4 lists every parcel. Each newly opened parcel plays its reveal
	# (haze lifts, ropes drop, dust, grass), then it's walkable and settlers move in.
	v = kit.level()
	await _stand(kit, Vector2i(38, 18))
	var opened: Array[String] = []
	v.parcel_opened.connect(func(id: String) -> void: opened.append(id))
	await _replay(kit, func(s: Dictionary) -> void:
		s["buildings"] = {"land": {"tier": 4, "parcels": ["home", "commons", "east", "south", "north"]}})
	await kit.until(func() -> bool: return v._revealing, 4.0)
	await kit.wait(1.6)
	await kit.shot("village_land_reveal_1")
	await kit.wait(0.9)
	await kit.shot("village_land_reveal_2")
	await kit.until(func() -> bool: return not v._revealing, 30.0)
	kit.check(opened.size() == 3, "every parcel opened once (%s)" % [opened])
	for id: String in v.parcels:
		var p: VillageParcel = v.parcels[id]
		kit.check(v.parcel_open(id), "%s is open" % id)
		kit.check(v.is_walkable(Rect2(p.center() + Vector2(-5, 20), Vector2(10, 4))) or v.is_walkable(Rect2(p.center() + Vector2(-5, -20), Vector2(10, 4))), "%s is walkable once open" % id)
	await _stand(kit, Vector2i(41, 18))
	await kit.hold("ui_right", 1.0)
	kit.check(v.leader.position.x > 44 * Level.TILE, "the leader walks into the east reach")
	var inside := {"east": Vector2i(53, 21), "south": Vector2i(52, 29), "north": Vector2i(50, 10)}
	for name: String in inside:
		await _stand(kit, inside[name])
		await kit.wait(0.6)
		await kit.shot("village_open_%s" % name)
	# A re-dress with the same land plays nothing again.
	await _replay(kit, func(s: Dictionary) -> void: pass)
	await kit.wait(0.3)
	kit.check(not v._revealing, "an open parcel doesn't replay its reveal")
	await Game.refresh()
	await kit.wait(0.3)
	kit.check(not v.parcel_open("east"), "the real state (no land tiers yet) closes them again")
	await _stand(kit, Village.SPAWN)
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
