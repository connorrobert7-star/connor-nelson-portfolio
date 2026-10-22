extends RefCounted
## The shop and the tavern, drawn to fill the screen: arrive, look, tap things, buy quietly,
## and walk back out the door.


func run(kit: TourKit) -> void:
	await kit.go_to("shop", Room.ENTRANCE)
	kit.check(kit.level() is ShopRoom, "the shop opens")
	var shop := kit.level() as ShopRoom
	await kit.wait(0.8)
	await kit.shot("interiors_shop_arrive")
	kit.check(shop.room_rect().size == Vector2(480, 272), "the shop fills the screen (%s)" % shop.room_rect().size)
	kit.check(shop.leader.position.distance_to(shop.feet_at(Room.ENTRANCE)) < 2, "you arrive just inside the door")
	var tags := shop.dynamic.get_children().filter(func(n: Node) -> bool: return n is ShopRoom.PriceTag)
	kit.check(tags.size() == mini(10, (Game.state.shop.stocks as Array).size()), "every stock has a price tag (%d)" % tags.size())
	var first: ShopRoom.PriceTag = tags[0]
	var s0: Dictionary = Game.state.shop.stocks[0]
	kit.check(first.symbol == str(s0.symbol) and first.hours == "%.1fh" % float(s0.price_hours), "the tag reads the symbol and the hours of work")
	kit.check(first.price == ShopRoom._price(int(s0.price_cents)), "the tag reads last Sunday's close (%s)" % first.price)
	await kit.wait(0.3)
	kit.check(not kit.main.panel.visible and kit.main.prompt_label.text == "", "no text panel or prompt in the shop")

	# Tap a shelf: the leader walks to it and Marlo asks how much.
	await kit.tap_world(Vector2(ShopRoom.SHELF_X[2], ShopRoom.ROW_A - 30))
	await kit.until(func() -> bool: return kit.dialogue_open(), 6.0)
	kit.check(kit.dialogue_open(), "tapping a shelf walks there and asks how much")
	await kit.shot("interiors_shop_shelf")
	await kit.reset_to_village()

	# Tap Marlo himself (not his spot) and buy: the register clunks, Marlo nods, nothing more.
	await kit.go_to("shop", Room.ENTRANCE)
	shop = kit.level() as ShopRoom
	await kit.tap_world(shop.marlo.position + Vector2(0, -16))
	await kit.until(func() -> bool: return kit.dialogue_open(), 6.0)
	kit.check(kit.dialogue_open(), "tapping Marlo walks to the counter and talks")
	await kit.read_on()
	await kit.choose("Buy shares")
	await kit.choose(0)
	await kit.read_on()
	var before := int(Game.state.extra.extra_cents)
	await kit.choose(0)
	await kit.choose("Buy")
	await kit.until(func() -> bool: return int(Game.state.extra.extra_cents) < before)
	kit.check(int(Game.state.extra.extra_cents) == before - 2500, "a $25 buy lowers extra by $25")
	await kit.wait(0.25)
	await kit.shot("interiors_shop_bought")
	await kit.reset_to_village()

	# Back out: from just inside the door, walk down.
	await kit.go_to("shop", Room.ENTRANCE)
	await kit.stand(Vector2i(7, 9))
	await kit.hold("ui_down", 0.6)
	await kit.until(func() -> bool: return kit.level() is Village, 5.0)
	kit.check(kit.level() is Village, "the shop door leads out")

	await kit.go_to("tavern", Room.ENTRANCE)
	kit.check(kit.level() is TavernRoom, "the tavern opens")
	var tavern := kit.level()
	await kit.wait(1.0)
	await kit.shot("interiors_tavern_arrive")
	kit.check(tavern is Room and (tavern as Room).room_rect().size == Vector2(480, 272), "the tavern fills the screen")
	await kit.wait(1.6)
	await kit.shot("interiors_tavern_later")
	await kit.stand(Vector2i(7, 9))
	await kit.hold("ui_down", 0.6)
	await kit.until(func() -> bool: return kit.level() is Village, 5.0)
	kit.check(kit.level() is Village, "the tavern door leads out")
