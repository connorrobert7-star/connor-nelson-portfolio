extends SceneTree
## Dev check, not part of the game. Loads the village, walks the leader with real
## input, visits each place, and saves screenshots.
##   godot --path game --script res://tour.gd -- <out_dir>

const STOPS := [
	["spawn", Vector2(328, 288)],
	["board", Vector2(344, 270)],
	["fields", Vector2(120, 232)],
	["tavern", Vector2(488, 222)],
	["river", Vector2(300, 100)],
	["house", Vector2(328, 200)],
	["shrine", Vector2(232, 362)],
	["shop", Vector2(424, 362)],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() else "/tmp"
	var village: Node2D = load("res://scenes/village.tscn").instantiate()
	root.add_child(village)
	while village.state.is_empty() and village._error == "":
		await process_frame
	if village._error != "":
		push_error(village._error)
		quit(1)
		return
	var leader: Node2D = village.leader
	var start: Vector2 = leader.position
	Input.action_press("ui_right")
	await create_timer(1.0).timeout
	Input.action_release("ui_right")
	print("walked right: ", start, " -> ", leader.position)
	Input.action_press("ui_up")
	await create_timer(4.0).timeout
	Input.action_release("ui_up")
	print("walked up into the river (should stop at bank): ", leader.position)
	for stop: Array in STOPS:
		leader.position = stop[1]
		for i in 10:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [out, stop[0]])
	# Page back two weeks with the [ key and look at the fields again.
	for i in 2:
		var key := InputEventKey.new()
		key.keycode = KEY_BRACKETLEFT
		key.pressed = true
		Input.parse_input_event(key)
		var want := i + 1
		while int(village.state.window.weeks_ago) != want:
			await process_frame
	print("paged back to: ", village.state.window, " crops ", village.state.crops.state)
	leader.position = Vector2(120, 232)
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/fields_2_weeks_ago.png" % out)
	quit(0)
