class_name ClawOverlay
extends MachineOverlay
## The claw machine: the heap from /state behind the glass, every plush outlined (and the
## better ones glowing) in its rarity, so the count Vex says is the pile you see. Drag the
## claw across the glass, or tap the stick left or right; tap the button (or the claw) to
## drop. The price lands first, then the claw goes down where you dropped it, takes the piece
## the house drew (the one nearest, after a little wobble: drop_x), shudders on the way up,
## carries it to the chute, and the plush pops out of the door with the cosmetic inside.

const GLASS_R := Rect2(112, 34, 248, 156)
const HEAP := Rect2(140, 44, 220, 146)  # the heap's x, y (0..1) map onto this
const RAIL_Y := 40.0
const REST_Y := 46.0  # the claw head's top, at rest
const CHUTE_X := 129.0
const FLOOR_Y := 188.0
const STICK := Vector2(186, 213)
const BUTTON := Vector2(296, 213)
const COIN_SLOT := Vector2(240, 216)
const OUTLET := Vector2(129, 210)
const X_MIN := 148.0
const X_MAX := 352.0
const SPEED := 150.0

const ANIMALS := A + "ninja-adventure/Actor/Animal/"
## The plushes, one per heap spot: [sheet, frame, scale]. Followers as Webkinz-soft toys,
## and a penguin on top.
const PLUSH := [
	[ANIMALS + "Cat/SpriteSheet.png", Rect2(0, 0, 16, 16), 2.0],
	[ANIMALS + "Frog/SpriteSheet.png", Rect2(0, 0, 16, 16), 2.0],
	[ANIMALS + "Pig/SpriteSheetPink.png", Rect2(0, 0, 16, 16), 2.0],
	[ANIMALS + "Racoon/SpriteSheet.png", Rect2(0, 0, 16, 16), 2.0],
	[ANIMALS + "CatCyclop/SpriteSheet.png", Rect2(0, 0, 16, 16), 2.0],
	[ANIMALS + "Dog/SpriteSheet.png", Rect2(0, 0, 16, 16), 2.0],
	[ANIMALS + "Hamster/SpriteSheet.png", Rect2(0, 0, 15, 15), 2.0],
	[ANIMALS + "LionCub/SpriteSheet.png", Rect2(0, 0, 16, 16), 2.0],
	[ANIMALS + "Monkey/SpriteSheetBrown.png", Rect2(0, 0, 16, 16), 2.0],
	[ANIMALS + "CatBlack/SpriteSheet.png", Rect2(0, 0, 16, 16), 2.0],
	[ANIMALS + "Parrot/SpriteSheetBlue.png", Rect2(0, 0, 16, 16), 2.0],
	[ANIMALS + "Chicken/SpriteSheetCute.png", Rect2(0, 0, 16, 16), 2.0],
	[ANIMALS + "Dog2/SpriteSheet.png", Rect2(0, 0, 16, 16), 2.0],
	[ANIMALS + "Hamster/SpriteSheetGray.png", Rect2(0, 0, 15, 15), 2.0],
	[A + "grafxkid-critters-penguin/penguin_edit.png", Rect2(72, 0, 24, 32), 1.0],
]

const SND_MOTOR := A + "freesound-cc0-picks/347840_fishing_reel_wav.mp3"
const SND_STICK := A + "kenney-interface-sounds/Audio/click_001.ogg"
const SND_BUTTON := A + "kenney-interface-sounds/Audio/switch_005.ogg"
const SND_OPEN := A + "kenney-rpg-audio/Audio/metalClick.ogg"
const SND_GRIP := A + "kenney-impact-sounds/Audio/impactMetal_light_002.ogg"
const SND_SQUEAK := A + "kenney-impact-sounds/Audio/impactSoft_medium_000.ogg"
const SND_CREAK := A + "kenney-rpg-audio/Audio/creak2.ogg"
const SND_DROP := A + "kenney-impact-sounds/Audio/impactWood_light_002.ogg"
const SND_DOOR := A + "kenney-rpg-audio/Audio/doorOpen_1.ogg"
const SND_BURST := A + "kenney-impact-sounds/Audio/impactSoft_heavy_000.ogg"
const SND_HEART := A + "bart-heartbeat-sounds/heartbeat_fast_0.ogg"

