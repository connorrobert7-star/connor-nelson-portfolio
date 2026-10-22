extends RefCounted
## Playtest: the shrine and the "while you were out" scene played like the owner on a phone,
## through real touches and finger drags (Godot makes a click from each touch too, like on
## the phone). After every step it checks the state: the chest opens and stays open, a pet
## counts once, food you can't pay for shakes its price and nothing is carried, a tap-tap and
## a drag both feed and cost exactly the food's price, the altar pays exactly its pile, the
## hatchling's name is picked by one touch, and a touch skips one beat of the night scene.
##   godot --path game res://dev/tour.tscn -- <out> res://features/followers/tour_play.gd

var kit: TourKit
var shrine: ShrineLevel


func run(k: TourKit) -> void:
	kit = k
	FollowersFeature.away_in_tours = false
	await kit.go_to("shrine", Room.ENTRANCE)
	shrine = kit.level() as ShrineLevel
	if not kit.check(shrine != null, "the shrine opens"):
		return
	await kit.wait(1.0)
	await _chest()
	await _pet_and_collect()
	await _feed()
	await _name()
	await _away()
	FollowersFeature.away_in_tours = false


func _chest() -> void:
	var at := _world(ShrineLevel.CHEST + Vector2(0, -14))
	var t := Time.get_ticks_msec()
	await touch(at)
	await kit.wait(0.3)
	kit.check(shrine._chest_open, "a touch on the chest opens it, and it stays open")
	kit.check(_heard(t), "with a creak")
	await touch(at)
	await kit.wait(0.3)
	kit.check(not shrine._chest_open, "a second touch shuts it")


func _pet_and_collect() -> void:
	var vti: FollowerBody = shrine.flock.bodies.get("hold_VTI")
	if not kit.check(vti != null, "VTI is in the flock"):
		return
	var pile := int(Game.state.followers.devotion.amount)
	var loyalty := int(_follower("hold_VTI").get("loyalty", 0))
	var t := Time.get_ticks_msec()
	await touch(_world(_center(vti)))
	kit.check(_heard(t), "a pet is answered at once")
	await kit.until(func() -> bool: return bool(_follower("hold_VTI").get("petted_today", false)), 5.0)
	await kit.wait(0.4)
	var gained := int(_follower("hold_VTI").get("loyalty", 0)) - loyalty
	kit.check(bool(_follower("hold_VTI").get("petted_today", false)), "a touch pets VTI")
	await touch(_world(_center(vti)))
	await kit.wait(0.6)
	var again := int(_follower("hold_VTI").get("loyalty", 0)) - loyalty
	kit.check(again == gained, "a second pet the same day adds nothing (%d then %d)" % [gained, again])
	var piled := int(Game.state.followers.devotion.amount)
	kit.check(piled > pile, "the pet piles devotion on the altar (%d -> %d)" % [pile, piled])
	# The favorite costs more than the purse holds before the altar is collected.
	var coins := int(Game.state.coins)
	if coins < 25:
		t = Time.get_ticks_msec()
		await touch(_world(ShrineLevel.PLATES.favorite))
		kit.check(_heard(t), "food you can't pay for answers (the price shakes)")
		kit.check(not shrine.flock.carrying(), "and nothing is picked up")
	await touch(_world(ShrineLevel.ALTAR + Vector2(0, -30)))
	await kit.until(func() -> bool: return int(Game.state.coins) > coins, 5.0)
	kit.check(int(Game.state.coins) == coins + piled, "a touch on the altar collects exactly its pile (%d + %d)" % [coins, piled])
	kit.check(int(Game.state.followers.devotion.amount) == 0, "and the altar is bare")


func _feed() -> void:
	var msft: FollowerBody = shrine.flock.bodies.get("hold_MSFT")
	var vti: FollowerBody = shrine.flock.bodies.get("hold_VTI")
	if msft == null or vti == null:
		return
	var price := _price("stew")
	var coins := int(Game.state.coins)
	await touch(_world(ShrineLevel.PLATES.stew))
	kit.check(shrine.flock.carrying(), "a touch on the stew picks it up")
	await kit.wait(0.2)
	kit.check(shrine.flock.carrying(), "and it stays on the finger after the touch lifts")
	await touch(_world(_center(msft)))
	await kit.until(func() -> bool: return bool(_follower("hold_MSFT").get("fed_today", false)), 5.0)
	kit.check(bool(_follower("hold_MSFT").get("fed_today", false)), "a touch on MSFT feeds it")
	await kit.wait(0.6)
	kit.check(int(Game.state.coins) == coins - price, "the stew costs exactly %d coins" % price)
	# A finger drags the favorite onto VTI.
	coins = int(Game.state.coins)
	price = _price("favorite")
	if coins >= price:
		await drag(ShrineLevel.PLATES.favorite, _center(vti))
		await kit.until(func() -> bool: return bool(_follower("hold_VTI").get("fed_today", false)), 5.0)
		kit.check(bool(_follower("hold_VTI").get("fed_today", false)), "a finger drags the favorite onto VTI")
		await kit.wait(0.6)
		kit.check(int(Game.state.coins) == coins - price, "the favorite costs exactly %d coins" % price)
	kit.check(not shrine.flock.carrying(), "nothing is left on the finger")
	await kit.shot("play_shrine_fed")


