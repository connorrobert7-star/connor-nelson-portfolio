class_name GateStacks
extends Node2D
## The little stacks of bone-white discs you pay with: the minimum payment, $25, $50,
## $100, $250 (and the rest, when it's less). Real money is bone white, never brass.
## Press and hold one; a ring fills around it; when it closes, the strike goes.

signal hint_done

const COIN_SHEET := "res://art/packs/greatdocbrown-coins-gems/coins-chests-etc-2-0.png"
const COIN_RECT := Rect2(17, 34, 14, 14)
const HAND_SHEET := "res://art/packs/kenney-cursor-pixel-pack/Tilemap/tilemap_packed.png"
const HAND_RECT := Rect2(272, 96, 16, 16)
const BONE := Color(1.0, 0.95, 0.84)
const SPACING := 40.0
const RING := 15.0

var amounts: Array = []  # [{amount_cents, kind, affordable}]
var charge_i := -1
var charge := 0.0

var _stacks: Array[Node2D] = []
var _coins: Array = []  # per stack: Array[Sprite2D]
var _lamps: Array[Sprite2D] = []
var _t := 0.0
var _hand: Sprite2D


func build(list: Array) -> void:
	amounts = list
	var tex := AtlasTexture.new()
	tex.atlas = load(COIN_SHEET)
	tex.region = COIN_RECT
	var n := list.size()
	var bone := GateFx.bone_material()
	for i in n:
		var a: Dictionary = list[i]
		var s := Node2D.new()
		var mid := (n - 1) / 2.0
		s.position = Vector2((i - mid) * SPACING, absf(i - mid) * -5.0)
		add_child(s)
		var lamp := GateFx.glow(Color(BONE, 0.5), 22, -1)
		lamp.position = Vector2(0, -12)
		s.add_child(lamp)
		_lamps.append(lamp)
		var coins: Array[Sprite2D] = []
		for c in _coin_count(int(a.amount_cents)):
			var coin := Sprite2D.new()
			coin.texture = tex
			coin.material = bone
			coin.scale = Vector2(1.0, 0.55)
			coin.position = Vector2(roundf(sin(c * 2.1) * 1.5), -4 - c * 3)
			s.add_child(coin)
			coins.append(coin)
		_coins.append(coins)
		var label := GateFx.label(_short(int(a.amount_cents)), 13, Palette.CREAM, 4)
		label.size = Vector2(56, 14)
		label.position = Vector2(-28, 2)
		s.add_child(label)
		if not bool(a.affordable):
			s.modulate = Color(0.45, 0.42, 0.5)
			lamp.visible = false
		# Pop out, one after another.
		s.scale = Vector2.ZERO
		var tw := s.create_tween()
		tw.tween_interval(i * 0.05)
		tw.tween_callback(func() -> void: Sfx.play_path("res://art/packs/lrsf-coins-library/Coins_Few/Coins_Few_%02d.ogg" % (i * 3 % 20), 1.0 + i * 0.06, -10.0))
		tw.tween_property(s, "scale", Vector2(1.15, 0.85), 0.09).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(s, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		_stacks.append(s)


static func _coin_count(cents: int) -> int:
	if cents <= 2500:
		return 3
	if cents <= 5000:
		return 4
	if cents <= 10000:
		return 6
	if cents <= 25000:
		return 8
	return 10


## "$25" for whole dollars, the exact amount otherwise.
static func _short(cents: int) -> String:
	var full := Money.fmt(cents)
	return full.substr(0, full.length() - 3) if cents % 100 == 0 else full


func _process(delta: float) -> void:
	_t += delta
	for i in _stacks.size():
		var coins: Array = _coins[i]
		var lift := charge if i == charge_i else 0.0
		for c in coins.size():
			var coin: Sprite2D = coins[c]
			var bob := sin(_t * 3.0 + i + c * 0.4) * 0.6
			var spread := lift * (c * 2.2 + 2.0)
			var shiver := randf_range(-1, 1) * lift * 1.5
			coin.position = Vector2(roundf(sin(c * 2.1) * 1.5 + shiver), roundf(-4 - c * 3 - spread + bob * (1.0 - lift)))
		if i < _lamps.size() and _lamps[i].visible:
			_lamps[i].modulate.a = 0.35 + 0.15 * sin(_t * 4.0 + i) + lift * 0.5
	queue_redraw()


func _draw() -> void:
	if charge_i < 0 or charge_i >= _stacks.size():
		return
	var c := _stacks[charge_i].position + Vector2(0, -10)
	draw_arc(c, RING, 0, TAU, 32, Color(Palette.NIGHT, 0.8), 4.0)
	draw_arc(c, RING, -PI / 2.0, -PI / 2.0 + TAU * charge, 32, Palette.CREAM, 2.0)


## Which stack a point (in this node's parent space) lands on, or -1.
func index_at(point: Vector2) -> int:
	var local := point - position
	var best := -1
	var best_d := 20.0
	for i in _stacks.size():
		var d := local.distance_to(_stacks[i].position + Vector2(0, -8))
		if d < best_d:
			best_d = d
			best = i
	return best


## The middle of a stack, in the parent's space.
func stack_pos(i: int) -> Vector2:
	return position + _stacks[i].position + Vector2(0, -10)


func amount(i: int) -> int:
	return int(amounts[i].amount_cents)


func affordable(i: int) -> bool:
	return bool(amounts[i].affordable)


func set_charge(i: int, value: float) -> void:
	if _hand:
		hide_hint()
	charge_i = i
	charge = value


## Let go early: the ring drains and the discs settle.
func drain() -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: charge = v, charge, 0.0, 0.15)
	tw.tween_callback(func() -> void: charge_i = -1)


