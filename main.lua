require("loveps3")

-- ********* STATE *********

local currentLevel = 1
local renderGrid = nil

-- ********* LOVE FUNCTIONS *********

function love.load()
    controller = getController(1, buttonListener, nil)
end

function love.update(dt)    
    controller:update()
end

function love.draw()
end

-- ********* CONTROLS *********

function buttonListener()

end

-- ********* GRID ********* 

function drawGrid()
    
end

local grid = {}
grid.__index = grid

function newGrid(level, x, y)
    local g = {} 
    g.x = x
    g.y = y
    return setmetatable(g, grid)
end

function grid:draw()
end

-- Grid items

local gridItem = {}
gridItem.__index = gridItem

local NONE = 0
local MOVING = 1
local TALKING = 2

local LEFT = 1
local RIGHT = 2
local BEHIND = 3
local IN_FRONT = 4

local CONVERTED = 1
local UNCONVERTED = 2

local playerState = NONE
local playerTarget = NONE
local workerState = UNCONVERTED

function gridItem:new(localX, localY, state, drawFunction)
    local gi = {}
    gi.localX = localX
    gi.localY = localY
    gi.state = state
    gi.draw = drawFunction
    return setmetatable(gi, gridItem)
end

function drawWorker(x, y)

end

function drawPlayer(x, y)

end

function drawSupervisor(x, y)

end

-- ********* LEVEL LAYOUTS *********

-- 0: Empty space
-- 1: Normal Worker
-- 2: Player starting point
-- 3: Supervisor starting point
levels = {
    {
        {3, 0, 0, 0, 0, 0},
        {0, 1, 1, 1, 1, 0},
        {0, 1, 2, 1, 1, 0},
        {0, 1, 1, 1, 1, 0},
        {0, 1, 1, 1, 1, 0},
        {0, 0, 0, 0, 0, 0}
    }
}
