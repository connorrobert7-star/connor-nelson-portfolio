extends RefCounted
## Every door, both ways, by tap, from a fresh save (the game opens in the casino):
## casino -> village -> arcade -> village -> shrine -> village -> gate -> village -> shop
## -> village -> tavern -> village -> casino. After each one: the new place loaded, the player
## is free, the leader stands on open floor in front of the door he came through (not on it),
## the camera is on him, the iris is open, and a tap on the ground walks him at once. Then the
## rough stuff: a door tapped twice fast, taps during the iris, out and straight back in.
##   godot --path game res://dev/tour.tscn -- <out> res://dev/tours/tour_doors.gd

const ROUTE := ["village", "arcade", "village", "shrine", "village", "gate", "village", "shop", "village", "tavern", "village", "casino"]

var kit: TourKit
var _shot := 0


func run(k: TourKit) -> void:
	kit = k
	await kit.until(func() -> bool: return kit.level() != null and not Game.busy, 20.0)
	kit.check(_id(kit.level()) == "casino", "a fresh save opens in the casino (%s)" % _id(kit.level()))
	await kit.wait(0.3)
	await _settle()
	var here := "casino"
	for next: String in ROUTE:
		var ok := await _through(here, next)
		if not ok:
			# Put the walk back on its route so one broken door doesn't hide the rest.
			await kit.go_to(next, Room.ENTRANCE if next != "village" else Village.SPAWN)
		here = next
	await _twice_fast()
	await _tap_during()
	await _out_and_back()
	await _by_finger()
	await _tap_building()


# --- one door ----------------------------------------------------------------------------

## Walk by tap from `from` into `to` through the door between them, then check the arrival.
func _through(from: String, to: String) -> bool:
	var lv := kit.level()
	var door := _door_to(lv, to)
	if not kit.check(not door.is_empty(), "%s has a door to %s" % [from, to]):
		return false
	var reached := await _walk_into(door)
	if not kit.check(reached, "%s -> %s: tapping the door walks through it" % [from, to]):
		await _snap("stuck_%s_to_%s" % [from, to])
		return false
	return await _arrival(from, to)


## Tap toward the door (via open ground on screen while it's off screen) until a level
## change starts. False if the leader stops short every time.
func _walk_into(door: Dictionary) -> bool:
	var lv := kit.level()
	var aim: Vector2 = (door.rect as Rect2).get_center()
	for attempt in 8:
		if kit.level() != lv or Game.busy:
			break
		var p := _on_screen_toward(aim)
		kit.log_line("    tap %s (leader %s)" % [p.round(), lv.leader.position.round()])
		await kit.tap_world(p)
		var moved_from := lv.leader.position
		var still := 0.0
		while kit.level() == lv and not Game.busy and is_instance_valid(lv):
			await kit.frames(1)
			if lv.leader.position.distance_to(moved_from) < 0.05:
				still += kit.get_process_delta_time()
			else:
				still = 0.0
			moved_from = lv.leader.position
			if still > 0.4:
				break
	var was := lv.get_instance_id()
	await kit.until(func() -> bool: return kit.level() == null or kit.level().get_instance_id() != was, 2.0)
	var left := kit.level() == null or kit.level().get_instance_id() != was
	if not left:
		kit.log_line("    stopped at %s, target %s, busy %s, overlay %s, dialogue %s" % [lv.leader.position.round(), lv.leader.target, Game.busy, kit.overlay(), kit.dialogue_open()])
		await kit.reset_to_village()
	return left


## Where to tap: the door itself if it's on screen, else the open ground on screen nearest
## to it (clear of the HUD, of people and things to use, and of other doors).
func _on_screen_toward(aim: Vector2) -> Vector2:
	var v := _view()
	var view := Rect2(v.position + Vector2(8, 48), v.size - Vector2(16, 52))
	if view.has_point(aim):
		return aim
	var lv := kit.level()
	var best := lv.leader.position
	var best_d := INF
	var y := view.position.y
	while y < view.end.y:
		var x := view.position.x
		while x < view.end.x:
			var p := Vector2(x, y)
			var d := p.distance_to(aim)
			if d < best_d and lv.is_walkable(Rect2(p + Leader.FOOT.position, Leader.FOOT.size)) and _bare(lv, p):
				var in_door := false
				for door: Dictionary in lv._doors:
					if (door.rect as Rect2).grow(10).has_point(p):
						in_door = true
				if not in_door:
					best = p
					best_d = d
			x += 8.0
		y += 8.0
	return best


## Open ground the owner could tap without hitting a villager, a cultist or a thing to use.
func _bare(lv: Level, p: Vector2) -> bool:
	for it: Dictionary in lv._interactables:
		if p.distance_to(it.pos) < Level.TAP_RADIUS + 4:
			return false
	if lv is Village:
		for c: VillageCultist in (lv as Village).cultists:
			if p.distance_to(c.position + Vector2(0, -7)) < 16:
				return false
	return true


