-- Camera.lua

Camera = {}
Camera.__index = Camera

function Camera:new(mapWidth, mapHeight, C)
    local instance = setmetatable({}, Camera)

    instance.C = C
    instance.x = 0
    instance.y = 0
    
    -- MODIFIED: Use the virtual resolution for all calculations
    instance.screenWidth = VIRTUAL_WIDTH
    instance.screenHeight = VIRTUAL_HEIGHT
    
    instance.scale = C.CAMERA_SCALE
    instance.smoothX = C.CAMERA_SMOOTH_X
    instance.smoothUp = C.CAMERA_SMOOTH_UP
    instance.smoothDown = C.CAMERA_SMOOTH_DOWN
    
    instance.mapWidth = mapWidth
    instance.mapHeight = mapHeight

    return instance
end

function Camera:update(targetX, targetY, dt)
    -- This function remains the same
    self.x = self.x + (targetX - self.x) * self.smoothX * dt
    local ySmooth = self.y > targetY and self.smoothUp or self.smoothDown
    self.y = self.y + (targetY - self.y) * ySmooth * dt
    local halfScreenWidth = self.screenWidth / (2 * self.scale)
    local halfScreenHeight = self.screenHeight / (2 * self.scale)
    self.x = math.max(halfScreenWidth, math.min(self.mapWidth - halfScreenWidth, self.x))
    self.y = math.max(halfScreenHeight, math.min(self.mapHeight - halfScreenHeight, self.y))
end

function Camera:attach()
    -- This function remains the same
    love.graphics.push()
    love.graphics.scale(self.scale)
    love.graphics.translate(-self.x + self.screenWidth / (2 * self.scale), -self.y + self.screenHeight / (2 * self.scale))
end

function Camera:detach()
    -- This function remains the same
    love.graphics.pop()
end

function Camera:mouseToWorld(mx, my)
    -- MODIFIED: This function now expects virtual mouse coordinates
    local worldX = (mx - self.screenWidth / 2) / self.scale + self.x
    local worldY = (my - self.screenHeight / 2) / self.scale + self.y
    return worldX, worldY
end