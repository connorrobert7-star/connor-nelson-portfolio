extends RefCounted
## Core walk-through: walking, collisions, talking, the shop, the tavern, the demo clock.


func run(kit: TourKit) -> void:
	var village := kit.level()
	var start := village.leader.position
	await kit.hold("ui_right", 1.0)
	kit.check(village.leader.position.x > start.x + 40, "walks right")
	await kit.hold("ui_up", 4.0)
	kit.check(village.leader.position.y > 80 and village.leader.position.y < 100, "stops at the riverbank")
	await kit.shot("core_village")

	await kit.stand(Vector2i(11, 13))
	if await kit.interact():
		kit.check(kit.dialogue_open(), "Wren talks")
		await kit.shot("core_wren")
		await kit.read_on()
	kit.check(not kit.dialogue_open() and not Game.busy, "dialogue closes and frees the player")

	# Walk in through the shop door.
	await kit.stand(Vector2i(26, 23))
	await kit.hold("ui_up", 1.0)
	await kit.until(func() -> bool: return kit.level() is ShopRoom)
	kit.check(kit.level() is ShopRoom, "walks into the shop")
	await kit.wait(0.4)
	await kit.stand(Vector2i(13, 7))
	if await kit.interact():
		await kit.read_on()
		await kit.choose("Buy shares")
		await kit.choose(0)
		await kit.read_on()
		var before := int(Game.state.extra.extra_cents)
		await kit.choose(0)
		await kit.choose("Buy")
		await kit.until(func() -> bool: return int(Game.state.extra.extra_cents) < before)
		kit.check(int(Game.state.extra.extra_cents) == before - 2500, "a $25 buy lowers extra by $25")
		await kit.shot("core_shop_bought")

	await kit.reset_to_village()
	var day: String = Game.state.today
	await kit.key(KEY_N)
	await kit.until(func() -> bool: return Game.state.today != day)
	kit.check(Game.state.today != day, "N lets a day pass in the demo")
