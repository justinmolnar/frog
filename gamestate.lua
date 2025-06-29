-- A more robust stack-based game state manager

local GameState = {}

-- The stack holds all our active states. The one on top is the active one.
local stack = {}

-- Gets the currently active state
function GameState.current()
    return stack[#stack]
end

-- Pushes a new state onto the stack, pausing the one below it.
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

-- Pops the current state off the stack, resuming the one below it.
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

-- Clears all states and switches to a new one (for Restart or starting a new game).
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

-- MODIFIED: This function is now smarter about drawing!
function love.draw()
    -- Find the first opaque state from the top of the stack
    local first_to_draw = #stack
    for i = #stack, 1, -1 do
        local state = stack[i]
        -- An overlay lets drawing continue to the state below it.
        -- An opaque state (is_overlay = false) stops the search.
        if not (state.is_overlay and state.is_overlay == true) then
            first_to_draw = i
            break
        end
    end

    -- Draw all states from the first opaque one to the top of the stack
    for i = first_to_draw, #stack do
        local state = stack[i]
        if state.draw then
            state:draw()
        end
    end
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