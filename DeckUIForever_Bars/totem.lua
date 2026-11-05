local ADDON, ns = ...
local D = DeckUIForever

-------------------------------------------------------------------
-- The totem bar: Blizzard's MultiCastActionBarFrame in the hotbar look
-------------------------------------------------------------------
-- Forever brings Wrath's totem bar for shamans (Blizzard_ActionBar
-- Shared/MultiCastActionBarFrame.lua, loaded for camelot): a summon
-- button, four totem slots with their element rings, a recall button,
-- and a flyout to pick the totem of each slot. The bar is an Edit Mode
-- system that pages and anchors itself, and its buttons are Blizzard's
-- secure action buttons - so it is not rebuilt but dressed (owner's
-- wish, 2026-11-05): the ring art goes, every button gets the square
-- slot look. Nothing of Blizzard's is replaced or wrapped, only textures
-- are hidden and ours added; the bar keeps its place and is moved in Edit
-- Mode. DeckUIForeverBarsDB.totemBar, a reload to undo.
-------------------------------------------------------------------
local MASK = "Interface\\AddOns\\DeckUIForever_Bars\\textures\\slot_rounded"
local dressed = false

-- the slot look on one of Blizzard's buttons: the shade and outline of our
-- own slots, the icon behind the rounded mask, Blizzard's art faded
local function Dress(b)
    if not b or b.DeckDressed then return end
    b.DeckDressed = true
    local mask = b:CreateMaskTexture()
    mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(b)
    local slot = b:CreateTexture(nil, "BACKGROUND", nil, -7)
    slot:SetAllPoints()
    slot:SetTexture(MASK)
    slot:SetVertexColor(0, 0, 0, 0.2)
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local line = b:CreateTexture(nil, "OVERLAY", nil, 6)
        line:SetTexture("Interface\\Buttons\\WHITE8x8")
        line:SetVertexColor(0.85, 0.85, 0.85, 0.3)
        if side == "TOP" or side == "BOTTOM" then
            line:SetPoint(side .. "LEFT")
            line:SetPoint(side .. "RIGHT")
            line:SetHeight(1)
        else
            line:SetPoint("TOP" .. side)
            line:SetPoint("BOTTOM" .. side)
            line:SetWidth(1)
        end
    end
    local icon = b.icon or _G[(b:GetName() or "") .. "Icon"]
    if icon then
        icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
        icon:AddMaskTexture(mask)
    end
    -- Blizzard's ring art and the empty-slot art: faded, and kept faded
    -- when Blizzard sets them again (a texture coordinate change does not
    -- touch alpha, so the hooks only guard SetTexture and SetAtlas)
    for _, key in ipairs({ "overlayTex", "background", "NormalTexture" }) do
        local tex = b[key]
        if tex then
            tex:SetAlpha(0)
            for _, setter in ipairs({ "SetTexture", "SetAtlas" }) do
                if tex[setter] then hooksecurefunc(tex, setter, function(self) self:SetAlpha(0) end) end
            end
        end
    end
    local normal = b.GetNormalTexture and b:GetNormalTexture()
    if normal and normal ~= b.NormalTexture then
        normal:SetAlpha(0)
        hooksecurefunc(normal, "SetTexture", function(self) self:SetAlpha(0) end)
        hooksecurefunc(normal, "SetAtlas", function(self) self:SetAlpha(0) end)
    end
    if b.cooldown then
        b.cooldown:SetSwipeTexture(MASK)
        b.cooldown:SetDrawEdge(false)
    end
    -- the hotkey text in our font, where Blizzard puts it
    local hotkey = b.HotKey or _G[(b:GetName() or "") .. "HotKey"]
    if hotkey then hotkey:SetFont(D.FONT, 11, "OUTLINE") end
end

function ns.ApplyTotemBar()
    if dressed or not DeckUIForeverBarsDB.totemBar then return end
    local frame = _G.MultiCastActionBarFrame
    if not frame then return end
    dressed = true
    for i = 1, (NUM_MULTI_CAST_PAGES or 3) * (NUM_MULTI_CAST_BUTTONS_PER_PAGE or 4) do
        Dress(_G["MultiCastActionButton" .. i])
    end
    for i = 1, (NUM_MULTI_CAST_BUTTONS_PER_PAGE or 4) do
        Dress(_G["MultiCastSlotButton" .. i])
    end
    Dress(_G.MultiCastSummonSpellButton)
    Dress(_G.MultiCastRecallSpellButton)
end

-- /df bars
function ns.PrintTotemBar()
    local frame = _G.MultiCastActionBarFrame
    print(("  totem bar: option %s, frame %s, dressed %s, active slots %s"):format(
        tostring(DeckUIForeverBarsDB.totemBar), frame and "found" or "missing", tostring(dressed),
        tostring(frame and frame.numActiveSlots)))
end
