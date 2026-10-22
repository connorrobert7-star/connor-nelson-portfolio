class_name HelperBubble
extends Node2D
## Pip's speech bubble: the same cream pixel bubble the casino and the gate use (dark
## outline, drop shadow, stepped tail, typed words with blips), a little wider so a thought
## fits in two short lines, and it waits to be read: a tap while typing shows the rest, a
## tap after moves on, and if nobody taps it leaves on its own after a reading pause.
## A soft blinking pip in the corner says there is more to come.
##   await bubble.say("An index fund owns a little of many companies.", true)
## The node's origin is the tip of the tail. Near the HUD band it flips under the speaker
## (`drop` px lower) with the tail pointing up; near a screen edge it slides sideways.

signal done

const FONT := preload("res://art/ui/fonts/m5x7.ttf")
const PX := 16
const LINE_H := 10.0
const PAD := Vector2(5, 3)
const TAIL := 5.0
const MAX_WIDTH := 184.0
const CHAR_SECONDS := 0.026
const PAUSE_SECONDS := 0.12
const BLIP := "res://art/packs/ignisforge-sfx-sampler/blip_15.ogg"
## The screen band the HUD plates live in; a bubble never hides under it.
const HUD_BAND := 46.0
const EDGE := 4.0
const PIP_COLOR := Color("5fb3c9")

## Blip pitch: a small creature speaks high.
var voice := 1.45
## How far below the origin the bubble sits when it flips under the speaker.
var drop := 34.0
## Seconds the full text has been on screen (0 while typing or hidden).
var shown_for := 0.0

var lines: PackedStringArray = []
var text := ""
var _state := "hidden"  # typing, hold, leaving, hidden
var _more := false
var _shown := 0
var _total := 0
var _size := Vector2.ZERO
var _char_t := 0.0
var _hold := 0.0
var _t := 0.0
var _leave_t := 0.0
var _rect := Rect2()  # where the body was last drawn, local to this node
var _body := Node2D.new()


func _ready() -> void:
	z_index = 120
	z_as_relative = false
	add_child(_body)
	_body.draw.connect(_draw_body)
	visible = false


