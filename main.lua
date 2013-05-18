require('loveps3')
require('AnAL')
require "pulse"

local tween = require('tween')

-- ********* STATE *********

MENU = 0
PLAYING = 1
STUNG = 2
PAUSE = 4
NO_CONTROLLER = 5

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

-- Supervisor State
local WALKING = 1
local TURNING = 2

-- Current states
local playerTarget = NONE

-- Game state
local currentLevel = 1
local warnings = 0
local renderGrid = nil
local playerTile = nil


-- ********* LOVE FUNCTIONS *********

function love.load()
    love.graphics.setCaption( 'Industrial Rule' )
    bg = love.graphics.newImage("assets/bg.png")
    worker = love.graphics.newImage("assets/worker.png")
    convertedImg = love.graphics.newImage("assets/soc.png")
    workerAnim = newAnimation(worker, 64, 64, 0.5, 2)

    controller = getController(1, buttonListener, stickListener)
    --if controller == nil then
    --    state = NO_CONTROLLER
    --    return
    --end
    loadLevel()
end

function loadLevel()
    state = PLAY
    renderGrid = newGrid(LEVELS[currentLevel])
    positionSupervisor()
    moveSupervisor()
end

function love.update(dt)
        if controller ~= nil then
            controller:update()
        end
    if state == PLAY then
        fx.fov:send("supervisorNormal", {renderGrid.supervisor.normal.x, renderGrid.supervisor.normal.y})
        fx.fov:send("supervisorPos", {renderGrid.supervisor.pos.x + 32, 568 - renderGrid.supervisor.pos.y})
        updateWorkers()
        updateSupervisor()
        workerAnim:update(dt)
        tween.update(dt)
        testCollisions()
    end
end

function love.draw()
    if state == PLAY or state == STUNG then
        love.graphics.setPixelEffect(fx.fov)
        love.graphics.draw(bg, 0, 0)
        love.graphics.setPixelEffect()
        if state == STUNG then
            love.graphics.print('You were taken out back and beaten!', 10, 10)
        end
        renderGrid:draw()
        drawSupervisor(renderGrid.supervisor.pos.x, renderGrid.supervisor.pos.y)
    elseif state == NO_CONTROLLER then
        love.graphics.print("NO CONTROLLER FOUND!", 100, 100)
    end
end

-- ********* CONTROLS *********

function buttonListener(button)
    if state == STUNG and button == 'CIRCLE' then
        loadLevel()
    end
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
        tile = getRelativeTile(playerTile, -1, 0)
    elseif direction == 'right' then
        tile = getRelativeTile(playerTile, 1, 0)
    elseif direction == 'up' then
        tile = getRelativeTile(playerTile, 0, -1)
    elseif direction == 'down' then
        tile = getRelativeTile(playerTile, 0, 1)
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
                    elseif item.state == CONVERTED then
                        surroundings = {    getRelativeTile(item, 0, -1),
                                            getRelativeTile(item, 0, 1),
                                            getRelativeTile(item, -1, 0),
                                            getRelativeTile(item, 1, 0)
                                        }
                        for idx, worker in ipairs(surroundings) do
                            if worker ~= nil and worker.type == WORKER then
                                if worker.state == NONE then
                                    if worker.loyaltyTween == nil then
                                        worker.loyaltyTween = tween.start(10, item, { loyalty = 0.0 }, 'linear',
                                                                            loyaltyDry, item, worker)
                                    end
                                    break;
                                elseif worker.state == CONVERTED then
                                    if item.loyaltyTween ~= nil then
                                        tween.stop(item.loyaltyTween)
                                        item.loyaltyTween = nil
                                        item.loyalty = 100
                                    end
                                end 
                            end
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

function loyaltyDry(item, worker)
    item.state = NONE
    worker.loyaltyTween = nil
end

