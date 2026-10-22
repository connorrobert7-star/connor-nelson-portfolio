class_name StatsOverlay
extends Overlay
## The ledger stone, read up close: the one place in the game with a table of numbers.
## Every figure comes from Game.state as the backend computed it; nothing is worked out here.
## Opened by tapping the ledger stone in the square.
##
## A carved slab rises out of the ground with one page at a time behind three stone tabs:
## money (a coin), the bills and the long run (a scroll), and the week's ledger (a book).
## Tap a tab for its page, tap the slab itself for the next one, tap off the slab (or the
## close button, or Esc) and it sinks back. Columns have fixed widths: names cut with an
## ellipsis, amounts right-aligned, 8 px between them.

const SLAB := VillageArt.PACKS + "tiopalada-dark-dwellers-gui/20251029darkDwellers9SlicesA.png"
const HEADER := VillageArt.PACKS + "tiopalada-dark-dwellers-gui/20251117darkDwellersHeaderC.png"
const CLOSE := VillageArt.PACKS + "tiopalada-dark-dwellers-gui/20251125closeButton1-Sheet.png"
const ICONS := VillageArt.PACKS + "kyrise-rpg-icons-16/icons/16x16/"
const TAB_ICONS := ["coin_05a.png", "scroll_01a.png", "book_02a.png"]
## The slab and its two columns, in screen pixels.
const SLAB_RECT := Rect2(40, 34, 400, 222)
const PAD := 14.0
const COL_W := 178.0
const GUTTER := 16.0
const AMOUNT_W := 64.0
const GAP := 8.0
const LINE := 10.0
const MAX_ROWS := 17
const SND_STONE := "kenney-impact-sounds/Audio/impactMining_00%d.ogg"
const SND_RISE := "kenney-impact-sounds/Audio/impactPlate_heavy_001.ogg"

var close_button: TextureButton
var page := 0
var _root := Control.new()  # the slab and everything on it; rises and sinks as one
var _slab := NinePatchRect.new()
var _pages: Array[Control] = []
var _tabs: Array[Tab] = []
var _ls: LabelSettings
var _ls_head: LabelSettings
var _ls_dim: LabelSettings
var _ls_out: LabelSettings


## A stone tab with an icon: raised and lit when its page is up.
class Tab extends Control:
	signal tapped
	var icon: Texture2D
	var active := false
	var hover := false
	var lift := 0.0
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func() -> void:
			hover = true
			Sfx.ui("hover")
		)
		mouse_exited.connect(func() -> void: hover = false)

	func _gui_input(event: InputEvent) -> void:
		if Level._is_tap(event):
			accept_event()
			tapped.emit()

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var up := roundf(lift + (3.0 if active else 0.0) + (1.0 if hover and not active else 0.0))
		var r := Rect2(0, 4 - up, size.x, size.y - 4 + up)
		var stone := Color(0.58, 0.54, 0.66) if active else Color(0.36, 0.33, 0.42)
		HudPurse.plate(self, r, stone)
		var c := Vector2(roundf(size.x / 2.0), roundf(r.position.y + 11))
		if active:
			# The lit tab: a soft glow behind its icon that breathes.
			var a := 0.18 + 0.06 * sin(_t * 3.0)
			draw_circle(c, 9.0, Color(Palette.GLOW, a))
		draw_texture(icon, c - Vector2(8, 8), Color.WHITE if active else Color(0.62, 0.58, 0.7))


