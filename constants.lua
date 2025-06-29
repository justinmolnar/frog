-- constants.lua
-- A central file for all game settings and "magic numbers" for easy tuning.

return {
    -- Player Physics
    GRAVITY = 2500,
    FRICTION = 0.7,
    BOUNCE_FACTOR = 0.5,

    -- Player Abilities
    MAX_JUMP_POWER = 700,
    MAX_CHARGE_TIME = 0.7,
    SLINGSHOT_POWER = 450,
    TONGUE_RANGE = 75,  -- Reduced for smaller tiles (was 250)
    SLINGSHOT_ADJUST_ANGLE = 10,
    SLINGSHOT_AIM_SENSITIVITY = .25,
    REEL_IN_SPEED = 900,
    LATCH_COYOTE_TIME = 0.5, -- How long (in seconds) the game remembers your latch attempt.


    -- Camera Settings
    CAMERA_SMOOTH_UP = 3,
    CAMERA_SMOOTH_DOWN = 0.8,
    CAMERA_SMOOTH_X = 5,
    CAMERA_SCALE = 3,  -- Zoom in for 16x16 tiles (was 0.75)

    -- World Settings  
    TILE_WIDTH = 16,   -- Updated to match your map
    TILE_HEIGHT = 16,  -- Updated to match your map

    GAME_SPEED_MULTIPLIER = 0.7,
}