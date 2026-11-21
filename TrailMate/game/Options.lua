-- TrailMate's page in the game's options (Esc > Options > AddOns), like
-- other addons have: what it is, its version, and buttons for what a player
-- looks for there. Each button runs the same action as its /tm command.

local _, ns = ...

local Options = {}
ns.Options = Options

local W = 600

-- Closes the game's options window, so what a button opens is in view.
local function closeOptions()
  if SettingsPanel and HideUIPanel then
    pcall(HideUIPanel, SettingsPanel)
  elseif InterfaceOptionsFrame and HideUIPanel then
    pcall(HideUIPanel, InterfaceOptionsFrame)
  end
end

--- Builds the page and adds it to the game's AddOns options.
--- actions = { panel, steps, minimap, help, version }: functions; version
--- returns the addon's version text. Returns the page, or nil when the
--- client has no place for it.
function Options.create(L, actions)
  local Theme = ns.Theme
  local f = CreateFrame("Frame")
  f.name = "TrailMate"
  local emblem, title = Theme.header(f, "TrailMate", 40, 16, -16)
  title:ClearAllPoints()
  title:SetPoint("TOPLEFT", emblem, "TOPRIGHT", 8, -2)
  local version = Theme.label(f, "GameFontDisableSmall")
  version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  version:SetText(L["Version %s"]:format(actions.version()))

  local about = Theme.label(f, "GameFontHighlight")
  about:SetPoint("TOPLEFT", emblem, "BOTTOMLEFT", 0, -14)
  about:SetWidth(W - 32)
  about:SetText(L["Leveling coach: a route that decides, an arrow, trainer and vendor advice. Advises, never plays."])

  local list = {
    { "Open the TrailMate panel", actions.panel, true },
    { "Show or hide the step window", actions.steps },
    { "Show or hide the minimap button", actions.minimap },
    { "Arrow to the top of the screen", actions.arrowTop },
    { "Arrow to the middle of the screen", actions.arrowCenter },
    { "Commands in the chat (/tm help)", actions.help, true },
  }
  local last
  for i, a in ipairs(list) do
    local b = Theme.button(f, L[a[1]], 300, function()
      if a[3] then
        closeOptions()
      end
      a[2]()
    end)
    b:SetHeight(26)
    if i == 1 then
      b:SetPoint("TOPLEFT", about, "BOTTOMLEFT", 0, -16)
      Theme.primary(b)
    else
      b:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -8)
    end
    last = b
  end
  local tip = Theme.label(f, "GameFontNormalSmall")
  tip:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -16)
  tip:SetWidth(W - 32)
  tip:SetTextColor(Theme.rgb(Theme.COLORS.muted))
  tip:SetText(L["Tip: /tm opens the panel; click a quest in your tracker and the arrow follows it."])

  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, f, "TrailMate")
    if ok and category then
      pcall(Settings.RegisterAddOnCategory, category)
      Options.category = category
    end
  elseif InterfaceOptions_AddCategory then
    pcall(InterfaceOptions_AddCategory, f)
  else
    return nil
  end
  Options.frame = f
  return f
end

--- Opens the game's options at TrailMate's page. False if it cannot.
function Options.open()
  local category = Options.category
  if category and Settings and Settings.OpenToCategory then
    local id = category.GetID and category:GetID() or category.ID
    return (pcall(Settings.OpenToCategory, id))
  end
  if Options.frame and InterfaceOptionsFrame_OpenToCategory then
    return (pcall(InterfaceOptionsFrame_OpenToCategory, Options.frame))
  end
  return false
end