## Where the claw is (room x), where the head hangs (its top), how open it is (0..1), the
## drop_x sent, and the plushes on display by slot, for the tour.
var claw_x := 250.0
var head_y := REST_Y
var open := 0.0
var drop_x := 0.5
var plushes: Dictionary = {}  # slot_index -> Control

var _target_x := 250.0
var _nudge := 0
var _nudge_held := 0.0
var _dragging := false
var _press_at := Vector2.ZERO
var _press_ms := 0
var _held: Control
var _swing := 0.0
var _cabinet: Cabinet
var _claw: Claw
var _stick: Stick
var _button: DropButton
var _door: Door
var _pile := Control.new()
var _motor := AudioStreamPlayer.new()
var _heart := AudioStreamPlayer.new()


func _build_machine() -> void:
	_cabinet = Cabinet.new()
	stage.add_child(_cabinet)
	_pile.size = Vector2(480, 270)
	_pile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pile.clip_contents = false
	stage.add_child(_pile)
	_show_heap(Game.state.get("casino", {}).get("claw", {}).get("heap", []), false)
	_claw = Claw.new()
	_claw.overlay = self
	stage.add_child(_claw)
	var glass := GlassFront.new()
	stage.add_child(glass)
	_door = Door.new()
	_door.position = OUTLET - Vector2(16, 12)
	stage.add_child(_door)
	_stick = Stick.new()
	_stick.position = STICK - Vector2(18, 18)
	stage.add_child(_stick)
	_button = DropButton.new()
	_button.position = BUTTON - Vector2(18, 18)
	stage.add_child(_button)
	_motor.stream = looped(SND_MOTOR)
	_motor.volume_db = -14.0
	add_child(_motor)
	_heart.stream = looped(SND_HEART)
	_heart.volume_db = -6.0
	add_child(_heart)


func _dealer_line() -> String:
	var dealer: Dictionary = Game.state.get("casino", {}).get("dealer", {})
	var before: Dictionary = dealer.get("before", {}).get("claw", {})
	return str(before.get(dest, dealer.get("line", "")))


func _price_cents() -> int:
	return int(Game.state.get("casino", {}).get("claw", {}).get("price_cents", 500))


func _machine_rect() -> Rect2:
	return Rect2(100, 14, 272, 220)


func _lamp_x() -> float:
	return 236.0


## Parts for taps and drags in the tour.
func stick_control() -> Control:
	return _stick


func button_control() -> Control:
	return _button


func glass_rect() -> Rect2:
	return GLASS_R


static func spot(x: float, y: float) -> Vector2:
	return HEAP.position + Vector2(x * HEAP.size.x, y * HEAP.size.y)


# --- the heap ------------------------------------------------------------------------------

