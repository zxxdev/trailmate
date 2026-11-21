-- A round button on the minimap edge with the TrailMate icon.
-- Left click: the panel. Right click: show or hide the step window.
-- Drag it around the minimap; the position is saved.

local _, ns = ...

local MinimapButton = {}
ns.MinimapButton = MinimapButton

-- How far past the minimap's edge the button's centre goes, like other
-- addons' buttons: it sits on the ring, half in and half out.
local OUT = 5
-- The classic minimap's size, for when the game has not laid it out yet.
local FALLBACK_SIZE = 140

local function size(get)
  local v = get and get(Minimap)
  return (type(v) == "number" and v > 0) and v or FALLBACK_SIZE
end

local function place(b, angle)
  local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
  local x, y = ns.Geo.edgeOffset(angle, size(Minimap.GetWidth) / 2 + OUT, size(Minimap.GetHeight) / 2 + OUT, shape)
  b:ClearAllPoints()
  b:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function MinimapButton.create(saved, L, onLeft, onRight)
  if not Minimap then
    return nil
  end
  local b = CreateFrame("Button", "TrailMateMinimapButton", Minimap)
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  -- Like every addon's minimap button: the icon's face (no ring of its own)
  -- inside the game's gold ring.
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER", b, "CENTER", 0, 0)
  ns.Theme.useIcon(icon, true)
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetSize(50, 50)
  border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

  saved.angle = saved.angle or 200
  place(b, saved.angle)
  -- The minimap can change size (or get it late): stay on its edge.
  if Minimap.HookScript then
    pcall(Minimap.HookScript, Minimap, "OnSizeChanged", function()
      place(b, saved.angle)
    end)
  end

  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      saved.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
      place(self, saved.angle)
    end)
  end)
  b:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
  end)
  b:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
      onRight()
    else
      onLeft()
    end
  end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("TrailMate")
    GameTooltip:AddLine(L["Left click: panel"], 1, 1, 1)
    GameTooltip:AddLine(L["Right click: show or hide the steps"], 1, 1, 1)
    GameTooltip:AddLine(L["Drag: move this button"], 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  if saved.hidden then
    b:Hide()
  end
  MinimapButton.button = b
  return b
end
