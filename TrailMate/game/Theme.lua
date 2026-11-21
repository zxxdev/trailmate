-- TrailMate's look, in the style of the game: a sharp gold border, a deep
-- blue gradient, the round badge and gold titles, with the game's own
-- buttons. Besides the game's own textures, the addon has pictures of its
-- own, drawn by scripts in tools/: the arrow, the pin and the icon. Nothing
-- is borrowed from other addons.

local _, ns = ...

local Theme = {}
ns.Theme = Theme

-- The icon (tools/make_icon.lua): a badge with a gold ring, a paw print and
-- a trail whose colour says who the companion is (purple with no AI, orange
-- for Claude, grey on black for ChatGPT). "IconFace" is the same without
-- the ring, for the minimap, where the game's own ring goes around it like
-- every addon's button.
local MEDIA = "Interface\\AddOns\\TrailMate\\media\\"
local SUFFIX = { none = "", claude = "-claude", chatgpt = "-chatgpt" }
Theme.companion = "none"
local iconTextures = {}

local function iconPath(face)
  return MEDIA .. (face and "IconFace" or "Icon") .. SUFFIX[Theme.companion]
end
Theme.iconPath = iconPath

--- Shows the addon icon on a texture and keeps it in step with the
--- companion. face: the version without the ring.
function Theme.useIcon(tex, face)
  iconTextures[#iconTextures + 1] = { tex = tex, face = face }
  tex:SetTexture(iconPath(face))
end

--- "claude", "chatgpt" or anything else for none. Returns the kind used.
function Theme.setCompanion(kind)
  if not SUFFIX[kind] then
    kind = "none"
  end
  Theme.companion = kind
  for _, e in ipairs(iconTextures) do
    e.tex:SetTexture(iconPath(e.face))
  end
  return kind
end
Theme.FLAT = "Interface\\Buttons\\WHITE8X8"
Theme.GOLD = { 1, 0.82, 0 }
Theme.ACCENT = { 0.61, 0.48, 0.83 }
Theme.BG_TOP = { 0.08, 0.13, 0.24, 0.97 }
Theme.BG_BOTTOM = { 0.02, 0.03, 0.08, 0.97 }
-- Borders are drawn with flat colours, not stretched pictures, so they stay
-- sharp at any screen size and UI scale: a dark outline, a gold band and a
-- dark inner line, the same as the icon's ring.
Theme.OUTLINE = { 0.04, 0.05, 0.09, 1 }
Theme.EDGE_GOLD = { 0.93, 0.71, 0.24, 1 }
Theme.EDGE_GOLD_DARK = { 0.58, 0.40, 0.12, 1 }
Theme.INSET = 5 -- outline 1 + gold 3 + inner line 1

-- Text colours by meaning, like quest text in the game.
Theme.COLORS = {
  accept = { 1, 0.82, 0 }, -- quest to pick up: gold
  complete = { 0.45, 0.75, 1 }, -- quest to do: light blue
  turnin = { 1, 0.9, 0.45 }, -- quest to hand in: pale gold
  ["goto"] = { 0.6, 1, 0.6 }, -- a place: green
  level = { 0.85, 0.7, 1 },
  note = { 0.9, 0.9, 0.9 },
  warning = { 1, 0.55, 0.2 },
  muted = { 0.62, 0.66, 0.74 },
}

-- Icons by step type, all from the game's own art.
Theme.STEP_ICONS = {
  accept = "Interface\\GossipFrame\\AvailableQuestIcon",
  turnin = "Interface\\GossipFrame\\ActiveQuestIcon",
  complete = "Interface\\CURSOR\\Attack",
  ["goto"] = "Interface\\Icons\\Ability_Hunter_Pathfinding",
  level = "Interface\\GossipFrame\\TrainerGossipIcon",
  note = "Interface\\GossipFrame\\GossipGossipIcon",
}

local function rgb(c)
  return c[1], c[2], c[3]
end
Theme.rgb = rgb

-- n screen pixels in this frame's units, so 1-pixel lines stay 1 pixel at
-- any UI scale (one UI unit is 1.875 pixels at 1440p, for example).
local function pixels(f, n)
  if n == 0 or not (PixelUtil and PixelUtil.GetNearestPixelSize and f.GetEffectiveScale) then
    return n
  end
  local ok, scale = pcall(f.GetEffectiveScale, f)
  if not (ok and type(scale) == "number" and scale > 0) then
    return n
  end
  local ok2, size = pcall(PixelUtil.GetNearestPixelSize, n, scale, n)
  return (ok2 and type(size) == "number") and size or n
end

-- A flat rectangle inset n screen pixels from the frame's edges, on a draw
-- sub-level.
local function rect(f, layer, sub, inset, c)
  local t = f:CreateTexture(nil, layer, nil, sub)
  local d = pixels(f, inset)
  t:SetPoint("TOPLEFT", d, -d)
  t:SetPoint("BOTTOMRIGHT", -d, d)
  t:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
  if t.SetSnapToPixelGrid then
    pcall(t.SetSnapToPixelGrid, t, false)
    pcall(t.SetTexelSnappingBias, t, 0)
  end
  return t
end

-- A vertical gradient (bottom to top), or the top colour if the client
-- cannot draw one.
local function gradient(t, bottom, top)
  t:SetTexture(Theme.FLAT)
  local ok = t.SetGradient and CreateColor and pcall(t.SetGradient, t, "VERTICAL",
    CreateColor(bottom[1], bottom[2], bottom[3], bottom[4] or 1), CreateColor(top[1], top[2], top[3], top[4] or 1))
  if not ok then
    t:SetColorTexture(top[1], top[2], top[3], top[4] or 1)
  end
end

--- Sharp gold border (outline, gold band, inner line) and a deep blue
--- vertical gradient behind the content. Returns the background texture.
function Theme.panel(f)
  rect(f, "BACKGROUND", -8, 0, Theme.OUTLINE)
  rect(f, "BACKGROUND", -7, 1, Theme.EDGE_GOLD)
  rect(f, "BACKGROUND", -6, 4, Theme.OUTLINE)
  local bg = rect(f, "BACKGROUND", -5, Theme.INSET, Theme.BG_TOP)
  gradient(bg, Theme.BG_BOTTOM, Theme.BG_TOP)
  return bg
end

--- The addon icon (a round badge with its own gold ring) in the top-left
--- corner of a frame, at x, y (10, -9 by default). Returns the holder frame.
function Theme.emblem(f, size, x, y)
  local holder = CreateFrame("Frame", nil, f)
  holder:SetSize(size, size)
  holder:SetPoint("TOPLEFT", x or 10, y or -9)
  holder:SetFrameLevel((f:GetFrameLevel() or 1) + 5)
  local icon = holder:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  Theme.useIcon(icon)
  return holder
end

--- Emblem plus a gold title next to it. Returns emblem, title.
function Theme.header(f, title, size, x, y)
  size = size or 28
  local emblem = Theme.emblem(f, size, x, y)
  local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  text:SetPoint("LEFT", emblem, "RIGHT", 8, 0)
  text:SetText(title)
  text:SetTextColor(rgb(Theme.GOLD))
  return emblem, text
end

-- Buttons are the game's own (UIPanelButtonTemplate): this client draws
-- them in HD, and the player knows them from every Blizzard window.

--- Marks a button as selected (the open tab, which cannot be clicked) or not.
function Theme.select(b, on)
  b:SetEnabled(not on)
end

--- Marks a button as the main one of its window (the game's buttons have
--- no such look: kept so the windows need not know).
function Theme.primary(b)
  return b
end

--- A game button with a click handler.
function Theme.button(parent, label, width, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width or 110, 22)
  b:SetText(label)
  b:SetScript("OnClick", onClick)
  return b
end

--- A text line in a panel.
function Theme.label(parent, template)
  local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
  fs:SetJustifyH("LEFT")
  return fs
end

--- Makes a frame movable with the left button and saves where it was left.
function Theme.movable(f, saved)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetClampedToScreen(true)
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    saved.point, saved.relPoint, saved.x, saved.y = point, relPoint, x, y
  end)
end
