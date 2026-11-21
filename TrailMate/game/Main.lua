-- Wiring: saved variables, game events, slash commands.
-- TrailMate advises and never plays: nothing here presses keys, moves the
-- character, buys, sells or trains. It only reads the game and shows text.
-- It depends on no other addon and uses none: its arrow, minimap and world
-- map marks are its own.

local addonName, ns = ...
local L = ns.L
local Api, Plan, Builder, Trainer, Atlas = ns.Api, ns.Plan, ns.Builder, ns.Trainer, ns.Atlas

local cdb -- TrailMateCharDB, per character
local atlas -- TrailMateDB.atlas, shared by the account's characters
local plan, progress, current, statuses
local arrowStep, markMethod
local detour -- { target, label }: takes over the arrow for a moment
local ourFocus -- the quest TrailMate asked the game to follow
local quietUntil -- until then, a quest the game follows is not the player's mark
local lastAdvice = {}
local lastProgress = {}
local lastCounts = {} -- quests worth doing per zone, from the last route
local lastZones = {} -- the numbered list /tm strategy showed
local warnedLevel = {} -- levels already announced as "almost there"
local warnedFull = false
local questThrottle = ns.Throttle.new(0.3)
local bagThrottle = ns.Throttle.new(1)
local clock, sinceMove, sinceTarget, sinceArrow, sinceTalents, sinceTrail, sinceChat = 0, 0, 0, 0, 0, 0, 0
local trails -- TrailMateDB.trails: the ways walked, shared by the account's characters
local trailPrev, trailLast -- last dot recorded, last position seen
local lastPath -- the trail route the arrow follows now
local lastWhy -- why there is no trail route now (for the self-test)
local showLearned = false -- /tm trail show: the map shows every learned dot
local followTrail -- defined with the update loop, used by /tm trail

local COLORS = {
  learn = "|cff40c040", skip = "|cffc04040", later = "|cffd0a020",
}

local lastReportLines, lastVendorLines, travelLines = {}, {}, {}
local hearthing = false -- the hearthstone was just used: learn where it lands

-- Every line TrailMate prints is also kept in the log (panel, Log tab).
local function out(line)
  print(line)
  if TrailMateDB then
    TrailMateDB.log = TrailMateDB.log or {}
    ns.Log.add(TrailMateDB.log, line, date and date("%H:%M") or nil)
  end
end

local function say(msg)
  out("|cff9b7bd4TrailMate|r: " .. msg)
end

-- A failure in one part (the talent panel, say) must not take the rest of
-- the addon down with it: each part runs guarded, and the error is shown
-- once in the chat and kept in the log so it can be sent.
local reported = {}
local function reportError(where, err)
  local msg = ("%s: %s"):format(where, tostring(err))
  if not reported[msg] then
    reported[msg] = true
    pcall(say, "|cffff5050" .. L["Error"] .. "|r " .. msg)
  end
end

local function guard(where, fn, ...)
  local ok, a, b = pcall(fn, ...)
  if not ok then
    reportError(where, a)
    return nil
  end
  return a, b
end

local function after(seconds, fn)
  if C_Timer and C_Timer.After then
    C_Timer.After(seconds, fn)
  else
    fn()
  end
end

local function playerPoint()
  local mapID, x, y = Api.position()
  return { mapID = mapID, x = x, y = y, level = Api.level() }
end

local function facts()
  local log = {}
  for _, q in ipairs(Api.questLog()) do
    log[q.questID] = { complete = q.complete }
  end
  local p = playerPoint()
  return { level = p.level, mapID = p.mapID, x = p.x, y = p.y, questLog = log, turnedIn = Api.turnedIn }
end

-- Where to go for a quest: where the game points (objective area, or the
-- turn-in once complete), or else what the atlas learned before.
local function questTarget(questID, complete)
  return Api.questTarget(questID) or (atlas and Atlas.questTarget(atlas, questID, complete, playerPoint()))
end

-- Where the current step wants you: its own point, or its quest's place.
local function stepTarget(step)
  if not step then
    return nil
  end
  if step.mapID then
    return { mapID = step.mapID, x = step.x, y = step.y }
  end
  if step.questID then
    return questTarget(step.questID, step.type == "turnin")
  end
  return nil
end

