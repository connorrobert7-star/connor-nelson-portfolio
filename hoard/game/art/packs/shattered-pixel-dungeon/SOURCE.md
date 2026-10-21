# Shattered Pixel Dungeon assets (sprites, environment, effects, interfaces, sounds, 7 music tracks)

- **Author:** Evan Debenham (Shattered Pixel), after Pixel Dungeon by Watabou; music by Lumine (Kristjan) Haaristo, SFX by Celesti, plus Freesound samples listed in CREDITS_from_AboutScene.txt
- **Page:** https://github.com/00-Evan/shattered-pixel-dungeon
- **License:** GPL-3.0
- **License evidence:** LICENSE.txt at the repo root (GNU GPL v3, 29 June 2007), copied here from the clone at commit 57a4e06a4caf162446d1c28caa7983f0493fecf0 (2026-10-06). The repo has no separate asset license; docs/getting-started-*.md say distributing a modification is bound by GPLv3, and docs/recommended-changes.md says existing credits must be kept. Sounds: AboutScene.java credits Freesound samples under CC-BY (JoelAudio, saturdaysoundguy, InspectorJ, Taira Komori, timmy h123) and CC0; those credits are kept in CREDITS_from_AboutScene.txt and in Hoard's credits.
- **Status:** in repo, 4.93 MB (133 png, 67 mp3, 7 ogg, 3 txt)
- **Format:** 16x16 tiles on 256x256 sheets; sprites ~12-20 px frames (sizes in sprites/<Name>Sprite.java); specks 8x8

## What Hoard uses it for

sprites/: sheep (model for the personal lamb follower), ghost (mourning, while-you-were-out visitor), goo (alternate debt boss), shopkeeper and imp (dealer and croupier stand-ins), wandmaker (shrine priest), eye and yog (watching-eye decor over machines), mimic (biting joke case), ratking. environment/: sewers, prison and halls sheets for the three daily dungeon rooms; halls skull pillars and red-vein floor for the debt-boss arena; stained glass recolored per rarity for the shrine. effects/: coin, note, heart, steam and exclamation specks over followers. interfaces/: boss_hp.png is the debt boss bar, buffs.png hunger and starvation icons, chrome.png 9-slices. sounds/: gold, mine, rocks, eat, mimic, secret, badge, boss, chains. music/: three dungeon rooms (sewers_1, prison_1, halls_1), halls_tense, caves_1 for the mine, city_boss and city_boss_finale for the gate fight.

## Credit line (game credits)

Shattered Pixel Dungeon art and audio by Evan Debenham, Pixel Dungeon by Watabou, music by Kristjan Haaristo, sound effects by Celesti (GPL-3.0); Freesound samples by JoelAudio, saturdaysoundguy, InspectorJ, Taira Komori, timmy h123 (CC-BY) and others (CC0)

## What was kept and changed

Copied straight from refs/spd/core/src/main/assets. Only 7 of 31 music tracks kept for size. fonts/ (pixel_font) and splashes/ not copied: the font's origin is undocumented and the splashes are unused. SPECKS_INDEX.txt lists where the speck indices and particle code live (read as reference, rebuild in GDScript, do not paste).

Recolor to the master palette in docs/ASSETS.md before use (rarity colors only where rarity is meant).
