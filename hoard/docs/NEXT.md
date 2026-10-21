# Next

What is written down but not built yet. The owner's own words for these are in
`docs/DESIGN_NOTES.md`. Nothing here is started.

## Piece 2: the pot (not built yet)

Stopped here to save credits. The full build contract is ready in `docs/POT.md`: scratch, wheel and
claw get blank pulls; each machine shows a run of lamps with exactly one hit (so a hit always comes
within the run, and the chance now is one in the lamps left); every pull's price still lands in the
Brokerage; blank pulls' dollars wait in one pot; a hit spends the whole pot (plus that pull) on the
stock picked ahead of time at Marlo's counter; cosmetics roll as now, on hits only. Start there.

## Piece 1: what was cut for time

Piece 1 shipped lean: the backend in full, the doubled island, and the building sites (signs with
requirement lamps, tap to build, scaffolding, the target banner). Not done yet:

- The two review passes (a rules critic and an owner playtest) did not run on the sites.
- The finished-building reveal is a short puff; the "while you were out" scene shows a
  `building_done` beat as a plain line of text (no custom renderer yet).
- The flock in the village is 9 cultists plus 2 per opened parcel; it should follow
  `buildings.capacity` (the backend's `followers.cultists` already does).
- `game/scripts/level.gd` still prefixes "E " on prompts outside the village (arcade "E Mine",
  shop and tavern "E Talk to ..."). Only the village hides them.
- Tours that need updating for the new map: `dev/tours/core_tour.gd` (old tiles), and the gate,
  minigames and casino room tours borrow empty corners that now overlap the shop (a free one is
  `Rect2i(34, 15, 5, 3)`).
- Followers' emote bubbles over the shrine can sit under the "next day" button.

## Piece 3 (the owner said: write it down, don't build it yet)

### Villagers that talk

Villagers talk to the owner and to each other. Their lines come from the numbers like now
(`backend/features/villagers/lines.py`, the dealer's counted lines in
`backend/features/casino/dealer.py`), plus:

- ambient chatter between villagers when the owner walks past (two speech bubbles trading lines),
- comments on what is being built (the crew, days left, a tier that just became ready on Sunday),
- the pot (how big it is, the lamps left on a machine, the last buy),
- the streak (pennants on the banner, a streak about to hit the discount, a streak that broke).

Every line still comes from the backend, which decides what is true; the game only draws bubbles.
Plain language, no exclamation points in the sermon.

### A history screen

On the first of every month, save a picture of the village and its numbers (balances, extra, debts,
tiers built, the pot, the life clock). A then-and-now view, so six months from now the owner can
look back at what they had. Open questions for when it's built: where the pictures live (the save,
or files next to it), and how the view is reached without a menu (a painting in the house, or the
ossuary).

### The grind

The village should feel earned. Minigames exist to serve the build (coins for construction); they
aren't the game. If something unlocks without saving for it, that's wrong. Things to look at when
this is built:

- The offering tablets restore the granary, ossuary and bell tower from behavior. Most sockets are
  saving behavior (deposits, a $250 week, a no-spend week, a debt payment), but one is "three
  minigame flames in a day", which unlocks a building without saving. Either move that socket to a
  saving behavior or make ruin restoration a building tier with balance requirements.
- The casino, the shop, the gate and the ruins have no tiers yet (piece 1 covers land, the house,
  the shrine, the arcade, the tavern and the lodge).
- Check that coin income (about 300 to 500 a day) against construction costs makes saving the
  pace-setter, not the arcade.

## Carried over from the last pass (not started)

- The 0x72 wizard as the leader everywhere (`wizzard_m`: idle at x128 y164, 16x28, four frames
  16 px apart; run at x192), not only in the minigames.
- The gate: a refused payment must not open the gate or spend the coin stack on screen (`_fire`
  spends and opens before `/gate/attack` answers); heal and bank-kill beats play twice;
  `/gate/seen` can return 500; platform toasts cut across the fight.
- The fixture bank keeps charging interest on a debt the gate killed.
- The HUD's "[ earlier" and "N next day" hints are keyboard words; week browsing has no tap
  version.
- The "next day" demo button draws over overlays.
- The casino feature draws a dark hall over the village's casino facade.
- A reduced-motion setting.
- README: the exact `.env` keys for Plaid, SnapTrade and Alpaca; refresh `CLAUDE.md` (its phases
  and shop rules are out of date).
- Real order placement: shop buys and pot buys are recorded and simulated; the SnapTrade trading
  call is a stub that raises `NotConfigured`.
