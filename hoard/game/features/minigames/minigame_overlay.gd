class_name MinigameOverlay
extends Overlay
## The shell every arcade game shares: start the run on the server, count down, burn the
## two-minute fuse, fill the coin pouch, finish the run, tally, and leave on a tap.
## Games override game_id(), setup(), tick(), press(), release() and result().

const W := 480.0
const H := 270.0
const POUCH := Vector2(26, 250)
const FUSE_Y := 7.0
const FUSE_X0 := 46.0
const FUSE_X1 := 434.0
const HAND := "res://art/packs/kenney-cursor-pixel-pack/Tilemap/tilemap_packed.png"
## How long the tally stays up before a tap can close the game (the way-out door has faded in
## by then, and a thumb still hammering blocks has seen what it won).
const END_GRACE := 1.0

static var _catalog_cache: Dictionary = {}

var run: Dictionary = {}
var catalog: Dictionary = {}
var world := Node2D.new()  ## everything that shakes
var hud := Control.new()  ## fuse, pouch, lantern, exit: steady on top
var seconds := 120.0
var time_left := 120.0
var playing := false
var clock_running := true
var coins_shown := 0
var done := false
var result_body: Dictionary = {}
var music_player: AudioStreamPlayer
var holding := false

var _pouch: Sprite2D
var _pouch_label: Label
var _fuse_line := Line2D.new()
var _fuse_spark := CPUParticles2D.new()
var _fuse_glow: Sprite2D
var _fuse_label: Label
var _flames: Array[Sprite2D] = []
var _end_ready := false
var _end_at := 0  # when the tally shelf settled (ticks, ms): taps before END_GRACE only nudge
var _coin_step := 0
var _last_whole := -1
var _edge: Array[ColorRect] = []
var _hint: Node2D


# --- what each game fills in -------------------------------------------------------------

func game_id() -> String:
	return ""


func music_path() -> String:
	return ""


## Build the scene. `run` and `catalog` are ready.
func setup() -> void:
	pass


func tick(_delta: float) -> void:
	pass


func press(_pos: Vector2) -> void:
	pass


func release(_pos: Vector2) -> void:
	pass


## What the run reports to /minigames/finish.
func result() -> Dictionary:
	return {}


## After the server answers: the game's own reveal (the dungeon's relic). Await-able.
func reveal(_body: Dictionary) -> void:
	pass


## Icons for the end shelf: [{texture, count}].
func haul() -> Array:
	return []


# --- the shell ---------------------------------------------------------------------------

static func load_catalog() -> Dictionary:
	if _catalog_cache.is_empty():
		var res: Array = await Game.call_api("GET", "/minigames/catalog")
		if res[1] == "":
			_catalog_cache = res[0]
	return _catalog_cache


func _ready() -> void:
	add_backdrop(1.0).mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(world)
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	_begin()


func _begin() -> void:
	catalog = await load_catalog()
	var res: Array = await Game.call_api("POST", "/minigames/start", {"game": game_id()})
	if catalog.is_empty() or res[1] != "":
		var l := ArcadeFx.label("The lantern sputters. Try again.", 16, Palette.MUTED)
		l.position = Vector2(150, 126)
		hud.add_child(l)
		await get_tree().create_timer(1.5).timeout
		close(null)
		return
	run = res[0]
	seconds = float(catalog.games.games[game_id()].seconds)
	time_left = seconds
	music_player = ArcadeFx.music(self, music_path())
	setup()
	_build_hud()
	await countdown()
	if done or not is_inside_tree():
		return  # the door was tapped during the count: the run ends with nothing
	playing = true


