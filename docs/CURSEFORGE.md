**Haulwise shows what everything you own is worth, what you can safely throw away, which gear is an upgrade, and where to make gold. It works it out from your own play and from what every Haulwise player shares.**

Made for **WoW Forever**. Free and open source. No ads, no accounts, no donations. In English, German and French.

**New in 0.18.0:** **pause** your session (from the session box or the HUD), dungeons get a session of their own, and Farm keeps a history of every farm run under **Sessions**; **Vendor flips** on the Craft tab: crafts a vendor buys for more than the mats cost, with the most you can pay for the main mat; and **TSM prices** when TradeSkillMaster is installed.

---

## What you get

Open Haulwise with the **gold bag button on your minimap**, the **Open Haulwise** button on the HUD, or `/haul`.

### 💰 The HUD — always on screen until you close it
- Gold per hour this session, with **pause** and **new session** buttons
- Gold, bag value and your **total worth**. Hover for the full breakdown: vendor value (guaranteed), best value (auction house and disenchanting), bank, gold in the mail, all your characters, and your 10 most valuable items.
- **Cheapest to throw away**: drag the HUD taller to see more, and Make room deletes with one click.
- **Sell junk** at vendors
- Gear upgrades waiting for you or your alts

### 🎒 Bags that know what things are worth
Every item is valued at the highest of:
- **vendor** price
- **auction** price after the 5% cut. Freshness is shown by colour.
- expected **disenchant** value, if you or one of your characters can disenchant it

The tooltip shows the whole calculation, and **Best move** says what gets the most for each item: sell on the AH, sell to a vendor, disenchant it, or send it to an alt who can. When disenchanting wins, a **Disenchant** button does the best one for you.

**Leveling Enchanting?** Turn on **Disenchant for mats** (Options on the Bags tab) and gear you can disenchant yourself is marked to disenchant even when selling pays a bit more. Haulwise shows what that costs you, picks the cheapest one first, and leaves alone anything that sells for more than three times its mats.

**Gear tooltips** show the best move, what the item disenchants into at your auction house prices, and what **your own disenchants** of it (or items like it) actually gave.

**When your bags are full while looting**, Haulwise compares the loot with your cheapest item and offers a one-click swap. If the swap would lose you money, the popup turns red and says how much.

**Never offered for deletion:**
- crafting materials of any kind
- quest items
- things you use again and again: a sleeping bag, toys, mounts and pets
- tools
- ammo
- epics
- reagents your recipes use
- upgrades for you or your alts
- items a quest in your log needs
- anything you mark to keep

### ⚔️ Upgrade Advisor, for you and your alts
- New gear is compared with what you wear, using **your Pawn scales** if Pawn is installed, or Haulwise's own stat weights per talent tree.
- Only gear your class can wear is suggested, and only once you can put it on within 3 levels (marked *at level 40* until then). No mail armor for a level 5 shaman.
- Bind-on-Equip gear is checked for **all your characters**. At a mailbox, *Send to alts* lists it and attaches it with one click.
- **Upgrades on the AH**: every auction house scan checks all gear for sale against you and your alts (thousands of listings, each item once at its cheapest), ranked by how much upgrade each gold buys. Set a max price, and at the auction house click one to buy that exact listing (same suffix) after you confirm the price.
- **Quest reward pick**: when a quest lets you choose, Haulwise marks the best reward with a gold frame and a green tick and says why in chat: a profession tool you're missing (like a Mining Pick), your biggest upgrade, or else the one worth the most.

### 🐺 Farm: the best gold per hour for *your* character
Haulwise measures:
- **Real drop rates**: only looted or confirmed-empty corpses count.
- Coins, skinning and pickpocket
- How fast **you** kill each mob

