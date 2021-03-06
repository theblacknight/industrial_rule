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
WINNER = 6
FINISHED = 7

state = MENU

-- Grid items
local EMPTY = 0
local WORKER = 1
local PLAYER = 2
local SUPERVISOR = 3
local BLOCK = 4

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
    menu = love.graphics.newImage("assets/menu.png")
    worker = love.graphics.newImage("assets/worker.png")
    player = love.graphics.newImage("assets/player.png")
    convertedImg = love.graphics.newImage("assets/soc.png")
    workerAnim = newAnimation(worker, 64, 64, 0.5, 2)
    movingWorkerAnim = newAnimation(worker, 64, 64, 0.3, 5)
    movingWorkerAnim:setSequence(3, 5)
    playerAnim = newAnimation(player, 64, 64, 0.5, 8)
    playerAnim:setSequence(1, 2)

    controller = getController(1, buttonListener, stickListener)
end

function loadLevel()
    tween.stopAll()
    state = PLAY
    playerTarget = NONE
    renderGrid = newGrid(LEVELS[currentLevel])
    positionSupervisor()
    moveSupervisor()
end

function love.update(dt)
    if controller ~= nil then
        controller:update()
    end
    keyListener(dt)
    if state == PLAY then
        testForWin()
        fx.fov:send("supervisorNormal", {renderGrid.supervisor.normal.x, renderGrid.supervisor.normal.y * -1})
        fx.fov:send("supervisorPos", {renderGrid.supervisor.pos.x + 32, 568 - renderGrid.supervisor.pos.y})
        updateWorkers()
        updateSupervisor()
        workerAnim:update(dt)
        movingWorkerAnim:update(dt)
        playerAnim:update(dt)
        tween.update(dt)
        testCollisions()
    end
end

function love.draw()
    if state == MENU then
        love.graphics.draw(menu, 0, 0)
    elseif state == PLAY or state == STUNG or state == WINNER or state == FINISHED then
        love.graphics.setPixelEffect(fx.fov)
        love.graphics.draw(bg, 0, 0)
        love.graphics.setPixelEffect()
        if state == STUNG then
            drawRetry()
        elseif state == WINNER then
            drawNewLevel()
        elseif state == FINISHED then
            drawFinished()
        end
        renderGrid:draw()
        drawSupervisor(renderGrid.supervisor.pos.x, renderGrid.supervisor.pos.y)
        drawStatus()
    end
end

-- ********* CONTROLS *********

function buttonListener(button)
    if button == 'X' then
        if state == STUNG then
            loadLevel()
        elseif state == MENU then
            loadLevel()
        elseif state == WINNER then
            currentLevel = currentLevel + 1
            loadLevel()
        elseif state == FINISHED then
            love.event.quit()
        end
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

function keyListener(dt)
    if state == PLAY then
        if love.keyboard.isDown("right") then
            stickListener('RIGHT', { x = 1, y = 0})
        elseif love.keyboard.isDown("left") then
            stickListener('RIGHT', { x = -1, y = 0})
        elseif love.keyboard.isDown("up") then
            stickListener('RIGHT', { x = 0, y = -1})
        elseif love.keyboard.isDown("down") then
            stickListener('RIGHT', { x = 0, y = 1})
        elseif love.keyboard.isDown("w") then
            stickListener('LEFT', { x = 0, y = -1})
        elseif love.keyboard.isDown("a") then
            stickListener('LEFT', { x = -1, y = 0})
        elseif love.keyboard.isDown("s") then
            stickListener('LEFT', { x = 0, y = 1})
        elseif love.keyboard.isDown("d") then
            stickListener('LEFT', { x = 1, y = 0})
        else
            stickListener('LEFT', { x = 0, y = 0})
        end
    end
    if love.keyboard.isDown(" ") then
        buttonListener('X')
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

function testForWin()
    if renderGrid.workerCount == renderGrid.converted then
        if currentLevel == #LEVELS then
            state = FINISHED
        else
            state = WINNER
        end
    end
end

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
    item.tween = tween.start(0.5, item.conversionBar, { width = 60 },
                                'linear', conversionFinished, item)
end

function loyaltyDry(item, worker)
    item.state = NONE
    renderGrid.converted = renderGrid.converted - 1
    worker.loyaltyTween = nil
end

function conversionFinished(worker)
    worker.state = CONVERTED
    renderGrid.converted = renderGrid.converted + 1
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
    local sup = renderGrid.supervisor
    local tile = renderGrid.data[sup.localX][sup.localY]
    sup.pos = { x = tile.pos.x, y = tile.pos.y}
    sup.state = WALKING
end

