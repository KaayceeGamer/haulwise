-- Haulwise: the Guide. Opens by itself the first time (and once after each update with news), and
-- any time with /haul guide or the "?" button. Plain text, scrolls, stays until you close it.
local _, GP = ...
local L = GP.L

local G = "|cffffd040"
local W = "|cffffffff"
local D = "|cffb8b4a8"
local E = "|r"

local function guideSections() return {
    { L["Getting started"], {
        L["Haulwise learns from what you do. Five things fill it with data, and each takes a minute:"],
        W .. L["1. Open each profession window once"] .. E .. L[" (K, or your profession's button). Haulwise reads your recipes."],
        W .. L["2. Visit a trade goods vendor"] .. E .. L[". Haulwise learns what thread, dyes and vials cost."],
        W .. L["3. Press Scan AH at the auction house"] .. E .. L[" (bottom of the Haulwise window). Once a day is ideal."],
        W .. L["4. Log in on each of your characters once"] .. E .. L[". Haulwise learns their gear, professions and bags."],
        W .. L["5. Open your bank and mailbox once"] .. E .. L[". Now Holdings knows everything you own."],
        L["Then just play: every mob you kill and loot, every trainer and vendor you open, adds to it."],
    } },
    { L["The HUD"], {
        L["The small box that stays on screen until you close it."],
        G .. L["Session"] .. E .. L[" what you've looted this session, and per hour."],
        G .. L["Gold / Bags / Total"] .. E .. L[" hover for the full breakdown: vendor value (guaranteed), best value (AH, disenchant), bank, mail, all your characters and your 10 most valuable items."],
        G .. L["Cheapest to throw away"] .. E .. L[" drag the HUD taller to list more. Shift-click one to always keep it."],
        G .. L["Sell junk"] .. E .. L[" appears at vendors when you carry grey items."],
        D .. L["Drag the corner to resize, the padlock locks it, the gear opens Settings."] .. E,
    } },
    { L["Bags: what's it worth, what can go"], {
        L["Every item is worth the highest of: vendor price (V), auction price after the 5% cut (AH, green/orange/red by age) and expected disenchant value (DE) if you or an alt can disenchant it."],
        G .. L["Never offered for deletion:"] .. E .. L[" crafting materials of any kind, quest items, tools, ammo, epics, reagents your recipes use, gear upgrades for you or your alts, and anything you keep (shift-click in the Bags tab)."],
        G .. L["Bags full while looting:"] .. E .. L[" a popup offers to swap the cheapest item for the loot. Red means you'd lose money; it says how much."],
        G .. L["\"Inventory is full\" elsewhere:"] .. E .. L[" Make room offers the cheapest items, one click each."],
        G .. L["Best move"] .. E .. L[" tells you what gets the most for each item: sell on the AH, sell to a vendor, disenchant, or send to an alt who can disenchant it. When disenchanting wins, a purple Disenchant button does the best one."],
        D .. L["Deleting can't be undone. If the game asks you to confirm, the item stays on your cursor until you do."] .. E,
    } },
    { L["Gear: upgrades for you and your alts"], {
        L["New gear is scored and compared with what you wear. With Pawn installed, Haulwise uses your Pawn scales; otherwise its own weights per talent tree (button in the Gear tab)."],
        L["Bind-on-Equip gear is also checked for your alts. At a mailbox, Send to alts lists it: click to attach. Haulwise never presses Send."],
        G .. L["On the AH"] .. E .. L[" (Gear tab) every full AH scan checks all gear for sale against you and your alts, ranked by how much upgrade each gold buys. Set a max price with the button on the right."],
    } },
    { L["Farm: where to make gold"], {
        L["Every mob you kill and loot is counted: real drop chances, coins, skinning and pickpocket, and how fast you kill it. Rows are mobs, ranked by gold per hour."],
        G .. L["By zone"] .. E .. L[" ranks zones by the best gold per hour there. Click a zone to see its mobs. "] .. G .. L["This zone only"] .. E .. L[" shows just the zone you're in."],
        G .. L["Safe"] .. E .. L[" ranks by the low end of each drop chance, so a lucky streak can't put a mob on top. "] .. G .. L["Expected"] .. E .. L[" uses the average."],
        D .. L["Kills count only while you're solo (group loot skews drop rates) unless you turn that on in Settings."] .. E,
    } },
    { L["Craft and Recipes"], {
        G .. L["Craft"] .. E .. L[" shows every recipe you know: reagent cost, sale price, profit and margin. \"?\" means a reagent has no price yet: visit a vendor or scan the AH."],
        G .. L["Shopping list"] .. E .. L[" click a recipe in Craft to add it. The list sums every reagent, subtracts what's in your bags and bank, and says where each is cheapest. Click a reagent to find it on the AH."],
        G .. L["Skill up"] .. E .. L[" (Craft tab) ranks the recipes that still give skill by what each point costs: reagents minus what the result sells for. Colours come from your profession window."],
        G .. L["Recipes"] .. E .. L[" shows recipes you don't know yet, ranked by profit, with where to get them (trainer, vendor, drop, AH) and how many crafts until they pay for themselves."],
    } },
    { L["Deals and Market"], {
        G .. L["Deals"] .. E .. L[" listings 30%+ under their usual price, and vendor flips (cheaper than a vendor pays). Click to search the AH."],
        G .. L["Market"] .. E .. L[" 7-day price trends for what you farm, craft and use, with a tip: Sell now, Hold, Stock up. After two weeks of scans it shows your AH's cheapest and dearest weekday."],
    } },
    { L["Holdings"], {
        L["Everything all your characters own and where: bags, bank, equipped, mail, auctions. Worn gear isn't counted as worth anything; it isn't for sale."],
    } },
    { L["Community data: everyone's kills in your Haulwise"], {
        L["Haulwise ships with drop rates, trainer and vendor recipes and reagent prices pooled from every player who shares."],
        G .. L["Sharing is manual."] .. E .. L[" Addons can't reach the internet, so nothing leaves your PC by itself. Press "] .. G .. L["Share data"] .. E .. L[" (or /haul export), press Ctrl+C, and paste it on "] .. W .. GP.SITE_URL .. E .. L[". The footer shows how many kills you haven't shared yet."],
        L["It's anonymous (no names, no IPs). Your newest upload replaces your old one. Each player's weight is capped and data that doesn't match everyone else's is left out."],
    } },
    { L["Commands and tips"], {
        W .. "/haul" .. E .. L[" window   "] .. W .. L["/haul hud"] .. E .. L[" HUD   "] .. W .. L["/haul room"] .. E .. L[" make room   "] .. W .. L["/haul settings"] .. E .. "   " .. W .. L["/haul guide"] .. E .. "   " .. W .. L["/haul feedback"] .. E .. L[" bugs and ideas"],
        W .. L["/haul export"] .. E .. " / " .. W .. "import" .. E .. L[" share data   "] .. W .. L["/haul reset"] .. E .. L[" window positions and sizes"],
        L["Click any column title to sort. Drag a window's corner to resize it. Ctrl + mouse wheel scales it."],
    } },
} end

