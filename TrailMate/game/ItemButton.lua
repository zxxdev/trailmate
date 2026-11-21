-- A button with the item the current step needs (the hearthstone on a trip,
-- the item a quest asks you to use), next to the step window and next to
-- the on-screen arrow. The player clicks it; TrailMate only puts the item
-- on it, the way an action bar does. Advises, never plays.
--
-- It is a secure action button: the game lets addons change it only out of
-- combat, so a change asked for in combat waits until the fight is over.

local _, ns = ...

local ItemButton = {}
ns.ItemButton = ItemButton

local buttons = {}
local shown -- item id on the buttons
local pending -- { id } asked for during combat
local SIZE = 34

local function itemIcon(id)
  if C_Item and C_Item.GetItemIconByID then
    local ok, icon = pcall(C_Item.GetItemIconByID, id)
    if ok and icon then
      return icon
    end
  end
  if type(GetItemIcon) == "function" then
    local ok, icon = pcall(GetItemIcon, id)
    return ok and icon or nil
  end
  return nil
end

local function make(name, parent)
  local b = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
  b:SetSize(SIZE, SIZE)
  b:RegisterForClicks("AnyUp", "AnyDown")
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints()
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetPoint("CENTER")
  border:SetSize(SIZE * 1.75, SIZE * 1.75)
  border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  border:SetBlendMode("ADD")
  border:SetVertexColor(ns.Theme.rgb(ns.Theme.GOLD))
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b:SetScript("OnEnter", function(self)
    if shown and GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      pcall(GameTooltip.SetItemByID, GameTooltip, shown)
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
  b:Hide()
  buttons[#buttons + 1] = b
  return b
end

--- Makes the two buttons: left of the step window, and centred under the arrow.
function ItemButton.create(window, arrow)
  local watcher = CreateFrame("Frame")
  watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
  watcher:SetScript("OnEvent", function()
    if pending then
      local id = pending[1]
      pending = nil
      ItemButton.set(id)
    end
  end)
  if window then
    local b = make("TrailMateItemButton", window)
    b:SetPoint("TOPRIGHT", window, "TOPLEFT", -4, -34)
  end
  if arrow then
    -- Centred under the arrow's text, where the eye already is. A protected
    -- button may only be anchored to frames (not to the text) and cannot
    -- move in combat, so it hangs from the bottom of the arrow frame, which
    -- leaves room for two lines of text and never covers the arrow.
    local b = make("TrailMateArrowItemButton", arrow)
    b:SetPoint("TOP", arrow, "BOTTOM", 0, -4)
  end
end

local function inCombat()
  return type(InCombatLockdown) == "function" and InCombatLockdown()
end

--- Puts an item on the buttons (an item id), or hides them (nil).
function ItemButton.set(id)
  if id == shown and not pending then
    return
  end
  if inCombat() then
    pending = { id }
    return
  end
  shown = id
  for _, b in ipairs(buttons) do
    if id then
      b:SetAttribute("type", "item")
      b:SetAttribute("item", "item:" .. id)
      b.icon:SetTexture(itemIcon(id))
      b:Show()
    else
      b:SetAttribute("type", nil)
      b:SetAttribute("item", nil)
      b:Hide()
    end
  end
end

--- The item on the buttons now, for the self-test.
function ItemButton.current()
  return shown
end
