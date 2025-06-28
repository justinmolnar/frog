-- constants.lua
-- A central file for all game settings and "magic numbers" for easy tuning.

return {
    -- Player Physics
    GRAVITY = 2500,
    FRICTION = 0.7,
    BOUNCE_FACTOR = 0.5,

    -- Player Abilities
    MAX_JUMP_POWER = 1000,
    MAX_CHARGE_TIME = 0.8,
    SLINGSHOT_POWER = 900,
    TONGUE_RANGE = 250,
    SLINGSHOT_ADJUST_ANGLE = 15,
    SLINGSHOT_AIM_SENSITIVITY = .25,


    -- Camera Settings
    CAMERA_SMOOTH_UP = 3,
    CAMERA_SMOOTH_DOWN = 0.8,
    -- THE CHANGE: New settings for X-axis smoothing and zoom level.
    CAMERA_SMOOTH_X = 5,
    CAMERA_SCALE = 0.75, -- Zoom out. 1 is default, < 1 is zoomed out.

    -- World Settings
    TILE_WIDTH = 32,
    TILE_HEIGHT = 32,
}
