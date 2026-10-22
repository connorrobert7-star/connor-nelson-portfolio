extends RefCounted
## Playtest: the gate fight played like the owner on a phone, through real touches and
## holds (Godot makes a click from each touch too, like on the phone). After each step it
## checks the state: a payment does exactly its dollars, a lifted finger moves nothing, a
## refusal leaves everything where it was and the next stack still pays, taps during a beat
## are answered and never fire a second strike, the heal plays once, and paying the card off
## kills it, drops its mask, and leaves the next boss ready for a touch.
##   godot --path game res://dev/tour.tscn -- <out> res://features/gate/tour_play.gd

var kit: TourKit
var gate: GateLevel
var items: Array = []


func run(k: TourKit) -> void:
	kit = k
	Game.event_fired.connect(func(e: Dictionary) -> void:
		if str(e.get("kind", "")) == "item":
			items.append(e))
	await kit.go_to("gate", Room.ENTRANCE)
	gate = kit.level() as GateLevel
	if not kit.check(gate != null, "the gate opens"):
		return
	# A tap while the front boss introduces itself lands, and the intro still finishes.
	if await _poll(func() -> bool: return gate.mode() == GateLevel.Mode.SCENE, 4.0):
		var t := Time.get_ticks_msec()
		await touch(_world(Vector2(240, 90)))
		kit.check(_heard(t), "a tap during the intro is answered")
	await _settle()
	await _aim_and_pay()
	await _refusal()
	await _days_and_heal()
	await _kill()


func _aim_and_pay() -> void:
	var card := gate.boss_node("debt_card")
	await touch(_world(card.chest()))
	await kit.wait(0.5)
	kit.check(gate.mode() == GateLevel.Mode.AIM and gate.stacks() != null, "a touch on the card brings the stacks out")
	await touch(_world(card.chest()))
	await kit.wait(0.3)
	kit.check(gate.mode() == GateLevel.Mode.AIM and gate.stacks() != null, "a second touch on it keeps them out")
	var hp0 := _hp()
	var extra0 := int(Game.state.extra.extra_cents)
	# A finger lifted early moves nothing.
	var i := _stack(5000)
	var t := Time.get_ticks_msec()
	await hold(_world(gate.stacks().stack_pos(i)), 0.15)
	kit.check(_heard(t), "pressing a stack is answered at once")
	await kit.wait(0.4)
	kit.check(gate.mode() == GateLevel.Mode.AIM, "a lifted finger lets the charge go")
	await Game.refresh()
	kit.check(_hp() == hp0 and int(Game.state.extra.extra_cents) == extra0, "and moves nothing")
	# Held: the payment goes, once; taps during the strike only land.
	await hold(_world(gate.stacks().stack_pos(i)), 0.6)
	await kit.until(func() -> bool: return gate.mode() == GateLevel.Mode.STRIKE, 3.0)
	t = Time.get_ticks_msec()
	await touch(_world(gate.boss_node("debt_card").chest()))
	await touch(_world(Vector2(240, 250)))
	kit.check(_heard(t), "taps during the strike are answered")
	await _settle()
	await Game.refresh()
	kit.check(_hp() == hp0 - 5000, "the held $50 stack does exactly $50 (%d -> %d)" % [hp0, _hp()])
	kit.check(int(Game.state.extra.extra_cents) == extra0 - 5000, "and moves exactly $50, once")
	kit.check(gate.boss_node("debt_card").painted() == Money.fmt(_hp()), "the painted balance matches")
	await kit.shot("play_gate_paid")


func _refusal() -> void:
	await _aim("debt_card")
	await hold(_world(gate.stacks().stack_pos(_stack(25000))), 0.6)
	await _settle()
	await _aim("debt_card")
	var big := _stack(25000)
	var hp1 := _hp()
	var extra1 := int(Game.state.extra.extra_cents)
	await hold(_world(gate.stacks().stack_pos(big)), 0.6)
	await kit.until(func() -> bool: return gate.beat == "refused", 4.0)
	kit.check(gate.beat == "refused", "a payment over today's cap is refused")
	await _settle()
	await Game.refresh()
	kit.check(_hp() == hp1 and int(Game.state.extra.extra_cents) == extra1, "a refusal moves nothing")
	kit.check(gate.mode() == GateLevel.Mode.AIM and gate.stacks() != null, "the stacks stay out after a refusal")
	kit.check(not Game.busy, "and nothing is left waiting")
	await kit.shot("play_gate_refused")
	# The next stack that fits still pays.
	var ok := -1
	for j in gate.stacks().amounts.size():
		if gate.stacks().affordable(j):
			ok = j
	if ok >= 0:
		var cents := gate.stacks().amount(ok)
		await hold(_world(gate.stacks().stack_pos(ok)), 0.6)
		await _settle()
		await Game.refresh()
		kit.check(_hp() == hp1 - cents, "after a refusal the next stack that fits pays ($%d)" % (cents / 100))


