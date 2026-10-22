class_name CasinoPot
extends RefCounted
## The pot on each pot machine (docs/POT.md): the run's lamps (lit, dark, and a warm one for
## the chance now), the pot jar with its dollar number, filling as it grows, and the small
## brass plate with the owner's pick and its creature. A blank drops a coin into the jar (the
## money still landed: the jar is the Brokerage); a hit blazes the run's last lamp and the
## jar pours into the pick's creature. Nothing here does money math: every number comes from
## the API or Game.state.

const A := "res://art/packs/"
const KYRISE := A + "kyrise-rpg-icons-16/spritesheet/spritesheet_16x16.png"
const COIN := Rect2(96, 96, 16, 16)
const SND_DARK := A + "kenney-interface-sounds/Audio/switch_002.ogg"
const SND_COIN := A + "kenney-casino-audio/Audio/chip-lay-2.ogg"
const SND_CLUNK := A + "kenney-impact-sounds/Audio/impactWood_heavy_001.ogg"
const SND_POUR := A + "kenney-casino-audio/Audio/chips-collide-3.ogg"
const SND_BLAZE := A + "ignisforge-sfx-sampler/jackpot_01.ogg"

const BRASS := Color("c99a4a")
const BRASS_LIT := Color("f2d08a")
const BRASS_DARK := Color("6b4a22")
const WARM := Color("ffb34a")
const LIT := Color("ffe6c4")
const GLASS := Color("bfe3ff")
const GOLD := Color("ffcf4a")


## The pot section of /state (total, pick, last buy).
static func pot() -> Dictionary:
	return Game.state.get("casino", {}).get("pot", {})


## One machine's run from /state: {size, left, average_one_in}.
static func run(key: String) -> Dictionary:
	return Game.state.get("casino", {}).get("runs", {}).get(key, {})


static func pick() -> Dictionary:
	var p: Variant = pot().get("pick")
	return p if p is Dictionary else {}


static func coin_tex() -> AtlasTexture:
	return MachineOverlay.region(KYRISE, COIN)


static func creature_tex(look: Dictionary) -> AtlasTexture:
	if look.is_empty():
		return null
	var r: Array = look.get("rect", [0, 0, 16, 16])
	return MachineOverlay.region(str(look.get("sheet", "")), Rect2(r[0], r[1], r[2], r[3]))


static func dollars(cents: int) -> String:
	return "$%d" % (cents / 100) if cents % 100 == 0 else "$%.2f" % (cents / 100.0)


## A soft round light drawn with stacked circles (no texture), for lamps and the jar.
static func soft(ci: CanvasItem, c: Vector2, color: Color, radius: float, strength: float) -> void:
	for i in 5:
		var f := 1.0 - i / 5.0
		ci.draw_circle(c, radius * f, Color(color, strength * 0.22 * (1.0 - f * 0.6)))


# --- the run's lamps -------------------------------------------------------------------------

