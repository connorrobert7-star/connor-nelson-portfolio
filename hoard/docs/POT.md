# Piece 2: the pot (build contract)

Source: `docs/DESIGN_NOTES.md` (October 21, 2026, piece 2), on top of the casino (`docs/CASINO.md`).
Rules: `CLAUDE.md`, `docs/FEATURES.md`. No text panels, everything by click or tap.

## The rule, in one line

Every pull at the small machines moves its exact price into the Brokerage. Some pulls hit and most
don't. A losing pull's dollars wait in the pot as cash in the Brokerage. A hit spends the whole pot,
plus the winning pull's own price, on the stock the owner picked ahead of time at Marlo's counter,
and drops a cosmetic. The game never picks a stock and never sells anything. No coins move.

## Which machines

- **Pot machines**: the scratch booth (each price is its own run), the wheel, the claw.
- **Cases are unchanged**: every case still drops a cosmetic from the belt and the box, and the case
  overlay still lets the owner choose House Fund or Brokerage.
- Pot machines always pay into `brk_1`. Their `to_account` is fixed (a body that names another
  account is refused 422). The extra check, the caps and `move()` are unchanged (`docs/CASINO.md`).

## Hits: runs you can see

Each pot machine has a **run**: `size` lamps, exactly one of which is the hit, at a position drawn
when the run loads (secure RNG in production, like the belt). Each pull uses the next lamp. A blank
lamp goes dark. When the hit comes up, that run is over and a fresh run of `size` loads. So:

- A hit always comes within `size` pulls of the start of a run, and within the lamps still lit from
  any point. That is the pity, and it is on the machine for anyone to count.
- The chance on the next pull is exactly `1 / lamps left`. The dealer says it ("Five lamps. One
  lights.") the way he counts the belt now.
- Over many pulls a hit comes once every `(size + 1) / 2` pulls on average. Posted with the machine
  (`average_one_in`).

Run sizes (content, `content/casino/machines.json` → `pot.runs`):

| Machine | Price | Run size | Hit within | Average |
| --- | --- | --- | --- | --- |
| scratch | $1 | 8 | 8 | 1 in 4.5 |
| scratch | $2 | 6 | 6 | 1 in 3.5 |
| scratch | $5 | 5 | 5 | 1 in 3 |
| wheel | $5 | 6 | 6 | 1 in 3.5 |
| claw | $5 | 6 | 6 | 1 in 3.5 |

## The pot

- One pot for all pot machines. A blank pull adds its price to the pot. A hit adds its own price and
  then buys with all of it. The pot is a tally of cash that already landed in the Brokerage through
  `move()`; it never moves money itself and never lowers a balance.
- On a hit, the pot buys the owner's pick at this week's price (`shop.price_cents`, never a live
  price): an `orders` row `{symbol, amount_cents: pot, price_cents, qty: pot / price, transfer_id:
  the winning pull's transfer, created}` and a `casino_pot_buys` row for the history. The buy goes
  through `ctx.providers.brokerage.place_order(symbol, amount_cents)`: the fixture returns
  `{"status": "simulated"}`; the real SnapTrade stub raises `NotConfigured` (so in real mode the
  whole pull is refused and rolled back until trading is written). Then the pot is 0.
- **The pick**: `POST /shop/pick {symbol}` at Marlo's counter, any symbol the shop carries. It can
  change any time; it applies to the next hit. Without a pick, the pot machines refuse with 409
  "Pick a stock at Marlo's counter first." and nothing moves (checked before `move()`).
- The game never picks: there is no default pick, no random pick, and nothing ever sells.

## Cosmetics

Only a hit drops a cosmetic, and its tier comes from the machine's own load exactly as now: the
scratch book for that price, the wheel's wedges (a won wedge comes off until the wheel resets), the
claw's heap. Blank pulls don't touch those loads. The trade-up, the book and the draw are unchanged.

## API changes (`backend/features/casino/`, `backend/features/shop/`)

| Route | Body | Returns |
| --- | --- | --- |
| `POST /casino/scratch` | `price_cents` (to_account optional, must be `brk_1`) | `{money, hit, item?, tier?, symbols, run, pot}` |
| `POST /casino/wheel` | (to_account optional, must be `brk_1`) | `{money, hit, wedge_index?, tier?, item?, wedges, run, pot}` |
| `POST /casino/claw` | `drop_x` (to_account optional, must be `brk_1`) | `{money, hit, grabbed: {slot_index, tier, held}, item?, heap, run, pot}` |
| `POST /shop/pick` | `symbol` | `{pick: {symbol, name, creature}}` |

- `run`: `{size, left, average_one_in}` after this pull (a fresh run after a hit).
- `pot`: `{before_cents, added_cents, total_cents}` on a blank; on a hit also
  `bought: {symbol, amount_cents, price_cents, qty, status}` and `total_cents: 0`.
- Scratch blanks show nine symbols with no tier three times. The claw's blank is a grab that slips:
  `grabbed.held = false` names the piece it touched, which stays in the heap.
- The wheel on a blank lands on a dud sliver: `wedge_index` is null and `dud_index` names the sliver.

`GET /state` → `casino` gains:

```
pot: {total_cents, pick: {symbol, name, creature} | null, last_buy: {...} | null,
      buys: n, bought_cents: n},
runs: {scratch_100: {size, left, average_one_in}, scratch_200: ..., scratch_500: ...,
       wheel: ..., claw: ...},
```

and `shop` gains `pick`. `dealer.line` names the run and the pot when the owner looks at a pot
machine. Pot machines' `to_account` choice is gone from their overlays.

## Tests

Every pull moves exactly its price into `brk_1`, hit or blank; a blank grants nothing and leaves the
cosmetic loads untouched; the pot equals the sum of blank prices since the last hit; a hit records
exactly one buy of `pot + price` of the pick at the weekly price, through `place_order`, and resets
the pot; a run always holds exactly one hit and a hit always comes within `size` pulls; across
100,000 pulls the hit rate is `2 / (size + 1)` within tolerance; no pick means 409 and nothing moved;
a non-brokerage `to_account` means 422 and nothing moved; nothing ever sells or lowers a balance; no
pot route grants coins; the old tests for cases, books, the wheel and the claw keep passing where
their rules didn't change (update the ones the pot changes on purpose).

## Godot

- On each pot machine in the casino room: the run's lamps (lit, dark, and a warm one for the chance
  now) and the pot jar with the dollar number on it, filling as it grows. A small brass plate with
  the pick's ticker and its creature. With no pick, the plate is blank and Vex says where to go.
- Scratch blanks reveal no triple, the wheel's blank lands on a dud sliver, the claw's blank slips.
  Each blank: a coin drops into the pot jar (the money still landed; the jar is the Brokerage).
- A hit: the run's last lamp blazes, the jar tips and pours into the pick's creature, which swells,
  then the cosmetic reveal as now. It's the owner's own money; the moment is the jar pouring into
  their stock, not a cash prize.
- Marlo's counter: tap a stock to pin it as the pick (a brass plate drops onto it with a clunk). The
  pinned one stays marked.
- Every action by tap or click. No new panels or menus.
