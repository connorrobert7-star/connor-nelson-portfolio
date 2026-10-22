class_name FollowerBody
extends Node2D
## One follower, alive. It bobs, breathes, blinks, looks around, shuffles about, and wears its
## mood on its body so it reads from across the room: posture and droop, a glow that dims with
## Faith, a veil in mourning, drool and growls when hungry, zzz when lazy. Every state comes from
## the backend (Game.state.followers); this only draws it. Taps and food reach it via its Flock.

## The chant runs at 92 BPM.
const BEAT := 60.0 / 92.0
const WALK_SPEED := 38.0

var fid := ""
var kind := "cultist"  # personal | holding | cultist
var data: Dictionary = {}
var flock: Node  # the Flock that owns it (null inside an overlay)
var home := Vector2.ZERO
var index := 0
var px := 1  # whole-number scale for 16px creatures
var band := "content"
var pose := "idle"
var bubble_name := ""
var stage := 0
var egg := false
var veiled := false
## A point this follower can't stop looking at (the 40% giant), or INF.
var stare_at := Vector2.INF
## Running, eating, kneeling: the idle shuffle waits.
var busy := false
## Wander around home (off inside overlays).
var wanders := true
## A holding growing or shrinking to its new weekly size.
var resizing := false

var rig := Node2D.new()
var body := Sprite2D.new()
var aura: Sprite2D
var item_aura: Sprite2D
## What it wears, on its own body (children of the body sprite, so they share its scale and
## follow its facing): a hat or helmet seated on its top row, a mask from the skin slot on its
## face, and a cloak as its body from the shoulders down redone in the cloak's colors (shade
## for shade, a lit edge where it drapes; see FollowerArt.cloak_material). A creature skin (a
## cat, an owl, an imp) is not worn but taken on: the follower becomes it.
var hat := Sprite2D.new()
var mask := Sprite2D.new()
var cloak: ShaderMaterial  # on the body while a cloak is worn
var veil := Sprite2D.new()
var halo := Sprite2D.new()
var bubble := Sprite2D.new()
var hover_ring: Sprite2D

var _pose: Dictionary = {}
var _bubbles: Dictionary = {}
var _tint := Color.WHITE
var _glow := 0.6
var _t := 0.0
var _phase := randf() * TAU
var _squash := Vector2.ONE
var _hop := 0.0
var _lift := 0.0
var _turn := 0.0  # extra rotation from reactions (head shakes, dances)
var _blink_in := randf_range(1.0, 4.0)
var _blink_left := 0.0
var _glance_in := randf_range(1.0, 4.0)
var _glance_left := 0.0
var _look := 0  # -1 left, 0 front, 1 right
var _wander_in := randf_range(1.5, 5.0)
var _bubble_in := randf_range(0.3, 6.0)
var _bubble_clock := -1.0
var _growl_in := randf_range(6.0, 20.0)
var _wobble := 0.0
var _wobble_in := randf_range(1.0, 2.5)
var _arms := false  # chanting: penguins throw their wings up on the beat
var _chant_left := 0.0
var _step := 0.0
var _height := 16.0
var _width := 16.0
var _shown_candles := 0.0
var _wearing: Dictionary = {}
var _skin: Texture2D = null  # a creature skin it has taken on
var _head: Dictionary = {}  # where the worn pieces sit, from the body's own pixels
var _worn_flip := false


func _init(follower_kind := "cultist", follower_id := "", at := Vector2.ZERO) -> void:
	kind = follower_kind
	fid = follower_id
	home = at
	position = at


func _ready() -> void:
	y_sort_enabled = false
	aura = FollowerArt.glow(Color(Palette.CREAM, 0.0), 20.0)
	add_child(aura)
	item_aura = FollowerArt.glow(Color(1, 1, 1, 0), 22.0)
	item_aura.visible = false
	add_child(item_aura)
	hover_ring = FollowerArt.glow(Color(Palette.CREAM, 0.0), 16.0, FollowerArt.SOFT)
	hover_ring.scale.y *= 0.4
	add_child(hover_ring)
	add_child(rig)
	rig.add_child(body)
	for s: Sprite2D in [mask, hat]:
		s.visible = false
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		body.add_child(s)
	veil.texture = FollowerArt.tex(FollowerArt.VEIL)
	veil.visible = false
	rig.add_child(veil)
	halo.texture = FollowerArt.region(FollowerArt.RING, Rect2(96, 0, 32, 32))
	halo.modulate = Color(Palette.CREAM, 0.8)
	halo.visible = false
	rig.add_child(halo)
	bubble.visible = false
	bubble.z_index = 30
	add_child(bubble)


