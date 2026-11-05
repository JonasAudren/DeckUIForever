local ADDON, ns = ...
local D = DeckForever

-------------------------------------------------------------------
-- Bag slots: a row of the equipped bags in the bag window
-------------------------------------------------------------------
-- A bag is swapped by dragging the new one onto the slot that holds the
-- old one; a right click on a bag only fills an empty slot. With "Hide
-- Blizzard's bag buttons" on, Blizzard's slots are parked out of sight,
-- and the bag window had no slots of its own - so a new bag could not be
-- put on at all (owner, in Mists, 2026-11-02; the same in retail). The
-- row sits in the title line, one square per bag slot (the reagent bag
-- too in retail; the backpack cannot be swapped).
--
-- Buttons of our own, not Blizzard's BagSlotButtonTemplate: that one
-- registers itself with MainMenuBarBagManager and toggles Blizzard's
-- parked bag frames on a click. The calls Blizzard's buttons make are
-- not protected (Blizzard_MainMenuBarBagButtons, both games, read
-- 2026-11-02): PutItemInBag(inventoryID) takes what is on the cursor
-- and hands back the old bag, PickupBagFromSlot(inventoryID) lifts a
-- bag. The inventory ID of a bag comes from ContainerIDToInventoryID.
-- The tooltip is GameTooltip:SetInventoryItem, the engine's own text.
-------------------------------------------------------------------
local SIZE = 20
local GAP  = 3
local window = ns.bags

local NUM_BAGS = Constants.InventoryConstants.NumBagSlots   -- 4
local REAGENT  = Enum.BagIndex.ReagentBag

local function InventoryID(bag)
    local f = C_Container and C_Container.ContainerIDToInventoryID or ContainerIDToInventoryID
    return f and f(bag)
end

local buttons = {}

local function Update(b)
    local id = b.inventoryID
    local texture = GetInventoryItemTexture("player", id)
    b.icon:SetTexture(texture or "Interface\\Buttons\\WHITE8x8")
    if texture then
        b.icon:SetVertexColor(1, 1, 1)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    else
        -- an empty slot is a dark square with a faint mark
        b.icon:SetVertexColor(0.2, 0.2, 0.2)
        b.icon:SetTexCoord(0, 1, 0, 1)
    end
    b.icon:SetDesaturated(IsInventoryItemLocked(id) and true or false)
end

local function OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local hasItem = GameTooltip:SetInventoryItem("player", self.inventoryID)
    if not hasItem then
        GameTooltip:SetText(self.bag == REAGENT and "Reagent bag slot" or (BAGSLOTTEXT or "Bag slot"))
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Drag a bag here to equip it; the old one goes to the cursor.", 0.5, 0.5, 0.5, true)
    GameTooltip:Show()
end

local function TakeFromCursor(self)
    if not CursorHasItem() then return false end
    PutItemInBag(self.inventoryID)
    return true
end

local function Make(i, bag)
    local b = CreateFrame("Button", nil, window)
    b:SetSize(SIZE, SIZE)
    b.bag, b.inventoryID = bag, InventoryID(bag)
    D.FlatBox(b, 0.9, 0.35)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.12)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    -- a click or a drop with a bag on the cursor puts it on; a drag lifts
    -- the bag that is there. A plain click does nothing: the window
    -- already shows every bag.
    b:SetScript("OnClick", TakeFromCursor)
    b:SetScript("OnReceiveDrag", TakeFromCursor)
    b:SetScript("OnDragStart", function(self) PickupBagFromSlot(self.inventoryID) end)
    b:SetScript("OnEnter", OnEnter)
    b:SetScript("OnLeave", GameTooltip_Hide)
    buttons[i] = b
    return b
end

local anchor = window.title
for bag = 1, NUM_BAGS do
    local b = Make(#buttons + 1, bag)
    b:SetPoint("LEFT", anchor, "RIGHT", anchor == window.title and 14 or GAP, 0)
    anchor = b
end
if REAGENT then
    local b = Make(#buttons + 1, REAGENT)
    b:SetPoint("LEFT", anchor, "RIGHT", GAP + 4, 0)
end

local function UpdateAll()
    for _, b in ipairs(buttons) do
        if b.inventoryID then Update(b) else b:Hide() end
    end
end

-- PLAYER_ENTERING_WORLD: the textures are there; BAG_UPDATE_DELAYED: a
-- bag came or went; ITEM_LOCK_CHANGED: one is on the cursor
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:RegisterEvent("ITEM_LOCK_CHANGED")
ev:SetScript("OnEvent", function(_, event, _, slot)
    -- ITEM_LOCK_CHANGED fires for every bag slot too (bag, slot); an
    -- inventory slot's lock comes without the second argument
    if event == "ITEM_LOCK_CHANGED" and slot then return end
    UpdateAll()
end)
window:HookScript("OnShow", UpdateAll)