local function newsLines() return {
    L["Farm ranks every mob now, also ones nobody has farmed yet: those are estimates from Classic's loot tables, marked est., until real kills take over."],
    L["Item tooltips say what an item is for: the quests that need it, the crafts that use it, who sells it and what drops it. Bags keep what a quest in your log needs."],
    L["Zones are shared by map number now, so players in every language add up in the same zone."],
    L["Farm tooltips say what a number is based on and how sure it is. Point at a tab to see what it's for."],
    L["At the auction house: Your auctions shows which of yours are undercut, with a Cancel button to post them again at the right price."],
    L["Sells/day: Haulwise sees how fast things sell from your scans. It's in tooltips, the sell helper and the Craft tab, and Deals won't tell you to buy more than sells."],
    L["Market → Your sales: what you sold and earned, logged from the mail invoices."],
    L["Craft queue: open a profession and your queued crafts show beside it. Click one, press Create. Queue best 5 on the Craft tab fills it."],
    L["Waylaid Crates: the tooltip prices every way to fill one and what one Merchant's Favor costs. Writs show what the ordered item costs."],
    L["Find trainer (Craft tab) or /haul trainer: a waypoint to the nearest trainer that teaches your next rank. Uses TomTom when you have it."],
    L["Recipes: click one for a waypoint to the vendor that sells it. Shift-click searches the AH."],
    L["Profession button in Craft, Skill up and Recipes: show one profession at a time."],
    L["Minimap button: click to open Haulwise, right-click for settings, Shift-click for the HUD. Drag it around the minimap; hide it in Settings or with /haul minimap."],
    L["Haulwise speaks German and French. It follows your game's language; pick another in Settings → Language."],
    L["Disenchanting is noted reliably now, also with auto loot, and a chat line confirms what you got."],
    L["The bottom line shows how fresh the community data is. Click it to import the newest."],
    L["Recipes show the skill they need, and hide ones far above yours."],
    L["/haul feedback now includes Haulwise's last errors, ready to paste into a bug report."],
    L["Gear tooltips: best move, what it disenchants into, and what your own disenchants gave."],
    L["Gear → On the AH: upgrades for you and your alts for sale on the auction house, ranked by upgrade per gold."],
    L["Craft: click a recipe to add it to your shopping list. Skill up shows the cheapest way to raise your profession."],
    L["Selling at the AH: a price suggestion next to the sell frame, and a warning when a vendor pays more."],
    L["Share data: the Export button is now Share data (your kills, plus the recipes and vendor prices you've seen). The footer counts kills you haven't shared, and a chat reminder comes every 100 (turn it off in Settings)."],
} end

