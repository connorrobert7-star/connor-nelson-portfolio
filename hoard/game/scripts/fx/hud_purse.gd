class_name HudPurse
extends Control
## Top-right purse: a dark plate holding a spinning brass coin with the coin count
## and a bone jar with extra (real money in BONE, play coins in BRASS). Both numbers
## roll to their new value with rising ticks, and the icon squashes when they land.
## Under it, a small calendar with the week being viewed.

const PLATE := preload("res://art/packs/tiopalada-dark-dwellers-gui/20251029darkDwellers9SlicesA.png")
const COIN := preload("res://art/packs/evercrazy-coin-gem-8x8/SpinningCoin.png")
const SMALL := preload("res://art/ui/fonts/m5x7.ttf")
const BIG := preload("res://art/ui/fonts/Jersey10-Regular.ttf")
const NUM_PX := 20
const PAD := 6.0
const H := 18.0

var coins := 0.0
var cents := 0.0
var week := ""
var _target_coins := -1
var _target_cents := -1
var _coin_scale := Vector2.ONE
var _jar_scale := Vector2.ONE
var _coin_flash := 0.0
var _jar_flash := 0.0
var _t := 0.0
var _last_tick := 0
var _tween_coins: Tween
var _tween_cents: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_purse(new_coins: int, new_cents: int, week_text: String) -> void:
	week = week_text
	if _target_coins < 0:
		coins = new_coins
		cents = new_cents
	else:
		if new_coins != _target_coins:
			_roll_coins(new_coins)
		if new_cents != _target_cents:
			_roll_cents(new_cents)
	_target_coins = new_coins
	_target_cents = new_cents
	queue_redraw()


func _roll_coins(to: int) -> void:
	if _tween_coins:
		_tween_coins.kill()
	var from := coins
	var seconds := Juice.count_seconds(to - from)
	_tween_coins = create_tween()
	_tween_coins.tween_method(func(v: float) -> void:
		var before := roundi(coins)
		coins = v
		if roundi(v) != before:
			_tick(absf(v - from) / maxf(1.0, absf(to - from)), to > from)
	, from, float(to), seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween_coins.tween_callback(func() -> void:
		coins = to
		_land("coin")
	)


func _roll_cents(to: int) -> void:
	if _tween_cents:
		_tween_cents.kill()
	var from := cents
	var seconds := Juice.count_seconds((to - from) / 100.0)
	_tween_cents = create_tween()
	_tween_cents.tween_method(func(v: float) -> void:
		var before := roundi(cents / 100.0)
		cents = v
		if roundi(v / 100.0) != before:
			_tick(absf(v - from) / maxf(1.0, absf(to - from)), to > from)
	, from, float(to), seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween_cents.tween_callback(func() -> void:
		cents = to
		_land("jar")
	)


func _tick(progress: float, up: bool) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_tick < 45:
		return
	_last_tick = now
	var pitch := (0.9 + progress * 0.5) if up else (1.2 - progress * 0.4)
	Sfx.play_path("res://art/packs/kenney-interface-sounds/Audio/tick_001.ogg", pitch, -16.0, "UI")


func _land(which: String) -> void:
	Sfx.play_path("res://art/packs/kenney-interface-sounds/Audio/tick_002.ogg", 1.5, -12.0, "UI")
	var prop := "_coin_scale" if which == "coin" else "_jar_scale"
	var flash := "_coin_flash" if which == "coin" else "_jar_flash"
	set(prop, Vector2(1.25, 0.8))
	set(flash, 1.0)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, prop, Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, flash, 0.0, 0.3)


func _process(delta: float) -> void:
	_t += delta
	if _target_coins >= 0:
		queue_redraw()


func _num_w(text: String) -> float:
	return BIG.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, NUM_PX).x


func _draw() -> void:
	if _target_coins < 0:
		return
	# Size the plate to the numbers it will land on, so it doesn't jitter while rolling.
	var coin_text := str(roundi(coins))
	var cash_text := Money.fmt(roundi(cents))
	var coin_w := maxf(_num_w(coin_text), _num_w(str(_target_coins)))
	var cash_w := maxf(_num_w(cash_text), _num_w(Money.fmt(_target_cents)))
	var inner := 10.0 + coin_w + 8.0 + 10.0 + cash_w
	var w := roundf(inner + PAD * 2.0)
	var x0 := size.x - w
	# The plate: the Dark Dwellers panel, darkened to sit back.
	_nine(Rect2(x0, 0, w, H))
	var x := x0 + PAD
	# Spinning brass coin.
	var frame := int(_t * 10.0) % 18
	_icon_at(Vector2(x + 4, 9), _coin_scale, func() -> void:
		draw_texture_rect_region(COIN, Rect2(-4, -4, 8, 8), Rect2(frame * 8, 0, 8, 8), Color(1, 1, 1).lerp(Color(2, 2, 2), _coin_flash))
	)
	x += 10.0
	_num(coin_text, Vector2(x, 14), Palette.BRASS.lerp(Color.WHITE, _coin_flash * 0.6))
	x += coin_w + 8.0
	# Bone jar.
	_icon_at(Vector2(x + 3, 10), _jar_scale, func() -> void: _jar(Vector2(-3, -5), _jar_flash))
	x += 10.0
	_num(cash_text, Vector2(x, 14), Palette.BONE.lerp(Color.WHITE, _jar_flash * 0.6))
	# The week, small and quiet under the plate.
	var wk_w := SMALL.get_string_size(week, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var wx := size.x - wk_w - 22.0
	_calendar(Vector2(wx - 10, H + 4))
	draw_string_outline(SMALL, Vector2(wx, H + 11), week, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 2, Color(Palette.NIGHT, 0.6))
	draw_string(SMALL, Vector2(wx, H + 11), week, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Palette.MUTED, 0.75))


