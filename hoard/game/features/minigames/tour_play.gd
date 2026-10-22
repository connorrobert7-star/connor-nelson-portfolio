extends RefCounted
## Playtest: the arcade played like the owner on a phone, through real touches (Godot turns
## each one into a click too, like on the phone) and a few mouse clicks. After every step it
## checks the state: one overlay per tap, every tap answered by a sound or something drawn
## that same frame, holds that let go, coins that land in the purse, flames that burn down,
## and nothing left stuck (Game.busy, the time scale, an overlay) after a run ends.
##   1. The mine: a tap from across the room opens it once; taps in the countdown answer;
##      each swing counts once; leave early; the coins land.
##   2. The mine again: the fuse burns out on its own and the tally still comes.
##   3. Fishing: cast, a tap too early, a missed bite, a hooked fish held in, leave.
##   4. The dungeon, out of flames: a quarter's pay, smites that never drop a tap, the bomb,
##      all four rooms, the relic.
##   5. The dungeon again: the door tapped mid-fight ends it cleanly, and the room still works.
##   godot --path game res://dev/tour.tscn -- <out> res://features/minigames/tour_play.gd

var kit: TourKit


func run(k: TourKit) -> void:
	kit = k
	await kit.go_to("arcade", Room.ENTRANCE)
	var room := kit.level() as ArcadeRoom
	if not kit.check(room != null, "the arcade opens"):
		return
	await kit.wait(1.0)
	kit.check(int(Game.state.minigames.flames.left) == 3, "three flames on the stand")
	await _mine_quit(room)
	await _mine_fuse(room)
	await _fishing(room)
	await _dungeon_full(room)
	await _dungeon_quit(room)
	await _dressed_in_the_mine(room)
	# The room is still alive after five runs: a tap on the floor walks.
	var at := room.leader.position
	await touch(_world(room, at + Vector2(-50, 0)))
	await kit.wait(1.0)
	kit.check(room.leader.position.distance_to(at) > 20.0, "after five runs a tap on the floor still walks")
	await kit.shot("play_arcade_end")


# --- 1 ---------------------------------------------------------------------------------

func _mine_quit(room: ArcadeRoom) -> void:
	var coins0 := int(Game.state.coins)
	var mine := await _open(room, 0) as MineOverlay
	if not kit.check(mine != null, "one touch from across the room opens the mine"):
		return
	# Taps during the count are answered, and the count still ends in play.
	await kit.until(func() -> bool: return mine.hud.get_node_or_null("Exit") != null, 6.0)
	kit.check(await _answered(mine, Vector2(300, 60)), "a tap during the countdown answers")
	await kit.until(func() -> bool: return mine.playing, 8.0)
	await kit.shot("play_mine_start")
	# Every swing on a block counts once: the chain climbs by one a touch.
	var once := true
	for i in 16:
		var c0 := mine.chain
		await touch(_screen(_mine_target(mine)))
		if mine.chain != c0 + 1:
			once = false
			kit.log_line("  swing %d: chain %d -> %d" % [i, c0, mine.chain])
		await kit.wait(0.05)
	kit.check(once, "every touch on a block is one swing (chain %d)" % mine.chain)
	for i in 40:
		await touch(_screen(_mine_target(mine)))
		await kit.wait(0.04)
	kit.check(mine.ore_total() > 0, "swinging pops ore out (%d)" % mine.ore_total())
	kit.check(mine.depth >= 1, "a cleared layer drops a level (depth %d)" % mine.depth)
	kit.check(await _answered(mine, Vector2(40, 140)), "a tap on the rock wall answers")
	await kit.shot("play_mine_digging")
	_check_grid(mine)
	# Leave early through the door.
	await touch(_screen(_center(mine.hud.get_node("Exit") as Control)))
	await kit.until(func() -> bool: return mine.done and mine._end_ready, 15.0)
	kit.check(mine.fever_left <= 0.0 and not mine._fever_rain.emitting, "no fever left burning under the tally")
	await kit.shot("play_mine_tally")
	var paid := int(mine.result_body.get("coins", -1))
	kit.check(paid > 0, "the run pays coins (%d)" % paid)
	await _leave(mine)
	await kit.until(func() -> bool: return int(Game.state.coins) == coins0 + paid, 5.0)
	kit.check(int(Game.state.coins) == coins0 + paid, "exactly the tally lands in the purse (%d + %d = %d)" % [coins0, paid, int(Game.state.coins)])
	kit.check(int(Game.state.minigames.flames.left) == 2, "one flame burned")
	await kit.until(func() -> bool: return _toast("coins"), 4.0)
	kit.check(_toast("coins"), "the coins show as a plate once the overlay is gone")


