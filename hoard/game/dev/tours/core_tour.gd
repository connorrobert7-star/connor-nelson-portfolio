extends RefCounted
## Core walk-through on today's island, written against Village's own constants so it moves
## with the map: walking, a facade that stops you, tapping Wren, tapping the ground, the
## shop's door, and the demo's day dial (a tap, like everything else).


func run(kit: TourKit) -> void:
	await kit.go_to("village", Village.SPAWN)
	var village: Village = kit.level()
	await kit.until(func() -> bool: return not village._beats_running, 25.0)
	await kit.wait(0.3)
	var start := village.leader.position
	await kit.hold("ui_right", 1.0)
	kit.check(village.leader.position.x > start.x + 40, "walks right")

	# A facade stops you: from the front road, walk up into the tavern's front wall.
	var front := Vector2i(Village.TAVERN.end.x - 1, Village.TAVERN.end.y)
	await kit.stand(front)
	await kit.hold("ui_up", 1.5)
	kit.check(village.leader.position.y > Village.TAVERN.end.y * Level.TILE, "the tavern's facade stops the walk (%s)" % village.leader.position)
	await kit.shot("core_village")

	# Tap Wren from a few tiles away (she stands by the fields): the leader walks over and talks.
	await kit.stand(Vector2i(14, 29))
	await kit.wait(0.8)  # let the camera settle on the leader before tapping the world
	await kit.tap_world(village.feet_at(Vector2i(13, 26)) + Vector2(0, -8))
	await kit.until(func() -> bool: return kit.dialogue_open(), 6.0)
	kit.check(kit.dialogue_open(), "tapping Wren walks there and talks")
	await kit.shot("core_wren")
	await kit.read_on()
	while kit.dialogue_open():
		await kit.press("ui_cancel")
		await kit.wait(0.2)
	await kit.wait(0.2)
	kit.check(not kit.dialogue_open() and not Game.busy, "dialogue closes and frees the player")

	var before_tap := village.leader.position
	await kit.tap_world(before_tap + Vector2(40, 16))
	await kit.wait(1.2)
	kit.check(village.leader.position.distance_to(before_tap) > 20, "tapping the ground walks there")

	# Walk in through the shop door from the path below it.
	await kit.stand(Village.SHOP_DOOR + Vector2i.DOWN)
	await kit.hold("ui_up", 1.0)
	await kit.until(func() -> bool: return kit.level() is ShopRoom)
	kit.check(kit.level() is ShopRoom, "walks into the shop")
	await kit.wait(0.6)
	await kit.shot("core_shop")

	# The demo clock: a tap on the sun-and-moon dial lets a day pass.
	await kit.reset_to_village()
	await kit.until(func() -> bool: return kit.main._day_button.visible, 5.0)
	var day: String = Game.state.today
	await kit.tap_control(kit.main._day_button)
	await kit.until(func() -> bool: return Game.state.today != day)
	kit.check(Game.state.today != day, "a tap on the dial lets a day pass in the demo")