## Corners of the 9-slice over the stretched fill, so the ornaments stay crisp.
func _nine(r: Rect2) -> void:
	const M := 5.0
	var mod := Color(0.55, 0.5, 0.68, 0.96)
	# Edges.
	draw_texture_rect_region(PLATE, Rect2(r.position + Vector2(M, 0), Vector2(r.size.x - M * 2, M)), Rect2(M, 0, 96 - M * 2, M), mod)
	draw_texture_rect_region(PLATE, Rect2(r.position + Vector2(M, r.size.y - M), Vector2(r.size.x - M * 2, M)), Rect2(M, 96 - M, 96 - M * 2, M), mod)
	draw_texture_rect_region(PLATE, Rect2(r.position + Vector2(0, M), Vector2(M, r.size.y - M * 2)), Rect2(0, M, M, 96 - M * 2), mod)
	draw_texture_rect_region(PLATE, Rect2(r.position + Vector2(r.size.x - M, M), Vector2(M, r.size.y - M * 2)), Rect2(96 - M, M, M, 96 - M * 2), mod)
	# Inner fill, then the four corners.
	draw_texture_rect_region(PLATE, r.grow(-M), Rect2(M + 8, M + 8, 96 - (M + 8) * 2, 96 - (M + 8) * 2), mod)
	for c: Vector2 in [Vector2.ZERO, Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var dst := Rect2(r.position + Vector2(c.x * (r.size.x - M), c.y * (r.size.y - M)), Vector2(M, M))
		draw_texture_rect_region(PLATE, dst, Rect2(c.x * (96 - M), c.y * (96 - M), M, M), mod)


func _icon_at(center: Vector2, s: Vector2, body: Callable) -> void:
	draw_set_transform(center, 0.0, s)
	body.call()
	draw_set_transform(Vector2.ZERO)


func _num(text: String, baseline: Vector2, color: Color) -> void:
	draw_string_outline(BIG, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, NUM_PX, 2, Palette.NIGHT)
	draw_string(BIG, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, NUM_PX, color)


## A 7x9 bone-white jar with a lid, for real money.
func _jar(o: Vector2, flash: float) -> void:
	var bone := Palette.BONE.lerp(Color.WHITE, flash)
	var shade := bone.darkened(0.3)
	var rows := [".nnnnn.", ".lllll.", "..n.n..", ".nbbbn.", "nbbbbbn", "nbhbbsn", "nbhbbsn", "nbbbssn", ".nnnnn."]
	for y in rows.size():
		for x in 7:
			var ch: String = rows[y][x]
			var c := Color.TRANSPARENT
			match ch:
				"n": c = Palette.NIGHT
				"l": c = Palette.BRASS.darkened(0.2)
				"b": c = bone
				"h": c = Color.WHITE
				"s": c = shade
			if c.a > 0.0:
				draw_rect(Rect2(o + Vector2(x, y), Vector2.ONE), c)


## A 7x7 calendar page.
func _calendar(o: Vector2) -> void:
	var a := 0.7
	draw_rect(Rect2(o + Vector2(0, 1), Vector2(7, 7)), Color(Palette.NIGHT, a))
	draw_rect(Rect2(o + Vector2(1, 2), Vector2(5, 2)), Color(Palette.BLOOD, a))
	draw_rect(Rect2(o + Vector2(1, 4), Vector2(5, 3)), Color(Palette.CREAM, a))
	draw_rect(Rect2(o + Vector2(2, 0), Vector2(1, 2)), Color(Palette.MUTED, a))
	draw_rect(Rect2(o + Vector2(4, 0), Vector2(1, 2)), Color(Palette.MUTED, a))
	draw_rect(Rect2(o + Vector2(2, 5), Vector2.ONE), Color(Palette.NIGHT, a))
	draw_rect(Rect2(o + Vector2(4, 5), Vector2.ONE), Color(Palette.NIGHT, a))