## Every block still in the grid is drawn, and every block drawn is still in the grid.
func _check_grid(mine: MineOverlay) -> void:
	var listed := 0
	for row: Array in mine._rows:
		for cell: Variant in row:
			if cell != null:
				listed += 1
				if not is_instance_valid((cell as Dictionary).node):
					kit.check(false, "a block in the grid has no sprite")
					return
	var drawn := 0
	for n in mine._grid.get_children():
		if not n.is_queued_for_deletion() and n.scale.x > 0.9:
			drawn += 1
	kit.check(drawn == listed, "every block drawn can be hit (%d drawn, %d in the grid)" % [drawn, listed])


func _mine_fuse(room: ArcadeRoom) -> void:
	var coins0 := int(Game.state.coins)
	var mine := await _open(room, 0) as MineOverlay
	if not kit.check(mine != null, "the mine opens a second time"):
		return
	await kit.until(func() -> bool: return mine.playing, 8.0)
	for i in 50:
		await touch(_screen(_mine_target(mine)))
		await kit.wait(0.05)
		if mine.ore_total() >= 3:
			break
	# Let the fuse burn down to its last seconds and run out on its own, a thumb still
	# hammering blocks the whole way through the tally: the tally stays up to be seen.
	mine.time_left = minf(mine.time_left, 3.0)
	var ready_at := -1
	var t0 := Time.get_ticks_msec()
	while kit.overlay() == mine and Time.get_ticks_msec() - t0 < 14000:
		await touch(_screen(_mine_target(mine)))
		await kit.wait(0.04)
		if mine._end_ready and ready_at < 0:
			ready_at = Time.get_ticks_msec()
		if ready_at >= 0 and Time.get_ticks_msec() - ready_at > 800:
			break
	var up := ready_at >= 0 and kit.overlay() == mine
	kit.check(up, "a thumb still hammering for most of a second after the fuse ends still sees the tally")
	if not up:
		return
	kit.check(mine.done, "the fuse burns out and the whistle goes")
	await kit.shot("play_mine_fuse_out")
	var paid := int(mine.result_body.get("coins", -1))
	await _leave(mine)
	await kit.until(func() -> bool: return int(Game.state.coins) == coins0 + paid, 5.0)
	kit.check(paid > 0 and int(Game.state.coins) == coins0 + paid, "the burnt-out run pays its tally (%d)" % paid)
	kit.check(int(Game.state.minigames.flames.left) == 1, "and burns the second flame")


# --- 3 ---------------------------------------------------------------------------------

