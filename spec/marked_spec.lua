local helper = require("spec.helper")

describe("Marked", function()
  local ns, Marked

  before_each(function()
    ns = helper.load()
    Marked = ns.Marked
  end)

  local function ctx(over)
    local c = { ours = 10, following = 10, now = 100, quietUntil = 50, questLog = { [10] = {}, [11] = {} } }
    for k, v in pairs(over or {}) do
      c[k] = v
    end
    return c
  end

  describe("isPlayerMark", function()
    it("counts a quest of the log the player clicked", function()
      assert.is_true(Marked.isPlayerMark(11, ctx()))
    end)

    it("ignores TrailMate's own choice and the guide's quest", function()
      assert.is_false(Marked.isPlayerMark(10, ctx()))
      assert.is_false(Marked.isPlayerMark(11, ctx({ ours = 11 })))
      assert.is_false(Marked.isPlayerMark(11, ctx({ ours = 12, following = 11 })))
    end)

    it("ignores nothing followed and quests not in the log", function()
      assert.is_false(Marked.isPlayerMark(nil, ctx()))
      assert.is_false(Marked.isPlayerMark(0, ctx()))
      assert.is_false(Marked.isPlayerMark(12, ctx()))
    end)

    it("ignores the game's own choice right after a quest event or the login", function()
      assert.is_false(Marked.isPlayerMark(11, ctx({ quietUntil = 101 })))
      assert.is_true(Marked.isPlayerMark(11, ctx({ quietUntil = 100 })))
    end)

    it("still works when the client gives no time", function()
      assert.is_true(Marked.isPlayerMark(11, ctx({ now = false, quietUntil = 200 })))
    end)
  end)

  describe("view", function()
    it("says what is left: doing it, then handing it in", function()
      local L = ns.L
      assert.same({ kind = "complete", text = L["Do: "] .. "Wolves" },
        Marked.view(11, "Wolves", { [11] = { complete = false } }, L))
      assert.same({ kind = "turnin", text = L["Turn in: "] .. "Wolves" },
        Marked.view(11, "Wolves", { [11] = { complete = true } }, L))
    end)

    it("names a quest by number when the game has not loaded its name", function()
      local L = ns.L
      assert.equals(L["Do: "] .. L["Quest %d"]:format(11), Marked.view(11, nil, { [11] = {} }, L).text)
    end)

    it("is nil once the quest has left the log", function()
      assert.is_nil(Marked.view(11, "Wolves", {}, ns.L))
    end)
  end)
end)
