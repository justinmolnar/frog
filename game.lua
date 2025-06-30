local Game = {}
Game.__index = Game

local player, camera, map, platforms, anchors, playerStartX, playerStartY

function Game:new()
    local instance = setmetatable({}, Game)

    instance.gearButton = {
        text = "⚙",
        x = VIRTUAL_WIDTH - 54,
        y = 10, w = 44, h = 44,
        action = function() GameState.push(Options:new()) end
    }
    
    instance.checkpointButtons = {
        place = { x = 10, y = 100, w = 150, h = 30 },
        return_to = { text = "Return to 🚩", x = 10, y = 140, w = 150, h = 30 }
    }

    -- Create fonts ONCE and store them for reuse.
    instance.uiFont = love.graphics.newFont(14)
    instance.debugFont = love.graphics.newFont(12)
    instance.emojiFontLarge = love.graphics.newFont("assets/NotoEmoji.ttf", 32)
    instance.emojiFontSmall = love.graphics.newFont("assets/NotoEmoji.ttf", 14)

    instance.isPaused = false
    instance.is_overlay = false
    instance.isIronmanRun = Settings.ironman

    return instance
end

function Game:enter()
    love.mouse.setGrabbed(true)
    love.mouse.setVisible(true)

    if self.isIronmanRun then
        Settings.showTongueRange = false
        Settings.showJumpPower = false
        Settings.checkpoints = false
    end

    map = sti('level1.lua')
    platforms = {}
    anchors = {}
    processTileLayers()

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
    player = Player:new(playerStartX, playerStartY, CONSTANTS, map.tilewidth, map.tileheight)

    camera.x = player.x
    camera.y = player.y

    DEBUG_MODE = false
    DEBUG_FLY_MODE = false
end

function Game:pause()
    love.mouse.setGrabbed(false)
    self.isPaused = true
end

function Game:resume()
    love.mouse.setGrabbed(true)
    love.mouse.setVisible(true)
    self.isPaused = false
end

function Game:leave()
    love.mouse.setGrabbed(false)
    player, camera, map, platforms, anchors, playerStartX, playerStartY = nil, nil, nil, nil, nil, nil, nil
end

function Game:update(dt)
    if self.isPaused then return end

    local scaledDt = dt * CONSTANTS.GAME_SPEED_MULTIPLIER
    map:update(scaledDt)

    local vMouseX, vMouseY = getVirtualMousePosition()
    local worldMouseX, worldMouseY = camera:mouseToWorld(vMouseX, vMouseY)

    if DEBUG_FLY_MODE then
        player:fly(scaledDt)
    else
        player:update(scaledDt, platforms, anchors, worldMouseX, worldMouseY)
    end

    camera:update(player.x, player.y, dt)
end

