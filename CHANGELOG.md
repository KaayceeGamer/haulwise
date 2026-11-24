# Changelog

## 0.19.1
- **Import without freezing**: pasting community data (hundreds of kilobytes) froze the game for seconds while the text box laid it all out. The box now shows only the start of what you paste and collects the rest as it arrives; Import then takes a moment instead.

## 0.19.0
- **Clean-up at the bank**: when you open the bank, a list shows what's safe to sell from your bags and bank (the Bags tab's rules: quest items, upgrades, things you use, epics and crafting materials Haulwise can't place are never offered), with what each is worth and where to sell it. It also shows which reagents in your bags and bank to keep (a recipe you or an alt know still gives skill with them, they make a mat for such a recipe, like Silk Cloth for the bolts a Crimson Silk Vest needs, crafting them makes a profit, or you can learn a recipe for them within 25 points) and which you're done with (every recipe of yours that uses them has gone grey), with what they're worth. On top: what you can craft for skill right now from what you have, and about how many points it gives. Item tooltips say the same in one line. Also `/haul cleanup`; turn it off in Settings > Bags and loot.
- **Enchants in Recipes and Skill up**: recipes that make no item (enchants like *Enchant Weapon - Revelation*) are now read from your Enchanting window. Ones you don't know show in Recipes with where to get them; ones you know show in Skill up with the cost per skill point and can go on the shopping list.
- **One character, one record**: the game sometimes gives an empty realm name, which saved a character twice (recipes in one record, bags in the other, and yourself listed as an alt). Haulwise now uses the realm it saw last, and folds the two records back into one: per profession the newer reading wins.
- **Recipes filed under the right profession**: the game can list other professions' recipes while one window is open, so Tailoring recipes could end up under Cooking (and Skill up for Tailoring showed nothing). Each recipe now goes under its own profession; open each profession window once to fix what's saved.
- **Farm: the button and the list agree**: picking *Rank by* undoes a column you clicked, and *Best farm right now* follows the ranking and skips mobs with only 1 or 2 kills when better-known ones are there.
- **No more "?" mobs**: a mob someone shared without ever seeing its name (inside dungeons the game hides names) is no longer named "?".

