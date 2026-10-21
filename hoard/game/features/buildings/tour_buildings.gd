extends RefCounted
## Buildings tour: the signs by the house, shrine and arcade, the land's sign by the east
## stake, the banner planted on the shrine by tapping its pole, a casino deposit, the Sunday
## check (land ready), and building it if the purse allows. Fresh save, HOARD_TODAY=2026-10-20.


func run(kit: TourKit) -> void:
	await kit.go_to("village", Village.SPAWN)
	var v: Village = kit.level()
	await kit.until(func() -> bool: return not Game.state.is_empty() and v.house != null)
	await kit.until(func() -> bool: return not v._beats_running, 25.0)
	await kit.wait(0.6)
	var feature: HoardFeature = null
	for f in Features.all:
		if f.id() == "buildings":
			feature = f
	kit.check(feature != null, "the buildings feature is loaded")
	var sites: Dictionary = feature.get("_sites")
	kit.check(sites.size() == Village.BUILDING_PLOTS.size() + 1, "one site per building plot plus the land")
	var shrine: BuildingSite = sites.shrine
	kit.check(shrine._sign != null, "the shrine has a sign for its next tier")

	for spot: Array in [["house", Vector2i(4, 20)], ["shrine", Vector2i(31, 13)], ["arcade", Vector2i(5, 13)], ["east_stake", Vector2i(39, 18)]]:
		await _stand(kit, spot[1])
		await kit.wait(0.5)
		await kit.shot("sign_%s" % spot[0])

	# Plant the banner on the shrine by tapping its pole.
	var flag_at: Vector2 = Village.building_plot("shrine").flag_at
	await _stand(kit, Vector2i(37, 13))
	await kit.tap_world(flag_at + Vector2(0, -8))
	await kit.until(func() -> bool: return Game.state.buildings.get("target") is Dictionary, 6.0)
	var t: Variant = Game.state.buildings.get("target")
	kit.check(t is Dictionary and t.building_id == "shrine", "tapping the shrine's pole plants the banner there")
	await kit.wait(0.6)
	await kit.shot("banner_shrine")

	# A tap on a sign that isn't ready shakes it and spends nothing.
	var coins_before := int(Game.state.coins)
	await kit.tap_world(Village.building_plot("shrine").sign_at + Vector2(0, -8))
	await kit.wait(1.0)
	kit.check(int(Game.state.coins) == coins_before, "a sign that isn't ready builds nothing")

	# A real deposit from the casino, then let the week turn over to Sunday's check.
	var res: Array = await Game.call_api("POST", "/casino/case", {"case_id": "case_20", "to_account": "brk_1"})
	kit.log_line("casino deposit: %s" % ("ok" if res[1] == "" else res[1]))
	await Game.advance_days(5)
	await kit.reset_to_village()
	v = kit.level()
	await kit.until(func() -> bool: return not v._beats_running, 25.0)
	await kit.wait(0.5)
	kit.log_line("today %s, coins %s" % [Game.state.today, Game.state.coins])
	var land: Dictionary = {}
	for e: Dictionary in Game.state.buildings.list:
		if e.id == "land":
			land = e
		if e.get("next") is Dictionary:
			kit.log_line("%s next t%s ready=%s can_build=%s why=%s coins=%s" % [e.id, e.next.tier, e.next.ready, e.next.can_build, e.next.why_not, e.next.coins])
	sites = feature.get("_sites")
	await _stand(kit, Vector2i(39, 18))
	await kit.wait(0.6)
	await kit.shot("land_stake_sunday")
	kit.check(not land.is_empty() and land.next is Dictionary and bool(land.next.ready), "the land's next tier is ready after Sunday")
	await _stand(kit, Vector2i(34, 13))
	await kit.wait(0.4)
	await kit.shot("shrine_sunday")

	# Build the land if the purse allows: tap its sign by the stake.
	if not land.is_empty() and land.next is Dictionary and bool(land.next.can_build):
		await _stand(kit, Vector2i(41, 18))
		await kit.tap_world(BuildingSite.land_sign_at("east") + Vector2(0, -8))
		await kit.until(func() -> bool: return Game.state.buildings.get("crew") is Dictionary, 6.0)
		kit.check(Game.state.buildings.get("crew") is Dictionary, "tapping the land's sign starts the crew")
		await Game.advance_days(1)
		await kit.reset_to_village()
		await kit.wait(0.8)
		await _stand(kit, Vector2i(41, 19))
		await kit.wait(0.6)
		await kit.shot("land_scaffold")
	else:
		kit.log_line("skipped the build: coins %s" % Game.state.coins)

	# Faked from the real state (the purse is empty on a fresh save): the shrine half built,
	# then the chapel finished (its look drawn from the sheet, the dust puff, then seen).
	await _stand(kit, Vector2i(33, 14))
	await _replay(kit, func(s: Dictionary) -> void:
		for e: Dictionary in s.buildings.list:
			if e.id == "shrine":
				e.constructing = true
				e.progress = 0.5
		s.buildings.crew = {"building_id": "shrine", "tier": 2, "days": 3, "days_done": 1, "progress": 0.5})
	await kit.wait(1.0)
	await kit.shot("shrine_scaffold")
	await _replay(kit, func(s: Dictionary) -> void:
		for e: Dictionary in s.buildings.list:
			if e.id == "shrine":
				e.tier = 2
				e.constructing = false
				e.progress = 0.0
				e.look = e.next.look
				e.next = null
		s.buildings.crew = null)
	await kit.wait(0.25)
	await kit.shot("shrine_finished_puff")
	await kit.wait(1.5)
	await kit.shot("shrine_chapel")


func _replay(kit: TourKit, change: Callable) -> void:
	var s: Dictionary = Game.state.duplicate(true)
	change.call(s)
	Game.state = s
	Game.state_changed.emit()
	await kit.frames(2)


func _stand(kit: TourKit, tile: Vector2i) -> void:
	kit.level().leader.target = Vector2.INF
	kit.level()._pending = {}
	await kit.stand(tile)
