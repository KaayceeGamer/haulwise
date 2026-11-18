# Changelog

## 0.8.2
- **Find trainer** matches your skill: at your cap (150/150) it finds a trainer for the next rank; below it (131/225) one that teaches up to your cap, so not a Journeyman when you're already Expert.

## 0.8.1
- **An arrow on screen** for waypoints: WoW Forever's own waypoint is only a pin on the map, so Haulwise draws its own arrow with the distance. It goes away when you arrive; drag it to move it, right-click to clear it. With TomTom installed, TomTom's arrow is used instead.

## 0.8.0
- **Waypoints to trainers and recipe vendors.** *Find trainer* in the Craft tab (or `/haul trainer tailoring`) points you to the nearest trainer of your faction that teaches your next rank: Journeyman, Expert or Artisan. In Recipes, click a recipe to go to the vendor that sells it; Shift-click searches the AH. Uses TomTom when it's installed, otherwise the game's own map pin and arrow.
- **Haulwise Data**: a new data-only addon that comes in the same download. It knows where 450+ profession trainers and recipe vendors stand in WoW Forever, from QuestieDB's Forever data (GPLv3; thanks to the Questie team). With QuestieDB installed, Haulwise reads it too.
- Haulwise remembers where every trainer and vendor you open stands, and those spots win over the data, so NPCs that moved in WoW Forever are right once you've been there.
- **Pick a profession** in Craft, Skill up and Recipes: the *Profession* button switches between All and each of your professions (remembered per character).

## 0.7.3
- **Deals** are more careful before there are 3 days of scans: the resale price is the next listing above the cheap ones, not one scan's middle price, and anything over 300% profit is left out. No more "3140%" wine.
- **Recipes**: "Worth learning" names the recipe that pays for itself fastest, and only if that's within 100 crafts.

## 0.7.2
- **Quest reward pick**: when a quest lets you choose, Haulwise marks the best reward with a gold frame and says why in chat: your biggest gear upgrade, or else the one worth the most (vendor, auction house or disenchanting). Off in Settings → Gear.
- **Easier to find the big window**: the small box has an **Open Haulwise** button instead of a tiny icon, and a first-time tip says where everything is.
- **Farm → By zone**: no more question-mark icons over the zone names, the Rank button (Safe/Expected) is there too, and the best zone line shows the same figure the zones are ranked by.

## 0.7.1
- **Disenchant button** works again: it sat behind the Haulwise window, which took the clicks.
- **Disenchant for mats** (Bags tab): leveling Enchanting? Tick it, and gear you can disenchant yourself is marked to disenchant, with the Disenchant button, even when selling pays more. It shows what that costs you compared with selling, picks the item that costs least, and skips gear that sells for more than 3 times its mats. The swap and Make room popup switches now live only in Settings.
- **Smaller saved data**: auction prices are saved as one short line per item, and old price history and unused item names are cleared out. The saved file shrinks by about a third, so logging in and `/reload` are quicker.
- **Shopping list**: the profit now counts the reagents you already have too, so it matches the Craft tab (before, it only subtracted what you still had to buy).

## 0.7.0
- **Minimap button**: click to open Haulwise, right-click for settings, Shift-click for the HUD. Drag it around the minimap (round or square). Hide it in Settings or with `/haul minimap`. With Titan Panel, ElvUI or another data broker display, Haulwise shows up there too.
- **German and French**: every text in Haulwise is translated. It follows your game's language; pick another in Settings → Language (or `/haul lang deDE`) and `/reload`.
- Professions are stored under one name whatever your game's language, so recipes, disenchanting and alts line up on every client.
- **Disenchanting** is noted reliably now (the item locks a moment after the cast starts, and auto loot is fast), and a chat line confirms what you got.

## 0.6.3
- **Community data line** at the bottom of the window: when the pooled data is from, how many players shared, and how many of your kills aren't shared yet. Click it to import the newest data.
- **Bug reports made easy**: Haulwise keeps its last errors, and `/haul feedback` shows them ready to paste into a report.
- **Recipes** show the skill they need (from trainers, the recipe's tooltip, or a ~guess from the gear's level) and hide recipes 30+ points above your skill. Tick "Show recipes far above my skill" to see them all.
- The scan button says what it's doing: waiting for the auction house, or reading the listings.

## 0.6.2
- **Share data** (was "Share kills"): the export also holds the trainer and vendor recipes and reagent prices you've seen, so the button now says so.
- Uploads no longer fail with "bad text in recipe": records with an empty or odd name are left out instead of breaking the whole upload.
- **Community data** updated: drop rates for 463 mobs.

