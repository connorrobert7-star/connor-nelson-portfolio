extends RefCounted
## The gate, played through the real UI by taps and holds only: the bosses smallest
## first with their real balances painted on, a payment that does exactly its dollars,
## a short tap that moves nothing, a refusal, the bank's hit and the monthly heal after
## days pass, then paying the card down until it dies and drops its mask.

var items: Array = []


func run(kit: TourKit) -> void:
	_register()
	Game.event_fired.connect(func(e: Dictionary) -> void:
		if str(e.get("kind", "")) == "item":
			items.append(e)
	)
	await kit.go_to("gate", Room.ENTRANCE)
	var gate := kit.level() as GateLevel
	if not kit.check(gate != null, "the gate opens as its own level"):
		return
	await kit.wait(0.5)
	await kit.shot("gate_01_arrive")
	await _settle(kit, gate)

	var bosses: Array = Game.state.gate.bosses
	kit.check(bosses.size() == 3, "three debts, three bosses")
	var hps: Array = bosses.map(func(b: Dictionary) -> int: return int(b.hp_cents))
	var sorted := hps.duplicate()
	sorted.sort()
	kit.check(hps == sorted, "smallest first")
	kit.check(gate.front_boss() and gate.front_boss().debt_id == "debt_card", "the card is in front")
	for b: Dictionary in bosses:
		var node := gate.boss_node(str(b.debt_id))
		kit.check(node != null and node.painted() == Money.fmt(int(b.hp_cents)), "%s has its real balance painted on (%s)" % [b.debt_id, Money.fmt(int(b.hp_cents))])
		kit.check(int(b.hp_cents) == int(Game.state.balances[b.debt_id]), "%s HP is the balance" % b.debt_id)
	kit.check(not kit.main.panel.visible, "no text panel at the gate")
	await kit.wait(3.2)
	await kit.shot("gate_02_hint")

	# Tap the card: it gets the reticle and the stacks come out.
	var card := gate.boss_node("debt_card")
	await kit.tap_world(card.chest())
	await kit.wait(0.6)
	kit.check(gate.mode() == GateLevel.Mode.AIM and gate.stacks() != null, "tapping the boss brings out the stacks")
	var amounts: Array = gate.stacks().amounts.map(func(a: Dictionary) -> int: return int(a.amount_cents))
	kit.check(amounts == [2500, 3500, 5000, 10000, 25000], "stacks: $25, the $35 minimum, $50, $100, $250 (%s)" % str(amounts))
	await kit.wait(1.4)
	await kit.shot("gate_03_aim")

	# A short tap on a stack moves nothing.
	var hp0 := int(_card().hp_cents)
	var extra0 := int(Game.state.extra.extra_cents)
	await _hold(kit, gate.stacks().stack_pos(2), 0.12)
	await kit.wait(0.5)
	await Game.refresh()
	kit.check(int(_card().hp_cents) == hp0 and int(Game.state.extra.extra_cents) == extra0, "a short tap moves nothing")

	# Hold the $50 stack: the strike goes, exactly $50 of damage.
	await _hold(kit, gate.stacks().stack_pos(2), 0.3, kit, "gate_04_charge")
	await kit.wait(0.35)
	await kit.shot("gate_05_motes")
	await kit.wait(0.55)
	await kit.shot("gate_06_hit")
	await kit.wait(0.25)
	await kit.shot("gate_07_hit_after")
	await _settle(kit, gate)
	kit.check(int(_card().hp_cents) == hp0 - 5000, "a $50 payment does exactly $50 of damage")
	kit.check(int(Game.state.extra.extra_cents) == extra0 - 5000, "and moves exactly $50 out of extra")
	kit.check(gate.boss_node("debt_card").painted() == Money.fmt(hp0 - 5000), "the painted balance drops to %s" % Money.fmt(hp0 - 5000))
	kit.check(int(Game.state.coins) == 0, "no coins for money")

	# $250, then $250 more is over today's cap: the gate stays shut.
	await _strike(kit, gate, 25000)
	var hp1 := int(_card().hp_cents)
	var extra1 := int(Game.state.extra.extra_cents)
	await _ensure_aim(kit, gate, "debt_card")
	var big := _stack_index(gate, 25000)
	kit.check(big >= 0 and not gate.stacks().affordable(big), "the $250 stack is dark once today's cap is near")
	await _hold(kit, gate.stacks().stack_pos(big), 0.6)
	await kit.until(func() -> bool: return gate.beat == "refused", 4.0)
	await kit.wait(0.15)
	kit.check(gate.beat == "refused", "the payment is refused")
	kit.check(gate.stacks() != null and gate.stacks()._stacks[big].scale.x > 0.9, "the refused stack stays where it is")
	kit.check(gate._gate_lift == 0.0, "the gate stays shut on a refusal")
	await kit.shot("gate_08_refused")
	await _settle(kit, gate)
	kit.check(int(_card().hp_cents) == hp1 and int(Game.state.extra.extra_cents) == extra1, "a refusal changes nothing")
	kit.check(gate.mode() == GateLevel.Mode.AIM and gate.stacks() != null and gate.stacks().amounts.size() > big, "after a refusal the same stacks stay out")

	# Days pass: the bank pays the card's minimum on its due day, and interest heals it.
	await kit.reset_to_village()
	await Game.advance_days(3)
	var heal: Variant = _card().get("heal")
	kit.check(heal is Dictionary and int(heal.amount_cents) > 0, "the card heals once on its due day")
	var bank_hits := (Game.state.away as Array).filter(func(a: Dictionary) -> bool: return str(a.kind) == "gate_hit")
	kit.check(bank_hits.size() == 1 and int(bank_hits[0].payload.amount_cents) == 3500, "the bank's $35 payment waits as an auto-attack")
	await kit.go_to("gate", Room.ENTRANCE)
	gate = kit.level() as GateLevel
	await kit.until(func() -> bool: return gate.beat == "heal", 8.0)
	await kit.wait(1.9)
	await kit.shot("gate_09_heal")
	await kit.until(func() -> bool: return gate.beat == "bank_hit", 8.0)
	await kit.wait(0.05)
	await kit.shot("gate_10_bank_hit")
	await _settle(kit, gate)
	await Game.refresh()
	kit.check(_card().get("heal") == null, "the heal played once and is marked seen")
	kit.check((Game.state.away as Array).filter(func(a: Dictionary) -> bool: return str(a.kind) == "gate_hit").is_empty(), "the bank's hit played and is marked seen")
	kit.check(gate.boss_node("debt_card").painted() == Money.fmt(int(_card().hp_cents)), "after the beats the bar shows the real balance")
	kit.check((Game.state.away as Array).filter(func(a: Dictionary) -> bool: return str(a.kind) == "gate_heal").is_empty(), "the heal played at the gate is gone from the away queue")
	# Out and back in: nothing plays twice.
	await kit.reset_to_village()
	await kit.go_to("gate", Room.ENTRANCE)
	gate = kit.level() as GateLevel
	var replayed := false
	for k in 90:
		replayed = replayed or gate.beat == "heal" or gate.beat == "bank_hit"
		await kit.frames(2)
	kit.check(not replayed, "walking out and back in doesn't replay the heal or the bank's hit")
	await _settle(kit, gate)

	# Pay the card down, a day at a time, until it dies.
	var day_button: Button = kit.main._day_button
	var shot_death := false
	for step in 30:
		var c := _card()
		if bool(c.defeated):
			break
		var pick := -1
		var best := 0
		for a: Dictionary in c.amounts:
			if bool(a.affordable) and int(a.amount_cents) > best:
				best = int(a.amount_cents)
				pick = int(a.amount_cents)
		if pick < 0:
			await kit.tap_control(day_button)
			await kit.wait(0.4)
			await _settle(kit, gate)
			continue
		var killing := pick == int(c.hp_cents)
		await _ensure_aim(kit, gate, "debt_card")
		var i := _stack_index(gate, pick)
		await _hold(kit, gate.stacks().stack_pos(i), 0.6)
		if killing:
			shot_death = true
			await kit.until(func() -> bool: return gate.beat == "death", 6.0)
			await kit.wait(0.45)
			await kit.shot("gate_11_death")
			await kit.wait(1.0)
			await kit.shot("gate_12_death_blast")
			await kit.until(func() -> bool: return gate.beat == "drop", 8.0)
			await kit.wait(1.1)
			await kit.shot("gate_13_drop")
		await _settle(kit, gate, 20.0)
	var dead := _card()
	kit.check(bool(dead.defeated) and int(dead.hp_cents) == 0, "the card is paid off")
	kit.check(shot_death, "the killing blow went through the gate")
	kit.check(dead.drop is Dictionary and str(dead.drop.id) == "gate_maw_mask", "it dropped the Maw Mask")
	var masks := items.filter(func(e: Dictionary) -> bool: return str(e.item_id) == "gate_maw_mask")
	kit.check(masks.size() == 1, "the mask was granted once")
	kit.check(gate.front_boss() and gate.front_boss().debt_id == "debt_car", "the car loan steps up")
	await kit.wait(0.8)
	await kit.shot("gate_14_next")

	# The plot in the village: the gatehouse, the smallest boss looming over it, its balance
	# on the lamp. (The village builder places the plot; this tries it on open ground.)
	await kit.reset_to_village()
	var village := kit.level()
	var f := GateFeature.new()
	var plot := Rect2i(31, 20, 6, 3)
	f.build_village(village, plot)
	f.dress_village(village, plot)
	await kit.stand(Vector2i(33, 24))
	await kit.wait(0.4)
	await kit.shot("gate_15_village_plot")
	var painted := village.dynamic.get_children().filter(func(n: Node) -> bool: return n is Label and (n as Label).text == Money.fmt(int(gate_front_hp())))
	kit.check(not painted.is_empty(), "the village gate's lamp shows the smallest debt's balance")


