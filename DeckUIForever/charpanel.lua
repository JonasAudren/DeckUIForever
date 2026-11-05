local D = DeckUIForever

-------------------------------------------------------------------
-- The character panel: item level per slot and missing enchants
-------------------------------------------------------------------
-- DeckUI's charpanel.lua (Mists, 2026-10-27), for Forever (owner's wish
-- 2026-11-05): in Classic content every enchant counts again.
-- DeckUIForeverDB.charPanel, off by default, on the Windows page.
--
-- On each of Blizzard's slot buttons (CharacterHeadSlot ..., Camelot's
-- PaperDollFrame.xml) sits a frame of ours, a child kept in our own
-- table: the item level bottom right in the item's quality colour, and
-- top left a red "E" when an enchant is missing. Nothing is written onto
-- Blizzard's buttons, the overlay takes no mouse. Under the window a
-- line sums it up: average item level and the missing enchants.
--
-- Reading an item: its link is "item:ID:enchant:...", so the enchant is
-- the second field. Classic has no sockets, so Mists' gem part is gone.
-- Which slots take an enchant is Classic's list: head (arcanum),
-- shoulders (the reputation enchants), back, chest, wrists, hands, legs
-- (armor kits), feet, both weapon slots and the ranged slot - but only a
-- weapon or shield in the off hand (a held frill takes none) and only a
-- bow, crossbow or gun in the ranged slot (a scope; wands take none).
-- Rings are left alone: Classic has no ring enchants.
-------------------------------------------------------------------
local SLOTS = {
    { 1, "Head" }, { 2, "Neck" }, { 3, "Shoulder" }, { 15, "Back" }, { 5, "Chest" },
    { 9, "Wrist" }, { 10, "Hands" }, { 6, "Waist" }, { 7, "Legs" }, { 8, "Feet" },
    { 11, "Finger0" }, { 12, "Finger1" }, { 13, "Trinket0" }, { 14, "Trinket1" },
    { 16, "MainHand" }, { 17, "SecondaryHand" }, { 18, "Ranged" },
}
local ENCHANT = { [1] = true, [3] = true, [15] = true, [5] = true, [9] = true, [10] = true,
    [7] = true, [8] = true, [16] = true }
local OFF_HAND, RANGED = 17, 18
local WEAPON_CLASS, ARMOR_CLASS = 2, 4
local SHIELD = 6                                   -- armor subclass
local RANGED_ENCHANTABLE = { [2] = true, [3] = true, [18] = true }   -- bow, gun, crossbow

local overlays = {}   -- slot -> our frame on Blizzard's button
local summary

local function Enabled() return DeckUIForeverDB and DeckUIForeverDB.charPanel end

-- the enchant ID, read from the link's second field
local function Enchant(link)
    local fields = link:match("item:([%-%d:]+)")
    if not fields then return 0 end
    local parts = { strsplit(":", fields) }
    return tonumber(parts[2]) or 0
end

-- does the item in this slot take an enchant at all
local function TakesEnchant(slot, link)
    if ENCHANT[slot] then return true end
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(link)
    if slot == OFF_HAND then
        return classID == WEAPON_CLASS or (classID == ARMOR_CLASS and subclassID == SHIELD)
    elseif slot == RANGED then
        return classID == WEAPON_CLASS and RANGED_ENCHANTABLE[subclassID] == true
    end
    return false
end

local function Overlay(slot, name)
    local f = overlays[slot]
    if f then return f end
    local button = _G["Character" .. name .. "Slot"]
    if not button then return nil end
    f = CreateFrame("Frame", nil, button)
    f:SetAllPoints()
    f:SetFrameLevel(button:GetFrameLevel() + 3)
    f:EnableMouse(false)
    f.ilvl = f:CreateFontString(nil, "OVERLAY")
    f.ilvl:SetFont(D.FONT, 11, "OUTLINE")
    f.ilvl:SetPoint("BOTTOMRIGHT", -1, 2)
    f.flags = f:CreateFontString(nil, "OVERLAY")
    f.flags:SetFont(D.FONT, 11, "OUTLINE")
    f.flags:SetPoint("TOPLEFT", 2, -2)
    overlays[slot] = f
    return f
end

local function Update()
    if not Enabled() then
        for _, f in pairs(overlays) do f:Hide() end
        if summary then summary:Hide() end
        return
    end
    local missing = 0
    for _, s in ipairs(SLOTS) do
        local slot, name = s[1], s[2]
        local f = Overlay(slot, name)
        if f then
            local link = GetInventoryItemLink("player", slot)
            local ilvlText, flags = "", ""
            if link then
                local ilvl = C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(link)
                local quality = GetInventoryItemQuality("player", slot)
                local c = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
                ilvlText = ilvl and ((c and c.hex or "") .. ilvl .. "|r") or ""
                if TakesEnchant(slot, link) and Enchant(link) == 0 then
                    flags = "|cffff3030E|r"
                    missing = missing + 1
                end
            end
            f.ilvl:SetText(ilvlText)
            f.flags:SetText(flags)
            f:Show()
        end
    end

    if not summary and CharacterFrame then
        summary = CharacterFrame:CreateFontString(nil, "OVERLAY")
        summary:SetFont(D.FONT, 12, "OUTLINE")
        -- Camelot's character frame keeps its tabs at the side (ModeTabs),
        -- so the line sits right under the window
        summary:SetPoint("TOP", CharacterFrame, "BOTTOM", 0, -6)
    end
    if summary then
        local _, equipped = GetAverageItemLevel()
        local parts = { ("Item level %.1f"):format(equipped or 0) }
        parts[#parts + 1] = missing > 0 and ("|cffff3030%d missing enchant%s|r"):format(
            missing, missing == 1 and "" or "s") or "|cff33ff33all enchanted|r"
        summary:SetText(table.concat(parts, "   "))
        summary:Show()
    end
end

-- many events, one pass a moment later (item data may still be arriving)
local pending = false
local function Request()
    if pending then return end
    pending = true
    C_Timer.After(0.1, function()
        pending = false
        if CharacterFrame and CharacterFrame:IsShown() then Update() end
    end)
end

local hooked = false
function D.ApplyCharPanel()
    if not hooked and PaperDollFrame then
        hooked = true
        PaperDollFrame:HookScript("OnShow", Request)
    end
    if Enabled() then Request() else Update() end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "GET_ITEM_INFO_RECEIVED", "UNIT_INVENTORY_CHANGED" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then
        D.ApplyCharPanel()
    elseif event == "UNIT_INVENTORY_CHANGED" and unit ~= "player" then
        return
    elseif Enabled() then
        Request()
    end
end)
