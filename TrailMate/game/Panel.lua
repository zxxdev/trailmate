-- The TrailMate panel: everything the slash commands do, as tabs and
-- buttons. Open it with the minimap button or /tm. Every button runs the
-- same command the chat would, so there is one code path for each action.

local _, ns = ...

local Panel = {}
ns.Panel = Panel

local W, H = 480, 416
local ROWS = 8
local TABS = { "Route", "Zones", "Trainer", "Bags", "Log" }
local L

local function run(cmd)
  SlashCmdList.TRAILMATE(cmd)
  Panel.refresh()
end

-- A scrolling, selectable text box (so long text can be copied with Ctrl+C).
local function textArea(parent, top)
  local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 12, top)
  scroll:SetPoint("BOTTOMRIGHT", -30, 12)
  local box = CreateFrame("EditBox", nil, scroll)
  box:SetMultiLine(true)
  box:SetAutoFocus(false)
  box:SetFontObject(ChatFontNormal)
  box:SetWidth(W - 60)
  box:SetScript("OnEscapePressed", box.ClearFocus)
  scroll:SetScrollChild(box)
  return box
end

-- A row: a text and up to two small buttons on the right.
local function makeRows(parent, top, buttons)
  local rows = {}
  for i = 1, ROWS do
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(W - 24, 22)
    row:SetPoint("TOPLEFT", 12, top - (i - 1) * 24)
    row.text = ns.Theme.label(row)
    row.text:SetPoint("LEFT", 0, 0)
    row.text:SetWidth(W - 24 - 8 - #buttons * 92)
    row.buttons = {}
    for j, label in ipairs(buttons) do
      local b = ns.Theme.button(row, L[label], 88)
      b:SetPoint("RIGHT", -(j - 1) * 92, 0)
      row.buttons[j] = b
    end
    row:Hide()
    rows[i] = row
  end
  return rows
end

local function buildRoute(page)
  local actions = {
    { "New route", "questlog" }, { "Skip step", "skip" }, { "Done", "done" }, { "Undo", "undo" },
    { "Back to plan", "plan" }, { "Clear route", "clear" },
    { "Arrow to the top", "arrow top" }, { "Arrow to the middle", "arrow center" },
  }
  for i, a in ipairs(actions) do
    local b = ns.Theme.button(page, L[a[1]], 148, function()
      run(a[2])
    end)
    b:SetPoint("TOPLEFT", 12 + ((i - 1) % 3) * 152, -8 - math.floor((i - 1) / 3) * 26)
  end
  page.text = textArea(page, -90)
end

local function buildZones(page)
  local intro = ns.Theme.label(page, "GameFontNormalSmall")
  intro:SetPoint("TOPLEFT", 12, -10)
  intro:SetWidth(W - 140)
  intro:SetText(L["Zones that suit your level. Pick one, or let TrailMate choose."])
  local auto = ns.Theme.button(page, L["Automatic"], 110, function()
    run("zone auto")
  end)
  auto:SetPoint("TOPRIGHT", -12, -6)
  page.rows = makeRows(page, -36, { "Go here" })
  page.note = ns.Theme.label(page)
  page.note:SetPoint("BOTTOMLEFT", 12, 12)
  page.note:SetWidth(W - 24)
end

local function buildTrainer(page)
  local advice = ns.Theme.button(page, L["Trainer advice"], 150, function()
    run("trainer")
  end)
  advice:SetPoint("TOPLEFT", 12, -8)
  local find = ns.Theme.button(page, L["Find my trainer"], 150, function()
    run("find trainer")
  end)
  find:SetPoint("LEFT", advice, "RIGHT", 4, 0)

  local check = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
  check:SetSize(22, 22)
  check:SetPoint("TOPLEFT", 12, -36)
  check:SetScript("OnClick", function(self)
    run(self:GetChecked() and "tracking off" or "tracking on")
  end)
  local checkText = ns.Theme.label(page)
  checkText:SetPoint("LEFT", check, "RIGHT", 2, 0)
  checkText:SetText(L["Skip hunter tracking spells"])
  page.tracking = check

  local reserveText = ns.Theme.label(page)
  reserveText:SetPoint("TOPLEFT", 260, -42)
  reserveText:SetText(L["Gold reserve"])
  local reserve = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
  reserve:SetSize(50, 20)
  reserve:SetPoint("LEFT", reserveText, "RIGHT", 8, 0)
  reserve:SetAutoFocus(false)
  local set = ns.Theme.button(page, L["Set"], 50, function()
    run("reserve " .. (reserve:GetText() or "0"))
    reserve:ClearFocus()
  end)
  set:SetPoint("LEFT", reserve, "RIGHT", 4, 0)
  page.reserve = reserve

  page.rows = makeRows(page, -66, { "Learned", "Ignore" })
  page.note = ns.Theme.label(page)
  page.note:SetPoint("BOTTOMLEFT", 12, 12)
  page.note:SetWidth(W - 24)
end

local function buildBags(page)
  local actions = {
    { "Vendor advice", "vendor" }, { "Find vendor", "find vendor" }, { "Find repairs", "find repair" },
    { "Find flight master", "find flight" }, { "Character", "status" },
  }
  for i, a in ipairs(actions) do
    local b = ns.Theme.button(page, L[a[1]], 148, function()
      run(a[2])
    end)
    b:SetPoint("TOPLEFT", 12 + ((i - 1) % 3) * 152, -8 - math.floor((i - 1) / 3) * 26)
  end
  page.text = textArea(page, -64)
end

local function buildLog(page)
  local diag = ns.Theme.button(page, L["Diagnostics"], 120, function()
    run("diag")
  end)
  diag:SetPoint("TOPLEFT", 12, -8)
  local select = ns.Theme.button(page, L["Select all"], 120, function()
    page.text:SetFocus()
    page.text:HighlightText()
  end)
  select:SetPoint("LEFT", diag, "RIGHT", 4, 0)
  local clear = ns.Theme.button(page, L["Clear log"], 120, function()
    ns.Main.clearLog()
    Panel.refresh()
  end)
  clear:SetPoint("LEFT", select, "RIGHT", 4, 0)
  local test = ns.Theme.button(page, L["Self-test"], 90, function()
    run("selftest")
  end)
  test:SetPoint("LEFT", clear, "RIGHT", 4, 0)
  page.test = test
  local hint = ns.Theme.label(page)
  hint:SetPoint("TOPLEFT", 12, -36)
  hint:SetText(L["Select all, then Ctrl+C to copy it and send it to the developer."])
  page.text = textArea(page, -54)
end

local BUILD = { Route = buildRoute, Zones = buildZones, Trainer = buildTrainer, Bags = buildBags, Log = buildLog }

function Panel.create(saved, locale)
  L = locale
  local template = BackdropTemplateMixin and "BackdropTemplate" or nil
  local f = CreateFrame("Frame", "TrailMatePanel", UIParent, template)
  f:SetSize(W, H)
  f:SetPoint(saved.point or "CENTER", UIParent, saved.relPoint or "CENTER", saved.x or 0, saved.y or 0)
  f:SetFrameStrata("DIALOG")
  ns.Theme.movable(f, saved)
  ns.Theme.panel(f)
  ns.Theme.header(f, "TrailMate", 30)
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)
  if type(UISpecialFrames) == "table" then
    table.insert(UISpecialFrames, "TrailMatePanel") -- Escape closes it
  end

  f.tabs, f.pages = {}, {}
  for i, name in ipairs(TABS) do
    local tab = ns.Theme.button(f, L[name], 88, function()
      Panel.show(name)
    end)
    tab:SetPoint("TOPLEFT", 14 + (i - 1) * 92, -42)
    f.tabs[name] = tab
    local page = CreateFrame("Frame", nil, f)
    page:SetPoint("TOPLEFT", 0, -70)
    page:SetPoint("BOTTOMRIGHT", 0, 0)
    page:Hide()
    BUILD[name](page)
    f.pages[name] = page
  end
  f:Hide()
  Panel.frame, Panel.saved = f, saved
  Panel.current = saved.tab or "Route"
  return f
