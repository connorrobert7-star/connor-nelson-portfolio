extends RefCounted
## Platform feel tour: HUD, toasts, tap marker, leader weight, camera, iris, overlay
## intro/outro, dialogue and speech bubbles. Run on its own:
##   godot --path game res://dev/tour.tscn -- <out> res://scripts/fx/tour_platform.gd


func run(kit: TourKit) -> void:
	var main := kit.main
	await kit.wait(0.6)
	await kit.shot("p01_arrive")
	kit.check(not main.panel.visible, "no text panel on arrival")
	kit.check(main._life._level >= 0, "the life gauge shows a level")
	kit.check(main._purse._target_coins >= 0, "the purse shows coins")

	# Walk in the village: dust, shadow, camera lead.
	await kit.go_to("village", Village.SPAWN)
	var lv := kit.level()
	await kit.until(func() -> bool: return lv.camera.offset == Vector2.ZERO and not Game.busy, 8.0)
	await kit.wait(0.5)
	await kit.shot("p02_village")
	var start := lv.leader.position
	Engine.time_scale = 0.15  # slow enough to catch the ring in a screenshot
	await kit.tap_world(start + Vector2(70, 0))
	var marks := lv.get_children().filter(func(n: Node) -> bool: return n is TapMarker)
	kit.check(not marks.is_empty(), "a tap leaves a ring where it landed")
	if not marks.is_empty():
		kit.log_line("  marker at %s, leader %s" % [str(marks[0].position), str(lv.leader.position)])
	await kit.shot("p03_tap_ring")
	Engine.time_scale = 1.0
	await kit.wait(0.25)
	await kit.shot("p04_walking")
	await kit.until(func() -> bool: return lv.leader.target == Vector2.INF, 4.0)
	await kit.wait(0.03)
	await kit.shot("p05_stop_squash")
	kit.check(lv.leader.position.distance_to(start + Vector2(70, 0)) < 20.0, "tap-walk arrives near the tap")
	kit.check(lv.camera.get_parent() == lv, "the camera is the leader's sibling")

	# Toasts: coins, money, item, a day, then a fourth pushes the oldest out.
	Game.event_fired.emit({"kind": "coins", "delta": 25})
	await kit.wait(0.08)
	Game.event_fired.emit({"kind": "money_moved", "amount_cents": 1000, "reason": "to Savings", "status": "simulated"})
	await kit.wait(0.08)
	Game.event_fired.emit({"kind": "item", "name": "Moth Crown", "tier": "epic", "item_id": "x"})
	await kit.wait(0.3)
	await kit.shot("p06_toasts")
	main.toast("Oct 21", Palette.MUTED, "", "day")
	await kit.wait(0.4)
	var live := 0
	for c in main._toasts.get_children():
		if not c.has_meta("leaving"):
			live += 1
	kit.check(live <= 3, "at most three toasts at once (%d)" % live)

	# The calendar plate is the week control: tap its left half for last week, its right
	# half to come back. Nothing here is keyboard-only.
	var purse: HudPurse = main._purse
	var cal: Rect2 = purse._cal_rect
	kit.check(cal.has_area(), "the calendar plate is drawn")
	var screen := kit.get_viewport().get_screen_transform()
	var weeks: int = int(Game.state.get("history_weeks", 1))
	if weeks > 1:
		await kit.tap_screen(screen * (purse.global_position + cal.position + Vector2(cal.size.x * 0.2, cal.size.y / 2.0)))
		await kit.until(func() -> bool: return Game.weeks_ago == 1 and not Game.busy, 5.0)
		kit.check(Game.weeks_ago == 1, "a tap on the calendar's left half turns back a week")
		await kit.wait(0.6)
		await kit.shot("p06b_last_week")
		await kit.tap_screen(screen * (purse.global_position + cal.position + Vector2(cal.size.x * 0.85, cal.size.y / 2.0)))
		await kit.until(func() -> bool: return Game.weeks_ago == 0, 5.0)
		kit.check(Game.weeks_ago == 0, "a tap on its right half comes back to this week")
		await kit.wait(0.5)

	# Purse count-up.
	var before: int = main._purse._target_coins
	main._purse.show_purse(before + 40, main._purse._target_cents + 12345, main._purse.week)
	await kit.wait(0.2)
	await kit.shot("p07_purse_counting")
	await kit.wait(0.9)
	await kit.shot("p08_purse_landed")
	main._purse.show_purse(before, int(Game.state.extra.extra_cents), main._purse.week)

	# An overlay: pop in, HUD slides away, pop out.
	var ov := Overlay.new()
	ov.add_backdrop()
	var lab := Label.new()
	lab.text = "overlay"
	lab.position = Vector2(220, 130)
	ov.add_child(lab)
	main.open_overlay(ov)
	await kit.wait(0.07)
	await kit.shot("p09_overlay_intro")
	await kit.wait(0.4)
	await kit.shot("p10_overlay_open")
	ov.close(null)
	kit.check(kit.overlay() == null, "a closing overlay is out of the list at once")
	await kit.wait(0.05)
	await kit.shot("p11_overlay_outro")
	await kit.wait(0.5)

	# Room to room: the iris.
	main.go_to("casino", Room.ENTRANCE)
	await kit.wait(0.12)
	await kit.shot("p12_iris_closing")
	await kit.wait(0.25)
	await kit.shot("p13_iris_opening")
	await kit.until(func() -> bool: return not Game.busy, 3.0)
	await kit.wait(0.4)

	# A speech bubble over the leader.
	var b := SpeechBubble.new()
	kit.level().leader.add_child(b)
	b.position = Vector2(0, -32)
	b.say("A new box. One go, then it's gone.", 1.0)
	await kit.wait(0.35)
	await kit.shot("p14_bubble")
	await kit.wait(2.0)
	b.queue_free()

	# Dialogue with choices.
	await kit.go_to("village", Village.SPAWN)
	var d: Dialogue = main.dialogue
	d.open("shopkeeper", "Marlo")
	d.ask("What'll it be?", ["Look at the shelf", "Ask about stocks", "Leave"] as Array[String])
	await kit.wait(0.6)
	await kit.shot("p15_dialogue")
	d._chosen.emit(2)
	d.close()
	await kit.wait(0.3)
