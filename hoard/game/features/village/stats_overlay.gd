class_name StatsOverlay
extends Overlay
## The ledger stone, read up close: the one place in the game with a table of numbers.
## Every figure comes from Game.state as the backend computed it; nothing is worked out here.
## Opened by tapping the ledger stone in the square. A tap anywhere (or Esc) closes it.

const SLAB := VillageArt.PACKS + "tiopalada-dark-dwellers-gui/20251029darkDwellers9SlicesA.png"
const HEADER := VillageArt.PACKS + "tiopalada-dark-dwellers-gui/20251117darkDwellersHeaderC.png"
const CLOSE := VillageArt.PACKS + "tiopalada-dark-dwellers-gui/20251125closeButton1-Sheet.png"
const COL_W := 148.0
const AMOUNT_W := 58.0
const LINE := 9.0
const MAX_LEDGER := 15

var _slab := NinePatchRect.new()
var _rows: Array[Control] = []
var _ls: LabelSettings
var _ls_head: LabelSettings
var _ls_dim: LabelSettings
var _ls_money: LabelSettings
var _ls_out: LabelSettings
var close_button: TextureButton


func _ready() -> void:
	add_backdrop(0.82)
	_ls = _settings(VillageArt.FONT_TABLE, 16, VillageArt.BONE)
	_ls_dim = _settings(VillageArt.FONT_TABLE, 16, Palette.MUTED)
	_ls_money = _settings(VillageArt.FONT_TABLE, 16, VillageArt.BONE)
	_ls_out = _settings(VillageArt.FONT_TABLE, 16, Color("ff9a8a"))
	_ls_head = _settings(VillageArt.FONT_PRICE, 10, VillageArt.BONE)
	_slab.texture = VillageArt.sheet(SLAB)
	_slab.modulate = Color(0.62, 0.55, 0.72)
	_slab.patch_margin_left = 12
	_slab.patch_margin_right = 12
	_slab.patch_margin_top = 12
	_slab.patch_margin_bottom = 12
	_slab.position = Vector2(6, 6)
	_slab.size = Vector2(468, 258)
	_slab.pivot_offset = _slab.size / 2.0
	_slab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_slab)
	_fill()
	close_button = TextureButton.new()
	close_button.texture_normal = VillageArt.tex(CLOSE, Rect2(0, 0, 32, 32))
	close_button.texture_hover = VillageArt.tex(CLOSE, Rect2(32, 0, 32, 32))
	close_button.texture_pressed = VillageArt.tex(CLOSE, Rect2(64, 0, 32, 32))
	close_button.position = Vector2(446, -4)
	close_button.scale = Vector2(0.75, 0.75)
	close_button.pressed.connect(_close)
	add_child(close_button)
	# The slab drops in, then the rows tick on.
	_slab.scale = Vector2(1.0, 0.2)
	_slab.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_slab, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(_slab, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	VillageArt.sfx("kenney-rpg-audio/Audio/bookOpen.ogg", 0.9, -6)
	for i in _rows.size():
		var r := _rows[i]
		r.modulate.a = 0.0
		var rt := r.create_tween()
		rt.tween_interval(0.12 + i * 0.004)
		rt.tween_property(r, "modulate:a", 1.0, 0.08)


func _settings(path: String, size: int, color: Color) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font = VillageArt.font(path)
	ls.font_size = size
	ls.font_color = color
	ls.line_spacing = 0
	return ls


func _gui_input(event: InputEvent) -> void:
	if Level._is_tap(event):
		accept_event()
		_close()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	VillageArt.sfx("kenney-rpg-audio/Audio/bookClose.ogg", 1.0, -6)
	close(null)


# --- the columns ----------------------------------------------------------------------

func _fill() -> void:
	var s := Game.state
	var bal: Dictionary = s.get("balances", {})
	var x := [14.0, 166.0, 318.0]
	var y := 14.0

	# Column one: money now, debts, and the week's extra.
	y = _head(x[0], y, "Money now")
	for a: Dictionary in s.get("accounts", []):
		y = _row(x[0], y, str(a.name), _m(bal.get(a.id, a.balance_cents)))
	y = _head(x[0], y + 3, "Debts")
	for d: Dictionary in s.get("debts", []):
		y = _row(x[0], y, str(d.name), _m(bal.get(d.id, d.balance_cents)))
		y = _row(x[0], y, "  %s%% apr, min %s" % [str(d.apr), _m(d.min_payment_cents)], "", _ls_dim)
	var e: Dictionary = s.get("extra", {})
	y = _head(x[0], y + 3, "Extra this week")
	y = _row(x[0], y, "Checking", _m(e.get("checking_cents", 0)))
	y = _row(x[0], y, "Bills due soon", "-" + _m(e.get("bills_due_cents", 0)), _ls_out)
	y = _row(x[0], y, "Floor kept", "-" + _m(e.get("floor_cents", 0)), _ls_out)
	y = _row(x[0], y, "Food and roads", "-" + _m(e.get("avg_weekly_food_transport_cents", 0)), _ls_out)
	y = _row(x[0], y, "Extra", _m(maxi(0, int(e.get("extra_cents", 0)))))
	y = _row(x[0], y, "Can move today", _m(s.get("caps_remaining_cents", 0)), _ls_dim)

	# Column two: bills, the life clock, house, wall and the flock.
	y = 14.0
	y = _head(x[1], y, "Bills, next two weeks")
	for b: Dictionary in e.get("bills", []).slice(0, 6):
		y = _row(x[1], y, "%s %s" % [Main._day(str(b.due)), str(b.merchant)], _m(b.amount_cents))
	var life: Dictionary = s.get("life", {})
	if not life.is_empty():
		y = _head(x[1], y + 3, "Life")
		y = _row(x[1], y, "Level", "%d of 100" % int(life.level))
		y = _row(x[1], y, "Age", "%.1f" % float(life.age_years))
		y = _row(x[1], y, "Days left", _n(int(life.days_left)))
		y = _row(x[1], y, "Hour of work", _m(s.get("hourly_rate_cents", 0)), _ls_dim)
	var v: Dictionary = s.get("village", {})
	if not v.is_empty():
		var h: Dictionary = v.house
		y = _head(x[1], y + 3, "House and wall")
		y = _row(x[1], y, "House Fund", _m(h.balance_cents))
		y = _row(x[1], y, "  %s, %s" % [str(h.stage.name), "done" if h.next == null else "%s to %s" % [_m(h.next.to_go_cents), str(h.next.name).to_lower()]], "", _ls_dim)
		y = _row(x[1], y, "Goal", _m(h.goal_cents), _ls_dim)
		var w: Dictionary = v.wall
		y = _row(x[1], y, "Emergency Fund", _m(w.balance_cents))
		y = _row(x[1], y, "  %.1f of %d months of costs" % [float(w.months_covered), int(w.months)], "", _ls_dim)
		var st: Dictionary = v.stats
		var faith: String = s.get("followers", {}).get("faith", {}).get("band", st.faith_band)
		var days: Variant = st.days_since_landing
		y = _row(x[1], y, "Faith", str(faith))
		y = _row(x[1], y, "Days since money landed", "-" if days == null else str(days), _ls_dim)
	y = _row(x[1], y, "Coins", _n(int(s.get("coins", 0))))

	# Column three: this week's ledger.
	y = 14.0
	var win: Dictionary = s.get("window", {})
	var wk: Dictionary = s.get("week", {})
	y = _head(x[2], y, "Week of %s" % Main._day(str(win.get("start", s.get("today", "")))))
	y = _row(x[2], y, "In", _m(wk.get("in_cents", 0)))
	y = _row(x[2], y, "Out", _m(wk.get("out_cents", 0)), _ls_out)
	var txns: Array = wk.get("transactions", [])
	var shown := txns.slice(maxi(0, txns.size() - MAX_LEDGER))
	for t: Dictionary in shown:
		var amt := int(t.amount_cents)
		var label := "%s %s" % [Main._day(str(t.date)).split(" ")[1], str(t.merchant)]
		y = _row(x[2], y, label, ("+" if amt < 0 else "") + _m(absi(amt)), _ls_money if amt < 0 else _ls_out)
	if txns.size() > shown.size():
		y = _row(x[2], y, "and %d earlier" % (txns.size() - shown.size()), "", _ls_dim)


func _head(x: float, y: float, text: String) -> float:
	var l := Label.new()
	l.label_settings = _ls_head
	l.text = text
	l.position = Vector2(x, y - 2)
	l.size = Vector2(COL_W, 12)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	var rule := TextureRect.new()
	rule.texture = VillageArt.tex(HEADER, Rect2(30, 14, 36, 2))
	rule.stretch_mode = TextureRect.STRETCH_SCALE
	rule.position = Vector2(x, y + 9)
	rule.size = Vector2(COL_W, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)
	_rows.append(l)
	_rows.append(rule)
	return y + 13.0


func _row(x: float, y: float, left: String, right: String, ls: LabelSettings = null) -> float:
	var l := Label.new()
	l.label_settings = ls if ls else _ls
	l.text = left
	l.clip_text = true
	l.position = Vector2(x, y)
	l.size = Vector2(COL_W - (AMOUNT_W + 2 if right != "" else 0), LINE + 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	_rows.append(l)
	if right != "":
		var r := Label.new()
		r.label_settings = ls if ls else _ls_money
		r.text = right
		r.position = Vector2(x + COL_W - AMOUNT_W, y)
		r.size = Vector2(AMOUNT_W, LINE + 2)
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(r)
		_rows.append(r)
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
