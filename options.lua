local Options = {}
Options.__index = Options

local function newCheckbox(y, text, settingKey, action)
    return {
        x = 250, y = y, w = 350, h = 40, box_w = 25,
        text = text,
        settingKey = settingKey,
        action = action
    }
end

function Options:new()
    local instance = setmetatable({}, Options)
    
    -- Load images for the background with the correct paths
    instance.backgroundImage = love.graphics.newImage('assets/Backgrounds/Background.png')
    instance.cloudsImage = love.graphics.newImage('assets/Backgrounds/Clouds.png')

    instance.checkboxes = {
        newCheckbox(120, "Show Tongue Range", "showTongueRange"),
        newCheckbox(170, "Show Jump Power Meter", "showJumpPower"),
        newCheckbox(220, "Checkpoints", "checkpoints"),
        newCheckbox(270, "Ironman Mode", "ironman")
    }

    instance.actionButtons = {
        {text = "Restart", x = 240, y = 450, w = 100, h = 50, action = function() GameState.switch(Game:new()) end},
        {text = "Quit", x = 360, y = 450, w = 100, h = 50, action = function() love.event.quit() end},
        {text = "Back", x = 480, y = 450, w = 100, h = 50, action = function() GameState.pop() end}
    }

    instance.is_overlay = true
    instance.showConfirmModal = false
    instance.confirmButtons = {
        {text = "OK", x = 290, y = 320, w = 100, h = 50},
        {text = "Cancel", x = 410, y = 320, w = 100, h = 50}
    }

    return instance
end

function Options:enter()
    love.mouse.setGrabbed(false)
    love.mouse.setVisible(true)
end

function Options:drawConfirmModal()
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 200, 200, 400, 200)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", 200, 200, 400, 200)

    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.printf("Disable Ironman mode for this run? \n\nThis cannot be undone.", 200, 240, 400, "center")

    local mx, my = getVirtualMousePosition()
    for _, btn in ipairs(self.confirmButtons) do
        if mx > btn.x and mx < btn.x + btn.w and my > btn.y and my < btn.y + btn.h then
            love.graphics.setColor(1, 1, 0)
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)
        love.graphics.printf(btn.text, btn.x, btn.y + 15, btn.w, "center")
    end
end

function Options:draw()
    local underlyingState = GameState.getUnderlyingState()
    local inGame = (underlyingState and underlyingState.isIronmanRun ~= nil)

    -- If we are not in the game, draw the background images.
    -- Otherwise, draw the overlay
    if not inGame then
        -- Calculate the scaling factors for the background
        local bg_w = self.backgroundImage:getWidth()
        local bg_h = self.backgroundImage:getHeight()
        local scale_x = VIRTUAL_WIDTH / bg_w
        local scale_y = VIRTUAL_HEIGHT / bg_h
        love.graphics.draw(self.backgroundImage, 0, 0, 0, scale_x, scale_y)

        -- Calculate the scaling factors for the clouds
        local clouds_w = self.cloudsImage:getWidth()
        local clouds_h = self.cloudsImage:getHeight()
        local clouds_scale_x = VIRTUAL_WIDTH / clouds_w
        local clouds_scale_y = VIRTUAL_HEIGHT / clouds_h
        love.graphics.draw(self.cloudsImage, 0, 0, 0, clouds_scale_x, clouds_scale_y)
    else
        love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
        love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    end


    if self.showConfirmModal then
        self:drawConfirmModal()
        return
    end
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(30))
    love.graphics.printf("Options", 0, 50, VIRTUAL_WIDTH, "center")

    love.graphics.setFont(love.graphics.newFont(18))
    local mx, my = getVirtualMousePosition()

    for _, cb in ipairs(self.checkboxes) do
        local isDisabled = false
        -- MODIFIED: Dependent options are now disabled if Ironman setting is on.
        if Settings.ironman and (cb.settingKey == "showTongueRange" or cb.settingKey == "showJumpPower" or cb.settingKey == "checkpoints") then
            isDisabled = true
        end
        -- You can't turn Ironman ON if you're already in a run.
        if inGame and cb.settingKey == "ironman" and not underlyingState.isIronmanRun then
             isDisabled = true
        end

        if isDisabled then
            love.graphics.setColor(0.5, 0.5, 0.5)
        elseif mx > cb.x and mx < cb.x + cb.w and my > cb.y and my < cb.y + cb.h then
            love.graphics.setColor(1, 1, 0)
        else
            love.graphics.setColor(1, 1, 1)
        end

        love.graphics.rectangle("line", cb.x, cb.y + (cb.h - cb.box_w) / 2, cb.box_w, cb.box_w)
        if Settings[cb.settingKey] then
            love.graphics.printf("X", cb.x, cb.y + (cb.h - cb.box_w) / 2, cb.box_w, "center")
        end
        love.graphics.printf(cb.text, cb.x + cb.box_w + 10, cb.y + (cb.h - 18) / 2, cb.w, "left")
        
        if cb.settingKey == "ironman" and inGame and not underlyingState.isIronmanRun then
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.print("(Cannot enable during a run)", cb.x + 160, cb.y + 10)
        end
    end

    for _, btn in ipairs(self.actionButtons) do
        if mx > btn.x and mx < btn.x + btn.w and my > btn.y and my < btn.y + btn.h then
            love.graphics.setColor(1, 1, 0)
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)
        love.graphics.printf(btn.text, btn.x, btn.y + 15, btn.w, "center")
    end
end

function Options:handleModalClick(x, y)
    local underlyingState = GameState.getUnderlyingState()
    
    for _, btn in ipairs(self.confirmButtons) do
        if x > btn.x and x < btn.x + btn.w and y > btn.y and y < btn.y + btn.h then
            if btn.text == "OK" then
                Settings.ironman = false
                if underlyingState and underlyingState.isIronmanRun ~= nil then
                    underlyingState.isIronmanRun = false
                end
            end
            self.showConfirmModal = false
            return true
        end
    end
    return false
end

function Options:mousepressed(x, y, button)
    local vx, vy = getVirtualMousePosition()

    if button ~= 1 then return end

    if self.showConfirmModal then
        self:handleModalClick(vx, vy)
        return
    end

    local underlyingState = GameState.getUnderlyingState()
    local inGame = (underlyingState and underlyingState.isIronmanRun ~= nil)

    for _, cb in ipairs(self.checkboxes) do
        if vy > cb.y and vy < cb.y + cb.h and vx > cb.x and vx < cb.x + cb.w then
            
            -- Logic for Ironman checkbox
            if cb.settingKey == "ironman" then
                local isRunLocked = (inGame and underlyingState.isIronmanRun)

                if inGame and not isRunLocked then
                    -- Cannot turn Ironman ON mid-run. Do nothing.
                elseif isRunLocked then
                    -- Trying to turn Ironman OFF mid-run. Show the modal.
                    self.showConfirmModal = true
                else
                    -- Not in a run, so toggle freely.
                    Settings.ironman = not Settings.ironman
                    -- If we just turned it ON, immediately force other settings off.
                    if Settings.ironman then
                        Settings.showTongueRange = false
                        Settings.showJumpPower = false
                        Settings.checkpoints = false
                    end
                end
            -- Logic for other checkboxes (only clickable if Ironman is off)
            elseif not Settings.ironman then
                Settings[cb.settingKey] = not Settings[cb.settingKey]
            end
        end
    end

    for _, btn in ipairs(self.actionButtons) do
        if vx > btn.x and vx < btn.x + btn.w and vy > btn.y and vy < btn.y + btn.h then
            btn.action()
        end
    end
end

return Options