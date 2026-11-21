-- The icon generator (tools/make_icon.lua) and the files it made.

describe("icon picture", function()
  local art = dofile("tools/make_icon.lua")
  local half = art.SIZE / 2

  -- The pixel at x, y in units of half the picture (y up).
  local function at(x, y, style)
    return art.pixel(math.floor(half + x * half), math.floor(half - y * half), style)
  end

  it("is a round badge: clear in the corners, solid in the middle, a gold ring at the top", function()
    local _, _, _, corner = art.pixel(0, 0, art.STYLES.default)
    local _, _, _, middle = art.pixel(half, half, art.STYLES.default)
    assert.equals(0, corner)
    assert.equals(1, middle)
    local r, g, b = at(0, 0.85, art.STYLES.default)
    assert.is_true(r > 0.85 and g > 0.6 and b < 0.35) -- gold
  end)

  it("has a white paw print in the middle", function()
    for _, style in pairs(art.STYLES) do
      local r, g, b = at(-0.10, -0.06, style)
      assert.is_true(r > 0.9 and g > 0.9 and b > 0.85)
    end
  end)

  it("draws the trail in the companion's colour, clear of the paw", function()
    local x, y = art.curve(0.3)
    local r, g, b = at(x, y, art.STYLES.claude)
    assert.is_true(r > 0.85 and g > 0.4 and g < 0.65 and b < 0.4) -- orange
    r, g, b = at(x, y, art.STYLES.default)
    assert.is_true(b > r and r > g) -- purple
    -- ChatGPT's badge is black away from the paw and the trail.
    r = at(0.45, 0.40, art.STYLES.chatgpt)
    assert.is_true(r < 0.2)
  end)

  it("has a face without the ring for the minimap, filling the picture", function()
    local style = art.STYLES.default
    -- Near the edge the badge is gold; the face is the dark fill there.
    local r, g, b = art.pixel(half, 3, style)
    assert.is_true(r > 0.6 and g > 0.4 and b < 0.3)
    r, g, b = art.pixel(half, 3, style, true)
    assert.is_true(r < 0.25 and g < 0.25 and b < 0.35)
    local _, _, _, corner = art.pixel(0, 0, style, true)
    assert.equals(0, corner)
  end)

  it("matches the files the addon loads", function()
    for _, style in pairs(art.STYLES) do
      for _, name in ipairs({ style.file, (style.file:gsub("^Icon", "IconFace")) }) do
        local file = assert(io.open("TrailMate/media/" .. name .. ".tga", "rb"))
        local data = file:read("*a")
        file:close()
        assert.equals(18 + art.SIZE * art.SIZE * 4, #data)
        assert.equals(art.SIZE, data:byte(13) + data:byte(14) * 256)
      end
    end
  end)
end)
