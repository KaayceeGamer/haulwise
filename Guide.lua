-- Haulwise: the Guide. Opens by itself the first time (and once after each update with news), and
-- any time with /haul guide or the "?" button. Plain text, scrolls, stays until you close it.
local _, GP = ...

local G = "|cffffd040"
local W = "|cffffffff"
local D = "|cffb8b4a8"
local E = "|r"

local GUIDE = {
    { "Getting started", {
        "Haulwise learns from what you do. Five things fill it with data, and each takes a minute:",
        W .. "1. Open each profession window once" .. E .. " (K, or your profession's button). Haulwise reads your recipes.",
        W .. "2. Visit a trade goods vendor" .. E .. ". Haulwise learns what thread, dyes and vials cost.",
        W .. "3. Press Scan AH at the auction house" .. E .. " (bottom of the Haulwise window). Once a day is ideal.",
        W .. "4. Log in on each of your characters once" .. E .. ". Haulwise learns their gear, professions and bags.",
        W .. "5. Open your bank and mailbox once" .. E .. ". Now Holdings knows everything you own.",
        "Then just play: every mob you kill and loot, every trainer and vendor you open, adds to it.",
    } },
    { "The HUD", {
        "The small box that stays on screen until you close it.",
        G .. "Session" .. E .. " what you've looted this session, and per hour.",
        G .. "Gold / Bags / Total" .. E .. " hover for the full breakdown: vendor value (guaranteed), best value (AH, disenchant), bank, mail, all your characters and your 10 most valuable items.",
        G .. "Cheapest to throw away" .. E .. " drag the HUD taller to list more. Shift-click one to always keep it.",
        G .. "Sell junk" .. E .. " appears at vendors when you carry grey items.",
        D .. "Drag the corner to resize, the padlock locks it, the gear opens Settings." .. E,
    } },
    { "Bags: what's it worth, what can go", {
        "Every item is worth the highest of: vendor price (V), auction price after the 5% cut (AH, green/orange/red by age) and expected disenchant value (DE) if you or an alt can disenchant it.",
        G .. "Never offered for deletion:" .. E .. " crafting materials of any kind, quest items, tools, ammo, epics, reagents your recipes use, gear upgrades for you or your alts, and anything you keep (shift-click in the Bags tab).",
        G .. "Bags full while looting:" .. E .. " a popup offers to swap the cheapest item for the loot. Red means you'd lose money; it says how much.",
        G .. "\"Inventory is full\" elsewhere:" .. E .. " Make room offers the cheapest items, one click each.",
        G .. "Best move" .. E .. " tells you what gets the most for each item: sell on the AH, sell to a vendor, disenchant, or send to an alt who can disenchant it. When disenchanting wins, a purple Disenchant button does the best one.",
        D .. "Deleting can't be undone. If the game asks you to confirm, the item stays on your cursor until you do." .. E,
    } },
    { "Gear: upgrades for you and your alts", {
        "New gear is scored and compared with what you wear. With Pawn installed, Haulwise uses your Pawn scales; otherwise its own weights per talent tree (button in the Gear tab).",
        "Bind-on-Equip gear is also checked for your alts. At a mailbox, Send to alts lists it: click to attach. Haulwise never presses Send.",
        G .. "On the AH" .. E .. " (Gear tab) every full AH scan checks all gear for sale against you and your alts, ranked by how much upgrade each gold buys. Set a max price with the button on the right.",
    } },
    { "Farm: where to make gold", {
        "Every mob you kill and loot is counted: real drop chances, coins, skinning and pickpocket, and how fast you kill it. Rows are mobs, ranked by gold per hour.",
        G .. "By zone" .. E .. " ranks zones by the best gold per hour there. Click a zone to see its mobs. " .. G .. "This zone only" .. E .. " shows just the zone you're in.",
        G .. "Safe" .. E .. " ranks by the low end of each drop chance, so a lucky streak can't put a mob on top. " .. G .. "Expected" .. E .. " uses the average.",
        D .. "Kills count only while you're solo (group loot skews drop rates) unless you turn that on in Settings." .. E,
    } },
    { "Craft and Recipes", {
        G .. "Craft" .. E .. " shows every recipe you know: reagent cost, sale price, profit and margin. \"?\" means a reagent has no price yet: visit a vendor or scan the AH.",
        G .. "Shopping list" .. E .. " click a recipe in Craft to add it. The list sums every reagent, subtracts what's in your bags and bank, and says where each is cheapest. Click a reagent to find it on the AH.",
        G .. "Skill up" .. E .. " (Craft tab) ranks the recipes that still give skill by what each point costs: reagents minus what the result sells for. Colours come from your profession window.",
        G .. "Recipes" .. E .. " shows recipes you don't know yet, ranked by profit, with where to get them (trainer, vendor, drop, AH) and how many crafts until they pay for themselves.",
    } },
    { "Deals and Market", {
        G .. "Deals" .. E .. " listings 30%+ under their usual price, and vendor flips (cheaper than a vendor pays). Click to search the AH.",
        G .. "Market" .. E .. " 7-day price trends for what you farm, craft and use, with a tip: Sell now, Hold, Stock up. After two weeks of scans it shows your AH's cheapest and dearest weekday.",
    } },
    { "Holdings", {
        "Everything all your characters own and where: bags, bank, equipped, mail, auctions. Worn gear isn't counted as worth anything; it isn't for sale.",
    } },
    { "Community data: everyone's kills in your Haulwise", {
        "Haulwise ships with drop rates, trainer and vendor recipes and reagent prices pooled from every player who shares.",
        G .. "Sharing is manual." .. E .. " Addons can't reach the internet, so nothing leaves your PC by itself. Press " .. G .. "Share data" .. E .. " (or /haul export), press Ctrl+C, and paste it on " .. W .. GP.SITE_URL .. E .. ". The footer shows how many kills you haven't shared yet.",
        "It's anonymous (no names, no IPs). Your newest upload replaces your old one. Each player's weight is capped and data that doesn't match everyone else's is left out.",
    } },
    { "Commands and tips", {
        W .. "/haul" .. E .. " window   " .. W .. "/haul hud" .. E .. " HUD   " .. W .. "/haul room" .. E .. " make room   " .. W .. "/haul settings" .. E .. "   " .. W .. "/haul guide" .. E .. "   " .. W .. "/haul feedback" .. E .. " bugs and ideas",
        W .. "/haul export" .. E .. " / " .. W .. "import" .. E .. " share data   " .. W .. "/haul reset" .. E .. " window positions and sizes",
        "Click any column title to sort. Drag a window's corner to resize it. Ctrl + mouse wheel scales it.",
    } },
}