## 0.18.2
- **Mob names in your language**: a mob you haven't seen yourself is named from Haulwise Data before someone else's shared data, so a German player's share no longer turns English names German.
- **Bags: one row per item**: stacks of the same item are added up in one row (gear stays one per row, since each piece can differ).
- **Kills in a group count**: a corpse you loot shows everything it dropped, so in a group it now counts for drop rates, your session's kills and its gold (your share of the coins). Only what a group can't tell stays solo: kill speed (a group kills faster) and corpses others looted (they'd look empty). *Record in groups* in Settings counts those too.

## 0.18.1
- **More from TSM**: with TradeSkillMaster and its desktop app, Haulwise now fills in what your own scans can't tell yet. *Sells/day* (Craft, tooltips, the sell helper) uses TSM's sold per day for the region where you haven't scanned enough. Market shows trends right away (TSM's market value against its 60-day price, marked *TSM*) until your own scans cover a week. Deals and the usual price use TSM's market value before you have 3 days of scans.
- **Market: what to buy and sell now**: every item you have, farm, gather, craft or use, with its price now against its usual price (a week of your scans, or TSM's 60-day price), how many you have, how fast it sells, and a tip: *Sell now* (dearer than usual, and you have some), *Farm now*, *Craft now*, *Stock up* (a reagent cheaper than usual), *Buy*, *Hold* or *Vendor it*. The top line adds up what selling now would bring over the usual price. *Show* picks everything, only what to sell, or only what to buy. Grey and soulbound items are left out.
- **Deals you can trust**: a resale deal is valued at what the item really sells for (TSM's region sale average when that's lower than its market value), counted only for as many as sell in about 3 days, and left out when it would take more than two weeks to sell. TSM's value isn't used for gear with random stats ("of the Monkey" and "of the Owl" get one price there), and rare items that look too good on TSM's numbers alone are left out. A new *Sells in* column says how long the units take to sell.
- **Disenchant flips**: Deals finds gear listed for less than its disenchant mats are worth (counted at 90% for bad luck), when you or an alt can disenchant it.
- **Craft mats under the limit**: a mat listed below what a vendor flip can pay for it shows up in Deals as *Craft + vendor*, with the craft to make.
- **Craft: up to per day**: a new column with the profit per craft times how many sell a day, and Best profit is sorted by it, so a small profit that sells fast beats a big one nobody buys.
- **Lighter**: the window keeps only the list on screen between redraws, and Market checks only items worth checking.
- **Settings: Font and Language are menus** now, instead of buttons you click through.
- `/haul tsm` shows what TSM returns for a few common items next to Haulwise's own scan.

## 0.18.0
- **Pause your session**: click the session box at the top (or the session line on the HUD) to pause. While paused the clock stops and loot stays out of your gold per hour, so a mailbox run or a vendor trip doesn't drag it down. What you loot still counts for drop rates.
- **Session tools on the HUD**: pause / resume and *New session* buttons on the session line, which also shows how many minutes the session has run.
- **Dungeons get their own session**: entering a dungeon or raid sets your open-world session aside; leaving saves the dungeon run and picks the open-world session up where it was.
- **Saved sessions**: Farm has a new view, *Sessions*: every farm run with where, who, how long, what it earned, gold per hour and the mobs you killed most. A session is saved when you start a new one, leave a dungeon, or come back after 30 minutes away; a /reload carries on the same session. Right-click one to delete it.
- **Vendor flips**: Craft has a new view for crafts a vendor buys for more than their mats cost on the AH (no AH cut, no waiting). For every recipe you and your alts know: what a vendor pays, what the mats cost now, the profit, and the most you can pay for the main mat (*Buy below*), so you can watch for cheap listings. A mat you can craft yourself counts at the cheaper of buying and crafting it. Mats whose limit is far under today's price (less than 60%) are left out.
- **TSM prices**: with TradeSkillMaster installed, Haulwise uses its market value (from the TSM desktop app) when your own scan is more than 3 days old. Turn it off in Settings.

## 0.17.0
- **Farm: estimates and real kills apart**: a new *Show* menu picks all mobs, only farmed ones (real kills, yours or shared) or only estimates. Under *Safe*, a mob nobody has killed counts its loot-table items for half, so mobs with real kills aren't buried under guesses. When the top row is a guess, the hero line also names the best farmed mob. A picked zone (*Where you are*) shows its low mobs too, instead of an empty list.
- **Settings window**: sections on the left (Look, Bags and loot, Gear, Farming, Auction house and mail, Tooltips), and every switch says what it does right under it, no hovering needed. *Use Pawn* is now in the Weights menu on the Gear tab.
- **Scan AH** says how long the game's wait has left ("Scan AH in 12 min").
- **Smoother with the window open**: Farm, Zones, Deals and Market keep their lists for a few seconds between redraws (loot, bags and kills redraw often), and work them out again at once when you change a setting, menu or zone.
- **New icon**: the bag of gold is now on the minimap button, the window, the HUD and the addon list.
- **Portraits for WoW Forever's new mobs**: mobs Haulwise Data doesn't know (like the ones in Riverglades) get their real portrait from the game by their NPC number, in the background, instead of the icon of an item they drop. Until the game has the mob (after you've seen it), they show a question mark.
- **Mob tooltips from the first kill**: the Haulwise line (gold per hour, per kill) showed only after 10 kills, so new WoW Forever mobs said nothing. It shows from the first kill now, marked *rough guess* until there are more.
- **/haul perf**: shows how much memory Haulwise uses and how long each list takes to work out, slowest first, to find what stutters.

## 0.16.1
- **Clearer controls on every tab**: the row under the tabs no longer mixes everything as checkboxes. Small tabs on the left switch what a list shows (Farm: Mobs | Zones, Craft: Best profit | Skill up | Enchant requests, Gear: Your gear | On the AH, Market: Prices | Your sales). Menus pick one of a few choices (Profession, Rank by, Zone, Weights, Min profit, Max price, Character, Where). One *Options* menu holds the switches that change what a list counts. Buttons that do something (Find trainer, Queue best 5, Shopping list, Make room) sit on the right. Settings that change what Haulwise does elsewhere (upgrade popups, the mailbox, trade chat) are in the settings window.
- **Enchant requests (an estimate)**: Craft has a new view, *Enchant requests*. In a city, Haulwise reads trade chat for messages asking for an enchanter ("LF crusader", "WTB +7 agi boots, tip 5g"), counts them per enchant and times how long you listened, so you see the requests per hour, the gold people name (middle value), a rough gold per hour, and whether one of your characters knows it. Everything is marked as an estimate: many ask by whisper, others answer first, and the words in chat are guessed at. Nothing about who asked is saved. Turn it off with *Listen to trade chat*.
- **Fix: stutter on the Recipes tab**: items the game never sends (removed from the game) kept the big window redrawing every second while Recipes was open. Each item is now asked for once, recipe rows are kept between redraws, and the mob data is built once per redraw instead of once per recipe.
- **Recipes: which vendor**: Haulwise Data now links 759 recipes to their pattern, plan or formula item (from QuestieDB), so "how to get it" names the vendors that sell it and the mobs that drop it, and a click sets a waypoint, also for recipes whose item you've never seen. For the new Forever recipes nobody has mapped yet, the tooltip says how they get filled in: by Haulwise players opening those vendors and sharing.

## 0.16.0
- **Kills per hour for every mob**: mobs nobody has timed no longer all count as 40 kills an hour. Haulwise Data now has an estimate per mob from how close together it stands (its spawns), its level and how many there are (55-90 an hour for most), scaled by your own kills-per-hour setting. Real kills still replace it.
- **Buy gear upgrades from the Gear tab**: at the auction house, click an upgrade on *On the AH* and Haulwise finds that exact listing (same "of the Owl" suffix, not a cheaper one with other stats) and asks you to confirm the price. Bought upgrades leave the list.
- **Post cancelled auctions again**: after Cancel in *Your auctions*, the item waits in the panel ("in your mailbox" until it's back), then Post puts it up again at the price the sell helper picks, after you confirm quantity, price and deposit.
- **Less memory**: no price history or sell speed for gear (each piece is its own listing, so trends meant little; it was 62% of both), 21 days of history instead of 28, and the bundled community text is freed once read.
- **Recipes**: "how to get it" also lists where the pattern drops (and world drops) from Haulwise Data, and the tooltip no longer promises a trainer waypoint for a pattern you can only buy or find: a click searches the AH for it.
- **How to learn a recipe, from Warcraft Wiki**: Haulwise Data now knows for 2,300+ Forever recipes whether they come from a trainer, a vendor, a drop or a quest, and the exact skill they need (no more "~" guesses). Recipes shows it as "Vendor (wiki)" when you haven't seen the source yourself, and a click takes you to a trainer only when the recipe is taught by one. Thanks to the Warcraft Wiki editors (CC BY-SA 4.0).
- **Website**: lists the realms that share prices, with how many players and how fresh.

## 0.15.5
- **Farm**: mobs show their own portrait, drawn by the game from the mob's model, instead of the icon of their main loot. Where the game can't draw one, an icon for what the mob is (a wolf, a spider, a humanoid, an elemental...). From the CMaNGOS creature data in Haulwise Data.

## 0.15.4
- **Gear on the AH**: after a /reload or login, upgrades whose items the game hadn't loaded yet were dropped from the list (15 became 2). They stay now, and are checked again once loaded.
- **Scan AH** lights up again by itself when the game's 15-minute wait is over; it stayed grey until something else redrew the window.

## 0.15.3
- **Fix**: Lua error on the Gear tab with Pawn in use (Gear.lua:67, "attempt to call a nil value").
- **Recipes**: a recipe whose result nobody sells on your AH (bound gear like Embroidered Belt of the Archmage) shows "no AH price" instead of a loss of hundreds of gold, and is ranked below recipes with a real profit. Its tooltip still says what the reagents cost.
- **Recipes**: skill "?" for items the game hadn't loaded yet: Haulwise now asks for them and fills in the skill (bags estimated from their item level), so the "far above my skill" filter works on them too.
- **Gear on the AH**: most gear on the auction house isn't in the game's item cache, and gear without stats can't be compared. Haulwise gave up after one retry; now it keeps asking every 3 seconds while more arrives (up to 30 seconds), so far more listings get checked (a level 39 mage went from 0 to 15+ upgrades). The empty page says how many were checked.
- **Gear on the AH**: an item listed several times shows once, at its cheapest.
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
