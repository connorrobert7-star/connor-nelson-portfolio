class_name CaseOverlay
extends Overlay
## STUB until its builder replaces it. Closes right away with null.

var case_id := ""


func _init(id: String = "") -> void:
	super._init()
	case_id = id


func _ready() -> void:
	close.call_deferred(null)