# --- state ----------------------------------------------------------------------------------------


## Take a new state for this follower. `look` is state.followers (poses, bubbles, bands).
func apply(d: Dictionary, look: Dictionary, faith_band: String) -> void:
	data = d
	band = faith_band
	_pose = look.get("poses", {}).get(str(d.get("pose", "idle")), {})
	pose = str(d.get("pose", "idle"))
	_bubbles = look.get("bubbles", {})
	var band_def: Dictionary = look.get("bands", {}).get(band, {})
	var tint: Array = band_def.get("tint", [1, 1, 1])
	_tint = Color(float(tint[0]), float(tint[1]), float(tint[2]))
	_glow = float(band_def.get("glow", 0.6))
	var new_bubble := str(d.get("bubble", ""))
	if new_bubble != bubble_name:
		bubble_name = new_bubble
		_bubble_in = randf_range(0.2, 1.5)
	veiled = bool(d.get("veiled", false))
	if kind == "personal":
		egg = not bool(d.get("hatched", false))
		stage = int(d.get("stage", 0))
	_skin = _skin_of(d.get("wearing", {}))
	_set_look()
	_set_wearing(d.get("wearing", {}))
	veil.visible = veiled and not egg
	halo.visible = int(d.get("level", 1)) >= 3 and not egg
	_place_parts()


func _set_look() -> void:
	match kind:
		"personal":
			if egg:
				# The egg sits big in the circle, waiting for the first deposit.
				body.texture = FollowerArt.egg(0)
				body.offset = Vector2(0, -10)
				body.scale = Vector2(2, 2)
				_height = 38.0
				_width = 24.0
			else:
				body.texture = FollowerArt.lamb(stage, 1)
				body.offset = Vector2(0, -FollowerArt.LAMB_CELL / 2.0)
				body.scale = Vector2.ONE
				_height = float(FollowerArt.lamb_size(stage))
				_width = _height * 0.8
		"holding":
			body.texture = FollowerArt.icon(data.get("look", {}))
			body.offset = Vector2(0, -8)
			if not resizing:
				body.scale = Vector2(px, px)
			_height = 15.0 * px
			_width = 14.0 * px
		_:
			body.texture = FollowerArt.penguin(FollowerArt.PENGUIN_IDLE)
			body.offset = Vector2(0, -13)
			_height = 17.0
			_width = 14.0
	if _skin and not egg:
		# A creature skin: it takes that shape, about as big as it was.
		var k := px if kind == "holding" else (maxi(1, roundi(_height / 16.0)) if kind == "personal" else 1)
		body.texture = _skin
		body.offset = Vector2(0, -_skin.get_height() / 2.0)
		if kind != "holding" or not resizing:
			body.scale = Vector2(k, k)
		_height = float(_skin.get_height() * k)
		_width = float(_skin.get_width() * k) * 0.9


## The skin slot's creature (null for none, or for a mask, which is worn on the face).
func _skin_of(wearing: Dictionary) -> Texture2D:
	var skin: Dictionary = wearing.get("follower_skin", {})
	if skin.is_empty():
		return null
	var cut := BookOverlay.cut_icon(skin)
	if cut and BookOverlay.mask_eyes(cut) >= 0.0:
		return null
	return FollowerArt.icon(skin.get("icon", {}))


func _set_wearing(wearing: Dictionary) -> void:
	_wearing = wearing
	_dress()
	var aura_item: Dictionary = wearing.get("aura", {})
	item_aura.visible = not aura_item.is_empty() and not egg
	if item_aura.visible:
		var c: Color = Palette.RARITY.get(str(aura_item.get("tier", "common")), Palette.COMMON)
		item_aura.modulate = Color(c, 0.55)
		item_aura.scale = Vector2.ONE * (_height * 1.6 / 128.0)


