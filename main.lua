-- Global requires
require 'player'
require 'camera'
sti = require "sti"
CONSTANTS = require 'constants'
GameState = require 'gamestate'
Settings = require 'settings' 

-- MODIFIED: Make state modules global by removing 'local'
-- This allows them to be accessed from other files like mainmenu.lua
MainMenu = require 'mainmenu'
Game = require 'game'
Options = require 'options' 

function love.load()
    -- Start the game by creating and switching to a new instance of the MainMenu state.
    GameState.switch(MainMenu:new())
end

-- All other love callbacks (update, draw, keypressed, etc.) are now handled by gamestate.lua