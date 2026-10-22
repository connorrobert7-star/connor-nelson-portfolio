class_name SpeechBubble
extends Node2D
## Words over a character's head instead of a text panel: a cream pixel bubble with a
## dark outline, a drop shadow and a tail down to the speaker. It pops from the tail,
## types out with blips in the speaker's voice (pausing at punctuation), bobs a pixel
## while talking, holds, then rises and fades. say() returns when the line is done.
##   var bubble := SpeechBubble.new(); dealer.add_child(bubble); bubble.position = Vector2(0, -36)
##   await bubble.say("Twenty-five shells. One purple.")
## The node's origin is the tip of the tail.

signal finished

const CHAR_SECONDS := 0.03
const PAUSE_SECONDS := 0.14
const HOLD_SECONDS := 1.6
const MAX_WIDTH := 150.0
const FONT := preload("res://art/ui/fonts/m5x7.ttf")
const PX := 16
const LINE_H := 10.0
const PAD := Vector2(5, 3)
const TAIL := 5.0
const BLIP := "res://art/packs/ignisforge-sfx-sampler/blip_15.ogg"

## Blip pitch for this speaker (Vex 0.7, bosses 0.6, Marlo 1.0, Bess 1.15).
var voice := -1.0
## Where the tail meets the bubble, from the bubble's center (positive = right).
var tail_x := 0.0

var _lines: PackedStringArray = []
var _shown := 0  # characters typed so far
var _total := 0
var _size := Vector2.ZERO
var _talking := false
var _t := 0.0
var _tween: Tween
var _body := Node2D.new()  # scaled for the pop, about the tail tip


func _ready() -> void:
	z_index = 120
	z_as_relative = false
	add_child(_body)
	_body.draw.connect(_draw_body)
	visible = false
	if voice < 0.0:
		voice = _guess_voice()


func _guess_voice() -> float:
	var n: Node = get_parent()
	for i in 4:
		if n == null:
			break
		var s := n.get_script() as Script
		var path := s.resource_path if s else ""
		if path.contains("gate_boss"):
			return 0.6
		if path.contains("vex") or path.contains("case_overlay") or path.contains("machine_overlay"):
			return 0.7
		n = n.get_parent()
	return 1.0


func say(text: String, hold := HOLD_SECONDS) -> void:
	if _tween:
		_tween.kill()
	_layout(text)
	_shown = 0
	visible = true
	modulate.a = 1.0
	_body.position = Vector2.ZERO
	_body.scale = Vector2(0.3, 0.3)
	_talking = true
	# The pop runs on its own; the words start typing while it settles.
	var pop := _body.create_tween()
	pop.tween_property(_body, "scale", Vector2(1.08, 1.08), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.tween_property(_body, "scale", Vector2.ONE, 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween = create_tween()
	_tween.tween_interval(0.04)
	var flat := " ".join(_lines)
	for i in _total:
		var ch := flat[i]
		_tween.tween_callback(func() -> void:
			_shown = i + 1
			if i % 2 == 0 and ch != " ":
				Sfx.play_path(BLIP, voice * randf_range(0.94, 1.06), -18.0, "UI")
		)
		_tween.tween_interval(PAUSE_SECONDS if ".,?-;:".contains(ch) and i < _total - 1 else CHAR_SECONDS)
	_tween.tween_callback(func() -> void: _talking = false)
	_tween.tween_interval(hold)
	_tween.set_parallel()
	_tween.chain().tween_property(self, "modulate:a", 0.0, 0.25)
	_tween.tween_property(_body, "position:y", -3.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_callback(func() -> void:
		visible = false
		finished.emit()
	)
	await finished


func hide_now() -> void:
	if _tween:
		_tween.kill()
	_talking = false
	visible = false
	finished.emit()


## Wrap the words to MAX_WIDTH with the real font, and size the bubble to the result.
func _layout(text: String) -> void:
	_lines = []
	var line := ""
	for word in text.split(" ", false):
		var next := word if line == "" else line + " " + word
		if line != "" and _w(next) > MAX_WIDTH:
			_lines.append(line)
			line = word
		else:
			line = next
	if line != "":
		_lines.append(line)
	_total = 0
	var w := 0.0
	for l in _lines:
		w = maxf(w, _w(l))
		_total += l.length()
	_total += maxi(0, _lines.size() - 1)  # the spaces that became line breaks
	_size = Vector2(ceilf(w), _lines.size() * LINE_H) + PAD * 2.0
	_size.x = maxf(_size.x, 14.0)


func _w(s: String) -> float:
	return FONT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, PX).x


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_body.queue_redraw()


func _draw_body() -> void:
	var bob := roundf(sin(_t * 9.0) * 0.5 + 0.5) if _talking else 0.0
	var r := Rect2(Vector2(roundf(-_size.x / 2.0), -_size.y - TAIL + 1.0 - bob), _size)
	var tx := roundf(clampf(tail_x, r.position.x + 5.0 - 0.0, r.end.x - 6.0))
	var b := _body
	# Drop shadow, then outline, then the cream fill with notched corners.
	b.draw_rect(Rect2(r.position + Vector2(1, 1), r.size), Color(Palette.NIGHT, 0.5))
	b.draw_rect(Rect2(r.position + Vector2(1, -1), Vector2(r.size.x - 2, r.size.y + 2)), Palette.NIGHT)
	b.draw_rect(Rect2(r.position + Vector2(-1, 1), Vector2(r.size.x + 2, r.size.y - 2)), Palette.NIGHT)
	b.draw_rect(Rect2(r.position + Vector2(1, 0), Vector2(r.size.x - 2, r.size.y)), Palette.CREAM)
	b.draw_rect(Rect2(r.position + Vector2(0, 1), Vector2(r.size.x, r.size.y - 2)), Palette.CREAM)
	# A soft lower edge so the bubble has a little body.
	b.draw_rect(Rect2(r.position + Vector2(1, r.size.y - 1), Vector2(r.size.x - 2, 1)), Palette.CREAM.darkened(0.12))
	# The tail: a stepped wedge down to the tip at (tail, 0).
	var top := r.end.y
	for i in int(TAIL):
		var half := maxi(0, 2 - i / 2)
		var y := top + i - 1
		b.draw_rect(Rect2(Vector2(tx - half - 1, y), Vector2(half * 2 + 3, 1)), Palette.NIGHT)
		b.draw_rect(Rect2(Vector2(tx - half, y), Vector2(half * 2 + 1, 1)), Palette.CREAM if i < TAIL - 1 else Palette.NIGHT)
	# The words typed so far.
	var left := _shown
	for li in _lines.size():
		if left <= 0:
			break
		var l := _lines[li]
		var part := l.substr(0, mini(left, l.length()))
		left -= l.length() + 1
		var base := r.position + PAD + Vector2(0, li * LINE_H + 8.0)
		b.draw_string(FONT, base, part, HORIZONTAL_ALIGNMENT_LEFT, -1, PX, Palette.NIGHT)
