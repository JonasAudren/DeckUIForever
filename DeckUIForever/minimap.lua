local D = DeckUIForever
local RADIUS = 100

local mmb = CreateFrame("Button", "DeckUIForeverMinimapButton", Minimap)
mmb:SetSize(32, 32)
mmb:SetFrameStrata("MEDIUM")
mmb:SetFrameLevel(8)
mmb:RegisterForClicks("LeftButtonUp", "RightButtonUp")
mmb:RegisterForDrag("LeftButton")
mmb:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local bg = mmb:CreateTexture(nil, "BACKGROUND")
bg:SetSize(24, 24)
bg:SetPoint("CENTER")
bg:SetTexture(D.DISC)
bg:SetVertexColor(0.1, 0.1, 0.1)

local ring = mmb:CreateTexture(nil, "ARTWORK")
ring:SetSize(20, 20)
ring:SetPoint("CENTER")
ring:SetTexture(D.DISC)
ring:SetVertexColor(0.2, 0.5, 1)

local orb = mmb:CreateTexture(nil, "ARTWORK", nil, 1)
orb:SetSize(14, 14)
orb:SetPoint("CENTER")
orb:SetTexture(D.DISC)
orb:SetVertexColor(0.9, 0.75, 0.2)

local border = mmb:CreateTexture(nil, "OVERLAY")
border:SetSize(54, 54)
border:SetPoint("TOPLEFT")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

-- Round maps keep the button on a circle. A square one (GetMinimapShape,
-- the convention addon button libraries use; DeckUIForever Map sets it) puts it
-- on the square's edge instead: the circle through the corners, clamped
-- to the sides - otherwise a small square map has it sitting on the map.
local function UpdatePosition()
    local angle = math.rad(DeckUIForeverDB.minimapAngle or 220)
    local x, y = math.cos(angle), math.sin(angle)
    if GetMinimapShape and GetMinimapShape() == "SQUARE" then
        local edge = Minimap:GetWidth() / 2 + 6
        local r = edge * math.sqrt(2)
        x = math.max(-edge, math.min(edge, x * r))
        y = math.max(-edge, math.min(edge, y * r))
    elseif _G.DeckMapMinimap then
        -- DeckUIForever Map's round map: just outside its ring, whatever its size
        local r = Minimap:GetWidth() / 2 + 22
        x, y = x * r, y * r
    else
        x, y = x * RADIUS, y * RADIUS
    end
    mmb:ClearAllPoints()
    mmb:SetPoint("CENTER", Minimap, "CENTER", x, y)
end
D.UpdateMinimapButton = UpdatePosition

local function OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    DeckUIForeverDB.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
    UpdatePosition()
end

mmb:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", OnDragUpdate) end)
mmb:SetScript("OnDragStop",  function(self) self:SetScript("OnUpdate", nil) end)

mmb:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
        D.SetUnlocked(not D.unlocked)
    elseif IsShiftKeyDown() then
        D.ToggleWeek()
    else
        D.ToggleConfig()
    end
end)

mmb:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("DeckUIForever")
    GameTooltip:AddLine("Left-click: settings", 1, 1, 1)
    GameTooltip:AddLine("Right-click: unlock/lock frames", 1, 1, 1)
    GameTooltip:AddLine("Shift-click: this week (Week module)", 1, 1, 1)
    GameTooltip:AddLine("Drag: move button", 1, 1, 1)
    GameTooltip:Show()
end)
mmb:SetScript("OnLeave", GameTooltip_Hide)

function D.SetMinimapShown(state)
    DeckUIForeverDB.showMinimap = state
    mmb:SetShown(state)
    if not state then print("DeckUIForever: minimap button hidden - /df opens the settings.") end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    UpdatePosition()
    if DeckUIForeverDB.showMinimap == false then mmb:Hide() end
end)