func _build_hud() -> void:
	# The fuse: a rope burning from right to left with a spark at the burning end.
	_fuse_line.width = 2.0
	_fuse_line.default_color = Color("8a6a4a")
	_fuse_line.points = PackedVector2Array([Vector2(FUSE_X0, FUSE_Y), Vector2(FUSE_X1, FUSE_Y)])
	hud.add_child(_fuse_line)
	var knot := ColorRect.new()
	knot.color = Color("5a4030")
	knot.size = Vector2(5, 5)
	knot.position = Vector2(FUSE_X0 - 6, FUSE_Y - 2.5)
	hud.add_child(knot)
	_fuse_glow = ArcadeFx.glow(hud, Vector2(FUSE_X1, FUSE_Y), Color("ff9a3c"), 14.0, 0.9)
	_fuse_spark.amount = 18
	_fuse_spark.lifetime = 0.35
	_fuse_spark.spread = 180.0
	_fuse_spark.initial_velocity_min = 20.0
	_fuse_spark.initial_velocity_max = 50.0
	_fuse_spark.gravity = Vector2(0, 120)
	_fuse_spark.color = Color("ffd38a")
	_fuse_spark.position = Vector2(FUSE_X1, FUSE_Y)
	hud.add_child(_fuse_spark)
	_fuse_label = ArcadeFx.label("", 16, Palette.CREAM)
	_fuse_label.position = Vector2(FUSE_X1 + 6, FUSE_Y - 8)
	hud.add_child(_fuse_label)

	# The pouch and the lantern's flames sit on plates in the bottom corners.
	ArcadeFx.plate(hud, Rect2(POUCH.x - 18, POUCH.y - 16, 74, 30))
	ArcadeFx.plate(hud, Rect2(W - 66, H - 30, 58, 26))
	# The pouch.
	_pouch = Sprite2D.new()
	_pouch.texture = ArcadeFx.tex(ArcadeFx.PACKS + "shattered-pixel-dungeon/sprites/items.png", [32, 16, 16, 16])
	_pouch.position = POUCH
	_pouch.scale = Vector2(1.5, 1.5)
	hud.add_child(_pouch)
	ArcadeFx.glow(hud, POUCH, ArcadeFx.BRASS, 20.0, 0.35)
	_pouch_label = ArcadeFx.label("0", 24, ArcadeFx.BRASS, true)
	_pouch_label.position = POUCH + Vector2(14, -14)
	hud.add_child(_pouch_label)

	# The lantern's flames: lit ones burn, the one this run spends flickers hard.
	var mg: Dictionary = Game.state.get("minigames", {})
	var flames: Dictionary = mg.get("flames", {"max": 3, "left": 3})
	var left := int(run.get("flames_left", flames.get("left", 3)))
	for i in int(flames.get("max", 3)):
		var f := Sprite2D.new()
		f.texture = ArcadeFx.tex(ArcadeFx.PACKS + "kyrise-rpg-icons-16/spritesheet/spritesheet_16x16.png", [64 if i < left else 48, 80, 16, 16])
		f.position = Vector2(W - 54 + i * 14, H - 14)
		hud.add_child(f)
		_flames.append(f)
		if i < left:
			ArcadeFx.breathe(ArcadeFx.glow(hud, f.position + Vector2(0, -5), Color("ffb05a"), 9.0, 0.7), 0.5, 1.0, 0.6 + i * 0.13)
		else:
			f.modulate = Color(0.6, 0.6, 0.6, 0.8)
	if left > 0:
		var burning := _flames[left - 1]
		var tw := burning.create_tween().set_loops()
		tw.tween_property(burning, "scale", Vector2(1.1, 1.25), 0.09)
		tw.tween_property(burning, "scale", Vector2(0.95, 0.9), 0.11)

	# Leave early: the coins already earned are kept.
	var exit := TextureButton.new()
	var sheet := ArcadeFx.PACKS + "tiopalada-dark-dwellers-gui/20251125exitButton1-Sheet.png"
	exit.texture_normal = ArcadeFx.tex(sheet, [0, 0, 32, 32])
	exit.texture_hover = ArcadeFx.tex(sheet, [32, 0, 32, 32])
	exit.texture_pressed = ArcadeFx.tex(sheet, [64, 0, 32, 32])
	exit.ignore_texture_size = true
	exit.stretch_mode = TextureButton.STRETCH_SCALE
	exit.size = Vector2(20, 20)
	exit.pivot_offset = exit.size / 2.0  # it pops about its middle when tapped
	exit.position = Vector2(4, 14)
	exit.focus_mode = Control.FOCUS_NONE
	exit.name = "Exit"
	exit.pressed.connect(func() -> void:
		ArcadeFx.sfx(ArcadeFx.SND_CLICK)
		ArcadeFx.pop(exit, 0.3)
		if can_leave():
			_leave()
		elif _end_ready:
			nudge(exit.position + exit.size / 2.0)
		elif not done:
			end_run()  # mid-run or still counting down: the coins so far are kept
	)
	hud.add_child(exit)

	# Brass edge glow for fever and the last seconds.
	for side in 4:
		var r := ColorRect.new()
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.color = Color(ArcadeFx.BRASS, 0.0)
		r.size = Vector2(W, 4) if side < 2 else Vector2(4, H)
		if side == 1:
			r.position = Vector2(0, H - 4)
		elif side == 3:
			r.position = Vector2(W - 4, 0)
		hud.add_child(r)
		_edge.append(r)


