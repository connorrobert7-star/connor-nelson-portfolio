class_name Overlay
extends Control
## A full-screen screen on top of the world: case reels, scratch tickets, minigames,
## the collection book. Open with `var result = await main.open_overlay(MyOverlay.new())`.
## The player can't move while one is open. Call close(result) when done.
##
## Every overlay pops in (fade, 0.94 -> 1.02 -> 1.0, an open sound) unless it sets
## `custom_intro = true` before it enters the tree because it stages its own entrance.
## Every overlay plays a short outro on close: `closed` fires at once so game flow never
## waits, and the overlay shrinks a touch and fades on a layer of its own.

signal closed(result: Variant)

## Overlays that already stage their own entrance. They still get the outro.
const OWN_INTRO := [
	"res://features/casino/case_overlay.gd", "res://features/casino/book_overlay.gd",
	"res://features/casino/draw_overlay.gd", "res://features/village/stats_overlay.gd",
	"res://features/casino/machine_overlay.gd",
]
const BACKDROP_SHADER := """
shader_type canvas_item;
// A dim that's a touch lighter in the middle, so the eye lands on the center.
void fragment() {
	float d = length((UV - 0.5) * vec2(1.0, 0.75)) * 1.6;
	COLOR.a *= mix(0.86, 1.0, smoothstep(0.15, 0.95, d));
}
"""

var main: Node  # scripts/main.gd, set by open_overlay
var custom_intro := false
var _closed := false
static var _backdrop_shader: Shader


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		_intro()


func _intro() -> void:
	var script := get_script() as Script
	while script != null:
		if OWN_INTRO.has(script.resource_path):
			custom_intro = true
		script = script.get_base_script()
	if custom_intro:
		return
	Sfx.ui("open")
	pivot_offset = get_viewport_rect().size / 2.0
	modulate.a = 0.0
	scale = Vector2(0.94, 0.94)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, 0.15)
	tw.tween_property(self, "scale", Vector2(1.02, 1.02), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(self, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close(result: Variant = null) -> void:
	if _closed:
		return
	_closed = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if main and main.has_method("retire_overlay"):
		main.retire_overlay(self)
	closed.emit(result)
	if not is_inside_tree():
		queue_free()
		return
	Sfx.ui("close")
	_ignore_input(self)
	pivot_offset = get_viewport_rect().size / 2.0
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "scale", Vector2(0.96, 0.96), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.chain().tween_callback(queue_free)


## While it plays out, the closing overlay takes no taps.
static func _ignore_input(n: Node) -> void:
	n.set_process_input(false)
	n.set_process_unhandled_input(false)
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_input(c)


## A dimmed backdrop in the palette's night color, a touch lighter at the center.
## Call from _ready() if wanted.
func add_backdrop(alpha := 0.88) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(Palette.NIGHT, alpha)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	if _backdrop_shader == null:
		_backdrop_shader = Shader.new()
		_backdrop_shader.code = BACKDROP_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _backdrop_shader
	bg.material = mat
	add_child(bg)
	return bg
