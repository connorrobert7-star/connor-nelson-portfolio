class_name Flock
extends Node2D
## The flock, placeable in any level:
##   var flock := Flock.new("all", Rect2(96, 96, 288, 136)); level.props.add_child(flock)
## It keeps one FollowerBody per follower in Game.state.followers, laid out inside `area`,
## and keeps them alive between state changes. On money landing (a money_moved event into an
## own account or a debt, never a stock buy) they run to `shrine_point`, kneel and chant.
## When `interactive`, a tap pets a follower, and food or clothes carried with carry() drop
## onto whoever is under the finger.
##
## Filters: "all", "named" (personal + holdings), "personal", "holdings", "cultists".

signal fed(body: FollowerBody, result: Dictionary)
signal refused(body: FollowerBody, reason: String)
signal dressed(body: FollowerBody, item_id: String)
signal naming_wanted(body: FollowerBody)

const OWN := ["sav_1", "sav_2", "brk_1"]
const MAX_CULTISTS := 12
const CHANT_BARS := 2

## What a session has already seen of each follower (stage, hatched, veiled, level), so a
## hatch or a growth that happened elsewhere still plays the first time it's seen here.
static var seen: Dictionary = {}

var filter := "all"
var area := Rect2(0, 0, 160, 80)
## Where they run to chant. Defaults to the middle of the area's top edge.
var shrine_point := Vector2.INF
## Rects for the nameless cultists (risers). Defaults to the top band of the area.
var riser_rects: Array[Rect2] = []
var interactive := true
var max_cultists := MAX_CULTISTS
## thing -> Array of Vector2: what each follower's hidden favorite thing looks like here.
var interests: Dictionary = {}

var bodies: Dictionary = {}  # fid -> FollowerBody
var celebrating := false

var _carry: Dictionary = {}
var _hovered: FollowerBody
var _chant_in := randf_range(3.0, 6.0)
var _layout_key := ""


func _init(which := "all", rect := Rect2(0, 0, 160, 80)) -> void:
	filter = which
	area = rect
	y_sort_enabled = true


func _ready() -> void:
	if shrine_point == Vector2.INF:
		shrine_point = Vector2(area.get_center().x, area.position.y + 8)
	Game.state_changed.connect(_sync)
	Game.event_fired.connect(_on_event)
	if not Game.state.is_empty():
		_sync()


## Where a follower whose favorite is `thing` keeps glancing, or INF.
func interest_point(thing: String) -> Vector2:
	var points: Array = interests.get(thing, [])
	return points.pick_random() if not points.is_empty() else Vector2.INF


func add_interest(thing: String, point: Vector2) -> void:
	if not interests.has(thing):
		interests[thing] = []
	(interests[thing] as Array).append(point)


# --- keeping the bodies in step with /state ---------------------------------------------------------


func _wanted() -> Array[Dictionary]:
	var f: Dictionary = Game.state.get("followers", {})
	var out: Array[Dictionary] = []
	if f.is_empty():
		return out
	if filter in ["all", "named", "personal"]:
		out.append({"kind": "personal", "fid": "personal", "data": f.personal})
	if filter in ["all", "named", "holdings"]:
		for h: Dictionary in f.get("holdings", []):
			out.append({"kind": "holding", "fid": str(h.id), "data": h})
	if filter in ["all", "cultists"]:
		var n := mini(int(f.get("cultists", 0)), max_cultists)
		for i in n:
			var d := {
				"id": "cultist_%d" % i,
				"pose": f.get("cultist_pose", "idle"),
				"bubble": f.get("cultist_bubble", "") if i % 3 == 0 else "",
				"veiled": f.get("mourning", false) or f.get("faith", {}).get("band", "") == "mourning",
				"hungry": "hungry" in f.get("reactions", []),
			}
			out.append({"kind": "cultist", "fid": d.id, "data": d})
	return out


