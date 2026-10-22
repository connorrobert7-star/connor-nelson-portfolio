extends RefCounted
## The arcade, played through the real UI: walk in, tap each cabinet, play each game with
## taps and holds, and check the coins, the lantern and the dungeon's cosmetic.


func run(kit: TourKit) -> void:
	await kit.go_to("arcade", Room.ENTRANCE)
	var room := kit.level() as ArcadeRoom
	if not kit.check(room != null, "the arcade opens"):
		return
	await kit.wait(1.2)
	await kit.shot("minigames_arcade")
	var flames0 := int(Game.state.minigames.flames.left)
	kit.check(flames0 == 3, "three flames burn on the stand")
	await _mine(kit, room)
	await _fishing(kit, room)
	await _dungeon(kit, room)
	kit.check(int(Game.state.minigames.flames.left) == 0, "three runs spent the day's three flames")
	await kit.wait(0.6)
	await kit.shot("minigames_arcade_end")
	await _village_front(kit)


## The arcade's front on a village plot. The hub wires the real plot after the merge; here
## the tour lends it an empty corner to check that it draws and shows today's flames.
func _village_front(kit: TourKit) -> void:
	await kit.reset_to_village()
	var village := kit.level() as Village
	var f := Features.for_plot("arcade")
	if not kit.check(f != null and f.door_level() == "arcade", "the arcade claims the arcade plot"):
		return
	var plot := Rect2i(32, 18, 4, 3)
	f.build_village(village, plot)
	f.dress_village(village, plot)
	await kit.stand(Vector2i(34, 23))
	await kit.wait(0.6)
	await kit.shot("minigames_village_front")


# --- the mine -----------------------------------------------------------------------------

func _mine(kit: TourKit, room: ArcadeRoom) -> void:
	var coins0 := int(Game.state.coins)
	var flames0 := int(Game.state.minigames.flames.left)
	await _tap_cabinet(kit, room, 0)
	var mine := kit.overlay() as MineOverlay
	if not kit.check(mine != null, "tapping the mine cabinet opens the mine"):
		return
	await kit.until(func() -> bool: return mine.playing, 10.0)
	await kit.shot("minigames_mine_start")
	var ore_before := _ore_total(mine)
	for i in 90:
		await kit.tap_screen(_screen(kit, _mine_target(mine)))
		await kit.wait(0.06)
		if i == 25:
			await kit.shot("minigames_mine_digging")
		if i == 60 and mine.fever_left > 0.0:
			await kit.shot("minigames_mine_fever")
	kit.check(_ore_total(mine) > ore_before, "swinging pops ore out")
	kit.check(mine.depth >= 2, "clearing layers digs deeper (depth %d)" % mine.depth)
	kit.check(mine.coins_shown > 0, "coins fly into the pouch")
	kit.check(mine.chain > 0 or mine.fever_left > 0.0 or mine.fever_coins > 0, "fast swings chain toward Coin Fever")
	await kit.shot("minigames_mine_late")
	await _leave_early(kit, mine)
	await kit.shot("minigames_mine_tally")
	kit.check(int(mine.result_body.get("coins", 0)) > 0, "the mine pays coins")
	await _close(kit)
	await kit.until(func() -> bool: return int(Game.state.coins) > coins0, 5.0)
	kit.check(int(Game.state.coins) > coins0, "the mine's coins are in the purse")
	kit.check(int(Game.state.minigames.flames.left) == flames0 - 1, "the mine burned one flame")
	await kit.wait(0.5)
	await kit.shot("minigames_arcade_after_mine")


func _ore_total(mine: MineOverlay) -> int:
	var n := 0
	for k: String in mine.ore_counts:
		n += int(mine.ore_counts[k])
	return n


