class_name Leader
extends Node2D
## The player. Walks on a grid-checked map; position is the feet.
## The 0x72 wizard has weight: a soft shadow, footsteps that know the ground,
## dust on each step, a squash when he starts and stops, and a little hop on arrival.

const SPEED := 72.0
const FOOT := Rect2(-5, -4, 10, 4)
## The owner's 0x72 wizard (wizzard_m): 4 idle frames, then 4 run frames, 16x28 each.
const SHEET := preload("res://art/packs/0x72-dungeontileset-ii/0x72_DungeonTilesetII_v1.7/0x72_DungeonTilesetII_v1.7.png")
const IDLE := Vector2(128, 164)
const RUN := Vector2(192, 164)
const FRAME := Vector2(16, 28)
const IDLE_FPS := 6.0
const RUN_FPS := 10.0
const STEPS := "res://art/packs/kenney-impact-sounds/Audio/footstep_%s_%03d.ogg"

var is_walkable: Callable  # func(Rect2) -> bool, set by the level
## func(Vector2) -> String: "grass", "concrete", "wood" or "carpet" under the feet.
var surface_at: Callable
## Where a click or tap sent the leader. INF when not walking to a point.
var target := Vector2.INF
## Which way he is walking (zero when standing), for the camera's lead.
var walk_dir := Vector2.ZERO
signal arrived

var _stuck_t := 0.0

var _sprite := Sprite2D.new()
var _shadow := _Shadow.new()
var _running := false
var _anim_t := 0.0
var _last_frame := -1
var _step_i := 0
var _squash: Tween


## A soft dark pixel ellipse under the feet.
class _Shadow extends Node2D:
	func _draw() -> void:
		PixelDraw.ellipse(self, Vector2(0, -1), 6, 2, Color(0.04, 0.02, 0.06, 0.45))


func _ready() -> void:
	_shadow.show_behind_parent = true
	add_child(_shadow)
	_sprite.texture = SHEET
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(IDLE, FRAME)
	_sprite.offset = Vector2(0, -FRAME.y / 2.0)  # bottom of the frame on the feet
	add_child(_sprite)
	BookOverlay.dress_leader(self, _sprite)  # what the collection book put on (features/casino)


func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO if Game.busy else Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir != Vector2.ZERO:
		target = Vector2.INF
	elif target != Vector2.INF and not Game.busy:
		var to := target - position
		if to.length() < 2.0:
			target = Vector2.INF
			arrived.emit()
		else:
			dir = to.normalized()
	if dir != Vector2.ZERO:
		var before := position
		var step := dir * SPEED * delta
		_try_move(Vector2(step.x, 0))
		_try_move(Vector2(0, step.y))
		if target != Vector2.INF:
			# Walked into a wall on the way to a tap: stop there and count it as arrived.
			_stuck_t = _stuck_t + delta if position.distance_to(before) < 0.2 else 0.0
			if _stuck_t > 0.15:
				_stuck_t = 0.0
				target = Vector2.INF
				arrived.emit()
		if absf(dir.x) > 0.1:
			var flip := dir.x < 0
			if flip != _sprite.flip_h:
				_sprite.flip_h = flip
				_turn_squash()
	walk_dir = dir
	var running := dir != Vector2.ZERO
	if running != _running:
		_running = running
		_anim_t = 0.0
		_last_frame = -1
		if running:
			_squash_to(Vector2(0.9, 1.1), 0.05, Vector2.ONE, 0.08, Tween.TRANS_QUAD)
		else:
			_squash_to(Vector2(1.15, 0.88), 0.03, Vector2.ONE, 0.2, Tween.TRANS_ELASTIC)
			_dust(-walk_dir, 5)
	_anim_t += delta
	var frame := int(_anim_t * (RUN_FPS if _running else IDLE_FPS)) % 4
	_sprite.region_rect = Rect2((RUN if _running else IDLE) + Vector2(frame * FRAME.x, 0), FRAME)
	if _running and frame != _last_frame and (frame == 0 or frame == 2):
		_footstep(dir)
	_last_frame = frame


## Walk to a point (from a click or tap).
func walk_to(point: Vector2) -> void:
	target = point
	_stuck_t = 0.0


## A little hop, for arriving at something he was sent to.
func hop() -> void:
	# Squashed about the feet (the leader's origin), so the worn pieces come along.
	if _squash:
		_squash.kill()
	_squash = create_tween()
	_squash.tween_property(self, "scale", Vector2(0.92, 1.1), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_squash.tween_property(self, "scale", Vector2(1.12, 0.9), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_squash.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _try_move(step: Vector2) -> void:
	var target_pos := position + step
	if is_walkable.is_null() or is_walkable.call(Rect2(target_pos + FOOT.position, FOOT.size)):
		position = target_pos


func _squash_to(s: Vector2, t_in: float, back: Vector2, t_out: float, trans: Tween.TransitionType) -> void:
	if _squash:
		_squash.kill()
	_squash = create_tween()
	_squash.tween_property(self, "scale", s, t_in)
	_squash.tween_property(self, "scale", back, t_out).set_trans(trans).set_ease(Tween.EASE_OUT)


func _turn_squash() -> void:
	if _squash:
		_squash.kill()
	scale = Vector2(0.85, 1.0)
	_squash = create_tween()
	_squash.tween_interval(0.035)
	_squash.tween_property(self, "scale", Vector2.ONE, 0.06)


func _footstep(dir: Vector2) -> void:
	var surface := "grass"
	if surface_at.is_valid():
		surface = str(surface_at.call(position))
	_step_i = (_step_i + 1 + randi() % 3) % 5
	Sfx.play_path(STEPS % [surface, _step_i], randf_range(0.92, 1.08), -22.0)
	_dust(-dir, 3)


## A few muted pixels kicked up behind the feet.
func _dust(away: Vector2, count: int) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = count
	p.lifetime = 0.35 if count <= 3 else 0.45
	p.explosiveness = 0.9
	p.local_coords = false
	p.position = Vector2(0, -1)
	p.direction = away if away != Vector2.ZERO else Vector2.UP
	p.spread = 50.0 if count <= 3 else 160.0
	p.gravity = Vector2(0, -12)
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 14.0
	p.damping_min = 20.0
	p.damping_max = 30.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(Palette.MUTED, 0.5))
	ramp.set_color(1, Color(Palette.MUTED, 0.0))
	p.color_ramp = ramp
	p.z_index = -1
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