func _sync() -> void:
	var f: Dictionary = Game.state.get("followers", {})
	if f.is_empty():
		return
	var band := str(f.get("faith", {}).get("band", "content"))
	var wanted := _wanted()
	var ids := {}
	for w: Dictionary in wanted:
		ids[w.fid] = true
	for fid: String in bodies.keys():
		if not ids.has(fid):
			var gone: FollowerBody = bodies[fid]
			bodies.erase(fid)
			var tw := gone.create_tween()
			tw.tween_property(gone, "modulate:a", 0.0, 0.3)
			tw.tween_callback(gone.queue_free)
	var fresh := false
	for i in wanted.size():
		var w: Dictionary = wanted[i]
		var b: FollowerBody = bodies.get(w.fid)
		if b == null:
			b = FollowerBody.new(w.kind, w.fid, area.get_center())
			b.flock = self
			b.index = i
			if w.kind == "holding":
				b.px = px_for(w.data)
			bodies[w.fid] = b
			add_child(b)
			fresh = true
		elif w.kind == "holding" and b.px != px_for(w.data):
			_resize(b, px_for(w.data))
		_react_to_change(b, w.data)
		b.apply(w.data, f, band)
	var key := ",".join(PackedStringArray(bodies.keys())) + str(f.get("giant")) + str(f.personal.get("hatched"))
	if fresh or key != _layout_key:
		_layout_key = key
		_layout(fresh)
	_stares(f)


## Pixel scale for a holding: 16px creatures at whole-number sizes (1x to 3x across the
## backend's 0.7 to 1.52 scale), and the 40% giant at 5x.
static func px_for(d: Dictionary) -> int:
	if bool(d.get("giant", false)):
		return 5
	var n := (float(d.get("scale", 1.0)) - 0.7) / 0.82
	return clampi(1 + roundi(n * 2.0), 1, 3)


## Holdings resize once a week, quietly: one slow tween, no sound.
func _resize(b: FollowerBody, to_px: int) -> void:
	b.px = to_px
	b.resizing = true
	var tw := b.create_tween()
	tw.tween_property(b.body, "scale", Vector2(to_px, to_px), 1.5).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void: b.resizing = false)


## Diff against what this session last saw: a hatch, a growth, a veil coming off, a level.
func _react_to_change(b: FollowerBody, d: Dictionary) -> void:
	var before: Dictionary = seen.get(b.fid, {})
	var now := {
		"stage": int(d.get("stage", 0)),
		"hatched": bool(d.get("hatched", true)),
		"veiled": bool(d.get("veiled", false)),
		"level": int(d.get("level", 1)),
	}
	seen[b.fid] = now
	if before.is_empty() or not b.is_inside_tree():
		return
	if b.kind == "personal" and not bool(before.hatched) and bool(now.hatched):
		_hatch(b)
	elif b.kind == "personal" and int(now.stage) > int(before.stage):
		b.grow.call_deferred(int(now.stage))
	if bool(before.veiled) and not bool(now.veiled):
		b.unveil.call_deferred()
	if int(now.level) > int(before.level):
		b.level_up.call_deferred()


func _hatch(b: FollowerBody) -> void:
	await get_tree().process_frame
	await b.hatch()
	if not bool(b.data.get("named", false)):
		naming_wanted.emit(b)


func _layout(snap: bool) -> void:
	var named: Array[FollowerBody] = []
	var cultists: Array[FollowerBody] = []
	var giant: FollowerBody
	for b: FollowerBody in bodies.values():
		if b.kind == "cultist":
			cultists.append(b)
		else:
			named.append(b)
			if bool(b.data.get("giant", false)):
				giant = b
	var c := area.get_center()
	var homes: Dictionary = {}
	# Holdings stand on a ring around the middle, leaving the front open; the 40% giant takes
	# the middle and the rest keep their distance.
	var holdings: Array = named.filter(func(b: FollowerBody) -> bool: return b.kind == "holding")
	var personal: Array = named.filter(func(b: FollowerBody) -> bool: return b.kind == "personal")
	var giant_room := 0.0
	if giant:
		homes[giant] = c + Vector2(0, 6)
		giant_room = giant.px * 8.0 + 22.0
	var others: Array = holdings.filter(func(b: FollowerBody) -> bool: return b != giant)
	var rx := area.size.x * 0.47
	var ry := area.size.y * 0.42
	var ring_c := c + Vector2(0, 8)
	# Biggest first, alternating left and right from the front; the smallest end up at the back.
	var slots: Array[float] = []
	for i in others.size():
		var t := (i + 0.5) / maxf(1.0, others.size())
		slots.append(deg_to_rad(lerpf(150.0, 390.0, t)))
	var order: Array[int] = []
	var lo := 0
	var hi := others.size() - 1
	while lo <= hi:
		order.append(lo)
		if hi != lo:
			order.append(hi)
		lo += 1
		hi -= 1
	for k in others.size():
		var ang: float = slots[order[k]]
		var p := ring_c + Vector2(cos(ang) * rx, sin(ang) * ry)
		p.y = maxf(p.y, area.position.y + 34.0)  # keep the back of the ring off the altar
		if giant and p.distance_to(homes[giant]) < giant_room:
			p = homes[giant] + (p - homes[giant]).normalized() * giant_room
		homes[others[k]] = p
	# The personal follower: the egg waits in the middle of the circle; once hatched it
	# stands at the front, nearest you.
	for b: FollowerBody in personal:
		var front := Vector2(c.x, area.end.y - 30.0)
		homes[b] = (c + Vector2(0, 10)) if b.egg and giant == null else front
	# Cultists fill the risers in rows.
	var risers: Array = riser_rects if not riser_rects.is_empty() else [Rect2(area.position, Vector2(area.size.x, minf(36.0, area.size.y)))]
	var per := ceili(float(cultists.size()) / maxf(1.0, risers.size()))
	for i in cultists.size():
		var r: Rect2 = risers[mini(i / maxi(1, per), risers.size() - 1)]
		var j := i % maxi(1, per)
		var cols := maxi(1, int(r.size.x / 18.0))
		var row := j / cols
		var col := j % cols
		var x := r.position.x + 9.0 + col * (r.size.x - 18.0) / maxf(1.0, cols - 1) + (5.0 if row % 2 else 0.0)
		homes[cultists[i]] = Vector2(x, r.position.y + 14.0 + row * 14.0)
	for b: FollowerBody in homes:
		var h: Vector2 = homes[b]
		h += Vector2(sin(b.index * 12.9898) * 3.0, cos(b.index * 78.233) * 2.0)
		b.home = h
		if snap or b.position == area.get_center():
			b.position = h
			FlockFx.pop_in(b.rig)
		elif not b.busy:
			b.walk_to(h)