## Fit what it wears to the body it has now, read from its own pixels: the head is three rows
## from its crown (the first row about as wide as the top of it), the shoulders a little under
## half way down.
func _dress() -> void:
	hat.visible = false
	mask.visible = false
	body.material = null
	_head = {}
	if egg:
		return
	var sh := FollowerArt.shape(body.texture)
	if sh.is_empty() or not (sh.used as Rect2i).has_area():
		return
	var used: Rect2i = sh.used
	var size: Vector2i = sh.size
	# The crown of its head: the first row as wide as most of its head (a lamb's curl or an
	# ear tip above it is not where a hat sits); the head is the three rows from there.
	var widest := 0
	for y in range(used.position.y, used.position.y + maxi(3, used.size.y / 3)):
		if sh.left[y] >= 0:
			widest = maxi(widest, int(sh.right[y]) - int(sh.left[y]) + 1)
	var top := used.position.y
	while top < used.end.y - 1 and (sh.left[top] < 0 or int(sh.right[top]) - int(sh.left[top]) + 1 < widest * 0.6):
		top += 1
	var l := size.x
	var r := -1
	for y in range(top, mini(top + 3, used.end.y)):
		if sh.left[y] >= 0:
			l = mini(l, sh.left[y])
			r = maxi(r, sh.right[y])
	# The body sprite is centered on its offset: texture pixel (0, 0) sits here, body-local.
	var origin := (-Vector2(size) / 2.0 + body.offset).round()
	_head = {"origin": origin, "top": top, "mid": (l + r + 1) / 2.0, "w": mini(r - l + 1, 14), "h": used.end.y - top}
	var hat_item: Dictionary = _wearing.get("hat", {})
	if not hat_item.is_empty():
		_fit_head_piece(hat, hat_item)
	var skin: Dictionary = _wearing.get("follower_skin", {})
	if not skin.is_empty() and _skin == null:
		_fit_head_piece(mask, skin)
	var cloak_item: Dictionary = _wearing.get("cloak", {})
	if not cloak_item.is_empty():
		var col: Color = Palette.RARITY.get(str(cloak_item.get("tier", "common")), Palette.COMMON)
		var pal := BookOverlay.palette_of(BookOverlay.cut_icon(cloak_item), col)
		if cloak == null:
			cloak = FollowerArt.cloak_material()
		cloak.set_shader_parameter("shoulder", float(top + maxi(3, roundi(used.size.y * 0.45))))
		cloak.set_shader_parameter("hem", float(used.end.y - 1))
		cloak.set_shader_parameter("bands", sh.bands)
		cloak.set_shader_parameter("cloak_dark", pal[0])
		cloak.set_shader_parameter("cloak_mid", pal[1])
		cloak.set_shader_parameter("cloak_light", pal[2])
		body.material = cloak
		_sync_cloak()
	_worn_flip = body.flip_h
	_place_worn()


## A hat or a mask, cut to its pixels and sized to the head's width.
func _fit_head_piece(s: Sprite2D, item: Dictionary) -> void:
	var cut := BookOverlay.cut_icon(item)
	if cut == null:
		return
	var art := BookOverlay.head_art(item, cut, float(_head.w))
	s.texture = art.texture
	s.set_meta("eyes", art.eyes)
	s.visible = true


## Seat the head pieces for the way it faces: a hat's lowest two rows over its top two, a
## mask's eyes a third of the way down its body. Whole pixels, mirrored with the body.
func _place_worn() -> void:
	if _head.is_empty():
		return
	var origin: Vector2 = _head.origin
	for s: Sprite2D in [mask, hat]:
		if not s.visible or s.texture == null:
			continue
		var w := s.texture.get_width()
		var h := s.texture.get_height()
		var eyes: float = s.get_meta("eyes", -1.0)
		var y := float(_head.top) + 2.0 - h
		if eyes >= 0.0:
			y = float(_head.top) + roundf(float(_head.h) * 0.3) - eyes
			y = maxf(y, float(_head.top) - 3.0)
		var x := roundf(float(_head.mid) - w / 2.0)
		var at := origin + Vector2(x, y)
		if body.flip_h:
			at.x = -(at.x + w)
		s.position = at
		s.flip_h = body.flip_h