function moveSupervisor()
    local sup = renderGrid.supervisor
    local nextTile, newDirection = getNextTile()
    if nextTile ~= nil and sup.state == WALKING then
        if newDirection ~= nil then
            sup.turnSpeed = getTurnSpeed(sup.normal, newDirection)
            sup.state = TURNING
        else
            tween.start(0.5, sup.pos, { x = nextTile.pos.x }, 'linear')
            tween.start(0.5, sup.pos, { y = nextTile.pos.y }, 'linear', moveSupervisor)
            sup.localX = nextTile.localX
            sup.localY = nextTile.localY
        end
    end
end

function getTurnSpeed(oldDirection, newDirection)
    if oldDirection.x == -1 then
        if newDirection.y == -1 then
            return 0.1
        else
            return -0.1
        end
    elseif oldDirection.x == 1 then
        if newDirection.y == -1 then
            return -0.1
        else
            return 0.1
        end
    elseif oldDirection.y == 1 then
        if newDirection.x == -1 then
            return 0.1
        else
            return -0.1
        end
    elseif oldDirection.y == -1 then
        if newDirection.x == -1 then
            return -0.1
        else
            return 0.1
        end
    end
    return 1.0
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
end

function isInFov(tile)
    supervisorPos = renderGrid.supervisor.pos
    vec = { x = item.pos.x - supervisorPos.x, y = item.pos.y - supervisorPos.y}
    if magnitude(vec) < fovRadius then
        -- Normal is set up to function in shader, which uses different coord system
        localNormal = { x = renderGrid.supervisor.normal.x, y = renderGrid.supervisor.normal.y }
        angle =  angleBetween(localNormal, vec);
        if angle < 0.873 and angle > -0.873 then
            return true
        end
    end
    return false
end

function getNextTile()
    sup = renderGrid.supervisor
    options =   {  
                    {getRelativeTile(sup, sup.normal.x, sup.normal.y), nil},
                    getRightTile(sup, sup.normal),
                    getLeftTile(sup, sup.normal),
                    {getRelativeTile(sup, sup.normal.x * -1, sup.normal.y * -1),
                        { x = sup.normal.x * -1, y = sup.normal.y * -1 } }
                }
    for i, tile in pairs(options) do
        if tile ~= nil and isWalkableTile(tile[1]) then
            return tile[1], tile[2]
        end
    end
end

function isWalkableTile(tile)
    return tile ~= nil and tile.type == EMPTY
end

function getRightTile(baseTile, normal)
    if normal.x == 1 then
        return {getRelativeTile(sup, 0, 1), { x = 0, y = 1}}
    elseif normal.x == -1 then
        return {getRelativeTile(sup, 0, -1), { x = 0, y = -1}}
    elseif normal.y == 1 then
        return {getRelativeTile(sup, -1, 0), { x = -1, y = 0}}
    elseif normal.y == -1 then
        return {getRelativeTile(sup, 1, 0), { x = 1, y = 0}}
    end
    return nil
end

function getLeftTile(baseTile, normal)
    if normal.x == 1 then
        return {getRelativeTile(sup, 0, -1), { x = 0, y = -1}}
    elseif normal.x == -1 then
        return {getRelativeTile(sup, 0, 1), { x = 0, y = 1}}
    elseif normal.y == 1 then
        return {getRelativeTile(sup, 1, 0), { x = 1, y = 0}}
    elseif normal.y == -1 then
        return {getRelativeTile(sup, -1, 0), { x = -1, y = 0}}
    end
    return nil
end

local grid = {}
grid.__index = grid

function newGrid(level)
    local g = {}
    g.x = level.x
    g.y = level.y
    g.tileSize = level.tileSize
    g.converted = 0
    g.data, g.workerCount = loadGrid(level.grid, level.x, level.y, level.tileSize)
    g.width = #g.data
    g.height = #g.data[1]
    local sup = LEVELS[currentLevel].supervisor
    g.supervisor =  {localX = sup.tileX, localY = sup.tileY, turnSpeed = 0,
                        normal =  sup.direction, state = NONE}
    return setmetatable(g, grid)
end

