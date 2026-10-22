extends RefCounted
## The collection book, the trade-up press and the weekly draw, played by taps.
##   godot --path game res://dev/tour.tscn -- /tmp/shots res://features/casino/tour_book.gd


func run(kit: TourKit) -> void:
	await _stock_up(kit)
	await _book(kit)
	await _world(kit)
	await _draw(kit)
	await kit.wait(1.2)  # let the last sounds finish before the tour quits


## Fill the inventory the way the owner would: real $1 and $5 scratch tickets and a few
## cases, each landing its exact price in the House Fund, and a won dungeon run for a trophy.
## (Setup, not the thing under test.)
func _stock_up(kit: TourKit) -> void:
	var before := _balance("sav_1")
	var spent := 0
	for i in 16:
		var res: Array = await Game.call_api("POST", "/casino/scratch", {"price_cents": 100, "to_account": "sav_1"})
		if res[1] == "":
			spent += 100
	for i in 10:
		var res: Array = await Game.call_api("POST", "/casino/scratch", {"price_cents": 500, "to_account": "sav_1"})
		if res[1] == "":
			spent += 500
	for i in 4:
		var res: Array = await Game.call_api("POST", "/casino/case", {"case_id": "case_10", "to_account": "sav_1"})
		if res[1] == "":
			spent += 1000
	var run: Array = await Game.call_api("POST", "/minigames/start", {"game": "dungeon"})
	if run[1] == "":
		await Game.call_api("POST", "/minigames/finish", {"run_id": int(run[0].run_id), "result": {"rooms_cleared": 4, "doors_broken": 4}})
	await Game.refresh()
	kit.check(_balance("sav_1") == before + spent, "every ticket and case landed its exact price in the House Fund (+%d cents)" % spent)
	kit.check(_owned_total() >= 25, "the inventory has pieces to show (%d)" % _owned_total())
	kit.check((Game.state.casino.get("trophies", {}) as Dictionary).size() >= 1, "the dungeon's boss dropped a trophy")