## 3, 2, 1, then a flash.
func countdown() -> void:
	for n in [3, 2, 1]:
		if done:
			return
		var l := ArcadeFx.label(str(n), 64, Palette.CREAM, true, 8)
		hud.add_child(l)
		l.reset_size()
		l.pivot_offset = l.size / 2.0
		l.position = Vector2(W, H) / 2.0 - l.size / 2.0
		l.scale = Vector2(2.2, 2.2)
		ArcadeFx.sfx(ArcadeFx.SND_TICK, 1.0 + (3 - n) * 0.1, -2.0)
		var tw := l.create_tween()
		tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.22)
		tw.tween_property(l, "modulate:a", 0.0, 0.1)
		tw.tween_callback(l.queue_free)
		await get_tree().create_timer(0.5).timeout
	if done:
		return
	ArcadeFx.sfx(ArcadeFx.SND_GO, 1.2, -2.0)
	ArcadeFx.flash(hud, Palette.CREAM, 0.35, 0.2)
	ArcadeFx.shake(world, 2.0, 0.15)


func _process(delta: float) -> void:
	if not playing:
		return
	if clock_running:
		time_left = maxf(0.0, time_left - delta)
		_draw_fuse()
		if time_left <= 0.0:
			end_run()
			return
	tick(delta)


func _draw_fuse() -> void:
	var k := time_left / seconds
	var x := lerpf(FUSE_X0, FUSE_X1, k)
	_fuse_line.points = PackedVector2Array([Vector2(FUSE_X0, FUSE_Y), Vector2(x, FUSE_Y + sin(Time.get_ticks_msec() * 0.03) * 0.5)])
	_fuse_spark.position = Vector2(x, FUSE_Y)
	_fuse_glow.position = Vector2(x, FUSE_Y)
	var whole := int(ceil(time_left))
	_fuse_label.text = str(whole)
	_fuse_label.position.x = x + 6
	if whole != _last_whole:
		_last_whole = whole
		if whole <= 10:
			ArcadeFx.sfx(ArcadeFx.SND_TICK, 1.0 + (10 - whole) * 0.05, -4.0)
			ArcadeFx.pop(_fuse_label, 0.5)
			_fuse_label.add_theme_color_override("font_color", Color("ffb05a"))
			edge_glow(Color("ff9a3c"), 0.5)
			if music_player:
				music_player.pitch_scale = 1.0 + (10 - whole) * 0.01


## A number from this game's row in games.json (max_ore, max_fish), 0 if it has none.
## The server refuses a run over its limit, so a run ends when its haul is full.
func limit(key: String) -> int:
	return int(catalog.get("games", {}).get("games", {}).get(game_id(), {}).get(key, 0))


## Light the screen's edges for a moment (fever, last seconds).
func edge_glow(color: Color, alpha := 0.6, seconds_ := 0.5) -> void:
	for r in _edge:
		r.color = Color(color, alpha)
		var tw := r.create_tween()
		tw.tween_property(r, "color:a", 0.0, seconds_)


## Hold the edges lit (fever). Pass alpha 0 to let them go.
func edge_hold(color: Color, alpha: float) -> void:
	for r in _edge:
		r.color = Color(color, alpha)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	var pos := mb.position
	if mb.pressed:
		clear_hint()
		holding = true
		if can_leave():
			_leave()
		elif playing:
			press(pos)
		else:
			nudge(pos)  # counting down or tallying: the tap still lands somewhere
	else:
		holding = false
		if playing:
			release(pos)


## A tap the game has no use for right now still answers: a soft tick and a few motes.
func nudge(pos: Vector2) -> void:
	ArcadeFx.sfx(ArcadeFx.SND_TICK, randf_range(0.85, 0.95), -14.0)
	ArcadeFx.burst(hud, pos, Palette.MUTED, 4, 30.0, 0.25, 0.0)


## A hand that taps at `pos` until the player taps anything. The only teaching there is.
func show_hint(pos: Vector2) -> void:
	clear_hint()
	_hint = Node2D.new()
	_hint.position = pos
	_hint.z_index = 90
	hud.add_child(_hint)
	var hand := Sprite2D.new()
	hand.texture = ArcadeFx.tex(HAND, [272, 96, 16, 16])
	hand.offset = Vector2(4, 8)
	_hint.add_child(hand)
	var ring := Line2D.new()
	ring.width = 1.0
	ring.default_color = Color(Palette.CREAM, 0.0)
	var pts := PackedVector2Array()
	for i in 17:
		pts.append(Vector2(cos(i * TAU / 16.0), sin(i * TAU / 16.0)) * 6.0)
	ring.points = pts
	_hint.add_child(ring)
	var tw := _hint.create_tween().set_loops()
	tw.tween_property(hand, "position", Vector2(3, 3), 0.25).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		hand.texture = ArcadeFx.tex(HAND, [272, 112, 16, 16])
		ring.scale = Vector2(0.4, 0.4)
		ring.default_color = Color(Palette.CREAM, 0.9))
	tw.tween_property(ring, "scale", Vector2(1.8, 1.8), 0.3)
	tw.parallel().tween_property(ring, "default_color:a", 0.0, 0.3)
	tw.tween_callback(func() -> void: hand.texture = ArcadeFx.tex(HAND, [272, 96, 16, 16]))
	tw.tween_property(hand, "position", Vector2.ZERO, 0.25).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.25)


