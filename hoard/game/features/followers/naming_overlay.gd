class_name NamingOverlay
extends Overlay
## The naming rite: the hatchling sits in a ring of green fire and three names float over it.
## Tap one. It burns in; the other two crumble. No typing, no panel.

const CIRCLE := "res://art/packs/srzolda-magic-summons/green_idle-Sheet.png"

var names: Array = []
var stage := 1
var chosen := ""

var _lamb := Sprite2D.new()
var _circle := Sprite2D.new()
var _words: Array[Label] = []
var _t := 0.0
var _done := false


func _init(offered: Array = [], at_stage := 1) -> void:
	super._init()
	names = offered
	stage = maxi(1, at_stage)


func _ready() -> void:
	add_backdrop(0.93).mouse_filter = Control.MOUSE_FILTER_IGNORE  # taps beside the names reach the rite
	var g := FollowerArt.glow(Color(Palette.BILE, 0.35), 110.0)
	g.position = Vector2(240, 170)
	add_child(g)
	_circle.texture = FollowerArt.region(CIRCLE, Rect2(0, 0, 64, 64))
	_circle.position = Vector2(240, 186)
	_circle.scale = Vector2(3, 1.4)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_circle.material = add
	_circle.modulate = Color(1, 1, 1, 0.7)
	add_child(_circle)
	_lamb.texture = FollowerArt.lamb(stage, 1)
	_lamb.offset = Vector2(0, -FollowerArt.LAMB_CELL / 2.0)
	_lamb.position = Vector2(240, 196)
	_lamb.scale = Vector2(3, 3)
	add_child(_lamb)
	FollowerArt.play("ethereal", 1.0, -10.0)
	for i in names.size():
		var l := FollowerArt.label(str(names[i]), FollowerArt.FONT_TITLE, 24, Palette.CREAM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(120, 28)
		l.pivot_offset = l.size / 2.0
		l.position = Vector2(60 + i * 120, 34 + (12 if i == 1 else 26)) - Vector2(0, 0)
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.gui_input.connect(_on_word_input.bind(i))
		l.modulate.a = 0.0
		var glow := FollowerArt.glow(Color(Palette.CREAM, 0.22), 40.0)
		glow.position = l.size / 2.0
		glow.show_behind_parent = true
		l.add_child(glow)
		add_child(l)
		_words.append(l)
		var tw := l.create_tween()
		tw.tween_interval(0.25 + i * 0.25)
		tw.tween_property(l, "modulate:a", 1.0, 0.4)
		tw.parallel().tween_callback(func() -> void: FollowerArt.play("pop", 0.8 + i * 0.15, -8.0))


func _process(delta: float) -> void:
	_t += delta
	_circle.texture = FollowerArt.region(CIRCLE, Rect2((int(_t * 10.0) % 43) * 64, 0, 64, 64))
	var blink := fmod(_t, 3.3) < 0.12
	_lamb.texture = FollowerArt.lamb(stage, FollowerArt.LAMB_BLINK if blink else 1)
	_lamb.scale = Vector2(3, 3 * (1.0 + 0.03 * sin(_t * TAU / 1.6)))
	if not _done:
		for i in _words.size():
			var l := _words[i]
			l.position.y = 34 + (12 if i == 1 else 26) + sin(_t * 1.7 + i * 2.0) * 3.0
			l.rotation = sin(_t * 1.1 + i) * 0.04


## A tap beside the names still answers: they bob toward the finger, and a soft note.
func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if _done or mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	FollowerArt.play("pop", 0.7, -14.0)
	for l in _words:
		var tw := l.create_tween()
		tw.tween_property(l, "scale", Vector2(1.12, 1.12), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_word_input(event: InputEvent, i: int) -> void:
	if _done:
		return
	if Level._is_tap(event):
		accept_event()
		_choose(i)


func _choose(i: int) -> void:
	_done = true
	chosen = str(names[i])
	var res: Array = await Game.call_api("POST", "/followers/name", {"name": chosen})
	if res[1] != "":
		_done = false
		FollowerArt.play("no", 1.0, -8.0)
		return
	FollowerArt.play("bell", 1.0, -4.0)
	FollowerArt.play("chant", 1.0, -6.0)
	FollowerArt.play("bleat", 1.3, -4.0)
	for j in _words.size():
		var l := _words[j]
		var tw := l.create_tween()
		if j == i:
			l.label_settings.font_color = Palette.GLOW
			tw.tween_property(l, "scale", Vector2(1.6, 1.6), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(l, "position", Vector2(180, 96), 0.5).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(l, "scale", Vector2(1.3, 1.3), 0.5)
		else:
			tw.tween_property(l, "position:y", l.position.y + 160.0, 0.6).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(l, "rotation", randf_range(-1.2, 1.2), 0.6)
			tw.parallel().tween_property(l, "modulate:a", 0.0, 0.6)
	FlockFx.burst(self, Vector2(240, 120), Palette.CREAM, 40, 140.0, 0.9, 120.0)
	FlockFx.specks(self, Vector2(240, 140), FollowerArt.SPECK_HEART, 6, 26.0)
	var hop := create_tween()
	for k in 3:
		hop.tween_property(_lamb, "position:y", 184.0, 0.12).set_ease(Tween.EASE_OUT)
		hop.tween_property(_lamb, "position:y", 196.0, 0.12).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(1.6).timeout
	await Game.refresh()
	close(chosen)