func _days_and_heal() -> void:
	# The dial lets days pass right here; the card's due day brings the heal and the bank's hit.
	var heal_seen := false
	var tapped := false
	for d in 4:
		await _settle()
		await kit.until(func() -> bool: return kit.main._day_button.visible, 5.0)
		var day := str(Game.state.today)
		await touch(_ctl(kit.main._day_button))
		await kit.until(func() -> bool: return str(Game.state.today) != day, 8.0)
		for f in 120:
			if gate.beat == "heal":
				heal_seen = true
				if not tapped:
					tapped = true
					var t := Time.get_ticks_msec()
					await touch(_world(Vector2(240, 120)))
					kit.check(_heard(t), "a tap during the heal is answered")
			await kit.frames(1)
		if heal_seen:
			break
	await _settle(20.0)
	if not heal_seen:
		# The beats wait for the next visit when the days pass elsewhere.
		await kit.reset_to_village()
		await kit.go_to("gate", Room.ENTRANCE)
		gate = kit.level() as GateLevel
		heal_seen = await _poll(func() -> bool: return gate.beat == "heal", 10.0)
		await _settle(20.0)
	kit.check(heal_seen, "interest heals the card on its due day, in the open")
	await Game.refresh()
	kit.check(_card().get("heal") == null, "the heal is marked seen")
	kit.check(gate.boss_node("debt_card").painted() == Money.fmt(_hp()), "the bar shows the real balance after the beats")
	await _aim("debt_card")
	kit.check(gate.mode() == GateLevel.Mode.AIM, "after the heal a touch on the card still aims")
	# Out and back in: the heal doesn't play twice.
	await kit.reset_to_village()
	await kit.go_to("gate", Room.ENTRANCE)
	gate = kit.level() as GateLevel
	var again := false
	for f in 90:
		again = again or gate.beat == "heal"
		await kit.frames(2)
	kit.check(not again, "walking out and back in doesn't replay the heal")
	await _settle()


func _kill() -> void:
	var died := false
	for step in 40:
		var c := _card()
		if bool(c.get("defeated", false)):
			break
		var pick := -1
		for a: Dictionary in c.amounts:
			if bool(a.affordable) and int(a.amount_cents) > pick:
				pick = int(a.amount_cents)
		if pick < 0:
			await _settle()
			await kit.until(func() -> bool: return kit.main._day_button.visible, 5.0)
			var day := str(Game.state.today)
			await touch(_ctl(kit.main._day_button))
			await kit.until(func() -> bool: return str(Game.state.today) != day, 8.0)
			await _settle(20.0)
			continue
		var killing := pick == int(c.hp_cents)
		await _aim("debt_card")
		var i := _stack(pick)
		if i < 0:
			continue
		await hold(_world(gate.stacks().stack_pos(i)), 0.6)
		if killing:
			await kit.until(func() -> bool: return gate.beat == "death", 6.0)
			died = gate.beat == "death"
			await touch(_world(Vector2(240, 120)))
			await kit.until(func() -> bool: return gate.beat == "drop", 10.0)
			await kit.wait(1.2)
			await kit.shot("play_gate_drop")
		await _settle(25.0)
	await Game.refresh()
	kit.check(died and bool(_card().get("defeated", false)), "paying the card off kills it")
	var masks := items.filter(func(e: Dictionary) -> bool: return str(e.get("item_id", "")) == "gate_maw_mask")
	kit.check(masks.size() == 1, "its mask drops once")
	await kit.until(func() -> bool: return _toast("item"), 4.0)
	kit.check(_toast("item"), "the mask shows as a plate")
	var front := gate.front_boss()
	kit.check(front != null and front.debt_id != "debt_card", "the next boss steps up")
	if front:
		await touch(_world(front.chest()))
		await kit.wait(0.5)
		kit.check(gate.mode() == GateLevel.Mode.AIM and gate.stacks() != null, "and a touch on it brings the stacks out")
	await kit.shot("play_gate_next")


# --- helpers ---------------------------------------------------------------------------

## Wait for something that may not happen (no failure if it doesn't).
func _poll(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while not cond.call():
		if t > timeout:
			return false
		await kit.frames(1)
		t += kit.get_process_delta_time()
	return true


func _aim(debt_id: String) -> void:
	await _settle()
	var node := gate.boss_node(debt_id)
	if node == null:
		return
	if gate.mode() == GateLevel.Mode.AIM and gate.stacks() and gate.stacks().amounts == node.data.amounts:
		return
	await touch(_world(node.chest()))
	await kit.wait(0.5)


func _settle(timeout := 14.0) -> void:
	await kit.until(func() -> bool:
		return not is_instance_valid(gate) or ((gate.mode() == GateLevel.Mode.IDLE or gate.mode() == GateLevel.Mode.AIM) and not Game.busy), timeout)
	await kit.wait(0.2)


func _stack(cents: int) -> int:
	if gate.stacks() == null:
		return -1
	for i in gate.stacks().amounts.size():
		if int(gate.stacks().amounts[i].amount_cents) == cents:
			return i
	return -1


func _card() -> Dictionary:
	for b: Dictionary in Game.state.gate.bosses:
		if str(b.debt_id) == "debt_card":
			return b
	return {}


func _hp() -> int:
	return int(_card().get("hp_cents", -1))


func _toast(kind: String) -> bool:
	for c in kit.main._toasts.get_children():
		if c is Toast and (c as Toast).kind == kind:
			return true
	return false


func _heard(since: int) -> bool:
	for p: Variant in Sfx._started:
		if int(Sfx._started[p]) >= since:
			return true
	return false


# --- input, the way a phone sends it ---------------------------------------------------

func touch(p: Vector2) -> void:
	await hold(p, 0.0)


func hold(p: Vector2, seconds: float) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = true
	ev.position = p
	Input.parse_input_event(ev)
	await kit.frames(1)
	if seconds > 0.0:
		await kit.wait(seconds)
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = p
	Input.parse_input_event(up)
	await kit.frames(2)


func _world(p: Vector2) -> Vector2:
	var vp := kit.get_viewport()
	return vp.get_screen_transform() * vp.get_canvas_transform() * p


func _ctl(c: Control) -> Vector2:
	return kit.get_viewport().get_screen_transform() * c.get_global_rect().get_center()
