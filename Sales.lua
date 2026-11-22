-- Haulwise: your auction sales. When an auction sells, the gold comes by mail with an invoice
-- (item, count, price, AH cut). Haulwise reads those invoices whenever you open a mailbox and
-- keeps a log, so you can see what you've actually earned per day and per item.
-- Each mail is logged once, even if you open the mailbox many times before taking the gold.
local _, GP = ...
local L = GP.L

local KEEP_DAYS = 60
local MAX_SALES = 3000
local MAIL_DAYS = 30 -- an auction mail stays 30 days, so its age is 30 minus the days left

local function charShort()
    return (UnitName and UnitName("player")) or "?"
end

-- An item name from an invoice back to its item ID, from what Haulwise has seen.
local function idForName(name)
    local get = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if get then
        local ok, id = pcall(get, name)
        if ok and type(id) == "number" then return id end
    end
    for id, n in pairs(GP.db.names or {}) do if n == name then return id end end
    for id, r in pairs(GP.db.prices or {}) do if r.n == name then return id end end
    return nil
end

-- A key that stays the same each time you open the mailbox: item, price and when the mail
-- expires, to the hour (checked one hour either side, so a reopen across an hour mark is fine).
-- Buyer and count are left out because the game sometimes fills them in a moment later. Two
-- identical mails are told apart by their order (#1, #2...), so selling five crates at the
-- same price logs five sales.
local function mailKeys(name, bid, expiresAt, nth)
    local base = (name or "") .. "|" .. (bid or 0) .. "|"
    local h = math.floor(expiresAt / 3600)
    local tail = "#" .. nth
    return base .. h .. tail, base .. (h - 1) .. tail, base .. (h + 1) .. tail, base .. h
end

-- Reads every auction invoice in the inbox. Returns how many new sales and their gold.
function GP:ReadSales()
    if not (GetInboxNumItems and GetInboxInvoiceInfo and GetInboxHeaderInfo) then return 0, 0 end
    local db, now, today = self.db, time(), GP.Day()
    db.sales, db.salesSeen = db.sales or {}, db.salesSeen or {}
    local added, gold = 0, 0
    local nthOf = {}
    for i = 1, GetInboxNumItems() do
        local okH, _, _, _, _, money, _, daysLeft = pcall(GetInboxHeaderInfo, i)
        local ok, kind, name, buyer, bid, _, _, cut, _, _, count = pcall(GetInboxInvoiceInfo, i)
        if okH and ok and kind == "seller" and name and (bid or 0) > 0 then
            daysLeft = GP.Safe(daysLeft) or MAIL_DAYS
            local _, _, _, group = mailKeys(name, bid, now + daysLeft * 86400, 0)
            nthOf[group] = (nthOf[group] or 0) + 1
            local k1, k2, k3 = mailKeys(name, bid, now + daysLeft * 86400, nthOf[group])
            if not (db.salesSeen[k1] or db.salesSeen[k2] or db.salesSeen[k3]) then
                db.salesSeen[k1] = today
                local earned = bid - (cut or 0)
                local age = math.max(0, math.min(MAIL_DAYS, MAIL_DAYS - daysLeft))
                local id = idForName(name)
                table.insert(db.sales, { t = math.floor(now - age * 86400), id = id, n = name,
                                         c = math.max(1, GP.Safe(count) or 1), g = earned, ch = charShort() })
                added, gold = added + 1, gold + earned
            end
        end
    end
    -- Tidy: old sales and keys of mails long gone.
    local cutoff = now - KEEP_DAYS * 86400
    local keep = {}
    for _, s in ipairs(db.sales) do if s.t >= cutoff then keep[#keep + 1] = s end end
    table.sort(keep, function(a, b) return a.t < b.t end)
    while #keep > MAX_SALES do table.remove(keep, 1) end
    db.sales = keep
    for k, d in pairs(db.salesSeen) do if d < today - MAIL_DAYS - 1 then db.salesSeen[k] = nil end end
    return added, gold
end

-- Gold earned from sales since `days` days ago (today counts as day 0).
function GP:SalesTotal(days)
    local from, sum, n = (GP.Day() - days) * 86400, 0, 0
    for _, s in ipairs(self.db.sales or {}) do
        if s.t >= from then sum, n = sum + s.g, n + math.max(1, s.c or 1) end
    end
    return sum, n
end

-- One row per item over the last `days` days, most earned first.
function GP:SalesRows(days)
    days = days or 30
    local from = (GP.Day() - days) * 86400
    local by = {}
    for _, s in ipairs(self.db.sales or {}) do
        if s.t >= from then
            local key = s.id or s.n
            local r = by[key]
            if not r then
                r = { id = s.id, name = s.n, count = 0, earned = 0, sales = {}, chars = {} }
                by[key] = r
            end
            r.count, r.earned = r.count + math.max(1, s.c or 1), r.earned + s.g
            r.last = math.max(r.last or 0, s.t)
            r.sales[#r.sales + 1] = s
            r.chars[s.ch or "?"] = true
        end
    end
    local rows = {}
    for _, r in pairs(by) do
        r.each = r.earned / math.max(1, r.count)
        local names = {}
        for c in pairs(r.chars) do names[#names + 1] = c end
        table.sort(names)
        r.who = table.concat(names, ", ")
        table.sort(r.sales, function(a, b) return a.t > b.t end)
        rows[#rows + 1] = r
    end
    table.sort(rows, function(a, b) return a.earned > b.earned end)
    return rows
end

GP:On("MAIL_INBOX_UPDATE", function()
    local ok, added, gold = pcall(GP.ReadSales, GP)
    if ok and added > 0 then
        if GP.session and GP.session.since then GP.session.sales, GP.session.salesN = (GP.session.sales or 0) + gold, (GP.session.salesN or 0) + added end
        GP.Print(string.format(L["Logged %s: %s. See the Market tab, Your sales."], GP.Plural(added, "sale"), GP.Coins(gold, true)))
        if GP.RefreshUI then GP:RefreshUI() end
    end
end)
