local MainMenu = {}
MainMenu.__index = MainMenu

function MainMenu:new()
    local instance = setmetatable({}, MainMenu)

    -- Load the background and cloud images with the correct paths
    instance.backgroundImage = love.graphics.newImage('assets/Backgrounds/Background.png')
    instance.cloudsImage = love.graphics.newImage('assets/Backgrounds/Clouds.png')
    instance.cloudOffset = 0

    instance.buttons = {
        {text = "Start", x = 350, y = 250, w = 100, h = 50, action = function() GameState.switch(Game:new()) end},
        {text = "Options", x = 350, y = 320, w = 100, h = 50, action = function() GameState.push(Options:new()) end}
    }

    instance.is_overlay = false

    return instance
end

function MainMenu:enter()
    love.mouse.setGrabbed(false)
    love.mouse.setVisible(true)
end

function MainMenu:update(dt)
    -- Update the cloud offset for a slow parallax effect
    self.cloudOffset = (self.cloudOffset + dt * 20) % VIRTUAL_WIDTH
end

function MainMenu:draw()
    -- Calculate the scaling factors for the background
    local bg_w = self.backgroundImage:getWidth()
    local bg_h = self.backgroundImage:getHeight()
    local scale_x = VIRTUAL_WIDTH / bg_w
    local scale_y = VIRTUAL_HEIGHT / bg_h

    -- Draw the background, scaled to fit the screen
    love.graphics.draw(self.backgroundImage, 0, 0, 0, scale_x, scale_y)

    -- Calculate the scaling factors for the clouds
    local clouds_w = self.cloudsImage:getWidth()
    local clouds_h = self.cloudsImage:getHeight()
    local clouds_scale_x = VIRTUAL_WIDTH / clouds_w
    local clouds_scale_y = VIRTUAL_HEIGHT / clouds_h

    -- Draw the scrolling clouds, scaled to fit the screen
    love.graphics.draw(self.cloudsImage, -self.cloudOffset, 0, 0, clouds_scale_x, clouds_scale_y)
    love.graphics.draw(self.cloudsImage, -self.cloudOffset + VIRTUAL_WIDTH, 0, 0, clouds_scale_x, clouds_scale_y)

    -- Draw the rest of the UI
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(30))
    love.graphics.printf("Tongue-Tied Ascent", 0, 100, VIRTUAL_WIDTH, "center")

    love.graphics.setFont(love.graphics.newFont(20))
    -- Use virtual mouse coordinates for UI interaction
    local mx, my = getVirtualMousePosition()

    for _, button in ipairs(self.buttons) do
        if mx > button.x and mx < button.x + button.w and my > button.y and my < button.y + button.h then
            love.graphics.setColor(1, 1, 0)
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.rectangle("line", button.x, button.y, button.w, button.h)
        love.graphics.printf(button.text, button.x, button.y + 15, button.w, "center")
    end
end

function MainMenu:mousepressed(x, y, button)
    -- Use virtual mouse coordinates for UI clicks
    local vx, vy = getVirtualMousePosition()

    if button == 1 then
        for _, btn in ipairs(self.buttons) do
            if vx > btn.x and vx < btn.x + btn.w and vy > btn.y and vy < btn.y + btn.h then
                btn.action()
            end
        end
    end
end

return MainMenu