class_name CasinoRoomMachine
extends Node2D
## Base for the things you tap in the casino: each has one or more spots (where a tap
## lands, where the leader stands to use it, what it does), a pool of light under it that
## swells when it's in reach or under the pointer, and an idle loop so nothing sits still.
## Position is the machine's feet, so it y-sorts with the leader.

const Art := preload("res://features/casino/casino_room_art.gd")

## One tappable spot: {hit: Rect2 (local), stand: Vector2 (local), action: Callable, id: String}.
var spots: Array[Dictionary] = []
var focus := 0.0
var pool: Sprite2D
var halo: Sprite2D
var pool_alpha := 0.16
var t := 0.0
var _want := 0.0
var _poke: Tween


func add_spot(id: String, hit: Rect2, stand: Vector2, action: Callable) -> void:
	spots.append({"id": id, "hit": hit, "stand": stand, "action": action})


## A soft pool of light on the floor under the machine (drawn on the room's floor layer).
func make_pool(floor_layer: Node2D, at: Vector2, color: Color, radius: float, alpha := 0.16) -> void:
	pool_alpha = alpha
	pool = Art.glow(floor_layer, position + at, color, radius, alpha, 0.55)
	# A faint halo of the same light over the machine itself, brighter in reach.
	halo = Art.glow(self, Vector2(0, -radius * 0.9), color, radius * 1.1, 0.0)
	halo.z_index = 3


func want_focus(on: bool) -> void:
	_want = 1.0 if on else 0.0


func _process(delta: float) -> void:
	t += delta
	focus = move_toward(focus, _want, delta * 5.0)
	if pool:
		pool.modulate.a = pool_alpha * (1.0 + focus * 1.4) + sin(t * 2.1) * 0.015
	if halo:
		halo.modulate.a = 0.04 + focus * 0.10 + sin(t * 1.7) * 0.01
	idle(delta)


## Every frame: the machine's idle loop.
func idle(_delta: float) -> void:
	pass


## Every state change: redraw counts and loads from state.casino.
func dress(_casino: Dictionary) -> void:
	pass


## Tapped: a quick squash so it answers the finger.
func poke() -> void:
	if _poke:
		_poke.kill()
	scale = Vector2(1.08, 0.92)
	_poke = create_tween()
	_poke.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
