class_name VillageCultist
extends Node2D
## A nameless hooded cultist (DawnLike) who lives on the square: wanders, sits, kneels toward
## the shrine fire, pairs up to talk (bobbing in turns, an emote now and then), turns to watch
## the leader go by and scatters when he runs through, then drifts back. Hops when tapped and
## chants when money lands. Each carries a torch: a small pool of light walks with them and
## rims their hood. Pure idle life: they never decide anything.

const SPEED := 18.0
const LOOKS := [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(0, 7), Vector2i(1, 7), Vector2i(2, 7), Vector2i(3, 7)]
const EMOTES := "kenney-emotes-pack/Tilesheets/pixel_style1.png"
## Talk emotes: [col, row] on the sheet (dots, heart, note, smile, haha, sparkles, question).
const TALK := [[1, 0], [2, 0], [4, 0], [9, 1], [3, 1], [8, 2], [8, 1], [9, 0]]
const WATCH := 40.0
const SCATTER := 20.0

var area := Rect2()  # where it wanders, in px
var is_walkable: Callable
var look := 0
var leader: Node2D
var shrine := Vector2.INF  # where the shrine fire burns (they kneel toward it)
var crowd: Array = []  # the other cultists (to pair up with)
var light: Node2D  # the torch's pool on the ground, owned by the village

var _body := Sprite2D.new()
var _rim: Sprite2D
var _frames: Array[Texture2D] = []
var _target := Vector2.INF
var _wait := 0.0
var _t := 0.0
var _busy := false
var _pose := ""  # "", "sit", "kneel", "talk"
var _mate: VillageCultist
var _emote_in := 0.0
var _speed := SPEED
var _last_leader := Vector2.INF


func _ready() -> void:
	var cell: Vector2i = LOOKS[look % LOOKS.size()]
	var rect := Rect2(cell.x * 16, cell.y * 16, 16, 16)
	_frames = [VillageArt.tex(VillageArt.HOODED_A, rect), VillageArt.tex(VillageArt.HOODED_B, rect)]
	var shadow := VillageArt.glow(self, Vector2(0, -1), Color(0, 0, 0, 0.5), 14)
	shadow.material = null
	shadow.scale.y *= 0.4
	_body.texture = _frames[0]
	_body.offset = Vector2(0, -8)
	add_child(_body)
	# The torch rims the hood on its side.
	_rim = VillageArt.pool(_body, Vector2(5, -14), Color(1.0, 0.62, 0.3, 0.55), 14, 0.3)
	_wait = randf_range(0.2, 3.0)
	_t = randf() * 2.0
	_emote_in = randf_range(8.0, 15.0)


func _exit_tree() -> void:
	if is_instance_valid(light):
		light.queue_free()


func _process(delta: float) -> void:
	_t += delta
	_body.texture = _frames[int(_t * 2.5) % 2]
	_rim.position.x = -5.0 if _body.flip_h else 5.0
	if is_instance_valid(light):
		light.position = position + Vector2(_rim.position.x, -5)
	if _busy:
		return
	if _react(delta):
		return
	if _target == Vector2.INF:
		_wait -= delta
		_idle(delta)
		if _wait <= 0.0:
			_stand_up()
			_pick()
		return
	var to := _target - position
	if to.length() < 1.5:
		_target = Vector2.INF
		_speed = SPEED
		_wait = randf_range(1.5, 6.0)
		_choose_pose()
		return
	var step := to.normalized() * _speed * delta
	var next := position + step
	if is_walkable.is_valid() and not is_walkable.call(Rect2(next + Vector2(-3, -2), Vector2(6, 2))):
		_target = Vector2.INF
		_speed = SPEED
		_wait = randf_range(0.5, 1.5)
		return
	position = next
	_body.flip_h = to.x < 0
	_body.position.y = -absf(sin(_t * (10.0 if _speed <= SPEED else 18.0))) * 1.5


## The leader nearby: running through scatters them; walking past, they turn to watch.
func _react(delta: float) -> bool:
	if leader == null or not is_instance_valid(leader):
		return false
	var lp := leader.position
	var moved := 0.0 if _last_leader == Vector2.INF else lp.distance_to(_last_leader) / maxf(delta, 0.001)
	_last_leader = lp
	var d := position.distance_to(lp)
	if d < SCATTER and moved > 30.0 and _speed <= SPEED:
		_stand_up()
		var away := (position - lp).normalized()
		if away == Vector2.ZERO:
			away = Vector2.RIGHT
		_target = (position + away * randf_range(22.0, 32.0)).clamp(area.position, area.end)
		_speed = SPEED * 3.0
		VillageArt.squash(_body, Vector2(0.8, 1.2), 0.15)
		return false
	if d < WATCH and _target == Vector2.INF and _pose != "kneel":
		_body.flip_h = lp.x < position.x
	return false