end

function Panel.show(name)
  local f = Panel.frame
  if not f then
    return
  end
  for tabName, page in pairs(f.pages) do
    page:SetShown(tabName == name)
    ns.Theme.select(f.tabs[tabName], tabName == name)
  end
  Panel.current = name
  Panel.saved.tab = name
  f:Show()
  Panel.refresh()
end

function Panel.toggle()
  local f = Panel.frame
  if not f then
    return
  end
  if f:IsShown() then
    f:Hide()
  else
    Panel.show(Panel.current or "Route")
  end
end

local function fillRows(rows, items, describe, actions)
  for i, row in ipairs(rows) do
    local item = items[i]
    if item then
      row.text:SetText(describe(i, item))
      for j, b in ipairs(row.buttons) do
        b:SetScript("OnClick", function()
          run(actions[j](i, item))
        end)
      end
      row:Show()
    else
      row:Hide()
    end
  end
end

local REFRESH = {
  Route = function(page)
    page.text:SetText(table.concat(ns.Main.routeLines(), "\n"))
  end,
  Zones = function(page)
    local zones, upcoming = ns.Main.strategy()
    fillRows(page.rows, zones, function(_, z)
      local quests = z.quests > 0 and (" - " .. L["%d quests in your log"]:format(z.quests)) or ""
      return ("%s (%d-%d) - %s%s"):format(z.label, z.min, z.max, L[z.difficulty], quests)
    end, {
      function(i)
        return "zone " .. i
      end,
    })
    page.note:SetText(upcoming)
  end,
  Trainer = function(page)
    local prefs = ns.Main.prefs()
    page.tracking:SetChecked(prefs.skipTracking == true)
    page.reserve:SetText(tostring(math.floor((prefs.reserve or 0) / 10000)))
    local advice = ns.Main.trainerAdvice()
    fillRows(page.rows, advice, function(_, r)
      return ("%s - %s (%s)"):format(L[r.verdict], r.name, ns.formatMoney(r.cost))
    end, {
      function(i)
        return "learned " .. i
      end,
      function(i)
        return "ignore " .. i
      end,
    })
    page.note:SetText(#advice == 0 and L["Open your trainer to see the advice here."] or "")
  end,
  Bags = function(page)
    page.text:SetText(table.concat(ns.Main.vendorLines(), "\n"))
  end,
  Log = function(page)
    page.text:SetText(ns.Main.logText())
  end,
}

--- Redraws the open tab.
function Panel.refresh()
  local f = Panel.frame
  if not (f and f:IsShown() and ns.Main) then
    return
  end
  local page = f.pages[Panel.current]
  if page and REFRESH[Panel.current] then
    REFRESH[Panel.current](page)
  end
end
