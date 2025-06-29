local Options = {}
Options.__index = Options

local function newCheckbox(y, text, settingKey, action)
    return {
        x = 250, y = y, w = 300, h = 40, box_w = 25,
        text = text,
        settingKey = settingKey,
        action = action
    }
end

function Options:new()
    local instance = setmetatable({}, Options)

    instance.checkboxes = {
        newCheckbox(120, "Show Tongue Range", "showTongueRange"),
        newCheckbox(170, "Show Jump Power Meter", "showJumpPower"),
        newCheckbox(220, "Checkpoints", "checkpoints"),
        newCheckbox(270, "Ironman Mode", "ironman"),
        newCheckbox(320, "Speedrun Mode", "speedrunMode"),
        newCheckbox(370, "Fullscreen", "fullscreen", function()
            toggleFullscreen()
        end)
    }

    instance.actionButtons = {
        {text = "Restart", x = 240, y = 450, w = 100, h = 50, action = function() GameState.switch(Game:new()) end},
        {text = "Quit", x = 360, y = 450, w = 100, h = 50, action = function() love.event.quit() end},
        {text = "Back", x = 480, y = 450, w = 100, h = 50, action = function() GameState.pop() end}
    }

    instance.is_overlay = true

    return instance
end

function Options:enter()
    love.mouse.setGrabbed(false)
    love.mouse.setVisible(true)
end

function Options:draw()
    love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
    love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(30))
    love.graphics.printf("Options", 0, 50, VIRTUAL_WIDTH, "center")

    love.graphics.setFont(love.graphics.newFont(18))
    -- Use virtual mouse coordinates for UI interaction
    local mx, my = getVirtualMousePosition()

    for _, cb in ipairs(self.checkboxes) do
        if my > cb.y and my < cb.y + cb.h and mx > cb.x and mx < cb.x + cb.w then
            love.graphics.setColor(1, 1, 0)
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.rectangle("line", cb.x, cb.y + (cb.h - cb.box_w) / 2, cb.box_w, cb.box_w)
        if Settings[cb.settingKey] then
            love.graphics.printf("X", cb.x, cb.y + (cb.h - cb.box_w) / 2, cb.box_w, "center")
        end
        love.graphics.printf(cb.text, cb.x + cb.box_w + 10, cb.y + (cb.h - 18) / 2, cb.w, "left")
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

function Options:mousepressed(x, y, button)
    -- Use virtual mouse coordinates for UI clicks
    local vx, vy = getVirtualMousePosition()

    if button == 1 then
        for _, cb in ipairs(self.checkboxes) do
            if vy > cb.y and vy < cb.y + cb.h and vx > cb.x and vx < cb.x + cb.w then
                Settings[cb.settingKey] = not Settings[cb.settingKey]
                if cb.action then cb.action() end
            end
        end
        for _, btn in ipairs(self.actionButtons) do
            if vx > btn.x and vx < btn.x + btn.w and vy > btn.y and vy < btn.y + btn.h then
                btn.action()
            end
        end
    end
end

return Options