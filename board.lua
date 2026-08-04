local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local function lrequire_common(name)
    local key = _dir .. "common/" .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. "common/" .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local grid_utils       = lrequire_common("sudoku_grid_utils")
local puzzle_generator = lrequire_common("puzzle_generator")
local BaseBoard        = lrequire_common("base_board")

local emptyGrid        = grid_utils.emptyGrid
local emptyNotes       = grid_utils.emptyNotes
local emptyMarkerGrid  = grid_utils.emptyMarkerGrid
local copyGrid         = grid_utils.copyGrid
local copyNotes        = grid_utils.copyNotes

local generateSolvedBoard = puzzle_generator.generateSolvedBoard
local createPuzzle        = puzzle_generator.createPuzzle

-- ---------------------------------------------------------------------------
-- Grid config (9x9 only)
-- ---------------------------------------------------------------------------

local GRID_CONFIGS = {
    { id = "9x9", n = 9, box_rows = 3, box_cols = 3, label = "9\xC3\x979" },
}

local function getGridConfig(id)
    return GRID_CONFIGS[1]
end

local DEFAULT_DIFFICULTY = "medium"

-- ---------------------------------------------------------------------------
-- Arrow placement helpers
-- ---------------------------------------------------------------------------

-- Place 5-8 arrows on the solution grid.
-- Each arrow: { src={r,c}, cells={{r,c},...}, value=N }
-- src is the tail cell (shows the sum), cells are the path cells (not including src).
-- value = sum of solution values along cells.
local function placeArrows(solution)
    local n = 9
    -- All 8 compass directions -- using only the 4 "forward" ones (right/
    -- down/both down-diagonals) left corner cells unreachable as a path
    -- cell (arriving at a corner would require a source with a negative
    -- row/col), so arrows clustered heavily toward the grid's center and
    -- almost never touched the corner boxes. All 8 directions make every
    -- cell reachable from some source, spreading arrows across the whole
    -- grid.
    local directions = {
        { dr = 0,  dc = 1  },  -- right
        { dr = 0,  dc = -1 },  -- left
        { dr = 1,  dc = 0  },  -- down
        { dr = -1, dc = 0  },  -- up
        { dr = 1,  dc = 1  },  -- diag down-right
        { dr = 1,  dc = -1 },  -- diag down-left
        { dr = -1, dc = 1  },  -- diag up-right
        { dr = -1, dc = -1 },  -- diag up-left
    }

    local arrows   = {}
    local cell_used = {}

    local function cellKey(r, c) return r * 100 + c end

    -- Even with all 8 directions available, uniformly-random source
    -- placement still favors the grid's center: any bounded-length path
    -- dropped at a random position/orientation in a bounded grid is more
    -- likely to fit (not go out of bounds) the closer its start is to the
    -- center -- a general geometric effect, not specific to this game.
    -- A soft bias (weighting source choice by how little a box has been
    -- touched so far) turned out too weak in testing: a source biased
    -- toward a corner box still mostly extends its path *into* the
    -- center anyway, since direction is picked independently. Instead,
    -- since the target count (5-8) never exceeds the 9 boxes, assign
    -- each arrow to its own shuffled box up front and require its source
    -- to land there -- this guarantees real spread rather than merely
    -- nudging the odds.
    local box_order = {}
    for br = 1, 3 do for bc = 1, 3 do box_order[#box_order + 1] = { br = br, bc = bc } end end
    for i = #box_order, 2, -1 do
        local j = math.random(i)
        box_order[i], box_order[j] = box_order[j], box_order[i]
    end

    local function randomCellInBox(box)
        local row_in_box = math.random(0, 2)
        local col_in_box = math.random(0, 2)
        return (box.br - 1) * 3 + row_in_box + 1, (box.bc - 1) * 3 + col_in_box + 1
    end

    -- Try to place one arrow with its source restricted to `box` (nil =
    -- anywhere). Returns true and appends to `arrows` on success.
    local function tryPlaceOne(box)
        local sr, sc
        if box then
            sr, sc = randomCellInBox(box)
        else
            sr, sc = math.random(1, n), math.random(1, n)
        end
        if cell_used[cellKey(sr, sc)] then return false end

        -- Pick a random direction and length for the path (2-3 cells, not including src)
        local dir    = directions[math.random(#directions)]
        local length = math.random(2, 3)

        local path = {}
        for i = 1, length do
            local nr = sr + dir.dr * i
            local nc = sc + dir.dc * i
            if nr < 1 or nr > n or nc < 1 or nc > n then return false end
            if cell_used[cellKey(nr, nc)] then return false end
            path[#path + 1] = { r = nr, c = nc }
        end
        if #path < 2 then return false end

        -- Compute sum of solution values along path
        local total = 0
        for _, cell in ipairs(path) do
            total = total + solution[cell.r][cell.c]
        end

        cell_used[cellKey(sr, sc)] = true
        for _, cell in ipairs(path) do
            cell_used[cellKey(cell.r, cell.c)] = true
        end

        arrows[#arrows + 1] = {
            src   = { r = sr, c = sc },
            cells = path,
            value = total,
        }
        return true
    end

    local target_count = math.random(5, 8)
    local box_sub_attempts = 40

    for i = 1, target_count do
        local box = box_order[i]
        local placed = false
        for _ = 1, box_sub_attempts do
            if tryPlaceOne(box) then placed = true; break end
        end
        if not placed then
            -- This box couldn't fit one (rare -- e.g. heavily used by
            -- earlier arrows); fall back to a free placement anywhere so
            -- the target count is still reached.
            for _ = 1, box_sub_attempts do
                if tryPlaceOne(nil) then break end
            end
        end
    end

    return arrows
end

-- ---------------------------------------------------------------------------
-- ArrowSudokuBoard
-- ---------------------------------------------------------------------------

local ArrowSudokuBoard = setmetatable({}, { __index = BaseBoard })
ArrowSudokuBoard.__index = ArrowSudokuBoard

function ArrowSudokuBoard:new(config)
    local n        = 9
    local box_rows = 3
    local box_cols = 3
    local board = {
        n               = n,
        box_rows        = box_rows,
        box_cols        = box_cols,
        grid_id         = "9x9",
        puzzle          = emptyGrid(n),
        solution        = emptyGrid(n),
        user            = emptyGrid(n),
        conflicts       = emptyGrid(n),
        notes           = emptyNotes(n),
        wrong_marks     = emptyMarkerGrid(n),
        selected        = { row = 1, col = 1 },
        difficulty      = DEFAULT_DIFFICULTY,
        reveal_solution = false,
        undo_stack      = {},
        arrows          = {},
    }
    setmetatable(board, self)
    board:recalcConflicts()
    return board
end

function ArrowSudokuBoard:serialize()
    local n = self.n
    -- Serialize arrows
    local arrows_data = {}
    for i, arrow in ipairs(self.arrows) do
        local cells_data = {}
        for j, cell in ipairs(arrow.cells) do
            cells_data[j] = { r = cell.r, c = cell.c }
        end
        arrows_data[i] = {
            src   = { r = arrow.src.r, c = arrow.src.c },
            cells = cells_data,
            value = arrow.value,
        }
    end
    return {
        n               = n,
        box_rows        = self.box_rows,
        box_cols        = self.box_cols,
        grid_id         = self.grid_id,
        puzzle          = copyGrid(self.puzzle, n),
        solution        = copyGrid(self.solution, n),
        user            = copyGrid(self.user, n),
        notes           = copyNotes(self.notes, n),
        wrong_marks     = copyGrid(self.wrong_marks, n),
        selected        = { row = self.selected.row, col = self.selected.col },
        difficulty      = self.difficulty,
        reveal_solution = self.reveal_solution,
        arrows          = arrows_data,
    }
end

function ArrowSudokuBoard:load(state)
    if not state or not state.puzzle or not state.solution or not state.user then
        return false
    end
    self.n        = state.n        or 9
    self.box_rows = state.box_rows or 3
    self.box_cols = state.box_cols or 3
    self.grid_id  = state.grid_id  or "9x9"
    local n = self.n
    self.puzzle      = copyGrid(state.puzzle, n)
    self.solution    = copyGrid(state.solution, n)
    self.user        = copyGrid(state.user, n)
    self.notes       = copyNotes(state.notes, n)
    self.wrong_marks = state.wrong_marks and copyGrid(state.wrong_marks, n) or emptyMarkerGrid(n)
    self.conflicts   = emptyGrid(n)
    self.difficulty  = state.difficulty or DEFAULT_DIFFICULTY
    self.undo_stack  = {}
    if state.selected then
        self.selected = {
            row = math.max(1, math.min(n, state.selected.row or 1)),
            col = math.max(1, math.min(n, state.selected.col or 1)),
        }
    else
        self.selected = { row = 1, col = 1 }
    end
    self.reveal_solution = state.reveal_solution or false
    -- Load arrows
    self.arrows = {}
    if state.arrows then
        for i, ad in ipairs(state.arrows) do
            local cells = {}
            for j, cell in ipairs(ad.cells) do
                cells[j] = { r = cell.r, c = cell.c }
            end
            self.arrows[i] = {
                src   = { r = ad.src.r, c = ad.src.c },
                cells = cells,
                value = ad.value,
            }
        end
    end
    self:recalcConflicts()
    return true
end

function ArrowSudokuBoard:generate(difficulty, randInt, on_progress)
    self.difficulty = difficulty or self.difficulty or DEFAULT_DIFFICULTY
    local n, box_rows, box_cols = self.n, self.box_rows, self.box_cols
    local solution = generateSolvedBoard(n, box_rows, box_cols, nil, randInt)
    local puzzle   = createPuzzle(solution, self.difficulty, n, box_rows, box_cols, nil, randInt, on_progress)
    self.puzzle          = puzzle
    self.solution        = solution
    self.user            = emptyGrid(n)
    self.notes           = emptyNotes(n)
    self.wrong_marks     = emptyMarkerGrid(n)
    self.selected        = { row = 1, col = 1 }
    self.reveal_solution = false
    self.undo_stack      = {}
    self.arrows          = placeArrows(solution)
    self:recalcConflicts()
end

function ArrowSudokuBoard:isGiven(row, col)
    return self.puzzle[row][col] ~= 0
end

function ArrowSudokuBoard:getWorkingValue(row, col)
    local given = self.puzzle[row][col]
    if given ~= 0 then return given end
    return self.user[row][col]
end

function ArrowSudokuBoard:getDisplayValue(row, col)
    if self.reveal_solution then
        return self.solution[row][col], self:isGiven(row, col)
    end
    if self:isGiven(row, col) then
        return self.puzzle[row][col], true
    end
    local value = self.user[row][col]
    if value == 0 then return nil end
    return value, false
end

function ArrowSudokuBoard:recalcConflicts()
    -- Call parent for row/col/box conflicts
    BaseBoard.recalcConflicts(self)
    -- Check arrow sum violations: if all cells in an arrow path are filled,
    -- verify sum equals arrow.value; if not, mark those cells as conflicts.
    for _, arrow in ipairs(self.arrows or {}) do
        local path_cells = arrow.cells
        -- Check if all path cells are filled
        local all_filled = true
        local actual_sum = 0
        for _, cell in ipairs(path_cells) do
            local v = self:getWorkingValue(cell.r, cell.c)
            if v == 0 then
                all_filled = false
                break
            end
            actual_sum = actual_sum + v
        end
        if all_filled and actual_sum ~= arrow.value then
            -- Mark all path cells as conflicts
            for _, cell in ipairs(path_cells) do
                self.conflicts[cell.r][cell.c] = true
            end
            -- Also mark the source cell
            local src = arrow.src
            self.conflicts[src.r][src.c] = true
        end
    end
end

function ArrowSudokuBoard:isConflict(row, col)
    return self.conflicts[row][col]
end

function ArrowSudokuBoard:clearUndoHistory()
    self.undo_stack = {}
end

return {
    ArrowSudokuBoard   = ArrowSudokuBoard,
    DEFAULT_DIFFICULTY = DEFAULT_DIFFICULTY,
    GRID_CONFIGS       = GRID_CONFIGS,
    getGridConfig      = getGridConfig,
}
