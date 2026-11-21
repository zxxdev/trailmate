local helper = require("spec.helper")

describe("Geo", function()
  local Geo
  local PI = math.pi

  before_each(function()
    Geo = helper.load().Geo
  end)

  local function near(expected, actual)
    assert.is_true(math.abs(expected - actual) < 1e-9, ("expected %s, got %s"):format(expected, actual))
  end

  it("puts the minimap button on the edge of a round minimap, whatever its size", function()
    -- A bigger minimap than the classic one (the user's case: it sat inside).
    local x, y = Geo.edgeOffset(0, 105, 105)
    near(105, x)
    near(0, y)
    x, y = Geo.edgeOffset(90, 75, 75, "ROUND")
    near(0, x)
    near(75, y)
    x, y = Geo.edgeOffset(225, 105, 105, "UNKNOWN") -- an unknown shape is round
    near(-105 * math.sqrt(2) / 2, x)
    near(-105 * math.sqrt(2) / 2, y)
  end)

  it("follows the sides of a square minimap into its corners", function()
    local x, y = Geo.edgeOffset(45, 75, 75, "SQUARE")
    local d = (math.sqrt(2 * 75 * 75) - 10) * math.sqrt(2) / 2
    near(d, x)
    near(d, y)
    x = Geo.edgeOffset(10, 75, 75, "SQUARE")
    near(75, x) -- held to the right side
    -- A minimap in the top-left corner of the screen is round only in its
    -- top-left quarter (the names other addons use for the shapes).
    x = Geo.edgeOffset(135, 75, 75, "CORNER-TOPLEFT")
    near(-75 * math.sqrt(2) / 2, x)
    x, y = Geo.edgeOffset(-45, 75, 75, "CORNER-TOPLEFT")
    near(d, x)
    near(-d, y)
  end)

  it("measures yards with the map size", function()
    near(500, Geo.distance(0.5, 0.5, 0.5, 0.0, 2000, 1000))
    near(1000, Geo.distance(0.0, 0.5, 0.5, 0.5, 2000, 1000))
    assert.is_nil(Geo.distance(0, 0, 1, 1, nil, nil))
  end)

  it("gives the bearing counter-clockwise from north", function()
    near(0, Geo.bearing(0.5, 0.5, 0.5, 0.1, 1, 1)) -- north (y grows south)
    near(PI / 2, Geo.bearing(0.5, 0.5, 0.1, 0.5, 1, 1)) -- west
    near(PI, Geo.bearing(0.5, 0.5, 0.5, 0.9, 1, 1)) -- south
    near(3 * PI / 2, Geo.bearing(0.5, 0.5, 0.9, 0.5, 1, 1)) -- east
    assert.is_nil(Geo.bearing(0.5, 0.5, 0.5, 0.5, 1, 1))
  end)

  it("uses the real map shape, not the square of the map image", function()
    -- Same map offsets, but the map is four times wider than tall.
    local wide = Geo.bearing(0.5, 0.5, 0.4, 0.4, 4000, 1000)
    near(math.atan2(400, 100), wide)
  end)

  it("turns the arrow with the player's facing", function()
    -- Target to the west while facing west: straight ahead.
    near(0, Geo.arrowRotation(PI / 2, PI / 2))
    -- Target north while facing west: on the right, a quarter turn clockwise.
    near(3 * PI / 2, Geo.arrowRotation(0, PI / 2))
    assert.is_nil(Geo.arrowRotation(nil, 0))
    assert.is_nil(Geo.arrowRotation(0, nil))
  end)

  it("formats distances in metres", function()
    assert.equals("9 m", Geo.formatDistance(10))
    assert.equals("1.8 km", Geo.formatDistance(2000))
    assert.equals("?", Geo.formatDistance(nil))
  end)

  it("picks the arrow picture drawn at the nearest angle", function()
    assert.equals(0, Geo.arrowFrame(0, 128))
    assert.equals(16, Geo.arrowFrame(PI / 4, 128))
    assert.equals(64, Geo.arrowFrame(PI, 128))
    assert.equals(0, Geo.arrowFrame(2 * PI - 0.001, 128)) -- wraps round
    assert.equals(127, Geo.arrowFrame(-2 * PI / 128, 128))
  end)

  it("finds the way to a target on another map from world positions", function()
    -- World axes as in the game (x north, y west): a step east is -y.
    local east, north = { x = 0, y = -10 }, { x = 10, y = 0 }
    local bearing, distance = Geo.worldBearing({ x = 300, y = 0 }, east, north)
    near(0, bearing) -- straight north
    near(300, distance)
    near(3 * PI / 2, (Geo.worldBearing({ x = 0, y = -50 }, east, north))) -- east
    near(PI / 2, (Geo.worldBearing({ x = 0, y = 50 }, east, north))) -- west
    -- Any other axis convention gives the same answer.
    near(PI, (Geo.worldBearing({ x = 0, y = -7 }, { x = 5, y = 0 }, { x = 0, y = 5 }))) -- south
    assert.is_nil(Geo.worldBearing({ x = 1, y = 1 }, { x = 0, y = 0 }, { x = 0, y = 0 }))
  end)

  it("says how far off course the target is", function()
    near(0, Geo.offCourse(0))
    near(0.5, Geo.offCourse(PI / 2))
    near(0.5, Geo.offCourse(3 * PI / 2)) -- right or left, the same
    near(1, Geo.offCourse(PI))
  end)
end)
