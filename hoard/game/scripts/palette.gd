class_name Palette
## Shared colors for UI drawn in code. tools/art/palette.py holds the same values
## for generated sprites. Rarity colors are reserved for rarity.

const NIGHT := Color("120c18")
const INK := Color("1d1424")
const PANEL := Color("2a1d33")
const CREAM := Color("f6ead2")
const MUTED := Color("b9a7c4")
const BLOOD := Color("e0304e")
const BILE := Color("b6e04a")
const GLOW := Color("ffd166")
const TEAL := Color("2ec4b6")
const PINK := Color("ff6fb5")
## Play coins are brass; real money is bone. Never swap them.
const BRASS := Color("e8b04a")
const BONE := Color("f6ead2")

const COMMON := Color("9aa0a6")
const RARE := Color("3d8bff")
const EPIC := Color("a347ff")
const LEGENDARY := Color("ffb627")
const MYTHIC := Color("ff2e3a")

const RARITY := {
	"common": COMMON, "rare": RARE, "epic": EPIC, "legendary": LEGENDARY, "mythic": MYTHIC,
}
