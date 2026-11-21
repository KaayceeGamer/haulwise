# Changelog

## 0.15.3
- **Fix**: Lua error on the Gear tab with Pawn in use (Gear.lua:67, "attempt to call a nil value").
- The session box is wider, so "loot + sales" no longer runs into the THIS SESSION label.

## 0.15.2
- **Gear**: no more suggestions you can't wear for ages. A level 5 shaman was told to upgrade to mail armor (shamans wear mail from level 40). Gear you can wear within 3 levels still shows ("at level 40" for a level 38); anything further off isn't suggested. Thanks for the report!

## 0.15.1
- **Session gold per hour counts your AH sales**: sales you collect from the mailbox are added to the session, next to the loot from kills. Hover the session box for the split: loot, sales, and how much the gold in your bags changed (which also counts vendors, quests and spending).
- Shopping list: shorter bottom line for tools, so it fits.
- **Fix**: "Haulwise has been blocked from an action" after buying from the shopping list (on Escape or the game menu). The confirm box is now Haulwise's own instead of the game's popup, which it tainted. If the game ever blocks Haulwise again, /haul feedback says from what.

## 0.15.0
- **Buy from the shopping list**: every reagent you still need has a Buy button. The first click finds the cheapest listings and shows what the amount you need costs right now; the next asks you to confirm the total and buys exactly that many. Your own listings are skipped, and nothing is bought without your click in the confirm box.
- **Dear today**: a reagent that's 30%+ over its usual price says so, in the list and in the confirm box. Wait a day if it isn't urgent.
- **Your alts first**: when an alt has a reagent you need, the list names them ("Bankalt has 2"), so you don't buy what you already own.
- **Vendor reagents**: the button puts an arrow on the nearest vendor that sells it.
- **Tools and skill-ups**: when nothing on the list sells on the AH (like a Runed Truesilver Rod), it shows what the reagents cost instead of a "loss".

## 0.14.2 (part of 0.15.0)
- **Market**: the countdown to trends was wrong ("4 of 4 days" and still nothing). Trends compare the last 3 days with the week before, so they need a scan from at least 6 days ago; the tab now says how old your oldest scan is and how many days are left.

