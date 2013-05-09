require('loveps3')
require('AnAL')

local tween = require('tween')

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
    bg = love.graphics.newImage("assets/bg.png")
    worker = love.graphics.newImage("assets/worker.png")
    workerAnim = newAnimation(worker, 64, 64, 0.5, 2)

    controller = getController(1, buttonListener, stickListener)
    if controller == nil then
        state = NO_CONTROLLER
        return
    end
    state = PLAY
    renderGrid = newGrid(LEVELS[currentLevel])
end

function love.update(dt)    
    if state == PLAY then
        controller:update(false)
        updateWorkers()
        workerAnim:update(dt)
        tween.update(dt)
    end
end

function love.draw()
    love.graphics.draw(bg, 0, 0)
    if state == PLAY then
        renderGrid:draw()
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
                if talking(item) then
                    if item.state == NONE then
                        item.state = CONVERTING
                        startConversionBar(item)
                        return
                    end
                else
                    if item.state == CONVERTING then
                        item.state = NONE
                        if item.tween ~= nil then
                            tween.stop(item.tween)
                            item.tween = nil
                            item.state = NONE
                            item.conversionBar = nil
                        end
                    end
                end
            end
        end
    end
end

function startConversionBar(item)
    item.conversionBar = {x = item.x + 2, y = item.y + 2, width = 0, height = 10}
    item.tween = tween.start(1, item.conversionBar, { width = 60 }, 'linear')
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

function newGrid(level)
    local g = {}
    g.x = level.x
    g.y = level.y
    g.tileSize = level.tileSize
    g.data = loadGrid(level.grid, level.x, level.y)
    return setmetatable(g, grid)
end

function loadGrid(level, x, y)
    parsedGrid = {}
    for i=1, table.getn(level) do
        parsedGrid[i] = {}
        for j=1, table.getn(level[i]) do
            item = newGridItem(i, j, level[i][j])
            tileX = x + (64 * (i - 1))
            tileY = y + (64 * (j - 1))
            item.x = tileX
            item.y = tileY
            if item.type == PLAYER then
                playerTile = item
            end
            table.insert(parsedGrid[i], item)
        end
    end
    return parsedGrid
end

function grid:draw()
    for i=1, table.getn(self.data) do
        for j=1, table.getn(self.data[i]) do
            it = self.data[i][j]
            it.draw(it.x, it.y, it)
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
    love.graphics.setColor(255, 255, 255)
    workerAnim:draw(x, y)
    --love.graphics.rectangle('fill', x, y, 60, 60)

    if item.state == CONVERTING then
        love.graphics.setColor(255, 0, 0)
        love.graphics.rectangle('fill', item.x, item.y,
                                item.conversionBar.width,
                                item.conversionBar.height)
    end
end

function drawPlayer(x, y, item)
    love.graphics.setColor(255, 0, 0)
    love.graphics.rectangle('fill', x, y, 60, 60)
    love.graphics.setColor(0, 0, 0)
    if item.state == TALKING then
        love.graphics.print('T', x + 5, y + 10)
    else
        love.graphics.print('P1', x + 5, y + 10)
    end
    
end

function drawSupervisor(x, y, item)
    love.graphics.setColor(0, 0, 255)
    love.graphics.rectangle('fill', x, y, 60, 60)
end

function drawSpace(x, y, item)
    love.graphics.setColor(255, 255, 255)
    love.graphics.rectangle('fill', x, y, 60, 60)
end

-- ********* LEVEL LAYOUTS *********

-- 0: Empty space
-- 1: Normal Worker
-- 2: Player starting point
-- 3: Supervisor starting point
LEVELS = {
    {
        tileSize = 64, x = 200, y = 100,
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
