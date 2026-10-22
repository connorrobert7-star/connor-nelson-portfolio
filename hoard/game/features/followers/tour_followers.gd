extends RefCounted
## The flock, played through taps and drags: the shrine on day one (an egg, a hungry flock),
## petting, collecting devotion at the altar, feeding by drag and by tap-tap, a level of
## loyalty that drops a cosmetic, dressing from the chest, the days passing (the away scene),
## a missed week mourned on Monday, money landing (the chant, the veils off, the hatch, the
## naming rite), the payday overnight, and Sunday's resize with the 40% giant.

var kit: TourKit


func run(k: TourKit) -> void:
	kit = k
	FollowersFeature.away_in_tours = false
	# The village plot (the village builder wires its door): a small fire with cultists around it.
	if kit.level() is Village:
		FollowersFeature.instance.build_village(kit.level(), Rect2i(30, 17, 6, 5))
		kit.level().leader.position = kit.level().feet_at(Vector2i(33, 23))
		await kit.wait(0.8)
		await kit.shot("followers_00_village_plot")
	await kit.go_to("shrine", Room.ENTRANCE)
	var shrine := kit.level() as ShrineLevel
	if not kit.check(shrine != null, "the shrine opens from its door level"):
		return
	await kit.wait(1.2)
	var flock := shrine.flock
	var f: Dictionary = Game.state.followers
	kit.check(flock.bodies.has("personal") and (flock.bodies.personal as FollowerBody).egg, "the personal follower is an egg before any deposit")
	kit.check(flock.bodies.size() == 1 + f.holdings.size() + int(f.cultists), "one body per follower: %d" % flock.bodies.size())
	kit.check(str(f.faith.band) == "content" and int(f.cultists) == 8, "Faith is content four days after the last landing, 8 cultists on the risers")
	var vti: FollowerBody = flock.bodies.get("hold_VTI")
	kit.check(vti != null and vti.pose == "hungry" and vti.bubble_name == "drool", "groceries over budget: the flock is hungry and drooling")
	await kit.shot("followers_01_shrine_day_one")

	# Tap a follower: it hops, a heart pops, loyalty and devotion go up.
	var pile := int(f.devotion.amount)
	await kit.tap_world(_center(vti))
	await kit.until(func() -> bool: return _follower("hold_VTI").get("petted_today", false), 5.0)
	# The day's first loyalty puts the day's share of devotion on the altar (capped).
	var cap := int(Game.state.followers.devotion.get("daily_cap", 60))
	var piled := int(Game.state.followers.devotion.amount)
	kit.check(piled > pile and piled - pile <= cap, "petting piles the day's devotion on the altar (%d -> %d)" % [pile, piled])
	await kit.wait(0.15)
	await kit.shot("followers_02_pet")

	# Tap the altar: the devotion flies over as coins.
	var coins := int(Game.state.coins)
	await kit.tap_world(ShrineLevel.ALTAR + Vector2(0, -30))
	await kit.until(func() -> bool: return int(Game.state.coins) > coins, 5.0)
	kit.check(int(Game.state.coins) == coins + piled, "tapping the altar collects the devotion as coins")
	kit.check(int(Game.state.followers.devotion.amount) == 0, "the altar is bare after collecting")

	# Drag the favorite from the cauldron onto VTI.
	coins = int(Game.state.coins)
	await _drag(ShrineLevel.PLATES.favorite, _center(vti))
	await kit.wait(0.25)
	await kit.shot("followers_03_feeding")
	await kit.until(func() -> bool: return int(_follower("hold_VTI").get("belly", 0)) == 100, 5.0)
	kit.check(int(Game.state.coins) == coins - 25, "the favorite costs 25 coins, nothing else")
	kit.check(_follower("hold_VTI").pose != "hungry", "a fed follower stops looking hungry")
	await kit.wait(0.8)

	# Tap the stew, then tap MSFT: the stew sticks to the cursor in between.
	var msft: FollowerBody = flock.bodies.get("hold_MSFT")
	await kit.tap_world(ShrineLevel.PLATES.stew)
	kit.check(flock.carrying(), "a tap on the stew picks it up")
	await kit.tap_world(_center(msft))
	await kit.until(func() -> bool: return int(_follower("hold_MSFT").get("belly", 0)) > 60, 5.0)
	kit.check(int(_follower("hold_MSFT").belly) == 100, "tap the food, tap the follower: fed")
	for fid in ["hold_SCHD", "hold_AAPL", "hold_VXUS"]:
		await kit.tap_world(_center(flock.bodies[fid]))
		await kit.wait(0.3)
	await kit.until(func() -> bool: return _follower("hold_VXUS").get("petted_today", false), 5.0)
	await kit.shot("followers_04_fed_and_petted")

	# A day passes: the "while you were out" scene plays, then the flock is hungry again.
	FollowersFeature.away_in_tours = true
	await _next_day(1, "followers_05_away_poses")
	await _tend_vti()
	await _next_day(1, "")
	await kit.tap_world(_center(flock.bodies["hold_VTI"]))
	await kit.until(func() -> bool: return int(_follower("hold_VTI").get("level", 1)) == 2, 5.0)
	kit.check(int(_follower("hold_VTI").level) == 2, "a full bar of loyalty is a level")
	await kit.until(func() -> bool: return not (Game.state.followers.wearables as Array).is_empty(), 5.0)
	kit.check(not (Game.state.followers.wearables as Array).is_empty(), "the level dropped a cosmetic from the flock's bag")
	await kit.wait(0.6)
	await kit.shot("followers_06_level_up")

	# The chest spills what you own; drag it onto a follower to dress it.
	await kit.tap_world(ShrineLevel.CHEST + Vector2(0, -14))
	await kit.wait(0.5)
	kit.check(shrine._wardrobe.get_child_count() > 0, "tapping the chest spills the wearables")
	await kit.shot("followers_07_wardrobe")
	var item_node := shrine._wardrobe.get_child(0) as Node2D
	var item: Dictionary = item_node.get_meta("item")
	await _drag(shrine._wardrobe.position + item_node.position, _center(flock.bodies["hold_VTI"]))
	await kit.until(func() -> bool: return not (_follower("hold_VTI").get("wearing", {}) as Dictionary).is_empty(), 5.0)
	kit.check((_follower("hold_VTI").wearing as Dictionary).has(str(item.slot)), "VTI wears the %s" % str(item.name))
	await kit.tap_world(ShrineLevel.CHEST + Vector2(0, -14))
	await kit.wait(0.6)
	await kit.shot("followers_08_dressed")

	# Four more days and nothing lands: on Monday the missed week is mourned.
	await _next_day(4, "followers_09_away_mourning", "mourning")
	shrine = kit.level() as ShrineLevel
	flock = shrine.flock
	f = Game.state.followers
	kit.check(bool(f.mourning), "Monday after a missed week: mourning")
	kit.check(str(f.faith.band) == "doubting", "ten days without money landing: doubting")
	kit.check((flock.bodies["hold_MSFT"] as FollowerBody).veil.visible, "the flock wears veils")
	kit.check(shrine._rain.emitting, "grey rain falls in the shrine")
	kit.check(shrine._grave.get_child_count() > 0, "a candle burns on the Grave of Weeks")
	kit.check(int(_follower("hold_AAPL").belly) == 0 and _follower("hold_AAPL").pose == "veiled", "nobody fed them: empty bellies under the veils")
	await kit.wait(1.0)
	await kit.shot("followers_10_mourning")

	# Money lands. A stock pick at the counter is quiet (no trade celebrations), but it is money
	# landing in your own account: the veils fly off, a flower grows by the candle, and the egg
	# hatches into the naming rite.
	var buy: Array = await Game.buy_stock("VTI", 25000)
	kit.check(buy[1] == "", "the shop counter takes a $250 VTI pick")
	kit.check(not flock.celebrating, "a stock pick never sets off the chant")
	f = Game.state.followers
	kit.check(not bool(f.mourning) and bool((f.graves as Array)[0].flower), "the veils come off and a flower grows by the candle")
	kit.check(str(f.faith.band) == "fervent", "Faith is fervent the day money lands")
	await kit.wait(0.5)
	await kit.shot("followers_11_veils_off_hatching")
	await kit.until(func() -> bool: return kit.overlay() is NamingOverlay, 8.0)
	await kit.wait(1.0)
	await kit.shot("followers_12_naming_rite")
	var rite := kit.overlay() as NamingOverlay
	if rite:
		var pick: Label = rite._words[1]
		var name := pick.text
		await kit.tap_control(pick)
		await kit.wait(0.5)
		await kit.shot("followers_13_named")
		await kit.until(func() -> bool: return kit.overlay() == null, 6.0)
		kit.check(str(Game.state.followers.personal.name) == name, "the hatchling is named %s by one tap" % name)
	await kit.wait(1.0)

	# A deposit the casino makes: they run to the circle, kneel and chant.
	Game.event_fired.emit({"kind": "money_moved", "amount_cents": 2000, "to_account": "sav_1", "status": "simulated", "reason": "Case: a $20 case"})
	await kit.wait(0.1)
	kit.check(flock.celebrating, "money landing: they run to the shrine and chant")
	await kit.wait(0.25)
	await kit.shot("followers_14_money_lands")
	await kit.wait(2.4)
	await kit.shot("followers_14b_kneel_and_chant")
	await kit.until(func() -> bool: return not flock.celebrating, 10.0)
	await kit.wait(1.5)
	await kit.shot("followers_15_fervent")

	# Next day, a second pick; then the Friday payday lands overnight; then Sunday's resize.
	await _next_day(1, "")
	await Game.buy_stock("VTI", 25000)
	await _next_day(4, "followers_16_away_payday", "landed")
	await _next_day(1, "followers_17_away_resized", "resized")
	f = Game.state.followers
	kit.check(str(f.giant) == "VTI", "over 40%% of the portfolio, VTI is a giant (%.3f)" % float(_follower("hold_VTI").get("share", 0)))
	shrine = kit.level() as ShrineLevel
	await kit.wait(2.0)
	var giant: FollowerBody = shrine.flock.bodies.get("hold_VTI")
	kit.check(giant != null and giant.px == 5, "the giant is drawn huge")
	var msft2: FollowerBody = shrine.flock.bodies.get("hold_MSFT")
	kit.check(msft2 != null and msft2.stare_at != Vector2.INF, "the others stare at the giant")
	await kit.shot("followers_18_giant")

	# The away scene also plays the other features' beats (the bank's debt payment as a gate
	# hit, a house stage built overnight), in priority order, under 12 seconds.
	var others: Array = [
		{"id": -3, "kind": "build", "priority": 20, "payload": {"stage": "frame"}},
		{"id": -2, "kind": "gate_hit", "priority": 30, "payload": {"debt_id": "debt_car", "amount_cents": 28500}},
		{"id": -1, "kind": "landed", "priority": 10, "payload": {"amount_cents": 35000}},
	]
	var started := Time.get_ticks_msec()
	var scene := WhileYouWereOutOverlay.new(others)
	kit.check(scene.beats.map(func(b: Dictionary) -> String: return str(b.kind)) == ["landed", "build", "gate_hit"], "beats play in priority order")
	kit.main.open_overlay(scene)
	var ref: WeakRef = weakref(scene)
	await kit.until(func() -> bool:
		var live: WhileYouWereOutOverlay = ref.get_ref()
		return live == null or live.played.has("gate_hit"), 12.0)
	await kit.wait(0.9)
	await kit.shot("followers_19_away_gate_hit")
	await kit.until(func() -> bool: return kit.overlay() == null, 12.0)
	kit.check(Time.get_ticks_msec() - started < 12500, "the whole scene takes 12 seconds or less")
	FollowersFeature.away_in_tours = false


