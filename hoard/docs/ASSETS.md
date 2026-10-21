# Hoard assets

Every asset Hoard uses is free. Nothing here was bought, and nothing is pulled from a
commercial game. In-repo packs are CC0 first, then CC-BY, then GPL-3.0 (Shattered Pixel
Dungeon), plus SIL OFL fonts, which allow bundling. Packs that are free but forbid
redistribution or commercial use stay out of git as manual downloads, with same-size
placeholders so the game builds against them now.

- `game/art/packs/<slug>/`: 77 packs in the repo, 59 MB of art and audio plus Godot's `.import` files.
  Each folder has `SOURCE.md` (author, link, license, evidence, what Hoard uses it for, credit line)
  and the pack's own license text (a LICENSE file, or the readme/credits file that states the license). `game/art/packs/credits.json` holds every credit line for the credits screen.
- `game/art/placeholders/<slug>/`: 9 manual-download packs, drawn by `python tools/art/placeholders.py`
  from `tools/art/placeholder_specs.json`. Git-ignored, so the real files dropped over them never get committed.
- Paths below are relative to `game/art/`.

## 1. The look

**Owner's call (Oct 21): the packs keep their own colors.** After seeing the raw packs, the owner
chose their original, colorful look over the muted palette in the first brief. So nothing below
dulls a pack. Recoloring is only for making pieces from different packs sit together, and for
keeping the five rarity colors meaning something.

Flat pixel tiles on a 480x270 canvas: 16x16 tiles and props, 32x32 followers and the leader,
nearest filtering, whole-number scaling, no anti-aliasing. Rooms sit on a near-black ground
(`night #120c18`) so the colorful sprites read against it.

### How rarity still stands out when everything is colorful

Rarity is carried by light and motion, not by being the only loud hue:

- **Glow and outline.** A thing of a given tier gets a 1px outline and a soft glow sprite (Kenney
  particle `light_*`, tinted) in its rarity color. Nothing else in the game gets a colored glow.
- **The reveal.** The flash, beam, particle burst and screen tint on a reveal use only the rarity ramp.
- **Darkness around machines.** Machines sit in pools of light on the dark floor, so a glowing case
  or reel item is the brightest thing on screen.
- **Collision cleanup.** Where a non-rarity sprite uses almost exactly a rarity color (a gold coin pile,
  a red slime), its glow and outline stay neutral. The sprite itself keeps its color.

| Rarity | Shadow | Base | Glow |
| --- | --- | --- | --- |
| common (grey) | `#5d6166` | `#9aa0a6` | `#d5d8db` |
| rare (blue) | `#1f4f9e` | `#3d8bff` | `#9cc4ff` |
| epic (purple) | `#5f259c` | `#a347ff` | `#d3a3ff` |
| legendary (gold) | `#a86a0c` | `#ffb627` | `#ffe08a` |
| mythic (red) | `#9e141d` | `#ff2e3a` | `#ff8a90` |

The rarity bases match `game/scripts/palette.gd` and `tools/art/palette.py`.

### Recoloring, only where needed

1. **Rarity tinting at runtime.** Greyscale or white bases (the Whimsy chest base, Kenney 1-Bit sheets,
   Kenney particle masks, SBS transition masks) are tinted with a small palette-swap shader through a
   5x3 lookup strip (rarity x shadow/base/glow), so one sprite serves all five tiers.
2. **Making packs match.** `tools/art/recolor.py` (Step 1) can nudge one pack toward another so they
   don't clash in the same room: matching outline darkness, keying out baked black or checkered
   backgrounds (GrafxKid, Whimsy), and evening out saturation between 0x72 and Shattered Pixel Dungeon
   props. Output goes to a generated folder; `packs/` stays as shipped so the licenses stay true.
3. **No cash imagery.** `$` signs in casino packs (Jephed, some slot symbols) are repainted or dropped,
   since nothing in Hoard pays out money.

## 2. Packs by category

### Environment tiles: casino, village, dungeon, shrine, gate

| Pack | Author | Direct link | License | Size / format | Status |
| --- | --- | --- | --- | --- | --- |
| `0x72-dungeontileset-ii` 16x16 DungeonTileset II v1.7, with Dungeon Tileset II Extended v1.1 and 16x16 Dark Dungeon | 0x72 (Robert); extension by Niji (nijikokun); dark variant by Zoltan Kosina (kosinaz) | https://0x72.itch.io/dungeontileset-ii | CC0 1.0 | 0.15 MB; 16x16 tiles (high walls 16x32), characters 16x16 to 32x36; frame rects in tile_list_v1.7 | in repo |
| `whimsy-hallow-dungeon` Free - Whimsy Hallow Asset Pack - Dungeon v1.62 | Crumpaloo | https://crumpaloo.itch.io/whimsy-hallow | CC0 1.0 | 0.64 MB; 16x16 grid, props up to ~64x64, one 2680x2896 sheet | in repo |
| `shattered-pixel-dungeon` Shattered Pixel Dungeon assets (sprites, environment, effects, interfaces, sounds, 7 music tracks) | Evan Debenham (Shattered Pixel), after Pixel Dungeon by Watabou; music by Lumine (Kristjan) Haaristo, SFX by Celesti, plus Freesound samples listed in CREDITS_from_AboutScene.txt | https://github.com/00-Evan/shattered-pixel-dungeon | GPL-3.0 | 4.93 MB; 16x16 tiles on 256x256 sheets; sprites ~12-20 px frames (sizes in sprites/<Name>Sprite.java); specks 8x8 | in repo |
| `spriteshift-purple-dungeon` Purple Dungeon TileSet | Spriteshift | https://spriteshift.itch.io/purple-dungeon-tileset | CC0 1.0 | 0.04 MB; 16x16 | in repo |
| `shade-puny-dungeon` 16x16 Puny Dungeon Tileset v1 | Shade (merchant-shade) | https://opengameart.org/content/16x16-puny-dungeon-tileset | CC0 1.0 | 0.03 MB; 16x16 | in repo |
| `kenney-tiny-town` Tiny Town | Kenney (kenney.nl) | https://kenney.nl/assets/tiny-town | CC0 1.0 | 0.01 MB; 16x16, 132 tiles (tilemap.png 1px spacing, tilemap_packed.png none) | in repo |
| `kenney-tiny-dungeon` Tiny Dungeon | Kenney (kenney.nl) | https://kenney.nl/assets/tiny-dungeon | CC0 1.0 | 0.01 MB; 16x16, 132 tiles (tilemap.png 1px spacing, tilemap_packed.png none) | in repo |
| `kenney-roguelike-indoors` Roguelike Indoors | Kenney (kenney.nl) | https://kenney.nl/assets/roguelike-indoors | CC0 1.0 | 0.02 MB; 16x16, 1px spacing, 458x305 sheet | in repo |
| `kenney-roguelike-caves-dungeons` Roguelike Caves & Dungeons | Kenney (kenney.nl) | https://kenney.nl/assets/roguelike-caves-dungeons | CC0 1.0 | 0.03 MB; 16x16, 1px spacing, 492x305 sheet | in repo |
| `kenney-1-bit-pack` 1-Bit Pack | Kenney (kenney.nl) | https://kenney.nl/assets/1-bit-pack | CC0 1.0 | 0.09 MB; 16x16, 1px spacing (packed versions without spacing) | in repo |
| `dawnlike` DawnLike 16x16 Universal Rogue-like tileset v1.81 | DragonDePlatino (art), DawnBringer (DB16 palette) | https://opengameart.org/content/dawnlike-16x16-universal-rogue-like-tileset-v181 | CC-BY 4.0 | 0.65 MB; 16x16, 2-frame pairs (sheet 0 and 1) | in repo |
| `dcss-altars-features` Dungeon Crawl Stone Soup 32x32 tiles: altars, statues, fountains (subset) | Dungeon Crawl Stone Soup team (rltiles and DCSS artists, see README.txt) | https://opengameart.org/content/dungeon-crawl-32x32-tiles-supplemental | CC0 1.0 | 0.12 MB; 32x32 | in repo |
| `vk-candles-with-eyes` Candles, oil lamp and eye with varied stands | vk | https://opengameart.org/content/candles-oil-lamp-and-eye-with-varied-stands | CC0 1.0 | 0.00 MB; 164x43 sheet: 8 bases x 8 tops | in repo |
| `jephed-casino-tileset` 2D Top-Down Pixel Art Tileset: Casino | Jephed (Game Between The Lines) | https://gamebetweenthelines.itch.io/2d-top-down-pixel-art-tileset-casino | custom (free) | 16x16 tiles (1024x512 and 640x512 sheets), 12 animated sheets; 14 PNG | manual download, placeholder in `placeholders/jephed-casino-tileset/` |
| `bigwander-dark-ritual` The Dark Ritual starter pack | BigWander | https://bigwander.itch.io/the-dark-ritual | custom (free) | 16x16 (160x128 sheet) + 80 single sprites; PNG | manual download, placeholder in `placeholders/bigwander-dark-ritual/` |

Also here: `ninja-adventure/Backgrounds/` (village houses, idols, stalls, pond, water, fishing net).

### Followers, leader, dealer, villagers, bosses