## The cloak's rows are counted from the top of the frame showing now (a penguin's frames sit
## on different rows of its sheet).
func _sync_cloak() -> void:
	if body.material == null or body.material != cloak:
		return
	var y := 0.0
	if body.texture is AtlasTexture:
		y = (body.texture as AtlasTexture).region.position.y
	cloak.set_shader_parameter("region_top", y)


func _place_parts() -> void:
	var head := -_height
	veil.position = Vector2(0, head + 6.0)
	veil.scale = Vector2.ONE * maxf(0.6, _width * 1.1 / 20.0)
	halo.position = Vector2(0, head - 3.0)
	halo.scale = Vector2(_width / 26.0, _width / 70.0)
	aura.position = Vector2(0, head * 0.5)
	aura.scale = Vector2.ONE * (_height * 1.7 / 128.0)
	item_aura.position = aura.position
	hover_ring.position = Vector2(0, 1)
	hover_ring.scale = Vector2(_width * 2.2 / 128.0, _width * 0.8 / 128.0)
	bubble.position = Vector2(0, head - 15.0)


## The tap target: the body's box, a little generous for fingers.
func hit_rect() -> Rect2:
	return Rect2(position + Vector2(-_width / 2.0 - 3.0, -_height - 3.0), Vector2(_width + 6.0, _height + 6.0))


func head_point() -> Vector2:
	return position + Vector2(0, -_height * 0.75)


func height() -> float:
	return _height


# --- the living loop ------------------------------------------------------------------------------


func _process(delta: float) -> void:
	_t += delta
	var hz := float(_pose.get("hz", 1.0))
	var amp := float(_pose.get("bob", 1.0))
	# At Fervent the flock breathes as one, on the chant's beat: the cult tell.
	var phase := 0.0 if band == "fervent" and not egg else _phase
	var clock := Time.get_ticks_msec() / 1000.0 if band == "fervent" else _t
	var wave := sin(clock * hz * TAU + phase)
	var bob := amp * (absf(wave) if bool(_pose.get("hop", false)) or _chant_left > 0.0 else wave * 0.5 + 0.5)
	if _chant_left > 0.0:
		bob = 3.0 * absf(sin(clock * PI / BEAT))
	var breath := 1.0 + 0.035 * sin(clock * TAU / 1.6 + phase)
	if pose == "sleep":
		breath = 1.0 + 0.08 * sin(_t * TAU / 2.4)
	var droop := float(_pose.get("droop", 1.0))
	var thin := float(_pose.get("thin", 1.0))
	if kind == "cultist" and pose in ["flat", "sleep"]:
		droop = 1.0
		thin = 1.0
	var shiver := float(_pose.get("shiver", 0.0)) * sin(_t * 47.0) * 0.6
	var blink_squash := 0.88 if _blink_left > 0.0 and kind != "personal" else 1.0
	rig.position = Vector2(shiver, -bob - _hop - _lift)
	rig.scale = Vector2(thin * _squash.x, droop * breath * _squash.y * blink_squash)
	var rot := _turn
	if _pose.has("tilt"):
		rot += deg_to_rad(float(_pose.tilt)) * (1.0 if index % 2 == 0 else -1.0)
	elif _pose.has("sway"):
		rot += deg_to_rad(float(_pose.sway)) * sin(_t * TAU * hz)
	if egg:
		rot += _wobble_angle(delta)
	rig.rotation = rot
	modulate = Color(_tint, modulate.a)
	# Faith shows as light: a soft cream halo that flickers, bright at Fervent, gone in grief.
	var flicker := 0.85 + 0.15 * sin(_t * 19.0 + _phase) * sin(_t * 7.0)
	aura.modulate = Color(Palette.CREAM, _glow * 0.42 * flicker)
	if item_aura.visible:
		item_aura.modulate.a = 0.4 + 0.2 * sin(_t * 3.0)
	_blink(delta)
	_glance(delta)
	_animate_frames(delta)
	_bubble_tick(delta)
	_noises(delta)
	_wander(delta)
	if _chant_left > 0.0:
		_chant_left -= delta