## The top row's first block still standing, so the tour digs down like a player would.
func _mine_target(mine: MineOverlay) -> Vector2:
	for r in mine._rows.size():
		var row: Array = mine._rows[r]
		for c in row.size():
			if row[c] != null:
				return Vector2(MineOverlay.GX + c * MineOverlay.CELL + 16, MineOverlay.GY + r * MineOverlay.CELL + 16)
	return Vector2(240, 140)


# --- fishing ------------------------------------------------------------------------------

func _fishing(kit: TourKit, room: ArcadeRoom) -> void:
	var coins0 := int(Game.state.coins)
	await _tap_cabinet(kit, room, 1)
	var pond := kit.overlay() as FishingOverlay
	if not kit.check(pond != null, "tapping the fishing cabinet opens the pond"):
		return
	await kit.until(func() -> bool: return pond.playing, 10.0)
	await kit.shot("minigames_fishing_start")
	var shots := 0
	var t := 0.0
	while pond.caught.size() < 3 and t < 75.0 and pond.playing:
		match pond.phase:
			FishingOverlay.Phase.IDLE:
				await kit.tap_screen(_screen(kit, Vector2(320 + randf_range(-40, 60), 190)))
			FishingOverlay.Phase.BITE:
				if shots == 0:
					await kit.shot("minigames_fishing_bite")
				await kit.tap_screen(_screen(kit, Vector2(300, 180)))
			FishingOverlay.Phase.REEL:
				# Hold while the hook is below the middle of the fish's zone, let go above it.
				var want := pond._marker_y + FishingOverlay.MARKER_H / 2.0 > pond._zone_y + pond._zone.size.y / 2.0
				if want != pond.holding:
					await _mouse(kit, want)
				if shots == 0 and pond._fill > 0.6:
					await kit.shot("minigames_fishing_reel")
					shots = 1
			FishingOverlay.Phase.LANDING:
				if pond.holding:
					await _mouse(kit, false)
				if shots == 1:
					await kit.wait(0.25)
					await kit.shot("minigames_fishing_landed")
					shots = 2
		await kit.frames(2)
		t += 0.033
	if pond.holding:
		await _mouse(kit, false)
	kit.check(pond.caught.size() >= 2, "casting, hooking and holding lands fish (%d)" % pond.caught.size())
	kit.check(pond.coins_shown > 0, "each fish pays coins into the pouch")
	await kit.shot("minigames_fishing_catch_row")
	await _leave_early(kit, pond)
	await kit.shot("minigames_fishing_tally")
	kit.check(int(pond.result_body.get("coins", 0)) > 0, "fishing pays coins")
	await _close(kit)
	await kit.until(func() -> bool: return int(Game.state.coins) > coins0, 5.0)
	kit.check(int(Game.state.coins) > coins0, "the fishing coins are in the purse")


# --- the dungeon --------------------------------------------------------------------------