# --- arriving ----------------------------------------------------------------------------

func _arrival(from: String, to: String) -> bool:
	var tag := "%s -> %s" % [from, to]
	await kit.until(func() -> bool: return kit.level() != null and kit.level().is_inside_tree(), 3.0)
	var lv := kit.level()
	var t0 := Time.get_ticks_msec()
	await _free(6.0)
	var took := (Time.get_ticks_msec() - t0) / 1000.0
	var all_ok := true
	all_ok = kit.check(_id(lv) == to, "%s: the %s loaded (%s)" % [tag, to, _id(lv)]) and all_ok
	all_ok = kit.check(not Game.busy, "%s: the player is free (%.2fs)" % [tag, took]) and all_ok
	all_ok = kit.check(_levels_in_world() == 1, "%s: one place in the world (%d)" % [tag, _levels_in_world()]) and all_ok
	var iris: float = (kit.main.fade.material as ShaderMaterial).get_shader_parameter("radius")
	all_ok = kit.check(iris >= Main.IRIS_OPEN - 1.0, "%s: the iris is open (%.0f)" % [tag, iris]) and all_ok
	var feet := lv.leader.position
	all_ok = kit.check(lv.is_walkable(Rect2(feet + Leader.FOOT.position, Leader.FOOT.size)), "%s: the leader stands on open floor %s" % [tag, feet]) and all_ok
	var on_door := false
	for d: Dictionary in lv._doors:
		if (d.rect as Rect2).grow(2).has_point(feet):
			on_door = true
	all_ok = kit.check(not on_door, "%s: the leader is not standing in a doorway" % tag) and all_ok
	var back := _door_to(lv, from)
	var gap := INF
	if not back.is_empty():
		gap = feet.distance_to((back.rect as Rect2).get_center())
	# In the village that's the tile outside the building's door; a room may walk him a step
	# or two in (the casino puts him in front of the table), never further.
	# The gate's way out runs under the wall, so he comes out on the road in front of it.
	var near := 50.0 if not (lv is Village) or from == "gate" else 34.0
	all_ok = kit.check(gap < near, "%s: he stands just in front of the door back to %s (%.0f px)" % [tag, from, gap]) and all_ok
	# The camera is on him: his feet well inside the screen. (The village's overnight beats
	# pan away to the house or the wall on the first visit; that show ends back on him.)
	if lv is Village and (lv as Village)._beats_running:
		kit.log_line("    the village plays its beats first")
		await kit.until(func() -> bool: return not (lv as Village)._beats_running, 25.0)
		await kit.wait(0.6)
	await kit.frames(2)
	var screen := lv.leader.get_global_transform_with_canvas().origin
	var vp := kit.get_viewport().get_visible_rect().size
	var inside := Rect2(Vector2(24, 40), vp - Vector2(48, 50)).has_point(screen)
	all_ok = kit.check(inside, "%s: the camera shows him (screen %s)" % [tag, screen.round()]) and all_ok
	await _snap("%s_to_%s" % [from, to])
	# A tap on open ground walks him right away.
	all_ok = await _tap_walks(tag) and all_ok
	return all_ok


## Tap open ground a little way off; he must start walking within a few frames.
func _tap_walks(tag: String) -> bool:
	var lv := kit.level()
	var feet := lv.leader.position
	var spot := Vector2.INF
	for off: Vector2 in [Vector2(0, -24), Vector2(24, -8), Vector2(-24, -8), Vector2(32, 0), Vector2(-32, 0), Vector2(0, -40)]:
		var p := feet + off
		if not lv.is_walkable(Rect2(p + Leader.FOOT.position, Leader.FOOT.size)):
			continue
		var near_thing := false
		for it: Dictionary in lv._interactables:
			if p.distance_to(it.pos) < Level.TAP_RADIUS + 4:
				near_thing = true
		for d: Dictionary in lv._doors:
			if (d.rect as Rect2).grow(8).has_point(p):
				near_thing = true
		if not near_thing:
			spot = p
			break
	if not kit.check(spot != Vector2.INF, "%s: open ground near him to tap" % tag):
		return false
	await kit.tap_world(spot)
	await kit.wait(0.25)
	var moved := lv.leader.position.distance_to(feet)
	var ok := kit.check(moved > 4.0 and kit.level() == lv, "%s: a tap right after arriving walks him (%.1f px)" % [tag, moved])
	await kit.until(func() -> bool: return lv.leader.target == Vector2.INF, 2.0)
	await kit.wait(0.1)
	return ok


# --- the rough stuff ---------------------------------------------------------------------