func _book(kit: TourKit) -> void:
	var book := BookOverlay.new()
	kit.main.open_overlay(book)
	await kit.until(func() -> bool: return book.moment == "look", 10.0)
	await kit.wait(0.6)
	await kit.shot("book_01_open")
	kit.check(book.items.size() >= 60, "the book knows all %d pieces" % book.items.size())
	var page_ids := book.items_on_page()
	kit.check(page_ids.size() == 32, "one set fills a two-page spread (%d pockets)" % page_ids.size())
	var missing := ""
	for id in page_ids:
		if book.count_of(id) == 0:
			missing = id
			break
	if missing != "":
		var c: BookOverlay.Cell = book.cell_control(missing)
		kit.check(c._sil.visible and not c._icon.is_visible_in_tree(), "a missing piece is a dark silhouette")

	# Flip to the other set by its ribbon, and back.
	var first := book.showing_set()
	await kit.tap_control(book.tab_control(1 if book.page == 0 else 0))
	await kit.until(func() -> bool: return book.moment == "look", 3.0)
	await kit.wait(0.3)
	kit.check(book.showing_set() != first, "tapping a ribbon flips to the other set")
	await kit.shot("book_02_other_set")
	await kit.tap_control(book.tab_control(0))
	await kit.until(func() -> bool: return book.moment == "look" and book.page == 0, 3.0)

	# Wear one piece from each slot that's owned: tap it, it flies onto the leader.
	var worn := 0
	for slot in ["hat", "aura", "charm", "cloak", "follower_skin"]:
		var id := _best_owned(book, slot)
		if id == "":
			continue
		if book._cell_set[id] != book.page:
			await kit.tap_control(book.tab_control(book._cell_set[id]))
			await kit.until(func() -> bool: return book.moment == "look" and book._cell_set[id] == book.page, 3.0)
		await kit.tap_control(book.cell_control(id))
		await kit.until(func() -> bool: return book.moment == "look", 5.0)
		await kit.until(func() -> bool: return str(Game.state.casino.equipped.get(slot, "")) == id, 5.0)
		kit.check(str(Game.state.casino.equipped.get(slot, "")) == id, "tapping %s wears it (%s)" % [id, slot])
		kit.check(book.piece_on_leader(slot) != null, "the %s shows on the leader on the stage" % slot)
		worn += 1
		if worn == 1:
			await kit.wait(0.05)
			await kit.shot("book_03_equip")
	await kit.wait(0.5)
	await kit.tap_control(book.tab_control(0))
	await kit.until(func() -> bool: return book.moment == "look", 3.0)
	await kit.shot("book_04_worn")
	# Up close on the stage: a worn charm is big enough to read (a candle keeps its flame).
	var charm := book.piece_on_leader("charm")
	if charm and charm.get_child_count() > 1:
		var art := (charm.get_child(1) as Sprite2D).texture
		kit.check(maxi(art.get_width(), art.get_height()) >= 6, "the worn charm is big enough to read (%dx%d)" % [art.get_width(), art.get_height()])
	var view := kit.get_viewport().get_texture().get_image()
	var st := kit.get_viewport().get_screen_transform()
	var stage := Rect2i(Rect2(st * BookOverlay.STAGE.position, st.basis_xform(BookOverlay.STAGE.size)))
	view.get_region(stage.intersection(Rect2i(Vector2i.ZERO, view.get_size()))).save_png("%s/book_04c_stage_closeup.png" % kit.out)

	# A second tap on a worn piece takes it off (it flies home to its pocket); a tap puts it
	# back on.
	var hat := str(Game.state.casino.equipped.get("hat", ""))
	if kit.check(hat != "", "a hat is worn to take off"):
		await _go_to_page_of(kit, book, hat)
		await kit.tap_control(book.cell_control(hat))
		await kit.until(func() -> bool: return book.moment == "look" and not Game.state.casino.equipped.has("hat"), 5.0)
		kit.check(not Game.state.casino.equipped.has("hat"), "tapping the worn hat takes it off")
		kit.check(book.piece_on_leader("hat") == null, "and the stage wizard has his own pointy hat back")
		await kit.wait(0.3)
		await kit.shot("book_04b_hat_off")
		await kit.tap_control(book.cell_control(hat))
		await kit.until(func() -> bool: return book.moment == "look" and str(Game.state.casino.equipped.get("hat", "")) == hat, 5.0)
		kit.check(str(Game.state.casino.equipped.get("hat", "")) == hat, "and a tap puts it back on")
		kit.check(book.piece_on_leader("hat") != null, "back on the stage wizard's head")
		await kit.tap_control(book.tab_control(0))
		await kit.until(func() -> bool: return book.moment == "look", 3.0)

	# The trade-up press: open the rail, tap ten greys in, pull the lever.
	await _trade_up(kit, book, "common")

	# Gold doesn't go in: the mouth is welded shut.
	var gold := ""
	for id: String in book.items:
		if str(book.items[id].tier) in ["legendary", "mythic"] and book.count_of(id) > 0:
			gold = id
	await kit.tap_screen(_screen(kit, BookOverlay.PRESS.get_center()))
	await kit.until(func() -> bool: return book.moment == "feed", 2.0)
	if gold != "":
		if book._cell_set[gold] != book.page:
			await kit.tap_control(book.tab_control(book._cell_set[gold]))
			await kit.until(func() -> bool: return book.moment == "feed", 3.0)
		await kit.tap_control(book.cell_control(gold))
		await kit.wait(0.1)
		await kit.shot("book_08_gold_bounces")
		kit.check(book.rail.is_empty(), "gold bounces off the press")
	# A blue after a grey doesn't go in either.
	var grey := _owned_of(book, "common")
	var blue := _owned_of(book, "rare")
	if grey != "" and blue != "":
		await _go_to_page_of(kit, book, grey)
		await kit.tap_control(book.cell_control(grey))
		await _go_to_page_of(kit, book, blue)
		await kit.tap_control(book.cell_control(blue))
		await kit.wait(0.3)
		kit.check(book.rail.size() == 1, "one color at a time on the rail")
	# Tapping the press again closes the rail and the pieces go home.
	await kit.tap_screen(_screen(kit, BookOverlay.PRESS.get_center()))
	await kit.wait(0.4)
	kit.check(book.rail.is_empty() and book.mode == BookOverlay.Mode.LOOK, "tapping the press again sends the pieces home")

	await _trophies(kit, book)

	# Tap the dark margin to put the book down.
	await kit.tap_screen(_screen(kit, Vector2(10, 100)))
	await kit.until(func() -> bool: return kit.overlay() == null, 3.0)
	kit.check(kit.overlay() == null and not Game.busy, "tapping outside the book closes it")


