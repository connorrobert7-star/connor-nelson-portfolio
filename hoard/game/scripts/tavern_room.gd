class_name TavernRoom
extends Room
## Inside the tavern. Bess runs the bar; the room fills with last week's visits.

const BESS := Vector2i(3, 2)
const SEATS: Array[Vector2i] = [
	Vector2i(4, 6), Vector2i(6, 6), Vector2i(9, 6), Vector2i(11, 6),
	Vector2i(4, 8), Vector2i(6, 8), Vector2i(9, 8), Vector2i(11, 8),
]


func _init() -> void:
	map = [
		"WWWWWWWWWWWWWWWW",
		"WwwwwwwwwwwwwwwW",
		"WffffffffffffffW",
		"WccccccffffffffW",
		"WffffffffffffffW",
		"WffffffffffffffW",
		"WfffftfffftffffW",
		"WffffffffffffffW",
		"WfffftfffftffffW",
		"WffffffffffffffW",
		"WWWWWWWddWWWWWWW",
	]


func build() -> void:
	super.build()
	add_npc("tavern_keeper", BESS, Vector2i(3, 4))
	place(preload("res://art/fireplace.png"), Rect2i(12, 0, 2, 2))
	add_zone(Rect2i(1, 4, 14, 6), _room_note, 0)


func dress() -> void:
	var tavern: Dictionary = Game.state.tavern
	var packed: bool = tavern.state == "packed"
	for i in mini(int(tavern.visits), SEATS.size()):
		var s := Sprite2D.new()
		s.texture = preload("res://art/villager.png")
		s.hframes = 2
		s.frame = 1 if packed else 0
		s.offset = Vector2(0, -8)
		s.position = feet_at(SEATS[i])
		dynamic.add_child(s)


func _room_note() -> String:
	var t: Dictionary = Game.state.tavern
	return "%d of last week's meals out are sitting here. %s of %s." % [
		int(t.visits), c(t.spent_cents), c(t.budget_cents)
	]
