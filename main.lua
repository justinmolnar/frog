-- Add this to the top of main.lua
DEBUG_MODE = true  -- Turn debug back on to see collision boxes

require 'Player'
require 'Camera'
local sti = require "sti"
CONSTANTS = require 'constants'

function love.load()
    map = sti('level1.lua')

    platforms = {}
    anchors = {}
    
    -- Process tile layers instead of object layers
    processTileLayers()
    
    -- Still get player start from meta layer
    local playerStart = map.layers['meta'].objects[1]
    for i, obj in ipairs(map.layers['meta'].objects) do
        if obj.name == 'player_start' then
            playerStart = obj
            break
        end
    end
    playerStartX = playerStart.x
    playerStartY = playerStart.y

    local mapPixelWidth = map.width * map.tilewidth
    local mapPixelHeight = map.height * map.tileheight
    camera = Camera:new(mapPixelWidth, mapPixelHeight, CONSTANTS)
    -- Create the player with tile-sized dimensions
    player = Player:new(playerStartX, playerStartY, CONSTANTS, map.tilewidth, map.tileheight)

    camera.x = player.x
    camera.y = player.y
end

function processTileLayers()
    -- Try to process tile layers first (new system)
    local foundTileLayers = false
    local platformsFound = 0
    local anchorsFound = 0
    
    -- Process platforms from ground tile layer
    if map.layers['ground'] and map.layers['ground'].type == "tilelayer" then
        foundTileLayers = true
        local layer = map.layers['ground']
        
        for y = 1, layer.height do
            for x = 1, layer.width do
                local tile = layer.data[y] and layer.data[y][x]
                if tile then
                    -- Check if this tile should be solid - support both "ground" and "solid" properties
                    local isSolid = false
                    if tile.properties then
                        isSolid = tile.properties.solid == true or 
                                 tile.properties.solid == "true" or 
                                 tile.properties.ground == "1" or
                                 tile.properties.ground == true
                    end
                    
                    if isSolid then
                        -- Use the actual map tile size instead of constants
                        local tileX = (x - 1) * map.tilewidth
                        local tileY = (y - 1) * map.tileheight
                        table.insert(platforms, {
                            x = tileX, 
                            y = tileY, 
                            w = map.tilewidth, 
                            h = map.tileheight,
                            tile = tile
                        })
                        platformsFound = platformsFound + 1
                    end
                end
            end
        end
    end
    
    -- Process anchors from anchors tile layer
    if map.layers['anchor'] and map.layers['anchor'].type == "tilelayer" then
        foundTileLayers = true
        local layer = map.layers['anchor']
        
        for y = 1, layer.height do
            for x = 1, layer.width do
                local tile = layer.data[y] and layer.data[y][x]
                if tile then
                    -- Check if this tile is an anchor - support multiple property formats
                    local isAnchor = false
                    if tile.properties then
                        isAnchor = tile.properties.anchor == true or 
                                  tile.properties.anchor == "true" or 
                                  tile.properties.anchor == "1"
                    end
                    
                    if isAnchor then
                        -- Use the actual map tile size instead of constants
                        local centerX = (x - 1) * map.tilewidth + map.tilewidth / 2
                        local centerY = (y - 1) * map.tileheight + map.tileheight / 2
                        table.insert(anchors, {
                            x = centerX, 
                            y = centerY, 
                            radius = map.tilewidth / 2,
                            tile = tile
                        })
                        anchorsFound = anchorsFound + 1
                    end
                end
            end
        end
    end
    
    -- Fallback to object layers (old system)
    if not foundTileLayers then
        processObjectLayers()
    end
end

function processObjectLayers()
    -- Your original object-based loading code
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
end

function love.update(dt)
    map:update(dt)
    
    local worldMouseX, worldMouseY = camera:mouseToWorld(love.mouse.getPosition())
    player:update(dt, platforms, anchors, worldMouseX, worldMouseY)
    
    camera:update(player.x, player.y, dt)
end

function love.keypressed(key)
    if key == "r" then
        player:reset(playerStartX, playerStartY)
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
    if button == 1 and player.state == "grounded" then
        player:startCharge()
    elseif button == 2 then
        player:autoLatch()
    end
end

function love.mousereleased(x, y, button, istouch, presses)
    local worldX, worldY = camera:mouseToWorld(x, y)

    if button == 1 and player.state == "grounded" then
        player:releaseCharge(worldX, worldY)
    elseif button == 2 and player.state == "latched" then
        player:releaseSlingshot()
    end
end

function love.draw()
    camera:attach()
    
    -- Always draw the actual tileset graphics (if any)
    map:draw()

    -- Draw debug collisions only if debug mode is on
    if DEBUG_MODE then
        drawDebugCollisions()
    end

    player:draw()

    camera:detach()

    -- Draw UI
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("State: " .. player.state, 10, 10)
    if DEBUG_MODE then
        love.graphics.print("Platforms: " .. #platforms, 10, 30)
        love.graphics.print("Anchors: " .. #anchors, 10, 50)
        love.graphics.print("Player: " .. math.floor(player.x) .. ", " .. math.floor(player.y), 10, 70)
        love.graphics.print("Press F1 to toggle debug", 10, 90)
    end
end

function drawDebugCollisions()
    -- Debug drawing for platforms
    love.graphics.setColor(0.3, 0.7, 0.2, 0.8)
    for i, p in ipairs(platforms) do
        love.graphics.rectangle("fill", p.x, p.y, p.w, p.h)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(i, p.x + 2, p.y + 2)
        love.graphics.setColor(0.3, 0.7, 0.2, 0.8)
    end
    
    -- Debug drawing for anchors
    love.graphics.setColor(1, 0.5, 0.8, 0.8)
    for i, a in ipairs(anchors) do
        love.graphics.circle("fill", a.x, a.y, a.radius)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(i, a.x - 5, a.y - 5)
        love.graphics.setColor(1, 0.5, 0.8, 0.8)
    end
    
    -- Draw player spawn point
    love.graphics.setColor(1, 1, 0, 0.8)
    love.graphics.circle("fill", playerStartX, playerStartY, 10)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("SPAWN", playerStartX - 15, playerStartY - 20)
end