local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"

package.preload["gettext"] = function()
    return setmetatable({}, { __call = function(_, s) return s end })
end
package.path = DIR .. "common/?.lua;" .. DIR .. "?.lua;" .. package.path

describe("ArrowSudokuBoard", function()
    local Mod, ArrowSudokuBoard

    setup(function()
        Mod = require("board")
        ArrowSudokuBoard = Mod.ArrowSudokuBoard
    end)

    describe("new", function()
        it("creates a 9x9 board with no arrows until generate is called", function()
            local b = ArrowSudokuBoard:new()
            assert.are.equal(9, b.n)
            assert.are.equal(3, b.box_rows)
            assert.are.equal(3, b.box_cols)
            assert.are.equal(0, #b.arrows)
        end)
    end)

    describe("generate", function()
        it("fills a valid 9x9 solution and places 5-8 arrows", function()
            math.randomseed(42)
            local b = ArrowSudokuBoard:new()
            b:generate("medium")
            local n = b.n
            for r = 1, n do
                local seen = {}
                for c = 1, n do seen[b.solution[r][c]] = true end
                for d = 1, n do assert.is_true(seen[d], "row " .. r .. " missing " .. d) end
            end
            assert.is_true(#b.arrows >= 5 and #b.arrows <= 8)
        end)

        it("every arrow's value equals the sum of its path cells in the solution", function()
            math.randomseed(7)
            local b = ArrowSudokuBoard:new()
            b:generate("medium")
            for _, arrow in ipairs(b.arrows) do
                local total = 0
                for _, cell in ipairs(arrow.cells) do
                    total = total + b.solution[cell.r][cell.c]
                end
                assert.are.equal(arrow.value, total)
            end
        end)
    end)

    describe("recalcConflicts (arrow sums)", function()
        it("flags an arrow whose filled path sum doesn't match its value", function()
            math.randomseed(42)
            local b = ArrowSudokuBoard:new()
            b:generate("medium")
            local arrow = b.arrows[1]
            for _, cell in ipairs(arrow.cells) do
                b.user[cell.r][cell.c] = 0
                if not b:isGiven(cell.r, cell.c) then
                    b.user[cell.r][cell.c] = (b.solution[cell.r][cell.c] % 9) + 1
                end
            end
            b:recalcConflicts()
            local any_conflict = false
            for _, cell in ipairs(arrow.cells) do
                if b.conflicts[cell.r][cell.c] then any_conflict = true end
            end
            assert.is_true(any_conflict)
        end)
    end)

    describe("serialize / load", function()
        it("round-trips puzzle, solution and arrows", function()
            math.randomseed(42)
            local b = ArrowSudokuBoard:new()
            b:generate("medium")
            local data = b:serialize()

            local b2 = ArrowSudokuBoard:new()
            assert.is_true(b2:load(data))
            assert.are.equal(#b.arrows, #b2.arrows)
            assert.are.equal(b.arrows[1].value, b2.arrows[1].value)
            for r = 1, b.n do
                for c = 1, b.n do
                    assert.are.equal(b.solution[r][c], b2.solution[r][c])
                end
            end
        end)

        it("load returns false for invalid data", function()
            local b = ArrowSudokuBoard:new()
            assert.is_false(b:load(nil))
            assert.is_false(b:load({}))
        end)
    end)
end)
