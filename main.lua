-- main.lua

require 'Player'
require 'Camera'
local sti = require "sti"
CONSTANTS = require 'constants'

function love.load()
    map = sti('level1.lua')

    platforms = {}
    anchors = {}
    
    if map.layers['platforms'] then
        for i, obj in ipairs(map.layers['platforms'].objects) do
            table.insert(platforms, {x = obj.x, y = obj.y, w = obj.width, h = obj.height})
        end
    end

    if map.layers['anchors'] then
        for i, obj in ipairs(map.layers['anchors'].objects) do
            local centerX = obj.x + obj.width / 2
            local centerY = obj.y + obj.height / 2
            table.insert(anchors, {x = centerX, y = centerY, radius = obj.width / 2})
        end
    end

    local playerStart = map.layers['meta'].objects[1]
    for i, obj in ipairs(map.layers['meta'].objects) do
        if obj.name == 'player_start' then
            playerStart = obj
            break
        end
    end
    playerStartX = playerStart.x
    playerStartY = playerStart.y

    -- THE CHANGE: Get map width in pixels and pass it to the camera
    local mapPixelWidth = map.width * map.tilewidth
    local mapPixelHeight = map.height * map.tileheight
    camera = Camera:new(mapPixelWidth, mapPixelHeight, CONSTANTS)
    player = Player:new(playerStartX, playerStartY, CONSTANTS)

    -- THE CHANGE: Sync both X and Y camera positions at the start
    camera.x = player.x
    camera.y = player.y
end


function love.update(dt)
    map:update(dt)
    
    -- THE FIX: Get the mouse's world coordinates here, once per frame.
    local worldMouseX, worldMouseY = camera:mouseToWorld(love.mouse.getPosition())
    -- Now pass them to the player's update function.
    player:update(dt, platforms, anchors, worldMouseX, worldMouseY)
    
    camera:update(player.x, player.y, dt)
end

function love.keypressed(key)
    if key == "r" then
        player:reset(playerStartX, playerStartY)
        -- THE CHANGE: Sync both X and Y camera positions on reset
        camera.x = player.x
        camera.y = player.y
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
    if player.state == "latched" then
        player:adjustAim(dx, dy)
    end
end

function love.mousepressed(x, y, button, istouch, presses)
    -- Left-click is ONLY for starting a jump charge from the ground.
    if button == 1 and player.state == "grounded" then
        player:startCharge()
    
    -- Right-click is ONLY for attempting to latch.
    elseif button == 2 then
        player:autoLatch()
    end
end

function love.mousereleased(x, y, button, istouch, presses)
    local worldX, worldY = camera:mouseToWorld(x, y)

    -- Left-click release is ONLY for firing a charged jump.
    if button == 1 and player.state == "grounded" then
        player:releaseCharge(worldX, worldY)

    -- Right-click release is ONLY for firing the slingshot from a latched state.
    elseif button == 2 and player.state == "latched" then
        player:releaseSlingshot()
    end
end

function love.draw()
    camera:attach()
    
    -- STI can draw any visual tile layers you have. We don't have any, but this is good practice.
    map:draw()

    -- We still need to draw our invisible objects for debugging/gameplay
    love.graphics.setColor(0.3, 0.7, 0.2)
    for i, p in ipairs(platforms) do
        love.graphics.rectangle("fill", p.x, p.y, p.w, p.h)
    end
    love.graphics.setColor(1, 0.5, 0.8, 0.8)
    for i, a in ipairs(anchors) do
        love.graphics.circle("fill", a.x, a.y, a.radius)
    end

    player:draw()

    camera:detach()

    -- Draw UI
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("State: " .. player.state, 10, 10)
end