class RunLamps:
	extends Control
	## A row of lamps, one per pull in the run. Used lamps are dark, the lamps still lit glow
	## pale, and the next one (the chance now: one in the lamps left) burns warm.
	var count := 6
	var left := 6
	var k := 1.0  # 1 in an overlay, smaller in the room
	var blaze := 0.0
	var _dying := -1
	var _die := 0.0
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func setup(r: Dictionary) -> void:
		count = maxi(1, int(r.get("size", count)))
		left = clampi(int(r.get("left", count)), 0, count)
		size = Vector2(count * 9.0 * k + 2.0, 10.0 * k)
		queue_redraw()

	func lamp_center(i: int) -> Vector2:
		return Vector2(5.0 * k + 1.0 + i * 9.0 * k, size.y / 2.0)

	## The lamp for the pull now.
	func current() -> int:
		return count - left

	## A blank: the warm lamp clicks dark and the next one warms.
	func go_dark() -> void:
		_dying = current()
		_die = 1.0
		left = maxi(1, left - 1)
		Sfx.play_path(CasinoPot.SND_DARK, 0.7, -10.0)
		var tw := create_tween()
		tw.tween_property(self, "_die", 0.0, 0.35)
		await tw.finished
		_dying = -1

	## The hit: the run's last lamp blazes, then a fresh run of `fresh` loads, lamp by lamp.
	func blaze_hit(fresh: Dictionary) -> void:
		_dying = current()
		Sfx.play_path(CasinoPot.SND_BLAZE, 1.0, -6.0)
		var tw := create_tween()
		tw.tween_property(self, "blaze", 1.0, 0.12)
		tw.tween_interval(0.5)
		tw.tween_property(self, "blaze", 0.0, 0.5)
		await tw.finished
		_dying = -1
		var n := maxi(1, int(fresh.get("size", count)))
		count = n
		left = 0
		size = Vector2(count * 9.0 * k + 2.0, 10.0 * k)
		for i in n:
			left = i + 1
			Sfx.play_path(CasinoPot.SND_DARK, 1.2 + i * 0.05, -16.0)
			await get_tree().create_timer(0.05).timeout
		left = int(fresh.get("left", n))

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var cur := current()
		for i in count:
			var c := lamp_center(i)
			var r := 3.0 * k
			draw_circle(c, r + 1.0, CasinoPot.BRASS_DARK)
			draw_arc(c, r + 0.5, PI, TAU, 8, CasinoPot.BRASS, 1.0)
			var color: Color
			if i < cur and i != _dying:
				color = Color("1a1016")  # spent
			elif i == cur or i == _dying:
				var pulse := 0.75 + 0.25 * sin(_t * 5.0)
				color = CasinoPot.WARM.lerp(CasinoPot.LIT, blaze)
				CasinoPot.soft(self, c, CasinoPot.WARM, r * (3.0 + blaze * 6.0), pulse + blaze * 2.0)
				if i == _dying and _die > 0.0:
					color = Color("1a1016").lerp(CasinoPot.WARM, _die)
			else:
				color = CasinoPot.LIT.darkened(0.15)
				CasinoPot.soft(self, c, CasinoPot.LIT, r * 2.2, 0.35)
			draw_circle(c, r, color)
			if i >= cur or i == _dying:
				draw_circle(c + Vector2(-1, -1) * k, maxf(0.8, r * 0.35), Color(1, 1, 1, 0.6))


# --- the pot jar -----------------------------------------------------------------------------