-- CORRECTED DRAW FUNCTION
function Game:draw()
    -- Use a single camera transform for all world objects
    camera:attach()

    -- Manually draw each map layer. This respects the camera's transform.
    -- We iterate numerically to control the draw order.
    for i = 1, #map.layers do
        local layer = map.layers[i]
        -- Make sure the layer is visible and we're not drawing the object layer here
        if layer.visible and layer.type ~= "objectgroup" then
            map:drawLayer(layer)
        end
    end
    
    -- Draw the placed checkpoint flag in the game world
    if Settings.checkpoints and player.checkpoint then
        love.graphics.setFont(self.emojiFontLarge)
        love.graphics.setColor(1, 1, 1, 1)
        local flag_width = self.emojiFontLarge:getWidth("🚩")
        love.graphics.print("🚩", player.checkpoint.x, player.checkpoint.y - 16)
    end
    
    -- Draw the player and its overlays (like the tongue range circle)
    player:draw(camera, map.tilewidth, map.tileheight)
    
    -- Draw debug information inside the camera view
    if DEBUG_MODE then
        drawDebugCollisions()
    end

    camera:detach()
    -- End of world-space drawing

    -- UI Drawing (Screen Space)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.debugFont)
    love.graphics.print("State: " .. (player and player.state or "unknown"), 10, 10)
    love.graphics.print("Press F1 to toggle debug", 10, 30)
    love.graphics.print("Press F2 to toggle fly mode", 10, 50)
    if DEBUG_MODE then love.graphics.print("DEBUG MODE ON", 10, 70) end
    if DEBUG_FLY_MODE then love.graphics.print("FLY MODE ON", 10, 90) end

    -- Draw Gear Button
    do
        local btn = self.gearButton
        local mx, my = getVirtualMousePosition()
        
        love.graphics.setFont(self.emojiFontLarge)
        if mx > btn.x and mx < btn.x + btn.w and my > btn.y and my < btn.y + btn.h then
            love.graphics.setColor(1, 1, 0, 0.8)
        else
            love.graphics.setColor(1, 1, 1, 0.8)
        end
        love.graphics.printf(btn.text, btn.x, btn.y + (btn.h - 32) / 2, btn.w, "center")
    end

    -- Draw Checkpoint UI
    if Settings.checkpoints then
        local r, g, b, a = love.graphics.getColor()
        local mx, my = getVirtualMousePosition()

        -- Draw "Place Checkpoint" button
        do
            local btn = self.checkpointButtons.place
            local isDisabled = player.state ~= "grounded" or player.checkpointsAvailable <= 0
            
            if isDisabled then love.graphics.setColor(0.5, 0.5, 0.5, 0.8)
            elseif mx > btn.x and mx < btn.x + btn.w and my > btn.y and my < btn.y + btn.h then love.graphics.setColor(1, 1, 0)
            else love.graphics.setColor(1, 1, 1) end

            love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)

            local textPart = "Place"
            local countPart = string.format("%d/%d", player.checkpointsAvailable, player.maxCheckpoints)
            
            love.graphics.setFont(self.uiFont)
            love.graphics.print(textPart, btn.x + 8, btn.y + (btn.h - self.uiFont:getHeight()) / 2)
            love.graphics.print(countPart, btn.x + btn.w - self.uiFont:getWidth(countPart) - 8, btn.y + (btn.h - self.uiFont:getHeight()) / 2)
            
            love.graphics.setFont(self.emojiFontSmall)
            love.graphics.print("🚩", btn.x + 55, btn.y + (btn.h - self.emojiFontSmall:getHeight()) / 2)
        end

        -- Draw "Return to Checkpoint" button
        do
            local btn = self.checkpointButtons.return_to
            local isDisabled = player.checkpoint == nil
            
            if isDisabled then love.graphics.setColor(0.5, 0.5, 0.5, 0.8)
            elseif mx > btn.x and mx < btn.x + btn.w and my > btn.y and my < btn.y + btn.h then love.graphics.setColor(1, 1, 0)
            else love.graphics.setColor(1, 1, 1) end

            love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)
            
            local textPart = "Return to"

            love.graphics.setFont(self.uiFont)
            love.graphics.print(textPart, btn.x + 8, btn.y + (btn.h - self.uiFont:getHeight()) / 2)

            love.graphics.setFont(self.emojiFontSmall)
            love.graphics.print("🚩", btn.x + btn.w - self.emojiFontSmall:getWidth("🚩") - 8, btn.y + (btn.h - self.emojiFontSmall:getHeight())/2)
        end
        love.graphics.setColor(r, g, b, a)
    end
end


function Game:keypressed(key)
    if self.isPaused then return end

    if key == "r" then
        player:reset(playerStartX, playerStartY)
        camera.x = player.x
        camera.y = player.y
    elseif key == "f1" then
        DEBUG_MODE = not DEBUG_MODE
    elseif key == "f2" then
        DEBUG_FLY_MODE = not DEBUG_FLY_MODE
    elseif key == "escape" then
        GameState.push(Options:new())
    end