func _dungeon(kit: TourKit, room: ArcadeRoom) -> void:
	var coins0 := int(Game.state.coins)
	await _tap_cabinet(kit, room, 2)
	var dun := kit.overlay() as DungeonOverlay
	if not kit.check(dun != null, "tapping the dungeon cabinet opens the stairs"):
		return
	await kit.until(func() -> bool: return dun.playing and not dun.mods.is_empty(), 10.0)
	var omens: Array = dun.mods.get("omens", [])
	kit.check(omens == ["wilting", "leech", "landed"], "the stairs carry the real week's omens %s" % str(omens))
	await kit.wait(1.6)
	await kit.shot("minigames_dungeon_stairs")
	await kit.until(func() -> bool: return dun.phase == DungeonOverlay.Phase.FIGHT, 15.0)
	await kit.wait(1.0)
	await kit.shot("minigames_dungeon_room1")
	kit.check(dun.party.size() == 3, "the leader and two followers fight")
	var shot_cascade := false
	var shot_leech := false
	var shot_boss := false
	var bombed := false
	var t := 0.0
	while not dun.done and t < 150.0:
		if dun.phase == DungeonOverlay.Phase.FIGHT:
			var e := _first_enemy(dun)
			if e != null:
				await kit.tap_screen(_screen(kit, e.at() + Vector2(0, -16)))
			if dun.room == 1 and not shot_leech:
				for u in dun.enemies:
					if u.drain > 0.0 and u.hp > 0.0:
						await kit.wait(1.5)
						await kit.shot("minigames_dungeon_leech")
						shot_leech = true
						break
			if dun.room == 1 and not bombed and dun.enemies.size() >= 4:
				await kit.wait(1.0)
				var bomb := dun.hud.get_node_or_null("Bomb") as Control
				if bomb and bomb.visible:
					await kit.tap_control(bomb)
					bombed = true
					await kit.wait(0.55)
					await kit.shot("minigames_dungeon_bomb")
			if dun.room == 3 and not shot_boss:
				await kit.wait(2.5)
				await kit.shot("minigames_dungeon_boss")
				shot_boss = true
		elif dun.phase == DungeonOverlay.Phase.CASCADE and not shot_cascade:
			await kit.wait(1.3)
			await kit.shot("minigames_dungeon_cascade")
			shot_cascade = true
		await kit.wait(0.12)
		t += 0.15
	kit.check(bombed, "the one bomb throws and bursts")
	await kit.until(func() -> bool: return not dun.result_body.is_empty(), 15.0)
	await kit.wait(1.4)
	await kit.shot("minigames_dungeon_relic")
	kit.check(dun.rooms_cleared == 4, "three rooms and the boss fall (%d)" % dun.rooms_cleared)
	kit.check(dun.doors_broken >= 1, "a cascade breaks a door (%d)" % dun.doors_broken)
	var items: Array = dun.result_body.get("items", [])
	kit.check(items.size() == 1, "the boss drops the day's cosmetic")
	await kit.until(func() -> bool: return dun._end_ready, 15.0)
	await kit.wait(0.8)
	await kit.shot("minigames_dungeon_tally")
	await _close(kit)
	await kit.until(func() -> bool: return int(Game.state.coins) > coins0, 5.0)
	kit.check(int(Game.state.coins) > coins0, "the dungeon's room coins are in the purse")
	kit.check(not bool(Game.state.minigames.relic_waiting), "the relic is taken for today")


func _first_enemy(dun: DungeonOverlay) -> DungeonOverlay.Unit:
	for e in dun.enemies:
		if e.hp > 0.0 and e.drain > 0.0:
			return e
	for e in dun.enemies:
		if e.hp > 0.0:
			return e
	return null




# --- helpers ------------------------------------------------------------------------------

func _tap_cabinet(kit: TourKit, room: ArcadeRoom, i: int) -> void:
	var cab := room.cabinets[i]
	await kit.tap_world(cab.position + Vector2(0, -20))
	await kit.until(func() -> bool: return kit.overlay() != null, 8.0)


func _leave_early(kit: TourKit, o: MinigameOverlay) -> void:
	var exit := o.hud.get_node("Exit") as Control
	await kit.tap_control(exit)
	await kit.until(func() -> bool: return o.done and o._end_ready, 15.0)
	await kit.until(func() -> bool: return o.can_leave(), 3.0)  # the way-out door has faded in


func _close(kit: TourKit) -> void:
	var o := kit.overlay() as MinigameOverlay
	if o:
		await kit.until(func() -> bool: return o.can_leave(), 3.0)  # the tally has had its moment
	await kit.tap_screen(_screen(kit, Vector2(240, 135)))
	await kit.until(func() -> bool: return kit.overlay() == null, 5.0)
	await kit.wait(0.3)


func _screen(kit: TourKit, p: Vector2) -> Vector2:
	return kit.get_viewport().get_screen_transform() * p


## Press or release the mouse without the other half, for holds.
func _mouse(kit: TourKit, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = _screen(kit, Vector2(300, 180))
	ev.global_position = ev.position
	Input.parse_input_event(ev)
	await kit.frames(1)
