require("loveps3")

-- ********* STATE *********

-- Grid items
local EMPTY = 0
local WORKER = 1
local PLAYER = 2
local SUPERVISOR = 3

-- Player states
local NONE = 0
local MOVING = 1
local TALKING = 2

-- Player directions
local LEFT = 1
local RIGHT = 2
local BEHIND = 3
local IN_FRONT = 4

-- Worker state
local UNCONVERTED = 1
local CONVERTING = 2
local CONVERTED = 3

-- Current states
local playerState = NONE
local playerTarget = NONE
local workerState = UNCONVERTED

-- Game state
local currentLevel = 1
local warnings = 0
local renderGrid = nil


-- ********* LOVE FUNCTIONS *********

function love.load()
    controller = getController(1, buttonListener, nil)
    renderGrid = newGrid(LEVELS[1], 32)
end

function love.update(dt)    
    controller:update()
end

function love.draw()
    renderGrid:draw(50, 50)
end

-- ********* CONTROLS *********

function buttonListener()

end

-- ********* GRID ********* 

function drawGrid()
    
end

local grid = {}
grid.__index = grid

function newGrid(level, tileSize)
    local g = {} 
    g.tileSize = tileSize
    g.data = loadGrid(level)
    return setmetatable(g, grid)
end

function loadGrid(level)
    parsedGrid = {}
    for i=1, table.getn(level) do
        parsedGrid[i] = {}
        for j=1, table.getn(level[i]) do
            table.insert(parsedGrid[i], newGridItem(i, j, level[i][j], NONE))
        end
    end
    return parsedGrid
end

function grid:draw(x, y)
    for i=1, table.getn(self.data) do
        for j=1, table.getn(self.data[i]) do
            tileX = x + (TILE_SIZE * (i - 1))
            tileY = y + (TILE_SIZE * (j - 1))
            self.data[i][j].draw(tileX, tileY)
        end
    end
end

-- Grid items

local gridItem = {}
gridItem.__index = gridItem

function newGridItem(localX, localY, type, state)
    local gi = {}
    gi.localX = localX
    gi.localY = localY
    gi.type = type
    gi.state = state
    if gi.type == WORKER then
        gi.draw = drawWorker
    elseif gi.type == PLAYER then
        gi.draw = drawPlayer
    elseif gi.type == SUPERVISOR then
        gi.draw = drawSupervisor
    else
        gi.draw = drawSpace
    end
    return setmetatable(gi, gridItem)
end

function drawWorker(x, y)
    love.graphics.setColor(0, 255, 0)
    love.graphics.rectangle('fill', x, y, TILE_SIZE - 5, TILE_SIZE - 5)
end

function drawPlayer(x, y)
    love.graphics.setColor(255, 0, 0)
    love.graphics.rectangle('fill', x, y, TILE_SIZE - 5, TILE_SIZE - 5)
end

function drawSupervisor(x, y)
    love.graphics.setColor(0, 0, 255)
    love.graphics.rectangle('fill', x, y, TILE_SIZE - 5, TILE_SIZE - 5)
end

function drawSpace(x, y)
    love.graphics.setColor(255, 255, 255)
    love.graphics.rectangle('fill', x, y, TILE_SIZE - 5, TILE_SIZE - 5)
end

-- ********* LEVEL LAYOUTS *********

TILE_SIZE = 64

-- 0: Empty space
-- 1: Normal Worker
-- 2: Player starting point
-- 3: Supervisor starting point
LEVELS = {
    {
        {SUPERVISOR, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY},
        {EMPTY, WORKER, WORKER, WORKER, WORKER, EMPTY},
        {EMPTY, WORKER, PLAYER, WORKER, WORKER, EMPTY},
        {EMPTY, WORKER, WORKER, WORKER, WORKER, EMPTY},
        {EMPTY, WORKER, WORKER, WORKER, WORKER, EMPTY},
        {EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY}
    }
}
