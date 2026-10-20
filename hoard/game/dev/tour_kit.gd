class_name TourKit
extends Node
## Plays the real game for tests and screenshots. Not shipped in the web build.
##   godot --path game res://dev/tour.tscn -- <out_dir> [res://features/x/tour_x.gd ...]
## Each tour script has `func run(kit: TourKit) -> void`. With no scripts, every
## dev/tours/*.gd and features/*/tour_*.gd runs. Failures make the exit code 1.

var out := "/tmp"
var main: Main
var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var scripts: Array[String] = []
	for i in range(1, args.size()):
		scripts.append(args[i])
	if scripts.is_empty():
		scripts = _all_tours()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await until(func() -> bool: return not Game.state.is_empty(), 20.0)
	await wait(0.5)
	for path in scripts:
		log_line("== %s" % path)
		var tour: Object = load(path).new()
		await tour.run(self)
		await reset_to_village()
	for f in failures:
		printerr("TOUR FAIL: ", f)
	print("tours done: %d failure(s)" % failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)


func _all_tours() -> Array[String]:
	var found: Array[String] = []
	for f in DirAccess.get_files_at("res://dev/tours"):
		if f.ends_with(".gd"):
			found.append("res://dev/tours/" + f)
	for d in DirAccess.get_directories_at("res://features"):
		for f in DirAccess.get_files_at("res://features/" + d):
			if f.begins_with("tour_") and f.ends_with(".gd"):
				found.append("res://features/%s/%s" % [d, f])
	return found


# --- checks ------------------------------------------------------------------------

func check(ok: bool, what: String) -> bool:
	if not ok:
		failures.append(what)
		printerr("  FAIL ", what)
	else:
		print("  ok   ", what)
	return ok


func log_line(text: String) -> void:
	print(text)


# --- time and input --------------------------------------------------------------

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


func until(cond: Callable, timeout := 10.0) -> bool:
	var t := 0.0
	while not cond.call():
		await get_tree().process_frame
		t += get_process_delta_time()
		if t > timeout:
			check(false, "timed out waiting (%.0fs)" % timeout)
			return false
	return true


func hold(action: String, seconds: float) -> void:
	Input.action_press(action)
	await wait(seconds)
	Input.action_release(action)


func press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(1)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await frames(2)


func key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(1)
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	await frames(2)


func shot(name: String) -> void:
	await frames(1)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


# --- places and talking -------------------------------------------------------------

func level() -> Level:
	return main.level


## Jump straight to a level (no walking) and wait for it to settle.
func go_to(level_id: String, spawn: Vector2i) -> void:
	main.go_to(level_id, spawn)
	await until(func() -> bool: return not Game.busy and main.level != null)
	await wait(0.4)


func reset_to_village() -> void:
	while main.dialogue.visible:
		if main.dialogue._choices.get_child_count() > 0:
			await press("ui_cancel")
		else:
			await press("interact")
		await wait(0.2)
	for child in main._overlays.get_children():
		if child is Overlay:
			(child as Overlay).close(null)
	await frames(2)
	if not (main.level is Village):
		await go_to("village", Village.SPAWN)


## Stand on a tile in the current level.
func stand(tile: Vector2i) -> void:
	level().leader.position = level().feet_at(tile)
	await frames(3)


## Press interact on whatever is in reach. Returns false if nothing was.
func interact() -> bool:
	if level().nearest_interactable().is_empty():
		check(false, "nothing to interact with at %s" % level().leader.position)
		return false
	await press("interact")
	await wait(0.3)
	return true


func dialogue_open() -> bool:
	return main.dialogue.visible


func choices() -> Array[String]:
	var out_list: Array[String] = []
	for b in main.dialogue._choices.get_children():
		out_list.append((b as Button).text)
	return out_list


## Click through lines until choices appear or the dialogue closes.
func read_on(max_lines := 12) -> void:
	for i in max_lines:
		await wait(0.1)
		if not dialogue_open() or main.dialogue._choices.get_child_count() > 0:
			return
		await press("interact")
		await press("interact")


## Pick the choice whose text starts with `prefix` (or by index if an int).
func choose(which: Variant) -> bool:
	await until(func() -> bool: return main.dialogue._choices.get_child_count() > 0, 5.0)
	var buttons := main.dialogue._choices.get_children()
	for i in buttons.size():
		var b: Button = buttons[i]
		if (which is int and i == which) or (which is String and b.text.begins_with(which)):
			if b.disabled:
				return check(false, "choice '%s' is disabled" % b.text)
			b.pressed.emit()
			await wait(0.3)
			return true
	return check(false, "no choice %s in %s" % [str(which), str(choices())])


func overlay() -> Overlay:
	var kids := main._overlays.get_children()
	return kids[-1] as Overlay if not kids.is_empty() else null
