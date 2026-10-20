class_name HoardFeature
extends RefCounted
## One per game/features/<id>/feature.gd, listed in game/features/manifest.gd.
## Override what the feature needs; everything defaults to "nothing".


## Matches backend/features/<id>/ and tools/art/<id>.py.
func id() -> String:
	return ""


## Places this feature adds: level_id -> a script that extends Level (or Room).
func levels() -> Dictionary:
	return {}


## Villagers this feature adds: npc_id -> {"texture": Texture2D, "frame": int, "hframes": int}.
## Their lines come from state.dialogue[npc_id] = {name, lines}.
func npcs() -> Dictionary:
	return {}


## The reserved village plot this feature owns (see scripts/village.gd PLOTS), or "".
func plot_id() -> String:
	return ""


## The level the plot's door leads into, or "" if the plot has no door.
func door_level() -> String:
	return ""


## Draw on the owned plot. Called on every state change; add nodes to village.dynamic
## (cleared each time) or village.props (kept). Use village.block()/add_npc()/
## add_interactable()/add_zone() only from build_village(), which runs once.
func dress_village(_village: Level, _plot: Rect2i) -> void:
	pass


## Runs once when the village is built: static sprites, NPCs, interactables, zones.
func build_village(_village: Level, _plot: Rect2i) -> void:
	pass
