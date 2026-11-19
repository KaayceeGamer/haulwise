# Haulwise Data

Haulwise Data is a separate addon from Haulwise. It holds where profession trainers and recipe
vendors stand in WoW Forever, so Haulwise can set waypoints to them, and which quests need an item,
who sells it and which mobs drop it, for Haulwise's item tooltips. It contains no code.

## Where the data comes from

The data is extracted from the Forever dataset of **QuestieDB**
(https://github.com/Questie/QuestieDB), at commit `4f628e8328ed8923ffba169c8b432996e0a7a326`
(18 November 2026), with `tools/build-haulwise-data.py` in the Haulwise repository. Only NPC names,
titles, factions, positions, profession trainers, the vendors of recipe items, quest names, levels
and factions with the items they need, and the vendors and mobs items come from are kept.

QuestieDB's data was imported from **Questie** (https://github.com/Questie/Questie). Thanks to the
Questie team and everyone who contributed to Questie and QuestieDB.

`Drops.lua` holds estimated drop rates and coins per kill, extracted from the **CMaNGOS Classic DB**
(https://github.com/cmangos/classic-db, GPLv3) at commit `e4825cf48176edff313d78de66b0beb14371c8eb`, with
`tools/build-drop-rates.py`. Only normal (non-elite) mobs that exist in QuestieDB's Forever dataset
are kept, with Forever's names, levels and zones; drops under 0.5% are left out. Thanks to the
CMaNGOS team and everyone who contributed to the Classic DB. World of Warcraft content is a
trademark and copyright of Blizzard Entertainment.

Haulwise and Haulwise Data are not affiliated with or endorsed by the Questie or CMaNGOS teams.

## Licence

Haulwise Data is licensed under the **GNU General Public License v3** (see `LICENSE.md`), the
licence the Questie team offers for its content. Haulwise itself is a separate addon under the MIT
licence; it reads this data when Haulwise Data is installed and works without it.