## Tap a door twice in quick succession: one trip, one place, a free player.
func _twice_fast() -> void:
	await kit.go_to("village", Village.SPAWN)
	await _settle()
	var lv := kit.level()
	var door := _door_to(lv, "shop")
	await kit.stand((door.tile as Vector2i) + Vector2i.DOWN * 2)
	await kit.wait(0.5)
	var aim: Vector2 = (door.rect as Rect2).get_center()
	var was := lv.get_instance_id()
	await kit.tap_world(aim)
	await kit.tap_world(aim)
	await kit.until(func() -> bool: return Game.busy, 3.0)
	await kit.tap_screen(kit.get_viewport().get_screen_transform() * kit.get_viewport().get_canvas_transform() * aim)
	await kit.until(func() -> bool: return kit.level().get_instance_id() != was and not Game.busy, 4.0)
	await kit.wait(0.6)
	kit.check(_id(kit.level()) == "shop", "a door tapped twice fast: one trip, into the shop (%s)" % _id(kit.level()))
	kit.check(_levels_in_world() == 1, "a door tapped twice fast: one place in the world (%d)" % _levels_in_world())
	kit.check(not Game.busy, "a door tapped twice fast: the player is free")
	await _snap("twice_fast")


## Taps during the iris land nowhere: no walk queued in the new place, no second trip.
func _tap_during() -> void:
	var lv := kit.level()
	var door := _door_to(lv, "village")
	var aim: Vector2 = (door.rect as Rect2).get_center()
	await kit.tap_world(aim)
	await kit.until(func() -> bool: return Game.busy, 3.0)
	var vp := kit.get_viewport().get_visible_rect().size
	var taps := 0
	# Whether the last press was handled after the iris had let go: a tap that lands the
	# frame the player is free walks him, as any tap then should. Only taps handled while
	# the iris ran must leave nothing behind.
	var last_free := false
	while Game.busy and taps < 30:
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.position = Vector2(vp.x * (0.3 + 0.04 * (taps % 10)), vp.y * 0.55)
		down.global_position = down.position
		Input.parse_input_event(down)
		await kit.frames(1)
		last_free = not Game.busy
		var up := down.duplicate() as InputEventMouseButton
		up.pressed = false
		Input.parse_input_event(up)
		await kit.frames(2)
		taps += 1
	await kit.until(func() -> bool: return not Game.busy, 4.0)
	await kit.frames(3)
	var now := kit.level()
	kit.check(_id(now) == "village", "taps during the iris: still one trip, out to the village (%s, %d taps)" % [_id(now), taps])
	kit.check(now.leader.target == Vector2.INF or last_free, "taps during the iris queue no walk in the new place (last tap after it let go: %s)" % last_free)
	kit.check(_levels_in_world() == 1, "taps during the iris: one place in the world")


## Out of a place and straight back in: the door answers the moment the iris lets go.
func _out_and_back() -> void:
	for place in ["arcade", "tavern", "shop", "shrine", "gate", "casino"]:
		await kit.go_to(place, Room.ENTRANCE)
		await _settle()
		if not await _walk_into(_door_to(kit.level(), "village")):
			kit.check(false, "out of the %s: the door works" % place)
			continue
		await kit.until(func() -> bool: return kit.level() is Village and not Game.busy, 4.0)
		var lv := kit.level()
		var door := _door_to(lv, place)
		await kit.tap_world((door.rect as Rect2).get_center())
		var was := lv.get_instance_id()
		await kit.until(func() -> bool: return kit.level().get_instance_id() != was, 3.0)
		await _free(6.0)
		kit.check(_id(kit.level()) == place and not Game.busy, "out of the %s and straight back in (%s)" % [place, _id(kit.level())])
		kit.check(_levels_in_world() == 1, "out of the %s and back: one place in the world" % place)
	await _snap("out_and_back")


## A finger on a phone: one touch is one tap (not a touch and its emulated click both), and
## it walks him through the door like a click does.
func _by_finger() -> void:
	await kit.go_to("village", Village.SPAWN)
	await _settle()
	var lv := kit.level()
	var door := _door_to(lv, "shop")
	await kit.stand((door.tile as Vector2i) + Vector2i.DOWN * 2)
	await kit.wait(0.6)
	var vp := kit.get_viewport()
	var screen := vp.get_screen_transform() * vp.get_canvas_transform() * (door.rect as Rect2).get_center()
	var rings_before := _rings(lv)
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = screen
	down.pressed = true
	Input.parse_input_event(down)
	await kit.frames(1)
	var rings := _rings(lv) - rings_before
	var up := down.duplicate() as InputEventScreenTouch
	up.pressed = false
	Input.parse_input_event(up)
	kit.check(rings == 1, "a finger's tap lands once (%d rings, touch-to-click %s)" % [rings, Input.is_emulating_mouse_from_touch()])
	var was := lv.get_instance_id()
	await kit.until(func() -> bool: return kit.level().get_instance_id() != was and not Game.busy, 4.0)
	kit.check(_id(kit.level()) == "shop", "a finger on the door walks him in (%s)" % _id(kit.level()))


