extends HoardFeature
## Buildings with tiers (docs/BUILDINGS.md). Owns no plot: the village calls it for the whole
## island. One BuildingSite per Village.BUILDING_PLOTS entry, plus one for the land, which
## stands by the next gated parcel's survey stake. Everything is lamps, numbers and taps.

var _sites: Dictionary = {}  # building id -> BuildingSite (for the village being shown)


func id() -> String:
	return "buildings"


func build_village(village: Level, _plot: Rect2i) -> void:
	_sites.clear()
	var plots := Village.building_plots()
	for bid: String in plots:
		var site := BuildingSite.new()
		site.building_id = bid
		site.plot = plots[bid]
		site.village = village
		village.props.add_child(site)
		_sites[bid] = site
		var p: Dictionary = plots[bid]
		village.add_interactable(p.sign_at + Vector2(0, -8), func() -> String: return "", site.tap_build)
		village.add_interactable(p.flag_at + Vector2(0, -8), func() -> String: return "", site.tap_flag)
		# The facade itself, a step above the door line (the house has its own pokes).
		if bid != "house":
			village.add_interactable(p.base + Vector2(0, -14), func() -> String: return "", site.tap_build)
	# The land: a sign by each gated parcel's rope line; only the next parcel's one shows.
	var land := BuildingSite.new()
	land.building_id = "land"
	land.village = village
	village.props.add_child(land)
	_sites["land"] = land
	for pid: String in Village.PARCELS:
		var spec: Dictionary = Village.PARCELS[pid]
		if spec.has("stake"):
			var at := BuildingSite.land_sign_at(pid)
			village.add_interactable(at + Vector2(0, -8), func() -> String: return "", land.tap_land.bind(pid))


func dress_village(village: Level, _plot: Rect2i) -> void:
	var b: Variant = Game.state.get("buildings")
	if not (b is Dictionary):
		return
	var by_id := {}
	for e: Dictionary in (b as Dictionary).get("list", []):
		by_id[e.id] = e
	for bid: String in _sites:
		var site: BuildingSite = _sites[bid]
		if not is_instance_valid(site):
			continue
		var e: Dictionary = by_id.get(bid, {})
		if bid != "land" and not e.is_empty():
			if not (village as Village).parcel_open(String(site.plot.get("parcel", "home"))):
				e = {}
		site.apply(e, b)
