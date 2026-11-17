# Haulwise

Your gold, bags and gear in one place, for WoW Forever. Type `/haul` (or `/cof`) to open it, and `/haul hud` for the HUD.

## The HUD

A small box that stays on screen until you close it. It shows:
- your gold per hour this session
- free bag slots and what your bags are worth
- the cheapest thing you could throw away, with a **Make room** button
- any gear upgrades waiting
- **Sell junk** when you're at a vendor

Drag it to move it, lock it with the padlock, and reopen it with `/haul hud`. The main window only closes with its X. It stays open through Escape and reloads.

## Bags, swaps and Make room

Every item in your bags is valued at the highest of:
- **vendor** price
- **auction** price after the 5% cut (only if the price is under 14 days old; green, orange or red by age)
- **disenchant** value: the expected dust, essence and shards at your AH's prices, if you or one of your characters has the Enchanting skill for it

Each value shows its source (V, AH or DE), and the tooltip shows the whole calculation.

- **Bags full while looting:** Haulwise compares the loot with the cheapest item in your bags and offers a one-click swap. Quest items, upgrades and reagents you use get a coloured popup, even when they're worth less. If the swap would lose you money, the popup is red and says how much.
- **"Inventory is full"** anywhere else (crafting, quest rewards, buying): Make room offers the cheapest items, one click each.
- **Never offered:** crafting materials of any kind (dust, essences, shards, cloth, leather, ore, herbs, gems, recipes), quest items, tools (hearthstone, skinning knife, mining pick, rods, fishing poles), ammo, items in special bags, epics, reagents your professions use, gear upgrades for you or your alts, and anything you shift-click in the Bags tab to keep.

## Gear: the Upgrade Advisor

Every piece of gear you pick up is scored and compared with what you wear. **With Pawn installed, Haulwise uses Pawn's stat weights**: the Pawn scales you have switched on for each character. Without Pawn, or if you turn it off in Settings, Haulwise uses its own weights per talent tree. The button in the Gear tab switches between them. If it's an upgrade, a popup shows the stat changes with **Equip**, **Later** and **Ignore**.

Bind-on-Equip gear is also checked against your other characters' gear (same realm and faction). At a mailbox, **Send to alts** lists those items: click one and Haulwise fills in the name and attaches it. It never presses Send.

## Holdings

Shows what all your characters own and where: bags, bank, equipped, mail and auctions, with values, gold and gold waiting in the mail. Each character is read when you log in on it. Bank, mail and auctions are read when you open them.

Free and open source. No ads, no donations, no accounts.

Free and open source. No ads, no donations, no accounts.

## Community data

Every release includes **community drop rates**, pooled from everyone who chooses to share. To add yours:
1. Press **Share kills** in the Haulwise window, or type `/haul export`.
2. Paste it on the Haulwise site.

Sharing is anonymous: no character names, no IPs. Your newest upload replaces your old one, so nothing is counted twice. Each player's weight per mob is capped, and uploads that don't match everyone else's drop rates are left out, so one player can't skew the numbers.

The community data is rebuilt every night. A new release ships each week. You can also get the latest data from the site and paste it in with `/haul import`.

## Gold making tabs

**Farm** shows which mobs give *you* the most gold per hour. Drop rates come from your own kills, prices from your own auction house, and kill speed is timed from how fast you actually kill each mob.
- Each row is a mob you can go and kill, with its drops, coins, skinning/gathering off the corpse and pickpocketing (rogues) added together.
- A kill only counts if you looted it, or the game confirmed the corpse was empty. Skipped corpses don't drag drop rates down.
- Rank by **Safe** gold/hour, which uses the low end of each drop chance's 95% range so a lucky streak can't put a mob on top, or by **Expected**, which uses the average.
- If a drop is worth more crafted (for example cooked instead of sold raw), the row is marked *craft↑*. Turn on "Value as crafted" to rank farms by that value.

**Craft** shows every recipe you know: what the reagents cost (cheapest of the AH and any vendor you've visited), what the result sells for after the AH cut, profit, margin, how many are listed and the 7-day trend. It also flags crafts that use something you farm. Click a row to search the AH.

**Deals** lists:
- **Below market**: listings 30%+ under the item's usual price (the 14-day median once there are 3+ days of scans). Buying is capped at a quarter of the market, so you don't buy more than you can resell.
- **Vendor flips**: items listed for less than a vendor pays. There's no risk.
- **Cheap recipes**: patterns listed below their usual price.

Gear is left out by default because random stats make its prices unreliable. Click a row to search for the item on the AH.

**Recipes** shows patterns you don't know yet, for your own professions. It ranks them by profit per craft and shows how many crafts it takes to pay back the recipe's AH price, plus where to get it (vendor, drop, trainer).

**Market** shows 7-day price trends for the things you farm, craft and use as reagents, with a tip for each: *Sell now*, *Hold*, *Stock up* or *Buy later*. It also lists the biggest movers on your AH. After two weeks of scans, it shows which weekday your AH is cheapest and dearest.

## How prices work

One **Scan AH** (allowed every 15 minutes) reads every auction. Per item, it stores:
- the price at the 10th percentile of all listed units, so one 1c troll listing or one greedy listing doesn't set the price
- the median price
- the 5 cheapest listings
- how many units are listed

Each scan adds a day to a 28-day history. Scan once a day and trends, deals and weekday patterns get sharper. Auctionator fills in any gaps.

## Under the Forever restrictions

WoW Forever runs on the Midnight engine, which closes the combat log to addons. Haulwise counts kills like this instead:
- it sees a mob alive, then dead with the loot yours
- it then either reads the loot window (`GetLootSourceInfo`, which also works for AoE loot) or finds out from `CanLootUnit` that the corpse is empty

Kills are only recorded while you're solo, unless you use `/haul group on`.

## Setup

1. Unzip into `World of Warcraft\_forever_\Interface\AddOns` so you get a `Haulwise` folder there.
2. Open each profession window once, so Haulwise can read your recipes.
3. Visit a trade goods vendor, so Haulwise learns what thread, salt, vials and so on cost.
4. Press **Scan AH** at the auction house, ideally once a day.

## Commands

| Command | |
|---|---|
| `/haul` | open / close |
| `/haul kph <n>` | kills/hour to assume for mobs you haven't timed yet |
| `/haul group on\|off` | record while grouped |
| `/haul session` | reset the session counter |
| `/haul export`, `/haul import` | share drop data with friends |
| `/haul wipe yes` | delete all drop data |
| `/haul debug` | print errors |

## Status

Version 0.4.0. Tested outside the game against a mocked WoW API. The tests cover:
- 360 simulated kills, AoE loot, reopened loot windows, skinning, pickpocketing and group filtering
- 21 days of AH scans, deals, crafting, recipes and trends
- every tab drawing
- the community server: upload checks, outlier filtering, per-player caps and export
- bag values (vendor, AH, disenchant), protection rules, swap and Make room, Upgrade Advisor for you and an alt, Holdings, the HUD

**It hasn't been run in the game client yet.** Expect a round of fixes after the first in-game test.
