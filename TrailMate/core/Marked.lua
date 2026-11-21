-- A quest the player marks: clicking it in the quest tracker or the quest
-- log makes the game follow it (super-track it). The arrow then goes to that
-- quest instead of the guide, until the player goes back to the guide, hands
-- the quest in or drops it. Pure Lua 5.1: which marks count, and what the
-- arrow says for one.

local _, ns = ...

local Marked = {}
ns.Marked = Marked

-- Seconds after a quest is taken, handed in or dropped in which the game may
-- choose a quest to follow by itself: that is not the player's mark.
Marked.QUIET = 1.5
-- At login the game brings back the quest followed last time.
Marked.QUIET_LOGIN = 5

--- True when the quest the game follows now was marked by the player.
--- ctx = { ours, following, now, quietUntil, questLog }: ours is the quest
--- TrailMate asked the game to follow; following is the quest of the step
--- being followed; now and quietUntil are times in seconds (either may be
--- nil); questLog is { [questID] = entry }.
function Marked.isPlayerMark(questID, ctx)
  if type(questID) ~= "number" or questID <= 0 then
    return false -- nothing followed
  end
  if questID == ctx.ours or questID == ctx.following then
    return false -- TrailMate's own, or the guide's quest already
  end
  if type(ctx.now) == "number" and type(ctx.quietUntil) == "number" and ctx.now < ctx.quietUntil then
    return false -- the game's own choice
  end
  return type(ctx.questLog) == "table" and ctx.questLog[questID] ~= nil
end

--- What the arrow says for a marked quest: { kind, text }, with kind
--- "complete" while there is something left to do and "turnin" once it is
--- done. nil when the quest has left the log (handed in or dropped).
function Marked.view(questID, title, questLog, L)
  local entry = type(questLog) == "table" and questLog[questID]
  if not entry then
    return nil
  end
  local name = title or L["Quest %d"]:format(questID)
  if entry.complete then
    return { kind = "turnin", text = L["Turn in: "] .. name }
  end
  return { kind = "complete", text = L["Do: "] .. name }
end
