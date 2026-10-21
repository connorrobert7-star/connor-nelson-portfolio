class_name VillageCultist
extends Node2D
## A nameless hooded cultist (DawnLike) who wanders the square, bobs, glances, hops
## when tapped and chants when money lands. Pure idle life: they never decide anything.

const SPEED := 18.0
const LOOKS := [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(0, 7), Vector2i(1, 7), Vector2i(2, 7), Vector2i(3, 7)]

var area := Rect2()  # where it wanders, in px
var is_walkable: Callable
var look := 0

var _body := Sprite2D.new()
var _frames: Array[Texture2D] = []
var _target := Vector2.INF
var _wait := 0.0
var _t := 0.0
var _busy := false


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
	_wait = randf_range(0.2, 3.0)
	_t = randf() * 2.0


func _process(delta: float) -> void:
	_t += delta
	_body.texture = _frames[int(_t * 2.5) % 2]
	if _busy:
		return
	if _target == Vector2.INF:
		_wait -= delta
		_body.position.y = sin(_t * 3.0) * 0.5
		if _wait <= 0.0:
			_pick()
		return
	var to := _target - position
	if to.length() < 1.5:
		_target = Vector2.INF
		_wait = randf_range(1.0, 4.5)
		if randf() < 0.3:
			_body.flip_h = not _body.flip_h
		return
	var step := to.normalized() * SPEED * delta
	var next := position + step
	if is_walkable.is_valid() and not is_walkable.call(Rect2(next + Vector2(-3, -2), Vector2(6, 2))):
		_target = Vector2.INF
		_wait = randf_range(0.5, 1.5)
		return
	position = next
	_body.flip_h = to.x < 0
	_body.position.y = -absf(sin(_t * 10.0)) * 1.5


func _pick() -> void:
	_target = Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))


## Tapped: a hop, a heart and a little noise.
func poke() -> void:
	if _busy:
		return
	_busy = true
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
