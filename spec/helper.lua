-- Loads core files the way the game does: each file gets (addonName, ns).
local M = {}

M.CORE = {
  "core/Locale.lua", "core/Plan.lua", "core/Builder.lua", "core/Throttle.lua",
  "core/Trainer.lua", "core/Bags.lua", "core/State.lua", "core/Geo.lua", "core/Atlas.lua",
  "core/Zones.lua", "core/Strategy.lua", "core/Log.lua", "core/Travel.lua", "core/Talents.lua", "core/Trails.lua",
  "core/Hubs.lua", "core/Guide.lua", "core/Marked.lua", "core/Dungeons.lua", "core/Link.lua",
}

function M.load()
  local ns = {}
  for _, path in ipairs(M.CORE) do
    local chunk = assert(loadfile("TrailMate/" .. path))
    chunk("TrailMate", ns)
  end
  return ns
end

-- Facts with sensible defaults; override what a test needs.
function M.facts(over)
  local f = { level = 10, mapID = 1, x = 0.5, y = 0.5, questLog = {}, turned = {} }
  for k, v in pairs(over or {}) do
    f[k] = v
  end
  f.turnedIn = function(id)
    return f.turned[id] == true
  end
  return f
end

return M
