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

## October 21, 2026 (later): real trading, every pull

The owner's call after reading the Alpaca/batch suggestion: "Yes to trading through an API broker.
No to the Sunday batch. I want every pull to move money the moment I pull. That's the whole point of
the game for me. Build it now."

### The broker

- moomoo first (the owner has an account): OpenAPI through the local gateway app OpenD, with paper
  trading. A swappable provider, so Alpaca drops in later with no other changes. Alpaca is a stub
  with the same interface.
- Day one: `tools/broker_check.py` connects to OpenD, places one paper order for about $5 of a
  fractional-eligible US stock, waits for the fill, and prints exactly what happened. The owner runs
  OpenD on their machine. Exact OpenD and paper-account setup steps go in README.md.
- moomoo takes a share count, not dollars. For a $5 pull: get the quote, divide, send the count to
  three decimals, never round up. Log the dollar target and the actual fill side by side. Leftover
  cents stay as cash.
- If the fractional order doesn't go through on paper: tell the owner and stop. Alpaca is the
  fallback and takes dollar amounts directly.
- Fidelity stays read-only through SnapTrade for the followers view. moomoo holdings come straight
  from its API.

### Instant moves

- Pre-loaded cash: the owner puts money into the brokerage on payday with a standing deposit they
  set up themselves. The game never touches the bank. Every pull is a real order from cash already
  in the brokerage, placed the second the owner pulls.
- The brokerage cash balance IS the budget. The machines show it. When it's gone the machines go
  dark until the next deposit lands. Delete the old extra-this-week math once this works.
- Market hours: during the day the order fills in seconds and the machine shows the fill, price and
  shares. After hours the backend queues it and submits at 9:30 ET; the machine shows "sent, fills
  at open." Never pretend it filled.
- The hard caps in money/transfer.py still apply per order, per day, per week. Live trading needs
  HOARD_LIVE=1 in .env on top of the keys; without it everything goes to paper even with real keys.
- The game never sells anything, ever (so day-trade rules can't trigger).
- Followers still update size on Sunday. Fills are instant, followers are weekly. Both.

### The counter and the pot

- A watchlist the owner picked on purpose. The pot and every machine buy only from the watchlist.
  The game never picks a stock.
- The counter shows each watchlist stock with real data, pulled weekly and cached: what it is in
  one sentence, 1-year and 5-year return, dividend yield, next earnings date, and what $5 a week
  turns into over 10 and 30 years at its own historical rate and at a flat 7%. A free source like
  yfinance; fixtures in demo mode.
- One index fund is the boring follower. Over the months it should visibly outgrow the flashy ones
  if that's what the data says. Don't fake it either way.
- No momentum signals. Nothing that says a stock is going up or might be worth buying. No live
  prices anywhere in the game. "If I ask for this later, point me back to this line."
- Share price is irrelevant with fractional shares: nothing sorts or suggests by price.

### The newspaper

- A weekly paper in the village, out Sunday with the sermon: what moved in the owner's holdings this
  week and why, in plain language, from news headlines. Earnings dates for holdings show up as
  events on the calendar and in the village.

### House fund

- `.env`: `HOUSE_FUND=bank` or `HOUSE_FUND=brokerage:SYMBOL`. Bank: the game counts what lands in
  savings each week and celebrates it. Brokerage: every savings purchase is an instant order for
  that symbol. Default bank. Build both.

### For NEXT.md, don't build yet

- The crypt: a Roth IRA as a place in the village (Alpaca offers them through the API as of May
  2026; moomoo doesn't as far as the owner knows). Things go in and don't come out until old age.
  The tower should already show what the current rate is worth at 60: add that now; the crypt waits.
- Villagers talking, the history screen, the grind notes stay in NEXT.md.

### How to work

- Order: broker provider and broker_check.py, then instant moves, then the counter and pot, then
  the newspaper, then the house fund config. Commit after each. Stop if something needs the owner
  (like OpenD being up) and say exactly what to do.
- Paper for at least a week before live keys. Say it in the README in big letters.
- Document every .env key: moomoo, Alpaca, SnapTrade, Plaid read-only, HOARD_LIVE, HOUSE_FUND.
- Rules that don't change: money is never random, only cosmetics are. The game never lowers a
  balance, never sells, never picks a stock. Coins and money never convert either way. Penalties
  never touch money.

## October 22, 2026: a helper, gold, silver, bitcoin, and a portfolio that keeps moving

The owner, after the look pass: "Let's do these" (finish the look pass, the first five minutes,
speed, the pot, the counter with real data, the newspaper, talking villagers, history, the crypt
tower, going real). Plus, in their words:

- "Let's add a character that's kind of like a helper in a way. Like, he explains stuff for me.
  Explains why it's good to put my money in these certain things, or why it's good to do this or
  that."
- "I also want to be able to like maybe buy gold and buy silver and maybe buy Bitcoin also."
- "I want the stocks to change with my income and how they're doing. So it's a diverse portfolio
  throughout the whole thing. And we're not just buying the same stuff over and over again. But
  that way I can keep moving it and keep growing with it. And adapts to what's happening outside.
  So that way it never will feel like it's stuck or not I'm not buying something right."

Note for whoever builds this: the October 21 notes say "The game never picks a stock", "No
momentum signals. Nothing that says a stock is going up or might be worth buying ... If I ask for
this later, point me back to this line." The last ask above was pointed back to that line and a
rule-keeping version (a target mix the owner sets, new money going to whatever is furthest below
its target) was put to the owner. Build whatever they chose, recorded below.