func _stares(f: Dictionary) -> void:
	var giant_id := "hold_%s" % str(f.get("giant")) if f.get("giant") != null else ""
	var g: FollowerBody = bodies.get(giant_id)
	for b: FollowerBody in bodies.values():
		var staring := g != null and b != g and (b.kind != "cultist" or b.index % 2 == 0)
		b.stare_at = g.position if staring else Vector2.INF
		if staring and b.kind != "cultist" and b.bubble_name == "":
			b.bubble_name = "sweat"


# --- money lands: run to the shrine, kneel, chant -------------------------------------------------------


func _on_event(e: Dictionary) -> void:
	match str(e.get("kind", "")):
		"money_moved":
			if lands(e):
				celebrate()


## Money that landed in an own account or paid a debt. A stock pick at the counter never counts.
static func lands(e: Dictionary) -> bool:
	var to := str(e.get("to_account", ""))
	if str(e.get("reason", "")).begins_with("Shop: buy"):
		return false
	return to in OWN or to.begins_with("debt_")


func celebrate() -> void:
	if celebrating or not is_inside_tree() or bodies.is_empty():
		return
	celebrating = true
	var lvl := _level()
	FlockFx.hit_stop(get_tree(), 0.08)
	if lvl and lvl.main:
		lvl.main.shake(2.0, 0.12)
	FollowerArt.play("bell", 1.0, -4.0)
	for p in [0.97, 1.0, 1.04]:
		FollowerArt.play("chant", p, -6.0)
	FlockFx.ring(self, shrine_point, Palette.CREAM, 60.0, 0.6)
	var order: Array = bodies.values()
	order.sort_custom(func(a: FollowerBody, b: FollowerBody) -> bool:
		return a.position.distance_to(shrine_point) < b.position.distance_to(shrine_point))
	var seconds := CHANT_BARS * 4 * FollowerBody.BEAT
	for i in order.size():
		var b: FollowerBody = order[i]
		var slot := _kneel_slot(i, order.size())
		_kneel_and_chant(b, slot, i * 0.06, seconds)
	await get_tree().create_timer(seconds + 1.4).timeout
	celebrating = false


## Kneeling places in a ring around the shrine point, open at the back toward the altar.
func _kneel_slot(i: int, n: int) -> Vector2:
	var inner := mini(n, 10)
	var ring := 0 if i < inner else 1
	var k := i if ring == 0 else i - inner
	var count := inner if ring == 0 else maxi(1, n - inner)
	var ang := deg_to_rad(lerpf(-40.0, 220.0, (k + 0.5) / count))
	var r := Vector2(78.0, 38.0) if ring == 0 else Vector2(118.0, 56.0)
	return shrine_point + Vector2(cos(ang) * r.x, sin(ang) * r.y)