func _choose_pose() -> void:
	var r := randf()
	if r < 0.22:
		_pose = "sit"
		_wait += 3.0
		var tw := create_tween()
		tw.tween_property(_body, "scale", Vector2(1.08, 0.82), 0.18).set_trans(Tween.TRANS_BACK)
	elif r < 0.38 and shrine != Vector2.INF:
		_pose = "kneel"
		_wait += 4.0
		_body.flip_h = shrine.x < position.x
		var tw := create_tween()
		tw.tween_property(_body, "scale", Vector2(1.0, 0.9), 0.2)
	elif r < 0.7:
		_mate = _find_mate()
		if _mate:
			_pose = "talk"
			_wait += 6.0
			_body.flip_h = _mate.position.x < position.x
			_mate._listen(self, _wait)
	else:
		_pose = ""


func _find_mate() -> VillageCultist:
	for c: Variant in crowd:
		if c == self or not is_instance_valid(c):
			continue
		var o := c as VillageCultist
		if o._target == Vector2.INF and o._pose == "" and not o._busy and o.position.distance_to(position) < 30.0:
			return o
	return null


## Another cultist starts talking to this one: stop and face them.
func _listen(other: VillageCultist, seconds: float) -> void:
	_target = Vector2.INF
	_pose = "talk"
	_mate = other
	_wait = seconds
	_body.flip_h = other.position.x < position.x


func _idle(delta: float) -> void:
	match _pose:
		"sit":
			_body.position.y = 1.0
		"kneel":
			# A slow bow toward the fire.
			var bow := maxf(0.0, sin(_t * 1.2))
			_body.position.y = 1.0 + bow
			_body.rotation = bow * 0.12 * (-1.0 if _body.flip_h else 1.0)
		"talk":
			# Bob in turns with the one they're talking to.
			var mine := int(_t * 1.6 + (0.0 if look % 2 else 0.5)) % 2 == 0
			_body.position.y = -1.0 if mine else 0.0
			_emote_in -= delta
			if _emote_in <= 0.0:
				_emote_in = randf_range(8.0, 15.0)
				var e: Array = TALK[randi() % TALK.size()]
				_bubble(Rect2(e[0] * 16, e[1] * 16, 16, 16))
		_:
			_body.position.y = sin(_t * 3.0) * 0.5


func _stand_up() -> void:
	if _pose == "":
		return
	_pose = ""
	_mate = null
	_body.rotation = 0.0
	var tw := create_tween()
	tw.tween_property(_body, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK)


func _pick() -> void:
	_target = Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))


## Tapped: a hop, a heart and a little noise.
func poke() -> void:
	if _busy:
		return
	_busy = true
	_stand_up()
	var tw := create_tween()
	tw.tween_property(_body, "position:y", -7.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_body, "position:y", 0.0, 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	VillageArt.squash(_body, Vector2(1.3, 0.75), 0.2)
	_speck(Rect2(80, 0, 8, 8))
	VillageArt.sfx("ninja-adventure/Audio/Sounds/Voice/Voice%d.ogg" % (1 + look % 10), randf_range(1.2, 1.5), -10)
	await tw.finished
	_busy = false


## Money landed somewhere: everyone hops and a spirit rises from them.
func chant(delay := 0.0) -> void:
	await VillageArt.wait(self, delay)
	_busy = true
	_stand_up()
	for i in 2:
		var tw := create_tween()
		tw.tween_property(_body, "position:y", -5.0, 0.12)
		tw.tween_property(_body, "position:y", 0.0, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		await tw.finished
	var spirit := VillageArt.anim(self, VillageArt.frames(VillageArt.SPIRIT, Vector2i(32, 32), 5, 10), Vector2(0, -14), false)
	spirit.material = VillageArt.additive()
	spirit.modulate = Color(VillageArt.BONE, 0.8)
	var up := spirit.create_tween()
	up.tween_property(spirit, "position:y", -40.0, 1.2)
	up.parallel().tween_property(spirit, "modulate:a", 0.0, 1.2)
	up.tween_callback(spirit.queue_free)
	_busy = false


## Stop and look at something for a moment (a new stage, a restored ruin).
func stare_at(point: Vector2, seconds := 1.5) -> void:
	_stand_up()
	_target = Vector2.INF
	_wait = seconds
	_body.flip_h = point.x < global_position.x
	_speck(Rect2(16, 0, 8, 8))


func _speck(rect: Rect2) -> void:
	var s := Sprite2D.new()
	s.texture = VillageArt.tex(VillageArt.SPECKS, rect)
	s.position = Vector2(0, -20)
	add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "position:y", -30.0, 0.6)
	tw.parallel().tween_property(s, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tw.tween_callback(s.queue_free)


## A little speech bubble from the emotes pack: pops in, holds, fades.
func _bubble(rect: Rect2) -> void:
	var s := Sprite2D.new()
	s.texture = VillageArt.tex(VillageArt.PACKS + EMOTES, rect)
	s.position = Vector2(0, -24)
	s.z_index = 6
	s.scale = Vector2(0.4, 0.4)
	add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.4)
	tw.tween_property(s, "modulate:a", 0.0, 0.3)
	tw.tween_callback(s.queue_free)