func _wobble_angle(delta: float) -> float:
	_wobble_in -= delta
	if _wobble_in <= 0.0:
		_wobble = 0.6
		_wobble_in = randf_range(1.2, 2.8)
	_wobble = maxf(0.0, _wobble - delta)
	return sin(_wobble * 40.0) * 0.22 * _wobble


func _blink(delta: float) -> void:
	if egg:
		return
	if _blink_left > 0.0:
		_blink_left -= delta
		return
	_blink_in -= delta
	if _blink_in <= 0.0:
		_blink_left = 0.11
		# Sometimes twice.
		_blink_in = 0.25 if randf() < 0.2 else randf_range(2.2, 5.0)


func _glance(delta: float) -> void:
	if _glance_left > 0.0:
		_glance_left -= delta
		if _glance_left <= 0.0:
			_look = 0
		return
	var every := float(_pose.get("glance", 0))
	if stare_at != Vector2.INF:
		# The others can't stop looking at the giant.
		_look = 1 if stare_at.x > position.x else -1
		return
	if every <= 0.0 or egg:
		_look = 0
		return
	_glance_in -= delta
	if _glance_in > 0.0:
		return
	_glance_in = every * randf_range(0.7, 1.4)
	_glance_left = randf_range(0.6, 1.4)
	var target := _interest_point()
	if target != Vector2.INF:
		_look = 1 if target.x > position.x else -1
	else:
		_look = [-1, 1].pick_random()


## Followers lean toward their hidden favorite thing; watching them is how you learn it.
func _interest_point() -> Vector2:
	if flock == null or randf() > 0.6:
		return Vector2.INF
	return flock.call("interest_point", str(data.get("favorite_thing", "")))


func _animate_frames(delta: float) -> void:
	_step += delta
	if _skin and not egg:
		body.texture = _skin
		body.flip_h = _look == -1
		_follow_flip()
		return
	match kind:
		"personal":
			if egg:
				return
			var frame := 1
			if _look == 1:
				frame = FollowerArt.LAMB_RIGHT
			elif _look == -1:
				frame = FollowerArt.LAMB_LEFT
			elif _blink_left > 0.0 or pose == "sleep" or pose == "flat":
				frame = FollowerArt.LAMB_BLINK
			elif busy and _hop > 0.5:
				frame = [0, 2][int(_step * 8.0) % 2]
			body.texture = FollowerArt.lamb(stage, frame)
		"holding":
			body.flip_h = _look == -1
		_:
			var cell := FollowerArt.PENGUIN_IDLE
			if pose == "flat":
				cell = FollowerArt.PENGUIN_FLAT
			elif pose == "sleep":
				cell = FollowerArt.PENGUIN_LIE
			elif _chant_left > 0.0 or pose == "chant":
				var up := int(Time.get_ticks_msec() / 1000.0 / BEAT + index) % 2 == 0
				cell = FollowerArt.PENGUIN_ARMS_UP if up else FollowerArt.PENGUIN_IDLE
			elif busy and _hop > 0.5:
				cell = FollowerArt.PENGUIN_STEP[int(_step * 8.0) % 2]
			elif _look != 0:
				cell = FollowerArt.PENGUIN_SIDE
			body.texture = FollowerArt.penguin(cell)
			body.flip_h = _look == -1
	_follow_flip()


## What it wears turns with it.
func _follow_flip() -> void:
	_sync_cloak()
	if body.flip_h != _worn_flip:
		_worn_flip = body.flip_h
		_place_worn()


