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

## Where worn things attach on each frame, measured from the sheet (rows and columns of the
## 16x28 frame): `brim` is the line his own pointy hat sits on (everything above it is that
## hat), `neck` the first row of robe under the beard; `left` and `right` are the outermost
## opaque columns of rows 18..27. The head spans columns 3..13 on every frame; the robe's
## hem is row 26.
const POSE := {
	"idle": [
		{"brim": 16, "neck": 22, "left": [3, 3, 3, 3, 4, 4, 4, 4, 3, 3], "right": [13, 13, 14, 14, 14, 13, 13, 13, 13, 13]},
		{"brim": 16, "neck": 23, "left": [3, 3, 3, 3, 3, 4, 4, 3, 2, 2], "right": [14, 13, 13, 14, 14, 14, 13, 13, 13, 13]},
		{"brim": 18, "neck": 24, "left": [2, 3, 3, 3, 3, 3, 3, 2, 1, 1], "right": [15, 14, 13, 13, 14, 14, 14, 13, 13, 14]},
		{"brim": 17, "neck": 23, "left": [3, 3, 3, 3, 3, 4, 4, 3, 2, 2], "right": [14, 13, 13, 14, 14, 14, 13, 13, 13, 13]},
	],
	"run": [
		{"brim": 17, "neck": 23, "left": [3, 3, 3, 3, 3, 4, 3, 2, 1, 1], "right": [14, 13, 13, 14, 14, 14, 13, 13, 13, 13]},
		{"brim": 15, "neck": 21, "left": [3, 3, 3, 4, 4, 4, 4, 3, 2, 2], "right": [13, 14, 14, 14, 13, 13, 13, 13, 12, 11]},
		{"brim": 15, "neck": 23, "left": [3, 3, 3, 3, 3, 4, 3, 2, 1, 1], "right": [14, 13, 13, 14, 14, 14, 13, 13, 13, 13]},
		{"brim": 17, "neck": 24, "left": [3, 3, 3, 3, 3, 3, 3, 1, 0, 0], "right": [14, 14, 13, 13, 14, 14, 14, 13, 13, 14]},
	],
}
const HEAD_COLS := Vector2i(3, 13)
const HEM_ROW := 26
## The robe's two colors on the sheet (the pointy hat shares them).
const ROBE_DARK := Color("5956bd")
const ROBE_MID := Color("5698cc")
## On the wizard's own sprite: a worn hat replaces his pointy one (rows down to the frame's
## brim go clear), and a worn cloak recolors his robe below it (a palette swap, exact colors
## only, so the beard, face and outline stay his).
const WEAR_SHADER := """
shader_type canvas_item;
uniform float region_top = 164.0;
uniform float brim_row = 16.0;
uniform bool hide_hat = false;
uniform bool recolor = false;
uniform vec4 robe_dark : source_color = vec4(0.349, 0.337, 0.741, 1.0);
uniform vec4 robe_mid : source_color = vec4(0.337, 0.596, 0.8, 1.0);
uniform vec4 cloak_dark : source_color = vec4(0.349, 0.337, 0.741, 1.0);
uniform vec4 cloak_mid : source_color = vec4(0.337, 0.596, 0.8, 1.0);
varying vec4 tint;
void vertex() {
	tint = COLOR;
}
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float row = floor(UV.y / TEXTURE_PIXEL_SIZE.y + 0.001) - region_top;
	if (hide_hat && row <= brim_row) {
		c.a = 0.0;
	}
	if (recolor && row > brim_row) {
		if (distance(c.rgb, robe_dark.rgb) < 0.03) {
			c.rgb = cloak_dark.rgb;
		} else if (distance(c.rgb, robe_mid.rgb) < 0.03) {
			c.rgb = cloak_mid.rgb;
		}
	}
	COLOR = c * tint;
}
"""

static var _wear_shader: Shader

var is_walkable: Callable  # func(Rect2) -> bool, set by the level
## func(Vector2) -> String: "grass", "concrete", "wood" or "carpet" under the feet.
var surface_at: Callable
## Where a click or tap sent the leader. INF when not walking to a point.
var target := Vector2.INF
## Which way he is walking (zero when standing), for the camera's lead.
var walk_dir := Vector2.ZERO
signal arrived
## The frame showing now ("idle" or "run", 0..3), for what he wears to follow.
var pose_anim := "idle"
var pose_frame := 0
## The wizard's sprite (worn pieces read its flip; the book's dressing sets its material).
var body: Sprite2D:
	get:
		return _sprite

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
	_sprite.material = Leader.wear_material()
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
	pose_anim = "run" if _running else "idle"
	pose_frame = frame
	Leader.pose_material(_sprite.material as ShaderMaterial, pose_anim, pose_frame)
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


# --- what he wears ---------------------------------------------------------------------

## A material for a wizard sprite cut from the sheet (the walking leader, the book's stage,
## the wizards in the games). One shader for all of them, compiled once a session (WebGL has
## no shader cache on disk, so a new one on every arrival would hitch the iris).
static func wear_material() -> ShaderMaterial:
	if _wear_shader == null:
		_wear_shader = Shader.new()
		_wear_shader.code = WEAR_SHADER
	var m := ShaderMaterial.new()
	m.shader = _wear_shader
	m.set_shader_parameter("region_top", IDLE.y)
	m.set_shader_parameter("robe_dark", ROBE_DARK)
	m.set_shader_parameter("robe_mid", ROBE_MID)
	return m


## Point the material at this frame's brim line.
static func pose_material(m: ShaderMaterial, anim: String, index: int) -> void:
	if m:
		m.set_shader_parameter("brim_row", float(POSE[anim][index].brim))


## Where things attach on a frame, in the leader's own pixels (feet at 0, 0; the frame's
## left edge at x -8 and its top at y -28), mirrored when he faces left. `head` is the head's
## middle (x) on the brim line (y); `neck`, `belt` and `hem` are rows; `back` and `front` are
## the outermost columns at a row on the side he faces away from and toward.
static func anchors(anim: String, index: int, flip: bool) -> Dictionary:
	var p: Dictionary = POSE[anim][index]
	var top := -int(FRAME.y)
	var brim: int = p.brim
	var neck: int = p.neck
	var head_mid := (HEAD_COLS.x + HEAD_COLS.y + 1) / 2.0 - 8.0
	return {
		"brim": top + brim,
		"head_x": -head_mid if flip else head_mid,
		"head_w": HEAD_COLS.y - HEAD_COLS.x + 1,
		"neck": top + neck,
		"belt": top + neck + 2,
		"hem": top + HEM_ROW,
		"flip": flip,
	}


## The outermost opaque pixel's left edge (leader pixels) on frame row `row` (18..27), on the
## back or the front side of the body.
static func edge(anim: String, index: int, row: int, front: bool, flip: bool) -> int:
	var p: Dictionary = POSE[anim][index]
	var i := clampi(row - 18, 0, 9)
	# On the sheet he faces right: the front is the frame's right edge, the back its left.
	# Flipped, the same pixels land mirrored about x 0.
	var col: int = p.right[i] if front else p.left[i]
	var x := col - 8
	return -x - 1 if flip else x

