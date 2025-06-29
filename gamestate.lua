-- A more robust stack-based game state manager

local GameState = {}

local stack = {}

function GameState.current()
    return stack[#stack]
end

function GameState.push(state, ...)
    local old_state = GameState.current()
    if old_state and old_state.pause then
        old_state:pause()
    end
    
    table.insert(stack, state)
    
    local new_state = GameState.current()
    if new_state and new_state.enter then
        new_state:enter(...)
    end
end

function GameState.pop(...)
    local old_state = GameState.current()
    if old_state and old_state.leave then
        old_state:leave()
    end
    
    table.remove(stack)
    
    local new_state = GameState.current()
    if new_state and new_state.resume then
        new_state:resume(...)
    end
end

function GameState.switch(state, ...)
    while GameState.current() do
        GameState.pop()
    end
    GameState.push(state, ...)
end

function love.update(dt)
    local state = GameState.current()
    if state and state.update then
        state:update(dt)
    end
end

function love.draw()
    love.graphics.setCanvas(gameCanvas)
    -- MODIFIED: Clear the canvas to opaque black (r=0, g=0, b=0, a=1)
    love.graphics.clear(0, 0, 0, 1)

    local first_to_draw = #stack
    for i = #stack, 1, -1 do
        local state = stack[i]
        if not (state.is_overlay and state.is_overlay == true) then
            first_to_draw = i
            break
        end
    end

    for i = first_to_draw, #stack do
        local state = stack[i]
        if state.draw then
            state:draw()
        end
    end

    love.graphics.setCanvas()

    local winWidth, winHeight = love.graphics.getDimensions()
    local scale = math.min(winWidth / VIRTUAL_WIDTH, winHeight / VIRTUAL_HEIGHT)
    local x = (winWidth - (VIRTUAL_WIDTH * scale)) / 2
    local y = (winHeight - (VIRTUAL_HEIGHT * scale)) / 2
    
    love.graphics.draw(gameCanvas, x, y, 0, scale, scale)
end

function love.keypressed(key, scancode, isrepeat)
    local state = GameState.current()
    if state and state.keypressed then
        state:keypressed(key, scancode, isrepeat)
    end
end

function love.mousepressed(x, y, button, istouch, presses)
    local state = GameState.current()
    if state and state.mousepressed then
        state:mousepressed(x, y, button, istouch, presses)
    end
end

function love.mousereleased(x, y, button, istouch, presses)
    local state = GameState.current()
    if state and state.mousereleased then
        state:mousereleased(x, y, button, istouch, presses)
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
    local state = GameState.current()
    if state and state.mousemoved then
        state:mousemoved(x, y, dx, dy, istouch)
    end
end

return GameState