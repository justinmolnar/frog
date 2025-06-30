local Game = {}
Game.__index = Game

local player, camera, map, platforms, anchors, playerStartX, playerStartY

function Game:new()
    local instance = setmetatable({}, Game)

    -- THIS IS THE FIX: Load the images that were removed by mistake
    instance.backgroundImage = love.graphics.newImage('assets/Backgrounds/Background.png')
    instance.cloudsImage = love.graphics.newImage('assets/Backgrounds/Clouds.png')
    instance.cloudOffset = 0

    instance.gearButton = {
        text = "⚙",
        x = VIRTUAL_WIDTH - 54,
        y = 10, w = 44, h = 44,
        action = function() GameState.push(Options:new()) end
    }
    
    instance.checkpointUI = {
        placeButton = { text = "Place", x = 10, y = 10, w = 80, h = 35 },
        returnButton = { text = "Return", x = 155, y = 10, w = 80, h = 35 },
        flagX = 105, -- Position for the flag icon
        flagY = 8
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
    map.layers['ground'].tintcolor = {180, 180, 255, 255}
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

    -- Correctly increment the cloud offset for animation
    self.cloudOffset = self.cloudOffset + dt * 20

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

function Game:draw()
    -- Clear the screen with a black background to start fresh
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle('fill', 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)

    -- THIS IS THE FIX: Set the color to a dimmer grey for the background layers
    love.graphics.setColor(0.7, 0.7, 0.7, 1)

    -- 1. Draw Background (deepest layer)
    love.graphics.push()
    local bg_scale = VIRTUAL_HEIGHT / self.backgroundImage:getHeight()
    local parallax_x = (camera.x * 0.2) % (self.backgroundImage:getWidth() * bg_scale)
    love.graphics.translate(-parallax_x, 0)
    love.graphics.draw(self.backgroundImage, 0, 0, 0, bg_scale, bg_scale)
    love.graphics.draw(self.backgroundImage, self.backgroundImage:getWidth() * bg_scale - 2, 0, 0, bg_scale, bg_scale)
    love.graphics.pop()

    -- 2. Draw Clouds (middle layer) with corrected animation
    love.graphics.push()
    local clouds_scale = VIRTUAL_HEIGHT / self.cloudsImage:getHeight()
    local scaled_cloud_width = self.cloudsImage:getWidth() * clouds_scale
    local parallax_clouds_x = (camera.x * 0.5 + self.cloudOffset) % scaled_cloud_width
    love.graphics.translate(-parallax_clouds_x, 0)
    love.graphics.draw(self.cloudsImage, 0, 0, 0, clouds_scale, clouds_scale)
    love.graphics.draw(self.cloudsImage, scaled_cloud_width, 0, 0, clouds_scale, clouds_scale)
    love.graphics.pop()

    -- THIS IS THE FIX: Reset the color to full white before drawing the game world
    love.graphics.setColor(1, 1, 1, 1)

    -- 3. Draw Game World (foreground layer) with the camera
    camera:attach()
    for i = 1, #map.layers do
        local layer = map.layers[i]
        if layer.visible and layer.type ~= "objectgroup" then
            map:drawLayer(layer)
        end
    end
    if Settings.checkpoints and player.checkpoint then
        love.graphics.setFont(self.emojiFontLarge)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("🚩", player.checkpoint.x, player.checkpoint.y - 16)
    end
    player:draw(camera, map.tilewidth, map.tileheight)
    if DEBUG_MODE then
        drawDebugCollisions()
    end
    camera:detach()

    -- 4. Draw UI (topmost layer, no camera transforms)
    love.graphics.setColor(1, 1, 1, 1)

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

    if Settings.checkpoints or self.isIronmanRun then
        local r, g, b, a = love.graphics.getColor()
        local mx, my = getVirtualMousePosition()

        local placeBtn = self.checkpointUI.placeButton
        local placeIsDisabled = player.state ~= "grounded" or player.checkpointsAvailable <= 0 or self.isIronmanRun
        if placeIsDisabled then love.graphics.setColor(0.5, 0.5, 0.5, 0.8)
        elseif mx > placeBtn.x and mx < placeBtn.x + placeBtn.w and my > placeBtn.y and my < placeBtn.y + placeBtn.h then love.graphics.setColor(1, 1, 0)
        else love.graphics.setColor(1, 1, 1) end
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", placeBtn.x, placeBtn.y, placeBtn.w, placeBtn.h, 5, 5)
        love.graphics.setFont(self.uiFont)
        love.graphics.printf(placeBtn.text, placeBtn.x, placeBtn.y + (placeBtn.h - self.uiFont:getHeight())/2, placeBtn.w, "center")

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(self.emojiFontLarge)
        love.graphics.print("🚩", self.checkpointUI.flagX, self.checkpointUI.flagY, 0, 0.7, 0.7)
        love.graphics.setFont(self.uiFont)
        local countText = string.format("%d/%d", player.checkpointsAvailable, player.maxCheckpoints)
        love.graphics.printf(countText, self.checkpointUI.flagX - 5, self.checkpointUI.flagY + 22, 40, "center")
        
        local returnBtn = self.checkpointUI.returnButton
        local returnIsDisabled = player.checkpoint == nil or self.isIronmanRun
        if returnIsDisabled then love.graphics.setColor(0.5, 0.5, 0.5, 0.8)
        elseif mx > returnBtn.x and mx < returnBtn.x + returnBtn.w and my > returnBtn.y and my < returnBtn.y + returnBtn.h then love.graphics.setColor(1, 1, 0)
        else love.graphics.setColor(1, 1, 1) end
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", returnBtn.x, returnBtn.y, returnBtn.w, returnBtn.h, 5, 5)
        love.graphics.setFont(self.uiFont)
        love.graphics.printf(returnBtn.text, returnBtn.x, returnBtn.y + (returnBtn.h - self.uiFont:getHeight())/2, returnBtn.w, "center")

        -- Show warning text in Ironfrog mode
        if self.isIronmanRun then
            love.graphics.setColor(1, 0.5, 0.5, 1)
            love.graphics.setFont(self.uiFont)
            love.graphics.printf("No Checkpoints In Ironfrog!", 10, 55, 300, "left")
        end

        love.graphics.setColor(r, g, b, a)
        love.graphics.setLineWidth(1)
    end
end


function Game:keypressed(key)
    if self.isPaused then return end

    if key == "r" then
        player:reset(playerStartX, playerStartY)
        camera.x = player.x
        camera.y = player.y
    -- F1 functionality has been removed
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

        if Settings.checkpoints or self.isIronmanRun then
            local placeBtn = self.checkpointUI.placeButton
            local placeIsDisabled = player.state ~= "grounded" or player.checkpointsAvailable <= 0 or self.isIronmanRun
            if not placeIsDisabled and (vx > placeBtn.x and vx < placeBtn.x + placeBtn.w and vy > placeBtn.y and vy < placeBtn.y + placeBtn.h) then
                player:placeCheckpoint()
                return
            end

            local returnBtn = self.checkpointUI.returnButton
            local returnIsDisabled = player.checkpoint == nil or self.isIronmanRun
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