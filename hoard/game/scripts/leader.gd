class_name Leader
extends Node2D
## The player. Walks on a grid-checked map; position is the feet.

const SPEED := 72.0
const FOOT := Rect2(-5, -4, 10, 4)
## The owner's 0x72 wizard (wizzard_m): 4 idle frames, then 4 run frames, 16x28 each.
const SHEET := preload("res://art/packs/0x72-dungeontileset-ii/0x72_DungeonTilesetII_v1.7/0x72_DungeonTilesetII_v1.7.png")
const IDLE := Vector2(128, 164)
const RUN := Vector2(192, 164)
const FRAME := Vector2(16, 28)
const IDLE_FPS := 6.0
const RUN_FPS := 10.0

var is_walkable: Callable  # func(Rect2) -> bool, set by the level
## Where a click or tap sent the leader. INF when not walking to a point.
var target := Vector2.INF
signal arrived

var _stuck_t := 0.0

var _sprite := Sprite2D.new()
var _running := false
var _anim_t := 0.0


func _ready() -> void:
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
			_sprite.flip_h = dir.x < 0
	var running := dir != Vector2.ZERO
	if running != _running:
		_running = running
		_anim_t = 0.0
	_anim_t += delta
	var frame := int(_anim_t * (RUN_FPS if _running else IDLE_FPS)) % 4
	_sprite.region_rect = Rect2((RUN if _running else IDLE) + Vector2(frame * FRAME.x, 0), FRAME)


## Walk to a point (from a click or tap).
func walk_to(point: Vector2) -> void:
	target = point
	_stuck_t = 0.0


func _try_move(step: Vector2) -> void:
	var target := position + step
	if is_walkable.is_null() or is_walkable.call(Rect2(target + FOOT.position, FOOT.size)):
		position = target