function loadGrid(level, x, y, tileSize)
    local parsedGrid = {}
    local workerCount = 0
    for i=1, table.getn(level) do
        for j=1, table.getn(level[i]) do
            column = parsedGrid[j]
            if column == nil then
                column = {}
                table.insert(parsedGrid, column)
            end
            item = newGridItem(level[i][j])
            item.localX = j
            item.localY = i
            tileX = x + (tileSize * (j - 1))
            tileY = y + (tileSize * (i - 1))
            item.pos = {x = tileX, y = tileY}
            if item.type == PLAYER then
                playerTile = item 
            elseif item.type == WORKER then
                workerCount = workerCount + 1
            end
            table.insert(column, item)
        end
    end
    return parsedGrid, workerCount
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
    local tmpLocalX = item1.localX
    local tmpLocalY = item1.localY
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

    if item.state == NONE or item.state == CONVERTING or item.state == CONVERTED then
        love.graphics.setPixelEffect(fx.fov)
        workerAnim:draw(item.pos.x, item.pos.y)
        love.graphics.setPixelEffect()
        if item.state == CONVERTING then
            love.graphics.setColor(255, 0, 0)
            love.graphics.rectangle('fill', item.pos.x, item.pos.y,
                                    item.conversionBar.width,
                                    item.conversionBar.height)
        elseif item.state == CONVERTED then
            pctLoyal = ((100 - item.loyalty) / 100) * 32
            stencil = { x = item.pos.x, y = item.pos.y + 32 + pctLoyal,
                        w = 64, h = 32}
            love.graphics.setStencil(loyaltyStencil)
            love.graphics.draw(convertedImg, item.pos.x, item.pos.y + 32)
            love.graphics.setStencil( )
        end
    elseif item.state == MOVING then
        love.graphics.setPixelEffect(fx.fov)
        movingWorkerAnim:draw(item.pos.x, item.pos.y)
        love.graphics.setPixelEffect()
    end

end

stencil = nil
loyaltyStencil = function()
    if stencil ~= nil then
        love.graphics.rectangle("fill", stencil.x, stencil.y, stencil.w, stencil.h)
    end
end

function drawPlayer(item)
    love.graphics.setPixelEffect(fx.fov)
    playerAnim:draw(item.pos.x, item.pos.y)
    love.graphics.setPixelEffect()
    if item.state == TALKING then
        if playerTarget == LEFT then
            playerAnim:setSequence(7, 7)
        elseif playerTarget == RIGHT then
            playerAnim:setSequence(8, 8)
        elseif playerTarget == UP then
            playerAnim:setSequence(6, 6)
        else 
            playerAnim:setSequence(1, 1)
        end
    else
        playerAnim:setSequence(1, 2)
    end
    
end

function drawSupervisor(x, y)
    love.graphics.setColor(255, 0, 0)
    love.graphics.circle('fill', x + 32, y + 32, 10, 10)
    love.graphics.setColor(255, 255, 255)
end

function drawSpace(item)
    if item.type == 4 then
        love.graphics.setColor(0, 0, 0)
        love.graphics.circle('fill', item.pos.x + 32, item.pos.y + 32, 10, 10)
        love.graphics.setColor(255, 255, 255) 
    end
end

function drawStatus()
    status = string.format("Converted: %d/%d", renderGrid.converted, renderGrid.workerCount)
    love.graphics.print(string.format("Level %s", currentLevel), 10, 10)
    love.graphics.print(status, 10, 25)
end

function drawRetry()
    love.graphics.print('You were taken out back and beaten!', 250, 550)
    love.graphics.print('Press space/X to retry', 275, 575)
end

function drawNewLevel()
    love.graphics.print('Press space/X to move on to the next level', 275, 575)
end

function drawFinished()
    love.graphics.print("That's all folks, thanks for playing.", 275, 575)
end

function swapPositions(worker)
    playerTile.state = MOVING
    worker.state = MOVING

    movingWorkerAnim:setSequence(3, 5)
    playerAnim:setSequence(3, 5)

    timer = {t = 0}
    tween.start(0.5, timer, { t = 100 }, 'linear', swapFinished, worker)
end

function swapFinished(worker)
    renderGrid:swap(playerTile, worker)
    playerTile.state = NONE
    worker.state = CONVERTED
    movingWorkerAnim:setSequence(4, 5)
    playerAnim:setSequence(4, 5)
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
            {EMPTY, EMPTY, EMPTY, EMPTY},
            {EMPTY, PLAYER, WORKER, EMPTY},
            {EMPTY, WORKER, WORKER, EMPTY},
            {EMPTY, WORKER, WORKER, EMPTY},
            {EMPTY, EMPTY, EMPTY, EMPTY}
        }
    },
    {
        tileSize = 64, x = 200, y = 100,
        supervisor = { tileX = 1, tileY = 1, direction = { x = 1, y = 0} },
        grid={
            {EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, BLOCK},
            {EMPTY, PLAYER, WORKER, WORKER, WORKER, EMPTY},
            {EMPTY, WORKER, WORKER, WORKER, WORKER, EMPTY},
            {EMPTY, WORKER, WORKER, WORKER, WORKER, EMPTY},
            {EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY}
        }
    },
    {
        tileSize = 64, x = 200, y = 100,
        supervisor = { tileX = 1, tileY = 1, direction = { x = 1, y = 0} },
        grid={
            {EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY},
            {EMPTY, PLAYER, WORKER, WORKER, WORKER, WORKER, EMPTY},
            {EMPTY, WORKER, WORKER, WORKER, WORKER, EMPTY, EMPTY},
            {EMPTY, WORKER, WORKER, WORKER, EMPTY, EMPTY},
            {EMPTY, EMPTY, EMPTY, EMPTY, EMPTY}
        }
    }
}
