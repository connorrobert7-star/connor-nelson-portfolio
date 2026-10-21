# Influences

Step 0 research for Hoard. This doc covers ten games. For each one it gives the one mechanic the game runs on, why that mechanic works on the player, and exactly how Hoard uses it to make saving feel good. Each section ends with a short feel spec (the timings, numbers and sounds the builders start from), a one-line money-rule check, and sources.

After the ten games, "How they combine" walks through the owner's first five minutes, first day and first week. "Decisions where the studies overlap" settles the places where the ten studies disagree. The closing table maps every mechanic to the owner's Steps 1 to 5 and to the feature folder that builds it.

How to read the numbers:

- Numbers about the original games come mostly from fan wikis, guides, interviews and, for Shattered Pixel Dungeon, its GPL source. Each section says where sources disagree.
- Numbers for Hoard (timings, counts, prices) are starting values to tune. They are not measurements of the originals.
- The ten studies were written separately and overlap a lot: four of them each invented a "days since the last deposit" mood meter. The per-game sections below already use the merged answer and note where they changed a study. The reasons are in "Decisions where the studies overlap".
- Rebuild mechanics only. Never copy code, art, sound or text from a commercial game. Shattered Pixel Dungeon's art and sound are GPL-3.0 and may be used as packs with credit (see ASSETS.md).

## At a glance

| Game | The one mechanic | What it becomes in Hoard |
| --- | --- | --- |
| Cult of the Lamb | Reciprocal devotion: the flock's faith rises when you tend it and sinks when you don't | Two meters split on the money line. Faith (whole cult) moves only when real money lands in your accounts; it changes how the flock looks and sounds and buys nothing. Loyalty (each follower) comes only from play and is what makes coins. |
| CS:GO cases | The slow-stop reel: the result is rolled at the click, then shown as a long strip that slows unevenly past near-misses | The Reliquary case machine at the front door. A $10/$20/$50 case moves exactly that into your account; the reel decides only which cosmetic you get. |
| Webkinz | The waiting pet: hunger and happiness drain on the real clock and only your hand refills them | Each follower shows Belly (hunger, fed with coins) and Glow (dims with days since your last deposit) on its body, never as bars. |
| Club Penguin | Play-to-wear in a crowded hub: short minigames behind doors pay coins you show off in the square | The Square hub with four loud doors. Coins from the mine and fishing buy food and rerolls; what you wear and who follows you shows what you've saved. |
| Balatro | The scoring cascade: Chips x Mult resolved one trigger at a time through things you chose | The daily three-room dungeon as one Balatro ante. Your real week deals the modifiers (overspent on delivery: faster enemies; saved extra: a starting buff). |
| Vampire Survivors | Visible escalation from physical pickups: gems spill, fly to you, a bar fills | Every real dollar that lands bursts into bone-white motes that fly to the shrine. Coins are brass and never mix with motes, so you can always see which is money. |
| Animal Crossing | Overnight resolution on a real clock: what you do today finishes while you're away | Deposits land now; the village finishes them overnight. Tomorrow a short "while you were out" scene shows what changed. |
| Stardew Valley | Community Center bundles: a visible checklist of slots restores a ruined building | Offering tablets beside ruined village buildings. Socket-grid savings challenges (like a no-spend week) open the building when full. |
| Shattered Pixel Dungeon | The ration clock: hunger rises every turn and only food brings it down | The Larder: hunger rises each game day; a deposit is a ration. The cult visibly waits for you when you come back. |
| Buckshot Roulette | The announced load: the dealer shows exactly what's loaded, then draws without replacement | The case odds and the pity counter become two visible loads on the dealer's table (the Belt and the Box). The dealer counts them out loud before every pull. |

## Terms used below

- **Own account**: the House Fund (`sav_1`), the wall (the emergency fund; the demo has no account for it yet), brokerage cash (`brk_1`), or a payment to a debt id. **Money landing** means a completed `move()` in `backend/money/transfer.py` into one of these.
- **Extra**: `compute_extra(ctx)["extra_cents"]`, always checked together with `caps_remaining(ctx)`.
- **Motes**: bone-white (CREAM) specks of light. They are the only way real dollars are drawn. **Coins** are brass, earned only by play, and never mixed into the same burst as motes.
- **Faith**: one cult-wide meter, 0 to 100, driven by days since money last landed. It buys nothing. **Belly**: per-follower hunger, refilled only with coin-bought food. **Loyalty**: per follower, raised only by play. Loyalty is the only thing that produces shrine Devotion, and Devotion becomes coins.
- **Kept week**: a Monday-to-Sunday week in which money landed in an own account. If extra was 0 that week, the week counts as kept when every bill was paid on time.
- **Leader**: the owner's character. **Personal follower**: the one creature that hatches from the first deposit and grows with kept weeks. **Holding followers**: one per held stock, sized weekly by portfolio share. **Acolytes**: followers recruited in the dungeon. **Cultists**: nameless background creatures that keep the Square from looking empty.
- **The belt and the box**: the casino's two counted loads, which are both the odds and the pity (see Buckshot Roulette).
- **Day line**: 04:00 local time. A new game day starts there.

---

## 1. Cult of the Lamb (Massive Monster / Devolver Digital, 2022)

### The mechanic: reciprocal devotion

You tend the flock with a daily sermon, a blessing, food and answers to their requests, and each follower's Loyalty rises. Loyal followers pray at the Shrine. Their Devotion piles up there, up to a cap, until you come back and collect it. Meanwhile one cult-wide Faith level slides while you stay away, until a follower turns its back on you. You give attention, they give worship, and your absence shows on their faces. In Hoard, the deposit is the sermon.

How it runs in the original:

- **Faith** is one cult-wide level. Bless gives +5 per follower, Bonfire +30, the Feasting ritual +30 (one wiki says +25; it costs 75 bones and has a 5-day cooldown), a Funeral +20 and a Holy Day +80 (nobody works that day). A follower's death costs -20, and declining a quest costs -35. Hunger, sickness, filth, missing beds and dissenters all drain it.
- **Dissenters**: low Faith turns followers into dissenters with red eyes. They stop working, spread doubt, and eventually leave with stolen coins. Re-education lowers dissent by 7.5 a day (25 in prison).
- **Loyalty** is a 0-100 bar per follower. A sermon gives +5, a blessing +20, Inspire +25, a gift +20 or +30, a finished quest +50, and the Confession Booth +75. A full bar levels the follower up (capped at 10 since v1.3.0) and pays 20 Devotion plus a Commandment Stone fragment.
- **Devotion**: each praying follower adds its level to the Shrine every 1/20 of a day. The Shrine starts at 50 Devotion with 4 praying slots and can be upgraded to 175 with 10.
- **Time**: a day lasts about 15 real minutes and keeps running during dungeon crusades. Needs show as icons over followers' heads. River Boy voiced every follower in gibberish.

### Why it works on the player

1. **It is reciprocal.** You give something, and the flock gives back something you can see and pick up: a glowing pile, a kneeling crowd, a chant. Being worshipped is a reward a budget bar cannot offer.
2. **Neediness creates attachment** (the Tamagotchi effect). Loss you can see weighs more than gain, and fixing it is cheap and immediate, so every visit ends in relief. This has moved real behavior: in Byrne et al. (Cornell), teens whose phone pet reacted to their real breakfast were about twice as likely to eat breakfast over 9 days.
3. **Capped storage plus time that runs while you're away** gives every return a payoff (the pile) and a small story (who got hungry, who is sulking). This is the direct fix for "nothing waits for me."
4. **The crowd is the meter.** Dozens of bodies moving together read instantly, with no UI.
5. **Dark-cute gives permission.** Neglecting round, big-eyed creatures stings, and the cult joke makes tending them a guilty pleasure. The framing is "feed the cult", not "stick to the budget".
6. **Tension and release.** The casino reel tightens, and the shrine chant releases.

### How Hoard uses it

Split the two meters exactly along the money line:

- **Faith** (cult-wide, 0-100) moves only when real money lands, plus a few free play acts. It buys nothing and produces nothing. It only changes how the flock looks and sounds.
- **Loyalty** (per follower) moves only through play, and it is the only thing that makes coins, through Devotion at the shrine.

A deposit restores faith. Petting and feeding earn coins. The two never cross.

- **Step 1, casino.** Followers stand on risers along the casino's back wall, and how many show up depends on Faith. They hum a semitone higher each time the reel's tick gap widens, go silent for the reveal hit-stop, then react by rarity. Every pull is money landing, so it resets the days-since-deposit clock, and the shrine flame is taller when the owner walks out.
- **Step 2.**
  - The daily dungeon takes up to 3 high-loyalty followers along.
  - About once a week, room 3 holds a caged acolyte that follows the leader home. A tap-only naming rite makes it the owner's: three generated names and three body forms to tap.
  - Followers stand at the gate during the debt-boss fight and chant when a payment lands.
- **Step 3, the main home.** The while-you-were-out scene, then the daily sermon (hold for 1 second). Tapping the shrine vacuums up the Devotion pile as coins. Tapping a follower blesses it, and dragging coin-bought food onto it feeds it.
  - Faith shows as flame height, eye glint, how in sync the flock breathes, how many voices chant and how many music stems play.
  - Faith slides about 7 points a day after the first day without money landing. Lean days freeze it.
  - Around day 12 to 14 with no deposit, one acolyte stands at the village edge with its back turned. Any deposit of any size walks it back, and so do "listen" taps on three separate days.
  - A missed week is mourned with a coffin and a funeral.
  - The personal follower grows at 1, 2, 4, 8, 13, 26 and 52 kept weeks and never shrinks.
  - Holding followers resize once, on Sunday.
- **Step 4.** Hit-stop on deposits, kneel squash, orbs arcing with rising pitch, heart pops, synced breathing at high Faith, and a bow ripple as the leader walks past.
- **Step 5.** The shrine sits at the center of the village, and its flame and spilled Devotion can be read from every plot. Shrine storage grows as ruins are restored, which is play. Nothing money drives can enlarge it.

### Feel spec

- **State.** `backend/features/followers` decides every state and bubble. `GET /state` adds `flock`: {faith, band, days_since_deposit, thoughts, mourning, shrine {devotion, cap}, since_last_visit, followers [{id, name, kind: personal|holding|acolyte, level, loyalty, belly, favorite, state, skin, scale, bubble}]}.
  - Routes: `POST /flock/sermon` (once per game day), `/flock/bless`, `/flock/feed`, `/flock/collect`, `/flock/funeral`, `/flock/listen`.
  - Only `/collect` and `/feed` touch coins, and none of them calls `move()`.
- **Faith** = clamp(100 - 7 x max(0, d - 1) + thoughts, 0, 100).
  - d = days since money last landed, counting only days with extra above 0 and no late bill.
  - Thoughts: money landed +15 for 3 days (at most 2 stacked); attended the sermon +5 for 1 day; every follower fed +5 for 1 day; funeral held +20 for 2 days; an unmourned missed week -20.
  - With daily play and no deposits: day 4 = 89, day 8 = 61, day 12 = 33, day 14 = 19.
  - One deposit a week keeps d at 7 or less, so Faith never drops below Content. A $1 deposit sets d back to 0.
- **Bands**: Fervent 80 and up, Content 50-79, Doubting 25-49, Cold under 25.
  - Shrine flame height = 4 + round(faith x 0.2) px, max 24.
  - Pupils: 3x3 with a 1 px glint at Fervent, 2x2 at Content, half-lidded at Doubting, hollow on the dissenter.
- **Idle**: 32x32 sprites with a 4-frame bob at 6 fps, plus breathing (scale.y 1.00 to 0.95 to 1.00 over 1.6 s, random phase).
  - At Fervent every phase snaps to the chant beat (92 BPM, one breath per 2 beats), so the whole flock breathes in unison. That is the creepy cult tell.
  - At Doubting the bob drops to 4 fps and heads glance around every 3-6 s.
- **Bless** (tap a follower):
  - Squash to (1.15, 0.85) in 60 ms, then back elastic over 260 ms.
  - An 8x8 heart pops above the head (0 to 1.25 to 1.0 over 180 ms, rises 6 px), with `heart` at pitch 1.0 + 0.05 x level.
  - +20 loyalty (+35 at level 1), once per follower per day. Later taps that day only squish and play a giggle.
- **Loyalty** shows as five 2x3 px candles at the follower's feet, lit at 20/40/60/80/100.
  - At 100 the follower lifts 6 px over 250 ms with a 3-frame white flash and `level_up`, and the candles blow out.
  - Body marks: a halo at level 3, horns at 5, a third eye at 8. Each level also adds one idle trick (from Webkinz).
- **Devotion**:
  - Each praying follower adds its level every 4 real hours. Hungry, asleep and dissenting followers don't pray.
  - The cap is 40, then 60, 90 and 150 as ruins are restored. 1 Devotion = 1 coin.
  - The pile is brass sparks stacked on the shrine, one per 5 Devotion. At the cap it spills into a 24 px ring that pulses at 0.5 Hz, visible from anywhere in the village.
  - Collect: sparks fly to the leader over 0.35 s (cubic in), staggered 25 ms, with `spark` rising a semitone per spark up to +12.
  - Fill time: 6 followers at level 1 take about 27 h; at an average level of 2, about 13 h.
- **Sermon**:
  - A `bell` rings and followers walk to a ring around the shrine at 40 px/s. The only prompt is a 16 px ring pulsing around the leader.
  - Hold for 1.0 s to fill it. Letting go early drains it over 200 ms and loses nothing.
  - On completion: 120 ms hit-stop, 1 px shake, everyone kneels, each follower sends orbs equal to its level (0.5 s arcs, 60 ms apart, `tick` rising a semitone per orb), the chant swells for 3 bars, and they rise.
  - It lasts 7 s or less. Any tap after 1.5 s plays the rest at 3x speed.
- **Money-landing chant** (any `money_moved` into an own account):
  - 80 ms hit-stop and a 2 px shake for 120 ms.
  - Followers run to the shrine at 1.5x walk speed, kneel on the first mote, chant 2 bars and rise on the last mote.
  - A stock pick at Marlo's counter never fires it.
- **Casino choir**:
  - Up to 12 followers on the risers: all of them at Fervent, 2/3 at Content, 1/3 at Doubting, and at Cold only the dissenter, facing the wall.
  - `chant_hum` climbs a semitone as the reel's tick gap passes 60/90/130/180/260 ms, then 150 ms of silence on the land.
  - Reactions:
    - Common: a low "mm" and a 1 px shrug.
    - Rare: one clap on the beat.
    - Epic: arms up and 1 bar of chant.
    - Legendary: everyone kneels and chants 4 bars under the cutscene.
    - Mythic: the whole flock faints flat for 600 ms, then springs up (stretch 1.2, elastic 400 ms) chanting at +6 dB.
- **Belly** (coins only) runs 100 to 0 over 48 h.
  - Gruel 5 coins (+40), stew 15 (+80), the follower's favorite 25 (+100, +20 loyalty and an 8-frame dance).
  - At 0 the follower lies flat and stops praying. It never gets sick or dies.
- **Dissenter**:
  - Appears only in the Cold band, at most one at a time, and only from acolytes.
  - It stands with its back turned at the village edge and plays `mutter` at pitch 0.7 every 8-12 s. Others within 48 px glance at it.
  - The way back: any deposit, or one `listen` tap on each of three separate days. It never leaves and never takes coins.
- **Mourning**:
  - Trigger: the Monday after a week with extra above 0 and nothing kept.
  - A 10x6 coffin with the week's dates sits on the shrine. Followers wear veils, the chant becomes `chant_dirge` (minor key, 46 BPM), and only the marimba stem plays.
  - Tap the coffin for an 8 s procession to the Grave of Weeks. Candles are lit there and stay forever, and Faith gets +20 for 2 days.
  - If ignored, mourning ends by itself the next Monday.
- **Holding followers**:
  - Scale = 0.7 + 1.3 x sqrt(portfolio share), set once on Sunday with a 1.5 s sine tween and no sound.
  - A holding over 40% is drawn at 2.2x. The others' pupils shift 1 px toward it, and they keep 32 px away.
  - Their mood never reads price.
- **Sound**:
  - The chant runs at 92 BPM on gibberish syllables (hoa, rd, keh, mun, oss) from two base voices, with +-8% pitch per follower. The number of voices scales with the band.
  - Village music is 4 stems (marimba, bass, choir hum, soft percussion), switched on at Faith 0/25/50/80 with 2 s crossfades.
- **Bow on pass** (a Hoard addition, not confirmed in the original): followers within 24 px of the leader dip their heads 2 px for 150 ms, staggered by distance, so a ripple follows the leader through the village.

**Money-rule check:** the flock only reacts to money that has already moved. No flock route calls `move()`, Faith never multiplies Devotion or coins, and holding followers never react to price.

**Also take:**

- Icon-only thought bubbles, at most one per follower, in priority order: request > bowl > veil > Zzz.
- Requests: at most 3 open, never expiring, each doable with $0 extra, worth +50 loyalty.
- Coin rituals on cooldowns: Feast (60 coins, fills every belly, 5 days) and Bonfire (40 coins, +15 loyalty for everyone, 3 days). Neither touches Faith.
- The Funeral is the free ritual.

**Leave out:**

- Death, sickness, sacrifice, and dissenters leaving or stealing.
- Faith or loyalty as multipliers on output.
- Coin rituals that raise Faith.
- Timed quests and penalties for declining.
- Red dissenter eyes (red is mythic).
- Poop and corpse chores.
- The 15-minute day.
- Doctrine screens.

**Sources**

- https://cult-of-the-lamb.fandom.com/wiki/Loyalty
- https://cult-of-the-lamb.fandom.com/wiki/Sermons
- https://cult-of-the-lamb.fandom.com/wiki/Shrine
- https://cult-of-the-lamb.fandom.com/wiki/Faith
- https://cult-of-the-lamb.fandom.com/wiki/Dissenter
- https://cult-of-the-lamb.fandom.com/wiki/Temple
- https://cult-of-the-lamb.fandom.com/wiki/Commandment_Stone
- https://cult-of-the-lamb.fandom.com/wiki/Feasting_Ritual
- https://cult-of-the-lamb.fandom.com/wiki/Follower_Quest
- https://cult-of-the-lamb.fandom.com/wiki/Follower_traits
- https://www.shacknews.com/article/131805/cult-of-the-lamb-raise-faith
- https://www.pcgamer.com/cult-of-the-lamb-followers/
- https://pcgamer.com/cult-of-the-lamb-doctrines
- https://www.ggrecon.com/guides/cult-of-the-lamb-doctrines/
- https://primagames.com/news/cult-of-the-lamb-follower-loyalty-dissent-leveling-guide
- https://primagames.com/gaming/cult-of-the-lamb-guide-shelters-sleeping-areas
- https://primagames.com/gaming/cult-of-the-lamb-guide-heal-sick-clean-poop-followers
- https://www.gameskinny.com/?p=73133
- https://www.wepc.com/gaming/cult-of-the-lamb-rituals/
- https://www.gameinformer.com/guide/2022/08/11/cult-of-the-lamb-10-tips-and-tricks-to-be-the-best-leader-possible
- https://pcgamer.com/cult-of-the-lamb-review
- https://unity.com/en/blog/games/recipe-behind-smash-hit-cult-of-the-lamb
- https://uk.news.yahoo.com/making-cult-lamb-lot-design-025122036.html
- https://stevivor.com/previews/cult-lamb-preview-aussie-made-diabolical/
- https://www.dreadxp.com/?p=27832
- https://www.npr.org/transcripts/1118519150
- https://lightintheattic.net/products/cult-of-the-lamb-original-soundtrack
- https://steamcommunity.com/app/1313140/discussions/0/3319736698843948707
- https://news.cornell.edu/node/271155
- https://en.wikipedia.org/wiki/Tamagotchi_effect
- Caveat: the numbers come from fan wikis and guides, mostly from 2022 to 2024, and a few disagree (Feast +30 vs +25). The bow ripple and the casino choir timings are Hoard designs.

---

## 2. Counter-Strike: Global Offensive / CS2 weapon cases

### The mechanic: the slow-stop rarity reel

The result is rolled the instant you click. It is then shown as a long strip of item cards, each with a rarity-colored bar, sliding under a fixed center line. The strip launches fast, brakes over several seconds and crawls the last tile or two, so rarer colors drift past the line. When it stops, the rarity color flashes. The mechanic is the staged gap between knowing and showing: a roll that takes a millisecond is stretched into a window of rising uncertainty, and a color the player reads instantly pays it off.

How it runs in the original:

- **Fixed at the click.** By community consensus (not a Valve statement), the outcome is fixed when you click: rarity tier, then skin, then wear. The animation only plays it back. Fan simulators build the strip around the winner; one uses 110 cards with the winner at index 75 and eases the strip in with a cubic-bezier.
- **The gold card.** Knives and gloves never appear on the strip as themselves. They show as one gold "Rare Special Item" card.
- **Published odds.** Rates were published in 2017 for China's disclosure rule: blue 79.92%, purple 15.98%, pink 3.20%, red 0.64%, gold 0.26%. The first four steps are exactly 5:1.
- **StatTrak** is a separate roll of about 10% that adds a kill counter. **Trade-ups** turn ten skins of one tier into one of the next.
- **Business shape.** Cases drop free, and the key has cost $2.49 since 2013. Spending was about $980M in 2023. Transferability through the Steam Market is what made cases gambling under the Dutch ruling, and Valve blocked case opening in the Netherlands and Belgium in 2018.
- **Spin length.** Valve publishes no duration. Footage suggests about 5 to 7 seconds; this is not verified.

### Why it works on the player

