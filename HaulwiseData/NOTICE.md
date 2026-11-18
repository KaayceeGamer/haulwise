# Haulwise Data

Haulwise Data is a separate addon from Haulwise. It holds where profession trainers and recipe
vendors stand in WoW Forever, so Haulwise can set waypoints to them. It contains no code.

## Where the data comes from

The data is extracted from the Forever dataset of **QuestieDB**
(https://github.com/Questie/QuestieDB), at commit `4f628e8328ed8923ffba169c8b432996e0a7a326`
(18 November 2026), with `tools/build-haulwise-data.py` in the Haulwise repository. Only NPC names,
titles, factions, positions, profession trainers and the vendors of recipe items are kept.

QuestieDB's data was imported from **Questie** (https://github.com/Questie/Questie). Thanks to the
Questie team and everyone who contributed to Questie and QuestieDB.

Haulwise and Haulwise Data are not affiliated with or endorsed by the Questie team.

## Licence

Haulwise Data is licensed under the **GNU General Public License v3** (see `LICENSE.md`), the
licence the Questie team offers for its content. Haulwise itself is a separate addon under the MIT
licence; it reads this data when Haulwise Data is installed and works without it.