func gate_front_hp() -> int:
	for b: Dictionary in Game.state.gate.bosses:
		if not bool(b.defeated):
			return int(b.hp_cents)
	return 0


func _card() -> Dictionary:
	for b: Dictionary in Game.state.gate.bosses:
		if str(b.debt_id) == "debt_card":
			return b
	return {}


func _stack_index(gate: GateLevel, cents: int) -> int:
	if gate.stacks() == null:
		return -1
	for i in gate.stacks().amounts.size():
		if int(gate.stacks().amounts[i].amount_cents) == cents:
			return i
	return -1


## Tap the boss if it isn't already the target with stacks out.
func _ensure_aim(kit: TourKit, gate: GateLevel, debt_id: String) -> void:
	await _settle(kit, gate)
	if gate.mode() == GateLevel.Mode.AIM and gate.stacks() and gate.boss_node(debt_id) and gate.stacks().amounts == gate.boss_node(debt_id).data.amounts:
		return
	var node := gate.boss_node(debt_id)
	if node == null:
		return
	await kit.tap_world(node.chest())
	await kit.wait(0.5)


func _strike(kit: TourKit, gate: GateLevel, cents: int) -> void:
	await _ensure_aim(kit, gate, "debt_card")
	var i := _stack_index(gate, cents)
	if not kit.check(i >= 0, "a $%d stack" % (cents / 100)):
		return
	await _hold(kit, gate.stacks().stack_pos(i), 0.6)
	await _settle(kit, gate)