1. **Uncertainty itself is the reward, and the reel makes it last.** Dopamine neurons carry an uncertainty signal that is strongest near 50/50 and ramps up until the reward is due (Fiorillo, Tobler and Schultz 2003). The crawl keeps the end near 50/50: in the last second only two cards are in play, this one or the next.
2. **Rarer colors hit harder.** In Larche et al., rarer items produced bigger skin-conductance responses, longer pauses after the reveal and a stronger urge to open another. The color bar can be read in a tenth of a second, so no text is needed.
3. **Near-misses are seasoning, not the engine.** Near-misses raise the urge to play again when the player started the pull themselves (Clark et al. 2009). Controlled tests of whether they make people play longer are mostly negative (Pisklak et al. 2019).
4. **Published odds give the gold meaning.** Knowing how rare gold is turns a gold card stopping one tick away into a story.
5. **A constant-ratio ladder turns colors into a scale.** Blue is "fine" and gold is "scream", and nobody has to explain it.
6. **Hoard's twist: the key is a deposit that stays yours.** Money lands, with the same motes and chant, before every reel. The deposit becomes the dependable cue that the thrill is coming. The goal is that, after a few weeks, the deposit sound alone feels good.

### How Hoard uses it

**Step 1, the Reliquary case machine, moment to moment.**

1. **The case waits.** Sealed cases sit on the shelf behind the dealer, each with its price painted on it ($10, $20, $50). Cases dropped by play in Step 2 sit there too, rattling every 4 s. The belt on the table and the box on the wall (see Buckshot Roulette) are the odds and the pity.
2. **The dealer states the price, the destination and the counts out loud** before every pull.
3. **The owner chooses where the dollars go** by tapping one of the slot mouths on the machine:
   - the House Fund jar (`sav_1`);
   - the wall;
   - the brokerage follower (`brk_1` cash, never a buy);
   - the debt boss (a payment).

   Each mouth has its real balance painted on it, and the last one used glows, so a repeat pull is one hold.
4. **The money lands first, and it always lands.** The backend checks `compute_extra(ctx)` and `caps_remaining(ctx)`, calls `move()`, and only then rolls the cosmetic, all in one request.
   - Motes stream into the jar and "+$20" floats up in bone white.
   - The jar's painted number counts up, and the choir chants one beat.
   - This certain reward plays before the uncertain one, every time.
5. **The case cracks and the reel runs** for about 6.6 to 7.1 s. Followers' heads track the line. In the crawl they lean in and hum, and with gold under the line they say "ooh".
6. **The stop flashes the rarity color**: hit-stop, flash, shake, particles and a slow zoom, with a cutscene for legendary and mythic.
   - The item arcs into the collection book on the counter, where its silhouette fills, and it also lands on the leader.
   - A duplicate drops into the trade-up hopper instead, which glows when it holds 10 of one tier.
7. **A peg drops on the belt**, and the next case is ready.

