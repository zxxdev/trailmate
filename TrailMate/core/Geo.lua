-- Arrow maths. Pure Lua 5.1.
--
-- Map coordinates go from 0 to 1: x grows to the east, y grows to the south.
-- The player's facing is in radians, 0 is north and it grows counter-clockwise
-- (pi/2 is west). An arrow texture that points up is rotated counter-clockwise
-- by the returned angle.

local _, ns = ...

local Geo = {}
ns.Geo = Geo

local TWO_PI = 2 * math.pi

-- Minimap shapes (GetMinimapShape): which quarters are round, in the order
-- bottom-right, bottom-left, top-right, top-left. A missing shape is round.
local SHAPES = {
  ROUND = { true, true, true, true },
  SQUARE = { false, false, false, false },
  ["CORNER-TOPLEFT"] = { false, false, false, true },
  ["CORNER-TOPRIGHT"] = { false, false, true, false },
  ["CORNER-BOTTOMLEFT"] = { false, true, false, false },
  ["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
  ["SIDE-LEFT"] = { false, true, false, true },
  ["SIDE-RIGHT"] = { true, false, true, false },
  ["SIDE-TOP"] = { false, false, true, true },
  ["SIDE-BOTTOM"] = { true, true, false, false },
  ["TRICORNER-TOPLEFT"] = { false, true, true, true },
  ["TRICORNER-TOPRIGHT"] = { true, false, true, true },
  ["TRICORNER-BOTTOMLEFT"] = { true, true, false, true },
  ["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
}

--- Where a button sits on the minimap's edge, as x, y from its centre:
--- angle in degrees (0 is east, counter-clockwise), halfW and halfH half the
--- minimap's size plus how far out the button goes. On a round quarter it
--- follows the circle; on a square one it follows the square's side.
function Geo.edgeOffset(angle, halfW, halfH, shape)
  local rad = math.rad(angle)
  local x, y = math.cos(rad), math.sin(rad)
  local q = 1
  if x < 0 then
    q = q + 1
  end
  if y > 0 then
    q = q + 2
  end
  local round = (SHAPES[shape or "ROUND"] or SHAPES.ROUND)[q]
  if round then
    return x * halfW, y * halfH
  end
  -- Out along the diagonal, then held to the square's sides.
  local dw, dh = math.sqrt(2 * halfW * halfW) - 10, math.sqrt(2 * halfH * halfH) - 10
  return math.max(-halfW, math.min(x * dw, halfW)), math.max(-halfH, math.min(y * dh, halfH))
end

--- Distance in yards between two points of the same map, given the map size
--- in yards. Returns nil when the size is unknown.
function Geo.distance(px, py, tx, ty, width, height)
  if not (width and height) then
    return nil
  end
  local east, south = (tx - px) * width, (ty - py) * height
  return math.sqrt(east * east + south * south)
end

--- Angle from north to the target, counter-clockwise, in [0, 2pi).
function Geo.bearing(px, py, tx, ty, width, height)
  local east = (tx - px) * (width or 1)
  local south = (ty - py) * (height or 1)
  if east == 0 and south == 0 then
    return nil
  end
  local angle = math.atan2(-east, -south)
  return angle % TWO_PI
end

--- Rotation for an up-pointing arrow so it points at the target, in [0, 2pi).
function Geo.arrowRotation(bearing, facing)
  if not (bearing and facing) then
    return nil
  end
  return (bearing - facing) % TWO_PI
end

--- Bearing and distance to a point given in world units, for targets on
--- another map. delta: target minus player; east, north: the world vectors
--- of a small step east and north on the player's map. Returns bearing
--- (counter-clockwise from north, like Geo.bearing) and distance, or nil.
function Geo.worldBearing(delta, east, north)
  local det = east.x * north.y - east.y * north.x
  if det == 0 then
    return nil
  end
  -- delta = a * east + b * north
  local a = (delta.x * north.y - delta.y * north.x) / det
  local b = (east.x * delta.y - east.y * delta.x) / det
  local eastYards = a * math.sqrt(east.x * east.x + east.y * east.y)
  local northYards = b * math.sqrt(north.x * north.x + north.y * north.y)
  if eastYards == 0 and northYards == 0 then
    return nil
  end
  local distance = math.sqrt(delta.x * delta.x + delta.y * delta.y)
  return math.atan2(-eastYards, northYards) % TWO_PI, distance
end

--- Which cell of a picture holding the arrow drawn at `frames` angles shows
--- this rotation: 0 to frames - 1, nearest angle.
function Geo.arrowFrame(rotation, frames)
  return math.floor((rotation % TWO_PI) / TWO_PI * frames + 0.5) % frames
end

--- How far off course the target is: 0 straight ahead, 1 straight behind.
function Geo.offCourse(rotation)
  local angle = rotation % TWO_PI
  if angle > math.pi then
    angle = TWO_PI - angle
  end
  return angle / math.pi
end

--- Short text for a distance in yards.
function Geo.formatDistance(yards)
  if not yards then
    return "?"
  end
  if yards >= 1000 then
    return ("%.1f km"):format(yards * 0.9144 / 1000)
  end
  return ("%d m"):format(math.floor(yards * 0.9144 + 0.5))
end
