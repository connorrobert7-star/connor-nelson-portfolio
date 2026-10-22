extends HoardFeature
## Pip, the owner's familiar (backend/features/helper, content/helper/lines.json). He has no
## place of his own: every level hosts him (Level._ready -> HelperFamiliar.join), so he
## follows the wizard everywhere. See familiar.gd.


func id() -> String:
	return "helper"
