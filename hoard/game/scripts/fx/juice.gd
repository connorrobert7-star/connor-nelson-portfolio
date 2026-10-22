class_name Juice
extends Node
## The one shared juice kit every lane calls, so a shake, a hit-stop or a count-up
## feels the same everywhere:
##   Juice.shake(0.4)                      trauma, capped at 1, decays on its own
##   Juice.kick(Vector2.LEFT, 3)           a directional knock of the camera
##   Juice.hit_stop(0.06)                  re-entrant, real time
##   Juice.count_up(label, 0, 50, "%d")    numbers roll to where they land
##   Juice.pop(node)                       squash and spring back
## It lives on its own node under the root, made the first time it is needed.

const SHAKE_PX := 4.0
const TRAUMA_DECAY := 1.8
const SHAKE_HZ := 28.0

static var _node: Juice

var trauma := 0.0
var _kick := Vector2.ZERO
var _t := 0.0
var _stop_end := 0.0  # seconds since start (real time) when the hit-stop lets go
var _stop_scale := 1.0
var _driving := false  # true while this node owns the camera offset
var _noise := FastNoiseLite.new()


static func _kit() -> Juice:
	if _node == null or not is_instance_valid(_node):
		_node = Juice.new()
		_node.name = "Juice"
		_node.process_mode = Node.PROCESS_MODE_ALWAYS
		var root := (Engine.get_main_loop() as SceneTree).root
		root.add_child.call_deferred(_node)
	return _node


func _init() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.seed = 7


# --- camera ------------------------------------------------------------------------

## Add trauma (0..1). Offset is 4px * trauma^2, so small hits barely move and big
## ones really do. Strength in pixels converts via shake_px().
static func shake(amount: float) -> void:
	var j := _kit()
	j.trauma = minf(1.0, j.trauma + maxf(0.0, amount))


## The old Main.shake(strength_px, seconds) in trauma terms.
static func shake_px(strength: float) -> void:
	shake(sqrt(clampf(strength / SHAKE_PX, 0.0, 1.0)))


## A short knock in one direction (hits, slams). Springs back by itself.
static func kick(dir: Vector2, px := 3.0) -> void:
	var j := _kit()
	j._kick += dir.normalized() * px


func _process(delta: float) -> void:
	var real := Time.get_ticks_msec() / 1000.0
	if _stop_end > 0.0 and real >= _stop_end:
		_stop_end = 0.0
		Engine.time_scale = 1.0
	var dt := minf(delta / maxf(Engine.time_scale, 0.01), 0.1)
	_t += dt
	trauma = maxf(0.0, trauma - TRAUMA_DECAY * dt)
	_kick = _kick.lerp(Vector2.ZERO, 1.0 - exp(-16.0 * dt))
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	if trauma > 0.0 or _kick.length() > 0.25:
		var s := SHAKE_PX * trauma * trauma
		var n := Vector2(_noise.get_noise_2d(_t * SHAKE_HZ, 0.0), _noise.get_noise_2d(0.0, _t * SHAKE_HZ + 40.0)) * 1.8
		cam.offset = (n * s + _kick).round()
		_driving = true
	elif _driving:
		cam.offset = Vector2.ZERO
		_driving = false


# --- time --------------------------------------------------------------------------

## Freeze the world for a beat. Overlapping calls extend it; time always comes back.
static func hit_stop(seconds := 0.06, scale := 0.05) -> void:
	var j := _kit()
	var real := Time.get_ticks_msec() / 1000.0
	j._stop_end = maxf(j._stop_end, real + seconds)
	Engine.time_scale = scale
	# A safety net in case this node isn't in the tree yet: a real-time timer.
	var tree := Engine.get_main_loop() as SceneTree
	tree.create_timer(seconds + 0.02, true, false, true).timeout.connect(func() -> void:
		if Time.get_ticks_msec() / 1000.0 >= j._stop_end - 0.001:
			j._stop_end = 0.0
			Engine.time_scale = 1.0
	)


# --- numbers and things --------------------------------------------------------------

## How long a count should take for a change of `delta`: small changes are quick,
## big ones roll a little longer (0.35 to 0.8 s).
static func count_seconds(delta: float) -> float:
	return clampf(0.35 + log(1.0 + absf(delta)) / log(10.0) * 0.1, 0.35, 0.8)


## Roll a label's number from `from` to `to`. `fmt` is a format string ("%d") or a
## Callable(value) -> String. `on_step` gets each new shown text (for ticks).
static func count_up(label: Label, from: float, to: float, fmt: Variant = "%d", seconds := -1.0, on_step := Callable()) -> Tween:
	if seconds < 0.0:
		seconds = count_seconds(to - from)
	var shown := [label.text]
	var tw := label.create_tween()
	tw.tween_method(func(v: float) -> void:
		var text: String = fmt.call(v) if fmt is Callable else (fmt as String) % v
		label.text = text
		if text != shown[0]:
			shown[0] = text
			if on_step.is_valid():
				on_step.call(text)
	, from, to, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: label.text = fmt.call(to) if fmt is Callable else (fmt as String) % to)
	return tw


## Squash a thing and let it spring back (Balatro landing). Works on Node2D and Control.
static func pop(node: CanvasItem, squash := Vector2(1.25, 0.8), seconds := 0.4) -> Tween:
	if node is Control:
		var c := node as Control
		c.pivot_offset = c.size / 2.0
	node.set("scale", squash)
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2.ONE, seconds).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	return tw


## A quick bright flash on a thing (modulate over 1, then back).
static func flash(node: CanvasItem, color := Color(1.8, 1.8, 1.8), seconds := 0.18) -> Tween:
	var base := node.modulate
	node.modulate = color
	var tw := node.create_tween()
	tw.tween_property(node, "modulate", base, seconds)
	return tw
