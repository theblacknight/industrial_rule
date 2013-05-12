require('loveps3')
require('AnAL')
require "pulse"

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
local MOVING = 10
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

-- Game state
local currentLevel = 1
local warnings = 0
local renderGrid = nil
local playerTile = nil
local renderSupervisor = nil


-- ********* LOVE FUNCTIONS *********

function love.load()
    love.graphics.setCaption( 'Industrial Rule' )
    bg = love.graphics.newImage("assets/bg.png")
    worker = love.graphics.newImage("assets/worker.png")
    workerAnim = newAnimation(worker, 64, 64, 0.5, 2)

    controller = getController(1, buttonListener, stickListener)
    if controller == nil then
        state = NO_CONTROLLER
        return
    end
    gt = 0
    state = PLAY
    renderGrid = newGrid(LEVELS[currentLevel])
    local sup = LEVELS[currentLevel].supervisor
    renderSupervisor = {pos = { x = 400, y = 300 }, 
                        normal =  sup.direction, state = NONE}
end

function love.update(dt)
    if state == PLAY then
        gt = gt + dt
        fx.fov:send("supervisorNormal", {renderSupervisor.normal.x, renderSupervisor.normal.y})
        fx.fov:send("supervisorPos", {renderSupervisor.pos.x, 600 - renderSupervisor.pos.y})
        controller:update()
        updateWorkers()
        workerAnim:update(dt)
        tween.update(dt)

        renderSupervisor.normal = rotateNormal(renderSupervisor.normal, -0.01)
    end
end

function love.draw()
    love.graphics.draw(bg, 0, 0)
    if state == PLAY then
        renderGrid:draw()
        drawSupervisor(renderSupervisor.pos.x, renderSupervisor.pos.y)
    elseif state == NO_CONTROLLER then
        love.graphics.print("NO CONTROLLER FOUND!", 100, 100)
    end
end

-- ********* CONTROLS *********

function buttonListener(button)

end

function stickListener(stick, vector)
    currentDirection = getDirection(vector)
    if stick == 'LEFT' then
        if playerTile.state ~= MOVING then
            if currentDirection == 'left' then
                setPlayerState(TALKING, LEFT) 
            elseif currentDirection == 'right' then
                setPlayerState(TALKING, RIGHT) 
            elseif currentDirection == 'up' then
                setPlayerState(TALKING, UP) 
            elseif currentDirection == 'down' then
                setPlayerState(TALKING, DOWN)
            else
                setPlayerState(NONE, NONE) 
            end
        end
    else
        if playerTile.state == NONE and currentDirection ~= nil then
            trySwap(currentDirection)
        end
    end
end

function setPlayerState(state, direction)
    playerTile.state = state
    playerTarget = direction
end

function trySwap(direction)
    if direction == 'left' then
        tile = getPlayerRelativeTile(-1, 0)
    elseif direction == 'right' then
        tile = getPlayerRelativeTile(1, 0)
    elseif direction == 'up' then
        tile = getPlayerRelativeTile(0, -1)
    elseif direction == 'down' then
        tile = getPlayerRelativeTile(0, 1)
    end
    if tile ~= nil and tile.type == WORKER and tile.state == CONVERTED then
        swapPositions(tile)
    end
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
    item.conversionBar = {width = 0, height = 10}
    item.tween = tween.start(1, item.conversionBar, { width = 60 },
                                'linear', conversionFinished, item)
end

function conversionFinished(worker)
    worker.state = CONVERTED
    worker.tween = nil
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
    return renderGrid.data[playerTile.pos.x + xOffset][playerTile.pos.y + yOffset]
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
    g.width = #g.data
    g.height = #g.data[1]
    return setmetatable(g, grid)
end

function loadGrid(level, x, y)
    parsedGrid = {}
    for i=1, table.getn(level) do
        parsedGrid[i] = {}
        for j=1, table.getn(level[i]) do
            item = newGridItem(level[i][j])
            item.pos = {x = i, y = j}
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
            tileX = self.x + (self.tileSize * (i - 1))
            tileY = self.y + (self.tileSize * (j - 1))
            it = self.data[i][j]
            it.draw(tileX, tileY, it)
        end
    end
end

function grid:swap(item1, item2)
    self.data[item1.pos.x][item1.pos.y] = item2
    self.data[item2.pos.x][item2.pos.y] = item1
    tmpPos = item1.pos
    item1.pos = item2.pos
    item2.pos = tmpPos
end

-- Grid items

local gridItem = {}
gridItem.__index = gridItem

function newGridItem(type)
    local gi = {}
    gi.type = type
    gi.state = NONE
    if gi.type == WORKER then
        gi.draw = drawWorker
    elseif gi.type == PLAYER then
        gi.draw = drawPlayer
    else
        gi.draw = drawSpace
    end
    return setmetatable(gi, gridItem)
end

function drawWorker(x, y, item)
    love.graphics.setColor(255, 255, 255)

    if item.state == CONVERTING then
        love.graphics.setColor(255, 0, 0)
        love.graphics.rectangle('fill', x, y,
                                item.conversionBar.width,
                                item.conversionBar.height)
    elseif item.state == MOVING then
        love.graphics.setColor(255, 255, 255)
        love.graphics.print('MOV', x, y)
    elseif item.state == CONVERTED then
        love.graphics.setColor(255, 255, 255)
    else
    end

    love.graphics.setPixelEffect(fx.fov)
    workerAnim:draw(x, y)
    love.graphics.setPixelEffect()
end

function drawPlayer(x, y, item)
    love.graphics.setColor(255, 0, 0)
    love.graphics.rectangle('fill', x, y, 60, 60)
    love.graphics.setColor(0, 0, 0)
    if item.state == TALKING then
        love.graphics.print('T', x + 5, y + 10)
    elseif item.state == MOVING then
        love.graphics.print('MOV', x + 5, y + 10)
    else
        love.graphics.print('P1', x + 5, y + 10)
    end
    
end

function drawSupervisor(x, y)
    love.graphics.setColor(255, 0, 0)
    love.graphics.circle('fill', x, y, 10, 10)
    love.graphics.setColor(255, 255, 255)
end

function drawSpace(x, y, item)
    --love.graphics.setColor(255, 255, 255)
    --love.graphics.rectangle('fill', x, y, 60, 60)
end

function swapPositions(worker)
    playerTile.state = MOVING
    worker.state = MOVING
    timer = {t = 0}
    tween.start(1, timer, { t = 100 }, 'linear', swapFinished, worker)
end

function swapFinished(worker)
    renderGrid:swap(playerTile, worker)
    playerTile.state = NONE
    worker.state = CONVERTED
end

function rotateNormal(normal, degrees)
    return normalise({ 
        x = math.cos(degrees) * normal.x - math.sin(degrees) * normal.y,
        y = math.sin(degrees) * normal.x + math.cos(degrees) * normal.y
    })
end

-- ********* LEVEL LAYOUTS *********

LEVELS = {
    {
        tileSize = 64, x = 200, y = 100,
        supervisor = { tileX = 0, tileY = 0, direction = { x = -1, y = 0} },
        grid={
            {EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY},
            {EMPTY, WORKER, WORKER, WORKER, WORKER, EMPTY},
            {EMPTY, WORKER, PLAYER, WORKER, WORKER, EMPTY},
            {EMPTY, WORKER, WORKER, WORKER, WORKER, EMPTY},
            {EMPTY, WORKER, WORKER, WORKER, WORKER, EMPTY},
            {EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY}
        }
    }
}