## The trophy shelves at the back of the book: the gate's, the undercroft's and the flock's
## pieces, owned in color, missing as silhouettes, wearable, never pressed.
func _trophies(kit: TourKit, book: BookOverlay) -> void:
	var shelves: Array[int] = []
	for i in book.sets.size():
		if book.sets[i].get("trophy", false):
			shelves.append(i)
	kit.check(shelves.size() == 3, "three trophy shelves follow the casino's sets (%d)" % shelves.size())
	var held: Dictionary = Game.state.casino.get("trophies", {})
	for si in shelves:
		var id := str(book.sets[si].id)
		await kit.tap_control(book.tab_control(si))
		await kit.until(func() -> bool: return book.page == si and book.moment == "look", 3.0)
		await kit.wait(0.35)
		await kit.shot("book_10_trophies_%s" % id)
		var ids := book.items_on_page()
		var right := ids.size() > 0
		for k in ids:
			var c: BookOverlay.Cell = book.cell_control(k)
			var have := int(held.get(k, 0)) > 0
			right = right and c.trophy and (c._clip.visible == have) and (c._sil.visible != have)
		kit.check(right, "the %s shelf: %d pieces, owned in color, missing as silhouettes" % [id, ids.size()])
	# Wear an owned trophy: it goes on the wizard like any other piece.
	var mine := ""
	for k: String in held:
		if book.items.has(k) and int(held[k]) > 0:
			mine = k
	if mine == "":
		kit.check(false, "no trophy to wear")
		return
	var slot := str(book.items[mine].slot)
	await _go_to_page_of(kit, book, mine)
	if str(Game.state.casino.equipped.get(slot, "")) != mine:  # a tap on a worn one takes it off
		await kit.tap_control(book.cell_control(mine))
	await kit.until(func() -> bool: return str(Game.state.casino.equipped.get(slot, "")) == mine and book.moment == "look", 5.0)
	kit.check(str(Game.state.casino.equipped.get(slot, "")) == mine, "tapping the %s trophy wears it" % mine)
	kit.check(book.piece_on_leader(slot) != null, "the trophy shows on the wizard")
	await kit.wait(0.4)
	await kit.shot("book_11_trophy_worn")
	# The press won't take it.
	await kit.tap_screen(_screen(kit, BookOverlay.PRESS.get_center()))
	await kit.until(func() -> bool: return book.moment == "feed", 2.0)
	await kit.tap_control(book.cell_control(mine))
	await kit.wait(0.3)
	kit.check(book.rail.is_empty(), "a trophy bounces off the press")
	await kit.shot("book_12_trophy_bounces")
	await kit.tap_screen(_screen(kit, BookOverlay.PRESS.get_center()))
	await kit.wait(0.3)


func _trade_up(kit: TourKit, book: BookOverlay, tier: String) -> void:
	var before: Dictionary = (Game.state.casino.owned as Dictionary).duplicate()
	var total_before := _owned_total()
	var tier_before := _tier_total(book, tier)
	if tier_before < 10:
		kit.check(false, "need ten %s to trade up (have %d)" % [tier, tier_before])
		return
	await kit.tap_screen(_screen(kit, BookOverlay.RAIL.get_center()))
	await kit.until(func() -> bool: return book.moment == "feed", 2.0)
	kit.check(book.mode == BookOverlay.Mode.FEED, "tapping the press opens its rail")
	var fed := 0
	var guard := 0
	while book.rail.size() < 10 and guard < 40:
		guard += 1
		var id := ""
		for k: String in book.items:
			if str(book.items[k].tier) == tier:
				var on_rail := 0
				for r: Dictionary in book.rail:
					if r.item_id == k:
						on_rail += 1
				if book.count_of(k) - on_rail > 0:
					id = k
					break
		if id == "":
			break
		await _go_to_page_of(kit, book, id)
		await kit.tap_control(book.cell_control(id))
		await kit.wait(0.08)
		fed += 1
		if book.rail.size() == 4:
			await kit.wait(0.15)
			await kit.shot("book_05_feeding")
	await kit.wait(0.3)
	kit.check(book.rail.size() == 10, "ten %s pieces sit on the rail" % tier)
	await kit.shot("book_06_rail_full")
	await kit.tap_screen(_screen(kit, BookOverlay.LEVER.get_center()))
	await kit.until(func() -> bool: return book.moment == "stamp", 4.0)
	await kit.wait(0.3)
	await kit.shot("book_07a_heat")
	await kit.until(func() -> bool: return book.moment == "reveal", 4.0)
	await kit.wait(0.75)
	await kit.shot("book_07b_reveal")
	await kit.until(func() -> bool: return book.moment == "landed" or book.moment == "look", 12.0)
	await kit.wait(0.1)
	await kit.shot("book_07c_landed")
	var won: Dictionary = book.last_trade.get("item", {})
	kit.check(str(won.get("tier", "")) == BookOverlay.NEXT[tier], "ten %s became one %s (%s)" % [tier, BookOverlay.NEXT[tier], str(won.get("name", "?"))])
	kit.check(_tier_total(book, tier) == tier_before - 10, "the ten went into the press")
	kit.check(_owned_total() == total_before - 9, "ten out, one in")
	kit.check(book.count_of(str(won.get("id", ""))) == int(before.get(str(won.get("id", "")), 0)) + 1, "the new piece is in its pocket")
	await kit.until(func() -> bool: return book.moment == "look", 3.0)


