class_name CasinoRoomVex
extends Node2D
## Vex, the dealer: a tall hood in the dark with a crooked tip, a void for a face, two lit
## eyes that don't quite match, a brass chip on a cord, and long pale hands on the felt.
## He breathes, blinks, glances, drums his fingers, leans into the lamp to speak, and stands
## when a special shell is next. He only says what the backend gives him
## (state.casino.dealer). Position is his feet, behind the table.
##
## The pack stand-ins (Shattered Pixel Dungeon's necromancer) read as a grey slab at this
## size, so he is painted here pixel by pixel, at the room's own resolution.

const Art := preload("res://features/casino/casino_room_art.gd")
const W := 48
const H := 62
const CLOAK := Color("1d1528")
const CLOAK_DARK := Color("140e1c")
const RIM := Color("43355a")
const VOID := Color("050308")
const OUTLINE := Color("07050a")
const SKIN := Color("e9dcc9")
const SKIN_DARK := Color("9c8a7a")
const SLEEVE := Color("1a1322")
const EYE := Color("fff6e0")

var bubble := SpeechBubble.new()
var speaking := false
var last_line := ""
var spoken := 0

var _body := Sprite2D.new()
var _frames: Array[Texture2D] = []
var _eye_l := ColorRect.new()
var _eye_r := ColorRect.new()
var _eye_glows: Array[Sprite2D] = []
var _rim_glow: Sprite2D
var _hands := _Hands.new()
var _t := 0.0
var _blink := 3.0
var _blinking := 0.0
var _glance := 0.0
var _glance_dir := 0
var _lean := 0.0
var _stand := 0.0
var _stand_to := 0.0
var _tell := Color.TRANSPARENT


func _ready() -> void:
	for breath in 2:
		_frames.append(paint(breath))
	_body.texture = _frames[0]
	_body.centered = false
	_body.position = Vector2(-W / 2.0, -H)
	add_child(_body)
	_rim_glow = Art.glow(self, Vector2(0, -50), Art.LAMP, 22, 0.06)
	for e: ColorRect in [_eye_l, _eye_r]:
		e.color = EYE
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(e)
	_eye_l.size = Vector2(3, 2)
	_eye_r.size = Vector2(2, 2)
	for i in 2:
		var g := Art.glow(self, Vector2.ZERO, Color("fff3d6"), 4, 0.4)
		g.z_index = 3
		_eye_glows.append(g)
	_hands.z_index = 1
	add_child(_hands)
	bubble.position = Vector2(0, -66)
	add_child(bubble)


## One frame of Vex, painted into an image: hood, crooked tip, face void, cloak, pendant,
## then a dark outline and the lamp's rim light along the top edges.
static func paint(breath: int) -> ImageTexture:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var b := breath
	var filled := func(x: int, y: int) -> bool:
		var cx := x - 24.0
		# Cloak: shoulders rounding into a bell that widens under the table.
		if y >= 28 + b:
			var half := 15.0 + (y - 28 - b) * 0.35
			if y < 33 + b:
				half -= (33 + b - y) * 1.2
			if absf(cx + 0.5) <= half:
				return true
		# Hood dome.
		var hx := cx / 13.5
		var hy := (y - 19.0 - b) / 13.0
		if hx * hx + hy * hy <= 1.0:
			return true
		# The tip, bent over to his left like it's listening.
		if y >= b and y <= 10 + b:
			var mid := 24.0 + (10 + b - y) * 0.75
			var hw := (y - b) * 0.8 + 0.5
			if absf(x - mid) <= hw:
				return true
		return false
	for y in H:
		for x in W:
			if not filled.call(x, y):
				continue
			var c := CLOAK if x < 26 else CLOAK_DARK
			if (x + y) % 7 == 0 and y > 34 + b:
				c = c.darkened(0.15)  # folds
			img.set_pixel(x, y, c)
	# Face: a void with a slightly lighter lip.
	for y in H:
		for x in W:
			var fx := (x - 24.0) / 8.5
			var fy := (y - 21.0 - b) / 7.5
			var d := fx * fx + fy * fy
			if d <= 1.0:
				img.set_pixel(x, y, VOID if d < 0.78 else Color("0e0915"))
	# Brass chip pendant on a cord.
	for i in 5:
		img.set_pixel(18 + i, 31 + b + i, Color("6b4a22"))
		img.set_pixel(30 - i, 31 + b + i, Color("6b4a22"))
	for y in range(-2, 3):
		for x in range(-2, 3):
			if x * x + y * y <= 5:
				img.set_pixel(24 + x, 38 + b + y, Color("c99a4a") if x + y > -2 else Color("f0cf8a"))
	img.set_pixel(24, 38 + b, Color("7a5a2a"))
	# Outline, then rim light where the lamp catches the top edge.
	var out := img.duplicate() as Image
	for y in H:
		for x in W:
			if img.get_pixel(x, y).a > 0.0:
				var above := y > 0 and img.get_pixel(x, y - 1).a == 0.0
				if above and img.get_pixel(x, y) != VOID:
					out.set_pixel(x, y, RIM if x <= 28 else RIM.darkened(0.3))
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < W and n.y < H and img.get_pixel(n.x, n.y).a > 0.0:
					out.set_pixel(x, y, OUTLINE)
					break
	return ImageTexture.create_from_image(out)


