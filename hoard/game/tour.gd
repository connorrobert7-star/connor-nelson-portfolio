extends Node
## Dev check, not part of the game. Plays the game with real input: walks, enters
## the shop, buys a share from Marlo, visits the tavern, and saves screenshots.
##   godot --path game res://tour.tscn -- <out_dir>

var out := "/tmp"
var main: Main


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if OS.get_cmdline_user_args().size():
		out = OS.get_cmdline_user_args()[0]
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while Game.state.is_empty():
		await get_tree().process_frame
	await _wait(0.5)
	var village: Level = main.level

	await _hold("ui_right", 1.0)
	print("walked right to ", village.leader.position)
	await _hold("ui_up", 4.0)
	print("stopped at the riverbank: ", village.leader.position)

	village.leader.position = village.feet_at(Vector2i(11, 13))
	await _shot("village_wren")
	await _press("interact")
	await _wait(1.5)
	await _shot("talk_wren")
	for i in 3:
		await _press("interact")
		await _wait(1.2)
	print("dialogue closed: ", not main.dialogue.visible)

	# Walk into the shop door from below.
	village.leader.position = village.feet_at(Vector2i(26, 23))
	await _hold("ui_up", 1.0)
	await _until(func() -> bool: return main.level is ShopRoom)
	await _wait(0.6)
	await _shot("shop_inside")
	var shop: Level = main.level
	shop.leader.position = shop.feet_at(Vector2i(3, 3))
	await _wait(0.3)
	await _shot("shop_shelf")

	# Talk to Marlo and buy $25 of the first stock.
	shop.leader.position = shop.feet_at(Vector2i(13, 7))
	await _wait(0.3)
	await _press("interact")
	await _advance_until_choices()
	await _shot("shop_menu")
	await _press("interact")  # Buy shares
	await _wait(1.0)
	await _shot("shop_pick")
	await _press("interact")  # first stock
	await _wait(2.5)
	await _shot("shop_amount")
	await _press("interact")  # first amount
	await _wait(2.0)
	await _shot("shop_confirm")
	await _press("interact")  # Buy
	await _until(func() -> bool: return main.dialogue._choices.get_child_count() == 0)
	await _wait(1.2)
	await _shot("shop_bought")
	print("orders after buy: ", Game.state.shop.recent_orders.slice(0, 1))
	await _advance_until_choices()
	await _press("ui_cancel")
	await _wait(0.5)
	print("busy after leaving Marlo: ", Game.busy)

	# Leave through the door, then go into the tavern.
	shop.leader.position = shop.feet_at(Vector2i(13, 9)) + Vector2(8, 0)
	await _hold("ui_left", 1.25)
	await _hold("ui_down", 1.0)
	await _until(func() -> bool: return main.level is Village)
	await _wait(0.5)
	print("back in village at ", main.level.leader.position)
	main.level.leader.position = main.level.feet_at(Vector2i(30, 14))
	await _hold("ui_up", 1.0)
	await _until(func() -> bool: return main.level is TavernRoom)
	await _wait(0.6)
	var tavern: Level = main.level
	tavern.leader.position = tavern.feet_at(Vector2i(3, 4))
	await _wait(0.3)
	await _press("interact")
	await _wait(1.5)
	await _shot("tavern_bess")
	get_tree().quit(0)


func _advance_until_choices() -> void:
	for i in 10:
		await _wait(1.5)
		if main.dialogue._choices.get_child_count() > 0:
			return
		await _press("interact")


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _until(cond: Callable) -> void:
	var t := 0.0
	while not cond.call():
		await get_tree().process_frame
		t += 0.016
		if t > 10.0:
			push_error("tour: timed out waiting")
			get_tree().quit(1)
			return


func _hold(action: String, seconds: float) -> void:
	Input.action_press(action)
	await _wait(seconds)
	Input.action_release(action)


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func _shot(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