func clear_hint() -> void:
	if _hint and is_instance_valid(_hint):
		_hint.queue_free()
	_hint = null


## Coins earned during the run fly into the pouch. Each one rises a note.
func earn(amount: int, from: Vector2) -> void:
	if amount <= 0:
		return
	var shown := mini(amount, 12)
	for i in shown:
		var last := i == shown - 1
		ArcadeFx.fly_coin(hud, from, POUCH, i * 0.035, func() -> void:
			_coin_step += 1
			ArcadeFx.sfx(ArcadeFx.SND_COIN, ArcadeFx.scale_pitch(_coin_step % 10, true), -10.0)
			ArcadeFx.squash(_pouch, Vector2(1.5, 1.5))
			if last:
				coins_shown += amount
				_pouch_label.text = str(coins_shown)
				ArcadeFx.pop(_pouch_label, 0.3)
		)


## Time is up (or the player left): freeze, whistle, report, tally, wait for a tap.
func end_run() -> void:
	if done:
		return
	done = true
	playing = false
	holding = false
	clear_hint()
	ArcadeFx.sfx(ArcadeFx.SND_WHISTLE, 1.0, -4.0)
	if music_player:
		var tw := music_player.create_tween()
		tw.tween_property(music_player, "volume_db", -30.0, 0.6)
	ArcadeFx.hit_stop(get_tree(), 0.12)
	await get_tree().create_timer(0.35).timeout
	var res: Array = await Game.call_api("POST", "/minigames/finish", {"run_id": int(run.run_id), "result": result()})
	if res[1] == "":
		result_body = res[0]
	await reveal(result_body)
	await _tally()
	Game.refresh()
	_end_at = Time.get_ticks_msec()
	_end_ready = true


## The tally has been on screen long enough to be seen: a thumb still hammering blocks when
## the fuse ran out only nudges until the way-out door has faded in.
func can_leave() -> bool:
	return _end_ready and Time.get_ticks_msec() - _end_at >= int(END_GRACE * 1000.0)


func _tally() -> void:
	# The server's word on the coins: the minimum, the cap, or a quarter once the flames are out.
	# No answer means nothing was paid, so the pouch counts down to what really landed: none.
	var final := int(result_body.get("coins", 0))
	var from := coins_shown
	ArcadeFx.sfx(ArcadeFx.SND_COINS, 1.0, -6.0)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		_pouch_label.text = str(int(v)), float(from), float(final), 0.6).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await tw.finished
	coins_shown = final
	if not bool(result_body.get("full", true)) and final > 0:
		# Practice pay: the pouch dims a little; the lantern was already out.
		_pouch_label.add_theme_color_override("font_color", Color(ArcadeFx.BRASS, 0.7))
	if bool(result_body.get("full", false)) and not _flames.is_empty():
		var left := int(result_body.get("flames_left", 0))
		if left < _flames.size():
			var f := _flames[left]
			f.texture = ArcadeFx.tex(ArcadeFx.PACKS + "kyrise-rpg-icons-16/spritesheet/spritesheet_16x16.png", [48, 80, 16, 16])
			ArcadeFx.burst(hud, f.position + Vector2(0, -6), Palette.MUTED, 8, 30.0, 0.6, -40.0)
			ArcadeFx.sfx(ArcadeFx.PACKS + "shattered-pixel-dungeon/sounds/puff.mp3", 1.0, -8.0)
	_end_shelf()