## The leader in the world wears what the book put on.
func _world(kit: TourKit) -> void:
	await kit.go_to("village", Village.SPAWN)
	await kit.wait(0.4)
	var worn: BookOverlay.Worn = null
	for n in kit.level().leader.get_children():
		if n is BookOverlay.Worn:
			worn = n
	kit.check(worn != null, "the leader carries the worn pieces")
	if worn:
		await kit.until(func() -> bool: return worn._pieces.has("hat") or Game.state.casino.equipped.get("hat", "") == "", 3.0)
		kit.check(worn._pieces.has("hat") or str(Game.state.casino.equipped.get("hat", "")) == "", "the hat is on the leader's head in the village")
	# Up close on the leader (the camera moved onto them, the map's edge limits lifted).
	var cam := kit.level().camera
	var limits := [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom]
	cam.limit_left = -100000
	cam.limit_top = -100000
	cam.limit_right = 100000
	cam.limit_bottom = 100000
	var home := cam.global_position
	var off := cam.offset
	cam.offset = Vector2.ZERO
	cam.global_position = kit.level().leader.global_position + Vector2(0, -12)
	cam.zoom = Vector2(3, 3)
	await kit.wait(0.3)
	await kit.shot("book_09_world_leader")
	cam.zoom = Vector2.ONE
	cam.offset = off
	cam.global_position = home
	cam.limit_left = limits[0]
	cam.limit_top = limits[1]
	cam.limit_right = limits[2]
	cam.limit_bottom = limits[3]