## Mood bubbles: pop in, hold, pop out, wait, again. Crying and the naming question come often.
func _bubble_tick(delta: float) -> void:
	var sheet := str(_bubbles.get(bubble_name, ""))
	if sheet == "" or busy:
		bubble.visible = false
		_bubble_clock = -1.0
		return
	if _bubble_clock < 0.0:
		_bubble_in -= delta
		if _bubble_in <= 0.0:
			_bubble_clock = 0.0
		return
	_bubble_clock += delta
	var frame := -1
	if _bubble_clock < 0.36:
		frame = int(_bubble_clock / 0.072)
	elif _bubble_clock < 2.0:
		frame = 5 + int((_bubble_clock - 0.36) * 7.0) % 5
	elif _bubble_clock < 2.36:
		frame = 10 + int((_bubble_clock - 2.0) / 0.072)
	if frame < 0 or frame > 14:
		bubble.visible = false
		_bubble_clock = -1.0
		var often := bubble_name in ["crying", "question", "drool"]
		_bubble_in = randf_range(0.6, 2.0) if often else randf_range(2.5, 6.0)
		return
	bubble.visible = true
	bubble.texture = FollowerArt.bubble(sheet, frame)
	bubble.position.y = -_height - 15.0 + sin(_t * 3.0) * 1.0


## Show the mood bubble now instead of waiting for its turn.
func bubble_now() -> void:
	_bubble_in = 0.0
	_bubble_clock = 0.0


func _noises(delta: float) -> void:
	if not bool(data.get("hungry", false)) or busy or not is_visible_in_tree():
		return
	_growl_in -= delta
	if _growl_in <= 0.0:
		_growl_in = randf_range(14.0, 30.0)
		FollowerArt.play("growl", randf_range(0.55, 0.75), -12.0)
		_shake_belly()


func _wander(delta: float) -> void:
	if not wanders or busy or egg or pose in ["flat", "sleep"]:
		return
	_wander_in -= delta
	if _wander_in > 0.0:
		return
	_wander_in = randf_range(2.5, 7.0) * (2.0 if veiled else 1.0)
	var target := home + Vector2(randf_range(-10, 10), randf_range(-6, 6))
	if stare_at != Vector2.INF and target.distance_to(stare_at) < 34.0:
		target = home
	walk_to(target, 0.6 if veiled else 1.0)


# --- moves ----------------------------------------------------------------------------------------