func _fishing(room: ArcadeRoom) -> void:
	var coins0 := int(Game.state.coins)
	var pond := await _open(room, 1) as FishingOverlay
	if not kit.check(pond != null, "a touch on the fishing cabinet opens the pond"):
		return
	await kit.until(func() -> bool: return pond.playing, 8.0)
	# A cast, and a tap while the line is in the air.
	await touch(_screen(Vector2(330, 190)))
	kit.check(pond.phase == FishingOverlay.Phase.FLYING, "a touch on the water casts")
	kit.check(await _answered(pond, Vector2(330, 190)), "a tap while the line flies answers")
	await kit.until(func() -> bool: return pond.phase == FishingOverlay.Phase.WAITING, 3.0)
	kit.check(await _answered(pond, Vector2(330, 190)), "a tap before the bite answers (the bobber tugs)")
	# Miss a bite on purpose: the fish gets away and the rod is ready again.
	await kit.until(func() -> bool: return pond.phase == FishingOverlay.Phase.BITE, 8.0)
	await kit.until(func() -> bool: return pond.phase != FishingOverlay.Phase.BITE, 3.0)
	kit.check(pond.phase == FishingOverlay.Phase.LANDING, "a bite left alone gets away")
	await kit.until(func() -> bool: return pond.phase == FishingOverlay.Phase.IDLE, 3.0)
	kit.check(pond.phase == FishingOverlay.Phase.IDLE, "and the line comes back in for the next cast")
	# Now fish properly: hook on the bite, hold to keep the hook in the zone.
	var t := 0.0
	var down := false
	while pond.caught.size() < 2 and t < 60.0 and pond.playing:
		match pond.phase:
			FishingOverlay.Phase.IDLE:
				await touch(_screen(Vector2(300 + randf_range(-30, 60), 190)))
			FishingOverlay.Phase.BITE:
				await touch(_screen(Vector2(300, 180)))
			FishingOverlay.Phase.REEL:
				var want := pond._marker_y + FishingOverlay.MARKER_H / 2.0 > pond._zone_y + pond._zone.size.y / 2.0
				if want != down:
					down = want
					if down:
						await touch_down(_screen(Vector2(300, 180)))
					else:
						await touch_up(_screen(Vector2(300, 180)))
					if pond.holding != down:
						kit.check(false, "the hold follows the finger (holding %s)" % pond.holding)
			_:
				if down:
					down = false
					await touch_up(_screen(Vector2(300, 180)))
		await kit.frames(2)
		t += 0.033
	if down:
		await touch_up(_screen(Vector2(300, 180)))
	kit.check(not pond.holding, "a lifted finger lets go of the reel")
	kit.check(pond.caught.size() >= 1, "a hooked fish held in the zone lands (%d)" % pond.caught.size())
	await kit.shot("play_fishing_catch")
	await touch(_screen(_center(pond.hud.get_node("Exit") as Control)))
	await kit.until(func() -> bool: return pond._end_ready, 15.0)
	var paid := int(pond.result_body.get("coins", -1))
	kit.check(paid > 0, "fishing pays (%d)" % paid)
	await _leave(pond)
	await kit.until(func() -> bool: return int(Game.state.coins) == coins0 + paid, 5.0)
	kit.check(int(Game.state.coins) == coins0 + paid, "exactly the fishing tally lands")
	kit.check(int(Game.state.minigames.flames.left) == 0, "the third flame is out")


# --- 4 ---------------------------------------------------------------------------------

func _dungeon_full(room: ArcadeRoom) -> void:
	var coins0 := int(Game.state.coins)
	var dun := await _open(room, 2) as DungeonOverlay
	if not kit.check(dun != null, "a touch on the dungeon cabinet opens the stairs"):
		return
	await kit.until(func() -> bool: return dun.playing, 8.0)
	kit.check(await _answered(dun, Vector2(240, 140)), "a tap on the stairs answers (and hurries them)")
	await kit.until(func() -> bool: return dun.phase == DungeonOverlay.Phase.FIGHT, 15.0)
	# Two touches on one enemy inside the bolt's cooldown: both bolts land.
	await kit.wait(0.6)
	var e := _enemy(dun)
	if e:
		var seen := {}
		var hp0 := e.hp
		await touch(_screen(e.at() + Vector2(0, -16)))
		await kit.wait(0.05)
		await touch(_screen(e.at() + Vector2(0, -16)))
		for f in 30:
			_thunder(dun, seen)
			await kit.frames(1)
		kit.check(seen.size() >= 2, "two quick touches call two bolts (%d)" % seen.size())
		kit.log_line("  enemy hp %.0f -> %.0f" % [hp0, e.hp])
	var bombed := false
	var rattled := false
	var t := 0.0
	while not dun.done and t < 150.0:
		if dun.phase == DungeonOverlay.Phase.FIGHT:
			var target := _enemy(dun)
			if target:
				await touch(_screen(target.at() + Vector2(0, -16)))
			if dun.room == 1 and not bombed and dun.enemies.size() >= 4:
				var bomb := dun.hud.get_node_or_null("Bomb") as Control
				if bomb and bomb.visible:
					await touch(_screen(_center(bomb)))
					await kit.wait(0.6)
					bombed = not bomb.visible
		elif dun.phase == DungeonOverlay.Phase.CASCADE and not bombed and not rattled:
			# The bomb between rooms rattles; it is not spent.
			var bomb := dun.hud.get_node_or_null("Bomb") as Control
			if bomb and bomb.visible:
				rattled = true
				await touch(_screen(_center(bomb)))
				kit.check(bomb.visible, "the bomb tapped at the door rattles and stays for the next room")
		await kit.wait(0.1)
		t += 0.13
	kit.check(bombed, "the bomb throws once in a fight")
	await kit.until(func() -> bool: return dun._end_ready, 20.0)
	await kit.shot("play_dungeon_tally")
	kit.check(dun.rooms_cleared == 4, "three rooms and the boss fall (%d)" % dun.rooms_cleared)
	kit.check(not bool(dun.result_body.get("full", true)), "out of flames: the run is practice pay")
	var items: Array = dun.result_body.get("items", [])
	kit.check(items.size() == 1, "the boss drops the day's cosmetic even out of flames")
	var paid := int(dun.result_body.get("coins", -1))
	kit.check(paid > 0, "the rooms still pay (%d)" % paid)
	await _leave(dun)
	await kit.until(func() -> bool: return int(Game.state.coins) == coins0 + paid, 5.0)
	kit.check(int(Game.state.coins) == coins0 + paid, "the dungeon's pay lands")
	await kit.until(func() -> bool: return _toast("item"), 4.0)
	kit.check(_toast("item"), "the relic shows as a plate after the overlay")