func _drag(from: Vector2, to: Vector2) -> void:
	var vp := kit.get_viewport()
	var xf := vp.get_screen_transform() * vp.get_canvas_transform()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = xf * from
	down.global_position = down.position
	Input.parse_input_event(down)
	await kit.frames(2)
	for i in 10:
		var m := InputEventMouseMotion.new()
		m.position = xf * from.lerp(to, (i + 1) / 10.0)
		m.global_position = m.position
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(m)
		await kit.frames(1)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = xf * to
	up.global_position = up.position
	Input.parse_input_event(up)
	await kit.frames(2)


func _center(b: FollowerBody) -> Vector2:
	return b.position + Vector2(0, -b.height() * 0.5)


func _follower(fid: String) -> Dictionary:
	var f: Dictionary = Game.state.get("followers", {})
	if fid == "personal":
		return f.get("personal", {})
	for h: Dictionary in f.get("holdings", []):
		if h.id == fid:
			return h
	return {}


## Pet VTI and feed it its favorite, collecting devotion first for the coins.
func _tend_vti() -> void:
	var shrine := kit.level() as ShrineLevel
	await kit.tap_world(_center(shrine.flock.bodies["hold_VTI"]))
	await kit.until(func() -> bool: return _follower("hold_VTI").get("petted_today", false), 5.0)
	await kit.tap_world(ShrineLevel.ALTAR + Vector2(0, -30))
	await kit.wait(1.0)
	await _drag(ShrineLevel.PLATES.favorite, _center(shrine.flock.bodies["hold_VTI"]))
	await kit.until(func() -> bool: return _follower("hold_VTI").get("fed_today", false), 5.0)
	await kit.wait(1.2)