## Waddle somewhere, hopping a little on each step.
func walk_to(target: Vector2, speed_mult := 1.0) -> Tween:
	var seconds := maxf(0.15, position.distance_to(target) / (WALK_SPEED * speed_mult))
	if target.x != position.x and kind != "personal":
		_look = 1 if target.x > position.x else -1
		_glance_left = seconds
	var tw := create_tween()
	tw.tween_property(self, "position", target, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var hops := create_tween().set_loops(maxi(1, int(seconds / 0.2)))
	hops.tween_property(self, "_hop", 1.5, 0.1)
	hops.tween_property(self, "_hop", 0.0, 0.1)
	return tw


func squash(to: Vector2, seconds := 0.06) -> Tween:
	var tw := create_tween()
	tw.tween_property(self, "_squash", to, seconds)
	tw.tween_property(self, "_squash", Vector2.ONE, 0.26).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	return tw


## A tap: squash, hop, a heart, a happy noise. Later taps the same day only squish.
func pet(gained: bool) -> void:
	var tw := create_tween()
	tw.tween_property(self, "_squash", Vector2(1.25, 0.78), 0.06)
	tw.tween_property(self, "_squash", Vector2(0.9, 1.15), 0.08)
	tw.tween_property(self, "_squash", Vector2.ONE, 0.26).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var hop := create_tween()
	hop.tween_property(self, "_hop", 7.0 if gained else 3.0, 0.1).set_ease(Tween.EASE_OUT)
	hop.tween_property(self, "_hop", 0.0, 0.18).set_ease(Tween.EASE_IN)
	if egg:
		_wobble = 0.8
		FollowerArt.play("crack", 1.4, -10.0)
		return
	_voice(1.15 if gained else 1.6)
	FlockFx.specks(get_parent(), head_point(), FollowerArt.SPECK_HEART, 3 if gained else 1)
	if gained:
		_shown_candles = 2.2
		queue_redraw()


func _voice(pitch := 1.0) -> void:
	match kind:
		"personal":
			FollowerArt.play("bleat", pitch * randf_range(1.05, 1.25), -6.0)
		"holding":
			FollowerArt.play("voice", pitch * randf_range(0.8, 1.4) / maxf(1.0, px * 0.6), -8.0)
		_:
			FollowerArt.play("voice", pitch * randf_range(1.4, 1.9), -12.0)


## Leaning toward food or a hat held over it: mouth open, eyes on it.
func hover(on: bool) -> void:
	var tw := create_tween()
	tw.tween_property(hover_ring, "modulate:a", 0.55 if on else 0.0, 0.1)
	if on:
		squash(Vector2(1.08, 1.1), 0.08)


## Chomp, chomp, chomp: crumbs, a swell, a love bubble. The favorite gets a little dance.
func eat(favorite: bool) -> void:
	busy = true
	FollowerArt.play("eat", randf_range(1.0, 1.15), -6.0)
	for i in 3:
		var tw := create_tween()
		tw.tween_property(self, "_squash", Vector2(1.18, 0.84), 0.06)
		tw.tween_property(self, "_squash", Vector2(0.96, 1.06), 0.06)
		await tw.finished
		FlockFx.burst(get_parent(), head_point(), Color("c99a5b"), 5, 40.0, 0.4)
	_squash = Vector2(1.12, 0.95)
	squash(Vector2(1.15, 0.92), 0.08)
	bubble_name = "love"
	_bubble_clock = 0.0
	if favorite:
		_voice(1.2)
		for i in 4:
			var tw := create_tween()
			tw.tween_property(self, "_hop", 6.0, 0.12).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(self, "_turn", 0.35 * (1 if i % 2 == 0 else -1), 0.12)
			tw.tween_property(self, "_hop", 0.0, 0.12).set_ease(Tween.EASE_IN)
			await tw.finished
			FlockFx.specks(get_parent(), head_point(), FollowerArt.SPECK_HEART, 1, 6.0)
		_turn = 0.0
	busy = false


## Full, or the purse is empty: a head shake.
func refuse() -> void:
	FollowerArt.play("no", 1.0, -10.0)
	var tw := create_tween()
	for i in 3:
		tw.tween_property(self, "_turn", 0.22, 0.05)
		tw.tween_property(self, "_turn", -0.22, 0.05)
	tw.tween_property(self, "_turn", 0.0, 0.05)


func _shake_belly() -> void:
	var tw := create_tween()
	tw.tween_property(self, "_squash", Vector2(1.08, 0.94), 0.05)
	tw.tween_property(self, "_squash", Vector2(0.94, 1.04), 0.05)
	tw.tween_property(self, "_squash", Vector2.ONE, 0.1)
	FlockFx.specks(get_parent(), head_point() + Vector2(0, _height * 0.4), FollowerArt.SPECK_STEAM, 1, 2.0, Palette.MUTED)


## A level of loyalty: lift, a white flash, a sparkle.
func level_up() -> void:
	FollowerArt.play("level", 1.0, -6.0)
	var tw := create_tween()
	tw.tween_property(self, "_lift", 6.0, 0.25).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(rig, "modulate", Color(3, 3, 3), 0.08)
	tw.tween_property(rig, "modulate", Color.WHITE, 0.3)
	tw.tween_property(self, "_lift", 0.0, 0.3).set_ease(Tween.EASE_IN)
	FlockFx.burst(get_parent(), head_point(), Palette.CREAM, 18, 70.0, 0.6, 60.0)
	FlockFx.ring(get_parent(), position + Vector2(0, -_height / 2.0), Palette.CREAM, 22.0)


## The personal follower grows a stage: flash, swell, pop.
func grow(to_stage: int) -> void:
	stage = to_stage
	_skin = _skin_of(data.get("wearing", {}))
	_set_look()
	_set_wearing(data.get("wearing", {}))
	_place_parts()
	FollowerArt.play("grow", 1.0, -4.0)
	rig.modulate = Color(4, 4, 4)
	_squash = Vector2(0.5, 0.5)
	var tw := create_tween()
	tw.tween_property(self, "_squash", Vector2(1.3, 1.3), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(rig, "modulate", Color.WHITE, 0.5)
	tw.tween_property(self, "_squash", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	FlockFx.burst(get_parent(), position + Vector2(0, -_height / 2.0), Palette.CREAM, 24, 90.0, 0.7, 80.0)
	FlockFx.ring(get_parent(), position + Vector2(0, -_height / 2.0), Palette.CREAM, 34.0, 0.5)


## The egg cracks open: shakes, chips of shell, and a hatchling on wobbly legs.
func hatch() -> void:
	busy = true
	egg = true
	body.scale = Vector2(2, 2)
	body.offset = Vector2(0, -10)
	for f in [1, 2]:
		body.texture = FollowerArt.egg(f)
		FollowerArt.play("crack", 1.0 + f * 0.15, -6.0)
		_wobble = 0.9
		await get_tree().create_timer(0.45).timeout
	FlockFx.burst(get_parent(), position + Vector2(0, -10), Palette.CREAM, 22, 90.0, 0.6, 220.0)
	FlockFx.puff(get_parent(), position + Vector2(0, -6), Palette.CREAM)
	egg = false
	FollowerArt.play("hatch", 1.0, -4.0)
	grow(maxi(1, int(data.get("stage", 1))))
	_voice(1.4)
	busy = false


## The veil lifts off and drifts away: the mourning is over.
func unveil() -> void:
	if not veil.visible:
		return
	var v := Sprite2D.new()
	v.texture = veil.texture
	v.global_position = veil.global_position
	v.scale = veil.global_scale
	v.z_index = 50
	get_parent().add_child(v)
	veil.visible = false
	var tw := v.create_tween()
	tw.tween_property(v, "position", v.position + Vector2(randf_range(-10, 10), -30), 0.9).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(v, "rotation", randf_range(-1.0, 1.0), 0.9)
	tw.parallel().tween_property(v, "modulate:a", 0.0, 0.9)
	tw.tween_callback(v.queue_free)


func dressed() -> void:
	FollowerArt.play("dress", 1.1, -6.0)
	squash(Vector2(1.2, 0.85), 0.07)
	FlockFx.specks(get_parent(), head_point(), FollowerArt.SPECK_SPARKLE, 4, 8.0)


## Run somewhere at 1.5x and kneel there, facing `face`.
func run_and_kneel(target: Vector2, face := Vector2.INF) -> void:
	busy = true
	var tw := walk_to(target, 1.6)
	await tw.finished
	if face != Vector2.INF and absf(face.x - position.x) > 6.0:
		_look = 1 if face.x > position.x else -1
		_glance_left = 8.0
	var k := create_tween()
	k.tween_property(self, "_squash", Vector2(1.2, 0.72), 0.12)
	await k.finished


## Chant for a while: wings up on the beat, spirit rising.
func chant(seconds: float) -> void:
	_chant_left = seconds
	_squash = Vector2.ONE
	var beats := int(seconds / BEAT)
	for i in beats:
		if not is_inside_tree():
			return
		if i % 2 == index % 2:
			FlockFx.spirit(get_parent(), head_point() + Vector2(randf_range(-4, 4), -4))
		await get_tree().create_timer(BEAT).timeout


func go_home() -> void:
	var tw := walk_to(home, 1.0)
	await tw.finished
	busy = false


# --- drawing --------------------------------------------------------------------------------------


func _draw() -> void:
	# A shadow on the floor, and after a pet or a meal, the five loyalty candles at the feet.
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, _width * 0.55, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
	if _shown_candles > 0.0 and kind != "cultist":
		var lit := int(data.get("loyalty", 0)) / 20
		for i in 5:
			var x := -8.0 + i * 4.0
			draw_rect(Rect2(x, 4, 2, 3), Palette.CREAM if i < lit else Color(Palette.MUTED, 0.5))
			if i < lit:
				draw_rect(Rect2(x, 2, 2, 2), Palette.GLOW)


func _physics_process(delta: float) -> void:
	if _shown_candles > 0.0:
		_shown_candles -= delta
		if _shown_candles <= 0.0:
			queue_redraw()
