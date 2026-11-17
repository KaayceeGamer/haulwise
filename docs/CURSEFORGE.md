# Haulwise

**Haulwise shows what everything you own is worth, what you can safely throw away, which gear is an upgrade, and where to make gold. It works it out from your own play and from what every Haulwise player shares.**

Free and open source. No ads, no accounts, no donations.

---

## What you get

### 🪙 The HUD — always on screen until you close it
- Gold per hour this session
- Gold, bag value and your **total worth**. Hover for the full breakdown: vendor value (guaranteed), best value (auction house and disenchanting), bank, gold in the mail, all your characters, and your 10 most valuable items.
- **Cheapest to throw away**: drag the HUD taller to see more, and Make room deletes with one click.
- **Sell junk** at vendors
- Gear upgrades waiting for you or your alts

### 🎒 Bags that know what things are worth
Every item is valued at the highest of:
- **vendor** price
- **auction** price after the 5% cut. Freshness is shown by colour.
- expected **disenchant** value, if you or one of your characters can disenchant it

The tooltip shows the whole calculation.

**When your bags are full while looting**, Haulwise compares the loot with your cheapest item and offers a one-click swap. If the swap would lose you money, the popup turns red and says how much.

**Never offered for deletion:**
- crafting materials of any kind
- quest items
- tools
- ammo
- epics
- reagents your recipes use
- upgrades for you or your alts
- anything you mark to keep

### ⚔️ Upgrade Advisor, for you and your alts
- New gear is compared with what you wear, using **your Pawn scales** if Pawn is installed, or Haulwise's own stat weights per talent tree.
- Bind-on-Equip gear is checked for **all your characters**. At a mailbox, *Send to alts* lists it and attaches it with one click.

### 🐺 Farm: the best gold per hour for *your* character
Haulwise measures:
- **Real drop rates**: only looted or confirmed-empty corpses count.
- Coins, skinning and pickpocket
- How fast **you** kill each mob

Each mob is valued at your own auction house's prices. Rank by **Safe** gold/hour, so a lucky streak can't fool you.

### 🧵 Craft and Recipes
- **Craft**: every recipe you know, with reagent cost (auction house or vendor, whichever is cheaper), sale price, profit, margin and 7-day trend.
- **Recipes**: the ones you don't know yet, ranked by profit, with **where to get them** (trainer, vendor, drop, auction house) and how many crafts until each pays for itself.

### 📈 Deals and Market
- **Deals**: listings 30%+ under their usual price, and vendor flips (cheaper than what a vendor pays).
- **Market**: 7-day trends for what you farm, craft and use, with a tip for each: *Sell now*, *Hold* or *Stock up*. After two weeks of scans it also shows which weekday your auction house is cheapest.

### 📦 Holdings
What every character owns and where: bags, bank, equipped, mail and auctions, with values.

### 🌍 Community data
Every release includes data pooled from everyone who shares:
- drop rates
- trainer and vendor recipes
- vendor reagent prices

Share yours with `/haul export`, then paste it on the upload page (link at the bottom). It's anonymous, each player's weight is capped, and outliers are filtered out.

### 🎨 Your way
- Drag-to-resize windows
- Font and text size
- Background opacity
- Click any column title to sort

---

## Getting started (5 minutes)
1. Open each **profession window** once.
2. Visit a **trade goods vendor** once.
3. Press **Scan AH** at the auction house. Once a day is ideal.
4. **Log in on each character** once.
5. Open your **bank** and **mailbox** once.

Then just play. The in-game guide (`/haul guide`) explains everything.

## Commands
| | |
|---|---|
| `/haul` | open the window |
| `/haul hud` | show or hide the HUD |
| `/haul room` | make room in your bags |
| `/haul settings` | settings |
| `/haul guide` | the guide |
| `/haul export` / `import` | share data |
| `/haul reset` | reset window positions and sizes |

## Works with
- **Pawn**: Haulwise uses your Pawn scales.
- **Auctionator**: Haulwise uses its prices until you scan yourself.

## Good to know
- Deleting items can't be undone. If the game wants you to confirm a delete, the item stays on your cursor until you do.
- Drop rates are recorded only while you're solo, because group loot skews them. You can change this in Settings.
- Haulwise never buys, sells on the auction house, posts or sends mail for you. It only fills things in for you to confirm.
- Haulwise can't reach the internet. Everything it learns stays in your SavedVariables until you choose to export it. Shared data is anonymous: no character, account or realm names are kept.
- Auction house scans use the game's own full scan, which the game allows once every 15 minutes.

---

### Links
- Upload page and community data: https://kaayceegamer.github.io/haulwise/
- Source code and issues: https://github.com/KaayceeGamer/haulwise

*Haulwise is a fan project and isn't affiliated with Blizzard Entertainment.*