func _dungeon_quit(room: ArcadeRoom) -> void:
	await kit.wait(0.4)
	var dun := await _open(room, 2) as DungeonOverlay
	if not kit.check(dun != null, "the dungeon opens again"):
		return
	await kit.until(func() -> bool: return dun.phase == DungeonOverlay.Phase.FIGHT, 20.0)
	await kit.wait(0.8)
	var e := _enemy(dun)
	if e:
		await touch(_screen(e.at() + Vector2(0, -16)))
	await touch(_screen(_center(dun.hud.get_node("Exit") as Control)))
	await kit.until(func() -> bool: return dun._end_ready, 15.0)
	kit.check(dun.done and not dun.playing, "the door mid-fight stops the fight")
	await kit.wait(0.6)
	var hp_before: Array = []
	for u in dun.enemies:
		hp_before.append(u.hp)
	await kit.wait(0.5)
	var still := true
	for i in dun.enemies.size():
		if dun.enemies[i].hp != hp_before[i]:
			still = false
	kit.check(still, "nothing keeps fighting under the tally")
	await _leave(dun)


# --- input, the way a phone sends it ---------------------------------------------------

## A finger down and up at a screen point. Godot also makes a click from it, like a phone.
func touch(p: Vector2) -> void:
	await touch_down(p)
	await touch_up(p)


