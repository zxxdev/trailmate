-- Draws TrailMate's icon in a flat, bold style: a round badge with a gold
-- ring and a dark outline, a winding trail across it and a white paw print
-- on top, with a flat shadow on its lower side. The paw is the companion at
-- your side; the trail is the way you level.
--
-- One picture per companion, so the icon says who is talking (the trail's
-- colour):
--   Icon.tga         no AI: TrailMate's purple
--   Icon-claude.tga  Claude: orange
--   Icon-chatgpt.tga ChatGPT: grey trail on a black badge
-- and the same three as IconFace*.tga: only the face, with no ring, for the
-- minimap button, where the game's own gold ring goes around it.
--
-- Every shape is a signed distance, smoothed over one pixel. The pictures
-- are 64 pixels, close to the size the game shows them at: the game does
-- not blend a picture well when it shrinks it a lot (it looks pixelated).
--
-- Run it from the repository root (in the VM): lua tools/make_icon.lua

local M = {}

M.SIZE = 64 -- near the size the game shows it at, so it never needs shrinking much

M.STYLES = {
  default = { file = "Icon", fill = { 0.07, 0.11, 0.21 }, trail = { 0.61, 0.48, 0.83 } },
  claude = { file = "Icon-claude", fill = { 0.07, 0.11, 0.21 }, trail = { 0.93, 0.52, 0.30 } },
  chatgpt = { file = "Icon-chatgpt", fill = { 0.07, 0.07, 0.08 }, trail = { 0.60, 0.62, 0.66 } },
}

M.OUTLINE = { 0.04, 0.05, 0.09 }
M.GOLD = { 0.93, 0.71, 0.24 }
M.GOLD_SHADE = { 0.78, 0.53, 0.15 }
M.PAW = { 0.98, 0.97, 0.93 }
M.PAW_SHADE = { 0.64, 0.70, 0.86 }

-- Radii in units of half the picture: the outline, the gold ring, the dark
-- line inside the ring and the inner face.
M.R_OUT, M.R_RING, M.R_LINE, M.R_FACE = 0.985, 0.91, 0.79, 0.745

local STROKE = 0.07 -- the dark outline around the paw and the trail
local SHADE = 0.08 -- how far the flat shadow reaches into the paw
local TRAIL_SHADE = 0.04 -- the same for the trail
local TRAIL_DARK = 0.72 -- the trail's shadow tone, as a share of its colour

-- The trail: a cubic curve that passes under the paw's pad and climbs on
-- the right, like levelling up. Both ends lie past the face: the ring cuts them.
local P = { { -0.86, -0.30 }, { -0.30, -0.80 }, { 0.45, -0.60 }, { 0.66, 0.50 } }
local STEPS = 96

--- A point of the trail, t from 0 to 1.
function M.curve(t)
  local u = 1 - t
  local a, b, c, d = u * u * u, 3 * u * u * t, 3 * u * t * t, t * t * t
  return a * P[1][1] + b * P[2][1] + c * P[3][1] + d * P[4][1], a * P[1][2] + b * P[2][2] + c * P[3][2] + d * P[4][2]
end

local trail = {}
for i = 0, STEPS do
  local x, y = M.curve(i / STEPS)
  trail[i + 1] = { x, y, i / STEPS }
end

-- Half width along the trail: wide in front (lower left), thin far away.
local function width(t)
  return 0.05 + 0.13 * (1 - t) ^ 1.3
end

local function clamp(v)
  return v < 0 and 0 or (v > 1 and 1 or v)
end

local function mix(a, b, t)
  return a + (b - a) * t
end

--- Signed distance to the trail (negative inside).
function M.trailDistance(x, y)
  local best = math.huge
  for i = 1, #trail - 1 do
    local a, b = trail[i], trail[i + 1]
    local dx, dy = b[1] - a[1], b[2] - a[2]
    local h = clamp(((x - a[1]) * dx + (y - a[2]) * dy) / (dx * dx + dy * dy))
    local ex, ey = x - a[1] - dx * h, y - a[2] - dy * h
    local d = math.sqrt(ex * ex + ey * ey) - width(mix(a[3], b[3], h))
    if d < best then
      best = d
    end
  end
  return best
end

-- The paw: a three-lobed pad and four toes, tilted a little to the right.
local TILT = math.rad(-14)
local COS, SIN = math.cos(TILT), math.sin(TILT)
local PAW_X, PAW_Y = -0.08, 0.10
local PAD = { { -0.135, -0.25, 0.155 }, { 0.135, -0.25, 0.155 }, { 0, -0.13, 0.185 } }
local TOES = { -- x, y, half width, half height, turn
  { -0.37, 0.09, 0.11, 0.14, math.rad(28) },
  { -0.15, 0.30, 0.11, 0.145, math.rad(9) },
  { 0.15, 0.30, 0.11, 0.145, math.rad(-9) },
  { 0.37, 0.09, 0.11, 0.14, math.rad(-28) },
}

-- Smooth union: blends two shapes with a rounded join.
local function smin(a, b, k)
  local h = clamp(0.5 + 0.5 * (b - a) / k)
  return mix(b, a, h) - k * h * (1 - h)
end