func _ready() -> void:
	add_backdrop(0.82)
	_ls = _settings(VillageArt.FONT_TABLE, 16, VillageArt.BONE)
	_ls_dim = _settings(VillageArt.FONT_TABLE, 16, Palette.MUTED)
	_ls_out = _settings(VillageArt.FONT_TABLE, 16, Color("ff9a8a"))
	_ls_head = _settings(VillageArt.FONT_PRICE, 10, Palette.GLOW.lerp(VillageArt.BONE, 0.5))
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	# Tabs first, so the slab's top edge overlaps their feet.
	for i in TAB_ICONS.size():
		var t := Tab.new()
		t.icon = VillageArt.sheet(ICONS + str(TAB_ICONS[i]))
		t.position = Vector2(SLAB_RECT.position.x + 14 + i * 40, SLAB_RECT.position.y - 22)
		t.size = Vector2(36, 28)
		t.tapped.connect(func() -> void: show_page(i))
		_root.add_child(t)
		_tabs.append(t)
	_slab.texture = VillageArt.sheet(SLAB)
	_slab.modulate = Color(0.5, 0.47, 0.58)
	_slab.patch_margin_left = 12
	_slab.patch_margin_right = 12
	_slab.patch_margin_top = 12
	_slab.patch_margin_bottom = 12
	_slab.position = SLAB_RECT.position
	_slab.size = SLAB_RECT.size
	_slab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_slab)
	_carve()
	for i in 3:
		var p := Control.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.visible = false
		_root.add_child(p)
		_pages.append(p)
	_fill_money(_pages[0])
	_fill_bills(_pages[1])
	_fill_week(_pages[2])
	close_button = TextureButton.new()
	close_button.texture_normal = VillageArt.tex(CLOSE, Rect2(0, 0, 32, 32))
	close_button.texture_hover = VillageArt.tex(CLOSE, Rect2(32, 0, 32, 32))
	close_button.texture_pressed = VillageArt.tex(CLOSE, Rect2(64, 0, 32, 32))
	close_button.position = SLAB_RECT.end * Vector2(1, 0) + Vector2(-26, SLAB_RECT.position.y - 8)
	close_button.pressed.connect(_close)
	_root.add_child(close_button)
	show_page(0, false)
	_rise()


func _settings(path: String, size: int, color: Color) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font = VillageArt.font(path)
	ls.font_size = size
	ls.font_color = color
	ls.line_spacing = 0
	return ls


## Chisel marks on the slab: a groove down the middle between the two columns.
func _carve() -> void:
	var groove := ColorRect.new()
	groove.color = Color(0.03, 0.02, 0.06, 0.45)
	groove.position = Vector2(SLAB_RECT.position.x + PAD + COL_W + GUTTER / 2.0 - 1, SLAB_RECT.position.y + 16)
	groove.size = Vector2(1, SLAB_RECT.size.y - 32)
	groove.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(groove)
	var lit := ColorRect.new()
	lit.color = Color(1, 1, 1, 0.06)
	lit.position = groove.position + Vector2(1, 0)
	lit.size = groove.size
	lit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(lit)