## 0.6.1

### Fixes from the first days of play
- **AH scan** can no longer get stuck on "scanning...": it shows progress on the button, stops with a reason if the auction house doesn't answer within a minute, and resets if you close the auction house.
- **Pawn 2.14** is detected again, and there's a **Use Pawn** checkbox in the Gear tab.
- **Gear upgrades** no longer show a fake +100% when the game hasn't sent the stats of what you wear yet. Gear → On the AH shows what each item **replaces** and is checked again when you change gear.
- **Deals**: rare items and gear need 3 days of scans before they count as "below market", so one odd listing no longer looks like a deal. Item names show even before the game has loaded them.
- **Popups**: only one at a time. The swap card sits next to the loot window, and says "Leave it" when even your cheapest item is worth more.
- **Class reagents** (Light Feather, candles, runes, seeds...) are never offered for deletion.
- **Disenchanting**: WoW Forever has no skill limit, so Haulwise no longer says you need a higher skill.
- Tooltips use brighter colours; Settings buttons no longer overlap; "1 craft", not "1 crafts".

## 0.6.0

### Gold
- **Gear → On the AH**: every full auction house scan checks all gear for sale against you and your alts, ranked by how much upgrade each gold buys. Max price button; click to search.
- **Shopping list**: click recipes in Craft to add them. It sums every reagent, subtracts what's in your bags and bank, and shows where the rest is cheapest.
- **Craft → Skill up**: the cheapest recipes to raise your profession, by cost per skill point.
- **Selling help**: next to the AH sell frame, a suggested price from live listings and your scans, with a warning when a vendor pays more. Use price fills it in; you press Post.

### Bags and mail
- **Best move** for every item: sell on the AH, sell to a vendor, disenchant, or send to an alt who can disenchant it.
- **Disenchant button** on the Bags tab when disenchanting pays most (out of combat only).
- **Mats to crafters**: at a mailbox, one click sends crafting mats to the alt whose recipes use them.

### Tooltips and disenchanting
- Gear tooltips show the **best move** (vendor, AH or disenchant), what it **disenchants into** with chances and AH prices, and what **your own disenchants** of that item (or items like it) actually gave.
- WoW Forever lets anyone with Enchanting disenchant anything, so the old skill limits are gone.
- The swap card sits next to the loot window, and only one popup shows at a time. Class reagents (Light Feather, candles, runes...) are never offered for deletion.

### Farm
- **By zone**: zones ranked by the best gold per hour there; click one to see its mobs.
- **This zone only**: just the mobs where you are.

## 0.5.0 — First public release

Everything below is new.

### HUD and windows
- HUD with gold per hour, gold, bag value and total worth, the cheapest items to throw away and waiting upgrades.
- Main window with eight tabs: Farm, Bags, Gear, Craft, Deals, Recipes, Market and Holdings.
- Both stay open until you close them. Drag a corner to resize them, and click any column title to sort.
- Settings for font, text size, scale and background opacity.
- An in-game guide, plus a short "What's new" after each update.

### Bags
- Every item is valued at the best of vendor, auction house (after the 5% cut) and disenchant value.
- When your bags are full, Haulwise offers a one-click swap with the cheapest item and warns you if it would lose you money.
- Crafting materials, quest items, tools, ammo, epics, reagents your recipes use, upgrades and kept items are never offered for deletion.
- Sell junk at vendors.

### Gear
- Upgrade Advisor using your Pawn scales, or built-in stat weights per talent tree.
- Bind-on-Equip upgrades are checked for all your characters, and you can send them from the mailbox.

### Gold
- Farm: measured drop rates, kill speed and a "Safe" gold per hour ranking.
- Craft and Recipes: profit per recipe, and where to learn the recipes you don't know yet.
- Deals, vendor flips, 7-day trends and weekday patterns from your own auction house scans.
- Holdings: bags, bank, equipped, mail and auctions on every character.

### Community data
- Ships with drop rates, trainer and vendor recipes and reagent prices shared by players.
- Sharing is manual and anonymous: `/haul export`, then paste it on the upload page.

### Sharing and feedback
- Sharing is manual (addons can't reach the internet). The Share kills button, a footer count of kills you haven't shared and a chat reminder every 100 make it easy. The reminder can be turned off.
- `/haul feedback` (or Settings → Feedback) shows where to report bugs and suggest ideas.