## Let days pass in the demo, watch the away scene, and wait for it to finish.
func _next_day(days: int, shot: String, expect := "") -> void:
	var day: String = Game.state.today
	if days > 1:
		await Game.call_api("POST", "/clock/advance", {"days": days - 1})
	await Game.advance_days(1)
	await kit.until(func() -> bool: return Game.state.today != day, 5.0)
	var appeared := await kit.until(func() -> bool: return kit.overlay() is WhileYouWereOutOverlay, 6.0)
	kit.check(appeared, "the away scene plays after a day line")
	if not appeared:
		return
	var o := kit.overlay() as WhileYouWereOutOverlay
	var kinds: Array = o.beats.map(func(b: Dictionary) -> String: return str(b.kind))
	kit.check("hug" in kinds and "poses" in kinds, "the flock's beats are queued: %s" % ", ".join(PackedStringArray(kinds)))
	if expect != "":
		kit.check(expect in kinds, "a %s beat is in the queue" % expect)
		var ref: WeakRef = weakref(o)
		await kit.until(func() -> bool:
			var live: WhileYouWereOutOverlay = ref.get_ref()
			return live == null or live.played.has(expect), 12.0)
		await kit.wait(1.1)
	else:
		await kit.wait(1.6)
	if shot != "":
		await kit.shot(shot)
	await kit.until(func() -> bool: return kit.overlay() == null, 15.0)
	kit.check((Game.state.away as Array).is_empty(), "the beats are marked seen")
	await kit.wait(0.6)
