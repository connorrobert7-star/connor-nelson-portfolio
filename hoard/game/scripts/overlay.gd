class_name Overlay
extends Control
## A full-screen screen on top of the world: case reels, scratch tickets, minigames,
## the collection book. Open with `var result = await main.open_overlay(MyOverlay.new())`.
## The player can't move while one is open. Call close(result) when done.

signal closed(result: Variant)

var main: Node  # scripts/main.gd, set by open_overlay


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func close(result: Variant = null) -> void:
	closed.emit(result)
	queue_free()


## A dimmed backdrop in the palette's night color. Call from _ready() if wanted.
func add_backdrop(alpha := 0.88) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(Palette.NIGHT, alpha)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	return bg