## 0.14.1
- **Login message about sharing**: once a day, a few seconds after you log in, one line in chat if you have something worth sharing (25+ new kills, or an AH scan you haven't shared), with how much the others have shared so far. Turned off together with the share reminder in /haul settings.
- **Farm**: mobs only known from the estimates show their zone instead of ?, and with *Hide mobs above my level* on, ones nobody has killed that are more than 10 levels below you are left out (no more level 1 kobolds on top for a level 38).
- **This zone only** says what it hides: when only estimates are left in your zone, the banner tells you how many mobs with real kills are in other zones.
- **Where prices come from**: the bottom line says if values come from your scan (orange when it's over 3 days old), plus prices shared for your realm, or from all realms as a rough guess until you scan.
- **Scroll bar**: drag it, or click it to jump. It widens when the mouse is on it.
- Zone names that weren't loaded yet are looked up again instead of showing as a number.

## 0.14.0
- **Shared auction house prices**: Share data now also takes the prices from your last AH scan (if it's at most 3 days old) for the items Haulwise uses, about 15-30 KB, with the realm and faction you scanned on. On the website, pick your realm under **Prices for your realm**, copy, and `/haul import`: Haulwise then has prices for items your own scan doesn't, and when your scan is more than 3 days old. Your own scan always comes first.
- **Prices from day one**: every release brings the median over all realms, so bags and Farm have values before your first scan. Tooltips say when a price is a rough guess from all realms, or shared for your realm.

## 0.13.1 (not released on its own, part of 0.14.0)
- **Things you use are kept**: items with a Use: effect that you use again and again (a sleeping bag, a toy, a mount or pet item, a single reusable consumable) are never offered to sell or throw away, however little they're worth. Soulbound green-or-better items that aren't gear are kept too. Stacks of food and drink can still go.
- **Throwing something away** now says in chat what went, and how to always keep it.
- **Bags full popup**: no more error when going through the items to swap.

## 0.13.0
- **Estimates for every mob**: Farm now also ranks mobs nobody has farmed yet, from Classic's loot tables (the open-source CMaNGOS Classic DB, in Haulwise Data). They're marked "est." and "~", and real kills, yours and shared, take over as they come in. Turn them off with **Estimates** on the Farm tab.
- **Quest items to deliver** say who to bring them to, and a quest offered by several quest givers shows once.
- **Craft queue**: a close button, Clear, and right-click a craft to take it off.
- **Mob tooltips** show gold per hour for every mob: an estimate (~) for ones nobody has farmed yet, and how sure the number is when there are few kills.

## 0.12.0
- **What an item is for**: item tooltips show the quests that need it (yours in the log first, done and other-faction quests left out), the crafts that use it (your recipes, your alts', and recipes other players shared), who sells it and which mobs drop it. Turn it off in Settings → Used for in tooltips.
- **Bags keep quest items**: an item a quest in your log needs is never offered to sell or throw away.
- **Shared recipes**: Share data now includes the recipes your characters know and their reagents, so everyone's tooltips know what an item is used for, even recipes none of their characters have.
- **Your sales**: an invoice that says 0 sold counts as one.
- **Craft queue**: sits a little away from the profession window, clear of other addons' side buttons.

## 0.11.0
- **Zones in every language**: kills are recorded under the zone's map number instead of its name, so a German and an English player's Stranglethorn Vale are the same zone in the shared data. Names show in your own language; older data moves over by itself.
- **Your kills aren't counted twice**: the community data includes what you shared yourself. Haulwise now takes your own upload out of it, so the numbers aren't skewed towards your luck.
- **How sure is it**: farm tooltips say what a number is based on ("34 kills: 12 yours, 22 from other players") and how sure it is, from rough guess to solid. Gold/h with under 10 kills gets a ~.
- **What sharing gives**: the bottom line shows what other players have shared about the zone you're in, and the Share window shows what you bring and what the pool already has.
- **Easier sharing on the website**: it remembers the consent tick, shares as soon as you paste, and shows a clear thank-you with a button for the newest community data.
- **Easier start**: point at a tab to see what it's for. New players get a Start here card with three steps (/haul start shows it again).
- **Market**: says how many days of scans are left before trends show.
- **Waylaid Crates**: the Favor line now shows for crates like "Flowering Expert Herbs".
- **Your sales**: a sale is no longer logged twice when the game fills in the count late, and identical sales are each counted.

## 0.10.0
- **Your auctions**: at the auction house a panel lists what you have up for sale, undercut ones first, with the cheaper price. Click one to search for the newest listings; undercut ones get a Cancel button so you can post them again at the sell helper's price.
- **Supply crates and writs**: a Waylaid Crate's tooltip prices every way to fill it (the materials you have at what they'd sell for, the rest at the cheapest place to buy), marks the cheapest, and says what one Merchant's Favor costs. Sealed crates say how much Favor they give, and Craftsman's Writs what the ordered item costs to buy or craft. English item names only for now.
- **Craft queue**: the shopping list is now also a craft queue. Open a profession and the queued crafts show beside it with how many you can make; click one and Haulwise picks the recipe and count, you press Create, and finished crafts come off the queue. **Queue best 5** on the Craft tab fills it with your most profitable crafts, as many as sell in about 2 days.
- **Sharing**: the Share data button lights up with your count once you have 100+ kills to share, and the reminder says plainly what gets shared (game stats only, no names, only what you paste).

## 0.9.0
- **Demand**: Haulwise now sees how fast things sell. When the cheapest listings from one scan are gone in the next, they sold, so after a few scans you see "sells ~12 a day" in item tooltips, in the sell helper and in a new Sells/day column on the Craft tab. Deals no longer tell you to buy more than sells in about 3 days, and leave out items nobody has bought in days.
- **Your sales**: open a mailbox and Haulwise logs every auction sale from the invoices. Market → Your sales shows what you earned today, this week and this month, per item, after the AH cut.
- **With TomTom**: the waypoint no longer disappears 10 yards before the NPC. It goes when you talk to them, and a new Haulwise waypoint replaces the old one instead of piling up.
- **Quest rewards**: a profession tool you need and don't have (Mining Pick, Skinning Knife, Blacksmith Hammer, Arclight Spanner) is now the Haulwise pick, and the pick is much easier to see: thick gold frame, a green tick, a slow pulse and its name after "Choose your reward:".

## 0.8.5
- **Fresher community data**: the pool is rebuilt every hour (was nightly), and Haulwise gets the newest data through CurseForge every day it has changed (was weekly).

## 0.8.4
- **Shared trainer and vendor positions**: *Share data* now includes where the trainers and vendors you opened stand, and the community data brings back everyone else's. Find trainer and recipe waypoints use them, so NPCs that moved in WoW Forever are right for everyone once one player has been there.
- Imports skip record types from newer Haulwise versions instead of failing.

## 0.8.3
- **The arrow stays until you get there**: it no longer disappears 8 yards out (positions can be a few yards off). Close by it says "you're there, look around"; it goes away when you talk to the trainer or vendor, or when you right-click it.
- Under the arrow: the direction (north-east...), and the target's and your own coordinates. Its tooltip explains that it points in a straight line through walls and floors. Click it to open the world map.

## 0.8.2
- **Deals** count on reselling at most 200 of anything, so 13,000 cheap arrows no longer top the list.
- **Price help when selling** follows the live market: 1 copper under the cheapest listing when plenty is listed there, and under the main market when only a few cheap ones sit far below it. Before, a deep market just under an old "usual price" got the usual price, which wouldn't sell.
- **The arrow points the right way**: it was mirrored, pointing a little right when the target was a little left. It now measures which way east and south lie on your map instead of assuming it.
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