local NEWS = {
    "The bottom line shows how fresh the community data is. Click it to import the newest.",
    "Recipes show the skill they need, and hide ones far above yours.",
    "/haul feedback now includes Haulwise's last errors, ready to paste into a bug report.",
    "Gear tooltips: best move, what it disenchants into, and what your own disenchants gave.",
    "Gear → On the AH: upgrades for you and your alts for sale on the auction house, ranked by upgrade per gold.",
    "Craft: click a recipe to add it to your shopping list. Skill up shows the cheapest way to raise your profession.",
    "Selling at the AH: a price suggestion next to the sell frame, and a warning when a vendor pays more.",
    "At the mailbox: send crafting mats to the alt whose recipes use them, in one click.",
    "Bags: Best move for every item, and a Disenchant button when disenchanting pays most.",
    "Farm: By zone, and This zone only.",
    "Share data: the Export button is now Share data (your kills, plus the recipes and vendor prices you've seen). The footer counts kills you haven't shared, and a chat reminder comes every 100 (turn it off in Settings).",
    "/haul feedback shows where to report bugs and suggest ideas.",
}

local guide

local function build()
    guide = GP.Panel("HaulwiseGuide", 560, 600, "Haulwise guide")
    guide:SetFrameStrata("DIALOG")
    local scroll = CreateFrame("ScrollFrame", nil, guide, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -34)
    scroll:SetPoint("BOTTOMRIGHT", -32, 46)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(500, 10)
    scroll:SetScrollChild(child)
    guide.child = child
    guide.lines = {}

    local done = GP.FlatButton(guide, "Got it", 100, 24)
    done:SetPoint("BOTTOMRIGHT", -14, 12)
    done:SetPrimary(true)
    done:SetScript("OnClick", function() guide:Hide() end)
    local settings = GP.FlatButton(guide, "Settings", 100, 24)
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
        y = addText(y, "What's new in " .. GP.VERSION, "HaulwiseFontLarge")
        for _, n in ipairs(NEWS) do y = addText(y, "•  " .. n, "HaulwiseFont", 6) end
        y = y - 10
    end
    for _, section in ipairs(GUIDE) do
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