## The stack goes: its discs fly off (the motes take over from here).
func spend(i: int) -> void:
	charge_i = -1
	charge = 0.0
	var s := _stacks[i]
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector2(1.3, 0.6), 0.06)
	tw.tween_property(s, "scale", Vector2(0.0, 1.4), 0.12)


## No: the discs turn grey and the lamp clicks off.
func refuse(i: int) -> void:
	charge_i = -1
	charge = 0.0
	if i < 0 or i >= _stacks.size():
		return
	var s := _stacks[i]
	_lamps[i].visible = false
	Sfx.play_path("res://art/packs/shattered-pixel-dungeon/sounds/click.mp3", 0.7, -6.0)
	var tw := s.create_tween()
	tw.tween_property(s, "modulate", Color(0.4, 0.38, 0.45), 0.25)
	tw.parallel().tween_property(s, "position:x", s.position.x + 3, 0.04)
	tw.tween_property(s, "position:x", s.position.x - 3, 0.06)
	tw.tween_property(s, "position:x", s.position.x, 0.05)


func fold() -> void:
	hide_hint()
	for i in _stacks.size():
		var s := _stacks[i]
		var tw := s.create_tween()
		tw.tween_interval(i * 0.03)
		tw.tween_property(s, "scale", Vector2.ZERO, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	var done := create_tween()
	done.tween_interval(0.3)
	done.tween_callback(queue_free)


## A pointing hand presses and holds the first stack you can use, once, to show how.
func show_hint() -> void:
	if _hand or _stacks.is_empty():
		return
	var i := -1
	for k in amounts.size():
		if bool(amounts[k].affordable):
			i = k
			break
	if i < 0:
		return
	var at := AtlasTexture.new()
	at.atlas = load(HAND_SHEET)
	at.region = HAND_RECT
	_hand = Sprite2D.new()
	_hand.texture = at
	_hand.z_index = 40
	_hand.offset = Vector2(4, 6)
	add_child(_hand)
	var base := _stacks[i].position + Vector2(6, -2)
	_hand.position = base + Vector2(14, 14)
	var tw := _hand.create_tween().set_loops(3)
	tw.tween_property(_hand, "position", base, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_hand, "scale", Vector2(0.85, 0.85), 0.08)
	tw.tween_method(func(v: float) -> void:
		charge_i = i
		charge = v, 0.0, 1.0, 0.6)
	tw.tween_callback(func() -> void:
		charge_i = -1
		charge = 0.0)
	tw.tween_property(_hand, "scale", Vector2.ONE, 0.08)
	tw.tween_property(_hand, "position", base + Vector2(14, 14), 0.3)
	tw.finished.connect(hide_hint)


func hide_hint() -> void:
	if _hand:
		_hand.queue_free()
		_hand = null
		charge_i = -1
		charge = 0.0
		hint_done.emit()