func _show_heap(heap: Array, rain: bool) -> void:
	var order := heap.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.y) > float(b.y))
	var i := 0
	for p: Dictionary in order:
		var slot := int(p.slot_index)
		if plushes.has(slot):
			continue
		var toy := make_plush(slot, str(p.tier))
		var at := spot(float(p.x), float(p.y))
		toy.position = at - toy.size / 2.0
		toy.set_meta("home", toy.position)
		_pile.add_child(toy)
		plushes[slot] = toy
		if rain:
			var home := toy.position
			toy.position.y = GLASS_R.position.y - 40.0
			var tw := toy.create_tween()
			tw.tween_interval(i * 0.06)
			tw.tween_property(toy, "position:y", home.y, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tw.tween_callback(func() -> void: Sfx.play_path(SND_SQUEAK, randf_range(0.9, 1.3), -14.0))
		i += 1


## A plush in its rarity: a glow under the better ones, a 1-pixel outline in the tier color,
## the pack sprite on top.
static func make_plush(slot: int, tier: String) -> Control:
	var spec: Array = PLUSH[slot % PLUSH.size()]
	var tex := MachineOverlay.region(str(spec[0]), spec[1])
	var k := float(spec[2])
	var root := Control.new()
	root.size = (spec[1] as Rect2).size * k
	root.pivot_offset = Vector2(root.size.x / 2.0, root.size.y)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_meta("tier", tier)
	root.set_meta("slot", slot)
	if tier != "common":
		var g := MachineOverlay.rarity_glow(root, root.size / 2.0, tier, root.size.x * 0.8)
		g.show_behind_parent = true
	# Grey ones get the grey ramp's dark step, so the pile stays quiet and the colors carry.
	var line: Color = MachineOverlay.SHADOW.common if tier == "common" else CasinoFx.rarity_color(tier)
	for off: Vector2 in [Vector2(-k, 0), Vector2(k, 0), Vector2(0, -k), Vector2(0, k)]:
		var o := TextureRect.new()
		o.texture = tex
		o.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		o.size = root.size
		o.position = off
		o.material = MachineOverlay.silhouette(line)
		o.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(o)
	var front := TextureRect.new()
	front.texture = tex
	front.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	front.size = root.size
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(front)
	return root


# --- moving the claw ---------------------------------------------------------------------

func _machine_input(event: InputEvent, at: Vector2) -> bool:
	if moment != "choose":
		return false
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			if at.distance_to(BUTTON) <= 16.0:
				_drop()
				return true
			if at.distance_to(STICK) <= 20.0:
				# A tap steps the claw; holding glides it.
				_nudge = -1 if at.x < STICK.x else 1
				_nudge_held = 0.0
				_target_x = clampf(claw_x + _nudge * 12.0, X_MIN, X_MAX)
				_stick.tilt = _nudge
				Sfx.play_path(SND_STICK, 1.0, -8.0)
				return true
			if GLASS_R.has_point(at):
				_dragging = true
				_press_at = at
				_press_ms = Time.get_ticks_msec()
				return true
			return false
		# Release.
		if _nudge != 0:
			_nudge = 0
			_stick.tilt = 0
			return true
		if _dragging:
			_dragging = false
			var tap := at.distance_to(_press_at) < 4.0 and Time.get_ticks_msec() - _press_ms < 350
			if tap and absf(at.x - claw_x) < 14.0 and at.y < head_y + 30.0:
				_drop()
			elif tap:
				_target_x = clampf(at.x, X_MIN, X_MAX)
			return true
		return false
	var mm := event as InputEventMouseMotion
	if mm and _dragging and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if at.distance_to(_press_at) >= 4.0:
			_target_x = clampf(at.x, X_MIN, X_MAX)
		return true
	return false


func _process(delta: float) -> void:
	super._process(delta)
	if moment == "choose":
		if _nudge != 0:
			_nudge_held += delta
			if _nudge_held > 0.25:
				_target_x = clampf(_target_x + _nudge * 110.0 * delta, X_MIN, X_MAX)
		var before := claw_x
		claw_x = move_toward(claw_x, _target_x, SPEED * delta)
		var moving := absf(claw_x - before) > 0.01
		if moving and not _motor.playing:
			_motor.pitch_scale = 1.6
			_motor.play(randf_range(0.0, 8.0))
		elif not moving and _motor.playing:
			_motor.stop()
		_swing = lerpf(_swing, clampf((claw_x - before) / maxf(delta, 0.001) / -400.0, -0.3, 0.3), minf(1.0, delta * 6.0))
	else:
		_swing = lerpf(_swing, 0.0, minf(1.0, delta * 3.0))
	if _held:
		var hang := Vector2(claw_x, head_y + 23.0)
		_held.position = hang - Vector2(_held.size.x / 2.0, 4.0)
		_held.rotation = _swing * 0.8 + sin(_t * 9.0) * 0.04 * (1.0 if moment == "carry" else 0.0)
	_claw.queue_redraw()


# --- the drop ------------------------------------------------------------------------------

func _drop() -> void:
	moment = "pressed"
	_button.press()
	Sfx.play_path(SND_BUTTON, 1.0, -4.0)
	_motor.stop()
	drop_x = clampf((claw_x - HEAP.position.x) / HEAP.size.x, 0.0, 1.0)
	var data := await pay("/casino/claw", {"drop_x": drop_x}, COIN_SLOT)
	if data.is_empty():
		return
	await play(data)


## Play a grab from the drop through the reveal. _drop calls this once the money has landed;
## it never moves money itself.
func play(data: Dictionary) -> void:
	result = data
	phase = Phase.BUSY
	hush()
	var grabbed: Dictionary = data.get("grabbed", {})
	var slot := int(grabbed.get("slot_index", 0))
	var toy: Control = plushes.get(slot)
	if toy == null:
		toy = make_plush(slot, str(grabbed.get("tier", "common")))
		toy.position = spot(0.5, 0.24) - toy.size / 2.0
		toy.set_meta("home", toy.position)
		_pile.add_child(toy)
	plushes.erase(slot)
	await _descend(toy)
	await _grip(toy)
	await _lift(toy)
	await _carry()
	await _chute(toy)
	await _burst_open(slot, str(grabbed.get("tier", "common")))
	await reveal(data.get("item", {}), OUTLET + Vector2(0, -8))
	_settle(data.get("heap", []))
	finish()


func _descend(toy: Control) -> void:
	moment = "drop"
	var target := toy.position + toy.size / 2.0
	var top := toy.position.y - 12.0
	Sfx.play_path(SND_OPEN, 1.0, -6.0)
	var tw := create_tween()
	tw.tween_property(self, "open", 1.0, 0.2)
	await tw.finished
	_motor.pitch_scale = 1.0
	_motor.play(randf_range(0.0, 8.0))
	var from_x := claw_x
	var down := create_tween().set_parallel(true)
	down.tween_property(self, "head_y", top, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The wobble: the claw drifts onto the piece it will take.
	down.tween_method(func(t: float) -> void: claw_x = lerpf(from_x, target.x, t) + sin(t * PI * 3.0) * 2.0 * (1.0 - t), 0.0, 1.0, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await down.finished
	_motor.stop()


func _grip(toy: Control) -> void:
	moment = "grab"
	var tier := str(toy.get_meta("tier", "common"))
	var close_tw := create_tween()
	close_tw.tween_property(self, "open", 0.0, 0.22).set_ease(Tween.EASE_IN)
	await close_tw.finished
	Sfx.play_path(SND_GRIP, 1.0, -4.0)
	Sfx.play_path(SND_SQUEAK, 1.2, -8.0)
	shake(_room, 1.0, 0.12)
	var c := toy.position + toy.size / 2.0
	ring(_fx, c, CasinoFx.rarity_color(tier), 22.0, 0.35)
	CasinoFx.burst(_fx, c, CasinoFx.rarity_color(tier), 8, 50.0, 0.5)
	var squash := toy.create_tween()
	squash.tween_property(toy, "scale", Vector2(0.85, 1.12), 0.08)
	squash.tween_property(toy, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# The pile shifts where it came out.
	for other: Control in plushes.values():
		var home: Vector2 = other.get_meta("home")
		if home.distance_to(toy.position) < 44.0:
			var j := other.create_tween()
			j.tween_property(other, "position", home + Vector2(randf_range(-1, 1), 2).round(), 0.08)
			j.tween_property(other, "position", home, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_held = toy
	await get_tree().create_timer(0.25).timeout


## Up it comes, and partway up the claw shudders like it might let go. It never does: every
## grab wins something.
func _lift(_toy: Control) -> void:
	moment = "lift"
	_motor.pitch_scale = 0.9
	_motor.play(randf_range(0.0, 8.0))
	var from := head_y
	var mid := lerpf(from, REST_Y, 0.45)
	var up := create_tween()
	up.tween_property(self, "head_y", mid, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await up.finished
	moment = "shudder"
	_motor.stop()
	_heart.play()
	Sfx.play_path(SND_CREAK, 1.0, -4.0)
	var shudder := create_tween()
	for i in 7:
		shudder.tween_property(self, "open", 0.18 if i % 2 == 0 else 0.0, 0.06)
		shudder.parallel().tween_property(self, "head_y", mid + (1.5 if i % 2 == 0 else 0.0), 0.06)
	shudder.tween_property(self, "head_y", mid + 3.0, 0.12)
	shudder.tween_property(self, "open", 0.0, 0.08)
	await shudder.finished
	await get_tree().create_timer(0.25).timeout
	_heart.stop()
	moment = "lift"
	_motor.play(randf_range(0.0, 8.0))
	var rest := create_tween()
	rest.tween_property(self, "head_y", REST_Y, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await rest.finished


func _carry() -> void:
	moment = "carry"
	_motor.pitch_scale = 1.4
	var from := claw_x
	var tw := create_tween()
	tw.tween_method(func(x: float) -> void:
		_swing = clampf((x - claw_x) * 4.0, -0.3, 0.3)
		claw_x = x, from, CHUTE_X, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	_motor.stop()
	await get_tree().create_timer(0.2).timeout


func _chute(toy: Control) -> void:
	moment = "chute"
	Sfx.play_path(SND_OPEN, 1.1, -6.0)
	var o := create_tween()
	o.tween_property(self, "open", 1.0, 0.15)
	await o.finished
	_held = null
	var fall := toy.create_tween().set_parallel(true)
	fall.tween_property(toy, "position:y", FLOOR_Y + 4.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(toy, "rotation", 0.0, 0.2)
	fall.tween_property(toy, "modulate:a", 0.0, 0.32).set_delay(0.18)
	await fall.finished
	toy.queue_free()
	Sfx.play_path(SND_DROP, 0.8, -2.0)
	shake(_room, 1.5, 0.12)
	var shut := create_tween()
	shut.tween_property(self, "open", 0.0, 0.3)
	shut.tween_property(self, "claw_x", 250.0, 0.8).set_trans(Tween.TRANS_SINE)
	_target_x = 250.0
	await get_tree().create_timer(0.25).timeout


## The door flaps open and the plush tumbles out and bursts; what was inside comes out.
func _burst_open(slot: int, tier: String) -> void:
	moment = "door"
	Sfx.play_path(SND_DOOR, 1.3, -6.0)
	_door.flap()
	var slot_toy := make_plush(slot, tier)
	slot_toy.position = OUTLET - slot_toy.size / 2.0
	slot_toy.scale = Vector2(0.4, 0.4)
	slot_toy.z_index = 30
	_fx.add_child(slot_toy)
	var out := slot_toy.create_tween()
	out.tween_property(slot_toy, "scale", Vector2(1.2, 0.85), 0.12).set_ease(Tween.EASE_OUT)
	out.tween_property(slot_toy, "scale", Vector2.ONE, 0.15)
	out.tween_property(slot_toy, "scale", Vector2(1.25, 1.25), 0.25).set_trans(Tween.TRANS_SINE)
	await out.finished
	Sfx.play_path(SND_BURST, 1.0, -2.0)
	CasinoFx.burst(_fx, OUTLET, Palette.CREAM, 16, 90.0, 0.6)
	for i in 8:
		var puff := glow(_fx, OUTLET + Vector2(randf_range(-10, 10), randf_range(-8, 6)), Color(Palette.MUTED, 0.35), randf_range(6, 11), false)
		var tw := puff.create_tween().set_parallel(true)
		tw.tween_property(puff, "position", puff.position + Vector2(randf_range(-24, 24), randf_range(-24, -4)), 0.6)
		tw.tween_property(puff, "modulate:a", 0.0, 0.6)
		tw.chain().tween_callback(puff.queue_free)
	slot_toy.queue_free()


## What's left in the glass, from the answer: a fresh heap rains in if this was the last one.
func _settle(heap: Array) -> void:
	var keep: Dictionary = {}
	for p: Dictionary in heap:
		keep[int(p.slot_index)] = true
	for slot: int in plushes.keys():
		if not keep.has(slot):
			(plushes[slot] as Control).queue_free()
			plushes.erase(slot)
	_show_heap(heap, true)


# --- drawn pieces ------------------------------------------------------------------------

class Cabinet:
	extends Control
	## The cabinet: a marquee with an eye and chasing bulbs, the glass box with its floor and
	## the chute in the corner, the deck below.
	var _t := 0.0

	func _init() -> void:
		size = Vector2(480, 270)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var g := ClawOverlay.GLASS_R
		var body := Rect2(104, 16, 264, 216)
		draw_rect(body, MachineOverlay.BODY)
		draw_rect(body, MachineOverlay.TRIM, false, 2.0)
		# Marquee.
		draw_rect(Rect2(110, 18, 252, 14), MachineOverlay.BODY_DARK)
		var chase := int(_t * 8.0)
		for i in 30:
			var lit := (i + chase) % 5 == 0
			draw_rect(Rect2(114 + i * 8.3, 21, 2, 2), Color(Palette.CREAM, 0.95 if lit else 0.2))
			draw_rect(Rect2(114 + i * 8.3, 27, 2, 2), Color(Palette.CREAM, 0.95 if (i + chase + 2) % 5 == 0 else 0.2))
		# The glass box: dark inside, a floor, the chute hole and its low wall.
		draw_rect(g, MachineOverlay.GLASS)
		var light := MachineOverlay.res(MachineOverlay.LIGHT) as Texture2D
		draw_texture_rect(light, Rect2(g.position.x + 20, g.position.y + 20, g.size.x - 40, g.size.y), false, Color(Palette.PANEL, 0.55))
		draw_rect(Rect2(g.position.x, ClawOverlay.FLOOR_Y, g.size.x, g.end.y - ClawOverlay.FLOOR_Y), Color("2a1d33"))
		draw_rect(Rect2(g.position.x + 2, ClawOverlay.FLOOR_Y, 32, g.end.y - ClawOverlay.FLOOR_Y), Color.BLACK)
		draw_rect(Rect2(g.position.x + 34, ClawOverlay.FLOOR_Y - 18, 3, 20), MachineOverlay.TRIM)
		draw_rect(Rect2(g.position.x + 34, ClawOverlay.FLOOR_Y - 18, 3, 1), MachineOverlay.TRIM_LIT)
		# The rail.
		draw_rect(Rect2(g.position.x + 4, ClawOverlay.RAIL_Y - 2, g.size.x - 8, 3), MachineOverlay.TRIM)
		draw_rect(Rect2(g.position.x + 4, ClawOverlay.RAIL_Y - 2, g.size.x - 8, 1), MachineOverlay.TRIM_LIT)
		# Deck.
		draw_rect(Rect2(104, 194, 264, 38), MachineOverlay.BODY_DARK)
		draw_rect(Rect2(104, 194, 264, 1), MachineOverlay.TRIM_LIT)
		draw_rect(Rect2(232, 212, 16, 6), MachineOverlay.TRIM_LIT)
		draw_rect(Rect2(234, 214, 12, 2), Color.BLACK)


class GlassFront:
	extends Control
	## Reflections on the glass, in front of the heap and the claw.
	func _init() -> void:
		size = Vector2(480, 270)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var g := ClawOverlay.GLASS_R
		for k in 3:
			var x := g.position.x + 30 + k * 7
			draw_line(Vector2(x, g.position.y + 8), Vector2(x + 26, g.position.y + 40), Color(Palette.CREAM, 0.06 - k * 0.015), 3.0)
		draw_line(Vector2(g.end.x - 30, g.end.y - 40), Vector2(g.end.x - 10, g.end.y - 12), Color(Palette.CREAM, 0.05), 2.0)
		draw_rect(g, MachineOverlay.TRIM_LIT, false, 1.0)


class Claw:
	extends Control
	## The carriage on the rail, the cable, and the three-pronged claw.
	var overlay: ClawOverlay

	func _init() -> void:
		size = Vector2(480, 270)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var x := roundf(overlay.claw_x)
		var y := roundf(overlay.head_y)
		var o := overlay.open
		var bone := Palette.CREAM.darkened(0.15)
		var dark := MachineOverlay.TRIM
		draw_rect(Rect2(x - 7, ClawOverlay.RAIL_Y - 4, 14, 6), MachineOverlay.TRIM_LIT)
		draw_rect(Rect2(x - 7, ClawOverlay.RAIL_Y - 4, 14, 6), dark, false, 1.0)
		draw_line(Vector2(x, ClawOverlay.RAIL_Y + 2), Vector2(x, y), Color("8a7a6a"), 1.0)
		var light := MachineOverlay.res(MachineOverlay.LIGHT) as Texture2D
		draw_texture_rect(light, Rect2(x - 16, y - 8, 32, 32), false, Color(Palette.CREAM, 0.12))
		draw_rect(Rect2(x - 6, y, 12, 7), bone)
		draw_rect(Rect2(x - 6, y, 12, 7), dark, false, 1.0)
		draw_rect(Rect2(x - 2, y + 2, 4, 2), MachineOverlay.EYES)
		for side: float in [-1.0, 1.0]:
			var a := Vector2(x + side * 5.0, y + 7)
			var b := Vector2(x + side * (7.0 + 6.0 * o), y + 14)
			var c := Vector2(x + side * (3.0 + 7.0 * o), y + 21)
			draw_polyline(PackedVector2Array([a, b, c]), bone, 2.0)
			draw_line(c, c + Vector2(-side * 2.0, 0), bone, 2.0)
		draw_line(Vector2(x, y + 7), Vector2(x, y + 16 - 3.0 * o), bone, 2.0)


class Stick:
	extends Control
	## The joystick: tap or hold its left or right side.
	var tilt := 0:
		set(v):
			tilt = v
			queue_redraw()

	func _init() -> void:
		size = Vector2(36, 36)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0 + Vector2(0, 4)
		draw_circle(c, 11.0, Color("120c18"))
		draw_arc(c, 11.0, 0.0, TAU, 24, MachineOverlay.TRIM, 1.0)
		for side: float in [-1.0, 1.0]:
			var tip := c + Vector2(side * 15.0, 0)
			var tri := PackedVector2Array([tip, tip + Vector2(-side * 4.0, -3), tip + Vector2(-side * 4.0, 3)])
			draw_colored_polygon(tri, Color(Palette.CREAM, 0.9 if tilt == int(side) else 0.35))
		var top := c + Vector2(tilt * 6.0, -10)
		draw_line(c, top, MachineOverlay.TRIM_LIT, 3.0)
		draw_circle(top, 5.0, Palette.PINK.darkened(0.3))
		draw_circle(top + Vector2(-1, -1), 4.0, Palette.PINK)
		draw_rect(Rect2(top + Vector2(-2, -3), Vector2(1, 1)), Palette.CREAM)


class DropButton:
	extends Control
	## The big button.
	var _down := 0.0:
		set(v):
			_down = v
			queue_redraw()
	var _t := 0.0

	func _init() -> void:
		size = Vector2(36, 36)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func press() -> void:
		var tw := create_tween()
		tw.tween_property(self, "_down", 1.0, 0.06)
		tw.tween_property(self, "_down", 0.0, 0.25)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0 + Vector2(0, 2)
		var light := MachineOverlay.res(MachineOverlay.LIGHT) as Texture2D
		draw_texture_rect(light, Rect2(c - Vector2(22, 22), Vector2(44, 44)), false, Color(Palette.TEAL, 0.25 + 0.1 * sin(_t * 4.0)))
		draw_circle(c + Vector2(0, 3), 11.0, Color("0c3a36"))
		var top := c + Vector2(0, 2.0 * _down)
		draw_circle(top, 10.0, Palette.TEAL.darkened(0.3))
		draw_circle(top + Vector2(0, -1), 9.0, Palette.TEAL)
		draw_rect(Rect2(top + Vector2(-4, -5), Vector2(3, 1)), Color(Palette.CREAM, 0.8))
		# A claw glyph pressed into the cap.
		draw_line(top + Vector2(0, -4), top + Vector2(0, 0), Color("0c3a36"), 1.0)
		draw_polyline(PackedVector2Array([top + Vector2(-3, 0), top + Vector2(-4, 3), top + Vector2(-2, 5)]), Color("0c3a36"), 1.0)
		draw_polyline(PackedVector2Array([top + Vector2(3, 0), top + Vector2(4, 3), top + Vector2(2, 5)]), Color("0c3a36"), 1.0)


class Door:
	extends Control
	## The prize door under the chute.
	var _open := 0.0:
		set(v):
			_open = v
			queue_redraw()

	func _init() -> void:
		size = Vector2(32, 22)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func flap() -> void:
		var tw := create_tween()
		tw.tween_property(self, "_open", 1.0, 0.08)
		tw.tween_interval(0.5)
		tw.tween_property(self, "_open", 0.0, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		draw_rect(Rect2(0, 0, size.x, size.y), Color.BLACK)
		draw_rect(Rect2(0, 0, size.x, size.y), MachineOverlay.TRIM_LIT, false, 1.0)
		var h := size.y * (1.0 - _open * 0.85)
		draw_rect(Rect2(2, 2, size.x - 4, h - 4), MachineOverlay.TRIM)
		draw_rect(Rect2(2, 2, size.x - 4, 1), MachineOverlay.TRIM_LIT)