## Press and hold a point in the world, like a finger would, then let go.
func _hold(kit: TourKit, world_point: Vector2, seconds: float, shot_kit: TourKit = null, shot_name := "") -> void:
	var vp := kit.get_viewport()
	var screen := vp.get_screen_transform() * vp.get_canvas_transform() * world_point
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = screen
	down.global_position = screen
	Input.parse_input_event(down)
	if shot_kit:
		await kit.wait(seconds)
		await shot_kit.shot(shot_name)
		await kit.wait(0.3)
	else:
		await kit.wait(seconds)
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	Input.parse_input_event(up)
	await kit.frames(2)


## Wait until nothing is playing at the gate.
func _settle(kit: TourKit, gate: GateLevel, timeout := 14.0) -> void:
	await kit.until(func() -> bool:
		return not is_instance_valid(gate) or ((gate.mode() == GateLevel.Mode.IDLE or gate.mode() == GateLevel.Mode.AIM) and not Game.busy), timeout)
	await kit.wait(0.2)


static func _register() -> void:
	# The orchestrator adds the gate to features/manifest.gd at merge; until then the tour
	# registers it so kit.go_to("gate") finds the level.
	if Features.level_script("gate") == null:
		var f := GateFeature.new()
		Features.all.append(f)
		Features._levels.merge(f.levels())