| Pack | Author | Direct link | License | Size / format | Status |
| --- | --- | --- | --- | --- | --- |
| `ninja-adventure` Ninja Adventure Asset Pack (actors, tilesets, items, UI, FX, sounds, 6 music tracks) | Pixel-boy and AAA | https://pixel-boy.itch.io/ninja-adventure-asset-pack | CC0 1.0 | 9.54 MB; 16x16 characters in 64x112 4-direction sheets; NinjaGreen 32x32; bosses 40-82 px; facesets 38x38 | in repo |
| `puny-characters` Free 16x16 Puny Character Sprites + PunyMonsters | Shade (merchant-shade) | https://merchant-shade.itch.io/16x16-puny-characters | CC0 1.0 | 0.70 MB; 32x32 frames, 768x256 sheets (8 directions x 24 frames) | in repo |
| `megowhat-little-lamb` Little Lamb | megowhat | https://opengameart.org/content/little-lamb | CC0 1.0 | 0.05 MB; 64x64 frames, 3 walk frames x 4 directions | in repo |
| `grafxkid-critters-penguin` GrafxKid CC0 creature sheets + Super Random Penguin Edit | GrafxKid (penguin edit by Zombie Rat) | https://opengameart.org/content/super-random-sprites | CC0 1.0 | 0.09 MB; mostly 32x32 frames; penguin edit 24x32 | in repo |
| `tiny-creatures` Tiny Creatures | Clint Bellanger (expansion to Kenney's Tiny Dungeon) | https://opengameart.org/content/tiny-creatures | CC0 1.0 | 0.04 MB; 16x16 single frames, 160x288 packed tilemap | in repo |
| `kenney-pixel-platformer-characters` Pixel Platformer (characters only) | Kenney (kenney.nl) | https://kenney.nl/assets/pixel-platformer | CC0 1.0 | 0.00 MB; 24x24, 9x3 sheet | in repo |
| `chasersgaming-pixel-poker` Asset Pack Pixel Poker (free files) | Chasersgaming | https://opengameart.org/content/asset-pack-pixel-poker | CC0 1.0 | 0.03 MB; Dealer 120x192 (4 talk frames ~30x48); cards ~16x24 | in repo |
| `superdark-npcs-forest` 16x16 Free NPC Pack + Enchanted Forest Characters (0x72 extensions) | Superdark | https://superdark.itch.io/16x16-free-npc-pack | custom informal grant (free) | 16x16 NPC sheet (112x128) + 512x512 forest sheet (32x32 canvases) | manual download, placeholder in `placeholders/superdark-npcs-forest/` |

Also here: `shattered-pixel-dungeon/sprites/`, `0x72-dungeontileset-ii` characters, `dawnlike/Characters/`.

### Casino machines and props

| Pack | Author | Direct link | License | Size / format | Status |
| --- | --- | --- | --- | --- | --- |
| `whimsy-hallow-chests` Whimsy Hallow - 15 ready-to-use chest animations | Crumpaloo | https://crumpaloo.itch.io/15-ready-to-use-chest-animations | CC0 1.0 | 0.05 MB; big chests 48x40 x21 frames, small 32x24 x11; frame list in the text file | in repo |
| `carnageddon-demonic-chest` Demonic chest | carnageddon | https://opengameart.org/content/demonic-chest-0 | CC0 1.0 | 0.00 MB; 8 frames of 32x32 | in repo |
| `bonsaiheldin-chests-32` Treasure chests 32x32 | Bonsaiheldin | https://opengameart.org/content/treasure-chests-32x32 | CC-BY 4.0 | 0.02 MB; 32x32, 120 stills | in repo |
| `karsiori-gems` FREE Pixel Art Gems Pack - Animated | karsiori | https://karsiori.itch.io/free-pixel-art-gem-pack | CC0 1.0 | 0.34 MB; gems 18x30 to 28x28, cluster 44x44, ~11-frame loops | in repo |
| `kenney-playing-cards` Playing Cards Pack | Kenney (kenney.nl) | https://kenney.nl/assets/playing-cards-pack | CC0 1.0 | 0.02 MB; small cards on 16x16 tiles, medium 32x32, large | in repo |
| `vircon32-slot-machine` Pixel art slot machine | Vircon32 (Carra) | https://opengameart.org/content/pixel-art-slot-machine | CC-BY 4.0 | 0.03 MB; parts for a 640x360 screen; symbols ~48 and ~24 px | in repo |
| `draganas-prize-wheel-64` Wheel Fortune (64x64) | draganasgamesart | https://opengameart.org/content/wheel-fortune | CC0 1.0 | 0.00 MB; 64x64 still | in repo |
| `publicvoid-slot-symbols` Pixel Art Slot Machine Sprites | Public Void Interactive | https://public-void-interactive.itch.io/pixel-art-slots-symbols | CC0 1.0 | 0.01 MB; 32x32 | in repo |
| `karsiori-neon-signs` FREE Pixel Art Neon Sign Pack - Animated | karsiori | https://karsiori.itch.io/free-pixel-art-neon-signs | CC0 1.0 | 0.73 MB; ~24x24 to ~60x60 frames, 10-40 frame loops | in repo |
| `ninjikin-treasure-plus` Treasure+ | SciGho (ninjikin) | https://ninjikin.itch.io/treasure | CC-BY 4.0 | 0.04 MB; 16x16 | in repo |
| `greatdocbrown-coins-gems` Coins & Gems & Chests & More v2.0 | greatdocbrown | https://greatdocbrown.itch.io/coins-gems-etc | CC0 1.0 | 0.18 MB; 16x16, one 912x1040 sheet | in repo |
| `bonsaiheldin-gold-icons` Gold treasure icons 16x16 | Bonsaiheldin | https://opengameart.org/content/gold-treasure-icons-16x16 | CC0 1.0 | 0.01 MB; 16x16 | in repo |
| `evercrazy-coin-gem-8x8` 8x8 Free Coin/Gem Collection | EverCrazy | https://opengameart.org/content/8x8-free-coin-gem-collection | CC0 1.0 | 0.00 MB; 8x8 frames | in repo |
| `lpc-animated-coins` LPC Animated Coins | Clint Bellanger | https://opengameart.org/content/animated-coins | CC-BY 3.0 | 0.00 MB; 32x32, 8-frame spin | in repo |
| `foozle-lucifer-pickups` Lucifer - Pickups | Foozle | https://foozlecc.itch.io/lucifer-pickups | CC0 1.0 | 0.01 MB; 16x16 animated | in repo |
| `laredgames-coins-gems` Gems / Coins Free | La Red Games | https://laredgames.itch.io/gems-coins-free | CC0 1.0 | 0.00 MB; 16x16 animated | in repo |
| `buch-golden-ui` Golden UI | Buch | https://opengameart.org/content/golden-ui | CC0 1.0 | 0.02 MB; pieces on a 606x414 sheet; author suggests 2x | in repo |
| `kia-slot-machine` 32x32 slot machine | Kia | https://kia.itch.io/32x32-slot-machine-pixel-art | free for non-commercial games (custom); commercial use (free) | 256x256 sheet: ~136x229 cabinet, 32x32 symbols; PNG | manual download, placeholder in `placeholders/kia-slot-machine/` |

Also here: the Jephed casino slot cabinets (manual download, above), `0x72-dungeontileset-ii` chest animations, `shattered-pixel-dungeon/sprites/mimic.png`.

### UI and fonts

| Pack | Author | Direct link | License | Size / format | Status |
| --- | --- | --- | --- | --- | --- |
| `tiopalada-dark-dwellers-gui` Tiny RPG - Dark Dwellers GUI | Gabriel "tiopalada" Lima | https://tiopalada.itch.io/tiny-rpg-dark-dwellers-gui | CC0 1.0 | 0.14 MB; icon buttons 32x32 x4 states, 9-slices 96x96, cursors 23x23 and 17x17 | in repo |
| `flatus-generic-dark-pixel-ui` Generic Dark Pixel UI | Flatus | https://flatus.itch.io/generic-dark-pixel-ui | CC0 1.0 | 0.04 MB; 13px widgets, normal/hover/pressed/disabled rows; icons 7-13 px | in repo |
| `tiopalada-emoji-pack-1` Tiny RPG - Emoji Pack I | Gabriel "tiopalada" Lima | https://tiopalada.itch.io/tiny-rpg-emoji-pack-i | CC0 1.0 | 0.10 MB; 32x32 frames, 160x128 sheets (pop-in, idle, pop-out) | in repo |
| `shikashi-fantasy-icons` Shikashi's Fantasy Icons Pack (FREE) v2 | Matt Firth (shikashipx), based on game-icons.net | https://shikashipx.itch.io/shikashis-fantasy-icons-pack | CC-BY 4.0 | 0.12 MB; 32x32, 16 per row | in repo |
| `kyrise-rpg-icons-16` Kyrise's Free 16x16 RPG Icon Pack V1.3 | Kyrise | https://kyrise.itch.io/kyrises-free-16x16-rpg-icon-pack | CC-BY 4.0 | 0.15 MB; 16x16 (32 and 48 copies dropped) | in repo |
| `kenney-cursor-pixel-pack` Cursor Pixel Pack | Kenney (kenney.nl) | https://kenney.nl/assets/cursor-pixel-pack | CC0 1.0 | 0.01 MB; 16x16, 20x11 tilemap | in repo |
| `kenney-ui-pack-pixel-adventure` UI Pack - Pixel Adventure | Kenney (kenney.nl) | https://kenney.nl/assets/ui-pack-pixel-adventure | CC0 1.0 | 0.03 MB; 16x16 small and 32x32 large tiles, thin and thick outline | in repo |
| `kenney-emotes-pack` Emotes Pack (pixel) | Kenney (kenney.nl) | https://kenney.nl/assets/emotes-pack | CC0 1.0 | 0.01 MB; 16x16, 8 balloon styles | in repo |
| `font-m5x7` m5x7 pixel font | Daniel Linssen (managore) | https://managore.itch.io/m5x7 | CC0 1.0 | 0.04 MB; TTF, 16 px em | in repo |
| `font-monogram` monogram | Vinicius Menezio (datagoblin) | https://datagoblin.itch.io/monogram | CC0 1.0 | 0.17 MB; TTF 16 px, ~5x9 cell | in repo |
| `google-pixel-fonts-ofl` Google Fonts pixel set: Jacquard 12, Jacquarda Bastarda 9, Jersey 10, Micro 5, Pixelify Sans, Silkscreen, Tiny5 | Sarah Cadigan-Fried / Soft Type; Stefie Justprince; Jason Kottke; Stefan Schmidt | https://fonts.google.com/specimen/Jacquard+12 | OFL-1.1 | 0.96 MB; TTF | in repo |
| `linssen-fonts` m6x11, m6x11plus and m3x6 pixel fonts | Daniel Linssen (managore) | https://managore.itch.io/m6x11 | custom (free) | TTF (m6x11 16 px em, m6x11plus 18 px, m3x6 16 px) | manual download, placeholder in `placeholders/linssen-fonts/` |

Also here: `shattered-pixel-dungeon/interfaces/` (boss bar, buff icons, 9-slices) and `ninja-adventure/Ui/` (fill orbs, emote bubbles, dialog box).

### Particles and VFX

| Pack | Author | Direct link | License | Size / format | Status |
| --- | --- | --- | --- | --- | --- |
| `foozle-lucifer-effects` Lucifer - Effects | Baldur (commissioned), distributed by Foozle | https://foozlecc.itch.io/lucifer-effects | CC0 1.0 | 0.01 MB; beams ~6x20 frames; Destroy 48x48; Wave 16x32 and 32x64 | in repo |
| `m484-explosion-set-1` Explosion Set 1 (M484 Games) | Master484 (Vesa Vanhatupa) | https://opengameart.org/content/explosion-set-1-m484-games | CC0 1.0 | 0.03 MB; ring pops 8-32 px, not on a grid (slice by hand) | in repo |
| `ansimuz-explosions` Explosion Animations Pack (pack 1 + bonus) | Luis Zuno (ansimuz) | https://ansimuz.itch.io/explosion-animations-pack | CC0 1.0 | 0.04 MB; 32 to 192 px frames, 7-22 frames | in repo |
| `srzolda-magic-summons` Free Magic Summons Pack | SrZolda | https://srzolda.itch.io/magic-summons | CC-BY 4.0 | 0.12 MB; 64x64 frames (red 102x102), 28-78 frames | in repo |
| `kenney-particle-pack` Particle Pack (1.1) | Kenney (kenney.nl) | https://kenney.nl/assets/particle-pack | CC0 1.0 | 0.47 MB; 128x128 white masks | in repo |
| `sbs-animated-transitions` Animated Transitions Pack | Screaming Brain Studios | https://screamingbrainstudios.itch.io/animated-transitions-pack | CC0 1.0 | 0.10 MB; 128x128 frames packed into horizontal strips (<name>_strip_<frames>x128.png) | in repo |
| `nogitsune-pixel-vfx` Free Pixel VFX Pack - 35 Animated Effects (20 used) | NogitsuneGurl | https://nogitsunegurl.itch.io/free-pixel-vfx-pack | custom (free) | 32/48/64 px frames, 7-14 frames; 20 of 35 effects mirrored (sheet + game strip + anchor.json) | manual download, placeholder in `placeholders/nogitsune-pixel-vfx/` |
| `untied-super-pixel-effects` Super Pixel Effects Gigapack (Free Version) v3.1.0 (14 effects used) | Will Tice / unTied Games | https://untiedgames.itch.io/super-pixel-effects-gigapack | custom unTied Games license (http (free) | 32-256 px frames, small and large; 14 effects mirrored (28 sheets + frame maps) | manual download, placeholder in `placeholders/untied-super-pixel-effects/` |
| `pimen-holy-dark-vfx` Holy Spell Effect + Dark Spell Effect (free VFX 01-02) | pimen | https://pimen.itch.io/holy-spell-effect | custom (free) | 32x32, 48x48, 40x32, 48x64 frames; 6 sheets | manual download, placeholder in `placeholders/pimen-holy-dark-vfx/` |
| `bdragon-effect-bullet-16x16` Free Effect and Bullet 16x16 | BDragon1727 | https://bdragon1727.itch.io/free-effect-and-bullet-16x16 | free for non-commercial games (custom); commercial use needs a contribution of any amount; modify OK; no resale or redistribution (free) | 16x16 grid, four 576x208 sheets | manual download, placeholder in `placeholders/bdragon-effect-bullet-16x16/` |

Also here: `ninja-adventure/FX/` (spark-circle flash, rings, smoke, god rays, fog) and `shattered-pixel-dungeon/effects/` (specks).

### SFX

| Pack | Author | Direct link | License | Size / format | Status |
| --- | --- | --- | --- | --- | --- |
| `kenney-interface-sounds` Interface Sounds | Kenney (kenney.nl) | https://kenney.nl/assets/interface-sounds | CC0 1.0 | 0.96 MB; OGG 44.1 kHz | in repo |
| `kenney-ui-audio` UI Audio | Kenney (kenney.nl) | https://kenney.nl/assets/ui-audio | CC0 1.0 | 0.32 MB; OGG 44.1 kHz | in repo |
| `kenney-casino-audio` Casino Audio | Kenney (kenney.nl) | https://kenney.nl/assets/casino-audio | CC0 1.0 | 0.53 MB; OGG 44.1 kHz | in repo |
| `kenney-impact-sounds` Impact Sounds | Kenney (kenney.nl) | https://kenney.nl/assets/impact-sounds | CC0 1.0 | 1.03 MB; OGG 44.1 kHz | in repo |
| `kenney-rpg-audio` RPG Audio | Kenney (kenney.nl) | https://kenney.nl/assets/rpg-audio | CC0 1.0 | 0.73 MB; OGG 44.1 kHz | in repo |
| `kenney-music-jingles` Music Jingles | Kenney (kenney.nl) | https://kenney.nl/assets/music-jingles | CC0 1.0 | 1.28 MB; OGG 44.1 kHz | in repo |
| `kenney-digital-audio` Digital Audio | Kenney (kenney.nl) | https://kenney.nl/assets/digital-audio | CC0 1.0 | 0.25 MB; OGG 44.1 kHz | in repo |
| `lrsf-coins-library` Coins Sound Effects Library | Little Robot Sound Factory | https://opengameart.org/content/coins-sound-effects-library | CC-BY 3.0 | 1.76 MB; OGG mono | in repo |
| `owlishmedia-creepy-chanting` Creepy Incoherent Chanting | OwlishMedia | https://opengameart.org/content/creepy-incoherent-chanting | CC0 1.0 | 3.59 MB; OGG | in repo |
| `ignisforge-sfx-sampler` IgnisForge Free SFX Sampler | IgnisForge | https://opengameart.org/content/ignisforge-free-sfx-sampler-43-synthesized-retro-sound-effects | CC0 1.0 | 0.35 MB; OGG | in repo |
| `freesound-cc0-picks` Freesound CC0 picks: prize wheel, slot reels, ratchet, roulette, pachinko room, coin pour, scratching, fishing reels, chants | tony_bear, leocb, aghirlandaio, monotraum, poenia, markystar, TheWoodlandNomad, univ_lyon3, Henaway, ameslynn, fennelliott, 170129, qubodup, SnowFightStudios, timothyd4y (Freesound) | https://freesound.org/people/tony_bear/sounds/274007/ | CC0 1.0 | 7.75 MB; MP3 128 kbps previews | in repo |
| `juhani-512-retro-sfx` The Essential Retro Video Game Sound Effects Collection [512 sounds] (subset) | Juhani Junkala (SubspaceAudio) | https://opengameart.org/content/512-sound-effects-8-bit-style | CC0 1.0 | 1.65 MB; OGG mono | in repo |
| `luke-8bit-coin-sounds` 10 8bit coin sounds | Luke.RUSTLTD | https://opengameart.org/content/10-8bit-coin-sounds | CC0 1.0 | 0.07 MB; OGG | in repo |
| `fisheefects` Fisheefects | Memoraphile @ You're Perfect Studio | https://opengameart.org/content/fisheefects | CC0 1.0 | 0.31 MB; OGG | in repo |
| `bart-heartbeat-sounds` Heartbeat sounds | bart | https://opengameart.org/content/heartbeat-sounds | CC0 1.0 | 0.05 MB; OGG | in repo |
| `mikeask-menu-tick` Menu select tick | mikeask | https://opengameart.org/content/menu-select-tick | CC0 1.0 | 0.01 MB; OGG | in repo |
| `antumdeluge-scrapes` Scrapes | AntumDeluge | https://opengameart.org/content/scrapes | CC0 1.0 | 0.16 MB; OGG | in repo |
| `themightyglider-breaking-rock` Breaking Rock | themightyglider | https://opengameart.org/content/breaking-rock | CC0 1.0 | 0.01 MB; OGG | in repo |
| `wobbleboxx-levelup-coin` Level up, power up, Coin get (13 sounds) | wobbleboxx | https://opengameart.org/content/level-up-power-up-coin-get-13-sounds | CC0 1.0 | 0.59 MB; OGG | in repo |
| `rubberduck-80-rpg-sfx` 80 CC0 RPG SFX (subset) | rubberduck | https://opengameart.org/content/80-cc0-rpg-sfx | CC0 1.0 | 1.12 MB; OGG | in repo |

Also here: `ninja-adventure/Audio/Sounds/` and `Audio/Jingles/` (Ogg), `shattered-pixel-dungeon/sounds/` (MP3).

### Music

| Pack | Author | Direct link | License | Size / format | Status |
| --- | --- | --- | --- | --- | --- |
| `nihilex-dark-ambient` Dark Ambient Soundscape (from Free Audio Asset Collection) | Nihilex (nihil-existentia) | https://nihil-existentia.itch.io/free-audio-asset-collection | CC0 1.0 | 2.18 MB; OGG stereo | in repo |
| `mumusi-cathedral-of-shadows` Cathedral of Shadows - dark choir seamless loop | mumusi (mumusi_c21) | https://mumusi-c21.itch.io/cathedral-of-shadows | CC-BY 4.0 | 1.07 MB; OGG 48 kHz stereo, 46 s seamless loop | in repo |
| `ove-melaa-select` Ove's Essential Game Audio Pack (two tracks) | Ove Melaa | https://opengameart.org/content/oves-essential-game-audio-pack-collection-160-files-updated | CC-BY 3.0 | 2.62 MB; MP3 / OGG | in repo |

Also here: `ninja-adventure/Audio/Music/` (6 tracks) and `shattered-pixel-dungeon/music/` (7 tracks).


## 3. Manual downloads

Free, but not allowed in a public repo. Each has a placeholder folder with the same file names, image
sizes and frame layout (flat muted silhouettes, 1px `muted` outline). Run `python tools/art/placeholders.py`
once after cloning, download the pack, and copy its files over the placeholders with the same names.
The script never overwrites a real file (`--status` shows what is still a stand-in). Keep these files
local: `game/art/placeholders/` is git-ignored except its README.

| Pack | Get it | License | Why it is not in the repo | Drop the files into |
| --- | --- | --- | --- | --- |
| 2D Top-Down Pixel Art Tileset: Casino | https://gamebetweenthelines.itch.io/2d-top-down-pixel-art-tileset-casino | custom: free for commercial and non-commercial use, credit requested ('Jephed, Game Between The Lines, https://gamebetweenthelines.com/'); silent on redistribution | License grants use but says nothing about redistribution; the only top-down pixel casino floor. | `game/art/placeholders/jephed-casino-tileset/`: Download the free zip from the page, extract it, and copy `2D_TopDown_Tileset_Casino_1024x512.png`, `2D_TopDown_Tileset_Casino_640x512.png` and the whole `Animated Sprite Sheets/` folder into this folder, replacing the stand-ins. |
| The Dark Ritual starter pack | https://bigwander.itch.io/the-dark-ritual | custom: free incl. commercial use, modification allowed, credit requested; no resale or redistribution, even modified | License forbids redistribution, even modified. | `game/art/placeholders/bigwander-dark-ritual/`: Download the free zip, extract it, and copy its `Spritesheet/` and `IndividualSprites/` folders here. |
| 32x32 slot machine | https://kia.itch.io/32x32-slot-machine-pixel-art | free for non-commercial games (custom); commercial use: pay what you think is fair; no redistribution grant | Free for non-commercial use only; no redistribution grant. | `game/art/placeholders/kia-slot-machine/`: Download `slot.png` from the page and put it here. |
| Free Pixel VFX Pack - 35 Animated Effects (20 used) | https://nogitsunegurl.itch.io/free-pixel-vfx-pack | custom: free in free or commercial games, editing allowed; no resale or redistribution as a standalone pack; credit appreciated | No redistribution as a standalone pack; raw files in a public repo come too close. | `game/art/placeholders/nogitsune-pixel-vfx/`: Download the free zip and copy the effect folders from its `Effects/` folder here (for example `Effects/Coin-Sparkle/` becomes `Coin-Sparkle/`). Each brings its `_sheet.png`, `game/` strip and real `anchor.json`; the other 15 effects can come along. |
| Super Pixel Effects Gigapack (Free Version) v3.1.0 (14 effects used) | https://untiedgames.itch.io/super-pixel-effects-gigapack | custom unTied Games license (http://untiedgames.com/files/license.txt): commercial and non-commercial use OK, attribution required, no redistribution of the pack except inside a game, no AI training | No redistribution except inside a game; attribution required. | `game/art/placeholders/untied-super-pixel-effects/`: Download the free zip and copy its `spritesheet/` folder here (paths look like `spritesheet/Magic Bursts/directional_coin_burst_001/directional_coin_burst_001_small_yellow/spritesheet.png`). The `.txt` frame maps come with it. |
| Free Effect and Bullet 16x16 | https://bdragon1727.itch.io/free-effect-and-bullet-16x16 | free for non-commercial games (custom); commercial use needs a contribution of any amount; modify OK; no resale or redistribution | Free for non-commercial use only; no redistribution. | `game/art/placeholders/bdragon-effect-bullet-16x16/`: Download the four sheets from the page and put them here with their original names. |
| Holy Spell Effect + Dark Spell Effect (free VFX 01-02) | https://pimen.itch.io/holy-spell-effect | custom: free for personal and commercial use and modification; no resale or redistribution; credit appreciated | License forbids redistribution. | `game/art/placeholders/pimen-holy-dark-vfx/`: Download the free files from https://pimen.itch.io/holy-spell-effect and https://pimen.itch.io/dark-spell-effect, extract the .rar archives, and copy the sheets so the paths match: `holy/Holy VFX 01/...`, `holy/Holy VFX 02/...`, `dark/Dark VFX 1/...`, `dark/Dark VFX 2/...`. |
| 16x16 Free NPC Pack + Enchanted Forest Characters (0x72 extensions) | https://superdark.itch.io/16x16-free-npc-pack | custom informal grant: free for any use incl. commercial, modification OK, no credit needed (author answered 'Yes it is' to 'Is it CC0?' in the Enchanted Forest comments); kept out of the repo because there is no formal CC0 deed | Informal grant (author's comment says CC0) with no license deed; kept local to be safe. | `game/art/placeholders/superdark-npcs-forest/`: Download the NPC pack and https://superdark.itch.io/enchanted-forest-characters, put `Fantasy RPG NPCs - Characters.png` and `Enchanted Forest Characters with animations.png` here. The NPC pack's animated frames come as a .rar; extract it here too if wanted. |
| m6x11, m6x11plus and m3x6 pixel fonts | https://managore.itch.io/m6x11 | custom: free to use with attribution ('Font by Daniel Linssen'); no license file, no redistribution grant | Free with attribution, no license file and no redistribution grant (only m5x7 is CC0, and it is in the repo). | `game/art/placeholders/linssen-fonts/`: Download m6x11 (and m6x11plus) from https://managore.itch.io/m6x11 and m3x6 from https://managore.itch.io/m3x6 and put the .ttf files here. Until then each name is a copy of the CC0 m5x7. |

Optional upgrades (nothing to place; the in-repo versions already work):

- Freesound originals: `packs/freesound-cc0-picks/` holds the public MP3 previews (four trimmed). Full-quality
  WAV/FLAC need a free Freesound login; links per file are in `packs/freesound-cc0-picks/LICENSE_SOURCE.txt`.
- Superdark's animated NPC frames ship as a RAR5 archive; extract on a machine with `unrar` or 7-Zip.
- More music from packs already in the repo: the other 35 Ninja Adventure tracks (https://pixel-boy.itch.io/ninja-adventure-asset-pack),
  the other 24 Shattered Pixel Dungeon tracks (refs/spd), the other four Nihilex beds (https://nihil-existentia.itch.io/free-audio-asset-collection).

Considered and left out: Gothic Castle Tileset by yanin, Castle Crypts by mftinyturtle, Medieval Interior by
a-something, Mystic Woods, Cute Fantasy RPG, Sprout Lands, Danaida's Free Pixel Monsters (non-commercial or
no redistribution, and the CC0 picks cover the same needs); Clavs neon tiles (credit-only custom license, karsiori covers it);
Heosphorus' animated vending machine (no license stated); House Edge and Isometric Casino Starter (3D or isometric);
Kronbits 200 SFX and ObsydianX interface tones (CC0, staged, but Kenney and Juhani already cover them); "casino midnight" by
madmakingmistery (CC0, never auditioned); OGA Gregorian "Chant" (uploader's ownership of the recording unclear).

## 4. Needs to sprites

Followers and the leader are 32x32. Where a pack sprite is 16px, it is either a 16px side character or
the model for a 32px redraw (see gaps).

### Casino (front door)

| Need | Sprites | Notes |
| --- | --- | --- |
| Room shell | `placeholders/jephed-casino-tileset/2D_TopDown_Tileset_Casino_1024x512.png` (carpet, walls, bar, tables); `packs/0x72-dungeontileset-ii/0x72_DungeonTilesetII_v1.7/atlas_walls_high-16x32.png`; `packs/spriteshift-purple-dungeon/PurpleDungeonTilesWithFloor.png` | Recolor Jephed dark. 0x72 wall banners in rarity colors hang over each machine. Red runner carpet from `packs/0x72-dungeontileset-ii/extended_niji/dungeontileset-extended.png` (oxblood) is the aisle to the dealer. |
| Background machines blinking | `placeholders/jephed-casino-tileset/Animated Sprite Sheets/SlotMachinesAnimationSheet_0.png`, `..._1.png`; `placeholders/jephed-casino-tileset/Animated Sprite Sheets/DecorativeLightsAnimationSheet.png` | Light chase runs around the room on every reveal. |
| Signs | `packs/karsiori-neon-signs/Sign 1/Sign 1 Glow - OPEN.png` and the other signs' flicker timing | Reletter CASES / WHEEL / odds in Jersey 10; signs flicker off while the owner is away. |
| Case machine (cabinet) | Jephed slot cabinet body; close-up pull screen `placeholders/kia-slot-machine/slot.png`; pull button and lever from `packs/buch-golden-ui/ui_split.png` | Kia is non-commercial; the CC0 fallback is a cabinet kitbashed from Jephed + Vircon32 parts. |
| Case (the physical box) | `packs/whimsy-hallow-chests/15_Ready_to_use_Treasure_Chests_Spritesheet.png` (wobble, white flash, open); `packs/carnageddon-demonic-chest/demonicchest1.png` (mythic maw); `packs/shattered-pixel-dungeon/sprites/mimic.png` (joke case) | Greyscale Whimsy base through the rarity shader. |
| Case reel strip | Item cards from `packs/kenney-playing-cards/Tilesheet/cardsMedium_tilemap_packed.png` (blank card + rarity border); case icons `packs/bonsaiheldin-chests-32/treasure_chests_32x32.png`; center needle and bezel `packs/vircon32-slot-machine/pixel_art_slot_machine_-_mechanic_elements.png`; window frame `packs/tiopalada-dark-dwellers-gui/20251029darkDwellers9SlicesA.png` | Rarity bar under each card is drawn (gap). |
| Rarity gem on reveal | `packs/karsiori-gems/GEM 1/GEM 1 - BLUE - Spritesheet.png` (and PURPLE, GOLD, RED; LILAC desaturated for common); cluster shape for mythic; `packs/karsiori-gems/Spark/Spark - Spritesheet.png` | Tier pips: `packs/kyrise-rpg-icons-16/icons/16x16/gem_01a.png` ... `gem_01j.png`. |
| Scratch-off ($1-$5) | Ticket base: blank medium card from Kenney Playing Cards; prize symbols `packs/greatdocbrown-coins-gems/coins-chests-etc-2-0.png` gift boxes and `packs/ninjikin-treasure-plus/Treasure+.png` relics; finger cursor `packs/kenney-cursor-pixel-pack/Tilemap/tilemap_packed.png` | Foil layer and flakes are drawn; the scratch is an alpha mask erased under the pointer. Card-flip timing: BigWander tarot frames (`placeholders/bigwander-dark-ritual/IndividualSprites/Card_Flip_01_TheDarkRitual_BigWander.png`). |
| Prize wheel | Room view `packs/draganas-prize-wheel-64/wheel_texture.png`; close-up drawn in code (wedges sized to the real odds) | Pointer, pegs drawn (gap). |
| Claw machine | Cabinet kitbashed from Jephed cabinet + glass; prizes are plushie versions of followers from `packs/kenney-pixel-platformer-characters/tilemap-characters_packed.png` and `packs/grafxkid-critters-penguin/TL_Creatures.png`; hand cursors from Kenney Cursor Pixel Pack | Claw (3 frames) drawn (gap). |
| Dealer | Rig and timing `packs/chasersgaming-pixel-poker/Dealer.png` (4 talk frames, bust framing); stand-ins `packs/shattered-pixel-dungeon/sprites/shopkeeper.png`, `packs/shattered-pixel-dungeon/sprites/imp.png`, `packs/ninja-adventure/Actor/Character/Inspector/Faceset.png`; chips and shoe `packs/chasersgaming-pixel-poker/Chips.png`, `packs/chasersgaming-pixel-poker/Card_Machine.png` | The real dealer is a drawn round, big-eyed, slightly wrong creature (gap). Word bubble: `packs/ninja-adventure/Ui/Dialog/DialogueBoxSimple.png`. |
| Odds on the wall | Digits from `packs/kenney-1-bit-pack/Tilesheet/monochrome-transparent_packed.png`, text in `packs/google-pixel-fonts-ofl/jersey10/Jersey10-Regular.ttf`, placard `packs/tiopalada-dark-dwellers-gui/20251117darkDwellersHeaderA.png` | Numbers painted on the wall, not a panel. Paytable layout from Vircon32. |
| Pity floor marker | Summoning circle drawing itself `packs/srzolda-magic-summons/purple_summon_Sheet.png` (glow grows toward epic at 25 and legendary at 100); BigWander pentagram glow stages as the 16px version | On the floor, never a bar. |
| Weekly draw | Ritual circle `packs/srzolda-magic-summons/red_idle_Sheet.png`; tickets from the Kenney card back; roulette-ball sound | Drum or urn on a dais is drawn (gap). |
| Trade-up (10 in, 1 out) | Input slots `packs/bonsaiheldin-chests-32/treasure_chests_32x32.png`; consumed puff `packs/foozle-lucifer-effects/Effects/VFX/Destroy Effect.png`; out beam Foozle rarity beam | Hopper and press drawn (gap). |
| Collection book | Cells `packs/tiopalada-dark-dwellers-gui/20251125portraitFrameA.png`; undiscovered = `???` orbs from greatdocbrown or dark silhouettes generated from the cosmetic sprite; trophies from `packs/ninjikin-treasure-plus/Treasure+.png`; display cases from Whimsy Hallow | Silhouettes are generated by a tool (alpha mask filled `night`). |
| Followers chanting at the back | `packs/dawnlike/Characters/Humanoid0.png` / `Humanoid1.png` hooded cultists (2-frame idle); Ninja `Monk`, `Monk2`, `Shaman` | Chant pose frames drawn (gap). |

### Followers and the leader

| Need | Sprites | Notes |
| --- | --- | --- |
| Cult flock (robed) | `packs/ninja-adventure/Actor/Character/Monk/SpriteSheet.png`, `Monk2`, `Shaman`, `Villager`-`Villager6`, `OldMan`, `OldWoman` | 16px chibis; promote to 32px on the Puny base. |
| Webkinz-style pets | `packs/ninja-adventure/Actor/Animal/Cat/` (Cat, CatBlack, Dog, Frog, Hamster, Pig, Racoon), `packs/puny-characters/PunyMonsters/Orange-Cat-32x32.png` (+ dog, rat), `packs/grafxkid-critters-penguin/penguin_edit.png` (Club Penguin nod), `packs/tiny-creatures/Tilemap/tilemap_packed.png` | One species per follower type; mood, hunger and favorite thing live on the creature. |
| Base body for 32px followers and won skins | `packs/puny-characters/Puny-Characters/Character-Base.png` (8 directions x 24 frames) | Cosmetics are aligned overlay sheets on this body (gap: 60+ overlays). |
| Personal follower (grows with the streak) | Model `packs/shattered-pixel-dungeon/sprites/sheep.png` + `packs/megowhat-little-lamb/lamb64x64.png`; portrait `packs/megowhat-little-lamb/lamb3.png` | Growth stages drawn (gap). |
| Stock followers (sized by weekly portfolio share) | Mushroom folk in three native sizes (`placeholders/superdark-npcs-forest/Enchanted Forest Characters with animations.png`); otherwise one species per holding scaled 16/24/32/48 px with cleanup | Over 40% = visibly huge; the others turn to stare (head-turn frames drawn). |
| Leader | `packs/ninja-adventure/Actor/CharacterAnimated/NinjaGreen/SpriteSheet.png` (32x32 full set) with `packs/ninja-adventure/Actor/CharacterAnimated/Weapon/Net.png` and `Pickaxe.png` | Recolor to a robed cult leader; Hoard emotes drawn (gap). |
| Mood without panels | `packs/tiopalada-emoji-pack-1/20250405emoticons-SheetDrooling.png` (hungry), `...-SheetSleepy.png` (lazy), `...-SheetLove.png` (fed), `...-SheetCrying.png` (mourning), `...-SheetLit.png` (chant), `...-SheetOMG.png` (staring); fill orbs `packs/ninja-adventure/Ui/Receptacle/Receptacle Sphere/BackgroundIron.png` + `ProgressWhite.png` | Status pips from `packs/shikashi-fantasy-icons/transparent_icons.png` (stomach, zzz, skull, heart). |
| Follower food (bought with coins) | `packs/ninja-adventure/Items/Food/Onigiri.png` and the rest of `Items/Food/` | |
| Villagers | Ninja `Villager*`, `OldMan*`, `Woman`; Superdark nuns, bishop, clerics, executioner (manual) | |
| While-you-were-out visitor, mourning | `packs/shattered-pixel-dungeon/sprites/ghost.png`, `packs/ninja-adventure/Actor/Character/Spirit/`, `packs/ninja-adventure/Actor/Boss/GiantSpirit/` | |

### Minigames, dungeon, gate, shrine, village

| Need | Sprites | Notes |
| --- | --- | --- |
| Mine | `packs/kenney-roguelike-caves-dungeons/Spritesheet/roguelikeDungeon_transparent.png` (walls, rails, ore in rarity hues), `packs/shattered-pixel-dungeon/environment/tiles_caves.png`, pickaxe overlay, critters from Tiny Creatures | Ore is cosmetic only. |
| Fishing | Pond `packs/ninja-adventure/Backgrounds/Tilesets/TilesetWater.png`, ripples `packs/ninja-adventure/Backgrounds/Animated/Water Ripples/SpriteSheet16x16.png`, `packs/ninja-adventure/Backgrounds/Vehicles/FishNet.png`, net overlay; catches `packs/dawnlike/Characters/Aquatic0.png`, `packs/ninja-adventure/Actor/Animal/Fish/` | Timing bar drawn from Dark Dwellers bars. |
| Daily dungeon (3 rooms) | `packs/shattered-pixel-dungeon/environment/tiles_sewers.png`, `tiles_prison.png`, `tiles_halls.png`; base floor `packs/0x72-dungeontileset-ii/dark_kosinaz/DarkDungeon.png`; portals as rarity doors `packs/shade-puny-dungeon/punyworld-dungeon-tileset.png` | Modifiers (Balatro-style cards from the real week) use `packs/ninja-adventure/Ui/Skill Icon/` and Shikashi weather icons. |
| Dungeon fodder and room bosses | 0x72 imp, chort, goblin, tiny_zombie; big_demon, ogre, big_zombie (atlas + `tile_list_v1.7`); `packs/ninja-adventure/Actor/Monster/` slimes, eyes, skulls | |
| Gate and debt boss | Arena `packs/shattered-pixel-dungeon/environment/tiles_halls.png` (skull pillars, red-vein floor); wall and gate `packs/kenney-tiny-town/Tilemap/tilemap_packed.png`; boss `packs/ninja-adventure/Actor/Boss/GiantSlime/` (interest-heal phase `GiantSlime2`), alternate `packs/shattered-pixel-dungeon/sprites/goo.png`; HP = balance bar `packs/shattered-pixel-dungeon/interfaces/boss_hp.png`; gargoyles from Whimsy Hallow | Damage states, heal swell, stagger, death and the unique drop are drawn (gap). |
| Shrine | Altar model `packs/dcss-altars-features/dungeon/altars/`; candles `packs/vk-candles-with-eyes/candles_with_eyes.png` (BigWander candle rings when downloaded); chandeliers and fire pits from Whimsy Hallow; ritual rug `packs/dawnlike/Objects/Decor0.png`; stained glass from SPD halls; idols `packs/ninja-adventure/Backgrounds/Tilesets/TilesetElement.png` | Flat 16px altar with sigil states is drawn (gap). |
| Coin fountain | 0x72 wall fountains (atlas), Whimsy fountains; coins `packs/evercrazy-coin-gem-8x8/SpinningCoin.png`, `packs/ninja-adventure/Items/Treasure/Coin2.png`, `packs/lpc-animated-coins/coin_gold.png` | Basin drawn or kitbashed; real-money coins never use brass play-coin art. |
| Village hub | `packs/kenney-tiny-town/Tilemap/tilemap_packed.png`, `packs/ninja-adventure/Backgrounds/Tilesets/TilesetHouse.png`, `TilesetVillageAbandoned.png`, `TilesetNature.png`, stalls from Whimsy Hallow | Night pass on all of it. |
| House in stages | Kitbash from Tiny Town walls and roofs + `packs/ninja-adventure/Backgrounds/Tilesets/TilesetHouse.png`; interiors `packs/kenney-roguelike-indoors/Tilesheets/roguelikeIndoor_transparent.png`, `packs/ninja-adventure/Backgrounds/Tilesets/Interior/TilesetInterior.png` | Stages (plot, foundation, frame, walls, roof, finished, decorated) drawn (gap); Cytopia (refs/cytopia) is the staging reference. |
| Wall (emergency fund) | Tiny Town fences and castle wall; DawnLike `Objects/Fence.png`, `Objects/Wall.png` | Stakes, palisade, stone, fortified, glowing stages drawn (gap). |
| Savings bundles (Stardew-style) | Offering pedestals kitbashed from DCSS altars and Whimsy display cases; filled-slot gems from Kyrise | Progress shows on the object. |

### UI (numbers on things, one stats screen)

| Need | Sprites |
| --- | --- |
| Cursor | `packs/tiopalada-dark-dwellers-gui/20251124mouseBig1-Sheet.png` (bony hand, 4 states); claw and scratch cursors from Kenney Cursor Pixel Pack |
| Buttons with pressed states | `packs/tiopalada-dark-dwellers-gui/20251125closeButton1-Sheet.png` etc. (32x32, 4 states); `packs/flatus-generic-dark-pixel-ui/sprites/gdp_styles.png` with ready StyleBoxes in `packs/flatus-generic-dark-pixel-ui/styles/` |
| Frames and plaques | Dark Dwellers 9-slices and headers; `packs/shattered-pixel-dungeon/interfaces/chrome.png` |
| Bars | `packs/tiopalada-dark-dwellers-gui/20251118darkDwellersBarA.png` (boss HP, pity), SPD `boss_hp.png` |
| Icons | `packs/shikashi-fantasy-icons/transparent_icons.png`, `packs/kyrise-rpg-icons-16/spritesheet/spritesheet_16x16.png`, SPD `buffs.png` (hunger, starvation), Flatus `gdp_icons.png` (lock, heart, skull) |
| Fonts | Body `packs/font-m5x7/m5x7.ttf`; big callouts `placeholders/linssen-fonts/m6x11plus.ttf` (Balatro's font; manual); cult titles `packs/google-pixel-fonts-ofl/jacquard12/Jacquard12-Regular.ttf`; inscriptions `packs/google-pixel-fonts-ofl/jacquardabastarda9/JacquardaBastarda9-Regular.ttf`; prices and odds `packs/google-pixel-fonts-ofl/jersey10/Jersey10-Regular.ttf`; tiny numbers `packs/google-pixel-fonts-ofl/tiny5/Tiny5-Variable.ttf`; dollar columns on the stats screen `packs/font-monogram/ttf/monogram-extended.ttf` |
| Transitions | `packs/sbs-animated-transitions/Iris01_strip_16x128.png` (into the casino), `Television01_strip_16x128.png` (while you were out), `Melt01_strip_15x128.png` (mythic), `Checker01_strip_17x128.png` (minigames) |

### Particles and reveal juice

| Moment | Sprites |
| --- | --- |
| Every coin landing | `placeholders/nogitsune-pixel-vfx/Coin-Sparkle/coin_sparkle_sheet.png` or in-repo `packs/ninjikin-treasure-plus/Shine_Sheet.png`; ring `packs/ninja-adventure/FX/Magic/Circle/SpriteSheetWhite.png` |
| Deposit lands (coin fountain) | `placeholders/untied-super-pixel-effects/spritesheet/Magic Bursts/directional_coin_burst_001/directional_coin_burst_001_small_yellow/spritesheet.png` (one-shot) + a GPUParticles2D stream of 8x8 coins + `packs/ninja-adventure/FX/Magic/Spirit/SpriteSheet.png` rising from chanting followers |
| Common reveal | One small ring: `packs/m484-explosion-set-1/M484ExplosionSet1_alpha.png` (grey) |
| Rare reveal | Ring + `packs/ninja-adventure/FX/Magic/Circle/SpriteSheetSpark.png` tinted blue + Foozle beam |
| Epic reveal | `packs/ansimuz-explosions/Explosions pack/explosion-1-g/spritesheet.png` recolored purple, `placeholders/nogitsune-pixel-vfx/Arcane-Burst/arcane_burst_sheet.png` |
| Legendary reveal | Pillar `placeholders/pimen-holy-dark-vfx/holy/Holy VFX 02/Holy VFX 02.png` or `placeholders/nogitsune-pixel-vfx/Holy-Pillar/holy_pillar_sheet.png`; beam `packs/foozle-lucifer-effects/Effects/Rarity Effects/Png/Legendary effect.png`; bloom `packs/kenney-particle-pack/PNG (Transparent)/light_01.png`; cutscene |
| Mythic reveal | Full-frame flash `packs/ansimuz-explosions/Explosions pack/explosion-1-e/explosion-5.png` recolored red, `packs/foozle-lucifer-effects/Effects/Rarity Effects/Png/Mythic effect.png`, circle `packs/srzolda-magic-summons/red_summon_Sheet.png`; cutscene |
| Near miss glint | `packs/ninjikin-treasure-plus/Shine_Sheet.png` glint sweep on the gold neighbor; `placeholders/bdragon-effect-bullet-16x16/Fire Effect and Bullet 16x16.png` glints |
| Hits, squash landings, dust | `packs/ninja-adventure/FX/Smoke/SmokeCircular/`, `placeholders/nogitsune-pixel-vfx/Dust-Cloud/dust_cloud_sheet.png`, `packs/foozle-lucifer-effects/Effects/Wave/Big/` |
| Glow under machines and candles | `packs/kenney-particle-pack/PNG (Transparent)/circle_05.png` as PointLight2D texture; `packs/ninja-adventure/FX/Environment/Raylight.png`, `Fog.png` |
| Follower specks | `packs/shattered-pixel-dungeon/effects/specks.png` (note, heart, steam, exclamation, coin) |
| Fed | `placeholders/nogitsune-pixel-vfx/Heart-Pop/heart_pop_sheet.png` |
| Mourning weather | `packs/ninja-adventure/FX/Particle/Leaf.png` and `Rain.png` recolored grey |
| Debt boss hit / penalty | `placeholders/untied-super-pixel-effects/spritesheet/Smoke Bursts/stylized_skull_smoke_burst_001/` and `packs/ansimuz-explosions/Explosions pack/explosion-1-b/spritesheet.png` grey |

### SFX by event

| Event | Sounds |
| --- | --- |
| Reel tick (rate follows the uneven slowdown) | `packs/kenney-interface-sounds/Audio/tick_001.ogg`, `tick_002.ogg`, alt `packs/mikeask-menu-tick/menu tick.ogg`; body `packs/freesound-cc0-picks/415074_slot_machine_reels_sound_m4a.mp3` |
| Reel slowing riser | `packs/kenney-digital-audio/Audio/phaserUp1.ogg`, `packs/wobbleboxx-levelup-coin/Rise01.ogg`; heartbeat `packs/bart-heartbeat-sounds/heartbeat_slow_0.ogg` / `heartbeat_fast_0.ogg` |
| Near miss (almost gold) | `packs/kenney-interface-sounds/Audio/glass_001.ogg` then `packs/kenney-digital-audio/Audio/phaserDown1.ogg` / `packs/wobbleboxx-levelup-coin/Downer01.ogg` |
| Reveal stingers by tier | common `packs/kenney-music-jingles/Audio/Pizzicato jingles/jingles_PIZZI00.ogg`; rare `Steel jingles/jingles_STEEL00.ogg`; epic `Sax jingles/jingles_SAX00.ogg`; legendary `Hit jingles/jingles_HIT00.ogg` + `packs/ignisforge-sfx-sampler/jackpot_01.ogg`; mythic HIT + `packs/ignisforge-sfx-sampler/stinger_01.ogg` + choir swell from `packs/mumusi-cathedral-of-shadows/Cathedral_of_Shadows_loop.ogg` |
| Real money lands | `packs/lrsf-coins-library/Coins_Pouring/Coins_Pouring_00.ogg` (bed, scaled by amount), `Coins_Several/`, `Coins_Single/`; shrine bell `packs/kenney-impact-sounds/Audio/impactBell_heavy_000.ogg`; chant swell |
| Coins earned by play | `packs/juhani-512-retro-sfx/General Sounds/Coins/sfx_coin_single1.ogg`, `packs/luke-8bit-coin-sounds/coin1.ogg`, `packs/ninja-adventure/Audio/Sounds/Bonus/Coin.ogg` |
| Followers chanting | `packs/owlishmedia-creepy-chanting/chant1.ogg` ... `chant23.ogg` layered and pitched; `ethereal_chant_Subclip_01_01.ogg`; `packs/freesound-cc0-picks/669797_Dark_Chanting_mp3.mp3` |
| Follower babble and moods | `packs/ninja-adventure/Audio/Sounds/Voice/Voice1.ogg` ... `Voice10.ogg` pitched per follower; eating `packs/shattered-pixel-dungeon/sounds/eat.mp3` |
| Dealer | Cards and chips `packs/kenney-casino-audio/Audio/card-shuffle.ogg`, `cards-pack-open-1.ogg`, `chips-collide-1.ogg`; letters typing `packs/ignisforge-sfx-sampler/blip_15.ogg`; table slam `packs/kenney-interface-sounds/Audio/bong_001.ogg` |
| Scratch-off | `packs/kenney-interface-sounds/Audio/scratch_001.ogg` ... `scratch_005.ogg`, `packs/freesound-cc0-picks/127979_Scratching_Paper_mp3.mp3`, `packs/antumdeluge-scrapes/scrape-1.ogg` |
| Prize wheel | `packs/freesound-cc0-picks/274007_prize_wheel.mp3`, pegs `packs/freesound-cc0-picks/752284_Spin_the_wheel_clicks.mp3`, `packs/kenney-ui-audio/Audio/switch1.ogg` |
| Claw machine | Winch `packs/freesound-cc0-picks/376195_toy_ratchet_wav.mp3`, latch `packs/kenney-rpg-audio/Audio/metalLatch.ogg`, drop `packs/kenney-casino-audio/Audio/chips-collide-1.ogg` |
| Weekly draw | `packs/freesound-cc0-picks/709623_Casino_RouletteSound_ball_damping.mp3`, `packs/kenney-casino-audio/Audio/dice-shake-1.ogg` |
| Trade-up | `packs/ignisforge-sfx-sampler/spellzap_04.ogg` |
| Collection book | `packs/kenney-rpg-audio/Audio/bookFlip1.ogg`; page complete `packs/shattered-pixel-dungeon/sounds/badge.mp3` |
| Buttons (squash) | `packs/kenney-interface-sounds/Audio/click_001.ogg`, `pluck_001.ogg`; `packs/kenney-ui-audio/Audio/rollover1.ogg` |
| Mine | `packs/kenney-impact-sounds/Audio/impactMining_000.ogg`, `packs/themightyglider-breaking-rock/rock_break.ogg`, `packs/shattered-pixel-dungeon/sounds/mine.mp3` |
| Fishing | `packs/fisheefects/reel.ogg`, `splash.ogg`, `bloop.ogg`, `point_special.ogg`, `uhoh.ogg`; `packs/freesound-cc0-picks/347840_fishing_reel_wav.mp3` |
| Dungeon | `packs/ninja-adventure/Audio/Sounds/Hit & Impact/Hit1.ogg`, `packs/shattered-pixel-dungeon/sounds/hit.mp3`, `step.mp3`, `door_open.mp3`; room change `packs/juhani-512-retro-sfx/Movement/Portals and Transitions/` |
| Debt boss | Payment hit `packs/kenney-impact-sounds/Audio/impactPunch_heavy_000.ogg` + `impactMetal_heavy_000.ogg`; roar `packs/rubberduck-80-rpg-sfx/creature_roar_02.ogg`; slime `creature_slime_02.ogg`; interest heals `packs/ninja-adventure/Audio/Sounds/Magic & Skill/Heal.ogg`; low HP `packs/juhani-512-retro-sfx/General Sounds/Alarms/Low health Alarms/`; boss start `packs/shattered-pixel-dungeon/sounds/boss.mp3` |
| Mourning a missed week | Toll `packs/kenney-impact-sounds/Audio/impactBell_heavy_001.ogg`, `packs/ninja-adventure/Audio/Jingles/GameOver.ogg`, a slowed ethereal chant; streak break `packs/kenney-interface-sounds/Audio/glitch_001.ogg` |
| Footsteps | `packs/kenney-impact-sounds/Audio/footstep_carpet_000.ogg` (casino), `footstep_wood_000.ogg`, `footstep_grass_000.ogg` (village) |

The synthesized stand-ins in `game/audio/` (`tools/sfx.py`) get replaced by these when Step 1 wires sound.

### Music by room

| Room | Track |
| --- | --- |
| Casino bed | `packs/nihilex-dark-ambient/04.Those_Who_Wait.ogg` low, room tone `packs/freesound-cc0-picks/79088_AkasakaPachinkoParlorLunchtime_4micsStereoExpanded_wav.mp3` at -24 dB |
| Casino lounge (detuned) | `packs/ove-melaa-select/Ove_Melaa-High_Stakes_Low_Chances.mp3` |
| Dealer's pause | `packs/ninja-adventure/Audio/Music/28 - Tension.ogg` |
| Shrine | `packs/mumusi-cathedral-of-shadows/Cathedral_of_Shadows_loop.ogg` |
| While you were out | `packs/nihilex-dark-ambient/06.There_In_Spirit.ogg` |
| Village | `packs/ninja-adventure/Audio/Music/26 - Lost Village.ogg` |
| Gate approach / fight | `packs/ninja-adventure/Audio/Music/14 - Curse.ogg`, then `packs/shattered-pixel-dungeon/music/city_boss.ogg` and `city_boss_finale.ogg` on the breaking payment |
| Dungeon rooms 1-3 | `packs/shattered-pixel-dungeon/music/sewers_1.ogg`, `prison_1.ogg`, `halls_1.ogg`; `halls_tense.ogg` for the last room |
| Mine / fishing | `packs/shattered-pixel-dungeon/music/caves_1.ogg` / `packs/ninja-adventure/Audio/Music/18 - Aquatic.ogg` |
| Casino after hours | `packs/ninja-adventure/Audio/Music/10 - Dark Castle.ogg` |
| Mourning | `packs/ninja-adventure/Audio/Music/7 - Sad Theme.ogg`, `packs/ove-melaa-select/Ove_Melaa-Dead_Buried_and_Cold_Ambient_Pad.ogg` |

## 5. Gaps: what has to be extended or drawn

| Gap | How |
| --- | --- |
| 20+ packs in one room | Packs keep their colors; `tools/art/recolor.py` only matches outlines, keys out backgrounds and evens saturation, plus the rarity palette-swap shader; see section 1. |
| Rarity variants of props (banners, candles, carpets, portals, chests, gems, beams, rings) | Recolor, not redraw: one greyscale base per prop through the 5x3 LUT. Grey and purple are missing from most VFX (Foozle, M484, BDragon): make them with the same shader. |
| Dark casino floor and cult-casino hybrid | Recolor Jephed (or kitbash 0x72 floors + Purple Dungeon + DawnLike rugs if Jephed stays out); pews facing the dealer kitbashed from Roguelike Indoors benches; ritual carpet = 0x72 runner in oxblood with a rarity inlay. |
| Case reel strip, item cards with a rarity bar, center needle, reveal plaque | Kitbash: Kenney medium card + 9-slice rarity border (drawn, 5 colors), Vircon32 arrows, Dark Dwellers frame, edge vignette shader; motion smear sprites drawn (3 small frames). |
| Scratch ticket foil and flakes | Draw a foil 9-slice and 2-3 px grey flakes; mask shader for the scratch. |
| Prize wheel pointer and pegs, claw (open/closing/gripped), claw cabinet, weekly-draw drum, trade-up hopper and press | Draw at 16px to match the surrounding packs, cabinets kitbashed from Jephed slot bodies and the Kia cabinet layout. |
| The dealer | Draw a 32x32 in-room sprite and a ~48x64 bust: round, big-eyed, menacing; idle tic, 4-frame lip-flap (Chasersgaming timing), lean-in for the near miss, slow grin on a rare pull, still stare. Facesets from Ninja as references. |
| Cult behaviours for followers | Draw on the Puny base (32x32): chant (arms up, sway), worship, eat, sleep, hungry clutch, cheer, sulk, cry, head-turn stare. |
| 60+ cosmetics in five tiers, two sets | Overlay sheets aligned to Puny Character-Base frames (robes, masks, hats, halos, horns, auras); plushie versions for the claw from Kenney Pixel Platformer and GrafxKid blobs; trophies from Treasure+. Silhouettes generated. |
| Personal follower growth (egg/lamb to elder) | Redraw at 32x32 from SPD sheep + Little Lamb; 64px Little Lamb for cutscenes. |
| Stock followers at 16/24/32/48 px and the over-40% giant | Superdark mushroom folk (3 native sizes) where they fit; otherwise nearest-scale + hand cleanup; giant state drawn. |
| Debt boss fight states | Extend Ninja GiantSlime / SPD Goo: swell-and-glow heal, stagger per payment, enrage at thresholds, dissolve, unique drop pop. HP-bar shards drawn. |
| Shrine centerpiece | Draw a flat 16px altar (2x2 tiles) with a glowing sigil in 3 intensity states, using DCSS altars as the guide. |
| House stages and the emergency-fund wall | Draw top-down stages (plot, foundation, frame, walls, roof, finished, decorated; stakes, palisade, stone, fortified, glowing) kitbashed from Tiny Town, Ninja Adventure and DawnLike walls; Cytopia's isometric stages are the pacing reference only. |
| Gate as a big damageable object | Kitbash Tiny Town castle gate + SPD halls pillars; crack overlays in 4 stages that spread with payments and partly heal monthly. |
| Night village | Recolor pass on Tiny Town, Ninja Adventure and Roguelike tiles (section 1). |
| Bundle pedestals and collection room | Kitbash DCSS altars + Whimsy display cases; filled-slot gems from Kyrise. |
| Glow and light | Kenney particle masks as Light2D textures, additive sprites; Purple Dungeon torch halo as the reference look. |
| Cutscene art (64-128 px) for legendary/mythic and while-you-were-out | Draw; procedural god rays (rebuild the idea of SPD's `Flare.java`, don't paste it). |
| Neon lettering (CASES, WHEEL, odds, $5/$20) | Letter in Jersey 10 / m6x11 with karsiori's glow and flicker timing. |
| LCD digits for machine readouts | Draw a 5x7 segment font, or use Jersey 10. |
| Sigils and runes for the shrine and weekly modifiers | Small hand-drawn set; SrZolda circles and Ninja skill icons cover part. |
| Floating numbers (+$20) | m5x7 / m6x11 with a 1px ink outline, tinted per rarity when it is a reveal. |
| Dealer voice, five-tier stinger family, rhythmic group chant, critter vocal range, claw motor, latex scratch, lottery drum, seedy lounge loop | Build in the mixer: Ninja Voice blips pitched as babble with the odds on the wall; same Kenney jingle index across instruments; layered OwlishMedia takes; formant-shifted Voice/pluck; ratchet + metal clicks; filtered scrapes; roulette ball + dice shake; detune and low-pass Ove's High Stakes. |
| Real money vs play coins | Mixing rule: LRSF recorded coins only when real money moves; 8-bit coins only for play coins. |

## 6. Credits

Generated from `game/art/packs/credits.json` (the game's credits screen reads that file).

Required (CC-BY, GPL, OFL): show these on the credits screen.

- Shattered Pixel Dungeon art and audio by Evan Debenham, Pixel Dungeon by Watabou, music by Kristjan Haaristo, sound effects by Celesti (GPL-3.0); Freesound samples by JoelAudio, saturdaysoundguy, InspectorJ, Taira Komori, timmy h123 (CC-BY) and others (CC0)
- DawnLike tileset by DragonDePlatino, DB16 palette by DawnBringer (CC-BY 4.0)
- Treasure+ by SciGho (https://ninjikin.itch.io/treasure), CC-BY 4.0
- Treasure chests by Bonsaiheldin (http://bonsaiheld.org), CC-BY 4.0
- "Pixel art slot machine" by Vircon32 (Carra), CC-BY 4.0
- Animated Coins by Clint Bellanger (CC-BY 3.0)
- Icons by Matt Firth (shikashipx), based on designs from game-icons.net, CC-BY 4.0
- Icons by Kyrise (kyrise.itch.io), CC-BY 4.0
- Jacquard 12, Jacquarda Bastarda 9, Jersey 10, Micro 5 by Sarah Cadigan-Fried; Pixelify Sans by Stefie Justprince; Silkscreen by Jason Kottke; Tiny5 by Stefan Schmidt (SIL OFL 1.1)
- Magic Summons by SrZolda (CC-BY 4.0)
- Coins Sound Effects by Little Robot Sound Factory - www.littlerobotsoundfactory.com (CC-BY 3.0)
- Music by mumusi_c21 - https://mumusi-c21.itch.io (CC-BY 4.0)
- "High Stakes, Low Chances" and "Dead, Buried and Cold" written and produced by Ove Melaa (Omsofware@hotmail.com), CC-BY 3.0

Courtesy (CC0, credit not required but given):

- DungeonTileset II by 0x72, Extended by Niji, Dark Dungeon by kosinaz (CC0)
- Whimsy Hallow by Crumpaloo (CC0)
- 1-Bit Pack by Kenney (CC0)
- Roguelike Indoors by Kenney (CC0)
- Roguelike Caves & Dungeons by Kenney (CC0)
- Tiny Town by Kenney (CC0)
- Tiny Dungeon by Kenney (CC0)
- Purple Dungeon TileSet by Spriteshift (CC0)
- Puny Dungeon by Shade (CC0)
- Ninja Adventure by Pixel-boy and AAA (CC0)
- Dungeon Crawl Stone Soup tiles (CC0)
- Candles with eyes by vk (CC0)
- Puny Characters by Shade (CC0)
- Sprites by GrafxKid, penguin edit by Zombie Rat (CC0)
- Tiny Creatures by Clint Bellanger (CC0)
- Little Lamb by megowhat (CC0)
- Pixel Poker by Chasersgaming (CC0)
- Pixel Platformer by Kenney (CC0)
- Whimsy Hallow Chests by Crumpaloo (CC0)
- Demonic chest by carnageddon (CC0)
- Gold treasure icons by Bonsaiheldin (CC0)
- Coins & Gems by greatdocbrown (CC0)
- Pixel Art Gems by karsiori (CC0)
- Pixel Art Neon Signs by karsiori (CC0)
- Playing Cards Pack by Kenney (CC0)
- Wheel Fortune by draganasgamesart (CC0)
- Slot symbols by Public Void Interactive (CC0)
- 8x8 coins by EverCrazy (CC0)
- Lucifer Pickups by Foozle (CC0)
- Gems / Coins by La Red Games (CC0)
- Tiny RPG Dark Dwellers GUI by tiopalada (CC0)
- Generic Dark Pixel UI by Flatus (CC0)
- Golden UI by Buch (CC0)
- Tiny RPG Emoji Pack by tiopalada (CC0)
- Cursor Pixel Pack by Kenney (CC0)
- UI Pack Pixel Adventure by Kenney (CC0)
- Emotes Pack by Kenney (CC0)
- m5x7 by Daniel Linssen (CC0)
- monogram by Vinicius Menezio (CC0)
- Lucifer Effects by Foozle (CC0)
- Explosion Animations by ansimuz (CC0)
- Explosion Set 1 by Master484 (CC0)
- Particle Pack by Kenney (CC0)
- Animated Transitions by Screaming Brain Studios (CC0)
- Interface Sounds by Kenney (CC0)
- UI Audio by Kenney (CC0)
- Casino Audio by Kenney (CC0)
- Impact Sounds by Kenney (CC0)
- RPG Audio by Kenney (CC0)
- Music Jingles by Kenney (CC0)
- Digital Audio by Kenney (CC0)
- Creepy Incoherent Chanting by OwlishMedia (CC0)
- IgnisForge SFX (CC0)
- Dark ambient by Nihilex (CC0)
- Freesound sounds by tony_bear, leocb, aghirlandaio, monotraum, poenia, markystar, TheWoodlandNomad, univ_lyon3, Henaway, ameslynn, fennelliott, 170129, qubodup, SnowFightStudios, timothyd4y (CC0)
- Retro SFX by Juhani Junkala / SubspaceAudio (CC0)
- 10 8bit coin sounds by Luke.RUSTLTD (CC0)
- Fisheefects by Memoraphile @ You're Perfect Studio (CC0)
- Heartbeat sounds by bart (CC0)
- Menu select tick by mikeask (CC0)
- Scrapes by AntumDeluge (CC0)
- Breaking Rock by themightyglider (CC0)
- Level up, power up, Coin get by wobbleboxx (CC0)
- 80 CC0 RPG SFX by rubberduck (CC0)

Manual downloads (add when the real files are dropped in; Jephed, unTied and Linssen ask for credit):

- Jephed, Game Between The Lines, https://gamebetweenthelines.com/
- The Dark Ritual by BigWander (https://bigwander.itch.io/the-dark-ritual)
- 32x32 slot machine by Kia (https://kia.itch.io)
- Pixel VFX by NogitsuneGurl
- Super Pixel Effects Gigapack - Will Tice / unTied Games
- Effect and Bullet 16x16 by BDragon1727
- Holy and Dark Spell Effects by pimen
- NPC Pack and Enchanted Forest Characters by Superdark
- Font by Daniel Linssen (managore.itch.io)

## 7. Keeping it clean

- Only packs whose license allows redistribution go in `game/art/packs/`. Every folder keeps its license
  file or license evidence plus `SOURCE.md`. Anything else is a manual download with a placeholder.
- Don't edit files in `packs/` in place; recolors and slices go to generated folders, so each pack
  stays exactly what its SOURCE.md describes.
- GPL-3.0 (Shattered Pixel Dungeon): fine for this private build. If Hoard is ever distributed, it ships
  under GPL-compatible terms with `packs/shattered-pixel-dungeon/LICENSE.txt` and the credits intact.
- Keep `game/art/packs/` under 60 MB. Big audio was converted to Ogg Vorbis and trimmed (see each SOURCE.md).
