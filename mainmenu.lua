local MainMenu = {}
MainMenu.__index = MainMenu

function MainMenu:new()
    local instance = setmetatable({}, MainMenu)
    
    instance.buttons = {
        -- MODIFIED: Use GameState.switch to replace the menu with the game
        {text = "Start", x = 350, y = 250, w = 100, h = 50, action = function() GameState.switch(Game:new()) end},
        {text = "Options", x = 350, y = 320, w = 100, h = 50, action = function() GameState.push(Options:new()) end}
    }
    
    -- This is an opaque screen, not an overlay
    instance.is_overlay = false
    
    return instance
end

function MainMenu:draw()
    love.graphics.setBackgroundColor(0.1, 0.1, 0.1) 
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(30))
    love.graphics.printf("Tongue-Tied Ascent", 0, 100, love.graphics.getWidth(), "center")
    
    love.graphics.setFont(love.graphics.newFont(20))
    for _, button in ipairs(self.buttons) do
        local mx, my = love.mouse.getPosition()
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
    if button == 1 then
        for _, btn in ipairs(self.buttons) do
            if x > btn.x and x < btn.x + btn.w and y > btn.y and y < btn.y + btn.h then
                btn.action()
            end
        end
    end
end

return MainMenu