func _process(delta: float) -> void:
	_t += delta
	# Breath on a 1.2 s cycle, a lean into the light while he speaks, standing for the tell.
	var breath := int(_t / 0.6) % 2
	_lean = move_toward(_lean, 1.0 if speaking else 0.0, delta * 6.0)
	_stand = move_toward(_stand, _stand_to, delta * 3.0)
	_body.texture = _frames[breath]
	var dy := roundf(_lean * 2.0 - _stand * 5.0)
	_body.position = Vector2(-W / 2.0, -H + dy)
	_blink -= delta
	if _blink <= 0.0:
		_blinking = 0.12
		_blink = randf_range(3.0, 7.0)
	_blinking = maxf(0.0, _blinking - delta)
	_glance -= delta
	if _glance <= 0.0:
		_glance = randf_range(2.0, 5.0)
		_glance_dir = [0, 0, -1, 1][randi() % 4]
	var look := Vector2(_glance_dir, 0)
	var eye := EYE if _tell.a == 0.0 else _tell.lightened(0.45)
	var open := _blinking <= 0.0
	var b := float(breath)
	_eye_l.position = Vector2(-7, -42 + b + dy) + look
	_eye_r.position = Vector2(3, -43 + b + dy) + look
	for e: ColorRect in [_eye_l, _eye_r]:
		e.visible = open
		e.color = eye
	var lit := (0.45 + _lean * 0.35 + (0.3 if _tell.a > 0.0 else 0.0)) * (1.0 if open else 0.0)
	_eye_glows[0].position = _eye_l.position + Vector2(1.5, 1)
	_eye_glows[1].position = _eye_r.position + Vector2(1, 1)
	for g: Sprite2D in _eye_glows:
		g.modulate = Color(eye, lit)
	_rim_glow.position.y = -50.0 + dy
	_hands.lean = _lean
	_hands.stand = _stand
	_hands.time = _t
	_hands.queue_redraw()


func say(text: String, hold := SpeechBubble.HOLD_SECONDS) -> void:
	if text == "":
		return
	last_line = text
	spoken += 1
	speaking = true
	Art.play(Art.SND_CARD, randf_range(0.8, 0.9), -14.0)
	await bubble.say(text, hold)
	speaking = false


func hush() -> void:
	if speaking:
		bubble.hide_now()
		speaking = false


## The tell: he stands and his eyes take the special shell's color. TRANSPARENT sits him down.
func set_tell(color: Color) -> void:
	_tell = color
	_stand_to = 1.0 if color.a > 0.0 else 0.0


func standing() -> bool:
	return _stand_to > 0.0


## His hood and shoulders in room space, for taps.
func hit_rect() -> Rect2:
	return Rect2(position + Vector2(-20, -60), Vector2(40, 46))