func _end_shelf() -> void:
	# The tally lands on a framed plate (the HUD's own Dark Dwellers frame), dropped in over a
	# dimmed game: the coins on top, the haul in a row beneath, brass light spilling behind.
	var items: Array = haul()
	var pw := maxf(140.0, float(items.size()) * 30.0 + 48.0)
	var dim := ColorRect.new()
	dim.color = Color(Palette.NIGHT, 0.0)
	dim.size = Vector2(W, H)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.z_index = 79
	hud.add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.55, 0.25)
	var shelf := Node2D.new()
	shelf.position = Vector2(W / 2.0, H / 2.0 + 6)
	shelf.z_index = 80
	hud.add_child(shelf)
	var spill := ArcadeFx.glow(shelf, Vector2(0, -6), ArcadeFx.BRASS, pw * 0.75, 0.22)
	ArcadeFx.breathe(spill, 0.6, 1.0, 1.6)
	ArcadeFx.plate(shelf, Rect2(-pw / 2.0, -44, pw, 80), Color(0.62, 0.56, 0.74, 1.0))
	# A brass rule between the coins and the haul, and a rivet in each corner.
	var rule := ColorRect.new()
	rule.color = Color(ArcadeFx.BRASS, 0.55)
	rule.size = Vector2(pw - 28, 1)
	rule.position = Vector2(-pw / 2.0 + 14, 3)
	shelf.add_child(rule)
	for corner in 4:
		var rivet := ColorRect.new()
		rivet.color = ArcadeFx.BRASS
		rivet.size = Vector2(2, 2)
		rivet.position = Vector2(-pw / 2.0 + (5.0 if corner % 2 == 0 else pw - 7.0), -39.0 if corner < 2 else 29.0)
		shelf.add_child(rivet)
	# The plate drops in from above and settles with a bounce.
	shelf.position.y -= 18.0
	shelf.modulate.a = 0.0
	var drop := shelf.create_tween().set_parallel()
	drop.tween_property(shelf, "position:y", H / 2.0 + 6, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	drop.tween_property(shelf, "modulate:a", 1.0, 0.15)
	drop.chain().tween_callback(func() -> void:
		ArcadeFx.sfx(ArcadeFx.SND_COIN_DOUBLE, 0.8, -8.0)
		ArcadeFx.burst(shelf, Vector2(0, -44), ArcadeFx.BRASS, 10, 60.0, 0.4))
	var coin := Sprite2D.new()
	coin.texture = ArcadeFx.tex(ArcadeFx.COIN_STRIP, [0, 0, 8, 8])
	coin.scale = Vector2(3, 3)
	coin.position = Vector2(-30, -16)
	shelf.add_child(coin)
	ArcadeFx.glow(shelf, coin.position, ArcadeFx.BRASS, 26.0, 0.5)
	var total := ArcadeFx.label(str(coins_shown), 40, ArcadeFx.BRASS, true, 8)
	total.position = Vector2(-16, -38)
	shelf.add_child(total)
	ArcadeFx.pop(total, 0.4)
	var x := -float(items.size()) * 15.0
	for h: Dictionary in items:
		var s := Sprite2D.new()
		s.texture = h.texture
		s.position = Vector2(x + 8, 18)
		if h.texture.get_height() > 20:
			s.scale = Vector2(0.5, 0.5)  # a 32px tile sits at the row's 16px
		shelf.add_child(s)
		var n := ArcadeFx.label(str(h.count), 16, Palette.CREAM)
		n.position = Vector2(x + 14, 16)
		shelf.add_child(n)
		ArcadeFx.bob(s, 1.0, 1.0 + randf() * 0.4)
		x += 30.0
	var best: Dictionary = result_body.get("best", {})
	if int(result_body.get("score", 0)) > 0 and int(result_body.get("score", 0)) >= int(best.get(game_id(), 0)):
		var crown := Sprite2D.new()
		crown.texture = ArcadeFx.tex(ArcadeFx.PACKS + "shattered-pixel-dungeon/sprites/items.png", [192, 48, 16, 16])
		crown.position = Vector2(0, -50)
		shelf.add_child(crown)
		ArcadeFx.breathe(ArcadeFx.glow(shelf, crown.position, Palette.GLOW, 16.0, 0.6))
		ArcadeFx.bob(crown, 2.0, 0.8)
	ArcadeFx.sfx(ArcadeFx.SND_RISE, 1.0, -8.0)
	# A door that breathes: tap anywhere to leave.
	var door := Sprite2D.new()
	door.texture = ArcadeFx.tex(ArcadeFx.PACKS + "tiopalada-dark-dwellers-gui/20251125exitButton1-Sheet.png", [0, 0, 32, 32])
	door.position = Vector2(W / 2.0 - 30, 40)
	door.modulate = Color(1, 1, 1, 0.0)
	shelf.add_child(door)
	var tw := door.create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(door, "modulate:a", 1.0, 0.3)
	ArcadeFx.bob(door, 2.0, 0.9)


func _leave() -> void:
	if music_player:
		music_player.stop()
	Engine.time_scale = 1.0
	close(result_body)