## The slab rises out of the ground in whole pixels with a little overshoot and a thud.
func _rise() -> void:
	VillageArt.sfx(SND_RISE, 0.6, -10)
	VillageArt.sfx("kenney-rpg-audio/Audio/bookOpen.ogg", 0.8, -10)
	_root.modulate.a = 0.0
	_root.position.y = 36.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_root, "modulate:a", 1.0, 0.1)
	tw.tween_method(func(v: float) -> void: _root.position.y = roundf(v), 36.0, 0.0, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Grit shaken off the stone as it lands.
	var dust := CPUParticles2D.new()
	dust.position = Vector2(SLAB_RECT.get_center().x, SLAB_RECT.end.y)
	dust.amount = 18
	dust.lifetime = 0.7
	dust.one_shot = true
	dust.explosiveness = 0.9
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(SLAB_RECT.size.x / 2.0, 2)
	dust.direction = Vector2(0, -1)
	dust.spread = 70.0
	dust.initial_velocity_min = 10.0
	dust.initial_velocity_max = 30.0
	dust.gravity = Vector2(0, 40)
	dust.color = Color(Palette.MUTED, 0.7)
	add_child(dust)
	var go := get_tree().create_timer(0.24)
	go.timeout.connect(func() -> void:
		if is_instance_valid(dust):
			dust.emitting = true
	)


## Bring a page up: its tab rises and lights, its rows tick on top to bottom.
func show_page(i: int, sound := true) -> void:
	page = posmod(i, _pages.size())
	if sound:
		VillageArt.sfx(SND_STONE % (page % 5), 1.3 + page * 0.08, -14)
	for k in _pages.size():
		_pages[k].visible = k == page
		_tabs[k].active = k == page
	var tab := _tabs[page]
	tab.lift = 3.0
	tab.create_tween().tween_property(tab, "lift", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var rows := _pages[page].get_children()
	for j in rows.size():
		var r := rows[j] as CanvasItem
		r.modulate.a = 0.0
		var rt := r.create_tween()
		rt.tween_interval(0.04 + j * 0.006)
		rt.tween_property(r, "modulate:a", 1.0, 0.08)


func _gui_input(event: InputEvent) -> void:
	if not Level._is_tap(event):
		return
	accept_event()
	var at: Vector2 = (event as InputEventMouseButton).position if event is InputEventMouseButton else (event as InputEventScreenTouch).position
	if SLAB_RECT.has_point(at - _root.position):
		show_page(page + 1)
	else:
		_close()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_close()
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		show_page(page + 1)
	elif event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		show_page(page - 1)


## The slab sinks back into the ground as the screen goes.
func _close() -> void:
	VillageArt.sfx("kenney-rpg-audio/Audio/bookClose.ogg", 1.0, -8)
	VillageArt.sfx(SND_RISE, 0.5, -14)
	var tw := _root.create_tween()
	tw.tween_method(func(v: float) -> void: _root.position.y = roundf(v), _root.position.y, _root.position.y + 24.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	close(null)


# --- the pages ----------------------------------------------------------------------------

## Column x positions on the slab.
func _col(c: int) -> float:
	return SLAB_RECT.position.x + PAD + c * (COL_W + GUTTER)


func _top() -> float:
	return SLAB_RECT.position.y + PAD


## Money now, debts, and how the week's extra is worked out.
func _fill_money(p: Control) -> void:
	var s := Game.state
	var bal: Dictionary = s.get("balances", {})
	var y := _top()
	y = _head(p, 0, y, "Money now")
	for a: Dictionary in s.get("accounts", []):
		y = _row(p, 0, y, str(a.name), _m(bal.get(a.id, a.balance_cents)))
	y = _head(p, 0, y + 4, "Debts")
	for d: Dictionary in s.get("debts", []):
		y = _row(p, 0, y, str(d.name), _m(bal.get(d.id, d.balance_cents)))
		y = _row(p, 0, y, "  %s%% apr, min %s" % [str(d.apr), _m(d.min_payment_cents)], "", _ls_dim)
	var e: Dictionary = s.get("extra", {})
	y = _top()
	y = _head(p, 1, y, "Extra this week")
	y = _row(p, 1, y, "Checking", _m(e.get("checking_cents", 0)))
	y = _row(p, 1, y, "Bills due soon", "-" + _m(e.get("bills_due_cents", 0)), _ls_out)
	y = _row(p, 1, y, "Floor kept", "-" + _m(e.get("floor_cents", 0)), _ls_out)
	y = _row(p, 1, y, "Food and roads", "-" + _m(e.get("avg_weekly_food_transport_cents", 0)), _ls_out)
	y = _rule(p, 1, y)
	y = _row(p, 1, y, "Extra", _m(maxi(0, int(e.get("extra_cents", 0)))))
	y = _row(p, 1, y, "Can move today", _m(s.get("caps_remaining_cents", 0)), _ls_dim)
	y = _row(p, 1, y + 6, "Coins", _n(int(s.get("coins", 0))))


## The next two weeks of bills, the life clock, the house, the wall and the flock.
func _fill_bills(p: Control) -> void:
	var s := Game.state
	var e: Dictionary = s.get("extra", {})
	var y := _top()
	y = _head(p, 0, y, "Bills, next two weeks")
	for b: Dictionary in (e.get("bills", []) as Array).slice(0, MAX_ROWS - 2):
		y = _row(p, 0, y, "%s %s" % [Main._day(str(b.due)), str(b.merchant)], _m(b.amount_cents))
	y = _top()
	var life: Dictionary = s.get("life", {})
	if not life.is_empty():
		y = _head(p, 1, y, "Life")
		y = _row(p, 1, y, "Level", "%d of 100" % int(life.level))
		y = _row(p, 1, y, "Age", "%.1f" % float(life.age_years))
		y = _row(p, 1, y, "Days left", _n(int(life.days_left)))
		y = _row(p, 1, y, "Hour of work", _m(s.get("hourly_rate_cents", 0)), _ls_dim)
	var v: Dictionary = s.get("village", {})
	if not v.is_empty():
		var h: Dictionary = v.house
		y = _head(p, 1, y + 4, "House and wall")
		y = _row(p, 1, y, "House Fund", _m(h.balance_cents))
		var stage := "%s, done" % str(h.stage.name) if h.next == null else "%s to %s" % [_m(h.next.to_go_cents), str(h.next.name).to_lower()]
		y = _row(p, 1, y, "  " + stage, "", _ls_dim)
		y = _row(p, 1, y, "  Goal", _m(h.goal_cents), _ls_dim)
		var w: Dictionary = v.wall
		y = _row(p, 1, y, "Emergency Fund", _m(w.balance_cents))
		y = _row(p, 1, y, "  %.1f of %d months" % [float(w.months_covered), int(w.months)], "", _ls_dim)
		var st: Dictionary = v.stats
		var faith: String = s.get("followers", {}).get("faith", {}).get("band", st.faith_band)
		var days: Variant = st.days_since_landing
		y = _row(p, 1, y + 4, "Faith", str(faith))
		y = _row(p, 1, y, "Since money landed", "-" if days == null else "%s d" % str(days), _ls_dim)


## The week's ledger: in and out, then every line, newest last, over both columns.
func _fill_week(p: Control) -> void:
	var s := Game.state
	var win: Dictionary = s.get("window", {})
	var wk: Dictionary = s.get("week", {})
	var y := _top()
	y = _head(p, 0, y, "Week of %s" % Main._day(str(win.get("start", s.get("today", "")))))
	y = _row(p, 0, y, "In", _m(wk.get("in_cents", 0)))
	y = _row(p, 0, y, "Out", "-" + _m(wk.get("out_cents", 0)), _ls_out)
	y = _rule(p, 0, y)
	var txns: Array = wk.get("transactions", [])
	var first_col := MAX_ROWS - 3
	var room := first_col + MAX_ROWS
	var shown := txns.slice(maxi(0, txns.size() - room))
	var col := 0
	var col_y := y
	for i in shown.size():
		if col == 0 and i == first_col:
			col = 1
			col_y = _top()
		var t: Dictionary = shown[i]
		var amt := int(t.amount_cents)
		var label := "%s %s" % [Main._day(str(t.date)).split(" ")[1], str(t.merchant)]
		col_y = _row(p, col, col_y, label, ("+" if amt < 0 else "-") + _m(absi(amt)), _ls if amt < 0 else _ls_out)
	if txns.size() > shown.size():
		_row(p, col, col_y, "and %d earlier" % (txns.size() - shown.size()), "", _ls_dim)


func _head(p: Control, c: int, y: float, text: String) -> float:
	var x := _col(c)
	var l := Label.new()
	l.label_settings = _ls_head
	l.text = text
	l.position = Vector2(x, y - 2)
	l.size = Vector2(COL_W, 12)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	_rule(p, c, y + 9)
	return y + 14.0


## A carved line across a column.
func _rule(p: Control, c: int, y: float) -> float:
	var rule := TextureRect.new()
	rule.texture = VillageArt.tex(HEADER, Rect2(30, 14, 36, 2))
	rule.stretch_mode = TextureRect.STRETCH_SCALE
	rule.position = Vector2(_col(c), y)
	rule.size = Vector2(COL_W, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(rule)
	return y + 3.0


## One line: the name cut with an ellipsis at its width, the amount right-aligned in its own.
func _row(p: Control, c: int, y: float, left: String, right: String, ls: LabelSettings = null) -> float:
	var x := _col(c)
	var l := Label.new()
	l.label_settings = ls if ls else _ls
	l.text = left
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.position = Vector2(x, y)
	l.size = Vector2(COL_W - (AMOUNT_W + GAP if right != "" else 0.0), LINE + 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	if right != "":
		var r := Label.new()
		r.label_settings = ls if ls else _ls
		r.text = right
		r.position = Vector2(x + COL_W - AMOUNT_W, y)
		r.size = Vector2(AMOUNT_W, LINE + 2)
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(r)
	return y + LINE


static func _m(cents: Variant) -> String:
	return Money.fmt(int(cents))


static func _n(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out