class _Hands:
	extends Node2D
	## Long pale hands resting on the felt, sleeves reaching back into the dark. One finger
	## at a time lifts in a slow drum.

	var lean := 0.0
	var stand := 0.0
	var time := 0.0

	func _draw() -> void:
		var drum := int(fmod(time, 3.2) / 0.11)  # 0..3 during the roll, then still
		for side: int in [-1, 1]:
			var wrist := Vector2(side * 23, -15 + roundf(lean) - roundf(stand * 3.0))
			var shoulder := Vector2(side * 14, -33 - roundf(stand * 5.0))
			# Sleeve: a dark tube from the shoulder to a ragged cuff, a pixel row at a time,
			# with the lamp catching its outer edge.
			var top := int(shoulder.y)
			var bottom := int(wrist.y) - 2
			for y in range(top, bottom + 1):
				var k := float(y - top) / maxf(1.0, bottom - top)
				var cx := roundf(lerpf(shoulder.x, wrist.x, k))
				var half := roundf(lerpf(4.0, 3.0, k))
				draw_rect(Rect2(cx - half, y, half * 2.0 + 1.0, 1), CasinoRoomVex.SLEEVE)
				draw_rect(Rect2(cx + side * half, y, 1, 1), CasinoRoomVex.RIM.darkened(0.25))
			draw_rect(Rect2(wrist + Vector2(-4, -3), Vector2(8, 2)), Color("2a2034"))
			# Palm and five long fingers spread toward the player.
			draw_rect(Rect2(wrist + Vector2(-3, -1), Vector2(6, 3)), CasinoRoomVex.SKIN_DARK)
			draw_rect(Rect2(wrist + Vector2(-3, -1), Vector2(6, 2)), CasinoRoomVex.SKIN)
			for f in 4:
				var fx := wrist.x - 3.0 + f * 2.0 - (side if f == 0 else 0)
				var lift := 1 if (side > 0 and drum == f) else 0
				var length: int = [5, 7, 7, 5][f]
				draw_rect(Rect2(Vector2(fx, wrist.y + 2 - lift), Vector2(1, length - lift)), CasinoRoomVex.SKIN)
				draw_rect(Rect2(Vector2(fx, wrist.y + 1 + length - lift), Vector2(1, 1)), CasinoRoomVex.SKIN_DARK)
			var thumb := wrist + Vector2(-side * 4, 0)
			draw_rect(Rect2(thumb, Vector2(1, 3)), CasinoRoomVex.SKIN)



## Vex in the machine overlays: the same painted hood at 2x, cut off at the chest, the
## mismatched lit eyes following `look`, and long pale fingers drumming on the frame. He
## leans into the light and his eyes flare when he speaks. Position is the bust's top-left.
class Bust:
	extends Control

	const K := 2.0
	const ROWS := 40  # source rows shown: hood, face, shoulders, the chip
	const LIGHT := "res://art/packs/kenney-particle-pack/PNG (Transparent)/light_01.png"

	## Where his eyes go (overlay coordinates): the bill, the reel, the item.
	var look := Vector2(240, 140)
	## The y (local) of the frame his hands rest on.
	var ledge := ROWS * K
	## Draw a dark rail with a brass lip under his hands (when there's no cabinet edge).
	var rail := false
	var tell := Color.TRANSPARENT
	var hands := Fingers.new()
	var _frames: Array[Texture2D] = []
	var _light: Texture2D
	var _glows: Array[TextureRect] = []
	var _t := 0.0
	var _blink := 2.5
	var _lean := 0.0
	var _flare := 0.0

	func _init() -> void:
		size = Vector2(CasinoRoomVex.W * K, ROWS * K)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		for b in 2:
			_frames.append(CasinoRoomVex.paint(b))
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		var soft := GradientTexture2D.new()
		soft.gradient = Gradient.new()
		soft.gradient.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
		soft.gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
		soft.fill = GradientTexture2D.FILL_RADIAL
		soft.fill_from = Vector2(0.5, 0.5)
		soft.fill_to = Vector2(1.0, 0.5)
		soft.width = 32
		soft.height = 32
		for i in 2:
			var g := TextureRect.new()
			g.texture = soft
			g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			g.size = Vector2(16, 14)
			g.material = add
			g.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(g)
			_glows.append(g)
		hands.bust = self
		hands.z_index = 2
		add_child(hands)

	## Lean into the lamp, eyes flaring, for a line.
	func speak() -> void:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "_lean", 1.0, 0.1)
		tw.tween_property(self, "_flare", 1.0, 0.06)
		tw.chain().tween_interval(0.7)
		tw.chain().tween_property(self, "_lean", 0.0, 0.3)
		tw.parallel().tween_property(self, "_flare", 0.0, 0.5)

	func breath() -> int:
		return int(_t / 0.6) % 2

	func lean_px() -> Vector2:
		return Vector2(roundf(_lean), roundf(_lean)) * K

	func _process(delta: float) -> void:
		_t += delta
		_blink -= delta
		if _blink < -0.12:
			_blink = randf_range(3.0, 7.0)
		var b := breath()
		var o := lean_px()
		var d := look - (global_position + Vector2(24, 20) * K)
		var off := Vector2(clampf(roundf(d.x / 90.0), -1, 1), clampf(roundf(d.y / 90.0), -1, 1))
		var open := _blink > 0.0
		var col := CasinoRoomVex.EYE if tell.a == 0.0 else tell.lightened(0.45)
		var spots := [Vector2(17, 20 + b), Vector2(27, 19 + b)]
		for i in 2:
			var at: Vector2 = (spots[i] + off) * K + o + Vector2(2 if i == 0 else 1, 1) * K * 0.5
			_glows[i].position = at - _glows[i].size / 2.0
			_glows[i].modulate = Color(col, (0.35 + 0.4 * _flare) * (1.0 if open else 0.0))
			_glows[i].scale = Vector2.ONE * (1.0 + _flare * 0.5)
			_glows[i].pivot_offset = _glows[i].size / 2.0
		set_meta("eye_off", off)
		queue_redraw()
		hands.queue_redraw()

	func _draw() -> void:
		var b := breath()
		var o := lean_px()
		# The lamp catching the edge of his hood, so the silhouette reads off the dark.
		if _light == null:
			_light = load(LIGHT) as Texture2D  # held: a texture only a draw call uses is freed
		draw_texture_rect(_light, Rect2(o + Vector2(-16, -8), Vector2(128, 104)), false, Color(0.42, 0.32, 0.55, 0.22))
		draw_texture_rect_region(_frames[b], Rect2(o, size), Rect2(0, 0, CasinoRoomVex.W, ROWS))
		if _blink <= 0.0:
			return
		var off: Vector2 = get_meta("eye_off", Vector2.ZERO)
		var col := CasinoRoomVex.EYE if tell.a == 0.0 else tell.lightened(0.45)
		# The two eyes that don't match: a wide one and a narrow one, lit.
		draw_rect(Rect2((Vector2(17, 20 + b) + off) * K + o, Vector2(3, 2) * K), col)
		draw_rect(Rect2((Vector2(27, 19 + b) + off) * K + o, Vector2(2, 2) * K), col)
		if _flare > 0.3:
			draw_rect(Rect2((Vector2(16, 19 + b) + off) * K + o, Vector2(5, 4) * K), Color(col, 0.18 * _flare))
			draw_rect(Rect2((Vector2(26, 18 + b) + off) * K + o, Vector2(4, 4) * K), Color(col, 0.18 * _flare))