class Jar:
	extends Control
	## A glass jar on the machine, gold coins inside up to the pot, the dollar number on its
	## brass label. It fills on a slow curve (the pot rarely passes about $90).
	var cents := 0
	var shown := 0.0
	var k := 1.0
	var tip := 0.0  # 0 upright, 1 tipped over to pour
	var _t := 0.0
	var _font: Font

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font = MachineOverlay.res(MachineOverlay.M5X7) as Font

	func setup(total_cents: int) -> void:
		size = Vector2(26, 34) * k
		pivot_offset = Vector2(size.x / 2.0, size.y)
		cents = total_cents
		shown = float(total_cents)
		queue_redraw()

	func fill() -> float:
		return 0.06 + 0.88 * (1.0 - exp(-shown / 3000.0)) if shown > 0.0 else 0.0

	## Where a coin goes in, in global coordinates.
	func mouth_global() -> Vector2:
		return get_global_transform() * Vector2(size.x / 2.0, 3.0 * k)

	## A blank: a coin arcs from `from` (global) into the jar and the number counts up to
	## the new total from the API.
	func drop_coin(from: Vector2, total_cents: int) -> void:
		var coin := TextureRect.new()
		coin.texture = CasinoPot.coin_tex()
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.size = Vector2(12, 12) * k
		coin.pivot_offset = coin.size / 2.0
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin.z_index = 30
		var host := get_parent() as Control
		host.add_child(coin)
		var inv: Transform2D = host.get_global_transform().affine_inverse()
		var to: Vector2 = inv * mouth_global() - coin.size / 2.0
		var start: Vector2 = inv * from - coin.size / 2.0
		coin.position = start
		var arc := func(v: float) -> void:
			coin.position = start.lerp(to, v) + Vector2(0, -38.0 * k * sin(v * PI))
			coin.rotation = v * TAU * 1.5
		var tw := coin.create_tween()
		tw.tween_method(arc, 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE)
		await tw.finished
		coin.queue_free()
		Sfx.play_path(CasinoPot.SND_COIN, 1.3, -4.0)
		cents = total_cents
		var bump := create_tween()
		bump.tween_property(self, "scale", Vector2(1.12, 0.9), 0.06)
		bump.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var count := create_tween()
		count.tween_property(self, "shown", float(total_cents), 0.4)
		await count.finished

	## The hit: the jar tips and pours a stream of coins into `target` (global), and drains.
	func pour_into(target: Vector2, final_cents: int) -> void:
		var tw := create_tween()
		tw.tween_property(self, "tip", 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tw.finished
		Sfx.play_path(CasinoPot.SND_POUR, 0.9, -2.0)
		var host := get_parent() as Control
		var inv: Transform2D = host.get_global_transform().affine_inverse()
		var from: Vector2 = inv * (get_global_transform() * Vector2(size.x * 0.9, 4.0 * k))
		var to: Vector2 = inv * target
		var n := clampi(6 + int(shown / 300.0), 6, 18)
		for i in n:
			var coin := TextureRect.new()
			coin.texture = CasinoPot.coin_tex()
			coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			coin.size = Vector2(10, 10) * k
			coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
			coin.z_index = 30
			host.add_child(coin)
			var a: Vector2 = from + Vector2(randf_range(-2, 2), randf_range(-2, 2)) - coin.size / 2.0
			var b: Vector2 = to - coin.size / 2.0
			var h := randf_range(20.0, 34.0) * k
			coin.position = a
			var arc := func(v: float) -> void: coin.position = a.lerp(b, v) + Vector2(0, -h * sin(v * PI))
			var c := coin.create_tween()
			c.tween_method(arc, 0.0, 1.0, 0.45)
			c.tween_callback(coin.queue_free)
			if i % 3 == 0:
				Sfx.play_path(CasinoPot.SND_COIN, randf_range(1.1, 1.5), -12.0)
			await get_tree().create_timer(0.05).timeout
		var drain := create_tween()
		drain.tween_property(self, "shown", float(final_cents), 0.4)
		await get_tree().create_timer(0.45).timeout
		cents = final_cents
		var back := create_tween()
		back.tween_property(self, "tip", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await back.finished

	func _process(delta: float) -> void:
		_t += delta
		rotation = tip * 1.1
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var body := Rect2(2.0 * k, 6.0 * k, w - 4.0 * k, h - 7.0 * k)
		# The light the coins throw, then the glass, then the coins inside.
		var f := fill()
		if f > 0.0:
			CasinoPot.soft(self, Vector2(w / 2.0, body.end.y - body.size.y * f * 0.5), CasinoPot.GOLD, w * (0.9 + f * 0.5), 0.35 + 0.1 * sin(_t * 2.0))
		draw_rect(body, Color(CasinoPot.GLASS, 0.10))
		if f > 0.0:
			var level := body.size.y * f
			var coins := Rect2(body.position.x + 1, body.end.y - level, body.size.x - 2, level - 1)
			draw_rect(coins, Color("b0761f"))
			var step := 4.0 * k
			var y := coins.end.y - 2.0 * k
			var row := 0
			while y > coins.position.y:
				var x := coins.position.x + (2.0 if row % 2 else 0.0) * k
				while x < coins.end.x - 1:
					draw_rect(Rect2(x, y - 1.0 * k, 3.0 * k, 1.5 * k), CasinoPot.GOLD)
					x += step
				y -= 2.5 * k
				row += 1
			draw_rect(Rect2(coins.position.x, coins.position.y, coins.size.x, 1), CasinoPot.GOLD.lightened(0.4))
		# Glass edges, a glint, the brass neck and lid.
		draw_rect(body, Color(CasinoPot.GLASS, 0.55), false, 1.0)
		draw_rect(Rect2(body.position.x + 2.0 * k, body.position.y + 2.0 * k, 1.0 * k, body.size.y * 0.5), Color(1, 1, 1, 0.35))
		draw_rect(Rect2(4.0 * k, 2.0 * k, w - 8.0 * k, 4.0 * k), CasinoPot.BRASS_DARK)
		draw_rect(Rect2(4.0 * k, 2.0 * k, w - 8.0 * k, 1.0 * k), CasinoPot.BRASS_LIT)
		draw_rect(Rect2(6.0 * k, 0, w - 12.0 * k, 2.0 * k), CasinoPot.BRASS)
		# The brass label with the pot's dollars.
		var label := Rect2(1.0 * k, h * 0.5 - 4.0 * k, w - 2.0 * k, 9.0 * k)
		draw_rect(label, CasinoPot.BRASS_DARK)
		draw_rect(label.grow(-1), CasinoPot.BRASS)
		draw_rect(Rect2(label.position.x + 1, label.position.y + 1, label.size.x - 2, 1), CasinoPot.BRASS_LIT)
		var text := CasinoPot.dollars(int(round(shown / 100.0)) * 100) if absf(shown - cents) > 1.0 else CasinoPot.dollars(cents)
		var fs := 16 if k >= 1.0 else 8
		draw_string(_font, Vector2(label.position.x, label.end.y - 2.0 * k), text, HORIZONTAL_ALIGNMENT_CENTER, label.size.x, fs, Palette.NIGHT)


# --- the pick's brass plate ------------------------------------------------------------------

class Plate:
	extends Control
	## The pick: a small brass plate with the ticker and its creature. With no pick the plate
	## is blank, dull brass with nothing on it.
	var symbol := ""
	var look: Dictionary = {}
	var k := 1.0
	var swell := 0.0
	var _creature := TextureRect.new()
	var _font: Font
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font = MachineOverlay.res(MachineOverlay.M5X7) as Font
		_creature.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_creature.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_creature)

	func setup(p: Dictionary) -> void:
		size = Vector2(54, 18) * k
		symbol = str(p.get("symbol", ""))
		look = p.get("look", {}) if p.get("look") is Dictionary else {}
		_creature.texture = CasinoPot.creature_tex(look)
		_creature.size = Vector2(16, 16) * k
		_creature.position = Vector2(2, 1) * k
		_creature.pivot_offset = Vector2(8, 16) * k
		_creature.visible = symbol != ""
		queue_redraw()

	func creature_global() -> Vector2:
		return _creature.get_global_transform() * (Vector2(8, 8) * k)

	## The jar poured into it: the creature swells with the light, then settles.
	func swell_up() -> void:
		var tw := _creature.create_tween()
		tw.tween_property(_creature, "scale", Vector2(1.7, 1.7), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(self, "swell", 1.0, 0.25)
		tw.tween_interval(0.4)
		tw.tween_property(_creature, "scale", Vector2(1.15, 1.15), 0.4).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(self, "swell", 0.0, 0.6)
		await tw.finished

	func _process(delta: float) -> void:
		_t += delta
		if swell > 0.0:
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var blank := symbol == ""
		if swell > 0.0:
			CasinoPot.soft(self, Vector2(10, 9) * k, CasinoPot.GOLD, 26.0 * k * (0.6 + swell), swell * 2.0)
		var face := CasinoPot.BRASS.darkened(0.45) if blank else CasinoPot.BRASS
		draw_rect(r, CasinoPot.BRASS_DARK)
		draw_rect(r.grow(-1), face)
		draw_rect(Rect2(1, 1, size.x - 2, 1), face.lightened(0.35))
		draw_rect(Rect2(1, size.y - 2, size.x - 2, 1), face.darkened(0.3))
		for x: float in [3.0 * k, size.x - 3.0 * k]:
			draw_circle(Vector2(x, size.y / 2.0) if blank else Vector2(x, 3.0 * k), 1.0 * k, CasinoPot.BRASS_DARK)
		if blank:
			return
		var fs := 16 if k >= 1.0 else 8
		draw_string(_font, Vector2(19.0 * k, size.y - 5.0 * k), symbol, HORIZONTAL_ALIGNMENT_LEFT, size.x - 21.0 * k, fs, Palette.NIGHT)
