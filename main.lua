require('loveps3')
require('tween')

-- ********* STATE *********

MENU = 0
PLAYING = 1
PAUSE = 2
NO_CONTROLLER = 3

state = MENU

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
local UP = 3
local DOWN = 4

-- Worker state
local CONVERTING = 1
local CONVERTED = 2

-- Current states
local playerTarget = NONE
local workerState = UNCONVERTED

-- Game state
local currentLevel = 1
local warnings = 0
local renderGrid = nil
local playerTile = nil


-- ********* LOVE FUNCTIONS *********

function love.load()
    controller = getController(1, buttonListener, stickListener)
    if controller == nil then
        state = NO_CONTROLLER
        return
    end
    state = PLAY
    renderGrid = newGrid(LEVELS[currentLevel].grid, 32)
end

function love.update(dt)    
    if state == PLAY then
        controller:update(false)
        updateWorkers()
    end
end

function love.draw()
    if state == PLAY then
        renderGrid:draw(LEVELS[currentLevel].x, LEVELS[currentLevel].y)
    elseif state == NO_CONTROLLER then
        love.graphics.print("NO CONTROLLER FOUND!", 100, 100)
    end
end

-- ********* CONTROLS *********

function buttonListener(button)

end

function stickListener(stick, vector)
    if stick == 'LEFT' then
        if pointingLeft(vector) then
            talkLeft()
        elseif pointingRight(vector) then
            talkRight()
        elseif pointingUp(vector) then
            talkUp()
        elseif pointingDown(vector) then
            talkDown()
        else
            resetPlayer()
        end
    end
end

function resetPlayer()
    playerTile.state = NONE
    playerTarget = NONE
end

function talkLeft()
    playerTile.state = TALKING
    playerTarget = LEFT
end

function talkRight()
    playerTile.state = TALKING
    playerTarget = RIGHT
end

function talkUp()
    playerTile.state = TALKING
    playerTarget = UP
end

function talkDown()
    playerTile.state = TALKING
    playerTarget = DOWN
end

-- GAME LOGIC

function updateWorkers()
    for i=1, table.getn(renderGrid.data) do
        for j=1, table.getn(renderGrid.data[i]) do
            item = renderGrid.data[i][j]
            if item.type == WORKER then
                if item.state == NONE and talking(item) then
                    item.state = CONVERTING
                    break
                else
                    if item.state == CONVERTING then
                        item.state = NONE
                        if item.tween ~= nil then
                            tween.stop(item.tween)
                            item.tween = nil
                            item.state = NONE
                        end
                    end
                end
            end
        end
    end
end

function talking(worker)
    if playerTile.state == TALKING then
        if isTarget(LEFT, worker) or 
            isTarget(RIGHT, worker) or
            isTarget(UP, worker) or
            isTarget(DOWN, worker) then
            return true
        end
    end
    return false
end

function isTarget(direction, worker)
    return playerTarget == LEFT and  worker == getPlayerRelativeTile(-1, 0) or
        playerTarget == RIGHT and  worker == getPlayerRelativeTile(1, 0) or
        playerTarget == UP and  worker == getPlayerRelativeTile(0, -1) or
        playerTarget == DOWN and  worker == getPlayerRelativeTile(0, 1)
end

function getPlayerRelativeTile(xOffset, yOffset)
    return renderGrid.data[playerTile.localX + xOffset][playerTile.localY + yOffset]
end

-- ********* GRID ********* 


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
            item = newGridItem(i, j, level[i][j])
            if item.type == PLAYER then
                playerTile = item
            end
            table.insert(parsedGrid[i], item)
        end
    end
    return parsedGrid
end

function grid:draw(x, y)
    for i=1, table.getn(self.data) do
        for j=1, table.getn(self.data[i]) do
            tileX = x + (TILE_SIZE * (i - 1))
            tileY = y + (TILE_SIZE * (j - 1))
            self.data[i][j].draw(tileX, tileY, self.data[i][j])
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
    gi.state = NONE
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

function drawWorker(x, y, item)
    love.graphics.setColor(0, 255, 0)
    love.graphics.rectangle('fill', x, y, TILE_SIZE - 5, TILE_SIZE - 5)

    if item.state == CONVERTING then
        love.graphics.setColor(0, 0, 0)
        love.graphics.print('C', x + 5, y + 10)
    end
end

function drawPlayer(x, y, item)
    love.graphics.setColor(255, 0, 0)
    love.graphics.rectangle('fill', x, y, TILE_SIZE - 5, TILE_SIZE - 5)
    love.graphics.setColor(0, 0, 0)
    if item.state == TALKING then
        love.graphics.print('T', x + 5, y + 10)
    else
        love.graphics.print('P1', x + 5, y + 10)
    end
    
end

function drawSupervisor(x, y, item)
    love.graphics.setColor(0, 0, 255)
    love.graphics.rectangle('fill', x, y, TILE_SIZE - 5, TILE_SIZE - 5)
end

function drawSpace(x, y, item)
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
        x = 200, y = 100,
        grid={
            {SUPERVISOR, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY},
            {EMPTY, WORKER, WORKER, WORKER, WORKER, EMPTY},
            {EMPTY, WORKER, PLAYER, WORKER, WORKER, EMPTY},
            {EMPTY, WORKER, WORKER, WORKER, WORKER, EMPTY},
            {EMPTY, WORKER, WORKER, WORKER, WORKER, EMPTY},
            {EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY}
        }
    }
}