## Show one line and return when it has gone. `more` lights the pip.
func say(t: String, more := false) -> void:
	text = t
	_more = more
	_layout(t)
	_shown = 0
	_char_t = 0.0
	_t = 0.0
	shown_for = 0.0
	_hold = clampf(1.6 + t.length() * 0.05, 2.6, 5.5)
	_state = "typing"
	visible = true
	modulate.a = 1.0
	_body.position = Vector2.ZERO
	_body.scale = Vector2(0.3, 0.3)
	var pop := _body.create_tween()
	pop.tween_property(_body, "scale", Vector2(1.08, 1.08), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.tween_property(_body, "scale", Vector2.ONE, 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await done


## A tap: finish typing at once, or move on if the words are all there.
func advance() -> void:
	match _state:
		"typing":
			_shown = _total
			_state = "hold"
		"hold":
			_leave()


## Gone at once (a level change, a skip).
func cut() -> void:
	if _state == "hidden":
		return
	_state = "hidden"
	visible = false
	done.emit()


func showing() -> bool:
	return _state == "typing" or _state == "hold"


## The bubble's rect in the level's pixels, for taps.
func hit_rect() -> Rect2:
	if not showing():
		return Rect2()
	return Rect2(global_position + _rect.position, _rect.size).grow(2.0)


func _leave() -> void:
	if _state == "leaving" or _state == "hidden":
		return
	_state = "leaving"
	_leave_t = 0.0


func _process(delta: float) -> void:
	if _state == "hidden":
		return
	_t += delta
	match _state:
		"typing":
			_char_t -= delta
			while _char_t <= 0.0 and _shown < _total:
				var flat := " ".join(lines)
				var ch := flat[_shown]
				_shown += 1
				if _shown % 2 == 0 and ch != " ":
					Sfx.play_path(BLIP, voice * randf_range(0.94, 1.06), -19.0, "UI")
				_char_t += PAUSE_SECONDS if ".,?-;:".contains(ch) and _shown < _total else CHAR_SECONDS
			if _shown >= _total:
				_state = "hold"
		"hold":
			shown_for += delta
			if shown_for >= _hold:
				_leave()
		"leaving":
			_leave_t += delta
			var k := clampf(_leave_t / 0.22, 0.0, 1.0)
			modulate.a = 1.0 - k
			_body.position.y = -roundf(3.0 * k)
			if k >= 1.0:
				_state = "hidden"
				visible = false
				done.emit()
				return
	_body.queue_redraw()


## Wrap the words to MAX_WIDTH with the real font, and size the bubble to the result.
func _layout(t: String) -> void:
	lines = []
	var line := ""
	for word in t.split(" ", false):
		var next := word if line == "" else line + " " + word
		if line != "" and _w(next) > MAX_WIDTH:
			lines.append(line)
			line = word
		else:
			line = next
	if line != "":
		lines.append(line)
	_total = 0
	var w := 0.0
	for l in lines:
		w = maxf(w, _w(l))
		_total += l.length()
	_total += maxi(0, lines.size() - 1)
	_size = Vector2(ceilf(w) + (6.0 if _more else 0.0), lines.size() * LINE_H) + PAD * 2.0
	_size.x = maxf(_size.x, 16.0)


func _w(s: String) -> float:
	return FONT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, PX).x


func _draw_body() -> void:
	var b := _body
	var screen := get_global_transform_with_canvas().origin
	var flip := screen.y - _size.y - TAIL < HUD_BAND
	var bob := roundf(sin(_t * 9.0) * 0.5 + 0.5) if _state == "typing" else 0.0
	var y := drop + TAIL - 1.0 + bob if flip else -_size.y - TAIL + 1.0 - bob
	var x := roundf(-_size.x / 2.0)
	# Slide sideways to stay on screen; the tail stays on the speaker.
	var left := screen.x + x
	if left < EDGE:
		x += EDGE - left
	elif left + _size.x > 480.0 - EDGE:
		x -= left + _size.x - (480.0 - EDGE)
	x = roundf(x)
	var r := Rect2(Vector2(x, y), _size)
	_rect = r
	var tx := roundf(clampf(0.0, r.position.x + 5.0, r.end.x - 6.0))
	b.draw_rect(Rect2(r.position + Vector2(1, 1), r.size), Color(Palette.NIGHT, 0.5))
	b.draw_rect(Rect2(r.position + Vector2(1, -1), Vector2(r.size.x - 2, r.size.y + 2)), Palette.NIGHT)
	b.draw_rect(Rect2(r.position + Vector2(-1, 1), Vector2(r.size.x + 2, r.size.y - 2)), Palette.NIGHT)
	b.draw_rect(Rect2(r.position + Vector2(1, 0), Vector2(r.size.x - 2, r.size.y)), Palette.CREAM)
	b.draw_rect(Rect2(r.position + Vector2(0, 1), Vector2(r.size.x, r.size.y - 2)), Palette.CREAM)
	b.draw_rect(Rect2(r.position + Vector2(1, r.size.y - 1), Vector2(r.size.x - 2, 1)), Palette.CREAM.darkened(0.12))
	# The tail: a stepped wedge to the speaker, down from the bottom or up from the top.
	for i in int(TAIL):
		var half := maxi(0, 2 - i / 2)
		var ty := r.end.y + i - 1 if not flip else r.position.y - i
		var fill := Palette.CREAM if i < TAIL - 1 else Palette.NIGHT
		b.draw_rect(Rect2(Vector2(tx - half - 1, ty), Vector2(half * 2 + 3, 1)), Palette.NIGHT)
		b.draw_rect(Rect2(Vector2(tx - half, ty), Vector2(half * 2 + 1, 1)), fill)
	var left_chars := _shown
	for li in lines.size():
		if left_chars <= 0:
			break
		var l := lines[li]
		var part := l.substr(0, mini(left_chars, l.length()))
		left_chars -= l.length() + 1
		b.draw_string(FONT, r.position + PAD + Vector2(0, li * LINE_H + 8.0), part, HORIZONTAL_ALIGNMENT_LEFT, -1, PX, Palette.NIGHT)
	# More to come: a small down-pointing pip that breathes in the corner.
	if _more and _state == "hold":
		var on := fmod(_t, 0.9) < 0.6
		var p := r.end - Vector2(7, 5)
		var c := PIP_COLOR if on else PIP_COLOR.darkened(0.35)
		b.draw_rect(Rect2(p, Vector2(5, 1)), c)
		b.draw_rect(Rect2(p + Vector2(1, 1), Vector2(3, 1)), c)
		b.draw_rect(Rect2(p + Vector2(2, 2), Vector2(1, 1)), c)
