# Design notes from the owner

Ideas as the owner gave them, kept close to their words so nothing gets lost. Build contracts live
in their own docs (`docs/BUILDINGS.md`, `docs/POT.md`); what is not built yet is in `docs/NEXT.md`.

## October 21, 2026

"The game feels really good so far. I can see this being great. Keep going in this direction."

Order: build 1, then 2. Write 3 into NEXT.md and don't build it yet. Commit after each piece.

### 1. Buildings that are worth saving for

This is the big one. Not just buildings: upgrades, and the upgrades are the thing being saved toward.

- Every building has tiers. Each tier has requirements across the real accounts, not just one.
  Example: Shrine tier 2 needs $2,000 in savings and $1,000 in brokerage and a 4-week deposit
  streak. Requirements are balances the owner has to hold, checked at the Sunday sync. They don't
  get spent.
- Once the requirements are met, construction costs coins and takes real days to finish. The owner
  should see it go up over the week. Nothing speeds it up for money.
- Streak discount. The owner picks one building as the target. Every consecutive week they deposit
  toward it, the streak grows. At 6 weeks the requirements for that building drop 20%. Miss a week
  and the discount resets.
- Data-driven: `content/buildings.json` with tiers, requirements, coin costs, build days, and what
  each tier changes in the village (looks, how many followers it holds, what it unlocks).
- Land is a tier too. Make the island about double what it is now so the villagers have room, and
  gate more land the same way as buildings.
- Rule check: balance thresholds unlock things, coins build them, money never buys coins, a broken
  streak costs a discount and nothing else.

### 2. The pot

Change how scratch-offs and the small machines pay out. Right now every pull gives something. Some
pulls should give nothing, so the hits mean more. The money still lands in brokerage every time;
that rule doesn't change.

- Every losing pull's dollars go into the pot, which is real cash sitting in brokerage.
- Hit odds are posted. Pity guarantees a hit within a set number of pulls.
- On a hit, the whole pot buys a position in a stock the owner picked ahead of time. Bigger pot,
  bigger position. That's the jackpot, and it's the owner's own money.
- The owner always picks the stock, ahead of time, at the counter. The game never picks one and
  never sells anything.
- Cosmetic rarity still rolls on its own, same as now.
- Show the pot on the machine so it can be watched growing.

### 3. Later (written into NEXT.md, not built yet)

- Villagers that talk to the owner and to each other. Lines come from the numbers like now, plus
  ambient chatter, plus comments on what's being built, the pot, and the streak.
- A history screen. On the first of every month, save a screenshot of the village and its numbers.
  A then-and-now view, so six months from now the owner can look back at what they had.
- The grind. The village should feel earned. Minigames exist to serve the build; they aren't the
  game. If something unlocks without saving for it, that's wrong.