local function updateTarget(force)
  if detour then
    ns.Arrow.setTarget(detour.target, detour.label, detour.item and L["Click the item to use it"])
    ns.ItemButton.set(detour.item)
    return
  end
  local step = current and plan and plan.steps[current] or nil
  if step == arrowStep and not force then
    return
  end
  local changed = step ~= arrowStep
  arrowStep = step
  local target = stepTarget(step)
  ns.Arrow.setTarget(target, step and step.text)
  -- A quest that needs an item used: a button to click.
  ns.ItemButton.set(step and step.type == "complete" and Api.questItem(step.questID) or nil)
  if changed then
    local focused = Api.focusQuest(step and step.questID)
    -- What the game really follows now (it keeps the last one when this
    -- step's quest is not in the log yet): that is TrailMate's, not a mark.
    ourFocus = Api.superTrackedQuest() or (step and step.questID)
    if target then
      markMethod = Api.setArrow(target, step.text, focused)
    else
      Api.clearArrow()
      markMethod = focused and "quest" or nil
    end
  end
end

-- Learning ------------------------------------------------------------------

-- Records where quest objectives move forward, so next time (or on an alt)
-- the arrow knows where a quest is done.
local function learnProgress()
  if not atlas then
    return
  end
  local p
  for _, q in ipairs(Api.questLog()) do
    local now = Api.questProgress(q.questID)
    local before = lastProgress[q.questID]
    if now and before and now > before then
      p = p or playerPoint()
      Atlas.recordProgress(atlas, q.questID, p)
    end
    lastProgress[q.questID] = now
  end
end

local function learnNpc(role, class)
  local npc = Api.npc()
  if npc and atlas then
    npc.role, npc.class, npc.faction = role, class, Api.faction()
    Atlas.recordNpc(atlas, npc, playerPoint())
  end
end

local function questInfo(questID)
  for _, q in ipairs(Api.questLog()) do
    if q.questID == questID then
      return q
    end
  end
  return nil
end

-- Plan --------------------------------------------------------------------------

local buildFromQuestLog
local travelTo -- a trip to another zone (defined with the travel planner)
local advanceGuide -- a guide is finished: go on to the next one

-- The step window shows the trip while travelling to a chosen zone.
local function render()
  if detour and detour.zone then
    ns.UI.renderTravel(travelLines, L)
  elseif detour and detour.marked then
    local step = plan and current and plan.steps[current]
    ns.UI.renderMarked(detour, step and step.text, ns.Guide.isGuide(plan), L)
  else
    ns.UI.render(plan, current, statuses, L, markMethod)
  end
end

-- The quest the player marked: what the arrow says and where it points (the
-- objectives, then the turn-in once done). False when it has left the log
-- (handed in or dropped): the detour ends and the guide leads again.
local function updateMarked()
  local log = facts().questLog
  local entry = questInfo(detour.marked)
  local view = ns.Marked.view(detour.marked, Api.questTitle(detour.marked) or (entry and entry.title), log, L)
  if not view then
    detour, arrowStep = nil, false
    say(L["Your marked quest is no longer in the log: back to the guide."])
    return false
  end
  detour.label, detour.kind = view.text, view.kind
  detour.target = questTarget(detour.marked, view.kind == "turnin")
  detour.item = view.kind == "complete" and Api.questItem(detour.marked) or nil
  return true
end

local function refresh()
  if detour and detour.marked then
    updateMarked()
  end
  if not plan then
    render()
    if detour then
      updateTarget()
    else
      ns.Arrow.setTarget(nil)
    end
    return
  end
  local ok, cur, st = pcall(Plan.evaluate, plan, progress, facts())
  if not ok then
    return
  end
  local finishedNow = current ~= nil and cur == nil
  current, statuses = cur, st
  if finishedNow then
    if ns.Guide.isGuide(plan) and advanceGuide then
      advanceGuide()
      return
    end
    if ns.Dungeons.isDungeon(plan) then
      say(L["Dungeon finished: back to your guide."])
      buildFromQuestLog(true)
      return
    end
    if Builder.isAuto(plan) and cdb.prefs.autoPlan ~= false then
      buildFromQuestLog(true)
      return
    end
    say(L["Plan finished."])
  end
  updateTarget()
  render()
  ns.Panel.refresh()
end

local function loadPlan(p, quiet)
  local ok, err = Plan.validate(p)
  if not ok then
    say(L["Plan rejected: %s"]:format(tostring(err)))
    return false
  end
  plan = p
  progress = Plan.ensureProgress(p, cdb.progress)
  cdb.plan, cdb.progress = p, progress
  current, arrowStep = nil, false
  if not quiet then
    say(L["Plan loaded: %s (%d steps)."]:format(p.title or p.id, #p.steps))
  end
  refresh()
  return true
end

local function joinNames(list, limit)
  local parts = {}
  for i, e in ipairs(list) do
    if i > limit then
      parts[#parts + 1] = "..."
      break
    end
    parts[#parts + 1] = e.title and ("%s (%s)"):format(e.title, e.reason) or ("%s (%d)"):format(e.zone, e.count)
  end
  return table.concat(parts, ", ")
end

-- Tells the player what the route decided and what it left out.
local function sayReport(report)
  local lines = {}
  if report.zone then
    lines[#lines + 1] = L["Route: %s, %d steps."]:format(report.zone, plan and #plan.steps or 0)
  end
  if #report.notNow > 0 then
    lines[#lines + 1] = L["Not now: %s"]:format(joinNames(report.notNow, 6))
  end
  if #report.abandon > 0 then
    lines[#lines + 1] = L["Consider abandoning: %s"]:format(joinNames(report.abandon, 6))
  end
  if #report.later > 0 then
    lines[#lines + 1] = L["Later: %s"]:format(joinNames(report.later, 5))
  end
  lastReportLines = lines
  for _, line in ipairs(lines) do
    say(line)
  end
end

local function zoneName(names, mapID)
  names[mapID] = names[mapID] or Api.mapName(mapID) or ("map " .. mapID)
  return names[mapID]
end

-- Quests to pick up nearby: the ones the game shows, plus the ones the atlas
-- saw before (on this character or an alt) that fit the player now.
local function offersHere(player, quests, names)
  local inLog = {}
  for _, q in ipairs(quests) do
    inLog[q.questID] = true
  end
  local offers, seen = {}, {}
  local function addAll(list)
    for _, o in ipairs(list) do
      if not seen[o.questID] then
        seen[o.questID] = true
        o.zone = o.target and zoneName(names, o.target.mapID)
        offers[#offers + 1] = o
      end
    end
  end
  addAll(Api.availableQuests(player.mapID))
  if atlas then
    addAll(Atlas.offers(atlas, {
      level = player.level or 1,
      faction = Api.faction(),
      isDone = function(id)
        return Api.turnedIn(id) == true
      end,
      inLog = function(id)
        return inLog[id] == true
      end,
    }, player))
  end
  return offers
end

-- Works out the route from the quest log without loading it.
-- Returns plan (or nil), report, quests.
local function computeRoute()
  local quests = Api.questLog()
  local names = {}
  local player = playerPoint()
  for _, q in ipairs(quests) do
    q.target = questTarget(q.questID, q.complete)
    if q.target then
      q.zone = zoneName(names, q.target.mapID)
    end
  end
  local p, report = Builder.fromQuestLog(quests, player, L, offersHere(player, quests, names), {
    zoneBonus = ns.Strategy.zoneBonus(player.level),
    focus = cdb.prefs.focusZone,
  })
  return p, report, quests
end

-- Is the hearthstone bound somewhere else than this zone?
local function hearthElsewhere(here)
  local h = Api.hearth()
  if not h then
    return false, nil
  end
  local bind = Atlas.bind(atlas, h.name)
  if bind then
    return bind.mapID ~= here.mapID, h
  end
  for _, name in ipairs(Api.zoneTexts()) do
    if name == h.name then
      return false, h
    end
  end
  return true, h
end

-- Just arrived in the zone chosen to level in: first pick up the quests of
-- the place, then (if the hearthstone is far) set it at the inn here, then
-- the quests. Steps put at the front of the plan.
local function addArrivalSteps(p)
  local here = playerPoint()
  if not (cdb.arrival and here.mapID == cdb.arrival) then
    return p
  end
  -- No quests of yours here yet (the usual case on arrival): a plan with
  -- only the arrival steps, rebuilt like any automatic plan as you take quests.
  p = p or { version = 1, id = "questlog-arrival-" .. here.mapID, title = Api.mapName(here.mapID) or "TrailMate",
    steps = {} }
  local front = 0
  while p.steps[front + 1] and p.steps[front + 1].type == "accept" do
    front = front + 1
  end
  local extra = {}
  -- The quests of the hubs here (data/Hubs.lua), one step each, unless the
  -- plan already picks them up.
  local taken = {}
  for _, s in ipairs(p.steps) do
    if s.type == "accept" then
      taken[s.questID] = true
    end
  end
  local inLog = {}
  for _, q in ipairs(Api.questLog()) do
    inLog[q.questID] = true
  end
  local ctx = {
    inLog = function(id)
      return inLog[id] == true or taken[id] == true
    end,
    isDone = function(id)
      return Api.turnedIn(id) == true
    end,
  }
  for _, hub in ipairs(ns.Hubs.forZone(ns.HUBS, here.mapID, Api.faction(), here.level or 1)) do
    for _, q in ipairs(ns.Hubs.pending(hub, ctx)) do
      local title = Api.questTitle(q.questID) or (atlas.quests[q.questID] and atlas.quests[q.questID].title)
        or L["Quest %d"]:format(q.questID)
      local known = atlas.quests[q.questID] and atlas.quests[q.questID].start
      local spot = known and known.mapID == here.mapID and known or { mapID = hub.mapID, x = hub.x, y = hub.y }
      extra[#extra + 1] = { id = "arrive-q" .. q.questID, type = "accept", questID = q.questID,
        text = L["Pick up: "] .. title, mapID = spot.mapID, x = spot.x, y = spot.y,
        why = q.optional and L["%s - optional: elite or group quest"]:format(hub.name) or hub.name }
    end
  end
  if front == 0 and #extra == 0 then
    extra[#extra + 1] = { id = "arrive-quests-" .. here.mapID, type = "note",
      text = L["Pick up the quests here first"],
      why = L["New area: talk to the quest givers marked ! around you before heading out. TrailMate remembers "
        .. "them for next time."] }
  end
  local far, h = hearthElsewhere(here)
  if far and h then
    local place, name = Atlas.findNpc(atlas, "innkeeper", nil, Api.faction(), here)
    local step = { id = "arrive-hearth-" .. here.mapID, type = "note",
      text = name and L["Set your hearthstone at %s"]:format(name) or L["Set your hearthstone at the inn here"],
      why = L["You will level here and your hearthstone is in %s."]:format(h.name) }
    if place and place.mapID == here.mapID then
      step.mapID, step.x, step.y = place.mapID, place.x, place.y
    end
    extra[#extra + 1] = step
  end
  local added = 0
  for _, step in ipairs(extra) do
    -- Done or skipped once on this visit: not again (plans are rebuilt often).
    if not cdb.arrivalDone[step.id] then
      added = added + 1
      table.insert(p.steps, front + added, step)
    end
  end
  return #p.steps > 0 and p or nil
end

-- Remembers an arrival step done or skipped, for the rest of this visit.
local function arrivalStepDone(step)
  if step and type(step.id) == "string" and step.id:find("^arrive%-") then
    cdb.arrivalDone[step.id] = true
  end
end

-- Guides -------------------------------------------------------------------------

local function who()
  return { faction = Api.faction(), class = Api.class(), race = Api.race() }
end

local function guides()
  return ns.Guide.list(ns.GUIDES, who())
end

-- Where this character's account saw a guide step's quest giver (picked up
-- or handed in there), checked in the game: it replaces the data's place.
local function guidePlace(s)
  local q = atlas and atlas.quests[s.q]
  if not q then
    return nil
  end
  if s.t == "accept" then
    return q.start
  elseif s.t == "turnin" then
    return q.finish
  end
  return nil
end

local function guideFinished(g)
  return ns.Guide.finished(g, who(), function(id)
    return Api.turnedIn(id) == true
  end)
end

-- Follows the guide for this character (chosen, or by level): returns false
-- when there is none (guides off, or none for this faction), so the plan is
-- built from the quest log instead.
local lastGone = {} -- quests the guide left out, by name (for the self-test)
local function loadGuide(quiet, repick)
  if cdb.prefs.guide == false then
    return false
  end
  local list = guides()
  if #list == 0 then
    return false
  end
  -- The zone the player chose, else where the player is: a guide with a
  -- part there wins. A chosen zone with no guide for it gets a route from
  -- the quest log instead.
  local level, focus = Api.level() or 1, cdb.prefs.focusZone
  if focus and not cdb.guideName and not ns.Guide.forZone(list, level, focus, guideFinished) then
    return false
  end
  -- Rebuilt by itself (login, reload, a new quest): the guide being
  -- followed stays while it is not finished, so crossing into the next zone
  -- does not swap guides. Only "automatic" or choosing a zone (repick)
  -- looks again by zone.
  local chosen = cdb.guideName
  if not (chosen or repick or focus) and ns.Guide.isGuide(plan) then
    for _, g in ipairs(list) do
      if plan.title == g.name and not guideFinished(g) then
        chosen = g.name
      end
    end
  end
  local g = ns.Guide.pick(list, level, chosen, guideFinished, focus or Api.position())
  -- What this character has done decides which quests it can still pick
  -- up: a breadcrumb whose quest it took, or a quest that needs another
  -- one first, is left out.
  local inLog = {}
  for _, q in ipairs(Api.questLog()) do
    inLog[q.questID] = true
  end
  local p, gone = ns.Guide.toPlan(g, { who = who(), L = L, title = Api.knownQuestTitle, place = guidePlace,
    needs = ns.GUIDE_QUESTS, done = function(id) return Api.turnedIn(id) == true end,
    inLog = function(id) return inLog[id] == true end })
  local same = plan and plan.id == p.id
  loadPlan(p, true)
  local left = {}
  for q in pairs(gone) do
    left[#left + 1] = Api.knownQuestTitle(q) or L["Quest %d"]:format(q)
  end
  table.sort(left)
  lastGone = left
  if not (quiet or same) then
    say(L["Guide: %s (%d steps). Other guides: /tm guide."]:format(g.name, #p.steps))
    if #left > 0 then
      say(L["Left out, you can no longer pick them up: %s."]:format(table.concat(left, ", ")))
    end
  end
  return true
end

-- The guide followed now (by its name, the plan's title), or nil.
local function currentGuide(list)
  for _, g in ipairs(list) do
    if ns.Guide.isGuide(plan) and plan.title == g.name then
      return g
    end
  end
  return nil
end

function advanceGuide()
  local list = guides()
  local nextGuide = ns.Guide.after(list, currentGuide(list))
  if not nextGuide then
    say(L["Plan finished."])
    return
  end
  cdb.guideName = nextGuide.name
  say(L["Guide finished. Next: %s."]:format(nextGuide.name))
  loadGuide(true)
end

-- /tm guide: list the guides, choose one by number, next, auto, on, off.
local function guideCommand(rest)
  local word = (rest or ""):lower()
  local list = guides()
  if word == "off" or word == "no" then
    cdb.prefs.guide = false
    say(L["Guides off: the plan comes from your quest log."])
    buildFromQuestLog(false)
    return
  elseif word == "on" or word == "si" or word == "sí" or word == "auto" then
    cdb.prefs.guide, cdb.guideName = nil, nil
    buildFromQuestLog(false, true)
    return
  elseif word == "next" or word == "siguiente" then
    local nextGuide = ns.Guide.after(list, currentGuide(list))
    if nextGuide then
      cdb.prefs.guide, cdb.guideName = nil, nextGuide.name
      buildFromQuestLog(false)
    end
    return
  elseif tonumber(word) and list[tonumber(word)] then
    cdb.prefs.guide, cdb.guideName = nil, list[tonumber(word)].name
    buildFromQuestLog(false)
    return
  end
  if #list == 0 then
    say(L["No guide for your faction yet."])
    return
  end
  local now = currentGuide(list)
  say(L["Guides (/tm guide <number>, next, auto, off):"])
  for i, g in ipairs(list) do
    out(("  [%d] %s%s"):format(i, g.name, g == now and ("  |cffffd100<- " .. L["now"] .. "|r") or ""))
  end
end

-- Dungeons -----------------------------------------------------------------------

local function handedIn(id)
  return Api.turnedIn(id) == true
end

-- Yards from the player to a map point, or nil when it cannot tell.
local function yardsTo(p)
  local here, there = Api.playerWorld(), Api.worldPos(p.m, p.x, p.y)
  if not (here and there and here.cont == there.cont) then
    return nil
  end
  return math.sqrt((here.x - there.x) ^ 2 + (here.y - there.y) ^ 2)
end

-- /tm dungeon: the dungeons for your level; with a number, plan that one.
local function dungeonCommand(rest)
  local level = Api.level() or 1
  local now, nextOne = ns.Dungeons.forLevel(ns.DUNGEONS, who(), level)
  local d = now[tonumber(rest or "") or 0]
  if d then
    local p = ns.Dungeons.toPlan(d, { who = who(), level = level, done = handedIn, L = L, distance = yardsTo })
    if loadPlan(p, true) then
      local ready = ns.Dungeons.quests(d, who(), level, handedIn)
      say(L["Dungeon: %s. %d quests to pick up before going in."]:format(d.name, #ready))
    end
    return
  end
  if #now == 0 then
    say(L["No dungeon suits your level right now."])
  else
    say(L["Dungeons for your level (/tm dungeon <number> to go):"])
    for i, e in ipairs(now) do
      local ready, inside, later = ns.Dungeons.quests(e, who(), level, handedIn)
      local extra = (#inside > 0 and L[", %d start inside"]:format(#inside) or "")
        .. (#later > 0 and L[", %d later"]:format(#later) or "")
      out(L["  [%d] %s, enemies %d-%d: %d quests to pick up first%s"]:format(i, e.name, e.min, e.max, #ready, extra))
    end
  end
  if nextOne then
    out(L["Next dungeon: %s from level %d."]:format(nextOne.name, nextOne.min - ns.Dungeons.BELOW))
  end
end

-- The companion chat --------------------------------------------------------------

-- The character's state for the companion, as short lines of text: what
-- TrailMate already shows the player, no names. Sent with the first
-- question and again when it changes.
local function chatContext()
  local lines = {}
  local function add(fmt, ...)
    lines[#lines + 1] = fmt:format(...)
  end
  local xp, xpMax = Api.xp()
  add("Character: %s level %d, %s (%s), XP %d%%, %s.", tostring(Api.class()), Api.level() or 0,
    tostring(Api.race()), tostring(Api.faction()), xp and xpMax and xpMax > 0 and math.floor(xp / xpMax * 100) or 0,
    ns.formatMoney and ns.formatMoney(Api.money() or 0) or tostring(Api.money()))
  add("Where: %s.", table.concat(Api.zoneTexts(), " / "))
  local free, total = Api.bagSpace()
  add("Bags: %d of %d free.", free or 0, total or 0)
  if plan then
    local now = current and plan.steps[current]
    add("Plan: %s. Now: %s%s.", tostring(plan.title or plan.id), now and now.text or "finished",
      now and now.why and (" (" .. now.why .. ")") or "")
    local nextSteps = {}
    for i = (current or #plan.steps) + 1, math.min(#plan.steps, (current or 0) + 4) do
      nextSteps[#nextSteps + 1] = plan.steps[i].text
    end
    if #nextSteps > 0 then
      add("Then: %s.", table.concat(nextSteps, "; "))
    end
  end
  local quests = {}
  for i, q in ipairs(Api.questLog()) do
    if i > 6 then -- short: the whole context fits in two saves
      break
    end
    quests[#quests + 1] = ("[%s] %s%s"):format(tostring(q.level or "?"), tostring(q.title), q.complete and " (done)"
      or "")
  end
  if #quests > 0 then
    add("Quest log: %s.", table.concat(quests, ", "))
  end
  local talents = ns.TalentPanel.advice and ns.TalentPanel.advice()
  if talents and talents.groups[1] then
    add("Talents: %d to spend, build %s, next %s.", talents.points, L[talents.chosen.label],
      talents.groups[1].talent.name)
  end
  local now = ns.Dungeons.forLevel(ns.DUNGEONS, who(), Api.level() or 1)
  if #now > 0 then
    local names = {}
    for _, d in ipairs(now) do
      names[#names + 1] = ("%s %d-%d"):format(d.name, d.min, d.max)
    end
    add("Dungeons for this level: %s.", table.concat(names, ", "))
  end
  return table.concat(lines, "\n")
end

function buildFromQuestLog(quiet, repick)
  if loadGuide(quiet, repick) then
    return
  end
  local p, report = computeRoute()
  p = addArrivalSteps(p)
  lastCounts = report.counts or {}
  if p and (not quiet or (report.zone and report.zone ~= cdb.lastZone)) then
    quiet = false
  end
  if not p then
    plan, progress, current = nil, nil, nil
    cdb.plan, cdb.progress = nil, nil
    arrowStep = nil
    Api.clearArrow()
    refresh()
    if not quiet then
      say(L["Nothing worth doing in your quest log right now."])
      sayReport(report)
    end
    return
  end
  loadPlan(p, true)
  if not quiet then
    sayReport(report)
  end
  cdb.lastZone = report.zone
end

local function planHasQuest(questID)
  for _, step in ipairs(plan and plan.steps or {}) do
    if step.questID == questID then
      return true
    end
  end
  return false
end

local function clearPlan()
  plan, progress, current, statuses = nil, nil, nil, nil
  cdb.plan, cdb.progress = nil, nil
  arrowStep = nil
  Api.clearArrow()
  Api.unfocusQuest()
  refresh()
end

local function takeSnapshot()
  local xp, xpMax = Api.xp()
  local mapID, x, y = Api.position()
  local free, total = Api.bagSpace()
  local snap = ns.State.build({
    class = Api.class(), level = Api.level(), xp = xp, xpMax = xpMax, money = Api.money(),
    mapID = mapID, x = x, y = y, quests = Api.questLog(), items = Api.bagItems(),
    bagsFree = free, bagsTotal = total,
  }, time and time() or nil)
  cdb.snapshot = snap
  return snap
end

-- Finding NPCs the atlas knows ---------------------------------------------------

local FIND = {
  trainer = { role = "trainer", ownClass = true, label = "Trainer: %s" },
  instructor = { role = "trainer", ownClass = true, label = "Trainer: %s" },
  vendor = { role = "vendor", label = "Vendor: %s" },
  vendedor = { role = "vendor", label = "Vendor: %s" },
  repair = { role = "repair", label = "Repairs: %s" },
  reparar = { role = "repair", label = "Repairs: %s" },
  flight = { role = "flight", label = "Flight master: %s" },
  vuelo = { role = "flight", label = "Flight master: %s" },
}

local function backToPlan()
  if not detour then
    return
  end
  local marked = detour.marked
  if detour.zone then
    cdb.trip = nil -- the player leaves the trip
  end
  detour = nil
  arrowStep = false
  if marked then
    -- The game stops following the marked quest (the guide's own quest is
    -- followed again just below), so marking it again is a fresh click.
    Api.clearSuperTrack()
    -- Marked on the way to another zone: the trip goes on.
    local trip, here = cdb.trip, Api.position()
    if trip and here and here ~= trip.zone then
      travelTo(trip.zone, trip.name or "?")
      return
    end
  end
  refresh()
end

-- The player marked a quest (the game follows it now): the arrow goes there
-- and the window offers the way back to the guide.
local function followMark()
  local questID = Api.superTrackedQuest()
  local step = plan and current and plan.steps[current]
  if detour and detour.marked and step and questID == step.questID then
    backToPlan() -- marked the guide's own quest: back to it
    return
  end
  if detour and detour.marked == questID then
    return
  end
  local isMark = ns.Marked.isPlayerMark(questID, {
    ours = ourFocus, following = step and step.questID, now = Api.now(), quietUntil = quietUntil,
    questLog = facts().questLog,
  })
  if not isMark then
    return
  end
  detour = { marked = questID }
  if not updateMarked() then
    return
  end
  say(L["Arrow on the quest you marked: %s. The guide waits."]:format(detour.label))
  arrowStep = false
  updateTarget()
  render()
end

local function findNpc(rest)
  local what = FIND[(rest or ""):lower()] or FIND.trainer
  local point, name = Atlas.findNpc(atlas, what.role, what.ownClass and Api.class() or nil, Api.faction(),
    playerPoint())
  if not point then
    say(L["TrailMate has not seen one yet. Visit one and it will remember it."])
    return
  end
  local label = L[what.label]:format(name or "?")
  detour = { target = point, label = label }
  Api.setArrow(point, label, false)
  ns.Arrow.setTarget(point, label)
  say(("%s - %s"):format(label, Api.mapName(point.mapID) or ""))
end

-- Strategy ----------------------------------------------------------------------

local function zoneLine(i, z)
  local quests = z.quests > 0 and (", " .. L["%d quests in your log"]:format(z.quests)) or ""
  return ("[%d] %s (%d-%d) - %s%s"):format(i, Api.mapName(z.mapID) or z.name, z.min, z.max, L[z.difficulty], quests)
end

-- Works out the zone list (numbered for /tm zone) and the "coming up" text.
local function strategyList()
  local level = Api.level()
  if type(level) ~= "number" then
    return {}, "", false
  end
  local advice = ns.Strategy.advise(level, Api.faction(), playerPoint().mapID, lastCounts)
  lastZones = {}
  if advice.best then
    lastZones[1] = advice.best
  end
  for i = 1, math.min(#advice.options, 5) do
    lastZones[#lastZones + 1] = advice.options[i]
  end
  for _, z in ipairs(lastZones) do
    z.label = Api.mapName(z.mapID) or z.name
  end
  local soon = {}
  for _, z in ipairs(advice.upcoming) do
    soon[#soon + 1] = ("%s (%d)"):format(Api.mapName(z.mapID) or z.name, z.min)
  end
  local upcoming = #soon > 0 and L["Coming up: %s"]:format(table.concat(soon, ", ")) or ""
  return lastZones, upcoming, advice.leaveHere
end

local function sayStrategy()
  local level = Api.level()
  if type(level) ~= "number" then
    return
  end
  local zones, upcoming, leaveHere = strategyList()
  say(L["Strategy for level %d:"]:format(level))
  for i, z in ipairs(zones) do
    out("  " .. zoneLine(i, z))
  end
  if leaveHere then
    say(L["This zone is too easy for you now: time to move on."])
  end
  if upcoming ~= "" then
    say(upcoming)
  end
  say(L["Want another zone? /tm zone <number>. Back to automatic: /tm zone auto."])
  if not ns.Zones.VERIFIED_IN_FOREVER then
    say(L["Zone levels are the classic ones, not yet confirmed in Forever."])
  end
end

-- Travel ---------------------------------------------------------------------

local function nodeTarget(n)
  return { mapID = n.mapID, x = n.mx, y = n.my }
end

-- Where the hearthstone lands: a flight point with the bind's name, or the
-- place the atlas saw it land before.
local function hearthPlace(hearth, nodes)
  for _, n in ipairs(nodes) do
    if n.name:find(hearth.name, 1, true) == 1 then
      hearth.cont, hearth.x, hearth.y = n.cont, n.x, n.y
      n.known = true -- bound there, so its flight master was found too
      return
    end
  end
  local b = Atlas.bind(atlas, hearth.name)
  local w = b and Api.worldPos(b.mapID, b.x, b.y)
  if w then
    hearth.cont, hearth.x, hearth.y = w.cont, w.x, w.y
  end
end

-- Zeppelins and ships this character may take, with world positions.
local function shipLinks()
  local faction, links = Api.faction(), {}
  local function dock(d)
    local w = Api.worldPos(d.mapID, d.x, d.y)
    return w and { name = L[d.name], cont = w.cont, x = w.x, y = w.y, mapID = d.mapID, mx = d.x, my = d.y,
      dock = true }
  end
  for _, s in ipairs(ns.Travel.SHIPS) do
    if s.faction == nil or s.faction == faction then
      local a, b = dock(s.a), dock(s.b)
      if a and b then
        links[#links + 1] = { kind = s.kind, a = a, b = b }
      end
    end
  end
  return links
end

local function describeStep(s, name, hearth)
  if s.kind == "hearth" then
    return L["Use your hearthstone (%s)."]:format(hearth.name)
  elseif s.kind == "ship" and s.from then
    return L["Take the %s from %s to %s."]:format(L[s.ship], s.from.name, s.to.name)
  elseif s.kind == "walk" and s.to and s.to.dock then
    return L["Go to %s."]:format(s.to.name)
  elseif s.kind == "fly" then
    local note = ""
    if not (s.from.sure and s.to.sure) then
      note = " " .. L["(open any flight master once so TrailMate knows your flight points)"]
    elseif not s.confirmed then
      note = " " .. L["(route not confirmed yet)"]
    end
    return L["Fly from %s to %s."]:format(s.from.name, s.to.name) .. note
  elseif s.kind == "ship" then
    return L["%s is on another continent: take a zeppelin or a ship from a capital or port."]:format(name)
      .. (s.via and (" " .. L["Nearest flight master you know: %s."]:format(s.via.name)) or "")
  elseif s.to and s.to.name then
    return L["Go to the flight master: %s."]:format(s.to.name)
  end
  return L["Walk to %s."]:format(name)
end

-- Plans the quickest way to a zone with what the game says (flight points
-- learned and seen connected, hearthstone, continent). Changes nothing:
-- returns the trip, the lines to show and the first place to go.
local function planTrip(mapID, name)
  local p = playerPoint()
  local nodes = Api.flightNodes(cdb.learnedFlights)
  local hearth = Api.hearth()
  if hearth then
    hearthPlace(hearth, nodes)
  end
  local trip = ns.Travel.plan({
    here = p.mapID and p.x and Api.worldPos(p.mapID, p.x, p.y),
    dest = Api.worldPos(mapID, 0.5, 0.5),
    nodes = nodes,
    hearth = hearth,
    reach = function(a, b)
      return Atlas.reach(atlas, a.name, b.name)
    end,
    speed = (p.level or 1) >= 40 and ns.Travel.MOUNT or ns.Travel.RUN,
    ships = shipLinks(),
  })
  local lines, target, item = {}, nil, nil
  if trip then
    lines[1] = L["Route to %s (about %s):"]:format(name, ns.Travel.minutes(trip.cost))
    if trip.steps[1] and trip.steps[1].kind == "hearth" then
      item = Api.HEARTHSTONE -- first thing to do: a button to click
    end
    for _, s in ipairs(trip.steps) do
      lines[#lines + 1] = "- " .. describeStep(s, name, hearth)
      if not target and not item then
        if s.kind == "walk" then
          target = s.to.name and nodeTarget(s.to) or { mapID = mapID, x = 0.5, y = 0.5 }
        elseif s.kind == "ship" and s.via then
          target = nodeTarget(s.via)
        end
      end
    end
    -- Flights on a continent never checked at a flight master are not used.
    local dest = Api.worldPos(mapID, 0.5, 0.5)
    local checked = false
    for _, n in ipairs(nodes) do
      checked = checked or (dest and n.cont == dest.cont and n.sure)
    end
    if dest and not checked then
      lines[#lines + 1] = L["Open a flight master there once: TrailMate will then use your flights on that continent."]
    end
  else
    lines[1] = L["Travel to %s"]:format(name)
  end
  return trip, lines, target, item
end

-- Applies a trip: tells the player the steps and points the arrow at the
-- first place to go, until they arrive.
function travelTo(mapID, name)
  local _, lines, target, item = planTrip(mapID, name)
  travelLines = lines
  detour = {
    -- First the hearthstone: no place to point at, a stone to click.
    target = not item and (target or { mapID = mapID, x = 0.5, y = 0.5 }) or nil,
    item = item,
    label = lines[2] and lines[2]:sub(3) or lines[1],
    zone = mapID,
    zoneName = name,
  }
  -- Saved with the character, so a /reload or a new login on the way
  -- resumes the trip instead of dropping it.
  cdb.trip = { zone = mapID, name = name }
  updateTarget(true)
  for _, line in ipairs(lines) do
    say(line)
  end
  render()
  ns.Panel.refresh()
end

-- The player picks a zone: the route works there, and the travel planner
-- shows the quickest way to get there.
local function chooseZone(rest)
  -- Choosing a zone, or automatic, also lets go of a guide fixed before:
  -- the guide is picked again for that zone (or where the player is).
  if (rest or ""):lower() == "auto" then
    cdb.prefs.focusZone, cdb.guideName, cdb.trip = nil, nil, nil
    if detour and detour.zone then
      detour, arrowStep = nil, false
    end
    say(L["Zone choice back to automatic."])
    buildFromQuestLog(false, true)
    return
  end
  local z = lastZones[tonumber(rest) or 0]
  if not z then
    say(L["Type /tm strategy first, then /tm zone <number>."])
    return
  end
  cdb.prefs.focusZone, cdb.guideName = z.mapID, nil
  local name = Api.mapName(z.mapID) or z.name
  say(L["Next zone: %s."]:format(name))
  if Api.position() == z.mapID then
    -- Already here: start with the place's quests and the hearthstone.
    cdb.arrival, cdb.arrivalDone = z.mapID, {}
    buildFromQuestLog(false, true)
  elseif (lastCounts[z.mapID] or 0) == 0 then
    say(L["No quests of yours there yet: pick some up when you arrive."])
  else
    buildFromQuestLog(true, true)
  end
  if Api.position() ~= z.mapID then
    travelTo(z.mapID, name)
  end
end

-- Trainer ---------------------------------------------------------------------

local function adviseTrainer()
  local services = Api.trainerServices()
  Trainer.remember(cdb.trainerMemory, services)
  local results, spend = Trainer.advise(services, {
    class = Api.class(), level = Api.level(), money = Api.money(), prefs = cdb.prefs,
  }, L)
  lastAdvice = results
  if #results == 0 then
    say(L["Nothing new to learn here."])
    return
  end
  say(L["Trainer advice"] .. ":")
  for i, r in ipairs(results) do
    out(("  [%d] %s%s|r %s (%s) - %s"):format(i, COLORS[r.verdict] or "", L[r.verdict], r.name,
      ns.formatMoney(r.cost), r.reason))
  end
  say(L["Total to learn now: %s"]:format(ns.formatMoney(spend)))
  say(L["Not interested in one? /tm ignore <number>. Already learned? /tm learned <number>."])
  ns.Panel.refresh()
end

-- "3" means entry 3 of the last trainer list; anything else is a spell name.
local function pickSpell(rest)
  local n = tonumber(rest)
  if n then
    local r = lastAdvice[n]
    return r and r.key, r and r.name
  end
  if rest and rest ~= "" then
    return rest, rest
  end
  return nil
end

-- Near the end of a level: say what the trainer will have, once per level.
local function remindBeforeLevel()
  local level = Api.level()
  local xp, xpMax = Api.xp()
  if type(level) ~= "number" or warnedLevel[level] or not (xp and xpMax and xpMax > 0) or xp / xpMax < 0.9 then
    return
  end
  warnedLevel[level] = true
  local names = Trainer.newAtLevel(cdb.trainerMemory, level + 1, cdb.prefs.ignored)
  if #names > 0 then
    say(L["Almost level %d: your trainer will have %s."]:format(level + 1, table.concat(names, ", ")))
  end
end

-- What still needs doing outside the route: new trainer spells, talents.
local function trainerDue(level)
  return type(level) == "number" and level >= 2 and level % 2 == 0 and (cdb.trainerVisitedLevel or 0) < level
end

local ALERT_ICONS = {
  trainer = "Interface\\GossipFrame\\TrainerGossipIcon",
  talents = "Interface\\Icons\\Ability_Marksmanship",
  bags = "Interface\\GossipFrame\\VendorGossipIcon",
}
local bagsFree -- free slots when the bags are (almost) full, else nil

-- Reminders shown as bars under the step window until they are done.
local function alerts()
  local list = {}
  local level = Api.level()
  if trainerDue(level) then
    list[#list + 1] = { kind = "trainer", icon = ALERT_ICONS.trainer, cmd = "find trainer", action = L["Take me"],
      text = L["Level %d: new spells at your trainer"]:format(level) }
  end
  local points = Api.talentPoints()
  if points and points > 0 then
    local advice = ns.TalentPanel.advice()
    local first = advice and advice.groups[1]
    list[#list + 1] = { kind = "talents", icon = first and first.talent.icon or ALERT_ICONS.talents,
      cmd = "talents", action = L["Open"],
      text = first and L["Talent point: take %s"]:format(first.talent.name)
        or L["%d talent point(s) to spend"]:format(points) }
  end
  if bagsFree then
    list[#list + 1] = { kind = "bags", icon = ALERT_ICONS.bags, cmd = "find vendor", action = L["Take me"],
      text = L["Bags full (%d free): go and sell"]:format(bagsFree) }
  end
  return list
end

local shownAlerts = {}

-- Shows the reminders; a new one also flashes in the middle of the screen.
local function updateAlerts()
  local list, now = alerts(), {}
  for _, a in ipairs(list) do
    now[a.kind] = true
    if not shownAlerts[a.kind] then
      Api.notice("TrailMate: " .. a.text)
    end
  end
  shownAlerts = now
  ns.UI.setAlerts(list)
end
ns.onTalentsChanged = function()
  updateAlerts()
end

local function remindAtLevel(level)
  local names = Trainer.newAtLevel(cdb.trainerMemory, level, cdb.prefs.ignored)
  if #names > 0 then
    say(L["Level %d: your trainer now has %s."]:format(level, table.concat(names, ", ")))
  elseif trainerDue(level) then
    -- In classic, new class spells come at even levels.
    say(L["Level %d: new spells are usually waiting at your class trainer."]:format(level))
  end
  if #names > 0 or trainerDue(level) then
    if Atlas.findNpc(atlas, "trainer", Api.class(), Api.faction(), playerPoint()) then
      say(L["Type /tm find trainer and the arrow takes you there."])
    else
      say(L["Visit your trainer once and TrailMate will remember where it is."])
    end
  end
  local points = Api.talentPoints()
  if points and points > 0 then
    say(L["You have %d unspent talent point(s)."]:format(points))
  end
  updateAlerts()
end

-- Vendor ----------------------------------------------------------------------

local function adviseVendor()
  local results, value = ns.Bags.advise(Api.bagItems(), { prefs = cdb.prefs }, L)
  local sell, auction = {}, {}
  for _, r in ipairs(results) do
    local label = r.item.link or ("item:" .. r.item.itemID)
    if r.verdict == "sell" then
      sell[#sell + 1] = label
    elseif r.verdict == "auction" then
      auction[#auction + 1] = label
    end
  end
  local lines = { L["Vendor advice"] .. ":" }
  if #sell > 0 then
    lines[#lines + 1] = L["Sell for about %s: %s"]:format(ns.formatMoney(value), table.concat(sell, " "))
  else
    lines[#lines + 1] = L["Nothing to sell."]
  end
  if #auction > 0 then
    lines[#lines + 1] = L["Worth taking to the auction house: %s"]:format(table.concat(auction, " "))
  end
  for _, line in ipairs(lines) do
    say(line)
  end
  for i, line in ipairs(lines) do
    lines[i] = ns.Log.plain(line)
  end
  lastVendorLines = lines
  ns.Panel.refresh()
end

local function checkBags()
  local free = Api.bagSpace()
  if ns.Bags.shouldReturn(free, cdb.prefs) then
    if not warnedFull then
      say(L["Bags almost full (%d free): time to go back to a vendor."]:format(free))
      local _, name = Atlas.findNpc(atlas, "vendor", nil, Api.faction(), playerPoint())
      if name then
        say(L["Nearest vendor you know: %s. Type /tm find vendor."]:format(name))
      end
      warnedFull = true
    end
  else
    warnedFull = false
  end
  local full = warnedFull and free or nil
  if full ~= bagsFree then
    bagsFree = full
    updateAlerts()
  end
end

-- Slash commands ------------------------------------------------------------

local function yes(word)
  word = (word or ""):lower()
  return word == "on" or word == "yes" or word == "si" or word == "sí"
end

local HELP = {
  { "/tm questlog | diario", "Build a plan from your quest log" },
  { "/tm skip | salta", "Skip the current step" },
  { "/tm pick | elegir <n>", "Do step n of the list now" },
  { "/tm done | hecho", "Mark the current step as done" },
  { "/tm undo | deshaz", "Undo the last mark" },
  { "/tm trainer | instructor", "Advice at the open trainer" },
  { "/tm ignore | ignorar <n|name>", "Never recommend that spell again (all ranks)" },
  { "/tm learned | aprendido <n|name>", "Stop reminding a spell you already have" },
  { "/tm unignore | recuperar <name>", "Recommend an ignored spell again" },
  { "/tm ignored | ignorados", "List ignored spells" },
  { "/tm vendor | vender", "What to sell, keep or auction" },
  { "/tm find trainer|vendor|repair|flight", "Arrow to the nearest one TrailMate has seen" },
  { "/tm plan", "Arrow back to the plan" },
  { "/tm strategy | estrategia", "Best zones for your level, with difficulty" },
  { "/tm zone <n>|auto  (zona)", "Choose the zone to level in, or let TrailMate choose" },
  { "/tm status | estado", "Character summary" },
  { "/tm tracking on|off  (rastreos si|no)", "Skip hunter tracking spells" },
  { "/tm reserve | reserva <gold>", "Gold the trainer advice never spends" },
  { "/tm arrow | flecha on|off", "Show or hide the arrow" },
  { "/tm arrow | flecha top|center  (arriba|centro)", "Bring the arrow back to the top or the middle of the screen" },
  { "/tm trail | rastro on|off|show|export|clear", "Learn the ways you walk and follow them (dots on the map)" },
  { "/tm guide | guia [number|next|auto|off]", "Quest guides: list, choose one, or plan from your quest log" },
  { "/tm dungeon | mazmorra [number]", "Dungeons by level: list, or plan one (quests first, then the entrance)" },
  { "/tm chat [question]", "Talk to your AI companion (needs trailmate-bridge on your PC)" },
  { "/tm talents | talentos", "Open your talents and say the next one" },
  { "/tm companion | compañero claude|chatgpt|none", "Icon colour of your AI companion" },
  { "/tm auto on|off", "Rebuild the plan by itself when it ends" },
  { "/tm show | hide  (mostrar | ocultar)", "Show or hide the window" },
  { "/tm minimap | minimapa", "Show or hide the minimap button" },
  { "/tm options | opciones", "TrailMate's page in Esc > Options > AddOns" },
  { "/tm clear | borrar", "Remove the plan" },
  { "/tm diag", "What this client exposes (for bug reports)" },
  { "/tm test | selftest", "Run the self-test and write it to the log" },
}

local COMMANDS = {}
local function alias(names, fn)
  for _, n in ipairs(names) do
    COMMANDS[n] = fn
  end
end

alias({ "questlog", "diario" }, function()
  buildFromQuestLog(false)
end)
alias({ "skip", "salta" }, function()
  local step = plan and Plan.skip(plan, progress, facts())
  if step then
    arrivalStepDone(step)
    say(L["Skipped: %s"]:format(step.text))
  end
  refresh()
end)
alias({ "pick", "elegir" }, function(rest)
  local step = plan and Plan.choose(plan, progress, facts(), tonumber(rest) or 0)
  if step then
    say(L["Now: %s"]:format(step.text))
    arrowStep = false
  end
  refresh()
end)
alias({ "done", "hecho" }, function()
  local step = plan and Plan.markDone(plan, progress, facts())
  if step then
    arrivalStepDone(step)
    say(L["Marked as done: %s"]:format(step.text))
  end
  refresh()
end)
alias({ "undo", "deshaz" }, function()
  local id = progress and Plan.undo(progress)
  local text
  for _, step in ipairs(id and plan and plan.steps or {}) do
    if step.id == id then
      text = step.text
    end
  end
  say(text and L["Undone: %s"]:format(text) or (id and L["Undone."]) or L["Nothing to undo."])
  refresh()
end)
alias({ "trainer", "instructor" }, adviseTrainer)
alias({ "ignore", "ignorar" }, function(rest)
  local key, name = pickSpell(rest)
  if not key then
    say(L["Which one? Use the number from the trainer list or the spell name."])
    return
  end
  cdb.prefs.ignored[key] = true
  say(L["Ignored: %s. It will not be recommended again."]:format(name))
end)
alias({ "unignore", "recuperar" }, function(rest)
  local key, name = pickSpell(rest)
  if key and cdb.prefs.ignored[key] then
    cdb.prefs.ignored[key] = nil
    say(L["%s will be recommended again."]:format(name))
  else
    say(L["Not in your ignored list."])
  end
end)
alias({ "ignored", "ignorados" }, function()
  local names = {}
  for key in pairs(cdb.prefs.ignored) do
    names[#names + 1] = key
  end
  table.sort(names)
  say(#names > 0 and table.concat(names, ", ") or L["Not in your ignored list."])
end)
alias({ "learned", "aprendido" }, function(rest)
  local n = tonumber(rest)
  local name = n and lastAdvice[n] and lastAdvice[n].name or rest
  if name and cdb.trainerMemory[name] then
    cdb.trainerMemory[name] = nil
    say(L["Marked as learned: %s"]:format(name))
  else
    say(L["Which one? Use the number from the trainer list or the spell name."])
  end
end)
alias({ "vendor", "vender" }, adviseVendor)
alias({ "talents", "talentos" }, function()
  if not Api.openTalents() then
    say(L["Open your talents with the N key (not in combat)."])
  end
  local advice = ns.TalentPanel.advice()
  local first = advice and advice.groups[1]
  if first then
    say(L["Next talent: %s (%s)."]:format(first.talent.name, advice.tabs[advice.chosen.tree].name))
  end
end)
alias({ "find", "buscar" }, findNpc)
alias({ "plan" }, backToPlan)
alias({ "strategy", "estrategia" }, sayStrategy)
alias({ "zone", "zona" }, chooseZone)
alias({ "status", "estado" }, function()
  for _, line in ipairs(ns.State.summary(takeSnapshot(), L)) do
    say(line)
  end
end)
alias({ "tracking", "rastreos" }, function(rest)
  cdb.prefs.skipTracking = not yes(rest)
  say(L["Tracking spells: %s"]:format(cdb.prefs.skipTracking and L["skip"] or L["learn"]))
end)
alias({ "reserve", "reserva" }, function(rest)
  local gold = tonumber(rest) or 0
  cdb.prefs.reserve = math.max(0, math.floor(gold * 10000))
  say(L["Reserve set to %s."]:format(ns.formatMoney(cdb.prefs.reserve)))
end)
-- Which AI companion talks to the player: only changes the icon's glow for
-- now; the chat bridge will set it by itself.
local COMPANIONS = { claude = "claude", chatgpt = "chatgpt", gpt = "chatgpt", openai = "chatgpt" }
alias({ "companion", "companero", "compañero" }, function(rest)
  local kind = ns.Theme.setCompanion(COMPANIONS[(rest or ""):lower()])
  cdb.prefs.companion = kind ~= "none" and kind or nil
  say(L["Companion: %s."]:format(kind == "none" and L["none"] or kind))
end)
alias({ "guide", "guia", "guía" }, guideCommand)
alias({ "dungeon", "dungeons", "mazmorra", "mazmorras" }, dungeonCommand)
alias({ "chat", "charla" }, function(rest)
  local word = (rest or ""):lower()
  if word == "diag" then
    for _, line in ipairs(ns.Chat.diag()) do
      out("  " .. line)
    end
  elseif word == "local" then
    ns.Chat.setLocal(true)
    say(L["Key bindings are kept on this PC now, so the chat can use them. Back to Blizzard's servers: /tm chat sync."])
  elseif word == "sync" then
    ns.Chat.setLocal(false)
    say(L["Key bindings sync with Blizzard again. The chat needs /tm chat local to work."])
  elseif rest and rest ~= "" then
    ns.Chat.create()
    ns.Chat.frame:Show()
    ns.Chat.ask(rest)
  else
    ns.Chat.toggle()
  end
end)
alias({ "trail", "rastro" }, function(rest)
  local word = (rest or ""):lower()
  if word == "clear" or word == "borrar" then
    TrailMateDB.trails = nil
    trails, trailPrev, lastPath = ns.Trails.ensure(TrailMateDB), nil, nil
    ns.Arrow.setVia(nil)
    ns.MapTrail.show(nil)
    say(L["Walked trails cleared."])
    return
  end
  if word == "export" or word == "exportar" then
    -- The dots around the player, as text in the Log tab (not in the chat:
    -- it is long), in pieces "TMR1 k/n ...", to ship them with the addon.
    local here = Api.playerWorld()
    if not here then
      say(L["Position unknown here"])
      return
    end
    local text, count = ns.Trails.export(trails, here.cont, here.x, here.y, 1500)
    local size = 200
    local pieces = math.ceil(#text / size)
    for k = 1, pieces do
      ns.Log.add(TrailMateDB.log, ("TMR1 %d/%d %s"):format(k, pieces, text:sub((k - 1) * size + 1, k * size)),
        date and date("%H:%M") or nil)
    end
    say(L["%d dots around you exported to the Log tab (%d lines). Copy the Log tab and send it."]:format(count,
      pieces))
    return
  end
  if word == "show" or word == "ver" then
    showLearned = not showLearned
    lastPath = nil
    say(showLearned and L["The world map now shows every dot learned around you. Again to go back to the route."]
      or L["The world map shows the route again."])
    followTrail()
    return
  end
  if word ~= "" then
    cdb.prefs.trails = yes(word)
  end
  local nodes, links = ns.Trails.counts(trails)
  say(L["Trails: %s, %d dots and %d joins learned."]:format(cdb.prefs.trails == false and L["off"] or L["on"],
    nodes, links))
end)
local ARROW_PLACES = { top = "top", arriba = "top", center = "center", centre = "center", centro = "center" }

alias({ "arrow", "flecha" }, function(rest)
  local where = ARROW_PLACES[(rest or ""):lower()]
  if where then
    -- Bring it back where it can be seen (and turn it on).
    cdb.arrow.disabled = false
    ns.Arrow.place(where)
    say(where == "top" and L["Arrow moved to the top of the screen."] or L["Arrow moved to the middle of the screen."])
  else
    cdb.arrow.disabled = not yes(rest)
  end
  ns.Arrow.update()
end)
alias({ "auto" }, function(rest)
  cdb.prefs.autoPlan = yes(rest)
end)
alias({ "show", "mostrar" }, function()
  ns.UI.setShown(true)
end)
alias({ "hide", "ocultar" }, function()
  ns.UI.setShown(false)
end)
alias({ "clear", "borrar" }, clearPlan)
alias({ "diag" }, function()
  local lines = Api.diagnose()
  TrailMateDB.diag = lines
  for _, line in ipairs(lines) do
    say(line)
  end
end)

local function version()
  local fn = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  local ok, v = pcall(fn, addonName, "Version")
  return ok and v or "?"
end

alias({ "help", "ayuda" }, function()
  say(("%s %s - %s"):format("TrailMate", version(), L["Commands"]))
  for _, h in ipairs(HELP) do
    out(("  %s  - %s"):format(h[1], L[h[2]]))
  end
end)
alias({ "panel" }, function()
  ns.Panel.toggle()
end)
alias({ "options", "opciones" }, function()
  if not ns.Options.open() then
    say(L["Find TrailMate in Esc > Options > AddOns."])
  end
end)

-- The minimap button: shown or hidden, remembered per character.
local function toggleMinimapButton()
  local b = ns.MinimapButton.button
  cdb.minimap.hidden = not cdb.minimap.hidden
  if b then
    b:SetShown(not cdb.minimap.hidden)
  end
end
alias({ "minimap", "minimapa" }, toggleMinimapButton)

SLASH_TRAILMATE1 = "/tm"
SLASH_TRAILMATE2 = "/trailmate"
SlashCmdList.TRAILMATE = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
  cmd = (cmd or ""):lower()
  if cmd == "" then
    if ns.Panel.frame then
      guard("panel", ns.Panel.toggle)
    else
      say(L["The panel could not be built: type /tm test and send the log."])
      COMMANDS.help()
    end
    return
  end
  local fn = COMMANDS[cmd] or COMMANDS.help
  guard("/tm " .. cmd, fn, rest)
end

-- Self-test ---------------------------------------------------------------------

local function count(t)
  local n = 0
  for _ in pairs(type(t) == "table" and t or {}) do
    n = n + 1
  end
  return n
end

-- Checks everything that can be checked without the player doing anything,
-- and writes PASS / FAIL lines to the log. It changes nothing: the route and
-- the trip are computed but not applied, and the panel is left as it was.
local function selfTest()
  local passed, failed = 0, 0
  local function check(name, fn)
    local ok, good, detail = pcall(fn)
    if ok and good then
      passed = passed + 1
      say(("[PASS] %s: %s"):format(name, tostring(detail)))
    else
      failed = failed + 1
      say(("[FAIL] %s: %s"):format(name, tostring(ok and detail or good)))
    end
  end
  say(L["Self-test started (nothing is changed)."])
  local p = playerPoint()

  check("client", function()
    local client, build, _, toc = GetBuildInfo()
    return true, ("%s build %s interface %s locale %s, TrailMate %s"):format(tostring(client), tostring(build),
      tostring(toc), tostring(GetLocale()), version())
  end)
  check("character", function()
    local xp, xpMax = Api.xp()
    return Api.class() ~= nil, ("%s level %s %s, XP %s/%s"):format(tostring(Api.class()), tostring(p.level),
      tostring(Api.faction()), tostring(xp), tostring(xpMax))
  end)
  check("position", function()
    return p.mapID ~= nil and p.x ~= nil, ("map %s (%s) at %s, %s"):format(tostring(p.mapID),
      tostring(p.mapID and Api.mapName(p.mapID)), tostring(p.x), tostring(p.y))
  end)
  check("map size and facing", function()
    local w, h = Api.mapSize(p.mapID)
    local facing = Api.facing()
    return w ~= nil and facing ~= nil, ("%s x %s yards, facing %s"):format(tostring(w), tostring(h), tostring(facing))
  end)
  check("route", function()
    local route, report, quests = computeRoute()
    local fromGame, fromAtlas, unknown = 0, 0, 0
    for _, q in ipairs(quests) do
      if Api.questTarget(q.questID) then
        fromGame = fromGame + 1
      elseif q.target then
        fromAtlas = fromAtlas + 1
      else
        unknown = unknown + 1
      end
    end
    return true, ("%d quests (place from game %d, atlas %d, unknown %d); zone %s, %d steps, not now %d, later %d")
      :format(#quests, fromGame, fromAtlas, unknown, tostring(report.zone), route and #route.steps or 0,
        #report.notNow, #report.later)
  end)
  local zones
  check("strategy", function()
    zones = strategyList()
    local names = {}
    for i, z in ipairs(zones) do
      names[#names + 1] = ("%d.%s %s"):format(i, z.label, z.difficulty)
    end
    return #zones > 0, table.concat(names, ", ")
  end)
  check("flight points", function()
    local nodes, known, sure = Api.flightNodes(cdb.learnedFlights), 0, 0
    local states, factions = {}, {}
    for _, n in ipairs(nodes) do
      known = known + (n.known and 1 or 0)
      sure = sure + (n.sure and 1 or 0)
      states[tostring(n.state)] = (states[tostring(n.state)] or 0) + 1
      factions[tostring(n.faction)] = (factions[tostring(n.faction)] or 0) + 1
    end
    local function show(t)
      local parts = {}
      for k, v in pairs(t) do
        parts[#parts + 1] = k .. "=" .. v
      end
      table.sort(parts)
      return table.concat(parts, " ")
    end
    local saved = {}
    for cont, set in pairs(cdb.learnedFlights or {}) do
      saved[tostring(cont)] = count(set)
    end
    return #nodes > 0, ("%d of your faction, %d known (%d checked at a flight master); routes seen at %d flight "
      .. "masters; states {%s} factions {%s}; saved by continent {%s}; taxi map %s"):format(#nodes, known, sure,
      count(atlas.flights), show(states), show(factions), show(saved), tostring(Api.taxiMapID()))
  end)
  check("hearthstone", function()
    local h = Api.hearth()
    return h ~= nil, h and ("%s, %s"):format(h.name, h.ready and "ready" or ("%d s left"):format(h.cooldown))
      or "no bind location"
  end)
  check("travel", function()
    local z
    for _, candidate in ipairs(zones or {}) do
      if candidate.mapID ~= p.mapID then
        z = candidate
        break
      end
    end
    if not z then
      return true, "no other zone to test"
    end
    local trip, lines = planTrip(z.mapID, z.label)
    return trip ~= nil, table.concat(lines, " ")
  end)
  check("atlas", function()
    local npcs, known = Atlas.counts(atlas)
    local finds = {}
    for _, role in ipairs({ "trainer", "vendor", "repair", "flight" }) do
      local _, name = Atlas.findNpc(atlas, role, role == "trainer" and Api.class() or nil, Api.faction(), p)
      finds[#finds + 1] = ("%s=%s"):format(role, tostring(name))
    end
    return true, ("%d npcs, %d quests, %d binds; nearest %s"):format(npcs, known, count(atlas.binds),
      table.concat(finds, " "))
  end)
  check("talents", function()
    local points = Api.talentPoints()
    local advice = ns.TalentPanel.advice()
    local first = advice and advice.groups[1]
    local summary = advice and ("template %s, next %s"):format(advice.chosen.id, first and first.talent.name or "none")
      or "no trees read"
    return points ~= nil and advice ~= nil, ("unspent %s, %s || %s"):format(tostring(points), summary,
      table.concat(Api.talentReport(), " || "))
  end)
  check("trainer memory", function()
    return true, ("%d spells remembered, %d ignored"):format(count(cdb.trainerMemory), count(cdb.prefs.ignored))
  end)
  check("bags", function()
    local results = ns.Bags.advise(Api.bagItems(), { prefs = cdb.prefs }, L)
    local verdicts = { sell = 0, keep = 0, auction = 0 }
    for _, r in ipairs(results) do
      verdicts[r.verdict] = verdicts[r.verdict] + 1
    end
    local free, total = Api.bagSpace()
    return #results > 0, ("%d items: sell %d, keep %d, auction %d; %d of %d slots free"):format(#results,
      verdicts.sell, verdicts.keep, verdicts.auction, free, total)
  end)
  check("arrow", function()
    ns.Arrow.update()
    local f, t = ns.Arrow.frame, ns.Arrow.target
    return true, ("%s (art: %s) target %s shown %s icon %s says %s item %s"):format(
      tostring(ns.Arrow.labelText), tostring(ns.Arrow.art), t and ("%s %.3f %.3f"):format(t.mapID, t.x, t.y) or "none",
      tostring(f and f:IsShown()), tostring(f and f.icon:IsShown()), tostring(f and f.distance:GetText()),
      tostring(ns.ItemButton.current()))
  end)
  check("guide", function()
    local list = guides()
    local now = currentGuide(list)
    local places, quests = 0, 0
    for _, s in ipairs(plan and plan.steps or {}) do
      if s.questID then
        quests = quests + 1
        places = places + (s.mapID and 1 or 0)
      end
    end
    return true, ("%s; %d guides for you; now %s, %d quest steps with a place of %d; step %s; left out %d%s"):format(
      cdb.prefs.guide == false and "off" or "on", #list, now and now.name or "none (quest log plan)", places, quests,
      tostring(current), #lastGone, #lastGone > 0 and (" (" .. table.concat(lastGone, ", ") .. ")") or "")
  end)
  check("dungeons", function()
    local level = Api.level() or 1
    local now, nextOne = ns.Dungeons.forLevel(ns.DUNGEONS, who(), level)
    local list = {}
    for _, d in ipairs(now) do
      local ready = ns.Dungeons.quests(d, who(), level, handedIn)
      list[#list + 1] = ("%s %d-%d (%d quests)"):format(d.name, d.min, d.max, #ready)
    end
    return #(ns.DUNGEONS or {}) > 0, ("%d in data; for level %d: %s; next %s; plan is a dungeon: %s"):format(
      #(ns.DUNGEONS or {}), level, #list > 0 and table.concat(list, ", ") or "none",
      nextOne and nextOne.name or "none", tostring(ns.Dungeons.isDungeon(plan)))
  end)
  check("chat", function()
    -- What the link needs from the client, and whether the inboxes exist.
    local link = ns.Chat.link
    local info = (C_AddOns and C_AddOns.GetAddOnInfo) or rawget(_G, "GetAddOnInfo")
    -- name, title, notes, loadable, reason
    local ok, name, _, _, _, reason = pcall(info or error, ns.Link.inbox(1))
    local first = ok and name ~= nil and reason ~= "MISSING"
    local apis = type(rawget(_G, "SetBinding")) == "function" and type(rawget(_G, "SaveBindings")) == "function"
      and type(rawget(_G, "GetBindingAction")) == "function"
    return link ~= nil and apis, ("session %s, status %s, slot %s; bindings API %s; inbox 1 %s"):format(
      tostring(link and link.session), tostring(link and link.status), tostring(link and link.slot), tostring(apis),
      first and "present" or ("missing (" .. tostring(reason) .. "): run trailmate-bridge init"))
  end)
  check("trails", function()
    local nodes, links = ns.Trails.counts(trails)
    local canvas, _, drawn = ns.MapTrail.state()
    local here = Api.playerWorld()
    return true, ("%s; %d dots, %d joins; route to the arrow target %s; world map canvas %s, %d dots drawn; here %s")
      :format(cdb.prefs.trails == false and "off" or "on", nodes, links,
        lastPath and (#lastPath .. " dots") or ("none: " .. tostring(lastWhy)),
        canvas and "found" or "not found", drawn,
        here and ("%s %.0f %.0f"):format(here.cont, here.x, here.y) or "unknown")
  end)
  check("quest highlight", function()
    local ok = C_SuperTrack ~= nil and type(C_SuperTrack.SetSuperTrackedQuestID) == "function"
    return ok, ok and "available" or "missing"
  end)
  check("map marks", function()
    -- TrailMate's own marks: no other addon is used, even when installed.
    local pin = ns.MinimapPin
    return true, ("minimap %s%s; world map target %s"):format(tostring(pin.state or "hidden"),
      pin.state and pin.state ~= "hidden" and (" at %.0f, %.0f"):format(pin.x or 0, pin.y or 0) or "",
      ns.MapTrail.mark and ns.MapTrail.mark.pin:IsShown() and "shown" or "not drawn (open the map)")
  end)
  check("panel", function()
    local shown, tab = ns.Panel.frame:IsShown(), ns.Panel.current
    for _, name in ipairs({ "Route", "Zones", "Trainer", "Bags", "Log" }) do
      ns.Panel.show(name)
    end
    ns.Panel.show(tab or "Route")
    if not shown then
      ns.Panel.frame:Hide()
    end
    return true, "all tabs drawn"
  end)
  say(L["Self-test done: %d passed, %d failed. Copy the Log tab and send it."]:format(passed, failed))
end

alias({ "selftest", "test" }, selfTest)

-- What the panel reads. It never changes state itself: its buttons run commands.
local function routeLines()
  local lines = {}
  if not plan then
    lines[1] = L["No plan loaded. Type /tm questlog to build one from your quest log."]
  elseif not current then
    lines[1] = L["Plan finished."]
  else
    local step = plan.steps[current]
    lines[#lines + 1] = L["Step %d of %d"]:format(current, #plan.steps) .. ": " .. step.text
    if step.why then
      lines[#lines + 1] = "   " .. step.why
    end
    local shown = 0
    for i = current + 1, #plan.steps do
      if statuses and statuses[i] == "pending" and shown < 6 then
        lines[#lines + 1] = "- " .. plan.steps[i].text
        shown = shown + 1
      end
    end
  end
  if detour then
    lines[#lines + 1] = ""
    for _, line in ipairs(detour.zone and travelLines or { L["Arrow: %s"]:format(detour.label) }) do
      lines[#lines + 1] = line
    end
  end
  lines[#lines + 1] = ""
  for _, line in ipairs(lastReportLines) do
    lines[#lines + 1] = line
  end
  return lines
end

ns.Main = {
  routeLines = routeLines,
  strategy = function()
    local zones, upcoming = strategyList()
    return zones, upcoming
  end,
  trainerAdvice = function()
    return lastAdvice
  end,
  prefs = function()
    return cdb and cdb.prefs or {}
  end,
  vendorLines = function()
    return lastVendorLines
  end,
  logText = function()
    return ns.Log.text(TrailMateDB and TrailMateDB.log)
  end,
  clearLog = function()
    if TrailMateDB then
      TrailMateDB.log = {}
    end
  end,
}

-- Click on TrailMate in the game's addon compartment (the minimap addons list).
function TrailMate_OnAddonCompartmentClick()
  ns.Panel.toggle()
end

-- Events ----------------------------------------------------------------------

local frame = CreateFrame("Frame")
local handlers = {}

-- Right after a quest is taken, handed in or dropped (and at login), the game
-- may choose a quest to follow by itself: that is not a mark of the player's.
local function quiet(seconds)
  local now = Api.now()
  if now then
    quietUntil = math.max(quietUntil or 0, now + seconds)
  end
end

handlers.ADDON_LOADED = function(name)
  if name ~= addonName then
    -- The game's talent window loads on demand: dock the talent plan to it.
    if cdb then
      ns.TalentPanel.attach()
    end
    return
  end
  TrailMateDB = TrailMateDB or {}
  TrailMateCharDB = TrailMateCharDB or {}
  cdb = TrailMateCharDB
  atlas = Atlas.ensure(TrailMateDB)
  trails = ns.Trails.ensure(TrailMateDB)
  -- The capitals' ways that ship with the addon, once per data version.
  local routes = ns.ROUTES
  if routes and (trails.seeded or 0) < (routes.version or 0) then
    for _, text in ipairs(routes) do
      local data = ns.Trails.parse(text)
      if data then
        guard("built-in trails", ns.Trails.import, trails, data)
      end
    end
    trails.seeded = routes.version
  end
  cdb.prefs = cdb.prefs or {}
  cdb.prefs.ignored = cdb.prefs.ignored or {}
  cdb.trainerMemory = cdb.trainerMemory or {}
  cdb.ui = cdb.ui or {}
  cdb.arrow = cdb.arrow or {}
  cdb.panel = cdb.panel or {}
  cdb.minimap = cdb.minimap or {}
  cdb.talents = cdb.talents or {}
  cdb.chat = cdb.chat or {}
  cdb.arrivalDone = cdb.arrivalDone or {}
  TrailMateDB.log = TrailMateDB.log or {}
  ns.setLocale(GetLocale and GetLocale() or "enUS")
  -- Each part on its own: one failing leaves the others working.
  local window = guard("window", ns.UI.create, cdb.ui)
  local arrow = guard("arrow", ns.Arrow.create, cdb.arrow, L)
  guard("item button", ns.ItemButton.create, window, arrow)
  guard("panel", ns.Panel.create, cdb.panel, L)
  guard("minimap button", ns.MinimapButton.create, cdb.minimap, L, ns.Panel.toggle, function()
    ns.UI.setShown(cdb.ui.hidden == true)
  end)
  guard("options page", ns.Options.create, L, {
    panel = ns.Panel.toggle,
    steps = function()
      ns.UI.setShown(cdb.ui.hidden == true)
    end,
    minimap = toggleMinimapButton,
    arrowTop = function()
      COMMANDS.arrow("top")
    end,
    arrowCenter = function()
      COMMANDS.arrow("center")
    end,
    help = COMMANDS.help,
    version = version,
  })
  guard("icon", ns.Theme.setCompanion, cdb.prefs.companion)
  guard("talent plan", ns.TalentPanel.init, cdb.talents, L)
  guard("talent plan", ns.TalentPanel.attach)
  guard("chat", ns.Chat.init, cdb.chat, L, chatContext)
  if cdb.plan then
    guard("plan", loadPlan, cdb.plan, true)
  else
    guard("plan", refresh)
  end
end

-- On login and /reload, an automatic plan is rebuilt from the current quest
-- log (once the log has loaded), so an old plan never lingers.
local rebuildPending = false

handlers.PLAYER_ENTERING_WORLD = function(isLogin, isReload)
  if cdb then
    quiet(ns.Marked.QUIET_LOGIN)
    arrowStep = false
    updateAlerts()
    -- A guide is reloaded too (the guide data may be newer), and with no
    -- plan at all the guide for the character starts by itself.
    local guided = (plan == nil or ns.Guide.isGuide(plan)) and cdb.prefs.guide ~= false
    if (isLogin or isReload or isLogin == nil) and (guided or (plan and Builder.isAuto(plan)))
      and cdb.prefs.autoPlan ~= false then
      rebuildPending = true
    end
    -- A trip to another zone saved before the /reload or the logout: go on
    -- with it from here, unless the player already got there.
    if cdb.trip and not detour then
      after(2, function()
        local trip, here = cdb.trip, Api.position()
        if not trip or detour or not here then
          return
        end
        if here == trip.zone then
          cdb.trip = nil
        else
          guard("trip", travelTo, trip.zone, trip.name or "?")
        end
      end)
    end
    questThrottle:mark()
  end
end

local function questChanged()
  questThrottle:mark()
end

handlers.QUEST_LOG_UPDATE = function()
  if rebuildPending then
    rebuildPending = false
    after(1, function()
      cdb.lastZone = nil
      buildFromQuestLog(true)
    end)
  end
  questChanged()
end

handlers.QUEST_REMOVED = function()
  quiet(ns.Marked.QUIET)
  questChanged()
end

handlers.SUPER_TRACKING_CHANGED = function()
  if cdb then
    -- Read a moment later: TrailMate's own choice may still be on its way.
    after(0.2, function()
      guard("marked quest", followMark)
    end)
  end
end

handlers.ZONE_CHANGED_NEW_AREA = function()
  -- Left the zone just arrived in: the arrival guide is over.
  if cdb and cdb.arrival and Api.position() ~= cdb.arrival then
    cdb.arrival, cdb.arrivalDone = nil, {}
  end
  -- Just used the hearthstone: learn where it lands.
  if hearthing then
    hearthing = false
    after(2, function()
      local h = Api.hearth()
      if h then
        Atlas.recordBind(atlas, h.name, playerPoint())
      end
    end)
  end
  -- On the way to a chosen zone: plan again from here (after a flight or the hearthstone).
  if detour and detour.zone and Api.position() ~= detour.zone then
    after(2, function()
      if detour and detour.zone then
        travelTo(detour.zone, detour.zoneName or "?")
      end
    end)
  end
  questChanged()
end

handlers.UNIT_SPELLCAST_SUCCEEDED = function(unit, _, spellID)
  if unit == "player" and spellID == 8690 then -- Hearthstone
    hearthing = true
  end
end

handlers.QUEST_ACCEPTED = function(a, b)
  local questID = b or a
  quiet(ns.Marked.QUIET)
  -- Learn who gave it and where.
  local q = questInfo(questID)
  local npc = Api.npc()
  Atlas.recordStart(atlas, questID, {
    title = q and q.title, level = q and q.level, npcID = npc and npc.id, faction = Api.faction(),
  }, playerPoint())
  if npc then
    learnNpc("quest")
  end
  -- A quest picked up outside the plan: rebuild an automatic plan so it joins.
  if plan and Builder.isAuto(plan) and cdb.prefs.autoPlan ~= false and not planHasQuest(questID) then
    after(0.5, function()
      buildFromQuestLog(true)
    end)
  end
  questChanged()
end

handlers.QUEST_TURNED_IN = function(questID)
  quiet(ns.Marked.QUIET)
  local npc = Api.npc()
  Atlas.recordFinish(atlas, questID, { npcID = npc and npc.id }, playerPoint())
  if npc then
    learnNpc("quest")
  end
  lastProgress[questID] = nil
  questChanged()
end

handlers.PLAYER_LEVEL_UP = function(level)
  questChanged()
  if type(level) == "number" and cdb then
    remindAtLevel(level)
  end
end

handlers.TRAINER_SHOW = function()
  backToPlan()
  if Api.isProfessionTrainer() then
    learnNpc("profession")
  else
    learnNpc("trainer", Api.class())
    cdb.trainerVisitedLevel = Api.level()
    updateAlerts()
  end
  after(0.3, adviseTrainer)
end
-- A talent was taken (or placed before "Apply Changes"): next advice.
local function talentsChanged()
  if cdb then
    ns.TalentPanel.refresh()
    updateAlerts()
  end
end
handlers.CHARACTER_POINTS_CHANGED = talentsChanged
handlers.PLAYER_TALENT_UPDATE = talentsChanged
handlers.PREVIEW_TALENT_POINTS_CHANGED = talentsChanged
-- Talking to a quest giver: learn every quest offered (not only the ones
-- taken), so this place's quests are known next time and to alts.
local function learnOffers(list)
  local npc = Api.npc()
  local p = playerPoint()
  for _, q in ipairs(list) do
    Atlas.recordStart(atlas, q.questID, { title = q.title, level = q.level, faction = Api.faction(),
      npcID = npc and npc.id }, p)
  end
  if npc and #list > 0 then
    learnNpc("quest")
  end
end

-- Talking to the step's quest giver, who does not offer its quest now (the
-- data may be wrong for Forever, or it needs something we cannot see):
-- skip it, say so, and look at the next step the same way.
local function skipNotOffered(offers)
  local npc = Api.npc()
  for _ = 1, 5 do
    local step = plan and current and plan.steps[current]
    if not (npc and ns.Guide.notOffered(step, npc.name, offers)) then
      return
    end
    Plan.skip(plan, progress, facts())
    say(L["%s does not offer \"%s\" now: skipped (/tm undo brings it back)."]:format(npc.name,
      (step.text:gsub("^" .. L["Pick up: "], ""))))
    arrowStep = false
    refresh()
  end
end

handlers.GOSSIP_SHOW = function()
  if not cdb then
    return
  end
  local offers = Api.npcOffers()
  learnOffers(offers)
  guard("plan", skipNotOffered, offers)
  if Api.npcIsInnkeeper() then
    learnNpc("innkeeper")
  end
end
handlers.QUEST_GREETING = handlers.GOSSIP_SHOW
-- A quest name asked for (a hub's quest) has loaded: show it.
local titlesPending = false
handlers.QUEST_DATA_LOAD_RESULT = function()
  if cdb and cdb.arrival and not titlesPending and plan and Builder.isAuto(plan) then
    titlesPending = true
    after(1, function()
      titlesPending = false
      buildFromQuestLog(true)
    end)
  end
end
handlers.QUEST_DETAIL = function()
  local q = cdb and Api.shownQuest()
  if q then
    learnOffers({ q })
  end
end
handlers.CONFIRM_BINDER = function()
  if cdb then
    learnNpc("innkeeper")
  end
end
-- The hearthstone was set: the arrival step is done.
handlers.HEARTHSTONE_BOUND = function()
  if not cdb then
    return
  end
  learnNpc("innkeeper")
  if cdb.arrival then
    cdb.arrivalDone["arrive-hearth-" .. cdb.arrival] = true
    if plan and Builder.isAuto(plan) then
      buildFromQuestLog(true)
    end
  end
end
handlers.MERCHANT_SHOW = function()
  learnNpc("vendor")
  if Api.vendorRepairs() then
    learnNpc("repair")
  end
  after(0.3, adviseVendor)
end
handlers.PLAYER_XP_UPDATE = function()
  if cdb then
    remindBeforeLevel()
  end
end
handlers.TAXIMAP_OPENED = function()
  learnNpc("flight")
  -- Learn which flights are open from here, and which flight points this
  -- character has on this continent (the flight map shows only those).
  local node, reachable, all, mapID = Api.taxiReach()
  if node then
    Atlas.recordFlights(atlas, node, reachable)
  end
  if all and mapID then
    -- Saved under the world's continent the player stands on (0 Eastern
    -- Kingdoms, 1 Kalimdor): continent map ids differ between clients
    -- (Forever's are 1463 and 1464, classic's 1414 and 1415).
    local here = Api.playerWorld()
    local cont = here and here.cont or Api.continentOf(mapID) or mapID
    local set = {}
    for _, name in ipairs(all) do
      set[name] = true
    end
    cdb.learnedFlights = cdb.learnedFlights or {}
    cdb.learnedFlights[cont] = set
  end
end
handlers.BAG_UPDATE_DELAYED = function()
  bagThrottle:mark()
end
handlers.PLAYER_LOGOUT = function()
  if cdb then
    pcall(takeSnapshot)
  end
end

for event in pairs(handlers) do
  pcall(frame.RegisterEvent, frame, event)
end

frame:SetScript("OnEvent", function(_, event, ...)
  guard(event, handlers[event], ...)
end)

local function talentTick()
  local panel = ns.TalentPanel.attach()
  if panel and panel:IsVisible() then
    ns.TalentPanel.refresh()
  end
end

-- Records the way the player walks: a dot every few yards, joined to the
-- previous one. Flights, ships and loading screens (a jump in position)
-- start a new piece, so no line is drawn through walls or over the sea.
local function recordTrail()
  if cdb.prefs.trails == false or Api.onTaxi() then
    trailPrev, trailLast = nil, nil
    return
  end
  local w = Api.playerWorld()
  if not w then
    -- No position for a moment (crossing into another map, like leaving
    -- Orgrimmar for Durotar): do not cut the trail; the next dot joins the
    -- last one if it is still close (Trails.LINK).
    trailLast = nil
    return
  end
  local last = trailLast
  trailLast = w
  if last and (last.cont ~= w.cont or math.sqrt((last.x - w.x) ^ 2 + (last.y - w.y) ^ 2) > 60) then
    trailPrev = nil
  end
  local p = trailPrev and trails.nodes[trailPrev]
  -- A new dot every few yards, or at once when the map (the floor) changes.
  if p and p[4] == w.mapID and math.sqrt((p[2] - w.x) ^ 2 + (p[3] - w.y) ^ 2) < ns.Trails.STEP then
    return
  end
  trailPrev = ns.Trails.add(trails, w.cont, w.x, w.y, trailPrev, w.mapID) or trailPrev
end

-- Follows a walked trail to the arrow's target when one helps: the arrow
-- points at the next dot and the map shows the dotted way.
function followTrail()
  local target = ns.Arrow.target
  local here = Api.playerWorld()
  local goal = target and Api.worldPos(target.mapID, target.x, target.y)
  local path, why
  if cdb.prefs.trails == false then
    why = "trails off"
  elseif not (here and goal) then
    why = "no position for you or the target"
  else
    path, why = ns.Trails.route(trails, here, goal)
  end
  lastWhy = why
  ns.Arrow.setVia(path and ns.Trails.next(path, here) or nil)
  if showLearned then
    -- /tm trail show: every dot learned around the player, to check them.
    ns.MapTrail.show(here and ns.Trails.around(trails, here.cont, here.x, here.y, 3000, 1200) or nil, true)
  elseif path or lastPath then
    ns.MapTrail.show(path)
  end
  lastPath = path
end

frame:SetScript("OnUpdate", function(_, elapsed)
  if not cdb then
    return
  end
  clock = clock + elapsed
  sinceMove = sinceMove + elapsed
  sinceTarget = sinceTarget + elapsed
  sinceArrow = sinceArrow + elapsed
  -- While the current step is a place to reach, look at the position every second.
  if sinceMove >= 1 and plan and current and plan.steps[current].type == "goto" then
    sinceMove = 0
    questThrottle:mark()
  end
  if questThrottle:tick(clock) then
    pcall(learnProgress)
    guard("plan", refresh)
  end
  if bagThrottle:tick(clock) then
    guard("bags", checkBags)
  end
  -- Quest objectives move (next area, turn-in): look again every two seconds.
  if sinceTarget >= 2 then
    sinceTarget = 0
    -- Arrived in the zone the player chose: drop the detour and route it.
    if detour and detour.zone and Api.position() == detour.zone then
      cdb.arrival, cdb.arrivalDone = detour.zone, {}
      detour, arrowStep, cdb.trip = nil, false, nil
      buildFromQuestLog(false)
    end
    if detour or (plan and current) then
      guard("arrow", updateTarget, true)
    end
    guard("trail", followTrail)
  end
  -- Learn the way while walking; redraw the dotted route on an open map.
  sinceTrail = sinceTrail + elapsed
  if sinceTrail >= 0.5 then
    sinceTrail = 0
    guard("trail", recordTrail)
    guard("map dots", ns.MapTrail.tick)
  end
  -- The talent window may switch tabs: keep the lit talent right.
  sinceTalents = sinceTalents + elapsed
  if sinceTalents >= 1 then
    sinceTalents = 0
    guard("talent plan", talentTick)
  end
  -- The chat with the companion: frames out, answers in.
  sinceChat = sinceChat + elapsed
  if sinceChat >= 0.1 then
    sinceChat = 0
    guard("chat", ns.Chat.tick, clock)
  end
  if sinceArrow >= 0.05 then
    sinceArrow = 0
    guard("arrow", ns.Arrow.update)
  end
end)
