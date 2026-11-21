-- Quest guides: TrailMate follows a guide (data/Guides.lua) step by step:
-- pick up these quests at this hub, do them there, hand them in, fly on.
-- Every quest step has the place of its quest giver or objectives, so the
-- arrow points everywhere. Pure Lua 5.1.
--
-- A guide becomes an ordinary TrailMate plan (core/Plan.lua): quest steps
-- tick off by themselves from the quest log; the travel hints and notes of
-- a guide are "soft": once something after them is done, they count as
-- passed, so the player never has to click through old hints.

local _, ns = ...

local Guide = {}
ns.Guide = Guide

-- Race names in guides (Guidelime) and in the game (UnitRace) differ.
local RACE_ALIASES = { UNDEAD = "SCOURGE", NIGHTELF = "NIGHTELF", NIGHT_ELF = "NIGHTELF" }

local function fits(only, who)
  if not only then
    return true
  end
  for _, w in ipairs(only) do
    local word = RACE_ALIASES[w] or w
    if word == who.class or word == who.race or w == who.race then
      return true
    end
  end
  return false
end
Guide.fits = fits

--- The guides for a faction (and class or race), in the data's order.
function Guide.list(guides, who)
  local out = {}
  for _, g in ipairs(guides or {}) do
    if g.faction == who.faction and fits(g.only, who) then
      out[#out + 1] = g
    end
  end
  return out
end

-- How many of a guide's steps are on a map (counted once per guide).
local zoneCounts = setmetatable({}, { __mode = "k" })
local function stepsOn(g, mapID)
  local counts = zoneCounts[g]
  if not counts then
    counts = {}
    for _, s in ipairs(g.steps or {}) do
      if s.m then
        counts[s.m] = (counts[s.m] or 0) + 1
      end
    end
    zoneCounts[g] = counts
  end
  return counts[mapID] or 0
end

-- A guide counts as one for a zone when it has a real part there.
Guide.ZONE_STEPS = 5
-- A guide for the zone may be up to this many levels below the player.
Guide.ZONE_BELOW = 3

--- True if the guide has a real part on this map.
function Guide.covers(g, mapID)
  return mapID ~= nil and stepsOn(g, mapID) >= Guide.ZONE_STEPS
end

--- The unfinished guide with the biggest part on this map among those that
--- suit the level (it starts at most one level above it and ends at most
--- ZONE_BELOW below it), or nil. A guide that only passes through the zone
--- (a few steps on the way out) loses to the zone's own guide.
function Guide.forZone(list, level, mapID, finished)
  local best, most = nil, 0
  for _, g in ipairs(list) do
    if g.min <= level + 1 and g.max >= level - Guide.ZONE_BELOW and Guide.covers(g, mapID)
      and not (finished and finished(g)) and stepsOn(g, mapID) > most then
      best, most = g, stepsOn(g, mapID)
    end
  end
  return best
end

--- The guide to follow: the one chosen by name if it still exists; else
--- the first unfinished guide with a part where the player is (mapID,
--- optional); else the first guide for the level (from one level below its
--- end) that is not finished; else the last one starting at or below the
--- level. finished(guide) (optional) says whether its quests are all
--- handed in.
function Guide.pick(list, level, chosen, finished, mapID)
  for _, g in ipairs(list) do
    if chosen and g.name == chosen then
      return g
    end
  end
  local here = Guide.forZone(list, level, mapID, finished)
  if here then
    return here
  end
  for _, g in ipairs(list) do
    if g.min <= level and g.max >= level - 1 and not (finished and finished(g)) then
      return g
    end
  end
  local pick
  for _, g in ipairs(list) do
    if g.min <= level and (not pick or g.min >= pick.min) then
      pick = g
    end
  end
  return pick or list[1]
end

--- True when every quest the guide hands in (not optional, for this
--- character) is handed in. isDone(questID).
function Guide.finished(guide, who, isDone)
  local any = false
  for _, s in ipairs(guide.steps) do
    if s.t == "turnin" and not s.opt and fits(s.only, who) then
      any = true
      if not isDone(s.q) then
        return false
      end
    end
  end
  return any
end

--- The guide after this one in the list, or nil.
function Guide.after(list, guide)
  for i, g in ipairs(list) do
    if g == guide then
      return list[i + 1]
    end
  end
  return nil
end

local function slug(text)
  return (text:lower():gsub("[^%w]+", "-"):gsub("^%-+", ""):gsub("%-+$", ""))
end

--- The guide's quests this character can no longer pick up, and why:
--- { [questID] = "crumb" | "excl" | "pre" }. needs: ns.GUIDE_QUESTS (what
--- each quest needs, from the database); done(id): handed in; inLog(id): in
--- the quest log now. A quest in the log or handed in always stays. The
--- quests the guide itself hands in or takes before count as done or taken.
function Guide.unavailable(guide, who, needs, done, inLog)
  local gone, handed, taken = {}, {}, {}
  local function had(id)
    return done(id) or inLog(id) or handed[id]
  end
  for _, s in ipairs(guide.steps) do
    if s.q and fits(s.only, who) then
      if needs and needs[s.q] and needs[s.q].absent then
        gone[s.q] = "absent" -- not in Forever at all
      elseif s.t == "accept" and not gone[s.q] and not inLog(s.q) and not done(s.q) then
        local e, why = needs and needs[s.q], nil
        if e and e.absent then
          why = "absent"
        elseif e then
          -- A breadcrumb is gone once the quest it leads to is taken.
          if e.crumb and (had(e.crumb) or taken[e.crumb]) then
            why = "crumb"
          end
          for _, x in ipairs(e.excl or {}) do
            if had(x) or taken[x] then
              why = why or "excl"
            end
          end
          if e.pre then
            local ok = false
            for _, p in ipairs(e.pre) do
              ok = ok or had(p)
            end
            why = why or (not ok and "pre" or nil)
          end
          for _, p in ipairs(e.preAll or {}) do
            why = why or (not had(p) and "pre" or nil)
          end
        end
        if why then
          gone[s.q] = why
        else
          taken[s.q] = true
        end
      elseif s.t == "turnin" then
        handed[s.q] = true
      end
    end
  end
  return gone
end

-- Words of a note that speaks about the guide itself, not the game: a link,
-- or asking for support. Lower case.
local AUTHOR_WORDS = {
  "http", "www%.", "%.com", "%.gg", "%.tv", "youtube", "twitch", "patreon", "paypal", "ko%-fi",
  "curseforge", "discord", "my work", "my guide", "written by",
}

--- True for a guide note that is the author's (a link, a request for
--- support), not something to do in the game: it is left out of the plan.
--- The guides' authors are credited in the README.
function Guide.isAuthorNote(s)
  if s.t ~= "note" or type(s.text) ~= "string" then
    return false
  end
  local text = s.text:lower()
  for _, w in ipairs(AUTHOR_WORDS) do
    if text:find(w) then
      return true
    end
  end
  return false