func _kneel_and_chant(b: FollowerBody, slot: Vector2, delay: float, seconds: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(b):
		return
	b.unveil()
	if b.egg:
		b.pet(true)
		return
	await b.run_and_kneel(slot, shrine_point)
	if not is_instance_valid(b):
		return
	b.squash(Vector2.ONE, 0.1)
	await b.chant(seconds)
	if is_instance_valid(b):
		b.go_home()


func _level() -> Level:
	var n := get_parent()
	while n and not (n is Level):
		n = n.get_parent()
	return n as Level


# --- taps, and carrying food or clothes ------------------------------------------------------------------


## The follower under a point; where bodies overlap, the one whose middle is nearest.
func body_at(point: Vector2, named_only := false) -> FollowerBody:
	var best: FollowerBody
	var best_d := INF
	for b: FollowerBody in bodies.values():
		if named_only and b.kind == "cultist":
			continue
		var r := b.hit_rect()
		if r.has_point(point) and r.get_center().distance_to(point) < best_d:
			best_d = r.get_center().distance_to(point)
			best = b
	return best


func carrying() -> bool:
	return not _carry.is_empty()


## Pick something up: it sticks to the finger. A drag drops it where it's let go; a quick tap
## leaves it stuck to the cursor until the next tap.
func carry(what: String, payload: Dictionary, texture: Texture2D, from: Vector2) -> void:
	cancel_carry()
	var s := Sprite2D.new()
	s.texture = texture
	s.position = from
	s.z_index = 90
	var under := FollowerArt.glow(Color(Palette.CREAM, 0.5), 10.0)
	under.z_index = -1
	s.add_child(under)
	add_child(s)
	FlockFx.pop_in(s, Vector2.ONE * 1.25)
	FollowerArt.play("pop", 1.2, -8.0)
	_carry = {"what": what, "payload": payload, "sprite": s, "from": from, "press": from, "dragging": true, "t": 0.0}


func cancel_carry() -> void:
	if _carry.is_empty():
		return
	var s: Sprite2D = _carry.sprite
	var from: Vector2 = _carry.from
	_carry = {}
	_set_hover(null)
	var tw := s.create_tween()
	tw.tween_property(s, "position", from, 0.18).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(s, "modulate:a", 0.0, 0.18)
	tw.tween_callback(s.queue_free)


func _process(delta: float) -> void:
	if not _carry.is_empty():
		_carry.t = float(_carry.t) + delta
		var s: Sprite2D = _carry.sprite
		s.offset.y = sin(float(_carry.t) * 8.0)
	_ambient_chant(delta)


## The flock's voices: often at Fervent, rarely when doubting, a slow dirge in grief.
func _ambient_chant(delta: float) -> void:
	if bodies.is_empty() or celebrating or not is_visible_in_tree():
		return
	_chant_in -= delta
	if _chant_in > 0.0:
		return
	var f: Dictionary = Game.state.get("followers", {})
	var band := str(f.get("faith", {}).get("band", "content"))
	var mourning := bool(f.get("mourning", false)) or band == "mourning"
	match band:
		"fervent":
			_chant_in = randf_range(5.0, 9.0)
			FollowerArt.play("chant", randf_range(0.98, 1.05), -12.0)
		"content":
			_chant_in = randf_range(9.0, 15.0)
			FollowerArt.play("chant", randf_range(0.94, 1.0), -16.0)
		_:
			_chant_in = randf_range(14.0, 22.0)
			FollowerArt.play("chant", 0.62 if mourning else 0.8, -16.0)


func _unhandled_input(event: InputEvent) -> void:
	if Game.busy or not is_visible_in_tree():
		return
	if event is InputEventMouseMotion and not _carry.is_empty():
		var p := (make_input_local(event) as InputEventMouseMotion).position
		(_carry.sprite as Sprite2D).position = p
		_set_hover(body_at(p, true))
		return
	if not (event is InputEventMouseButton) or (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	var mb := make_input_local(event) as InputEventMouseButton
	var p := mb.position
	if not _carry.is_empty():
		if mb.pressed and not bool(_carry.dragging):
			get_viewport().set_input_as_handled()
			_drop(p)
		elif not mb.pressed and bool(_carry.dragging):
			get_viewport().set_input_as_handled()
			if p.distance_to(_carry.press) > 6.0:
				_drop(p)
			else:
				_carry.dragging = false  # a tap: it stays stuck to the cursor
		return
	if not mb.pressed or not interactive:
		return
	var b := body_at(p)
	if b:
		get_viewport().set_input_as_handled()
		tap(b)


func _set_hover(b: FollowerBody) -> void:
	if b == _hovered:
		return
	if is_instance_valid(_hovered):
		_hovered.hover(false)
	_hovered = b
	if b:
		b.hover(true)


## A tap on a follower: pet it (the egg only wobbles; a nameless hatchling asks for its name).
func tap(b: FollowerBody) -> void:
	if b.kind == "personal" and b.egg:
		b.pet(false)
		return
	if b.kind == "personal" and not bool(b.data.get("named", false)):
		b.pet(false)
		naming_wanted.emit(b)
		return
	if b.kind == "cultist":
		b.pet(false)
		return
	b.pet(not bool(b.data.get("petted_today", false)))
	var res: Array = await Game.call_api("POST", "/followers/pet", {"follower_id": b.fid})
	if res[1] != "":
		return
	var out: Dictionary = res[0]
	if int(out.get("gained", 0)) > 0:
		_devotion_spark(b)
	await Game.refresh()


## A brass spark flies from the follower to the altar: loyalty piling up as devotion.
func _devotion_spark(b: FollowerBody) -> void:
	var s := Sprite2D.new()
	s.texture = FollowerArt.coin(0)
	s.position = b.head_point()
	s.z_index = 85
	add_child(s)
	var from := s.position
	var to := shrine_point
	var mid := (from + to) / 2.0 + Vector2(0, -40)
	var tw := s.create_tween()
	tw.tween_method(func(t: float) -> void:
		if is_instance_valid(s):
			s.position = from.lerp(mid, t).lerp(mid.lerp(to, t), t)
			s.texture = FollowerArt.coin(int(t * 17.0)), 0.0, 1.0, 0.6).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		FollowerArt.play("coin", randf_range(1.0, 1.3), -12.0)
		FlockFx.specks(self, to, FollowerArt.SPECK_SPARKLE, 2, 6.0, Palette.GLOW))
	tw.tween_callback(s.queue_free)


func _drop(p: Vector2) -> void:
	var c := _carry
	_carry = {}
	_set_hover(null)
	var b := body_at(p, true)
	var s: Sprite2D = c.sprite
	if b == null:
		_carry = c
		cancel_carry()
		return
	if c.what == "food":
		await _feed(b, c.payload, s, c.from)
	else:
		await _dress(b, c.payload, s, c.from)


func _fly_to_mouth(s: Sprite2D, b: FollowerBody) -> void:
	var from := s.position
	var to := b.head_point() + Vector2(0, b.height() * 0.15)
	var mid := (from + to) / 2.0 + Vector2(0, -10)
	var tw := s.create_tween()
	tw.tween_method(func(t: float) -> void:
		if is_instance_valid(s):
			s.position = from.lerp(mid, t).lerp(mid.lerp(to, t), t), 0.0, 1.0, 0.14)
	await tw.finished


func _feed(b: FollowerBody, food: Dictionary, s: Sprite2D, from: Vector2) -> void:
	if b.egg:
		b.refuse()
		_return(s, from)
		refused.emit(b, "egg")
		return
	b.squash(Vector2(1.1, 1.15), 0.08)  # mouth open, anticipation
	var food_id := str(food.get("id", "gruel"))
	if food_id == "favorite":
		s.texture = FollowerArt.icon(b.data.get("favorite_food", {}).get("icon", {}))
	var res: Array = await Game.call_api("POST", "/followers/feed", {"follower_id": b.fid, "food": food_id})
	if res[1] != "":
		b.refuse()
		_return(s, from)
		refused.emit(b, "coins")
		return
	var out: Dictionary = res[0]
	if bool(out.get("full", false)):
		b.refuse()
		_return(s, from)
		refused.emit(b, "full")
		return
	await _fly_to_mouth(s, b)
	s.queue_free()
	fed.emit(b, out)
	b.eat(food_id == "favorite")
	await Game.refresh()


func _dress(b: FollowerBody, item: Dictionary, s: Sprite2D, from: Vector2) -> void:
	var res: Array = await Game.call_api("POST", "/followers/dress", {"follower_id": b.fid, "item_id": str(item.get("id", ""))})
	if res[1] != "":
		b.refuse()
		_return(s, from)
		return
	var tw := s.create_tween()
	tw.tween_property(s, "position", b.head_point(), 0.14)
	tw.tween_callback(s.queue_free)
	await tw.finished
	b.dressed()
	dressed.emit(b, str(item.get("id", "")))
	await Game.refresh()


func _return(s: Sprite2D, from: Vector2) -> void:
	var tw := s.create_tween()
	tw.tween_property(s, "position", from + Vector2(0, -6), 0.22).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(s, "modulate:a", 0.0, 0.3)
	tw.tween_callback(s.queue_free)