Each mob is shown with its own portrait (WoW Forever's new mobs too) and valued at your own auction house's prices. Rank by **Safe** gold/hour, so a lucky streak can't fool you. Your farm runs are kept under **Sessions**: where, how long, gold per hour and what you killed. Pause a session for a mailbox run, and dungeons get their own. Switch to **Zones** to see where to go, or set **Zone** to *Where you are* to see what's worth killing right here.

Every number says **how sure** it is: what it's based on ("34 kills: 12 yours, 22 from other players") and a word from *rough guess* to *solid*.

**Mobs nobody has farmed yet** are ranked too, from estimated drop rates in Classic's loot tables. They're marked *est.* and *~*, and real kills (yours and shared) take over as they come in. Mob tooltips show the estimated gold per hour as well. Under **Safe** an estimate counts for less, so mobs with real kills come first. The **Show** menu on the Farm tab picks all mobs, only farmed ones, or only estimates.

### 🧵 Craft and Recipes
- **Craft**: every recipe you know, with reagent cost (auction house or vendor, whichever is cheaper), sale price, profit, margin, **how many sell per day** and 7-day trend.
- **Shopping list**: click recipes to add them, and see every reagent you need, what's already in your bags and bank, where the rest is cheapest, and what the whole batch earns.
  - **Buy** on a reagent finds the cheapest listings (skipping your own) and shows what the amount you need costs now. The next click asks you to confirm the total and buys exactly that many. Nothing is bought without your click.
  - Says when a reagent is **dear today** (30%+ over its usual price), and which **alt** already has it, so you send it over instead of buying it.
  - Vendor reagents get an arrow to the nearest vendor that sells them.
- **Craft queue**: the shopping list is also your queue. Open a profession and the queued crafts show beside it with how many you can make; click one and Haulwise picks the recipe and count, you press Create, and finished crafts come off the queue. **Queue best 5** fills it with your most profitable crafts, as many as sell in about two days.
- **Skill up**: the cheapest recipes to raise your profession right now, by what each skill point costs.
- **Vendor flips**: crafts a vendor buys for more than their mats cost on the AH, for you and your alts, with the most you can pay for the main mat (*Buy below*).
- **Recipes**: the ones you don't know yet, ranked by profit, with **where to get them** (trainer, vendor, drop, quest, auction house; how every Forever recipe is learned and its exact skill come from Warcraft Wiki) and how many crafts until each pays for itself. Results nobody sells on the AH (bound gear) say *no AH price* instead of a made-up loss. **Click one for a waypoint** to the vendor that sells it.
- **Find trainer**: a waypoint to the nearest trainer of your faction that teaches your next rank (Journeyman, Expert, Artisan). Also `/haul trainer tailoring`.
- **Enchant requests** (an estimate): in a city, Haulwise counts what people ask enchanters for in trade chat, per enchant, how often per hour you're listening, the gold they name and whether you know it. Many ask by whisper and others answer first, so it's marked as an estimate everywhere. Nothing about who asked is saved.
- Show **one profession at a time** with the Profession menu.

### 📈 Deals and Market
- **Deals**: listings 30%+ under their usual price, and vendor flips (cheaper than what a vendor pays). Never more than sells in about three days, and nothing nobody has been buying.
- **Market**: 7-day trends for what you farm, craft and use, with a tip for each: *Sell now*, *Hold* or *Stock up*. After two weeks of scans it also shows which weekday your auction house is cheapest.
- **Your sales**: open a mailbox and Haulwise logs every auction sale from the invoices: what you earned today, this week and this month, per item, after the AH cut.
- **How fast it sells**: from your scans, Haulwise sees which cheap listings disappear. Tooltips, the sell helper and the Craft tab show *sells ~12 a day*.

### 🏷️ Selling help at the auction house
When you put an item up for sale, Haulwise suggests a price that undercuts the real market (not the troll listings), says how fast it sells, and warns you when a vendor would pay more. **Use price** fills it in; you press Post.

**Your auctions**: a panel beside the auction house lists what you have up for sale, undercut ones first. Click one to check the newest price; undercut ones get a Cancel button, and once the item is back in your bags a Post button puts it up again at the sell helper's price (you confirm quantity, price and deposit first).

### 🔎 What is this item for?
Item tooltips show:
- the **quests that need it**, yours in the log first (done and other-faction quests are left out), and who to bring quest items to
- the **crafts that use it**: your recipes, your alts', and recipes other players shared
- **who sells it** and **which mobs drop it**

### 📦 Supply crates and writs
- **Waylaid Crates**: the tooltip prices every way to fill the crate (the materials you have at what they'd sell for, the rest at the cheapest place to buy), marks the cheapest, and says what one Merchant's Favor costs.
- **Sealed crates** say how much Merchant's Favor they give.
- **Craftsman's Writs** say what the ordered item costs to buy or to craft yourself.

### 📦 Holdings and mail
- What every character owns and where: bags, bank, equipped, mail and auctions, with values.
- **Mats to crafters**: at a mailbox, one click sends the crafting mats in your bags to the alt whose recipes use them.

### 🌍 Community data
Every release includes data pooled from everyone who shares:
- drop rates
- the recipes players know, and what they're made from
- trainer and vendor recipes, and where trainers and vendors stand
- vendor reagent prices
- auction house prices: the median over all realms comes with every release as a rough guess until you scan

Zones are shared by map number, so a German, French and English player's Stranglethorn Vale add up. Your own upload is taken out of the pool again, so your kills are never counted twice.

**Sharing is manual, and that's on purpose.** WoW addons can't reach the internet, so nothing ever leaves your PC by itself. To share, press **Share data** in the Haulwise window, press Ctrl+C, and paste it on the Haulwise website (link at the bottom). It takes about 10 seconds, and the site shares it as soon as you paste. The button lights up when you have 100+ kills to share, and the bottom line shows what other players have shared about the zone you're in.

**Prices for your realm**: every realm has its own auction house, so shared prices are kept per realm and faction. On the website, pick yours under *Prices for your realm*, copy, and `/haul import`. Haulwise uses them for items your own scan doesn't have and when your scan is more than 3 days old. Your own scan always comes first.

Shared data is anonymous, each player's weight is capped, and outliers are filtered out.

### 🎨 Your way
- Drag-to-resize windows
- Font and text size
- Background opacity
- Click any column title to sort
- **Minimap button** (drag it anywhere around the minimap), plus a launcher for Titan Panel, ElvUI and other data broker displays
- **English, German and French**: follows your game's language, or pick one in Settings

---

## Getting started (5 minutes)
1. Open each **profession window** once.
2. Visit a **trade goods vendor** once.
3. Press **Scan AH** at the auction house. Once a day is ideal.
4. **Log in on each character** once.
5. Open your **bank** and **mailbox** once.

Then just play. The in-game guide (the **i** button, or `/haul guide`) explains everything.

## Commands
| Command | What it does |
|---|---|
| `/haul` | open the window |
| `/haul hud` | show or hide the HUD |
| `/haul minimap` | show or hide the minimap button |
| `/haul lang deDE` | language: `auto`, `enUS`, `deDE` or `frFR` (then `/reload`) |
| `/haul trainer [profession]` | waypoint to the nearest trainer |
| `/haul room` | make room in your bags |
| `/haul settings` | settings |
| `/haul guide` | the guide |
| `/haul start` | the start card again |
| `/haul export` / `import` | share your data / load community data |
| `/haul reset` | reset window positions and sizes |
| `/haul perf` | memory and how long each list takes |
| `/haul feedback` | report a bug or suggest an idea |

## Works with
- **Pawn**: Haulwise uses your Pawn scales.
- **TradeSkillMaster**: Haulwise uses TSM's market value when your own scan is more than 3 days old.
- **Auctionator**: Haulwise uses its prices until you scan yourself.
- **TomTom**: waypoints use TomTom's arrow when it's installed; otherwise the game's own map pin.
- **QuestieDB**: not needed. Haulwise Data (included) already has its trainers, vendors, quests and drop sources. If you have QuestieDB installed anyway, Haulwise also uses it to find NPCs that Haulwise Data doesn't cover.

## Good to know
- Deleting items can't be undone. If the game wants you to confirm a delete, the item stays on your cursor until you do.
- Drop rates are recorded only while you're solo, because group loot skews them. You can change this in Settings.
- Haulwise never buys, posts auctions or sends mail for you. It only fills in prices, recipients and attachments for you to confirm.
- Haulwise can't reach the internet. Everything it learns stays in your SavedVariables until you choose to export it. Shared data is anonymous: no character, account or realm names are kept.
- Auction house scans use the game's own full scan, which the game allows once every 15 minutes.

---

### Feedback
Found a bug or have an idea? Leave a comment here, or open an issue on GitHub (link below). `/haul feedback` in game shows the links, and the last errors Haulwise noted, ready to paste into your report.

### Links
- Upload page and community data: https://kaayceegamer.github.io/haulwise/
- Source code and issues: https://github.com/KaayceeGamer/haulwise

### Credits
Trainer and recipe vendor positions, the quests that need each item, and where items drop and who sells them in **Haulwise Data** (included in the download as its own addon folder) come from the Forever data of [QuestieDB](https://github.com/Questie/QuestieDB), licensed under GPLv3. Thanks to the Questie team and everyone who contributed.

The estimated drop rates for mobs nobody has farmed yet come from the [CMaNGOS Classic database](https://github.com/cmangos/classic-db), licensed under GPLv3. Thanks to the CMaNGOS team.

How each recipe is learned (trainer, vendor, drop, quest) comes from [Warcraft Wiki](https://warcraft.wiki.gg), licensed under CC BY-SA 4.0. Thanks to the wiki's editors.

Haulwise Data is GPLv3; Haulwise itself is MIT. Neither is affiliated with the Questie or CMaNGOS teams or Warcraft Wiki.

*Haulwise is a fan project and isn't affiliated with Blizzard Entertainment.*