function conversionFinished(worker)
    worker.state = CONVERTED
    worker.loyalty = 100
    worker.conversionBar = nil
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
    return playerTarget == LEFT and  worker == getRelativeTile(playerTile, -1, 0) or
        playerTarget == RIGHT and  worker == getRelativeTile(playerTile, 1, 0) or
        playerTarget == UP and  worker == getRelativeTile(playerTile, 0, -1) or
        playerTarget == DOWN and  worker == getRelativeTile(playerTile, 0, 1)
end

function getRelativeTile(tile, xOffset, yOffset)
    if renderGrid.data[tile.localX + xOffset] == nil then
        return nil
    end
    return renderGrid.data[tile.localX + xOffset][tile.localY + yOffset]
end

-- ********* GRID ********* 


function positionSupervisor()
    sup = renderGrid.supervisor
    tile = renderGrid.data[sup.tileX][sup.tileY]
    sup.pos = { x = tile.pos.x, y = tile.pos.y}
    sup.state = WALKING
end

function moveSupervisor()
    sup = renderGrid.supervisor
    nextTile, newDirection = getNextTile(sup.tileX, sup.tileY, sup.normal)
    if nextTile ~= nil and sup.state == WALKING then
        if newDirection ~= nil then
            sup.turnSpeed = -0.1
            sup.state = TURNING
        else
            tween.start(0.5, sup.pos, { x = nextTile.pos.x }, 'linear')
            tween.start(0.5, sup.pos, { y = nextTile.pos.y }, 'linear', moveSupervisor)
            sup.tileX = nextTile.localX
            sup.tileY = nextTile.localY
        end
    end
end

local turned = 0.0

function updateSupervisor()
    sup = renderGrid.supervisor
    if sup.state == TURNING then
        turned = turned + sup.turnSpeed
        if math.abs(turned) < 1.57 then
            sup.normal = rotateNormal(sup.normal, sup.turnSpeed)
        else
            turned = 0
            sup.normal.x = round(sup.normal.x)
            sup.normal.y = round(sup.normal.y)
            sup.state = WALKING
            moveSupervisor()
        end
    end
end

function round(x)
  if x%2 ~= 0.5 then
    return math.floor(x+0.5)
  end
  return x-0.5
end

local testAngle = 45
local fovRadius = 250
function testCollisions()

    for i=1, table.getn(renderGrid.data) do
        for j=1, table.getn(renderGrid.data[i]) do
            item = renderGrid.data[i][j]
            if item.type == PLAYER and 
                (item.state == TALKING or item.state == MOVING) and 
                isInFov(item) then
                state = STUNG
            end
        end
    end

    return false
end

function isInFov(tile)
    supervisorPos = renderGrid.supervisor.pos
    vec = { x = item.pos.x - supervisorPos.x, y = item.pos.y - supervisorPos.y}
    if magnitude(vec) < fovRadius then
        -- Normal is set up to function in shader, which uses different coord system
        localNormal = { x = renderGrid.supervisor.normal.x, y = renderGrid.supervisor.normal.y * -1 }
        angle =  angleBetween(localNormal, vec);
        if angle < 0.873 and angle > -0.873 then
            return true
        end
    end
    return false
end

function getNextTile(currentTileX, currentTileY, direction)
    if direction.x ~= 0 then
        if direction.x == 1 and currentTileX < #renderGrid.data then
            return renderGrid.data[currentTileX + 1][currentTileY]
        elseif direction.x == -1 and currentTileX > 1 then
            return renderGrid.data[currentTileX - 1][currentTileY]
        else
            if renderGrid.data[currentTileX][currentTileY + 1] ~= nil then
                return renderGrid.data[currentTileX][currentTileY + 1], { x = 0, y = -1}
            else
                return renderGrid.data[currentTileX][currentTileY - 1], { x = 0, y = 1}
            end
        end
    elseif direction.y ~= 0 then
        if direction.y == -1 and currentTileY < #renderGrid.data[1] then
            return renderGrid.data[currentTileX][currentTileY + 1]
        elseif direction.y == 1 and currentTileY and currentTileY > 1 then
            return renderGrid.data[currentTileX][currentTileY - 1]
        else
            if renderGrid.data[currentTileX + 1] ~= nil then
                return renderGrid.data[currentTileX + 1][currentTileY], { x = 1, y = 0}
            else
                return renderGrid.data[currentTileX -1][currentTileY], { x = -1, y = 0}
            end
        end
    end