end

function Game:mousemoved(x, y, dx, dy)
    if self.isPaused then return end

    if player and player.state == "latched" then
        player:adjustAim(dx, dy)
    end
end

function Game:mousepressed(x, y, button)
    if self.isPaused then return end

    local vx, vy = getVirtualMousePosition()

    if button == 1 then
        local btn = self.gearButton
        if vx > btn.x and vx < btn.x + btn.w and vy > btn.y and vy < btn.y + btn.h then
            btn.action()
            return
        end

        if Settings.checkpoints then
            local placeBtn = self.checkpointButtons.place
            local placeIsDisabled = player.state ~= "grounded" or player.checkpointsAvailable <= 0
            if not placeIsDisabled and (vx > placeBtn.x and vx < placeBtn.x + placeBtn.w and vy > placeBtn.y and vy < placeBtn.y + placeBtn.h) then
                player:placeCheckpoint()
                return
            end

            local returnBtn = self.checkpointButtons.return_to
            local returnIsDisabled = player.checkpoint == nil
            if not returnIsDisabled and (vx > returnBtn.x and vx < returnBtn.x + returnBtn.w and vy > returnBtn.y and vy < returnBtn.y + returnBtn.h) then
                player:returnToCheckpoint()
                return
            end
        end

        if player.state == "grounded" then
            player:startCharge()
        end
    elseif button == 2 then
        player:startLatchAttempt()
    end
end

function Game:mousereleased(x, y, button)
    if self.isPaused then return end

    local vx, vy = getVirtualMousePosition()
    local worldX, worldY = camera:mouseToWorld(vx, vy)

    if button == 1 and player.state == "grounded" then
        player:releaseCharge(worldX, worldY)
    elseif button == 2 then
        if player.state == "latched" then
            player:releaseSlingshot()
        else
            player:cancelLatchAttempt()
        end
    end
end

function processTileLayers()
    if map.layers['ground'] and map.layers['ground'].type == "tilelayer" then
        local layer = map.layers['ground']
        for y = 1, layer.height do
            for x = 1, layer.width do
                local tile = layer.data[y] and layer.data[y][x]
                if tile and (tile.properties.ground == "1" or tile.properties.solid == true) then
                    table.insert(platforms, {
                        x = (x - 1) * map.tilewidth, y = (y - 1) * map.tileheight,
                        w = map.tilewidth, h = map.tileheight
                    })
                end
            end
        end
    end
    if map.layers['anchor'] and map.layers['anchor'].type == "tilelayer" then
        local layer = map.layers['anchor']
        for y = 1, layer.height do
            for x = 1, layer.width do
                local tile = layer.data[y] and layer.data[y][x]
                if tile and (tile.properties.anchor == "1" or tile.properties.anchor == true) then
                    table.insert(anchors, {
                        x = (x - 1) * map.tilewidth + map.tilewidth / 2,
                        y = (y - 1) * map.tileheight + map.tileheight / 2,
                        radius = map.tilewidth / 2,
                        draw_x = (x - 1) * map.tilewidth,
                        draw_y = (y - 1) * map.tileheight,
                        quad = tile.quad,
                        image = map.tilesets[tile.tileset].image
                    })
                end
            end
        end
    end
end

function drawDebugCollisions()
    love.graphics.setColor(0.3, 0.7, 0.2, 0.8)
    for _, p in ipairs(platforms) do
        love.graphics.rectangle("line", p.x, p.y, p.w, p.h)
    end
    love.graphics.setColor(1, 0.5, 0.8, 0.8)
    for _, a in ipairs(anchors) do
        love.graphics.circle("line", a.x, a.y, a.radius)
    end
    love.graphics.setColor(1, 1, 0, 0.6)
    love.graphics.circle("line", playerStartX, playerStartY, 8)
    love.graphics.print("SPAWN", playerStartX - 15, playerStartY - 20)
end

return Game