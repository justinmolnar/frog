-- Global requires
require 'player'
require 'camera'
sti = require "sti"
CONSTANTS = require 'constants'
GameState = require 'gamestate'
Settings = require 'settings' 

-- Make state modules global
MainMenu = require 'mainmenu'
Game = require 'game'
Options = require 'options' 

-- NEW: Define our game's native resolution and main canvas
VIRTUAL_WIDTH = 800
VIRTUAL_HEIGHT = 600
gameCanvas = nil

-- NEW: Global function to convert real mouse coords to virtual canvas coords
function getVirtualMousePosition()
    local mx, my = love.mouse.getPosition()
    local winWidth, winHeight = love.graphics.getDimensions()
    
    -- calculate the scale and offsets used to draw the canvas
    local scale = math.min(winWidth / VIRTUAL_WIDTH, winHeight / VIRTUAL_HEIGHT)
    local x_offset = (winWidth - (VIRTUAL_WIDTH * scale)) / 2
    local y_offset = (winHeight - (VIRTUAL_HEIGHT * scale)) / 2

    -- reverse the transformation
    local virtualX = (mx - x_offset) / scale
    local virtualY = (my - y_offset) / scale
    
    return virtualX, virtualY
end


function toggleFullscreen()
    if Settings.fullscreen then
        local dw, dh = love.window.getDesktopDimensions(1)
        love.window.setMode(dw, dh, {fullscreen = true, vsync = true, resizable = false})
    else
        love.window.setMode(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, {fullscreen = false, vsync = true, resizable = true})
    end
end

function love.load()
    -- Create the main canvas that we will render the game to
    gameCanvas = love.graphics.newCanvas(VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    gameCanvas:setFilter('nearest', 'nearest') -- Use nearest-neighbor scaling for crisp pixels

    toggleFullscreen()
    
    GameState.switch(MainMenu:new())
end