end

local grid = {}
grid.__index = grid

function newGrid(level)
    local g = {}
    g.x = level.x
    g.y = level.y
    g.tileSize = level.tileSize
    g.data = loadGrid(level.grid, level.x, level.y, level.tileSize)
    g.width = #g.data
    g.height = #g.data[1]
    local sup = LEVELS[currentLevel].supervisor
    g.supervisor =  {tileX = sup.tileX, tileY = sup.tileY, turnSpeed = 0,
                        normal =  sup.direction, state = NONE}
    return setmetatable(g, grid)
end

function loadGrid(level, x, y, tileSize)
    parsedGrid = {}
    for i=1, table.getn(level) do
        parsedGrid[i] = {}
        for j=1, table.getn(level[i]) do
            item = newGridItem(level[i][j])
            item.localX = i
            item.localY = j
            tileX = x + (tileSize * (i - 1))
            tileY = y + (tileSize * (j - 1)) 
            item.pos = {x = tileX, y = tileY}
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
            it.draw(it)
        end
    end
end

function grid:swap(item1, item2)
    self.data[item1.localX][item1.localY] = item2
    self.data[item2.localX][item2.localY] = item1
    tmpLocalX = item1.localX
    tmpLocalY = item1.localY
    item1.localX = item2.localX
    item1.localY = item2.localY
    item2.localX = tmpLocalX
    item2.localY = tmpLocalY
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

function drawWorker(item)
    love.graphics.setColor(255, 255, 255)
    love.graphics.setPixelEffect(fx.fov)
    workerAnim:draw(item.pos.x, item.pos.y)
    love.graphics.setPixelEffect()

    if item.state == CONVERTING then
        love.graphics.setColor(255, 0, 0)
        love.graphics.rectangle('fill', item.pos.x, item.pos.y,
                                item.conversionBar.width,
                                item.conversionBar.height)
    elseif item.state == MOVING then
        love.graphics.setColor(255, 255, 255)
        love.graphics.print('MOV', item.pos.x, item.pos.y)
    elseif item.state == CONVERTED then
        pctLoyal = (item.loyalty * 32) / 100
        stencil = { x = item.pos.x, y = item.pos.y + 32 + pctLoyal, 
                    w = 64, h = 32}
        love.graphics.setStencil(loyaltyStencil)
        love.graphics.draw(convertedImg, item.pos.x, item.pos.y + 32)
        love.graphics.setStencil( )
    else
    end

end

stencil = nil
loyaltyStencil = function()
    if stencil ~= nil then
        love.graphics.rectangle("fill", stencil.x, stencil.y, stencil.w, stencil.h)
    end
end

function drawPlayer(item)
    love.graphics.setColor(255, 0, 0)
    love.graphics.rectangle('fill', item.pos.x, item.pos.y, 60, 60)
    love.graphics.setColor(0, 0, 0)
    if item.state == TALKING then
        love.graphics.print('T', item.pos.x + 5, item.pos.y + 10)
    elseif item.state == MOVING then
        love.graphics.print('MOV', item.pos.x + 5, item.pos.y + 10)
    else
        love.graphics.print('P1', item.pos.x + 5, item.pos.y + 10)
    end
    
end

function drawSupervisor(x, y)
    love.graphics.setColor(255, 0, 0)
    love.graphics.circle('fill', x + 32, y + 32, 10, 10)
    love.graphics.setColor(255, 255, 255)
end

function drawSpace(item)
    --love.graphics.setColor(255, 255, 255)
    --love.graphics.rectangle('fill', item.pos.x, item.pos.y, 64, 64)
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
        supervisor = { tileX = 1, tileY = 1, direction = { x = 1, y = 0} },
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