## His long pale hands on the frame: sleeves out of the dark, fingers hooked over the edge,
## one finger at a time lifting in a slow drum.
class Fingers:
	extends Control

	var bust: Bust

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _px(x: float, y: float, w: float, h: float, c: Color, o: Vector2) -> void:
		draw_rect(Rect2(Vector2(x, y) * Bust.K + o, Vector2(w, h) * Bust.K), c)

	func _draw() -> void:
		if bust == null:
			return
		var k := Bust.K
		var o := Vector2(bust.lean_px().x, 0)
		var edge := roundf(bust.ledge / k)  # in source pixels
		var drum := int(fmod(bust._t, 3.2) / 0.11)  # 0..3 during the roll, then still
		if bust.rail:
			_px(-2, edge, 52, 3, Color("1a1012"), Vector2.ZERO)
			_px(-2, edge, 52, 1, Color("8a6a3a"), Vector2.ZERO)
			_px(-2, edge + 3, 52, 1, Color(0, 0, 0, 0.5), Vector2.ZERO)
		for side: int in [-1, 1]:
			var wx := 24 + side * 15
			# Sleeve: a dark tube from the shoulder down to a ragged cuff at the edge.
			var top := 30
			for y in range(top, int(edge) - 1):
				var f := float(y - top) / maxf(1.0, edge - 1 - top)
				var cx := roundf(lerpf(24 + side * 11, wx, f))
				_px(cx - 3, y, 7, 1, CasinoRoomVex.SLEEVE, o)
				_px(cx + side * 3, y, 1, 1, CasinoRoomVex.RIM.darkened(0.2), o)
			_px(wx - 4, edge - 3, 8, 2, Color("2a2034"), o)
			# The palm on the edge, four long fingers hooked over it, a thumb.
			_px(wx - 3, edge - 1, 6, 2, CasinoRoomVex.SKIN, o)
			_px(wx - 3, edge, 6, 1, CasinoRoomVex.SKIN_DARK, o)
			for f in 4:
				var fx := wx - 3 + f * 2 - (side if f == 0 else 0)
				var lift := 2 if (side > 0 and drum == f) else 0
				var length: int = [4, 6, 6, 4][f]
				_px(fx, edge + 1 - lift, 1, length - lift, CasinoRoomVex.SKIN, o)
				_px(fx, edge + length - lift, 1, 1, CasinoRoomVex.SKIN_DARK, o)
			_px(wx - side * 4, edge - 1, 1, 3, CasinoRoomVex.SKIN, o)