**The trade-up machine** reuses the reel. The owner feeds in ten items of one tier, one by one; each clunk is a semitone higher and the machine heats up (Balatro's fire preview). Then a 3.5 s reel runs over next-tier items only. The mythic mouth is welded shut, and legendaries bounce off it.

**Step 2.**

- Minigames, fishing and the daily dungeon drop sealed cases onto the shelf. Opening one still takes a deposit of its price into an own account: play makes the case and saving opens it. A play-dropped case has the same price and odds as a shelf case, so play never makes a deposit cheaper.
- Coin-paid rerolls run on a copper machine skin that moves no money, so the two machines never look alike.
- A debt-boss kill plays its unique cosmetic on a red-lit strip.

**Step 3.**

- Won skins go straight onto followers.
- About 10% of drops come as a Tally variant: a notch strip that gets one carved notch for each deposit that lands while it is worn. It counts saving, with no text.
- The personal follower stands next to the machine and reacts loudest.

**Step 4.** The reveal table below becomes the shared table for every reveal in the game.

**Step 5.** A pull aimed at the house or the wall visibly moves that building's stage meter on the way out.

What the owner feels: "I put $20 in the House Fund, the gold crawled under the line, it slipped to blue, and I want another." The only way to get another is to save another $20.

Changed from the study: pity counts cases on the belt and box instead of $10 steps, because the owner's rule is "by case 25" and "by case 100". The CS:GO-style percentages become the target that the belt and box average out to.

### Feel spec

- **Layout.** The camera pushes into the machine face (zoom 1.0 to 2.0 over 0.4 s, quint out). The machine face is the reel; it is not a panel, and the dimmed room and followers stay visible at the edges.
  - Reel window: 396x48 at (240, 120).
  - Cards: 32x32 icons on dark cards at a 36 px pitch, 11 visible, each with a 3 px rarity bar along its bottom edge.
  - Legendary and mythic cards show only a gold or red eye glyph.
  - The center line is 1 px bone white with 5 px triangles, and it kinks 1 px at each peg crossing.
- **Strip** (built by the backend):
  - 100 cards. The winner is at index 90, index 5 starts under the line, and travel = 85 x 36 px + land_offset.
  - Filler is drawn from what is actually left in the belt and box.
  - Response: {strip, winner_index, land_offset_px, near_miss: null|fell|short|tease, tier, item_id}.
  - Land offset: normal -12..+12 px. "fell" is -15..-8 (just slipped off the gold card). "short" is +8..+15 (stopped 3-10 px before it).
- **Motion**, authored on an internal clock s from 0 to 6.4 s, integrated at 240 Hz and scaled so the reel lands to the pixel:
  - Windup 0-0.15 s, back 8 px.
  - Launch 0.15-0.45 s, ease-in to v_max.
  - Cruise to 1.30 s, with a +-3% wobble at 7 Hz.
  - Brake to 5.20 s: v = v_c + (v_max - v_c)(1 - u)^2.5.
  - Crawl to 6.40 s, linear to 0.
  - v_max comes out about 1300 px/s after scaling, and v_c is 80. Above 600 px/s, each card draws 2 ghost copies at alpha 0.3.
- **Uneven slowdown as a time warp.** The landing stays exact because position depends only on s; the hangs add time without moving the stop.
  - Below 150 px/s, time runs at 0.3 within 4 px of each card boundary, so the reel catches on each peg for 60-120 ms: tick, hang, tick.
  - At the near-miss boundary, time runs at 0.12 for 0.45 s with the line half on gold.
  - Real time totals 6.6 to 7.1 s. The settle is a 2 px overshoot that springs back over 120 ms.
- **Near-miss rates** (a tuning knob):
  - Common or rare outcome: 15% "fell", 15% "short", 20% "tease" (gold 2-4 cards before the winner, passing about 1 s before the stop).
  - Epic outcome: 20% get a legendary neighbor. Legendary outcome: 10% get a mythic neighbor.
  - Never on a mythic outcome, never two staged cards in one strip, and only with a tier that is really still in the box.
  - The first pull of a save always stages "short" when the outcome is common or rare.
- **Ticks** play on their own player, never through the 8-voice Sfx pool.
  - One per card boundary, at least 35 ms apart; extras are dropped, never queued.
  - Pitch = lerp(1.25, 0.9, slowness) +-0.03. Volume goes from -14 dB fast to -4 dB slow.
  - Hangs play `peg` instead: a heavier click at pitch 0.8, +2 dB.
  - The tick itself is a 25 ms filtered noise click with a 2 kHz peak (from `tools/sfx.py`) or a Kenney Casino Audio chip clack.
- **Tension bed.**
  - During the brake, the Music bus ducks -10 dB and a low-pass sweeps from 8 kHz to 900 Hz.
  - In the crawl, the follower hum rises 2 semitones, the camera pushes 1.0 to 1.08 and the vignette darkens to 40%.
  - On the stop, the filter snaps back within 80 ms.
- **Reveal table.** Hit-stop uses `Engine.time_scale = 0` and is released by a timer that ignores time scale.
  - **Common:** 50 ms. No flash; the card pulses grey once. 6 dust puffs, `reveal_common` (a dull thunk), and one follower sighs.
  - **Rare:** 83 ms. Blue flash at 0.35 alpha, fading over 180 ms. The card scales 1.0 to 1.25 to 1.1. 16 blue sparks, a 1 px shake for 150 ms, and the choir claps.
  - **Epic:** 117 ms. Purple flash at 0.5 over 250 ms, a 16 px light beam for 0.6 s, 32 sparks and 8 stars, a 2 px shake for 250 ms, and a zoom to 1.06.
  - **Legendary:** 200 ms with everything desaturated except the card. Gold flash at 0.7 over 400 ms, a 4 px shake, 64 sparks and 40 falling gold flakes, and a slow zoom to 1.2 over 0.8 s. Then a 3.5 s pedestal cutscene, skippable after 1 s.
  - **Mythic:** the music cuts and the room goes black for 0.5 s except the card's red glow. Red flash at 0.9 over 600 ms, a 6 px shake, 120 rising embers, a zoom to 1.3 over 1.2 s, and a 6 s cutscene with the flock circling and kneeling, over a 40 Hz sub boom. The room's lights flicker red for the rest of the visit.
- **Pacing.**
  - After 1.0 s of spin, a tap jumps to the late brake (s = 4.0). The crawl and the near-miss can never be skipped.
  - Case starts are at least 2.5 s apart. There is no autoplay and no open-many.
  - The item arcs to the book in 0.5 s, the book squashes (1.2, 0.8), and the silhouette fills bottom-up over 300 ms.
- **Target ladder**, the averages the belt and box are tuned to: common 67, rare 22, epic 7.5, legendary 2.7, mythic 0.8 percent.
  - Each step is roughly 3x rarer, gentler than CS:GO's 5x because the owner opens about 5 cases a week.
  - At 5 x $20 a week, that is an epic about every 2 weeks, a legendary about every 6 and a mythic about twice a year.
- **Case contents on the case.** Hover or long-press lifts the lid 4 px to show silhouette rows by tier. The gold and red rows show only eye glyphs.
- **Colors** come from `palette.gd` only. Real-dollar numbers are always bone white.

**Money-rule check:** the roll happens only after `move()` succeeds in the same request (no move, no reel), only the item is random, cosmetics have no cash value and cannot be sold or traded, and the brokerage mouth is a cash deposit, never a stock buy.

**Leave out:**

- Cash value, selling, trading or gifting of cosmetics.
- A key that is spent and gone.
- Dollar values on any tile.
- Autoplay and "open 10".
- Odds that shift with spending, balance, streak or time.
- Near-misses about money or about the destination account.
- Fake winner feeds.
- Wear shown as "worth less".
- Valve's sounds and art.

**Sources**

- https://www.esports.net/wiki/guides/counter-strike-case-odds
- https://steamdb.com/en/articles/cs2-case-opening-odds-explained
- https://steamcommunity.com/app/730/discussions/0/1474222595307264893
- https://www.pcgamesn.com/dota-2/dota-2-treasures-china
- https://case.oki.gg/case-odds
- https://csdb.gg/are-cs2-csgo-cases-predetermined
- https://steamcommunity.com/app/730/discussions/0/35222218619490647
- https://www.gfinityesports.com/article/from-basic-drops-to-legendary-skins-the-evolution-of-cs2-case-opening
- https://www.mintlify.com/Shermie80/cajas/features/case-opening
- https://cs.money/blog/cs-go-skins/everything-about-cs2-skin-rarity-and-float/
- https://link.springer.com/article/10.1007/s10899-019-09913-5
- https://pmc.ncbi.nlm.nih.gov/articles/PMC7882574
- https://uwaterloo.ca/bioengineering-biotechnology/events/profs-present-players-arousal-and-reward-signatures-loot
- https://pmc.ncbi.nlm.nih.gov/articles/PMC2658737/
- https://sciencedaily.com/releases/2009/02/090211122130.htm
- https://pmc.ncbi.nlm.nih.gov/articles/PMC7214505
- https://pubmed.ncbi.nlm.nih.gov/31522339/
- https://www.citedrive.com/en/discovery/discrete-coding-of-reward-probability-and-uncertainty-by-dopamine-neurons
- https://pmc.ncbi.nlm.nih.gov/articles/PMC2806405
- https://csdb.gg/trade-up-contracts-guide
- https://cs.money/blog/cs-go-skins/cs-go-craft-guide/
- https://game-wisdom.com/general/csgo-trade-contracts-work
- https://wecoach.gg/blog/article/cs2-case-drop-rates-guide-2026
- https://pricempire.com/stattrak-guide
- https://csdb.gg/guides/how-to-get-cs2-keys/
- https://lis-skins.com/blog/how-much-do-cs2-case-keys-cost/
- https://afkgaming.com/csgo/news/cs2-players-spend-more-than-980-million-on-cases-and-keys-in-2023
- https://steamcommunity.com/news/post/2838841185434278558
- https://publicgaming.com/news-categories/regulatory-issues/3185-valve-disables-cs-go-and-dota-2-item-trading-in-netherlands-after-legal-warning
- https://gameranx.com/updates/id/156574/article/csgo-lootboxes-have-been-disabled-in-the-netherlands-and-belgium/
- https://afkgaming.com/gaming/genshin-impact/what-is-pity-in-genshin-impact-and-how-does-it-work
- https://opengameart.org/content/54-casino-sound-effects-cards-dice-chips

---

## 3. Webkinz (Ganz, 2005; Webkinz Classic and Webkinz Next)

### The mechanic: the waiting pet

You name a creature you own. Its meters drain on the real clock, including while you are away. Only your own hand refills them, using things bought with currency you earned by showing up. It never dies.

How it runs in the original:

- **Adoption.** A plush tag code made a virtual twin you named at the Adoption Center, and one code bought a year of play. Webkinz launched in April 2005. Webkinz Next came out in 2020, and the plush were discontinued in 2021.
- **Meters.** Happiness, Hunger and Health (Rest replaced Health from 2015). The decay rate was never published.
  - A neglected pet got sick (a green snout) and needed 25 KinzCash of medicine. It never died.
  - In March 2015 sickness was retired: Ganz kept the need and dropped the punishment.
- **Requests (Webkinz X).** Pets ask for food, a bath or a game, with a timer ring. Four answered requests fill the Pet Care Heart, which pays KinzCash and items. The family bonus applies to the first 10 hearts a day.
- **Dailies.**
  - Wheel of WOW: one free spin a day, with duds; a bonus meter pays at 15 spins (one later post says 20).
  - Gem Hunt: one of five mines a day, 3 rocks, and your turn ends at the first gem. 30 gems make the Crown of Wonder.
  - The Curio Shop sells one rare item for one hour.
- **Rooms.** You decorate rooms with furniture, and the pet is standing in its room when you log in.

### Why it works on the player

1. **The pet keeps living while you're away.** A meter on the real clock keeps a loop open while the game is closed.
2. **It makes you its caretaker.** Children who raised a virtual dog treated it as having its own needs (SFU thesis, Nintendogs). Refilling a meter you let fall is relief, and relief is a strong reinforcer.
3. **It is yours.** You named it and furnished its room. People overvalue what they build themselves (Norton, Mochon and Ariely 2012, the IKEA effect).
4. **The need gives the currency a purpose.** KinzCash would be meaningless without a hungry pet.
5. **Webkinz removed the punishment.** Neglect that costs currency to fix turns guilt into avoidance, and Duolingo has said the same about streak fear.

For Hoard: saving is normally self-denial for a payoff decades away, so present bias beats it. The waiting pet turns a deposit into care for something you can see right now. The owner isn't "not spending"; they're feeding the thing that chants their name.

### How Hoard uses it

**Two needs per follower, shown on the body and never as bars.**

- **Belly** runs on the real clock and is refilled only with coin-bought food. It is the daily-visit loop.
- **Faith** (this study called it "glow") is driven only by days since money landed. Any deposit, of any amount, restores it fully, so it rewards the habit and never the size. It is the same meter as Cult of the Lamb's Faith.
- **Quirks** are the backend's week reactions drawn on the creatures:
  - groceries over budget: they grumble and hold an empty bowl;
  - eating out over budget: they lie down and walk slower;
  - a deposit: they chant at the shrine.

  Quirks reset on Monday, and coins can't buy them away.

**Step 3, den and shrine.**

- **On open**, the while-you-were-out scene plays. The personal follower is wherever the owner's absence left it: at the door, asleep on the doorstep, holding an empty bowl, or with the whole flock curled at the shrine. It spots the leader, runs and hugs. Money that landed while the owner was away replays in miniature.
- **Feeding.** The owner clicks the larder shelf, where each food shows its coin price on itself. The food sticks to the cursor. Then the owner clicks a follower: anticipation, chomp, squash, crumbs, and the belly swells.
- **The personal follower is the adoption moment.** It is an egg until the first deposit ever. That deposit cracks it, and the owner names it with the tap-only rite. It grows with kept weeks and never shrinks.
- **A missed week** gets Cult of the Lamb's coffin and funeral. Webkinz adds that the next deposit plants a flower on that week's grave, and it stays a flower. Over time the Grave of Weeks becomes a garden of redeemed weeks.
- **Each follower has a hidden favorite category**: candles, bones, shiny things, plants or skulls. The owner finds it by watching who leans toward what.

**Step 1.**

- The personal follower stands at the owner's shoulder in the casino.
- The prize wheel gets a bonus meter of 15 candle notches, which is pity you can see.
- The free once-a-day spin on the shrine wheel is the Wheel of WOW. Up to 3 missed days bank, and its prizes rotate every 14 days.

**Step 2.**

- Coins from the minigames buy food.
- Gem Hunt becomes the daily dig at the mine mouth, part of the morning rounds.
- Fed followers (belly 60 or more) join the dungeon run. Hungry ones stay home and wave.

**Step 5.** The den is inside the house.

- Click the chest and won cosmetics spill out in an arc. Drag them onto a 16 px grid, and followers walk over within 2 s to inspect anything new.
- Placing a follower's favorite makes it gasp, run over, and sleep beside the item from then on.
- New rooms open as the house fund crosses stages, so the den mirrors the real balance and never spends it.

Changed from the study:

- The 10-minute request ring and heart pips are folded into Cult of the Lamb's never-expiring requests and loyalty levels.
- "Glow" is folded into Faith.
- The one typed name field is replaced by tap-only naming, so there are no panels.

### Feel spec

- **State.** The backend stores `last_fed_at` per follower and the last money landing. `/state` returns belly 0-100, the band, the quirk, a pose and away_hours. No meter math in GDScript.
- **Belly** goes from 100 to 0 over 48 h, so one visit a day keeps it above 50.
  - 60 or more: round belly, bob 2 px at 1.2 Hz.
  - 30-59: bob 1 px at 0.8 Hz, glances at the larder every 6-10 s.
  - Under 30: thin sprite holding an empty bowl, growl every 20-40 s at -12 dB.
  - At 0: lies flat. Nothing worse ever happens.
  - Feeding at 100: the follower shakes its head and no coin is spent.
- **Feeding**:
  - The food sticks to the cursor, bobbing 1 px. The mouth opens (2 frames, 80 ms), and the food flies in on a 120 ms parabola with an 8 px peak.
  - Chomp: 3 frames at 60 ms. Squash to (1.25, 0.80) over 60 ms, then elastic back over 240 ms.
  - 3-6 crumbs (gravity 140 px/s^2, 0.4 s life). Sound: `chomp` plus `pop` at pitch 1.0-1.15.
  - The belly sprite swaps on the next frame.
- **Faith poses** (Webkinz's glow bands mapped onto the Faith bands):
  - Fervent bounces 2 px at 1.5 Hz with a twirl every 12-20 s.
  - Content bobs 1 px at 1 Hz and blinks every 3-5 s.
  - Doubting sits facing the shrine, with idles at 70% speed.
  - Cold holds a candle, sways at 0.5 Hz with half-lidded eyes, and a low dirge hum loops at -18 dB in the den.
  - A lean week (extra 0) freezes Faith in a calm "fasting" pose: eyes closed, paws together, no hum.
- **Halo**, readable across the room: radius lerps from 0 to 10 px with Faith, CREAM at 0.35 alpha, flickering +-1 px at 3 Hz. It is never drawn in a rarity color.
- **Deposit hop** (layered on the chant):
  - Followers turn toward the shrine, staggered 60 ms by distance, and hop 4 px with squash (1.2, 0.85) then stretch (0.9, 1.15) over 180 ms.
  - Three chant voices, detuned +-3%.
  - Halos overshoot to 12 px over 200 ms (back out) and settle at 10.
  - Under 2.0 s in total, and it never blocks input.
- **Free shrine wheel**: 12 slices.
  - Free table: coins 15 (30%), coins 40 (10%), moth cake (20%), a Grave Dirt dud (10%; the personal follower eats it happily, +10 belly), common (19%), rare (8%), epic (2.5%), legendary (0.5%). No mythic.
  - The odds are painted on a plank beside the wheel. Unused days bank as up to 3 tokens on the wheel.
- **Wheel spin**:
  - Flick or drag; release speed is clamped to 540-900 degrees/s. The server picks the result first, then the wheel turns 3 full turns plus the landing angle over 3.6 s (quint out).
  - In 25% of results next to an epic-or-better slice, it lands in the last 15% of the slice and the pointer teeters on the divider for 180 ms.
  - `tick` at each slice boundary. The pointer flap tips -14 degrees and springs back over 70 ms.
- **Bonus meter**:
  - 15 candle notches. Every spin (free, coin or dollar) lights one with a flare and `blip`.
  - On the 15th, all of them flare for 300 ms, `whoosh` plays, and a bonus wheel pops out (scale 0 to 1.3 to 1.0 over 220 ms).
  - Bonus table: rare 80, epic 18, legendary 2. It is painted with the rest.
- **Wheel reveal**: 120 ms hit-stop. The prize rises from its slice with a 2-frame rarity ring, 12 + 4 particles per tier above common, and `reveal_<tier>`. Shake: common 0, rare 1 px, epic 2 px, legendary 3 px.
- **Personal follower at the door, by time away**:
  - Under 8 h: waiting at the door.
  - 8-36 h: asleep on the doorstep, with a z every 900 ms.
  - 36 h-7 d: sitting with an empty bowl.
  - Over 7 d: the flock curled at the shrine, one candle stub per day away (max 14).
  - Then a request-mark pop, a run at 1.5x and a hug (squash 1.3/0.75, elastic over 200 ms, 3 hearts).
- **Decorating**:
  - The chest spills 6 items per row, each with a 1 px rarity outline.
  - The drag ghost is 50% alpha and snaps to 16 px, with a CREAM outline when valid. An invalid spot shakes +-2 px for 120 ms.
  - Drop: squash (1.2, 0.85), 6 dust and `pop` at 0.7. The nearest follower walks over within 2 s and sniffs.
- **Sound levels**: chant -6 dB, coin -10, chomp -8, growl -12, dirge hum -18, tick -9, reveal stingers -4.

**Money-rule check:** belly is fed only with coins and a deposit never fills it; Faith is restored only by money that landed through `move()`; and any dollar-paid spin uses a cosmetic-only table with no coins and no food.

**Leave out:**

- Paying money for access or currency.
- Sickness and paid cures.
- One-hour shop windows.
- Selling items back for currency.
- Coin prizes on any machine that costs dollars.
- Timers on deposit requests.

**Sources**

- https://strategywiki.org/wiki/Webkinz_World/Wheel_of_Wow
- https://webkinz.fandom.com/wiki/Wheel_of_WOW
- https://webkinznewz.ganzworld.com/kinzapedia/wheel-of-wow/
- https://webkinznewz.ganzworld.com/announcements/we-have-updated-the-webkinz-prize-pool/
- https://webkinznewz.ganzworld.com/announcements/webkinz-prize-pool-update/
- https://webkinz.fandom.com/wiki/Daily_KinzCare
- https://webkinz.fandom.com/wiki/Family_Score
- https://webkinz.fandom.com/wiki/Webkinz_X
- https://webkinznewz.ganzworld.com/announcements/webkinz-x-revealed-pet-requests/
- https://webkinznewz.ganzworld.com/carousel/webkinz-x-revealed-pet-requests/comment-page-1/
- https://webkinznewz.ganzworld.com/announcements/season-25-guide-week-3-2
- https://webkinznewz.ganzworld.com/announcements/release-237/comment-page-1/?login=1
- https://webkinz.fandom.com/wiki/Webkinz_World
- https://webkinz.fandom.com/wiki/Webkinz_Guide
- https://webkinz.fandom.com/wiki/Dr._Quack%27s_Clinic
- https://webkinz.fandom.com/wiki/Dr._Quack
- https://webkinznewz.ganzworld.com/tips-tricks/keeping-your-pets-healthy/
- https://webkinznewz.ganzworld.com/tips-tricks/wishing-well-2/
- https://webkinz.fandom.com/wiki/Today's_Activities
- https://webkinz.fandom.com/wiki/Simple_Ways_to_Get_KinzCash
- https://umsi580.lsait.lsa.umich.edu/s/thanks-for-playing-video-game-nostalgia/item/5350
- https://webkinz.fandom.com/wiki/Curio_Shop
- https://webkinz.fandom.com/wiki/Arte_Fact
- https://webkinz.fandom.com/wiki/Gems
- https://webkinznewz.ganzworld.com/kinzapedia/gem-hunt/
- https://webkinz.fandom.com/wiki/Webkinz_Crown_of_Wonder
- https://webkinz.fandom.com/wiki/My_House
- https://webkinznewz.ganzworld.com/announcements/webkinz-room-design-tips-use-columns-to-create-a-unique-looking-room/
- https://webkinz.fandom.com/wiki/Webkinz
- https://en.wikipedia.org/wiki/Webkinz
- https://www.kfvs12.com/story/7091912/webkinz-online-pets-does-it-work/
- https://www.tampabay.com/archive/2007/12/22/sooner-or-later-webkinz-gets-us-all/
- https://www.computerworld.com/article/1651318/how-webkinz-is-getting-children-hooked-on-the-web.html
- https://knowledge.wharton.upenn.edu/podcast/knowledge-at-wharton-podcast/move-over-beanie-babies-webkinz-are-coming-to-a-store-and-virtual-world-near-you/
- https://summit.sfu.ca/item/9146
- https://en.wikipedia.org/wiki/Tamagotchi_effect
- https://dra.revistas.csic.es/index.php/dra/article/download/1059/1430/4059
- https://dash.harvard.edu/handle/1/12136084
- https://ixd.prattsi.org/2025/09/design-critique-finch-ios-app-2/
- https://blog.duolingo.com/how-duolingo-streak-builds-habit
- Caveat: Ganz never published meter decay rates, so every Hoard timing here is a design choice.

---

## 4. Club Penguin (New Horizon Interactive / Disney, 2005-2017)

### The mechanic: play-to-wear in a crowded hub

Every minigame sits behind a door off one shared square. Every 1-3 minute run pays coins scaled by score. The coins buy clothes and furniture, which you then wear and place where a crowd can see them. The crowd gives the coins their value: a coin you can't show off is just a number.

How it ran in the original:

- **The map is the menu.** Rooms are single screens you click to walk across, and each minigame lives in the building that fits it.
- **Pay.** Coins were about score/10, doubled once you owned all of that game's stamps. Every run paid something.
  - Cart Surfer: an efficient run made about 450 coins (900 with all stamps). Tricks scored 10 (a turn) to 100 (a flip), and mixing tricks scored best.
  - Ice Fishing: 3 worms are your lives. A jellyfish, a crab and a shark get in the way, and the late Mullet needs a caught fish as bait.
  - Puffle Roundup ran 120 s rounds.
- **Prices.** New penguins got 500 coins. Items cost hundreds to thousands, and a 2011 columnist made 5-10 coins a game.
- **Things that changed.** The catalogs changed monthly. Igloos held up to 130 items. There was a party every month with a free item, and a hidden pin every two weeks. Membership gated most buying.
- **Status.** Items that were never sold again became status symbols; the Beta Party Hat was only available in two 2-hour windows in September 2005.
- **Puffles** had care meters and ran away when neglected. A walked puffle helped in some games (the green puffle grabbed coins in Jet Pack Adventure) and set off fireworks at full stats (from 2013).
- **Snowballs** could be thrown anywhere. In the Mall they turned into gold coins with a coin-drop sound.
- **Coins for Change** (2007): 2.5 million players gave about 2 billion coins to decide how $1M was split among three charities.

### Why it works on the player

1. **Every run pays, and skill pays more.** There is no losing run, only a smaller payout (the competence need in self-determination theory). It is the steady counterweight to the casino.
2. **Fixed prices become "how many runs".** Every item is a short goal with a visible end (goal gradient).
3. **What you earn is worn where it is seen.** Coins become identity and status.
4. **Earning and spending are seconds apart.** Play, pay, walk, buy and be seen takes about five minutes, and the next door is always in view.
5. **Something changes every time you come back.**
6. **A pet comes with you.**
7. **Hoard is single-player, so it has to supply the audience.** A reward means more when someone reacts to it, and Hoard's followers are that audience.

### How Hoard uses it

1. **The Square (Step 5 hub).**
   - One 480x270 screen with no scrolling: a dark plaza lit by four loud doors. The casino is center back as the front door, with the arcade, the gate and the shrine around it. The fishing hole and a mine cart sit at the edges.
   - Tap anywhere and the leader walks there in a straight line. No door is more than about 3 s from another.
   - Holding followers, the personal follower and 6-10 nameless cultists fill the Square, so it never looks empty.
   - Each door bleeds its own sound, so the owner hears the casino before seeing it.
2. **Earning coins (Step 2).**
   - Tap the pool for fishing (with the owner's timing bar), or the cart for the mine run (a Cart Surfer rebuild). Each runs 2 minutes.
   - Pay is coins = max(5, floor(score/10)). The coins fly from the score on the cabinet glass into a pouch on the leader's hip.
   - Each game has four picture stamps. Owning all four doubles that game's pay for good.
3. **Spending coins (Steps 2 and 5).** Things are sold where they're used:
   - follower food at the shrine larder;
   - pity items from the dealer;
   - wheel tokens at the wheel;
   - wearables and furniture at the Coin Stall, a tent in the Square with six things on a rack and prices painted on their tags.

   The first tap equips a preview and the second buys. If the pouch is short, the item shakes and a ghost stack the size of the gap floats over the pouch. The rack changes on the 1st of each month, and old items come back the next year.
4. **Spending money (Step 1), the part Club Penguin gives Hoard.**
   - A case moves exactly its price, the cosmetic goes straight onto the leader, and the door puts the owner back in the Square wearing it, in front of the crowd.
   - The reaction depends on rarity only:
     - common: the two nearest followers glance;
     - rare: heads within 96 px turn;
     - epic: a gasp, and three followers hop over;
     - legendary: everyone forms a ring and chants for 3 s in a gold glow;
     - mythic: the Square dims, a red spotlight falls on the leader, and everyone kneels.
   - The next morning one cultist wears a grey knockoff of the newest epic-or-better piece.
   - The outfit becomes a wearable record of deposits.
5. **The puffle is the personal follower.** It trails the leader and does a trick when tapped. It comes into every coin game and grabs one stray coin or fish every 8 s, the same help at any size or mood. Once a day it stops and digs something up.
6. **The igloo is the house (Step 5).** The owner drags coin furniture and case relics anywhere and picks the music. When money lands in the House Fund, the followers file in for an open house, sit on the furniture and stare at the rarest relic.
7. **Something to do between things (Step 4).** Press and hold on empty ground to throw a glowing ember. Followers chase it; hit one and it squashes, and sometimes it throws one back. There is no reward. This is the snowball fight, and it is a direct fix for "nothing to do but bump into buildings."

### Feel spec

- **Square**: 30x17 tiles of 16 px.
  - The leader walks straight at 80 px/s with 4-way facing, a 1 px waddle every 125 ms, and a stop squash of (1.1, 0.9) for 60 ms.
  - The longest door-to-door walk is 220 px (2.75 s).
- **Doors**:
  - Tap: the door squashes (1.08, 0.92) for 80 ms and the leader walks in. An iris closes over 220 ms (cubic in), holds black for 60 ms and opens over 220 ms, with `door` then `whoosh`.
  - Exit: the leader pops out with a 3 px hop and a landing squash of (1.2, 0.8), elastic back over 150 ms.
- **Door sound bleed**:
  - Each door loops a 2-4 s ambience at lerp(-30 dB, -10 dB) by distance, within 160 px.
  - Facade light pulses 0.65 to 1.0 on a 1.4 s sine, and the sign flickers 2 frames every 3-7 s.
- **Rounds**: 120 s.
  - Countdown 3-2-1-GO at 0.5 s per beat: `tick` three times, then pitch 1.5 with a 2 px shake on GO.
  - In the last 10 s the music pitch ramps 1.0 to 1.1 with a tick every second.
  - The end is a 300 ms freeze and a `whistle`.
- **Tally**: coins = max(5, floor(score/10)), counted over 0.8-2.0 s.
  - One 6x6 coin every 33 ms arcs 18 px from the glass to the pouch at (12, 252), with `coin` pitch running 1.0 to 1.8.
  - The pouch squashes (1.15, 0.88) on each landing.
  - The final beat is `cash`, a 2 px shake and a pouch pop from 1.35 to 1.0.
- **Stamps**: 4 per game, 24x24.
  - Difficulty is shown by 1-4 notches and ink density, never by rarity colors.
  - Mid-run, a stamp slides in over 160 ms and holds 1.2 s.
  - With all four owned, an x2 stamp slams onto the total (2.2 to 1.0 in 110 ms, 70 ms hit-stop, 3 px shake), and the second half of the coins tallies at double speed.
- **Fishing**:
  - 3 worms are the lives, and the hook depth follows the pointer.
  - A bite starts a 48x6 bar sweeping for 0.7 s with a 10 px pale zone; a tap in the zone hooks the fish (+50).
  - Hazards: a jelly zaps the fish off, a crab cuts the line (lose a worm), an eel eats fish and worm.
  - After 15 fish, the Big One rises and needs a hooked fish as bait. Landing it is +1000, with 1.5 s of slow motion at 0.4, a 4 px shake and `splash_big`.
- **Mine cart**:
  - 120 s. Tricks score 10-100, and repeating the same trick back to back scores x0.5.
  - Tap to jump, hold to crouch, left/right or swipe to lean.
  - A wrong lean wobbles for 0.8 s; a second wrong lean during the wobble crashes and costs 3 s.
- **Crowd reaction** (once per new item; later visits get one glance):
  - Common: the 2 nearest followers turn their heads for 1.0 s.
  - Rare: everyone within 96 px turns, staggered 40 ms by distance, with a 1-frame glint on the item.
  - Epic: `gasp`, and the 3 nearest hop 6 px and walk to within 24 px.
  - Legendary: everyone turns within 0.5 s, forms a 40 px ring and chants for 3 s.
  - Mythic: the Square dims to 40% over 400 ms, a red cone falls on the leader, and everyone kneels for 2 s with a 3 px shake, then chants for 4 s.
- **Puffle**:
  - It trails 18-24 px behind, following where the leader was 0.25 s earlier.
  - It hops 3 px every 2 steps, does an idle trick every 6-10 s, and plays `pop` at 1.3-1.6 for a trick when tapped.
- **Daily dig**:
  - After 45 s of walking in the Square, the personal follower digs for 1.2 s.
  - The find: 70% 10-30 coins, 25% food, 5% a common cosmetic. Up to 3 unclaimed digs bank.
- **Coin prices** (starting point; see Decisions):
  - A new save starts with 150 coins. A good run pays 60-120 (120-240 with all stamps).
  - A common wearable costs 120, furniture 80-400, and the top wearable 1,200, about a week of two good runs a day.
- **Ember throw**:
  - Hold 250 ms on empty ground (or right-click). The ember arcs over 400 ms with a 24 px apex and lands in an 8-particle puff.
  - Followers within 48 px trot over.
  - A hit squashes the follower to (1.3, 0.7) with `pop`, and 25% of the time it throws one back after 600 ms. 0.5 s cooldown.
- **Open house**: followers enter one every 300 ms, sit on the nearest furniture, face the rarest relic and stay 20 s.
- **Pouch jingle**: for 3 s after any payout, each step plays `coin` at -18 dB, pitch 1.2-1.4.

**Money-rule check:** coin pay never reads deposits, streak, follower size or mood; the Coin Stall sells only things that move no money; and the crowd reacts to cosmetic rarity only, never to the size of a deposit or to a stock buy.

**Leave out:**

- Membership gating.
- Coins for Change (coins never steer real money).
- Never-again rares and short windows.
- Followers running away.
- Timed rare-item shops.
- Paged catalogs.
- Fake other players.
- Grinding as the only coin source.
- Bigger celebrations for bigger deposits.
- Streak or mood changing payouts.

**Sources**

- https://breezewiki.discard.no/clubpenguin/wiki/Coin
- https://en.wikipedia.org/wiki/Club_Penguin
- https://www.bangordailynews.com/2011/01/23/news/cool-game-illuminates-preferences/
- https://clubpenguin.fandom.com/wiki/List_of_Games
- https://cpicewhite.yolasite.com/mini-ghames-help.php
- https://cp3d.fandom.com/wiki/Pizzatron_3000?oldid=7976
- https://clubpenguinrewritten.fandom.com/wiki/File:Cart_Surfer_Grind.gif
- https://clubpenguin.rebelfederation.com/cpr-stamp-guide-cart-surfer
- https://clubpenguin.fandom.com/wiki/File:Bean_Counters_fish.png
- https://clubpenguinjourney.fandom.com/wiki/Ice_Fishing
- https://breezewiki.discard.no/clubpenguin/wiki/Mullet
- https://anyflip.com/lqvqc/abfm/basic/151-200
- https://tundrapenguin.fandom.com/wiki/Puffle_Roundup
- https://penguinorigins.wiki.gg/wiki/Jet_Pack_Adventure
- https://clubpenguin.rebelfederation.com/cpj-stamp-guide-jet-pack-adventure/
- https://clubpenguinjourney.fandom.com/wiki/Stamps
- https://clubpenguin.fandom.com/wiki/Furniture_Catalog
- https://clubpenguin.fandom.com/wiki/File:Carpet_furniture.png
- https://clubpenguin.fandom.com/wiki/Portal:Parties
- https://clubpenguinrewritten.fandom.com/wiki/Parties_and_Events
- https://clubpenguin.fandom.com/wiki/File:Jitsu.jpg
- https://clubpenguin.fandom.com/wiki/Rarity
- https://clubpenguin.fandom.com/wiki/Snowball
- https://clubpenguin.fandom.com/wiki/Puffle_Interface
- https://clubpenguin.fandom.com/Puffles
- https://clubpenguin.fandom.com/wiki/Red_Puffle
- https://clubpenguin.fandom.com/wiki/Fish_Burger
- https://www.giantbomb.com/games/3030-36105/
- https://clubpenguin.fandom.com/wiki/Tour_guides
- https://clubpenguin.fandom.com/wiki/File:Rockhopper%27s_Rare_Items_June_2008.png
- https://www.chiefmarketer.com/clubs-penguins-raise-cold-cash-for-charities/
- https://thewaltdisneycompany.com/club-penguins-coins-for-change-inspires-real-world-action-through-connected-play/
- https://clubpenguinkrew.yolasite.com/ninjas.php
- https://thecentraltrend.com/114657/opinion/club-penguin-a-retrospective
- https://rocketsnail.com/clubpenguin/
- https://www.lancaster.ac.uk/fass/events/digital-literacies/Ref%20Docs/MARSHesrc1.pdf
- Caveat: almost every number comes from fan wikis and fan-run servers. Treat them as tuning references.

---

## 5. Balatro (LocalThunk / Playstack, 2024)

### The mechanic: the scoring cascade

Balatro scores Chips x Mult, resolved one trigger at a time, left to right, through jokers the player picked and put in order. A poker hand sets base Chips and base Mult. Each scored card adds Chips. Each joker, in slot order, adds Chips, adds Mult or multiplies Mult. Only at the end does Chips x Mult multiply out, and the product pours into the round score against the blind's target. Order matters: on a base of 5 Mult, +16 then x2 gives 42, while x2 then +16 gives 26. A few cheap modifiers combine into numbers that grow by orders of magnitude, and the game shows every step happening.

How it runs in the original:

- **Base hands**: High Card 5x1, Pair 10x2, Two Pair 20x2, Three of a Kind 30x3, Straight 30x4, Flush 35x4, Full House 40x4, Four of a Kind 60x7, Straight Flush 100x8.
- **Order of scoring**: the base hand, then played cards left to right, then held-card effects, then jokers left to right, then Chips x Mult.
- **Jokers**: 150 of them (61 common, 64 uncommon, 20 rare, 5 legendary) in 5 slots. Legendaries come only from The Soul, about 0.3% per card. Some jokers scale across a run (Hologram, Green Joker, Ride the Bus).
- **The run**: 8 antes of small, big and boss blinds. A boss can't be skipped and carries one rule (The Wall, The Needle, The Flint, The Hook, The Manacle). Ante 1 draws from milder bosses.
- **Flat payouts**: $3, $4 or $5 per blind, plus interest of $1 per $5 held, up to $5. Beating a blind by a lot pays nothing extra.
- **Feel**: the score boxes catch fire once the selected hand would win, even before you commit. Each scored card plays a rising note. Scores past about 1e308 read "naneinf", and players chase it.
- **Intent**: LocalThunk built it from Big Two and Luck Be a Landlord, doesn't play poker, and has barred the IP from ever being licensed for gambling. A 2025 study of 702 reviews found about 42% discussed design or "juiciness".

### Why it works on the player

1. **The player built the engine.** Every big number is their own doing: competence plus the IKEA effect, not luck.
2. **Multiplication outruns intuition.** People estimate growth as if it adds (Stango and Zinman 2009), so the result overshoots the prediction. That gap reads as "I broke it."
3. **The sequential reveal turns one result into a string of small rewards.** Rising pitch makes the ear predict the next note until the slam resolves it. Randomness lives upstream in the draw, so every step feels earned.
4. **It explains itself.** Every number pops next to the thing that caused it.
5. **Pressure keeps the engine hungry.** The fire preview is an honest yes before you commit.
6. **Overkill pays nothing, and players chase it anyway.** The spectacle itself is the reinforcer. Hoard depends on exactly this: it can hand out the explosion freely without tying any payout to it.

### How Hoard uses it

**Where.** Step 2's daily three-room dungeon, the Undercroft under the shrine, is Balatro's ante cut down to one: room 1 is the small blind, room 2 the big blind and room 3 the boss. It runs once a day and takes about 2 minutes.

**Shape.** It stays an action run with followers, as the owner asked and as three other studies assumed: tap to move, followers attack on their own, oil in the lantern. Balatro supplies the modifier layer and the scoring. (The study's card-hand version, with bone cards whose suits are follower breeds, is kept as the fallback if the action version doesn't feel good.)

- **The door.** Each room's door has its target carved on it as a plain number: 300, 450 and 600 at depth 0. That is the only text in the room.
- **Chips.** Kills and opened heaps feed a Chips box over the door, each worth a fixed number of pips.
- **The idol shelf.** Five idols (the jokers) sit on a shelf above the door, each wearing its effect as a glyph ("+8", "x2"). They fire in shelf order.
- **Fire.** The Chips and Mult boxes catch fire the instant the room's running score would beat the door. The preview is exact because every idol is deterministic.
- **The cascade.** Walking into the door resolves it: idols fire left to right, the boxes slam, and the product pours into the carved number. Crossing the number cracks the door.
- **The fence.** Between rooms, a big-eyed fence offers 2 idols and the owner takes 1 (draft odds: common 70, rare 25, epic 5, legendary 0.3). Tap an idol, then a slot, to reorder. The fire grows or shrinks live, which teaches +Mult-before-xMult with no words.

**How saving makes it feel good.** Every Monday the shelf is dealt from the real week. The omens are yes/no facts and week counts, never scaled by dollars:

- **Lit Shrine** (money landed last week, any amount; every casino case counts): x2 Mult. The choir throws its arms up when it fires.
- **Streak Idol** (the personal follower): x(1 + 0.2 per kept week), capped at x3. It never steps back, because the follower never shrinks.
- **Quiet Tavern** (eating out under budget): +8 Mult.
- **Green Fields** (groceries healthy or bumper): +30 Chips.
- **High River** (no new subscription): +3 Mult per follower still standing.
- **Lamb's Bell** (everyone gets it): +4 Mult, so a broke week still plays.

The week's worst spending reaction becomes the boss's one rule, shown by how the boss looks and acts:

- **Sloth** (tavern packed): the first idol on the shelf sleeps and doesn't fire.
- **Hunger** (groceries over budget): base Chips and Mult are halved, and the boss gnaws.
- **Leech** (a new subscription): it carries the merchant's name on its back and drains the Chips box while it lives.
- A clean week draws a mild boss.

What the omens do to the numbers. Say room 1's kills come to 60 Chips:

- A plain week plays 60 x (1 + 4) = 300 against a door of 300, and it just opens.
- Add a quiet tavern and it is 60 x 13 = 780.
- Add money landed and it is 1,560.
- Add a ten-week streak and it is 4,680. The room burns from the first kills, and the chant gets louder with every x.

That gap is the reward: the owner can see that this week's saving is why the dungeon broke.

**Coins.**

- Each cleared room pays a fixed 8 / 12 / 20 coins. Coin heaps in a room are fixed in number. Coins never come per kill or per point of score.
- A full clear raises tomorrow's depth by 1, and targets grow x1.7 per depth (300, 510, 867, 1,474, about 12,300 at depth 7). A failed run lowers depth by 1.
- Pay never scales with depth, so strong omens push the owner deeper, not richer.
- Overkill pays a personal best carved on the dungeon wall, a louder chant, and depth cosmetics (a hat at depth 4, a halo at 7).
- At the end of a run the coin purse pays +1 coin per 10 coins held, up to +5: Balatro's interest, earned only by play.

**Ties to the other steps.**

- Step 1: the trade-up machine heats slot by slot with the same rising notes and ignites at ten.
- Step 2: the debt boss uses the same cascade but additive only. Each payment hits once for exactly its dollars; interest heals once a month.
- Step 3: the personal follower is the Streak Idol, the spending reactions become the boss, and the Monday deal is a beat of the while-you-were-out scene.
- Step 4: the pop curve, the rising notes, the hit-stop on every x, floating numbers and fire become the house juice.
- Step 5: each completed play bundle adds a permanent idol (Wall Stone: +10 Chips per room cleared). The Vault, the money bundle, adds none.

### Feel spec

- **Event queue.** Every trigger in a cascade is an entry {wait_s, callable} in one queue run by a single node, in strict order. Waits are multiplied by a speed: 1.0 normally, 2.5 while the mouse or finger is held down (hold to fast-forward, no settings menu), and 0 under reduced motion.
- **Cascade timing at 1x.** Each trigger fires on a step that starts at 0.30 s and shrinks 0.025 s per trigger (floor 0.12 s), so it accelerates. The slam takes 0.10 s, the product settles in 0.35 s, and the tally runs 0.60 s. A big room takes about 3.0 s; held, about 1.2 s.
- **Pop curve**, the house pop for every card, idol, number and button (Step 4):
  - scale = 1 + A sin(2 pi 8 t)(1 - t/0.4)^3.
  - rotation = R sin(2 pi 6.5 t)(1 - t/0.4)^2.
  - Both run for 0 <= t <= 0.4 s, with a random sign on R.
  - A = 0.20 for props, 0.35 for idols, 0.25 for numbers, 0.12 for buttons. R = 0.12 rad, or 0 for numbers.
- **Floating numbers**:
  - "+7" spawns in CREAM, 8 px with a 3 px NIGHT outline, rises 10 px over 0.5 s (cubic out) and fades over the last 0.2 s.
  - +Mult numbers are BILE.
  - xMult numbers are 10 px and start at scale 1.6, settling elastic over 0.25 s.
- **Notes**:
  - Each Chips trigger plays `note` (a bone xylophone at C5, 120 ms or shorter) at pitch 2^(s/12), walking up the major scale and resetting each room.
  - +Mult triggers continue the walk an octave up at -3 dB.
  - xMult plays `mult_hit` (a low drum plus a choir "HAH") at 0.85 + 0.05 per earlier xMult.
  - The cascade gets its own pool of 4 players.
- **xMult hit**:
  - 70 ms hit-stop: pause the overlay's queue with `tween.set_speed_scale(0)` and resume on a timer that ignores time scale.
  - The Mult box flashes, then pops with A = 0.4, with `main.shake(2.0, 0.15)`.
  - The choir raises its arms for 0.4 s, and `chant` plays at -12 dB.
- **Slam**: the 40x14 boxes slide 6 px toward each other in 0.10 s. A 1-frame white flash and `slam`, then the product appears at scale 1.6 and settles over 0.35 s.
- **Tally into the door**:
  - The count runs over 0.6 s (quart out), with `tick` every 30 ms at pitch 1.0 to 1.5.
  - Crossing the target: `boom`, a 2-frame flash, `main.shake(4.0, 0.3)`, a 3-frame crack across the carved number and 8 dust. Shake never goes above 6 px.
- **Fire**: f = clamp(log10(score / target), 0, 3).
  - Particles: 8 + 24f, life 0.5 s, upward speed 20 + 20f px/s, BILE to CREAM, flame height 6 + 10f px.
  - `crackle` plays at -18 + 4f dB.
  - At f >= 2 the room darkens 20%. At f = 3 the boxes jitter 1 px every frame.
- **Big numbers**:
  - Commas up to 999,999,999, then mantissa-e form ("4.7e12").
  - The font steps 10 / 8 / 6 px at 5, 8 and 11 characters so the number fits in 40 px.
  - Never a $ in these boxes.
- **Idol shelf**:
  - 5 slots of 18x18, each idol with a 5 px glyph and a rim in its rarity color.
  - Real-week idols pulse alpha 0.75 to 1.0 on a 1.6 s sine and carry a tiny shrine mark.
  - A swap tweens in 0.15 s, and the fire updates the same frame.
- **Monday deal**:
  - Idols drop onto the shelf 0.35 s apart, each with a squash (1.3, 0.7) to (1, 1) over 0.18 s, `thunk` and 6 dust.
  - The boss mask drops last over 0.8 s with `drone` and acts out its rule once.
- **Dollars stay additive.** Dollars appear only as exact amounts on things (the debt boss's HP, plaques). Never an x, fire or a Chips x Mult box near a dollar figure.

**Money-rule check:** the dungeon never calls `move()` and only reads yes/no week facts each Monday; coins are fixed per room; and the depth ladder must keep a saver's and a non-saver's coins equal over a month, which Step 2 has to show in a simulation before the money omens ship.

**Leave out:**

- Rewards proportional to score.
- Omens scaled by dollars, or drawn from holdings or prices.
- Stats on casino cosmetics.
- Multipliers near dollars.
- Destroying anything won with money (Balatro's glass cards).
- 8-ante runs and endless mode.
- Tooltips and run-info tables.
- Vouchers and consumables, for now.
- Red Mult and blue Chips: they collide with mythic and rare, so use BILE and CREAM.
- A game-speed menu.
- Anything of Balatro's own: name, Jimbo, card art, shader, sounds, code.

**Sources**

- https://www.inverse.com/gaming/balatro-tips-for-scoring-big
- https://forum.quartertothree.com/t/balatro-a-cheating-frenzy-roguelike-poker-deckbuilder-deserves-a-thread/161018?page=13
- https://primagames.com/gaming/all-poker-hands-and-their-chips-and-mults-in-balatro
- https://informatika.stei.itb.ac.id/~rinaldi.munir/Matdis/2024-2025-2/Makalah2025/Makalah-Matdis-2025-IF-ITB%20(10).pdf
- https://dotesports.com/indies/news/balatro-antes-blinds-explained
- https://steamcommunity.com/app/2379780/discussions/0/596263931969820687
- https://criticalhits.com.br/dicas/balatro-todos-os-blinds-do-jogo/
- https://progameguides.com/balatro/how-does-ante-work-in-balatro/
- https://www.tvtropes.org/pmwiki/pmwiki.php/VideoGame/Balatro
- https://www.pcgamer.com/balatro-tips/
- https://games.gg/balatro/guides/balatro-economy-guide/
- https://games.gg/balatro/guides/balatro-jokers-guide/
- https://www.giga.de/games/balatro-alle-joker-freischalten--01JYP8RPYMGMY8WQJHTKKGXH3E
- https://mobalytics.gg/blog/tier-lists/best-balatro-jokers/
- https://steamcommunity.com/app/2379780/discussions/0/604143740583441031
- https://blakecrosley.com/guides/design/balatro
- https://steamcommunity.com/app/2379780/discussions/0/4346606879508270539
- https://setsideb.com/tag/lua/
- https://anais-siiepe.ufpel.edu.br/2025/LA_04940.pdf
- https://mechanicsofmagic.com/2025/05/23/balatro-and-addiction-whos-the-monster-in-frankenstein-really/
- https://www.matchstickeyes.com/2025/04/27/balatro-the-joy-of-making-numbers-go-up/
- https://shacknews.com/article/139116/balatro-inspiration-luck-be-a-landlord-reddit-ama
- https://www.pcgamer.com/i-dont-play-poker-at-all-says-solo-developer-who-made-the-poker-roguelike-i-cant-stop-playing/
- https://www.pushsquare.com/news/2024/08/balatro-creator-ensures-ip-wont-ever-be-used-for-gambling
- https://gigazine.net/gsc_news/en/20241217-balatro-rating-pegi-18
- https://www.pocketgamer.biz/balatro-exceeds-5-million-in-sales-on-all-platforms
- https://en.wikipedia.org/wiki/Balatro
- Hoard repo: `backend/features/week/reactions.py` (the week states the omens read: shrine, crops, tavern, drains).
- Caveat: the 70/25/5 shop weighting and the ante target figures were not confirmed by search.

---

## 6. Vampire Survivors (poncle, 2021; 1.0 in 2022)

### The mechanic: the visible escalation loop, built from physical pickups

Every kill spills an XP gem on the floor. The gem flies into you once you are in range, the bar fills, and a full bar freezes the world for a power pick that makes your attacks visibly bigger, so the next wave spills gems even faster. The biggest payouts come as treasure chests, whose contents are rolled before you touch them and then shown with a slot-machine fanfare. The reward is a thing you physically collect, and it adds up to power you can see.

For Hoard: every real dollar becomes a mote of light that flies home. The motes fill one Hoard bar. A full bar freezes the room and drops a reliquary chest. The room itself gets brighter and louder as lifetime savings grow.

How it runs in the original:

- **Input.** Movement is the only input; weapons fire on their own timers.
- **Gems.** Blue holds up to 2 XP, green up to 9, red anything beyond that. Gems inside the Magnet radius fly to you. Vacuum pulls in every gem on the map and can only drop after level 12. When more than 400 gems are on the ground, new XP pools into one red gem.
- **Levels.** A level-up pauses for 3-4 choices, and each level costs more.
- **Gold.** Each kill has a 75% chance to drop a 0.5 coin, plus bags worth 10 and 100, and Gold Fever lasts 10 s. Gold carries over between runs, so a lost run still pays.
- **Chests** upgrade 1, 3 or 5 items. The tier is rolled when the boss spawns, not when you open it.
  - Opening one pauses the game, plays a tier jingle, spills coins and scrolls icons like slot reels.
  - The first six chests on a save are scripted 1-1-3-1-1-5 and can't be skipped. The 5-item ceremony unlocks a skip only after 50 of them.
- **Time.** Runs stop at 30:00, when the Reaper arrives. Options toggle damage numbers, flashing and shake.
- **Origin.** Galante came from the gambling industry, and Wikipedia says he drew on slot-machine flashiness for the chests.

### Why it works on the player

1. **The reward is something you can touch.** You steer into it, it snaps to you and it makes a sound, hundreds of times a minute.
2. **The bar turns small wins into one countable goal** (goal gradient).
3. **The freeze-and-pick puts a choice at the peak**, and the result shows on screen within seconds (competence and autonomy).
4. **The power compounds visibly.** The game never tells you you're stronger; it shows you.
5. **The chest is a jackpot that is already decided.** All the uncertainty is in the presentation, and a learned sound (the 5-item jingle) becomes a cue the player craves.
6. **Scripted early luck** guarantees every new player sees the top of the ladder in the first session.
7. **The skip is earned.** The ceremony is taught first, and later the player chooses to keep watching it.
8. **A capped session plus near-misses** pushes another run, while carried-over gold makes losing still feel like progress.

### How Hoard uses it

1. **Every real dollar becomes a physical mote.**
   - When a request that called `move()` returns a completed move, the source bursts bone-white motes. Sources are a case machine, a scratch-off, the wheel, the claw, a debt payment, a rule or a draw deposit.
   - Motes are always CREAM, never a rarity color. Coins are brass and never share a burst with motes. The owner learns without being told: white light is real money and always exact; color is cosmetic luck.
   - The mote unit is the smallest of $0.25, $1, $5, $25 or $100 that keeps a burst at 60 motes or fewer. A $1 scratch-off is 4 quarter-motes, a $20 case is 20 one-dollar motes, and $250 is 50 five-dollar shards. Any remainder rides the last mote, drawn one size larger.
2. **The motes fly home** to the Hoard: the pile of bones and light behind the dealer, and the shrine bowl in the village.
   - A plaque on the pile ticks up by each mote and lands exactly on the server's `amount_cents`.
   - The choir hops and chants one syllable per 5 motes.
   - This is the owner's "coin fountain and chant whenever money lands", made of the owner's own dollars.
3. **The Hoard bar** is the only always-on HUD: a 2 px cream line across the top of the casino and the village. Each mote that lands adds its value.
   - The first three bars take $10, $20 and $30, so the very first $20 case fills a bar inside minute one.
   - After that, a bar is 50% of the average weekly extra over the last 8 weeks, rounded to $5 and clamped to $10-$200.
   - The step never grows with level; the escalation is in what levels look like.
   - Every completed move into an own account counts, including rules that fire while the game is closed. Stock buys at Marlo's counter never count.
4. **A full bar freezes the world and drops a reliquary chest.**
   - The choir stops mid-chant, the music drops to a low pad, the bar shatters, and a bone reliquary falls in front of the dealer. If a reveal is playing, the chest waits until it ends.
   - Its size (1, 3 or 5 cosmetics) is rolled on the server in the same request that moved the money; the client only animates.
   - The size odds are painted on the wall and spoken: 1 item 75%, 3 items 20%, 5 items 5%, with a 5-item chest guaranteed if the last 9 had none.
   - Each item fires a shell from the belt and box, so it counts toward pity, and the dealer's counts stay the only odds in the room.
   - The first six chests on a save are scripted 1-1-3-1-1-5 and can't be skipped, so the 5-item jingle is heard in week one. After that, a tap skips 1- and 3-item chests; 5-item chests become skippable after 20 of them.
5. **The evolution slot.** Stage-ups set by real balances (a house stage, a wall segment, a growth stage of the personal follower) ride the next chest as an extra slot that never spins. It rises with a choir chord while the building or follower flashes across the room. A change that money decided is never dressed up as luck.
6. **Escalation over a lifetime.**
   - Hoard level = bars filled. Each level adds one visible thing to the casino: another machine's marquee lights up, another chanting voice joins (up to 8), the floor glow widens.
   - The pile grows one stage per doubling of lifetime saved: stage = floor(log2(lifetime_saved / $25)). Compounding becomes a shape the owner watches grow.
   - Hoard level is cosmetic only. It never raises shrine storage, coin yield or odds.
7. **The Bell (while you were out).** Money that landed while the game was closed waits as motes on the shrine steps. In the scene's first beat the shrine bell rings, and every mote streams home at once. The plaque counts to the exact sum and the followers chant; if the bar fills, the chest drops right there. Motes never fade, and ignoring them changes nothing, because the money is already home.
8. **Coin minigames on Vampire Survivors rules (Step 2).**
   - In the dungeon, followers attack on their own and the owner only moves.
   - Coins are brass pickups pulled in by a magnet radius, and a rare Bell pickup sweeps the floor.
   - Coin Fever runs only in the mine cart, which has no real-week modifiers.
   - Every run stops hard at 2:00 with a clean screen clear.
   - The iron chest at the end of the dungeon gives 1, 3 or 5 items drawn from coins, food, pity tokens and cosmetics. The bone reliquary (money) and the iron chest (play) never swap contents.
9. **The debt boss (Step 2).** A payment's motes fly into the boss as hits: a white flash, hit-stop, knockback and a cream "-$50". Monthly interest heals it once with a slow, muted green "+$31". The payment also fills the Hoard bar.

### Feel spec

- **Base**: 480x270 at 60 fps, with positions rounded to whole pixels. At most 200 particles on screen and 3 full-screen flashes per second.
- **Mote emission**:
  - One mote every min(0.025 s, 1.2 s / N), so any burst lasts 1.2 s or less.
  - Launch at 70-150 px/s in an upward cone (-160 to -20 degrees), gravity 320 px/s^2, drag x0.9 per frame, burst phase 0.30 s +-0.08.
- **Mote homing**: speed ramps from 60 to 480 px/s over 0.35 s (quad in), heading turns at 12 rad/s, and the mote is collected within 6 px. 3-frame trail at alpha 0.6 / 0.35 / 0.15.
- **Mote look**:
  - CREAM core with a 2 px additive halo at 0.35.
  - Sizes: $0.25 = 2x2, $1 = 3x3, $5 = a 5x5 shard, $25 = a 7x7 orb, $100 = a 9x9 heart with a 2-frame pulse.
  - With 60 or more already on screen, the overflow condenses into one heart showing its value in 6 px type.
- **Mote sound**: `mote` (under 150 ms) at 2^(s/12), stepping up the minor pentatonic [0,3,5,7,10] over two octaves, then wrapping. At least 28 ms apart, with extras dropped. -10 dB. The last mote plays `cash` and `chant` together.
- **Plaque**: counts up per mote, is set to `amount_cents` on the last, and punches 1.0 to 1.35 to 1.0 over 0.18 s. 8 px CREAM with a 3 px NIGHT outline.
- **Pile**: each landing squashes it to (1.06, 0.94) for 50 ms. Its light radius grows 4 px while receiving and eases back over 0.4 s.
- **Chant**: on every 5th mote, one back-row follower hops 3 px and chants at pitch 0.9, 1.0 or 1.12. Active voices = min(8, 1 + hoard_level / 5).
- **Bar**:
  - 2 px tall at y = 2, full width minus 16 px gutters. INK track, CREAM fill.
  - The leading edge jumps in 0.08 s, and the trailing fill follows over 0.4 s.
  - In the last 20%, a 1 px highlight sweeps across every 0.8 s.
- **Bar full**: 120 ms hit-stop, a 2-frame white flash, 12 cream shards falling, `level_up`, and a zoom from 1.0 to 1.08 over 0.5 s toward where the chest will land.
- **Chest**, 3.2 / 4.4 / 6.0 s for 1 / 3 / 5 items:
  - It falls in 0.28 s and lands with a squash (1.3, 0.7), 8 dust, `hit` and a 1 px shake.
  - Wobble at 0.45 s: +-4 to +-8 degrees at 10 Hz for 0.6 s. Neutral cream beams leak from the seams, as many as the true item count.
  - Lid at 1.05 s: `pop` and the tier jingle (`chest_1` 1.2 s, `chest_3` 2.4 s, `chest_5` 4.0 s; same key, more layers), a 1-frame flash and 24 grey sparks.
- **Chest reels**, from 1.15 s:
  - One 16x16 column per item, starting at 700 px/s and slowing on a cubic curve.
  - The first column stops at +0.9 s and each next one 0.35 s later.
  - `reel_tick` at least 30 ms apart. Filler comes from the belt and box.
  - Each stop: 60 ms hit-stop, a rarity ring growing from 0 to 20 px over 0.25 s, and `reveal_<tier>`. Epic adds a 2 px shake; legendary and mythic add their cutscenes.
- **Floating numbers**: pop from 1.6 to 1.0 in 0.10 s, rise 14 px over 0.7 s, fade over the last 0.25 s. Payments are CREAM "-$50", coins brass "+12", and interest a muted green "+$31", once a month.
- **Debt boss hit**:
  - The boss flashes white for 2 frames.
  - Hit-stop is 60 ms under $25, 80 ms for $25-99, 120 ms for $100 and up.
  - Knockback 3 px in 0.08 s, back over 0.2 s. `hit` at pitch 0.9-1.1 and a 2 px shake.
- **Pickups**:
  - The player moves at 60 px/s. Coins within 24 px home at 120 px/s, ramping to 360, with the same pentatonic climb.
  - Coin Fever (mine only): 10 s, +0.5 s per coin, +5 s per purse, capped at 10 s. Coins count x2, the screen edges glow brass and the music goes up 2 semitones.
  - The Bell pickup never appears before 60 s.
- **Taps everywhere**: squash to (0.9, 1.1) for 50 ms, stretch to (1.1, 0.9) for 80 ms, and settle over 120 ms. Idle: everything bobs 1 px on a 1.2 s sine with a random phase.

**Money-rule check:** the mote count, mote sizes and plaque all come from the response's `amount_cents` and land on the exact number; the reliquary holds only cosmetics, never coins, food or rerolls; bar steps scale with income and never grow; and stock buys get no motes, no bar progress and no chest.

**Leave out:**

- Chests that pay gold.
- A Luck stat.
- A steeper XP curve.
- Late-game whiteout.
- Teaser beams that don't match the contents.
- Endless modes.
- Anything for stock buys.
- A Reaper that costs anything.
- Idle auto-play on anything tied to money.

**Sources**

- https://en.wikipedia.org/wiki/Vampire_Survivors
- https://theconversation.com/vampire-survivors-how-developers-used-gambling-psychology-to-create-a-bafta-winning-game-203613
- https://researchportal.port.ac.uk/en/publications/vampire-survivors-how-developers-used-gambling-psychology-to-crea/
- https://vampire-survivors.fandom.com/wiki/Experience_Gem
- https://vampire-survivors.fandom.com/wiki/Treasure_Chest
- https://vampire.survivors.wiki/w/Treasure_Chest
- https://vampire.survivors.wiki/w/Chest
- https://vampire.survivors.wiki/w/Music
- https://vampire.survivors.wiki/w/Growth
- https://vampire.survivors.wiki/w/Vacuum
- https://vampire.survivors.wiki/w/Attractorb
- https://vampire.survivors.wiki/w/Orologion
- https://vampire.survivors.wiki/w/Gold_Fever
- https://vampire.survivors.wiki/w/Gold_Coin_(currency)
- https://vampire-survivors.fandom.com/wiki/Gilded_Clover
- https://vampire-survivors.fandom.com/wiki/Evolution
- https://vampire-survivors.fandom.com/wiki/The_Reaper
- https://vampire.survivors.wiki/w/Options
- https://progameguides.com/vampire-survivors/how-to-farm-gold-in-vampire-survivors/
- https://www.nerdsandscoundrels.com/vampire-survivors-luck/
- https://steamcommunity.com/app/1794680/discussions/0/3175603565752259060/
- https://steamcommunity.com/app/1794680/discussions/0/4924132112059825217/
- https://steamcommunity.com/app/1794680/discussions/0/3201493834358639726
- https://steamcommunity.com/app/1794680/discussions/0/3827539750708105096/
- https://steamcommunity.com/app/1794680/discussions/0/3734079155586709816/
- https://steamcommunity.com/app/1794680/discussions/0/596263353496695814/
- https://steamcommunity.com/app/1794680/discussions/0/604161881226104048/
- https://poncle.itch.io/vampire-survivors/devlog/324009/v022-now-available
- https://www.joshwcomeau.com/email/009
- https://www.thevibes.com/articles/lifestyles/53373/vampire-survivors-an-escalating-dopamine-rush-disguised-as-a-retro-game
- https://benjaminglover.substack.com/p/how-a-game-rife-with-gambling-mechanics
- https://www.pcgamesn.com/vampire-survivors/power-ups-best
- https://ken.ieice.org/ken/paper/20230315OCSt/eng/
- https://www.wayline.io/learn/game-feel/1
- https://bugnet.io/blog/how-to-fix-hitstop-or-freeze-frame-feeling-off
- Caveat: exact per-level XP numbers and the original chest frame timings were not verified. Hoard's chest timings are original design values.

---

## 7. Animal Crossing (mainly New Horizons; New Leaf and Wild World for the clock)

### The mechanic: overnight resolution on a shared real-time clock

The world keeps the player's real time and keeps running while they are away. What the player does today (pays the loan, orders an item, plants a money tree) the world finishes while they sleep, and the result waits for them the next morning, after the 5 AM day line. The house built overnight after a loan payment is the clearest case.

How it runs in the original:

- **The clock.** The game reads the console clock. A new day starts at 5:00 AM, so late-night play still counts as today. The game doesn't simulate while it is off: on load it applies the whole gap at once (fossils, weeds, mail). There are 24 hourly music themes.
- **The house loans.** Moving out of the tent costs 5,000 Nook Miles. The Bell loans after that are 98,000, 198,000, 348,000, 548,000, 758,000, 1,248,000 and 2,498,000, which is 5,696,000 in all.
  - There is no interest, no minimum and no deadline.
  - The bigger house appears the next morning.
  - Paying everything off earns a personal flag and free exterior changes.
  - Producer Hisashi Nogami has called repayment one of the biggest reasons people keep playing.
- **Daily check-in** is a fixed, finite set: 4 fossils, 1 money rock, 1 glowing spot and 1 message bottle. The Nook Stop login bonus climbs from 50 to 300 Miles and resets on a missed day. Orders arrive the next morning. Daisy Mae comes only on Sunday from 5 AM to noon.
- **Being away has gentle, visible costs**: about 3 weeds a day, roaches after about a month, and after about 15 days a villager may say they want to move.
- **Intent.** Eguchi told GDC 2006 that inconvenience is a large part of why the game is habit-forming, and balanced it with things you can do right away.

### Why it works on the player

1. **The reward is certain, delayed and visible.** The paid-off house appears tomorrow, which leaves an open loop the player carries into real life. Because the reward is certain, the wait reads as anticipation, not frustration.
2. **Rationing makes each day small and finishable.** There is always something left for tomorrow and never a backlog.
3. **A world that kept time without you feels alive**, and it feels like it noticed you.
4. **A loan with no pressure keeps the goal and drops the threat.** The early loans are small, so the first wins come fast.
5. **Absence costs a little, and the cost is cheap to fix.** Cleaning up is satisfying in itself.

For saving, this fixes the core problem: a deposit's real reward is far off and invisible. Overnight resolution turns it into a certain reward tomorrow morning, and the immediate juice covers today.

### How Hoard uses it

**The overnight**: money lands now, the village finishes it while the owner sleeps, and tomorrow it is waiting.

1. **Clock.**
   - The game day turns at 04:00 local time. (Animal Crossing uses 05:00; three other studies chose 04:00.) This is a platform change, because `ctx.today` is `date.today()` today.
   - `run_days` already catches up every missed day on load. Each `@daily` hook can also write rows to an `away_events` queue (day, kind, priority, payload), and the scene reads that queue.
   - In the Pyodide build, a device clock moved backwards is ignored until it passes the latest time already seen.
2. **Opening.** If the owner has been gone under 8 hours and no day line has passed, the game opens straight into the casino. Otherwise the while-you-were-out scene plays first:
   - one small moon crosses the top for each night away;
   - dawn comes up and the shrine bell tolls once;
   - up to 6 beats play in priority order;
   - then a whip-pan into the casino, where the dealer says the day's first line.
3. **The house fund as a no-pressure Nook loan in reverse (Step 5).**
   - Stages follow Animal Crossing's loan curve as fractions of the house goal: tent at 0, then 1.7%, 5.2%, 11.3%, 20.9%, 34.2%, 56.1% and 100%. With a $60,000 goal that is $1,032 / $3,120 / $6,780 / $12,540 / $20,520 / $33,660 / $60,000.
   - The demo's $8,250 House Fund opens at stage 3 (walls) with $4,290 to the roof, so the owner starts with a house already standing. That is honest endowed progress.
   - Money into the House Fund grows a brick pile beside the scaffold at once, with motes and a chant. It can come from a case aimed at the house, a rule, or the brick box: three physical bricks ($1 pebble, $5 brick, $20 stone), each its own `move()`; click one and the leader carries it over.
   - Overnight the followers build. At dawn the pile is gone and the next stage's silhouette has filled up to the true balance. Every night with any deposit also adds one fixture (a lantern, a bone wind chime, a gargoyle), so every deposit pays off the next morning even when the dollar gap is large.
   - Crossing a threshold puts up scaffolding. The next morning the scaffold drops and the stage is revealed. Then the Mason, a smiling mole, traces the dotted outline of the next stage and paints the dollar gap on the board.
   - There is no deadline, no minimum and no nagging. When nothing goes in, the Mason naps on the scaffold.
   - When the goal is reached, the owner's banner goes up and exterior recolors are free forever.
   - The wall (emergency fund) works the same way with stone courses.
4. **Morning rounds (Step 2).** Free, finite, about 2 minutes, coins and cosmetics only:
   - ring the shrine bell (streak coins);
   - dig 4 bone cracks;
   - hit the coin rock;
   - dig the glow crack for a cosmetic seed that blooms over 3 mornings;
   - do the Gem Hunt dig at the mine mouth;
   - collect the free shrine pack (up to 3 bank).
5. **Absence is visible, cheap to fix, and never costs money (Step 3).**
   - Glowing fungus creeps over paths and machines at 3 tufts per missed day, and each pops for 1 coin.
   - After 30 days, bats hang in the house rafters.
   - Faith falls with days since money landed.
6. **Real-clock ambience (Steps 1 and 4).**
   - Casino neon is brightest at night, and the light changes in four bands.
   - The shrine bell tolls the hour.
   - The draw priest stands at the shrine on Sunday from 04:00 to 12:00, and the draw results arrive in Sunday's scene.
   - On Sunday, holding followers are simply their new size.

Changed from the study: the day-7 candle vigil is folded into the Doubting band, the red "many nights" moon became a large pale moon (red is mythic), and Gem Hunt joined the morning rounds.

### Feel spec

- **Day line**: 04:00. The scene plays on the first open after a day line or after 8+ hours away; otherwise the game opens on the casino with a 250 ms door whoosh.
- **Scene open**:
  - 300 ms of black.
  - One 8x8 moon per night away (up to 7; 8 or more shows one large 16x16 pale moon), staggered 120 ms, each with `tick` at 0.8 + 0.05 i.
  - The dawn tint tweens CanvasModulate from #2b1d3a to #ffffff over 1.2 s (sine out) under one `bell` toll at -10 dB.
- **Beats**: a camera pan of 450 ms (cubic in-out) and a hold of 900 ms each, at most 6 beats, and 12 s or less for the whole scene. Click advances; holding 600 ms or Esc skips.
- **Brick pile**: one 4x3 brick per $5 landed since the last build, up to 24, then a crate. Each brick drops 8 px with a bounce over 220 ms and plays `thunk` at 0.92-1.08.
- **Overnight fill**:
  - Rows = floor(32 x (balance - prev_threshold) / (next_threshold - prev_threshold)), as a high-water mark.
  - New rows rise one at a time, 60 ms apart, each with a 0.5 s back-out pop, 6 dust (#8a7a6a) and `thunk` +3% per row.
- **Stage complete**:
  - The scaffold falls over 250 ms, then 80 ms hit-stop, a 3 px shake for 200 ms and 24 dust.
  - The stage scales 1.0 to 1.08 to 1.0 over 300 ms with `level_up`, and the followers squash, stretch and chant for 1.5 s.
  - The Mason traces the next outline over 800 ms at 30% alpha.
- **Nightly fixture**: one per night with at least $1 into the House Fund, from a 40-item pool, with a 200 ms pop.
- **Shrine bell streak** (coins): 10, 20, 30, 40, 50, 60 and 70 on days 1-7, then 70 every day. A missed day steps back one rung, never below 10.
- **Bone cracks**: 4 a day, each a pulsing 1 px glow on a 2 s period. 3 clicks dig one (squash 0.9/1.1, `dig`), paying 10 coins or a book fragment.
- **Coin rock**: one a day. Up to 8 hits within 4.0 s of the first; hit n pays n + 1 coins (44 max). Each hit gets a 40 ms hit-stop and `rock_hit`, 4% higher each time; it cracks on hit 8.
- **Glow seed**: sprouts, buds and blooms over 3 mornings, with a 120 ms rarity flash on the bloom. Odds are carved on a stone beside it: common 70, rare 22, epic 6.5, legendary 1.3, mythic 0.2. Decoration only.
- **Absence creep**: fungus capped at 30 tufts; 5 bats at 5 coins each to shoo.
- **Light bands**: 05-09 dawn (#c8a0b0 at 15%), 09-17 day, 17-21 dusk (#a06070 at 15%), 21-05 night (#302040 at 35%, neon x1.6). A band change tweens over 60 s, with a 4 s music crossfade.
- **Hour bell**: tolls hour % 12 times (12 at noon and midnight), 1.2 s apart, at -18 dB. Followers glance at the shrine.
- **Goal reached**: the banner rises 24 px over 1.5 s under `level_up` and `chant`.

**Money-rule check:** only the picture waits overnight; every deposit moves at once through `move()` and the board shows the true balance immediately; built stages never unbuild; and nothing on the real clock gates or times a money action.

**Leave out:**

- The loan itself: Hoard never lends.
- Turnips.
- Money trees and any game-made interest.
- Villagers who leave.
- Hard-reset login streaks.
- Shop hours on anything that moves money.
- Scolding.
- Rules changed by a patch.
- Clock tricks as a way to farm.

**Sources**

- https://nookipedia.com/wiki/Home_loan
- https://twinfinite.net/2020/03/animal-crossing-new-horizons-house-all-upgrades/
- https://www.imore.com/animal-crossing-new-horizons-how-upgrade-your-tent-house
- https://nookipedia.com/wiki/Flag
- https://en.wikipedia.org/wiki/Tom_Nook
- https://nookipedia.com/wiki/New_day
- https://primagames.com/tips/when-does-new-day-start-animal-crossing-new-horizons
- https://www.cheatcc.com/articles/the-wall-clock-is-the-game-how-animal-crossing-tells-time/
- https://nookipedia.com/wiki/Time_travel
- https://iwataasks.nintendo.com/interviews/3ds/animalcrossing-newleaf/0/1
- https://www.nintendoworldreport.com/news/11224/is-that-a-franchise-in-your-pocket
- https://en.wikipedia.org/wiki/Animal_Crossing_(video_game)
- https://gamemusic.net/?p=20207
- https://sportskeeda.com/esports/what-happens-play-animal-crossing-new-horizons-month
- https://twinfinite.net/guides/animal-crossing-new-horizons-how-to-get-rid-of-cockroaches/
- https://nookipedia.com/wiki/Weed
- https://nookipedia.com/wiki/Roach
- https://sportskeeda.com/esports/what-fastest-way-earn-nook-miles-animal-crossing-new-horizons-2022-guide
- https://www.pocketgamer.com/animal-crossing-new-horizons/10-things-to-do-every-day-in-animal-crossing-new-horizons/
- https://imore.com/animal-crossing-new-horizons-how-unlock-nook-shopping-phone-app
- https://nookipedia.com/wiki/Money_tree
- https://nookipedia.com/wiki/Shizue
- https://inverse.com/gaming/animal-crossing-new-horizons-turnips-prices-where-is-daisy-may-hours
- https://kotaku.com/don-t-neglect-turnips-in-animal-crossing-new-horizons-1842497058
- https://nintendoeverything.com/animal-crossing-new-horizons-bank-of-nook-lowers-interest-rate
- https://www.fandom.com/articles/time-traveling-animal-crossing
- https://rowatcher.com/news/daily-login-bonuses-are-lazy-design-here-s-what-works-instead
- Hoard repo: `backend/core/hooks.py` (`run_days` already catches up missed days), `game/demo/state_0.json` (demo House Fund $8,250).

---

## 8. Stardew Valley (ConcernedApe, 2016; version 1.6)

### The mechanic: Community Center bundles

A ruined building carries a fixed, fully visible checklist of item-specific slots. Slots are grouped into bundles, and bundles into rooms. You fill the slots with things you already produce in ordinary play across the seasons. When the last slot of a room fills, the town physically changes overnight in a cutscene, and a new place or tool opens for good.

How it runs in the original:

- **Structure.** 6 rooms and 30 bundles. Each room restores one piece of the valley: the bridge, the Greenhouse, panning, the minecarts, a friendship boost, the bus.
  - Bundles appear as golden scrolls on the walls.
  - Some show more items than they need (the Artisan Bundle shows 12 items for 6 slots), so the player chooses.
- **Rewards.** Each bundle pays its own reward at once. A finished room pays overnight in a cutscene of the Junimos doing the work. A known flaw: if two rooms finish the same day, only one cutscene plays.
- **The Vault** is the only room paid in gold: 2,500g, 5,000g, 10,000g and 25,000g, a 1:2:4:10 ratio.
- **The Joja route** lets the player skip the bundles by paying gold. It unlocks the same things but feels hollow; fans treat it as the villain route.
- **Pull cue.** Hovering over an item a bundle needs makes the golden scroll icon pulse.
- **Seasons and days.** 4 seasons of 28 days, and crops die when the season ends. A day lasts about 14 real minutes, and energy runs out. Passing out costs about 10% of gold (sources disagree on the cap). Shipped items pay out overnight with an itemized tally.

### Why it works on the player

1. **It turns a sandbox into a route.** The next useful thing to do is always on the wall, and every fish or ore becomes a slot.
2. **Open slots nag, and the last slots pull hardest** (the Zeigarnik effect and goal gradient). Closure comes often: about 30 small ones, 6 medium and 1 big.
3. **Choice gives ownership.** "Any 4 of 6" lets the player choose the path.
4. **Effort beats price.** The Joja route proves it inside the same game: identical unlocks bought with gold feel hollow.
5. **The reward is a place, not a number.** A bridge is permanent and visible every day.
6. **The overnight payoff.** Ending a day promises a show the next morning: "just one more day."
7. **Scarcity on the calendar and in the day** means every day ends with unfinished business and a choice for tomorrow.

### How Hoard uses it

**The ruins: Step 5's "Stardew-style savings bundles that open buildings", fed by Steps 1 to 4.**

The casino's back door opens onto the village at night. Six buildings stand in chains, each with a stone Offering Tablet bolted beside its door. The tablet is the whole UI: no scroll, no menu, no words.

- Each tablet is a grid of round sockets, and each socket shows the dark silhouette of exactly what goes in it. Pip dots show counts.
- Dollar sockets are glass vials with the amount etched on the glass in 6 px digits ("$62/$80").
- The hub has a Plaque of Stars with 6 empty star sockets, one per ruin.

The six ruins hold 24 bundles and about 100 sockets, and take about one real year to finish:

1. **The Pond (Step 2).** Four bundles of mine items. Opens the fishing minigame.
2. **The Undercroft (Step 2).** Fish, ore and a follower's shed feather. Opens the daily dungeon. It needs Pond output, so the ruins chain.
3. **The Granary (Step 3).** Full Sheaf marks (dropped on Monday after a week of groceries under budget), Cold Hearth marks (after a quiet eating-out week), follower favorites, fish and dungeon relics. Opens the follower kitchen: favorite foods and the Feast. Gruel and stew are sold at the shrine bowl from day one.
4. **The Ossuary (Step 1).** Any-tier cosmetic sockets, Dead Drain trophies (a subscription with no charge for 40 days) and boss bones. Opens a walk-in hall for the collection book. The book itself sits on the casino counter from day one.
5. **The Bell Tower (the capstone).** Four seasonal bundles. Opens a louder chant on every deposit and two more praying spots at the shrine.
6. **The Vault**, the only ruin with dollar sockets.
   - Four vials sized 1x, 2x, 4x and 10x the owner's own weekly unit E, which is Stardew's ratio.
   - E is the median weekly amount moved to own accounts or above-minimum debt payments over the last 8 weeks, rounded down to $5, with a minimum of $5. It is fixed when a vial is hung.
   - Demo with E = $40: $40, $80, $160 and $400, $680 in all, about 17 weeks at the owner's normal pace.
   - Vials fill themselves from transfers that have already landed.
   - The Vault restores the Cathedral, where legendary and mythic cutscenes play from then on, plus one cosmetic set.

**Never locked by bundles**: the casino machines, the gate and debt boss, the weekly draw, the followers, the house, the wall and the collection book. Bundles open play places and decoration only.

**The first session.**

- The owner pulls a $20 case and walks out the back door. The Vault's first vial already holds $20 of bone-white liquid, because it counts deposits since Monday.
- The mine mouth glows, and the Pond tablet shows silhouettes of three ores. After one 2-minute mine run the owner is holding 2 copper chunks.
- From across the map the Pond tablet pulses, and an ember thread drifts from the leader to it.
- Tap the tablet: items that fit shake and the rest dim. Tap a chunk and it hops into its socket with a thunk; the pitch climbs with every socket filled.
- On a bundle's last socket the followers sing a chord, the rope cinches, and a follower carries the bundle into the ruin on its head.

**When a room finishes**, the chains fall link by link and a star goes into the plaque. That night the ruin shows scaffolding, torches and hammering. On the next open after the day line, the restoration cutscene plays. Every finished room gets its own cutscene, which fixes Stardew's one-per-night flaw.

**Seasons** are real quarters: Molt (Oct-Dec), Long Dark (Jan-Mar), Thaw (Apr-Jun) and Rot Bloom (Jul-Sep).

- Each season brings 3 exclusive pond fish and 2 mine ores.
- Seasonal bundles show 6 silhouettes from this season and the next, and take any 4.
- A missed season never locks a bundle.

**Days.** The leader's lantern holds 3 flames per real day.

- One full-yield coin run (mine, fishing, or the whole dungeon) burns one flame. Unused flames bank, up to 3 extra.
- With no flames left, runs still play for practice, with no coins and no items.
- Flames never gate deposits, machines, followers, the gate or the draw.

**How it makes saving feel good.** The Vault vial is the one place money is shown as a goal, and it fills by itself whenever money lands. A $20 case visibly adds $20 to the vial, and finishing the vials raises the Cathedral where the best reveals play. Vials count deposits, not balances, so a real withdrawal never empties one.

**Build notes.**

- `content/village/bundles.json`: rooms [{id, plot, opens, bundles: [{id, show: [socket], need, reward}]}], where each socket is {kind: item|mark|cosmetic_tier|vault, id, qty, tier, mult}.
- `backend/features/village/` tables: `village_bundles_fill` (bundle_id, socket, item_id, qty, ts) and `village_bundles_room` (room_id, done_on, shown_on).
- Vault progress = SUM of landed transfers to own accounts or above-minimum debt payments since the vial was hung. Overflow carries into the next vial.
- `POST /bundles/offer` {bundle_id, socket, item_id} consumes items only, never money.

### Feel spec

- **Colors**: empty silhouettes are MUTED at 35% alpha. Filled sockets and vault liquid are CREAM, not gold.
- **Tablet idle**: breathes at scale 1.00 to 1.02 on a 2.4 s sine. A ruin in chains sways its chain sprite 1 px at 0.5 Hz.
- **Fit pulse**: when the satchel holds something that fits, the tablet pulses 1.00 to 1.12 to 1.00 every 0.8 s. An ember thread of 8 CREAM particles leaves the leader toward it every 0.5 s. An off-screen ruin gets a 4 px edge arrow that bobs 2 px.
- **Open**: tapping the tablet zooms the camera 1.0x to 1.6x in 0.35 s and dims the world to 50%. Fitting items hop 2 px at 3 Hz, and the rest desaturate to 40%.
- **Insert**:
  - The item flies to its socket in 0.28 s on an 18 px parabola.
  - It lands with a squash of (1.3, 0.7) back to 1.0 over 0.12 s, a 33 ms hit-stop, a 1 px shake and 6 dust motes.
  - `socket_thunk` rises up the major scale per socket filled in this bundle.
- **Bundle complete**:
  - 67 ms hit-stop and a 2-frame white rune flash. The rope cinches over 0.2 s.
  - A chord (`chant` at pitch 1.0, 1.26 and 1.5) and 24 particles.
  - A follower runs over at 60 px/s, takes the bundle on its head and walks it into the ruin.
  - The reward drops and bounces twice (12 px, then 4 px).
- **Room complete**: the chains fall one link every 90 ms, each `chain_drop` a semitone lower, then a 3 px shake. A follower carries a star to the plaque. That night: scaffold, 3-5 torch followers, hammer ticks at 4 Hz, and windows flickering at 2 Hz.
- **Restoration cutscene**:
  - Letterbox bars slide in 20 px. The camera pans to the ruin over 1.2 s, and the hammering speeds up from 4 to 12 Hz over 1.5 s.
  - A 2-frame white flash, 60 dust and 20 sparks, and the sprite swaps with a 1.0 to 1.08 to 1.0 y-squash on a low boom (`boss_down` at 0.8).
  - The windows light one at a time, 80 ms apart, and the followers chant.
  - 7 s or less, and a tap skips it. Several restorations queue with a 0.4 s gap.
- **Vault fill** (on the next village visit after money lands):
  - One mote per $5 (max 20) arcs from the door of the machine that caused it into the vial.
  - `coin` rises a semitone per mote.
  - The liquid rises over 0.6 s with a glug, and the etched number counts up in whole dollars.
- **Vial full**: the cork pops and the vial turns solid. Its cosmetic reward comes forward with its own rarity sound, and any overflow pours into the next vial over 0.4 s.
- **Season change**: a 1.5 s palette crossfade. New fish shadows circle the pond, and the seasonal silhouettes flip in 50 ms apart.
- **Lantern**: 3 flame sprites on the leader's lantern, not on a HUD bar. A spent flame gutters out over 0.5 s with a puff of smoke; banked flames show as small embers.
- **Pacing targets**:
  - The first bundle in the first session; the Pond on day 2 or 3; the Undercroft around day 7-10.
  - The Ossuary and Granary in weeks 2-6; the Vault at about 17 weeks; the Bell Tower after a full year.
- **Reduced motion**: zoom, shake and hit-stop off. Cutscenes become a 1.5 s crossfade, and sounds stay.

**Money-rule check:** dollar sockets exist only in the Vault and only read transfers that have already landed in own accounts (deposits, not balances, so a withdrawal never empties one); there is no pay-to-skip route; and the Vault opens no place that earns coins.

**Also take:**

- **The itemized overnight tally**: each deposit walks into the morning scene as a counted object.
- **The pulsing scroll**: any item that fits a socket makes its ruin pulse, and a follower perks up when the leader carries its favorite.
- **Grandpa's candles**: four shrine candles lit by yearly behavior milestones (kept weeks, drains slain, bills on time, ruins restored), never by dollar amounts. They can be re-lit any time by offering a mine diamond.
- **Festivals**: one festival on a fixed real date each season, with free coin games and a follower parade.

**Leave out:**

- The Joja route.
- The pass-out penalty.
- Things dying at season change.
- Energy that blocks activities.
- One cutscene per night.
- The in-session clock.
- A separate bundle menu.
- Gold that is spent away.
- Vault rewards with resale value.
- A one-time judgment at a deadline.
- Sockets that need one specific random drop.

**Sources**

- https://stardewvalleywiki.com/Bundles
- https://wiki.stardewvalley.net/Bundles
- https://stardewvalleywiki.com/Community_Center
- https://stardewvalleywiki.com/Junimos
- https://stardewvalleywiki.com/Pantry
- https://www.stardewvalleywiki.com/Vault
- https://gameshorizon.com/guides/stardew-valley-community-center-bundles-guide/
- https://www.gfinityesports.com/stardew-valley/how-to-repair-community-center/
- https://stardewvalleywiki.com/Joja_Community_Development_Form
- https://www.thegamer.com/stardew-valley-community-center-guide/
- https://www.bisecthosting.com/blog/stardew-valley-community-center-guide-bundles-unlock
- https://stardewvalleytracker.com/bundles
- https://stardewvalleywiki.com/Time
- https://www.stardewvalleywiki.com/Day_Cycle
- https://stardewvalleywiki.com/Passing_out
- https://en.number13.de/stardew-valley-that-happens-when-you-have-no-more-energy/
- https://stardewvalleywiki.com/Seasons
- https://stardewvalleywiki.com/Remixed_Bundles
- https://destructoid.com/?p=261653
- https://www.stardewvalleywiki.com/Shipping
- https://stardewvalleywiki.com/Grandpa%27s_Evaluation
- https://www.carlsguides.com/stardewvalley/grandpa-end-score.php
- https://stardewvalley.net/dev-update-19/
- https://www.pcgamesn.com/stardew-valley/stardew-valley-map-design
- https://media.gdcvault.com/gdc2024/GNR/Posters/Brooke+Glasier+-+Stardew+Valley.pdf
- https://www.siliconera.com/stardew-valley-community-center-concept-art-shared/
- https://www.ballstatedaily.com/article/2018/05/what-makes-stardew-valley-so-much-fun
- https://gameinformer.com/b/features/archive/2017/01/13/funny-to-a-point-god-help-me-i-can-t-stop-playing-stardew-valley
- https://forums.stardewvalley.net/threads/community-center-restored-vs-joja-warehouse-rebuilt-ive-always-wanted-to-find-the-absolute-answer-but-what-ive-found-is-it-depends-on-how-you-pl.20725/
- https://www.holy.gg/en/post/stardew-valley-jojamart-or-the-community-center
- https://www.bisecthosting.com/blog/stardew-valley-event-calendar-birthdays-festivals-events
- https://destructoid.com/?p=595008
- Caveat: Stardew's own bundle animation frames and sound cues were not confirmed. Every timing above is Hoard's design.

---

## 9. Shattered Pixel Dungeon (Evan Debenham, GPL-3.0; source read at v4.0.2, commit 57a4e06)

### The mechanic: the ration clock

A hunger level rises by 1 every turn, and only food brings it down. Hungry starts at 300 and Starving at 450. Exactly one ration (worth 300) is guaranteed on every non-boss floor. The game always puts the relief you need one floor ahead, so you only starve by standing still. The clock is why runs are short, why floors go by quickly, why you can't grind, and why the boss on every fifth floor arrives on rhythm.

How it runs, from the source (`core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/`):

- **Hunger** (`actors/buffs/Hunger.java`).
  - The level rises 1 per turn, with HUNGRY = 300 and STARVING = 450.
  - Below 300 nothing shows at all. Crossing 300 posts one warning, once. At 450 the hero loses 0.1% of max HP per turn, a slow bleed of about 1000 turns from full.
  - Hunger freezes on a locked boss floor and while Well Fed.
- **Food** (`items/food/`): Ration 300, Pasty 450, small foods 150, Meat Pie 900 plus Well Fed (no hunger for 450 turns). Eating takes 3 turns and shows the food icon over the hero's head (`effects/SpellSprite.java`: fade in 0.2 s, hold 0.8 s, fade out 0.4 s).
- **The guarantee** (`levels/Level.java`): every non-boss floor spawns one food from a deck of {Ration 4, Pasty 1}.
- **Fixed supply** (`Dungeon.java`): the same "items left vs floors left" rule gives exactly 2 Strength potions and 3 Upgrade scrolls per 5-floor region, so the drop is certain by floor 4. None of it can be farmed.
- **Pacing** (`levels/RegularLevel.java`):
  - 4-6 rooms per floor and 3-5 items per floor. Each item lands as a plain heap 14/20 of the time, a chest 4/20, a skeleton 1/20, or a mimic 1/20.
  - No monster may spawn within 8 tiles of the entrance.
  - Half of all floors from floor 2 get a "feeling" (dark, large, traps and others).
  - Special rooms come from a shuffled no-repeat deck.
- **Bosses** sit on floors 5, 10, 15, 20 and 25, with a shopkeeper on the floor after each early boss. Goo (`actors/mobs/Goo.java`) heals +1 HP a turn standing in water, and before its big hit it pumps up over two turns (`chargeup` at pitch 0.8, then 1.0).
- **Loot decks** (`items/Generator.java`): two alternating 35-card category decks. Each draw removes a card, and artifacts never repeat.
- **Identification**: potion colors and scroll runes are shuffled each run and learned by use.

### Why it works on the player

1. **The reward is relief**, and the relief is always on the next floor: "one more floor."
2. **The pressure is fair.** The guarantee means the player trusts that moving forward fixes things. Pressure with that trust turns into momentum.
3. **It stays quiet until it matters.** One warning, once, so it never nags.
4. **It's tuned to feel like just barely making it.** Every floor ends in a small "I made it."
5. **Mistakes can be fixed.** The bleed is slow, so one bad floor hurts without ending the run.
6. **It stops grinding**, and the boss every fifth floor lands on a steady beat.
7. **Scarce things come on a schedule**, so spending them feels like a real choice.

### How Hoard uses it

1. **The clock becomes Faith's shape (Step 3).** The study proposed a separate larder clock (Hungry at 8 days, Starving at 12). It is merged into Faith (see Decisions), and these Shattered Pixel Dungeon rules carry over:
   - **Silent until it matters.** Faith shows only on the followers' bodies, never as a number outside the stats screen.
   - **One warning per threshold.** Crossing into Doubting and into Cold each plays one sound, once, and never sends a notification.
   - **Generous on purpose.** One deposit a week keeps Faith at Content or above, so a weekly saver never sees Doubting.
   - **Relief is always one step ahead.** Any deposit of any size restores Faith fully.
   - **A locked floor freezes the clock.** That becomes the lean pause: days with extra at 0 don't count.
   - **A slow bleed, never a cliff.** About 7 points a day.
2. **The ration moment becomes the deposit beat.** The study's feast choreography is kept for money landing: heads snap toward the shrine, followers run in staggered, color floods back and the chant swells.
   - The three chomps become three kneels. Belly is coin-fed, and a deposit never fills it.
   - After a Cold spell, the beat is preceded by 1.2 s of silence while a black candle is snuffed: a mourning beat, then the relief.
3. **The daily dungeon's pacing (Step 2).**
   - **Lantern oil**: the leader's lantern burns oil during a run: 60 s capacity, 1 per second. Each room has exactly one oil flask (+40 s, capped at 60), Shattered Pixel Dungeon's one food per floor. At 40 s without fuel the light shrinks to 5/8. At 60 s it goes out and the run ends with everything carried kept. No death. The 2:00 hard stop still applies, and the lantern freezes in the boss room.
   - **Room 1 is safe**: no enemy within 8 tiles of the entrance.
   - **Room 2 is the fight**: 2 + (runs this week mod 5) enemies, a 1/4 chance of a second group, and 3/4/5 heaps at 60/30/10%. Heaps are open 14/20, chest 4/20, remains 1/20, and mimic 1/20 from run 2.
   - **Room 3 is the boss**, carrying the week's rule (Balatro), with a Goo-style two-beat warning before its big attack. Behind it, about once a week, wait the caged acolyte and the week's veiled relic.
   - **Fixed supply**: exactly one veiled cosmetic relic per week of runs, out of 5 runs a week. Each run's chance is relics left / runs left, so the 5th run always has it. This is not used on paid cases, whose odds are the stated belt and box.
   - **Shuffle-bag decks** for free cosmetic sources (the daily shrine pack, dungeon chests, the post-boss pack): no duplicate until the set is done. Duplicates come only from paid cases and feed the trade-ups.
   - **Weekly vials** get new colors every Monday and are learned by drinking. They change how a run plays (magnet radius, follower speed, lantern glow), never what it pays.
   - **Level feelings**, chosen from the week, not random: groceries over budget = Overgrown (grass hides heaps); eating out over = Dark (sight x5/8, followers yawn); a new subscription = Traps; money landed = Choir (music only). Each keeps the expected coins the same and changes only risk. They are the fallback if the Balatro omens fail the coin-parity test.
4. **Bosses on a rhythm (Step 2).** Weeks 1-4 are the floors, and the end of the month is the boss floor at the gate.
   - Interest is Goo's water: the boss steps into a pool and green "+$" ticks up exactly once.
   - Below half HP the boss bar bleeds dark particles.
   - Afterwards a free post-boss shrine pack (one common cosmetic) waits, like the shopkeeper after each boss.
5. **Remains.** If the flock went Cold, a remains heap waits in room 1 of the next dungeon run with a keepsake cosmetic (at most once per 30 days). A missed stretch ends in a gift and a way back.

Changed from the study:

- The larder clock merged into Faith.
- The deposit's chomp became a kneel.
- Coin snacks that eased the clock were dropped, because coins never move Faith.
- The month-end molt was dropped, because the personal follower grows by kept weeks.

### Feel spec

- **Bands on the body**:
  - Doubting: saturation 0.7, lerped over 1.5 s (sine in-out) on the visit where it crosses.
  - Cold: saturation 0.45, candles out, the music bus low-passed at 800 Hz and -6 dB.
- **One-shot warnings**:
  - Crossing into Doubting plays `groan` once (0.4 s, pitch 0.8).
  - Crossing into Cold plays it at pitch 0.6 and lights a black candle over 0.5 s.
  - Neither ever repeats.
- **Deposit beat**:
  - Every head turns to the shrine on the first mote's impact frame.
  - Followers run in at 10 fps, start times staggered 40 ms, paths capped at 48 px so the beat fits in 1.8 s.
  - 3 kneels 0.25 s apart, each a (1.1, 0.9) squash of 50 ms.
- **Glyph pop over each head**: a 16 px icon 4 px above the sprite. Alpha 0 to 1 in 0.2 s, hold 0.8 s, fade over 0.4 s while rising 6 px (SpellSprite's timings).
- **Color return**: saturation back to 1.0 over 0.6 s (cubic out). The chant layers in one voice per follower, 120 ms apart, up to -6 dB over 1.2 s, and candles relight left to right, 60 ms each.
- **Mourning beat** (only after Cold):
  - Music ducks to -24 dB over 0.15 s and holds 1.2 s of silence.
  - The black candle is snuffed with `puff` and 4 smoke particles, then the beat plays.
  - The personal follower gets an extra 0.5 s hug.
- **Threshold scene beat**: if a band was crossed while the owner was away, the camera zooms 1.0 to 1.15 over 2.0 s on the followers at the empty bowl, then eases back over 0.5 s. 2.5 s in total; a tap skips it after 0.5 s.
- **Lantern oil**: 60 s capacity, +40 s per flask. Dimming takes 0.3 s and flickers +-1 px at 2 Hz. Going out takes 0.8 s, with `whoosh` at 0.7.
- **Goo warning**:
  - Beat 1: `chargeup` at 0.8, a 20 fps pump and the tiles in range tinted.
  - Beat 2: `chargeup` at 1.0, then the big hit with a 3 px shake for 0.2 s.
  - A region boss's arrival shakes 3 px for 0.7 s.
  - The interest heal ticks green "+$N" every 0.15 s, once a month.
- **Assets**: Shattered Pixel Dungeon's GPL `eat.mp3`, `chargeup.mp3`, `puff.mp3`, `descend.mp3`, `secret.mp3` and `goo.png` (20x14 frames) can be recolored into `game/art/packs/spd/`. Followers stay 32x32, and Shattered Pixel Dungeon's 16 px item icons fit the prop grid.

**Money-rule check:** the clock only listens to completed moves and never starts one; every penalty is a pose, a sound or a saturation change; and deposits grant no coins, oil or relics.

**Leave out:**

- Starvation damage, death, or losing anything.
- Rations scaled by deposit size.
- Upgrades bought with money.
- Identify-by-use near money.
- Text logs, buff icons, item windows and inventory grids.
- Hunger notifications and countdowns.
- Long runs and turn-based depth.
- Copying Shattered Pixel Dungeon code. Its art and sound as GPL packs with credit are fine.

**Sources**

- Source repository (GPL-3.0): https://github.com/00-Evan/shattered-pixel-dungeon. Files read at commit 57a4e06, under `core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/`: `actors/buffs/Hunger.java`, `WellFed.java`, `LockedFloor.java`; `items/food/Food.java` and the other food classes; `levels/Level.java`, `RegularLevel.java`, `SewerLevel.java`; `levels/rooms/secret/SecretRoom.java`, `levels/rooms/special/SpecialRoom.java`; `Dungeon.java`; `items/Generator.java`; `items/weapon/Weapon.java`, `items/armor/Armor.java`, `items/rings/Ring.java`; `actors/mobs/Goo.java`, `Tengu.java`, `DM300.java`, `DwarfKing.java`, `YogDzewa.java`; `effects/SpellSprite.java`; `Bones.java`. Assets under `core/src/main/assets/`.
- https://linuxphoneapps.org/apps/com.shatteredpixel.shatteredpixeldungeon/
- https://flathub.org/de/apps/com.shatteredpixel.shatteredpixeldungeon
- https://shatteredpixel.com/blog/whats-coming-in-shattered-pixel-dungeon-v060.html
- https://shatteredpixel.com/blog/whats-coming-in-shattered-pixel-dungeon-v060-2.html
- https://shatteredpixel.com/blog/coming-soon-to-shattered-better-secrets.html
- https://shatteredpixel.com/blog/coming-soon-to-shattered-levelgen-refinements.html
- https://shatteredpixel.com/blog/coming-soon-to-shattered-new-foes.html
- https://en.wikipedia.org/wiki/Pixel_Dungeon
- https://apps.apple.com/app/id1563121109
- https://pixeldungeon.fandom.com/wiki/Potion_of_Strength
- https://www.speedrun.com/shpd/guides/h39dc
- https://vaporlens.app/app/1769170/shattered_pixel_dungeon.md
- https://www.gamedeveloper.com/pc/analysis-the-eight-rules-of-roguelike-design
- https://gamasutra.com/design/-play-81-on-rogue-s-item-identification-system
- https://brogue.wiki/wiki/Traditional_roguelikes_via_Brogue

---

## 10. Buckshot Roulette (Mike Klubnika, 2023; Steam 2024 via Critical Reflex; made in Godot)

### The mechanic: the announced load

The dealer shows the exact count of each kind of shell, loads them in an order nobody can see, and fires one per turn. The draw is without replacement, so the odds are public and exact, and every shot changes them. The player is always doing the math, and the last shell is a certainty. The dealer, the slow loading, the items and the turn ritual all serve this one idea.

How it runs in the original:

- **Setup.** You wake in the back room of a nightclub and sign a waiver (six letters; GOD and DEALER are refused). A figure across the table brings out a 12-gauge.
- **The load.** Before each load the game shows how many live and blank shells are going in, then the dealer loads them and says so: "I insert the shells in an unknown order."
- **The turn.** Aim at yourself or the dealer. A blank on yourself keeps your turn, and that chains. A live round costs the target one charge.
- **Structure.** Three rounds with 2, 4 and 5 charges and 0, 2 and 4 items. A defibrillator revives you in rounds 1 and 2; in round 3 its wires are cut.
- **Items.**
  - Base game: magnifying glass (see the chambered shell), beer (eject a shell), handcuffs, hand saw (double damage), cigarettes (+1 charge).
  - Double or Nothing added the burner phone (reveals one shell's position and type), the inverter (flips the chambered shell), adrenaline (steal an item) and expired medicine (40% chance of +2, otherwise -1).
- **The dealer's mind.** Per the developer, the dealer doesn't calculate odds: he flips a coin when unsure. He was left deliberately imperfect so the game never becomes a solved puzzle.
- **Presentation.** Almost nothing on screen: lamp light, clicks, ejected casings and the pump sound. The music picks up when someone is near elimination.
- **Scale.** $3. Reported at 1M sales by April 2024 and 8M on PC by December 2025. Influenced by Inscryption: a host across a table running a game of chance with you.

### Why it works on the player

1. **Known odds with a hidden order.** The player never feels cheated, because the counts are true, and never feels safe, because the order is hidden.
2. **Drawing without replacement makes every turn a new problem.** Five shells with two live is 40%; after a blank it is 50%. A depleting pool marches straight toward the 50/50 moment, where the dopamine uncertainty signal peaks (Fiorillo, Tobler and Schultz 2003), and then into certainty on the last shell.
3. **A person across the table states the stakes.** The odds become a promise made to your face, and his formal politeness against the setting's horror is the whole tone.
4. **The ritual stretches the waiting.** Load, rack, aim, pause, bang. Most of the arousal lives in the wait.
5. **Items turn luck into decisions.** Choosing gives a sense of control (Langer 1975). A 2021 reanalysis questions that finding, and a replication found that stating the true odds reduced the effect without removing it, which suggests honest odds and fun can coexist.
6. **Escalation.** Hoard keeps points 1 to 5 and drops the life-and-death stakes entirely.

### How Hoard uses it

**Step 1, the casino table (the front door).** Every case pull is drawn from two visible loads instead of a dice roll. The dealer (Vex, from FEATURES.md) says the counts out loud before every pull. The announced load is how the owner's pity rule becomes something on the table.

1. **The belt.**
   - Twenty-five shells tumble onto the felt, sorted by color: 18 grey, 6 blue, 1 purple. The dealer counts them aloud, then loads them face-down.
   - Each case fires one shell. When the purple fires, he sweeps the rest off and loads a fresh 25.
   - So an epic or better comes within 25 cases every time. The chance climbs as the belt empties: 1 in 25, then 1 in 24, down to 1 in 2, and the last shell is certain.
2. **The box.**
   - A 10x10 grid of holes hangs on the wall behind him. When a box is loaded, two hidden holes are fixed as special. Each is gold (legendary), or red (mythic) one time in four. He announces it: "A new box. Two gold." or "One gold. One red."
   - Every case darkens one hole. When a special hole comes up, its shell fires instead of the belt's. When both specials have fired, a fresh box loads.
   - So a legendary or better comes within 100 cases every time.
3. **Simulated rates** (2 million pulls, belt plus a two-special box):
   - common 67.2%, rare 22.4%, epic 7.5%, legendary 2.2%, mythic 0.7%;
   - epic or better every 9.6 cases on average, never more than 25 apart;
   - legendary or better every 33.8 on average, never more than 99 apart.

   This lands close to the CS:GO-style target ladder (67 / 22 / 7.5 / 2.7 / 0.8). The study's one-special box gave legendary 1.8% and mythic 0.2%, so the second hole is a change.
4. **The odds are physical, with no text.** A peg rack beside the belt shows what is left by color. Spent casings land in a tray in their colors. The box grid shows the holes used.

**Moment to moment:**

1. The leader walks to the table. The dealer racks a shell and states the stakes in one breath: "Twenty to the House Fund. Nine shells. One purple." The money half is always certain; the shell half only decides a cosmetic.
2. The owner holds the $20 bill on the slot for 0.45 s.
3. The bill is stamped with their waiver signature and the destination glyph and shoots up a brass tube. Motes burst toward the jar, and the choir chants once. The money has landed before anything random happens.
4. 150 ms of silence, the bang, then the CS:GO reel.
5. The reel's filler is drawn from what is really left in the belt and box. A purple can only flash past if a purple is truly still in there, so near-misses are honest.
6. The casing drops into the tray and a peg falls. The chant at the back speeds up, because everyone in the room can count: 84 BPM on a fresh belt, 140 BPM at the last shells.

**The gold tell.** When the box's special hole is next, the dealer stands, the lamp turns gold (or red), and he takes the shell from the wall and chambers it in full view before the owner pays. The tell is always true. If the week's extra has already run out, the chambered shell waits, unchanged, for as long as it takes. He never mentions it beyond the count.

**Items, coins only.** This is the owner's "coins buy pity rerolls". The owner holds up to 4 in slots on their side of the table, and they never expire.

- **Lens** (the magnifying glass): see the chambered shell.
- **Toss** (the beer): flick a shell you have already seen into the tray. Never a purple. This is the pity reroll.
- **Whisper** (the burner phone): he leans out of the light and names one shell's position and color, and a chalk mark appears.
- **Gilding** (a softened inverter): turns a seen grey into blue, once per belt.

On the first visit each day he slides one free item across the felt, so something is always waiting.

**First visit.** Nobody explains anything. He slides a waiver across, the owner scribbles a signature with the mouse or a finger, and it hangs on the wall from then on and is stamped on every bill.

**The other machines** follow the same rule: each is a finite load he counts out loud.

- Scratch-offs come in books of 20 with stated contents: "Twenty in the book. Four blue. One purple."
- The prize wheel has 12 wedges, and a won wedge is pulled off and set on the table until the wheel resets.
- The claw machine's pile is a visible heap he counts.

**Step 2.**

- **The back-room duel**: the real Buckshot loop as a 2-minute coin minigame, with candles in place of the gun-on-a-person.
  - He announces a load of 2-8 live and blank shells. You aim at your own candle or his, and a blank on your own candle keeps your turn.
  - Three rounds, with 2, 3 and 4 candles and 0, 2 and 4 items.
  - Week modifiers: each budget line over this week adds a live shell to your first load, and a kept pledge adds a candle. A week with a deposit only changes the music (the followers sing).
  - Pays coins only: 40, 80 and 150 per round won as placeholders. A loss keeps the coins already earned.
  - Here, and only here, he is fallible like the original dealer.
- **The gate**: payments are the owner's turn, with damage exactly equal to the dollars paid. Once a month, on the statement date, the debt boss takes its turn in the open. It sets its interest on the table as pips, says the exact amount ("Interest. Forty-one twenty."), and heals exactly that.

**Step 3.** The choir counts with you: heads turn to the gun at 8 shells left, they stand at 3, and they leap and scream when the purple fires. The personal follower sits on the owner's side of the table.

**Step 4.** The bang is the template for juice elsewhere: hit-stop, white flash, smoke, casing squash.

**Step 5.** From the village, the casino sign shows the belt as a row of brass shells, and the window glows gold when a gold shell is chambered and waiting.

**When money runs out.** When extra or the transfer caps run out, the lamp over the slot clicks off, the dealer lays the gun down and says "Not this week." The belt, the box and any chambered shell wait, unchanged, forever.

Changed from the study:

- The box has two special holes instead of one.
- The duel's deposit modifier (a free Lens) became music only, because a deposit must not make a coin game easier when nothing else balances it out.

### Feel spec

- **Room layout**:
  - A black felt table across y 150-220.
  - One hanging lamp at x 240 casts a 150 px cone (additive CREAM light at 0.35 alpha). Everything outside the cone stays NIGHT.
- **Vex**:
  - A 48x48 sprite with only his face and long hands lit.
  - 2x2 glowing eyes that blink every 3-7 s, and a 2-frame idle breath on a 1.2 s cycle.
  - He leans 2 px into the light whenever he speaks.
- **Shells**: 3x8 px.
  - Grey plain; blue with one band; purple with two; gold with three bands plus a glint; red with three bands plus a 0.6 s pulse.
  - Rarity colors plus band shapes, so the colors can be told apart (fans of the original built a recolor mod).
  - Loaded shells are drawn brass-backed so the order stays hidden.
- **Sizes**: the belt holds 25 shells at a 4 px pitch (100 px). The peg rack uses 3x3 pegs in color columns. The box is a 10x10 grid of 3x3 holes with 1 px gaps (40x40); spent holes are dark and unspent holes dim brass.
- **Load ritual**, about 4.5 s:
  1. The lamp flickers off for 2 frames with a `buzz`.
  2. Shells fall onto the felt sorted by color, one every 40 ms, each with a 3-frame squash and a tick pitched by tier (grey 1.0, blue 1.19, purple 1.5, gold 2.0).
  3. A 1.2 s hold while the camera zooms 1.00 to 1.08 toward the purple shell, whose glint pulses.
  4. The line ("Twenty-five shells. One purple.").
  5. A 250 ms sweep.
  6. He loads them one at a time, a `clack` every 60 ms.
  7. The pegs pop up 15 ms apart.

  After the first load of the day, a tap runs the ritual at 3x.
- **Rack** at the start of each turn: `rack` (two pump sounds 180 ms apart), and the belt steps 4 px with a back-out ease over 150 ms.
- **Voice**:
  - Lines type at 28 ms per character, with a voice blip every 2 characters (square wave, 110-140 Hz, 40 ms, +-8%).
  - About 8 words a line, counts only.
  - Lines come from `backend/game/dialogue.py` through a finalizer, because the backend writes every line.
- **Hold to feed**: 450 ms on the slot. A ring fills around the bill, and releasing early drains it in 150 ms with nothing moved. While the owner holds: the music bus tweens to -14 dB, a heartbeat starts at 72 BPM, and the camera zooms 1.00 to 1.05.
- **Money lands first**:
  - The 16x7 bill slides in over 200 ms with `cash`.
  - The stamp thunks at +200 ms with a 2 px shake.
  - The tube whoosh takes 350 ms, then the mote burst.
  - "+$20" rises 18 px over 0.8 s, and one `chant`.
- **Breath and bang**:
  - The breath: 150 ms of total silence with the screen at 70% brightness.
  - The bang: 90 ms hit-stop (time scale 0.05, released by a timer that ignores time scale), a white flash at 0.8 alpha fading over 120 ms, a 3 px shake decaying over 220 ms, the camera snapping back in 150 ms, 6-10 smoke puffs, and the casing flipping out on an arc, still brass until the reel lands.
- **Reel and landing**:
  - During the reel the heartbeat climbs from 72 to 110 BPM.
  - When the reel stops, the casing drops into the tray in its color with a squash, and the clink is pitched by tier.
  - The matching peg drops 4 px with a bounce over 200 ms. Then the rarity flash.
- **Chant tempo**: BPM = 84 + 56 x (1 - shells_left / 25), built from 4 pre-rendered stems at 84, 100, 120 and 140 BPM and crossfaded over 1 s, never pitch-shifted. The village chant stays at 92 BPM.
- **Gold tell**:
  - The chant cuts to silence and the lamp lerps to LEGENDARY (or MYTHIC) over 600 ms.
  - A `chair_scrape`, and he stands, holds still for 1.5 s, walks to the wall and chambers the shell with one `clack` at 0.8.
  - On the reveal: 200 ms hit-stop and a 6 px shake for 500 ms, then the cutscene.
- **New box**: the line, and the 100 holes light in a sweep 8 ms apart. A box with a red hole also makes the choir kneel and holds the chant silent for 2 s.
- **Items**: the owner taps a 16x16 slot, and the dealer performs the item.
  - Lens: he tilts the shell into the lamp for 1.2 s, and a colored dot hangs over the chamber until it fires.
  - Whisper: low blips at 50% volume and a chalk mark.
  - Toss: a flick into the tray, a peg drops, and he racks the next shell.
  - Gilding: a brush stroke and a `ting`.
  - Placeholder prices: Lens 25, Toss 50, Whisper 40, Gilding 120 coins (see Decisions). The free daily item is a Lens 60% of the time, a Whisper 30%, a Gilding 10%.
- **Refusal**: the lamp over the slot clicks off. He lays the gun down (`thunk`) and says "Not this week." The bill in hand turns grey, and the choir sits down quietly.
- **Pacing**: a full cycle takes about 7 s (rack 0.35, line 1.2, hold 0.45, money 0.9, breath 0.15, reel about 4.5). Never under 2.5 s, and no autoplay. Reduced motion turns off shake, flash and zoom, and keeps the sounds and silences.
- **Backend shape**:
  - `casino_belt` (shells as JSON, position) and `casino_box` (special holes, kinds, position), both fixed with a secure RNG when loaded.
  - `POST /casino/case` returns the tier, the item, the new counts and the dealer's next line, and emits the `reveal` event.

**Money-rule check:** `move()` runs before any shell or hole moves, in the same transaction, and a failure rolls everything back and slides the bill out; the counts the dealer says are read from the database and are always true; items are bought only with coins and never move money; and the dealer at the table is never fallible.

**Leave out:**

- Double or Nothing's cash pot and "cash out or keep going".
- Lives or charges tied to money, and the cut defibrillator.
- Pointing the gun at the player or a follower: it fires only into the case machine, and the duel uses candles.
- The hand saw on debt bosses.
- Coin flips near money.
- A fallible or bluffing dealer at the casino table.
- Fake tells.
- Blind ejects (Toss works only on a seen shell).
- Faint shell colors.
- A long ritual every single time.
- Anything of Buckshot's own: lines, art, music or code.

**Sources**

- https://en.wikipedia.org/wiki/Buckshot_Roulette
- https://imfdb.org/wiki/Buckshot_Roulette
- https://www.casino.org/blog/how-to-play-buckshot-roulette-rules-items-strategy/
- https://www.switchbladegaming.com/horror-games/buckshot-roulette-guide/
- https://primagames.com/tips/what-every-item-in-buckshot-roulette-does-explained
- https://primagames.com/gaming/buckshot-roulette-new-double-or-nothing-items-explained
- https://www.destructoid.com/all-items-and-uses-in-buckshot-roulette/
- https://dotesports.com/indies/news/all-items-in-buckshot-roulette-listed
- https://primagames.com/gaming/all-forbidden-names-in-buckshot-roulette-explained
- https://steamcommunity.com/app/2835570/discussions/0/4356744017095577366
- https://steamcommunity.com/app/2835570/discussions/0/4329726860276721830
- https://steamcommunity.com/app/2835570/discussions/0/4356743780115509205
- https://gamecritics.com/eugene-sax/buckshot-roulette-video-review/
- https://godisageek.com/reviews/buckshot-roulette-review/
- https://www.well-played.com.au/buckshot-roulette-review/
- https://www.gameshedge.com/review-buckshot-roulette/
- https://www.gamereactor.eu/buckshot-roulette-1379503/
- https://noobfeed.com/reviews/buckshot-roulette-review
- https://maksloboda.itch.io/buckshot-roulette-shell-recolor-mod/community
- https://automaton-media.com/articles/newsjp/20240531-295690/
- https://www.thepostathens.com/r/216fbc6dd8
- https://www.worthplaying.com/article/2024/4/17/news/141624-buckshot-roulette-exceeds-1-million-copies-sold-on-steam/
- https://www.kitguru.net/gaming/joao-silva/buckshot-roulette-hits-8-million-sales-console-port-gets-delayed/
- https://www.nature.com/articles/nrn1127
- https://www.ncbi.nlm.nih.gov/pmc/articles/PMC1182345/
- https://gamblingresearch.sites.olt.ubc.ca/files/2021/09/ClarkWohl_2021_LangersIoC_AAM.pdf
- https://faculty.wharton.upenn.edu/wp-content/uploads/2020/11/Klusowski-Small-Simmons.pdf
- https://www.czasopisma.pan.pl//Content/118432/PDF/2020-04-PPB-07-Chodzynska.pdf
- Drop rates: a Monte Carlo simulation of the belt and the two-special box, 2 million pulls, run for this doc.

---

## How they combine

The ten mechanics split into three jobs:

- **Make a deposit feel good the instant it lands**: Buckshot's announced load, the CS:GO reel, and Vampire Survivors' motes and bar.
- **Leave something waiting when the owner comes back**: Cult of the Lamb's flock and shrine, Webkinz's waiting pet, Shattered Pixel Dungeon's fair clock, Animal Crossing's overnight, and Stardew's ruins.
- **Give the owner something to do with coins earned by play**: Club Penguin's doors, Balatro's cascade in the dungeon, and Vampire Survivors' pickups.

Below is the order in which the owner meets them. The name in brackets is the mechanic doing the work at that moment.

### The first five minutes: the casino front door

- **0:00. The game opens on the casino, with no menu and no title.** One lamp hangs over a felt table, machines glow at the edges, and the dealer's eyes catch the light. At the back, followers on risers hum. A new save starts at full Faith, so the risers are full: the five holding followers, sized by portfolio share, and the nameless cultists. An egg sits on the counter. *(Cult of the Lamb choir; Webkinz adoption.)*
- **0:05. The dealer slides a waiver across.** The owner scribbles anything, and it hangs on the wall. Nobody explains anything. *(Buckshot waiver.)*
- **0:10. The first load.** Shells tumble onto the felt by color, and the dealer counts them: "Twenty-five shells. One purple." The box on the wall lights up in a sweep: "A new box. Two gold." The pegs and the grid are the odds on the wall. *(Buckshot announced load; CS:GO published odds.)*
- **0:20. The choice.** Sealed cases on the shelf carry painted prices. The owner taps the $20 case. The slot mouths show real balances, and the House Fund glows. The owner holds the bill on the slot for 0.45 s: a heartbeat starts and the music ducks. *(CS:GO destination mouths; Buckshot hold-to-feed.)*
- **0:22. The money lands first.** A stamp, the tube, and twenty bone-white motes home into the House jar. "+$20 House Fund" floats up, the painted number counts up, and the choir chants one beat. The Hoard bar along the top fills, since the first bar is $10. The certain reward plays before anything random. *(Vampire Survivors mote fountain and bar; CS:GO money-landing beat; Cult of the Lamb deposit chant.)*
- **0:23. Silence, then the bang, and the case cracks.** *(Buckshot breath and bang.)*
- **0:24 to 0:31. The reel.**
  - It launches, cruises, then brakes unevenly, catching on each peg: tick, hang, tick. *(CS:GO time-warp slowdown.)*
  - The followers lean in and hum, a semitone higher each time the gap widens. *(Cult of the Lamb choir hum.)*
  - A gold eye card crawls toward the line, and the line sits half on gold for almost half a second. The choir says "ooh". *(CS:GO near-miss, staged as "short" on a save's first pull. It is honest, because two gold shells really are in the box.)*
- **0:31. It stops a few pixels short, on blue.** 83 ms of hit-stop, a blue flash, sparks, and the choir claps. The item arcs into the collection book on the counter, and a silhouette fills in. The item also appears on the leader. *(CS:GO reveal table; Stardew empty-slot pull; Club Penguin play-to-wear.)*
- **0:33. A blue casing drops into the tray, a peg drops, and the chant ticks faster.** *(Buckshot chant tempo.)*
- **0:34. The egg hatches.** It has been trembling since the money landed. Three names float over it; the owner taps one, then taps one of three body forms. The hatchling hops onto the counter next to the machine. *(Webkinz adoption; Cult of the Lamb naming rite.)*
- **0:40. The bar-full chest.** The room freezes, the bar shatters, and a bone reliquary drops in front of the dealer with one cream beam leaking from its seam. A short reel lands a common. *(Vampire Survivors reliquary, scripted first chest.)*
- **0:50. The dealer racks:** "Twenty to the House Fund. Twenty-four shells. One purple." The owner wants another. The loop has taken under a minute.
- **1:00 to 4:00. More pulls, about 7 s each and never closer than 2.5 s apart.**
  - Each one is a little different: a rare chime, the scripted 1-1-3 chests, a scratch-off book counted out loud and scratched with a finger, the prize wheel with its 15 candle notches, the claw's counted heap.
  - An epic, with its purple beam and the choir jumping, is likely within the first ten pulls.
  - The pity is in the pegs, so everyone can count.
  - *(Buckshot finite loads; Webkinz wheel bonus meter; Vampire Survivors chest script.)*
- **If extra or the day's cap runs out**, the lamp over the slot clicks off and the dealer says "Not this week." Nothing else changes. *(Buckshot refusal.)*
- **About 4:00. The owner walks out the back door into the Square at night.** *(Club Penguin hub.)*
  - The two nearest followers glance at the new blue piece. *(Club Penguin crowd reaction.)*
  - The shrine flame is tall, and the flock breathes in unison. *(Cult of the Lamb Faith at Fervent.)*
  - A brick pile has grown by the house scaffold. *(Animal Crossing brick pile.)*
  - The Vault vial on its tablet already holds the dollars. *(Stardew Vault.)*
  - The mine mouth glows, and the Pond tablet shows three ore silhouettes. *(Stardew bundles.)*
- **About 5:00. One mine run.**
  - Coins fly into the pouch, and two copper chunks come out. *(Club Penguin cart and tally; Vampire Survivors magnet pickups.)*
  - The Pond tablet pulses across the map, and an ember thread drifts toward it. *(Stardew pulsing scroll.)*
  - Nobody has explained any of it.

### The first day

- **Coin runs.** The mine run burned one of the lantern's three flames. *(Stardew lantern.)* The chunks go into the Pond tablet, and the first bundle completes in the first session: a chord, and a follower carries the bundle into the ruin. *(Stardew bundles.)*
- **The shrine.**
  - Coins go to the shrine bowl: drag gruel onto a follower holding an empty bowl. *(Webkinz feeding; Cult of the Lamb belly.)*
  - Tap followers to bless them: a squish, a heart, and a loyalty candle lights. *(Cult of the Lamb bless.)*
  - A request bubble shows a picture of a copper chunk. *(Cult of the Lamb and Webkinz requests.)*
- **Morning rounds.** 4 bone cracks, the coin rock, the glow crack (a seed gets planted), the Gem Hunt dig at the mine mouth, the free shrine pack, and day 1 of the bell streak. *(Animal Crossing finite dailies; Webkinz Gem Hunt.)*
- **The shelf.** The mine run dropped a sealed case onto the casino shelf, where it rattles. Opening it later will take a deposit. *(CS:GO cases drop free, the key is a deposit.)*
- **The gate.** The car loan stands there as the debt boss, with $6,840 of HP. A payment at the gate's slot fires motes as hits. *(Owner's debt boss; Vampire Survivors hits; Balatro additive damage.)*
- **Nothing to do but play.** The owner throws embers in the Square and the followers chase them. *(Club Penguin snowballs.)*
- **Closing the game starts the clocks that make tomorrow worth opening:**
  - shrine Devotion starts filling *(Cult of the Lamb capped storage)*;
  - bellies drain over 48 h *(Webkinz)*;
  - the house builds overnight *(Animal Crossing)*;
  - a finished Pond queues its restoration *(Stardew)*.

### The first return (day 2)

- **The while-you-were-out scene.** The 04:00 day line has passed, so the scene plays, 12 s at most, with every beat tappable. *(Animal Crossing overnight resolution.)*
  1. A moon crosses the top, dawn comes up, and the bell rings. Money that landed overnight (a payday rule) streams home as motes, and the plaque lands on the exact sum. *(Vampire Survivors Bell.)*
  2. The brick pile has become house rows, and a fixture appeared. The Pond is restored in its own cutscene. *(Animal Crossing overnight build; Stardew restoration.)*
  3. Followers stand posed in what happened: groceries ran over, so they stare at the wilting crops with growling stomachs. *(Cult of the Lamb and Webkinz quirks.)*
  4. The personal follower waits at the door, spots the leader, runs over and hugs. *(Webkinz.)*
  5. The Devotion pile is spilling over the shrine. *(Cult of the Lamb.)*
- **The sermon.** A ring pulses around the leader. Hold for 1 s: the followers kneel, orbs fly in, the chant swells. *(Cult of the Lamb sermon.)*
- **Then the owner's hands do the rest.** Tap the shrine to vacuum Devotion into coins, then feed and bless. *(Cult of the Lamb, Webkinz.)*
- **The casino.**
  - The scene whip-pans into the casino, where the dealer slides a free item across the felt. *(Buckshot.)*
  - Yesterday's case rattles on the shelf, and the belt shows exactly where it was left. Pity never resets. *(CS:GO shelf; Buckshot belt.)*

### The first week

- **Days 2-3.** The Pond opens fishing with the timing bar, and stamps begin. *(Club Penguin.)* The shelf fills with play-dropped cases. *(CS:GO.)*
- **Days 2-6.**
  - Requests are answered, and loyalty candles fill. The first level-up brings a halo at level 3 and a new idle trick. *(Cult of the Lamb loyalty; Webkinz bond.)*
  - The first epic arrives (about one every 9.6 pulls).
  - Duplicates pile in the trade-up hopper until ten glow. *(CS:GO trade-up; Balatro fire preview on the machine.)*
  - By about the sixth bar, the scripted 5-item chest drops with its long jingle. *(Vampire Survivors.)*
- **Days 7-10.** The Undercroft is restored, and the daily dungeon opens:
  - followers fight on their own *(Vampire Survivors)*;
  - lantern oil and room pacing *(Shattered Pixel Dungeon)*;
  - three loyal followers along *(Cult of the Lamb)*;
  - the idol shelf and the cascade at each door *(Balatro)*.
- **Sunday.**
  - The draw priest stands at the shrine from 04:00 to noon, and the weekly draw results arrive in the scene: every $5 deposited was an entry, and the prizes are cosmetics only. *(Owner's weekly draw; Animal Crossing's Sunday window.)*
  - Holdings update, and the holding followers are quietly resized. *(Owner; Cult of the Lamb.)*
- **Monday (the first week boundary).**
  - The dungeon shelf is dealt from last week. Lit Shrine is on, because money landed. Quiet Tavern is on. The boss wears the week's worst reaction (Hunger, for groceries, or Leech, for StreamBox+). *(Balatro omens and boss rule; Shattered Pixel Dungeon feelings.)*
  - The personal follower grows its first stage while the flock chants. *(Cult of the Lamb Keeper streak.)*
  - Quirks reset. *(Webkinz, fresh start.)*
  - If the week had extra but kept nothing, a coffin sits on the shrine instead. *(Cult of the Lamb mourning; Webkinz flower on the next deposit.)*
- **Any stretch without a deposit.**
  - The flame lowers about 7 points a day after the first.
  - By day 9 or 10 the flock is Doubting: half-lidded eyes, glances, one groan, once. *(Shattered Pixel Dungeon one-shot warning.)*
  - Any deposit of any size brings it all back in one beat. *(Shattered Pixel Dungeon relief one step ahead; Cult of the Lamb sermon.)*
- **First month end.** The debt boss takes its interest turn in the open: the pips, the exact amount, one heal. *(Buckshot boss turn; Shattered Pixel Dungeon Goo's pool; Animal Crossing monthly beat.)*

---

## Decisions where the studies overlap

1. **Two meters, and one money line.**
   - Faith (Cult of the Lamb's formula) is the only meter money drives. Webkinz's glow, Shattered Pixel Dungeon's larder clock and Animal Crossing's mood were the same idea, so they are merged into it, and each contributes poses for one band.
   - Belly is the only follower meter coins fill.
   - Loyalty, raised only by play, is the only source of shrine Devotion.
2. **A deposit never fills a belly.** On money landing, followers run in and kneel; they don't eat. Feeding is coins only.
3. **Day line at 04:00 local.** This is a platform change, because `ctx.today` is the calendar date today.
4. **One while-you-were-out scene**, 12 s or less, with every beat tappable. Beat order:
   1. the Bell (money that landed);
   2. overnight builds and restorations;
   3. the Monday deal, on Mondays;
   4. mourning, if any;
   5. posed followers and the personal follower's hug;
   6. the Devotion pile;
   7. the sermon ring.

   Then the casino. If the owner was away under 8 hours and no day line passed, the game opens straight on the casino.
5. **Pity is the belt and box** (Buckshot), with two special holes per box and one hole in four red. CS:GO's 67 / 22 / 7.5 / 2.7 / 0.8 ladder is the target, and the simulated 67.2 / 22.4 / 7.5 / 2.2 / 0.7 is close. Pity counts cases, not $10 steps.
   - The dealer's counts are the exact odds for the next pull, so Shattered Pixel Dungeon's warning against hidden ramps on paid cases is met: nothing is hidden.
   - Reliquary chest items fire shells from the same belt and box.
   - Scratch-offs, the wheel and the claw run their own counted loads.
   - Free sources (shrine pack, dungeon, post-boss pack) use shuffle-bag decks and never touch the belt.
6. **Real money is drawn as cream motes, with exact values** (Vampire Survivors' unit rule). This replaces the studies' various coin counts. The owner's "coin fountain" is the mote fountain. Brass coins mean game coins only.
   - Dollar figures are bone white with a $, and no other number carries a $.
   - Money landing gets a short hit-stop (80 ms) and the chant, but never an x, fire or a Chips x Mult box (Balatro's concern).
7. **Coin-side light is brass, never cream.** That covers the Devotion pile, coin pickups and coin floating numbers.
8. **Rarity colors stay rarity-only.**
   - No red moon, no red boss-bleed particles, no red dissenter eyes.
   - No rarity-colored stamp difficulty, and no red or blue Chips and Mult.
   - Gold flakes, not coins, fall in the legendary reveal.
   - GLOW (#ffd166) sits close to legendary gold, so use it only for the shrine flame.
9. **Money never buys coins, even through the dungeon.**
   - Dungeon coins are fixed per room and never per kill, and Coin Fever runs only in the mine.
   - The depth ladder has to keep a saver's and a non-saver's monthly coins equal, and Step 2 must show this in a simulation before the Lit Shrine and Streak Idol ship. If it fails, those two omens become Shattered Pixel Dungeon-style feelings that change risk and look, not clear rate.
   - The duel's deposit modifier is music only.
   - Only play bundles add dungeon idols; the Vault adds none.
   - Shrine storage grows with ruins restored, never with Hoard level.
   - Hoard level is cosmetic only.
10. **The dungeon is an action run, and Balatro scores it.** Followers fight, the owner moves, oil burns, and each door resolves a Chips x Mult cascade against its carved target. Room 3 is always the week's boss. The card-hand version is the fallback.
11. **Three different minigames:**
    - the mine cart (Club Penguin's Cart Surfer, with Vampire Survivors' magnet and Coin Fever);
    - fishing (Club Penguin's Ice Fishing plus the owner's timing bar);
    - the dungeon.

    Gem Hunt, the bone cracks and the coin rock are morning rounds, not minigames.
12. **The personal follower.**
    - An egg until the first deposit ever, then a tap-only naming rite (no typed text field).
    - Seven growth stages at 1, 2, 4, 8, 13, 26 and 52 kept weeks (counted in total, not in a row), drawn as Webkinz's egg-to-crowned-elder line.
    - It never shrinks, and its Streak Idol value never steps back. A broken streak only veils it.
    - It trails the leader and helps in coin games the same amount at every size (Club Penguin's puffle).
13. **Kept week**: money landed in an own account that week, or, with extra at 0, every bill was paid on time. Lean weeks never count against anything.
14. **Requests never expire.** At most 3 are open, all doable with $0, each worth +50 loyalty. Webkinz's timer rings and heart pips are dropped. Loyalty levels double as bond levels, and each level unlocks one idle trick.
15. **Food.** Gruel (5 coins) and stew (15) are sold at the shrine bowl from day one. Favorite foods (25) and the Feast (60, 5-day cooldown) arrive with the Granary.
16. **One coin table, set in Step 2 and priced in runs** (Club Penguin's rule). The studies' placeholders disagree by about 8x: Buckshot's Toss is 50 coins, while Club Penguin's pity charm is 400. A pity item should cost about one to two good runs. Daily coin sources to count:
    - minigame runs (3 flames);
    - morning rounds;
    - Devotion (about one pile a day);
    - the daily dig;
    - requests;
    - dungeon rooms;
    - the duel.
17. **One lantern.** Three flames a day cap full-yield runs (Stardew). During a dungeon run, the lit flame burns oil (Shattered Pixel Dungeon).
18. **Mourning.**
    - On the Monday after a week with extra above 0 and nothing kept: a coffin, veils, the dirge, an optional funeral (+20 Faith), and a candle on the Grave of Weeks.
    - The next deposit plants a flower beside the candle (Webkinz).
    - The day-7 vigil from Animal Crossing is folded into the Doubting band.
19. **Holding followers** resize on Sunday only, with one quiet 1.5 s tween and no sound, and they never react to price. The 40% giant and the others' stare are the only diversification nudge.
20. **The debt boss.**
    - HP = the real balance. A payment is exact, additive damage delivered as motes.
    - Interest heals exactly once a month, on the statement date (the 1st when it is unknown), telegraphed with Goo's two beats and announced by the dealer's exact amount.
21. **Pacing floors on money.** At least 2.5 s between money-linked starts, one tap or hold per pull, no autoplay, no open-many. The reel's crawl never skips. A bar-full chest waits until the current reveal ends.
22. **Collection book.** It sits on the casino counter from day one; the Ossuary later adds a walk-in hall.
23. **Chant tempo.** The casino chant follows the belt (84-140 BPM). The village chant stays at 92 BPM, and the dirge is 46.
24. **Reduced motion is one setting.** It turns off shake, hit-stop, flash and zoom, caps fountains at 5 motes, and keeps all sounds. Where the switch lives, with no menus allowed, is an open question for Step 4.
25. **Sounds.**
    - Existing names: `blip coin cash pop tick reveal_* level_up error door whoosh hit boss_down chant scratch`.
    - New names across the studies, with duplicates merged:
      - `chant_hum chant_dirge kneel heart spark growl yawn bell mutter peg chomp chime whistle gasp`
      - `splash_big dig squeak note mult_hit slam boom crackle thunk drone mote`
      - `chest_drop chest_1 chest_3 chest_5 reel_tick fever rock_hit scaffold_fall dawn`
      - `chain_drop groan chargeup puff buzz rack clack heartbeat chair_scrape ting bang`
    - Merges: `bell` covers the sermon, the Bell and the hour toll at different pitches. `thunk` covers bricks, sockets and idols. Tablet sockets use `thunk` too (the Stardew study's `socket_thunk`).
    - Reel ticks, cascade notes and mote sounds get their own players outside the 8-voice Sfx pool.

### Open questions for Step 1

- The wall needs a real account (the demo has only checking, the House Fund and brokerage).
- The day line and the `away_events` queue are platform changes, so the orchestrator has to approve them.
- Reduced motion needs a home that isn't a menu.
- Step 2's coin-parity simulation decides whether money omens stay in the dungeon.

---

## Mechanic map

Folders are the owner's five: `casino`, `minigames`, `followers`, `juice`, `village`. "Platform" means `backend/core` or `game/scripts`, which the orchestrator owns.

| Mechanic | From | Step | Folder |
| --- | --- | --- | --- |
| Belt of 25 (epic within 25 cases) and box of 100 (legendary within 100) as odds and pity | Buckshot Roulette | 1 | casino |
| Dealer states price, destination and counts before every pull | Buckshot Roulette, CS:GO | 1 | casino |
| Waiver signature stamped on every bill | Buckshot Roulette | 1 | casino |
| Hold-to-feed bill, heartbeat, breath and bang | Buckshot Roulette | 1 | casino |
| Destination mouths with real balances painted on them | CS:GO | 1 | casino |
| Money lands before the roll, in one request | CS:GO, Buckshot Roulette | 1 | casino |
| Slow-stop reel with uneven slowdown (time warp) | CS:GO | 1 | casino |
| Tension bed: music duck and low-pass sweep | CS:GO | 1 | casino |
| Honest near-miss staging from what is left | CS:GO, Buckshot Roulette | 1 | casino |
| Eye-glyph cards for legendary and mythic | CS:GO | 1 | casino |
| Reveal table: hit-stop, flash, shake, particles, zoom, cutscenes | CS:GO | 1, 4 | casino, juice |
| Gold tell: the special shell chambered in view | Buckshot Roulette | 1 | casino |
| Coin items: Lens, Toss, Whisper, Gilding (pity rerolls) | Buckshot Roulette | 1, 2 | casino |
| One free item from the dealer each day | Buckshot Roulette | 1 | casino |
| Scratch-off books, wheel wedges and claw heap as counted loads | Buckshot Roulette | 1 | casino |
| Wheel flick-spin with teeter, and the 15-notch bonus meter | Webkinz | 1 | casino |
| Trade-up machine (10 to 1, mythic welded shut) with fire preview | CS:GO, Balatro | 1 | casino |
| Collection book with silhouettes | CS:GO, Stardew Valley | 1 | casino |
| Hoard bar and the reliquary chest (1/3/5) | Vampire Survivors | 1 | casino |
| First six chests scripted 1-1-3-1-1-5 | Vampire Survivors | 1 | casino |
| Evolution slot for balance-decided stage-ups | Vampire Survivors | 1, 5 | casino, village |
| Casino grows louder with Hoard level; pile stage by log2 of lifetime saved | Vampire Survivors | 1, 4 | casino |
| Choir on the risers, sized by Faith, reacting by rarity | Cult of the Lamb | 1, 3 | casino, followers |
| Chant tempo follows shells left | Buckshot Roulette | 1 | casino |
| Refusal: lamp off, "Not this week." | Buckshot Roulette | 1 | casino |
| Weekly draw, $5 per entry, Sunday priest, cosmetics only | Owner, Animal Crossing | 1 | casino |
| Copper machine for coin rerolls (moves no money) | CS:GO | 1, 2 | casino |
| Tally variant skins that notch per deposit | CS:GO | 1, 3 | casino, followers |
| Sealed cases dropped by play onto the shelf | CS:GO | 2 | minigames, casino |
| 2-minute coin games paying max(5, score/10) | Club Penguin | 2 | minigames |
| Four stamps per game that double pay | Club Penguin | 2 | minigames |
| Fishing with the timing bar and the Big One | Club Penguin, owner | 2 | minigames |
| Mine cart run with trick scoring | Club Penguin | 2 | minigames |
| Magnet pickups and Coin Fever (mine only) | Vampire Survivors | 2 | minigames |
| 2:00 hard stop on every run | Vampire Survivors | 2 | minigames |
| Followers attack on their own; the owner only moves | Vampire Survivors, Cult of the Lamb | 2 | minigames |
| Dungeon pacing: safe entrance, fight room, heaps, mimics | Shattered Pixel Dungeon | 2 | minigames |
| Lantern oil, one flask per room | Shattered Pixel Dungeon | 2 | minigames |
| Idol shelf and the Chips x Mult cascade at each door | Balatro | 2 | minigames |
| Real-week omens dealt on Monday | Balatro | 2 | minigames |
| Boss rule from the week's worst reaction | Balatro, Shattered Pixel Dungeon | 2 | minigames |
| Flat room pay, depth ladder, coin interest | Balatro | 2 | minigames |
| Level feelings from the week (risk-neutral fallback) | Shattered Pixel Dungeon | 2 | minigames |
| One veiled relic per week on a fixed schedule | Shattered Pixel Dungeon | 2 | minigames |
| Shuffle-bag decks for free cosmetic sources | Shattered Pixel Dungeon | 1-3 | minigames, followers |
| Weekly vials learned by use | Shattered Pixel Dungeon | 2 | minigames |
| Goo-style two-beat telegraph | Shattered Pixel Dungeon | 2 | minigames |
| Iron chest of play loot | Vampire Survivors | 2 | minigames |
| Remains heap after a Cold spell | Shattered Pixel Dungeon | 2 | minigames |
| Caged acolyte and tap-only naming rite | Cult of the Lamb | 2, 3 | minigames, followers |
| Back-room duel | Buckshot Roulette | 2 | minigames |
| Morning rounds: bell streak, bone cracks, coin rock, glow seed, Gem Hunt dig | Animal Crossing, Webkinz | 2 | minigames |
| Three lantern flames a day | Stardew Valley | 2 | minigames |
| Debt boss: HP = balance, payments as exact mote hits | Owner, Vampire Survivors, Balatro | 2 | minigames (gate) |
| Interest turn once a month, in the open | Buckshot Roulette, Shattered Pixel Dungeon, Animal Crossing | 2 | minigames (gate) |
| Faith: one money meter shown on bodies, flame and voices | Cult of the Lamb (with Webkinz, Shattered Pixel Dungeon, Animal Crossing) | 3 | followers |
| One-shot threshold warnings; lean pause | Shattered Pixel Dungeon | 3 | followers |
| Belly and coin food | Webkinz, Cult of the Lamb | 3 | followers |
| Loyalty candles, levels, body marks, idle tricks | Cult of the Lamb, Webkinz | 3 | followers |
| Shrine Devotion pile, capped, collected as coins | Cult of the Lamb | 3 | followers |
| Daily sermon (hold 1 s) | Cult of the Lamb | 3 | followers |
| Bless | Cult of the Lamb | 3 | followers |
| Icon thought bubbles and never-expiring requests | Cult of the Lamb, Webkinz | 3 | followers |
| Feast and Bonfire (coins), Funeral (free) | Cult of the Lamb | 3 | followers |
| Dissenter (acolytes only, Cold only) | Cult of the Lamb | 3 | followers |
| Missed-week coffin, Grave of Weeks, flower on the next deposit | Cult of the Lamb, Webkinz | 3 | followers |
| Personal follower: egg, naming, seven stages, never shrinks | Webkinz, Cult of the Lamb | 3 | followers |
| Personal follower trails, helps in games, digs daily | Club Penguin | 3 | followers |
| Streak Idol (the personal follower in the dungeon) | Balatro | 2, 3 | minigames, followers |
| Holding followers sized weekly; the 40% giant and the stare | Owner, Cult of the Lamb | 3 | followers |
| Spending quirks on bodies, reset Monday | Webkinz, Cult of the Lamb | 3 | followers |
| While-you-were-out scene and the 04:00 day line | Animal Crossing, Cult of the Lamb, Webkinz, Stardew Valley, Shattered Pixel Dungeon, Vampire Survivors | 3 | followers, platform |
| The Bell: waiting motes stream home | Vampire Survivors | 3 | followers |
| Crowd reaction to worn rarity; knockoffs | Club Penguin | 3 | followers |
| Hidden favorite category, found by watching | Webkinz | 3 | followers |
| Free daily shrine wheel | Webkinz | 3 | followers |
| Grandpa's candles from yearly behavior | Stardew Valley | 3, 5 | followers |
| Mote fountain: the only picture of real dollars | Vampire Survivors | 4 | juice |
| Money-landing chant and kneel choreography | Cult of the Lamb, Webkinz, Shattered Pixel Dungeon | 3, 4 | followers, juice |
| Pop curve for every prop, idol, number and button | Balatro | 4 | juice |
| Floating numbers | Balatro, Vampire Survivors | 4 | juice |
| Rising-pitch note walks | Balatro, Vampire Survivors, CS:GO | 4 | juice |
| Hit-stop helper that ignores time scale | CS:GO, Buckshot Roulette, Vampire Survivors | 4 | juice |
| Tap squash and stretch; idle bob on everything | Vampire Survivors | 4 | juice |
| Particle and flash caps | Vampire Survivors | 4 | juice |
| Event queue for cascades; hold to fast-forward | Balatro | 4 | juice |
| Pulsing fit cue and ember thread | Stardew Valley | 4 | juice |
| Real-clock light bands and the hour bell | Animal Crossing | 4 | juice |
| Bow ripple as the leader passes | Hoard (Cult of the Lamb tone) | 4 | followers |
| Reduced-motion setting | Several | 4 | juice |
| The Square: one-screen hub, map as menu | Club Penguin | 5 | village |
| Door iris and sound bleed | Club Penguin | 4, 5 | village |
| Ember throw | Club Penguin | 4, 5 | village |
| Coin Stall rack, rotating monthly | Club Penguin | 2, 5 | village |
| House stages on the Animal Crossing loan curve, overnight build, brick box, Mason, banner | Animal Crossing | 5 | village |
| Wall in stone courses | Animal Crossing | 5 | village |
| Den decorating on a 16 px grid | Webkinz | 5 | village |
| Open house when money lands in the House Fund | Club Penguin | 5 | village |
| Ruins and Offering Tablets (24 bundles) | Stardew Valley | 5 | village |
| Vault vials sized from the owner's weekly unit | Stardew Valley | 5 | village |
| Restoration cutscenes, all queued | Stardew Valley | 5 | village |
| Hoard seasons as real quarters | Stardew Valley | 5 | village |
| Festivals on fixed dates | Stardew Valley | 5 | village |
| Absence creep: fungus and bats | Animal Crossing | 3, 5 | village |
| Overnight mailbox with a flag | Animal Crossing | 5 | village |
| Play bundles add permanent dungeon idols | Balatro | 5 | village |
| One stats screen (the only place Faith and day counts appear as numbers) | Owner | 5 | village |
