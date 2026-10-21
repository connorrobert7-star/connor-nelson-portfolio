extends HoardFeature
## The village hub (Step 5). The map itself is scripts/village.gd; this feature holds its
## pieces: the house (VillageHouse), the wall (VillageWall), the ruins and their offering
## tablets (VillageRuin), the square's cultists (VillageCultist), the ledger stone's
## StatsOverlay, and the art helpers (VillageArt). The backend is backend/features/village.
## It owns no plot: the hub draws the plots other features own and opens their doors.


func id() -> String:
	return "village"