func _name() -> void:
	# Money lands (a stock pick at the shop counter, through the API): the egg hatches.
	var buy: Array = await Game.buy_stock("VTI", 25000)
	kit.check(buy[1] == "", "money lands")
	var rite := await _poll(func() -> bool: return kit.overlay() is NamingOverlay, 8.0)
	if not rite:
		# The rite opens from a touch on the hatchling too.
		var p: FollowerBody = shrine.flock.bodies.get("personal")
		if p:
			await touch(_world(_center(p)))
		await kit.until(func() -> bool: return kit.overlay() is NamingOverlay, 6.0)
	var o := kit.overlay() as NamingOverlay
	if not kit.check(o != null, "the naming rite opens"):
		return
	await kit.wait(1.2)
	var word: Label = o._words[1]
	var chosen := word.text
	await touch(_ctl(word))
	kit.check(o.chosen == chosen, "one touch picks a name (%s)" % chosen)
	await touch(_ctl(o._words[0]))
	kit.check(o.chosen == chosen, "a second touch can't change it")
	await kit.until(func() -> bool: return kit.overlay() == null, 8.0)
	kit.check(kit.overlay() == null and not Game.busy, "the rite closes and frees the shrine")
	await Game.refresh()
	kit.check(str(Game.state.followers.personal.get("name", "")) == chosen, "the hatchling is named %s" % chosen)
	await kit.wait(0.6)
	var p2: FollowerBody = shrine.flock.bodies.get("personal")
	if p2:
		var t := Time.get_ticks_msec()
		await touch(_world(_center(p2)))
		kit.check(_heard(t), "the named hatchling answers a pet")
		await kit.wait(0.5)
		kit.check(not (kit.overlay() is NamingOverlay), "and no second rite opens")


func _away() -> void:
	FollowersFeature.away_in_tours = true
	await kit.until(func() -> bool: return not Game.busy and kit.main._day_button.visible, 8.0)
	var day := str(Game.state.today)
	await touch(_ctl(kit.main._day_button))
	await kit.until(func() -> bool: return str(Game.state.today) != day, 8.0)
	var shown := await _poll(func() -> bool: return kit.overlay() is WhileYouWereOutOverlay, 8.0)
	if not kit.check(shown, "a day later the night scene plays"):
		return
	var o := kit.overlay() as WhileYouWereOutOverlay
	var ref: WeakRef = weakref(o)
	kit.log_line("  night beats: %s" % str(o.beats.map(func(b: Dictionary) -> String: return str(b.kind))))
	await kit.until(func() -> bool: return o.played.size() >= 1, 4.0)
	await kit.wait(0.3)
	if o.beats.size() >= 2:
		var n := o.played.size()
		await touch(_screen(Vector2(240, 135)))
		await kit.wait(0.15)
		var live: WhileYouWereOutOverlay = ref.get_ref()
		if live:
			kit.check(live.played.size() == n + 1, "one touch skips one beat (%d -> %d)" % [n, live.played.size()])
	await kit.shot("play_away")
	# Quick taps run the rest down; what a skipped beat had left to do never lands in the next.
	for i in 3:
		await touch(_screen(Vector2(240, 135)))
		await kit.wait(0.1)
	await kit.until(func() -> bool: return kit.overlay() == null, 15.0)
	kit.check(kit.overlay() == null and not Game.busy, "the night scene ends and frees the shrine")
	await Game.refresh()
	kit.check((Game.state.away as Array).is_empty(), "its beats are marked seen")
	# The shrine still answers after it.
	var vti: FollowerBody = shrine.flock.bodies.get("hold_VTI")
	if vti:
		await touch(_world(_center(vti)))
		await kit.until(func() -> bool: return bool(_follower("hold_VTI").get("petted_today", false)), 5.0)
		kit.check(bool(_follower("hold_VTI").get("petted_today", false)), "after the scene a touch still pets")


# --- helpers ---------------------------------------------------------------------------

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


func _price(food_id: String) -> int:
	for food: Dictionary in Game.state.get("followers", {}).get("foods", []):
		if str(food.get("id", "")) == food_id:
			return int(food.get("price", 0))
	return 0


func _heard(since: int) -> bool:
	for p: Variant in Sfx._started:
		if int(Sfx._started[p]) >= since:
			return true
	return false


func _poll(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while not cond.call():
		if t > timeout:
			return false
		await kit.frames(1)
		t += kit.get_process_delta_time()
	return true


# --- input, the way a phone sends it ---------------------------------------------------

func touch(p: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = true
	ev.position = p
	Input.parse_input_event(ev)
	await kit.frames(1)
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = p
	Input.parse_input_event(up)
	await kit.frames(2)


## A finger down on one world point, dragged to another, lifted there.
func drag(from: Vector2, to: Vector2) -> void:
	var a := _world(from)
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = true
	ev.position = a
	Input.parse_input_event(ev)
	await kit.frames(2)
	var prev := a
	for i in 10:
		var p := _world(from.lerp(to, (i + 1) / 10.0))
		var d := InputEventScreenDrag.new()
		d.index = 0
		d.position = p
		d.relative = p - prev
		Input.parse_input_event(d)
		prev = p
		await kit.frames(1)
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = prev
	Input.parse_input_event(up)
	await kit.frames(2)


func _world(p: Vector2) -> Vector2:
	var vp := kit.get_viewport()
	return vp.get_screen_transform() * vp.get_canvas_transform() * p


func _screen(p: Vector2) -> Vector2:
	return kit.get_viewport().get_screen_transform() * p


func _ctl(c: Control) -> Vector2:
	return _screen(c.get_global_rect().get_center())