func touch_down(p: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = true
	ev.position = p
	Input.parse_input_event(ev)
	await kit.frames(1)


func touch_up(p: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = false
	ev.position = p
	Input.parse_input_event(ev)
	await kit.frames(2)


## A touch at an overlay point; true if a sound started or something new was drawn by the
## next frame.
func _answered(o: Node, at: Vector2) -> bool:
	var t := Time.get_ticks_msec()
	var n := _count(o)
	await touch_down(_screen(at))
	var heard := false
	for p: Variant in Sfx._started:
		if int(Sfx._started[p]) >= t:
			heard = true
	var drawn := _count(o) != n
	await touch_up(_screen(at))
	return heard or drawn


func _count(n: Node) -> int:
	var c := 1
	for k in n.get_children():
		c += _count(k)
	return c


func _screen(p: Vector2) -> Vector2:
	return kit.get_viewport().get_screen_transform() * p


func _world(lv: Level, p: Vector2) -> Vector2:
	var vp := kit.get_viewport()
	return vp.get_screen_transform() * vp.get_canvas_transform() * p


func _center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


# --- 6 ---------------------------------------------------------------------------------

## What the book put on him goes down the mine with him: the pieces hang on the mine's
## wizard, on his frame, and come off with the game.
func _dressed_in_the_mine(room: ArcadeRoom) -> void:
	var cat: Dictionary = await BookOverlay.load_catalog()
	var wear := ""
	for id: String in Game.state.casino.get("trophies", {}):
		if cat.has(id) and BookOverlay.GAME_LOOK.has(str(cat[id].slot)):
			wear = id
	for i in 8:
		if wear != "":
			break
		var r: Array = await Game.call_api("POST", "/casino/scratch", {"price_cents": 100, "to_account": "sav_1"})
		if r[1] == "" and BookOverlay.GAME_LOOK.has(str(r[0].item.slot)):
			wear = str(r[0].item.id)
	if not kit.check(wear != "", "a piece the wizard can wear in the games"):
		return
	var res: Array = await Game.call_api("POST", "/casino/equip", {"item_id": wear})
	kit.check(res[1] == "", "the piece goes on (%s)" % res[1])
	await Game.refresh()
	var slot := str(cat[wear].slot)
	var mine := await _open(room, 0) as MineOverlay
	if not kit.check(mine != null, "the mine opens dressed"):
		return
	await kit.until(func() -> bool: return mine.playing, 8.0)
	var worn: BookOverlay.WornOn = null
	for c in mine._leader.get_children():
		if c is BookOverlay.WornOn:
			worn = c
	kit.check(worn != null, "the mine's wizard is dressed")
	if worn:
		await kit.until(func() -> bool: return worn._pieces.has(slot), 3.0)
		kit.check(worn._pieces.has(slot), "his %s is on him in the mine (%s)" % [slot, wear])
		if slot == "hat":
			kit.check(bool((mine._leader.material as ShaderMaterial).get_shader_parameter("hide_hat")), "and his own pointy hat is off under it")
	await kit.wait(0.3)
	await kit.shot("play_mine_dressed")
	var img := kit.get_viewport().get_texture().get_image()
	var k := img.get_width() / 480.0
	var at := mine._leader.get_global_transform_with_canvas().origin
	var crop := img.get_region(Rect2i(Vector2i(((at - Vector2(16, 34)) * k).round()), Vector2i((Vector2(32, 40) * k).round())))
	crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_NEAREST)
	crop.save_png("%s/play_mine_dressed_zoom.png" % kit.out)
	await touch(_screen(_center(mine.hud.get_node("Exit") as Control)))
	await kit.until(func() -> bool: return mine._end_ready, 15.0)
	await _leave(mine)


# --- helpers ---------------------------------------------------------------------------

## A touch on a cabinet from the arcade's entrance: the leader walks over and it opens, once.
func _open(room: ArcadeRoom, i: int) -> MinigameOverlay:
	room.leader.position = room.feet_at(Room.ENTRANCE)
	await kit.frames(3)
	var cab := room.cabinets[i]
	await touch(_world(room, cab.position + Vector2(0, -20)))
	await kit.until(func() -> bool: return kit.overlay() != null, 8.0)
	await kit.wait(0.4)
	kit.check(kit.main._overlays.get_child_count() == 1, "one touch, one overlay (%d)" % kit.main._overlays.get_child_count())
	kit.check(Game.busy, "the room waits while a game is open")
	return kit.overlay() as MinigameOverlay


## A tap anywhere on the tally leaves; everything is let go of.
func _leave(o: MinigameOverlay) -> void:
	if not o.can_leave():
		# The moment the tally lands a tap only nudges: the shelf stays up to be read.
		await touch(_screen(Vector2(240, 135)))
		kit.check(kit.overlay() == o, "a tap the moment the tally lands keeps it up")
	await kit.until(func() -> bool: return o.can_leave(), 3.0)
	await touch(_screen(Vector2(240, 135)))
	await kit.until(func() -> bool: return kit.overlay() == null, 5.0)
	kit.check(kit.overlay() == null, "a tap on the tally closes the game")
	kit.check(not Game.busy, "and frees the room")
	kit.check(Engine.time_scale == 1.0, "and time runs at full speed (%.2f)" % Engine.time_scale)
	await kit.wait(0.5)
	kit.check(kit.main._closing.get_child_count() == 0, "the closed game is gone after its outro")


func _toast(kind: String) -> bool:
	for c in kit.main._toasts.get_children():
		if c is Toast and (c as Toast).kind == kind:
			return true
	return false


func _mine_target(mine: MineOverlay) -> Vector2:
	for r in mine._rows.size():
		var row: Array = mine._rows[r]
		for c in row.size():
			if row[c] != null:
				return Vector2(MineOverlay.GX + c * MineOverlay.CELL + 16, MineOverlay.GY + r * MineOverlay.CELL + 16)
	return Vector2(240, 140)


func _enemy(dun: DungeonOverlay) -> DungeonOverlay.Unit:
	for e in dun.enemies:
		if e.hp > 0.0 and e.at().x < 470.0:
			return e
	return null


## Note every lightning strike on the field by its node.
func _thunder(dun: DungeonOverlay, seen: Dictionary) -> void:
	for n in dun._arena.get_children():
		if n is AnimatedSprite2D:
			var t := (n as AnimatedSprite2D).sprite_frames.get_frame_texture("default", 0) as AtlasTexture
			if t and t.atlas and t.atlas.resource_path == DungeonOverlay.THUNDER:
				seen[n.get_instance_id()] = true
