local ADDON, ns = ...
local D = DeckUIForever

ns.DISC = D.DISC
ns.FONT = D.FONT

-- The countdown numbers a Cooldown frame writes on an aura icon come in a
-- font the client picks from the frame's size, and Forever picks a big
-- one: "50m" filled a 22 px status icon (owner, 2026-11-05). The icons
-- now hand their cooldown a font of our own, sized to the icon - one
-- font object per size, made once.
local countdownFonts = {}
function ns.CountdownFont(size)
    local px = math.max(7, math.floor(size * 0.42 + 0.5))
    local name = "DeckUIForeverOrbsCountdown" .. px
    if not countdownFonts[px] then
        local font = CreateFont(name)
        font:SetFont(ns.FONT, px, "OUTLINE")
        font:SetTextColor(1, 1, 1)
        countdownFonts[px] = font
    end
    return name
end

-- the icon's cooldown writes its numbers in that font (nothing to do
-- where the numbers are hidden, buffs.lua and raid.lua)
function ns.StyleCountdown(button)
    local cd = button.Cooldown
    if cd and cd.SetCountdownFont then
        cd:SetCountdownFont(ns.CountdownFont(button:GetWidth() or 20))
    end
end
-- the aura containers' layout axes
ns.FLOW = AnchorUtil.FlowLayoutAxis

ns.GLOW  = 0
ns.glows = {}

local function AddGlow(bar, mask)
    local glow = bar:CreateTexture(nil, "ARTWORK", nil, 1)
    glow:SetAllPoints(bar:GetStatusBarTexture())
    glow:SetColorTexture(1, 1, 1, ns.GLOW)
    glow:SetBlendMode("ADD")
    glow:AddMaskTexture(mask)
    table.insert(ns.glows, glow)
    return glow
end

function ns.SetGlow(value)
    ns.GLOW = value
    for _, glow in ipairs(ns.glows) do
        glow:SetColorTexture(1, 1, 1, value)
    end
end

-- A round, vertically filling bar with a dark disc behind it: the orb
-- itself sits above its ring, which shows through as the outer band.
local function RoundBar(parent, size, levelOffset, bgShade, bgAlpha)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(size, size)
    bar:SetPoint("CENTER")
    bar:SetFrameLevel(parent:GetFrameLevel() + levelOffset)
    bar:SetOrientation("VERTICAL")
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")

    local mask = D.RoundMask(bar)
    bar:GetStatusBarTexture():AddMaskTexture(mask)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(bgShade, bgShade, bgShade, bgAlpha)
    bg:AddMaskTexture(mask)

    AddGlow(bar, mask)
    return bar
end

function ns.CreateOrb(parent, size) return RoundBar(parent, size, 2, 0.08, 1) end
function ns.CreateRing(parent, size) return RoundBar(parent, size, 1, 0.1, 0.9) end

function ns.CreateCastOverlay(orb, size)
    local bar = CreateFrame("StatusBar", nil, orb)
    bar:SetSize(size, size)
    bar:SetPoint("CENTER", orb, "CENTER")
    bar:SetFrameLevel(orb:GetFrameLevel() + 1)
    bar:SetOrientation("HORIZONTAL")
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetStatusBarColor(1, 0.85, 0.3, 0.55)

    local mask = D.RoundMask(bar)
    bar:GetStatusBarTexture():AddMaskTexture(mask)

    return bar
end