--- Signed distance to the paw print (negative inside).
function M.pawDistance(x, y)
  x, y = x - PAW_X, y - PAW_Y
  x, y = x * COS + y * SIN, -x * SIN + y * COS
  local pad
  for _, c in ipairs(PAD) do
    local d = math.sqrt((x - c[1]) ^ 2 + (y - c[2]) ^ 2) - c[3]
    pad = pad and smin(pad, d, 0.07) or d
  end
  local best = pad
  for _, e in ipairs(TOES) do
    local c, s = math.cos(e[5]), math.sin(e[5])
    local lx, ly = x - e[1], y - e[2]
    lx, ly = lx * c + ly * s, -lx * s + ly * c
    local dx, dy = lx / e[3], ly / e[4]
    local d = (math.sqrt(dx * dx + dy * dy) - 1) * math.min(e[3], e[4])
    best = math.min(best, d)
  end
  return best
end

-- Paints colour c over (r, g, b) with coverage a.
local function over(r, g, b, c, a)
  return mix(r, c[1], a), mix(g, c[2], a), mix(b, c[3], a)
end

--- Colour at pixel (px, py), top-left origin: r, g, b, a from 0 to 1.
--- face: only the inner face, filling the picture (for the minimap, where
--- the game's own ring goes around it).
function M.pixel(px, py, style, face)
  local half = M.SIZE / 2
  local zoom = face and M.R_FACE or 1
  local x, y = (px + 0.5 - half) / half * zoom, (half - (py + 0.5)) / half * zoom
  local px1 = zoom / half -- one pixel, in these units
  -- Coverage of "distance d is inside", smoothed over one pixel.
  local function cover(d)
    return clamp(0.5 - d / px1)
  end
  local rho = math.sqrt(x * x + y * y)
  local alpha = cover(rho - (face and M.R_FACE or M.R_OUT))
  if alpha == 0 then
    return M.OUTLINE[1], M.OUTLINE[2], M.OUTLINE[3], 0
  end
  local r, g, b = M.OUTLINE[1], M.OUTLINE[2], M.OUTLINE[3]
  if not face then
    -- The gold ring, with a crescent of shadow on its lower right.
    local ringLit = math.sqrt((x + 0.07) ^ 2 + (y - 0.07) ^ 2) <= 0.90
    r, g, b = over(r, g, b, ringLit and M.GOLD or M.GOLD_SHADE, cover(rho - M.R_RING))
    r, g, b = over(r, g, b, M.OUTLINE, cover(rho - M.R_LINE))
  end
  face = face and 1 or cover(rho - M.R_FACE)
  -- The face glows a little in the middle, so the paw stands out.
  local k = mix(1.5, 0.85, clamp(rho / M.R_FACE))
  r, g, b = over(r, g, b, { style.fill[1] * k, style.fill[2] * k, style.fill[3] * k }, face)

  -- The trail, inside the face: its dark outline, its shadow tone, and its
  -- colour where a copy moved towards the light still covers it.
  local t = M.trailDistance(x, y)
  local tc = style.trail
  r, g, b = over(r, g, b, M.OUTLINE, cover(t - STROKE) * face)
  r, g, b = over(r, g, b, { tc[1] * TRAIL_DARK, tc[2] * TRAIL_DARK, tc[3] * TRAIL_DARK }, cover(t) * face)
  r, g, b = over(r, g, b, tc, cover(t) * cover(M.trailDistance(x + TRAIL_SHADE, y - TRAIL_SHADE)) * face)

  -- The paw on top: outline, white, and the flat shadow where a copy moved
  -- towards the light (top left) no longer covers it.
  local p = M.pawDistance(x, y)
  r, g, b = over(r, g, b, M.OUTLINE, cover(p - STROKE))
  local inside = cover(p)
  local lit = cover(M.pawDistance(x + SHADE, y - SHADE))
  r, g, b = over(r, g, b, M.PAW_SHADE, inside)
  r, g, b = over(r, g, b, M.PAW, inside * lit)
  return clamp(r), clamp(g), clamp(b), alpha
end

local function byte(v)
  return string.char(math.floor(clamp(v) * 255 + 0.5))
end

--- One style as an uncompressed 32-bit TGA file (rows bottom-up).
function M.tga(style, face)
  local s = M.SIZE
  local out = { string.char(0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, s % 256, math.floor(s / 256), s % 256,
    math.floor(s / 256), 32, 8) }
  for py = s - 1, 0, -1 do
    local row = {}
    for px = 0, s - 1 do
      local r, g, b, a = M.pixel(px, py, style, face)
      row[#row + 1] = byte(b) .. byte(g) .. byte(r) .. byte(a)
    end
    out[#out + 1] = table.concat(row)
  end
  return table.concat(out)
end

if arg and arg[0] and arg[0]:match("make_icon%.lua$") then
  local dir = arg[1] or "TrailMate/media"
  for _, style in pairs(M.STYLES) do
    for _, face in ipairs({ false, true }) do
      local name = face and style.file:gsub("^Icon", "IconFace") or style.file
      local path = ("%s/%s.tga"):format(dir, name)
      local file = assert(io.open(path, "wb"))
      file:write(M.tga(style, face))
      file:close()
      print(path)
    end
  end
end

return M