end

--- A TrailMate plan from a guide. ctx = { who, L, title(questID), place(step),
--- needs, done(id), inLog(id) }: title gives the game's (localized) quest
--- name, falling back to the guide's; place gives where the player saw that
--- quest giver ({ mapID, x, y }), which replaces the data's position. With
--- needs, the quests this character can no longer pick up are left out
--- (Guide.unavailable): returned second, by quest id.
function Guide.toPlan(guide, ctx)
  local L, who = ctx.L, ctx.who
  local steps = {}
  local max = ns.Plan.MAX_TEXT
  local function cut(text)
    return #text > max and text:sub(1, max - 3) .. "..." or text
  end
  local never = function()
    return false
  end
  local gone = ctx.needs and Guide.unavailable(guide, who, ctx.needs, ctx.done or never, ctx.inLog or never) or {}
  for i, s in ipairs(guide.steps) do
    if fits(s.only, who) and not (s.q and gone[s.q]) and not Guide.isAuthorNote(s) then
      local step = { id = "g" .. i }
      local name = s.q and ((ctx.title and ctx.title(s.q)) or s.name or L["Quest %d"]:format(s.q))
      if s.t == "accept" then
        step.type, step.questID, step.text = "accept", s.q, L["Pick up: "] .. name
        step.why = s.npc and L["From %s"]:format(s.npc) or nil
        step.npc = s.npc -- to notice when that quest giver does not offer it
      elseif s.t == "turnin" then
        step.type, step.questID, step.text = "turnin", s.q, L["Turn in: "] .. name
        step.why = s.npc and L["To %s"]:format(s.npc) or nil
      elseif s.t == "complete" then
        step.type, step.questID, step.text = "complete", s.q, L["Do: "] .. name
      elseif s.t == "goto" then
        step.type, step.text, step.soft = "goto", s.text, true
      elseif s.t == "level" then
        step.type, step.level, step.text = "level", s.level, s.text
      else
        step.type, step.text, step.soft = "note", s.text, true
      end
      if s.opt then
        step.why = L["Optional: elite or group quest"] .. (step.why and (" - " .. step.why) or "")
      end
      -- Where the game showed the quest giver wins over the data.
      local seen = ctx.place and ctx.place(s)
      if seen then
        step.mapID, step.x, step.y = seen.mapID, seen.x, seen.y
      elseif s.m and s.x and s.y then
        step.mapID, step.x, step.y = s.m, s.x, s.y
      end
      step.text = cut(step.text or "")
      if step.why then
        step.why = cut(step.why)
      end
      steps[#steps + 1] = step
    end
  end
  if #steps == 0 then
    steps[1] = { id = "g0", type = "note", soft = true, text = L["Nothing left to do in this guide."] }
  end
  return {
    version = 1,
    id = "guide-" .. slug(guide.faction .. "-" .. guide.name),
    title = guide.name,
    steps = steps,
  }, gone
end

--- True if the step asks to pick up a quest from this quest giver, who does
--- not offer it now (offers: { { questID } } from the gossip or greeting
--- window). The data can be wrong for Forever, or the quest may need
--- something we cannot see: the guide must not wait for it.
function Guide.notOffered(step, npcName, offers)
  if not (step and step.type == "accept" and step.npc and npcName and step.npc == npcName) then
    return false
  end
  for _, q in ipairs(offers or {}) do
    if q.questID == step.questID then
      return false
    end
  end
  return true
end

--- True if a plan was made from a guide.
function Guide.isGuide(plan)
  return type(plan) == "table" and type(plan.id) == "string" and plan.id:find("^guide%-") ~= nil
end