## A tap on the building itself (its sign, its roof), not the doorway, walks him in too.
func _tap_building() -> void:
	await kit.go_to("village", Village.SPAWN)
	await _settle()
	var lv := kit.level()
	await kit.stand(Vector2i(28, 22))
	await kit.wait(0.8)
	var roof := Vector2(Village.SHOP.position * Level.TILE) + Vector2(Village.SHOP.size.x * Level.TILE / 2.0, 10)
	await kit.tap_world(roof)
	var was := lv.get_instance_id()
	await kit.until(func() -> bool: return kit.level().get_instance_id() != was and not Game.busy, 6.0)
	kit.check(_id(kit.level()) == "shop", "a tap on the shop's roof walks him in through its door (%s)" % _id(kit.level()))
	# The door's top frame, just above the doorway, is where a thumb lands: it goes in on
	# every building, never into a build tap pinned to the facade.
	for place: String in ["tavern", "arcade", "shrine", "shop", "casino"]:
		for up: int in [8, 14]:
			await kit.go_to("village", Village.SPAWN)
			await _settle()
			var vl := kit.level()
			var door := _door_to(vl, place)
			if not kit.check(not door.is_empty(), "the village has a door to the %s" % place):
				continue
			vl.leader.position = vl.door_front(place) + Vector2(0, 32)
			await kit.wait(0.4)
			var r: Rect2 = door.rect
			var p := Vector2(r.get_center().x, r.position.y - 3.0 - up)
			var vp := kit.get_viewport()
			var screen := vp.get_screen_transform() * vp.get_canvas_transform() * p
			var down := InputEventScreenTouch.new()
			down.index = 0
			down.position = screen
			down.pressed = true
			Input.parse_input_event(down)
			await kit.frames(1)
			var lift := down.duplicate() as InputEventScreenTouch
			lift.pressed = false
			Input.parse_input_event(lift)
			var gone := vl.get_instance_id()
			await kit.until(func() -> bool: return kit.level().get_instance_id() != gone and not Game.busy, 6.0)
			kit.check(_id(kit.level()) == place, "a finger %d px above the %s's doorway walks him in (%s)" % [up, place, _id(kit.level())])
			await _free(6.0)


func _rings(lv: Level) -> int:
	var n := 0
	for c in lv.get_children():
		if c is TapMarker and not c.is_queued_for_deletion():
			n += 1
	return n


# --- helpers -----------------------------------------------------------------------------

func _id(lv: Level) -> String:
	if lv == null:
		return "none"
	if "level_id" in lv and str(lv.get("level_id")) != "":
		return str(lv.get("level_id"))
	if lv is CasinoRoom:
		return "casino"
	if lv is ArcadeRoom:
		return "arcade"
	if lv is ShrineLevel:
		return "shrine"
	if lv is GateLevel:
		return "gate"
	if lv is ShopRoom:
		return "shop"
	if lv is TavernRoom:
		return "tavern"
	if lv is Village:
		return "village"
	return "?"


## The door in `lv` that leads to `to` (the middle one when a doorway is several tiles wide).
func _door_to(lv: Level, to: String) -> Dictionary:
	var found: Array[Dictionary] = []
	for d: Dictionary in lv._doors:
		if d.level == to:
			found.append(d)
	if found.is_empty():
		return {}
	var r: Rect2 = found[0].rect
	for d in found:
		r = r.merge(d.rect)
	return {"rect": r, "tile": found[0].tile, "level": to}


func _levels_in_world() -> int:
	var n := 0
	for c in kit.main.world.get_children():
		if c is Level and not c.is_queued_for_deletion():
			n += 1
	return n


func _view() -> Rect2:
	var vp := kit.get_viewport()
	var inv := vp.get_canvas_transform().affine_inverse()
	var size := vp.get_visible_rect().size
	return Rect2(inv * Vector2.ZERO, inv.basis_xform(size))


## Until the player is free and stays free (a place's own scene may take him back a frame
## after the iris lets go).
func _free(timeout: float) -> void:
	var t := 0.0
	var calm := 0
	while calm < 6 and t < timeout:
		await kit.frames(1)
		t += kit.get_process_delta_time()
		calm = 0 if Game.busy else calm + 1


## Wait out whatever plays when a place opens (the gate's intro, the village's beats).
func _settle() -> void:
	await _free(12.0)
	var lv := kit.level()
	if lv is Village:
		await kit.until(func() -> bool: return not (lv as Village)._beats_running, 25.0)
	await kit.wait(0.2)


func _snap(name: String) -> void:
	_shot += 1
	await kit.shot("doors_%02d_%s" % [_shot, name])