local guide

local function build()
    guide = GP.Panel("HaulwiseGuide", 560, 600, L["Haulwise guide"])
    guide:SetFrameStrata("DIALOG")
    local scroll = CreateFrame("ScrollFrame", nil, guide, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -34)
    scroll:SetPoint("BOTTOMRIGHT", -32, 46)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(500, 10)
    scroll:SetScrollChild(child)
    guide.child = child
    guide.lines = {}

    local done = GP.FlatButton(guide, L["Got it"], 100, 24)
    done:SetPoint("BOTTOMRIGHT", -14, 12)
    done:SetPrimary(true)
    done:SetScript("OnClick", function() guide:Hide() end)
    local settings = GP.FlatButton(guide, L["Settings"], 100, 24)
    settings:SetPoint("RIGHT", done, "LEFT", -6, 0)
    settings:SetScript("OnClick", function() GP:ToggleSettings() end)
    GP.MakeResizable(guide, "HaulwiseGuide", 420, 300, 900, 1000, function() if guide:IsShown() then GP:ShowGuide(guide.news) end end)
end

local function addText(y, text, font, indent)
    local fs = guide.child:CreateFontString(nil, "OVERLAY", font)
    fs:SetPoint("TOPLEFT", indent or 0, y)
    fs:SetWidth(guide.child:GetWidth() - (indent or 0))
    fs:SetJustifyH("LEFT")
    fs:SetSpacing(2)
    fs:SetText(text)
    guide.lines[#guide.lines + 1] = fs
    return y - (fs:GetStringHeight() or 14) - 6
end

function GP:ShowGuide(withNews)
    if not guide then build() end
    guide:RestorePosition({ "CENTER", UIParent, "CENTER", 0, 20 })
    guide.news = withNews
    for _, fs in ipairs(guide.lines) do fs:Hide() end
    guide.lines = {}
    guide.child:SetWidth(math.max(300, (guide:GetWidth() or 560) - 60))
    local y = 0
    if withNews then
        y = addText(y, L["What's new in "] .. GP.VERSION, "HaulwiseFontLarge")
        for _, n in ipairs(newsLines()) do y = addText(y, "•  " .. n, "HaulwiseFont", 6) end
        y = y - 10
    end
    for _, section in ipairs(guideSections()) do
        y = addText(y, section[1], "HaulwiseFontLarge")
        for _, line in ipairs(section[2]) do y = addText(y, line, "HaulwiseFont", 6) end
        y = y - 8
    end
    guide.child:SetHeight(-y + 10)
    guide:Show()
end

function GP:ToggleGuide()
    if guide and guide:IsShown() then guide:Hide() else self:ShowGuide(false) end
end

-- First install: the guide. After an update: the guide with "What's new" on top. Once each.
GP:On("PLAYER_ENTERING_WORLD", function()
    local seen = GP.db.guideSeen
    if seen == GP.VERSION then return end
    C_Timer.After(4, function()
        if InCombatLockdown and InCombatLockdown() then return end
        GP:ShowGuide(seen ~= nil)
        GP.db.guideSeen = GP.VERSION
    end)
end)