## The weekly draw: this week's tickets, then Sunday comes and last week's ten are drawn.
func _draw(kit: TourKit) -> void:
	await kit.go_to("village", Village.SPAWN)
	# A bigger week: four $50 cases, each landing exactly $50 in the Brokerage.
	var brk := _balance("brk_1")
	var tickets_before := int(Game.state.casino.draw.entries)
	var landed := 0
	for i in 4:
		var res: Array = await Game.call_api("POST", "/casino/case", {"case_id": "case_50", "to_account": "brk_1"})
		if res[1] == "":
			landed += 5000
	await Game.refresh()
	kit.check(landed > 0 and _balance("brk_1") == brk + landed, "each $50 case landed exactly $50 in the Brokerage (+%d cents)" % landed)
	var dr: Dictionary = Game.state.casino.draw
	var entries := int(dr.entries)
	kit.check(entries == tickets_before + landed / 500, "every $5 that landed this week is a ticket (%d)" % entries)
	var od := DrawOverlay.new()
	kit.main.open_overlay(od)
	await kit.until(func() -> bool: return od.moment == "look", 6.0)
	await kit.wait(0.5)
	await kit.shot("draw_01_week")
	kit.check(od.line_count() == entries, "the owner's tickets hang on the line (%d)" % od.line_count())
	var plaque: Label = od._root.find_child("Plaque", true, false)
	kit.check(plaque != null and plaque.text == "%d of %d" % [entries, int(dr.tickets_total)], "the dais says the odds: %s" % (plaque.text if plaque else "?"))
	kit.check(dr.last == null, "no draw has happened yet, so the board is empty")
	var calm := od.spin_speed()
	await kit.tap_screen(_screen(kit, DrawOverlay.HUB))
	await kit.wait(0.35)
	kit.check(od.spin_speed() > calm + 1.0, "tapping the drum turns it")
	await kit.shot("draw_02_spin")
	await kit.tap_screen(_screen(kit, Vector2(460, 236)))
	await kit.until(func() -> bool: return kit.overlay() == null, 3.0)
	kit.check(kit.overlay() == null, "tapping the floor leaves the draw")

	# Sunday: the daily hook draws last week. Cosmetics only; no money moves.
	var house := _balance("sav_1")
	var owned_before := _owned_total()
	await Game.advance_days(5)
	await kit.until(func() -> bool: return Game.state.casino.draw.last != null, 5.0)
	var last: Dictionary = Game.state.casino.draw.last
	kit.check(str(last.week) == str(dr.week_start), "Sunday drew the week of %s" % str(dr.week_start))
	kit.check(_balance("sav_1") >= house, "the draw never takes money")
	var won: Array = last.won
	kit.check(_owned_total() == owned_before + won.size(), "each winning ticket of the owner's granted a piece (%d)" % won.size())
	od = DrawOverlay.new()
	kit.main.open_overlay(od)
	await kit.until(func() -> bool: return od.moment == "drawing", 6.0)
	kit.check(od.moment == "drawing", "a new result plays the drawing")
	await kit.wait(2.2)
	await kit.shot("draw_03_drawing")
	await kit.until(func() -> bool: return od.moment == "look", 20.0)
	await kit.wait(0.4)
	await kit.shot("draw_04_winners")
	var cream := 0
	for i in 10:
		var t: DrawOverlay.BoardTicket = od.board_ticket(i)
		if t and t.visible and t.slot.mine:
			cream += 1
	kit.check(cream == won.size(), "the board shows the owner's %d winning tickets in cream, the rest grey" % won.size())
	for i in 10:
		var t: DrawOverlay.BoardTicket = od.board_ticket(i)
		if t and t.slot.mine:
			await kit.tap_control(t)
			await kit.wait(0.3)
			await kit.shot("draw_05_mine")
			break
	await kit.tap_screen(_screen(kit, Vector2(460, 236)))
	await kit.until(func() -> bool: return kit.overlay() == null, 3.0)
	# Opened again, the result is already on the board.
	od = DrawOverlay.new()
	kit.main.open_overlay(od)
	await kit.until(func() -> bool: return od.moment == "look", 6.0)
	kit.check(od.moment == "look", "a seen result doesn't replay")
	await kit.wait(0.5)  # a tap the instant it opens is read as the tail of a double tap
	await kit.tap_screen(_screen(kit, Vector2(460, 236)))
	await kit.until(func() -> bool: return kit.overlay() == null, 3.0)


# --- helpers ---------------------------------------------------------------------------

func _screen(kit: TourKit, p: Vector2) -> Vector2:
	return kit.get_viewport().get_screen_transform() * p


func _go_to_page_of(kit: TourKit, book: BookOverlay, id: String) -> void:
	if book._cell_set[id] != book.page:
		var want: int = book._cell_set[id]
		var was := book.moment
		await kit.tap_control(book.tab_control(want))
		await kit.until(func() -> bool: return book.page == want and book.moment == was, 3.0)


func _balance(account: String) -> int:
	for d: Dictionary in Game.state.get("casino", {}).get("destinations", []):
		if d.id == account:
			return int(d.balance_cents)
	return 0


func _owned_total() -> int:
	var n := 0
	for k: String in Game.state.casino.owned:
		n += int(Game.state.casino.owned[k])
	return n


func _tier_total(book: BookOverlay, tier: String) -> int:
	var n := 0
	for k: String in Game.state.casino.owned:
		if book.items.has(k) and str(book.items[k].tier) == tier:
			n += int(Game.state.casino.owned[k])
	return n


func _owned_of(book: BookOverlay, tier: String) -> String:
	for id: String in book.items:
		if str(book.items[id].tier) == tier and book.count_of(id) > 0:
			return id
	return ""


## The rarest owned piece for a slot.
func _best_owned(book: BookOverlay, slot: String) -> String:
	var best := ""
	var rank := -1
	for id: String in book.items:
		var it: Dictionary = book.items[id]
		if str(it.slot) == slot and book.count_of(id) > 0:
			var r := BookOverlay.TIERS.find(it.tier)
			if r > rank:
				rank = r
				best = id
	return best
