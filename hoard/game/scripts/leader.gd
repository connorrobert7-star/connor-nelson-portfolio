class_name Leader
extends Node2D
## The player. Walks on a grid-checked map; position is the feet.

const SPEED := 72.0
const FOOT := Rect2(-5, -4, 10, 4)

var is_walkable: Callable  # func(Rect2) -> bool, set by the level
## Where a click or tap sent the leader. INF when not walking to a point.
var target := Vector2.INF
signal arrived

var _stuck_t := 0.0

var _sprite := Sprite2D.new()
var _facing := 0  # 0 down, 1 up, 2 side
var _anim_t := 0.0


func _ready() -> void:
	_sprite.texture = preload("res://art/leader.png")
	_sprite.hframes = 6
	_sprite.offset = Vector2(0, -14)
	add_child(_sprite)


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
		if absf(dir.x) > absf(dir.y):
			_facing = 2
			_sprite.flip_h = dir.x < 0
		else:
			_facing = 1 if dir.y < 0 else 0
		_anim_t += delta
	else:
		_anim_t = 0.0
	_sprite.frame = _facing * 2 + (int(_anim_t * 6.0) % 2)


## Walk to a point (from a click or tap).
func walk_to(point: Vector2) -> void:
	target = point
	_stuck_t = 0.0


func _try_move(step: Vector2) -> void:
	var target := position + step
	if is_walkable.is_null() or is_walkable.call(Rect2(target + FOOT.position, FOOT.size)):
		position = target
