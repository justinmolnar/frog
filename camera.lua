-- Camera.lua

Camera = {}
Camera.__index = Camera

function Camera:new(mapWidth, mapHeight, C)
    local instance = setmetatable({}, Camera)

    instance.C = C
    instance.x = 0
    instance.y = 0
    
    instance.screenWidth = love.graphics.getWidth()
    instance.screenHeight = love.graphics.getHeight()
    
    instance.scale = C.CAMERA_SCALE
    instance.smoothX = C.CAMERA_SMOOTH_X
    instance.smoothUp = C.CAMERA_SMOOTH_UP
    instance.smoothDown = C.CAMERA_SMOOTH_DOWN
    
    instance.mapWidth = mapWidth
    instance.mapHeight = mapHeight

    return instance
end

function Camera:update(targetX, targetY, dt)
    -- Smoothly follow the target on the X axis
    self.x = self.x + (targetX - self.x) * self.smoothX * dt
    
    -- Smoothly follow the target on the Y axis, with different speeds for up/down
    local ySmooth = self.y > targetY and self.smoothUp or self.smoothDown
    self.y = self.y + (targetY - self.y) * ySmooth * dt

    -- Calculate the current "half-screen" size in world units, accounting for zoom
    local halfScreenWidth = self.screenWidth / (2 * self.scale)
    local halfScreenHeight = self.screenHeight / (2 * self.scale)

    -- Clamp camera position to map boundaries
    self.x = math.max(halfScreenWidth, math.min(self.mapWidth - halfScreenWidth, self.x))
    self.y = math.max(halfScreenHeight, math.min(self.mapHeight - halfScreenHeight, self.y))
end

function Camera:attach()
    love.graphics.push()
    -- Apply the zoom first
    love.graphics.scale(self.scale)
    -- Then translate the world so the camera's position is at the center of the screen
    love.graphics.translate(-self.x + self.screenWidth / (2 * self.scale), -self.y + self.screenHeight / (2 * self.scale))
end

function Camera:detach()
    love.graphics.pop()
end

function Camera:mouseToWorld(mx, my)
    -- This correctly reverses the transformations from attach()
    local worldX = (mx - self.screenWidth / 2) / self.scale + self.x
    local worldY = (my - self.screenHeight / 2) / self.scale + self.y
    return worldX, worldY
end
