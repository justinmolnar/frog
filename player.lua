-- Player.lua

Player = {}
Player.__index = Player

function Player:new(x, y, C, tileWidth, tileHeight)
    local instance = setmetatable({}, Player)

    instance.C = C
    instance.x = x
    instance.y = y
    -- Use tile size if provided, otherwise default to 16x16
    instance.w = tileWidth or 16
    instance.h = tileHeight or 16
    instance.x_velocity = 0
    instance.y_velocity = 0
    instance.state = "grounded" 
    instance.isCharging = false
    instance.charge = 0

    instance.tongue = {
        active = false,
        anchor = nil,
    }

    instance.canLatch = false
    instance.closestAnchor = nil
    
    instance.latchAngle = 0
    instance.latchDist = 0
    instance.aimAdjustment = 0
    instance.aimAxis = {x=0, y=0}
    
    instance.launchVector = nil

    -- NEW: Variables for latch coyote time
    instance.isAttemptingLatch = false
    instance.latchAttemptTimer = 0

    return instance
end

function Player:_handleCharging(dt)
    if self.isCharging then
        self.charge = math.min(self.charge + dt / self.C.MAX_CHARGE_TIME, 1)
    end
end

function Player:_applyPhysics(dt)
    if self.state ~= "grounded" then
        self.y_velocity = self.y_velocity + self.C.GRAVITY * dt
    else
        self.x_velocity = self.x_velocity * self.C.FRICTION
    end
end

function Player:_moveHorizontally(dt, platforms)
    self.x = self.x + self.x_velocity * dt
    for i, p in ipairs(platforms) do
        if self.x < p.x + p.w and self.x + self.w > p.x and
           self.y < p.y + p.h and self.y + self.h > p.y then
            if self.x_velocity > 0 then
                self.x = p.x - self.w
            elseif self.x_velocity < 0 then
                self.x = p.x + p.w
            end
            self.x_velocity = -self.x_velocity * self.C.BOUNCE_FACTOR
        end
    end
end

function Player:_moveVertically(dt, platforms)
    self.y = self.y + self.y_velocity * dt
    for i, p in ipairs(platforms) do
        if self.x < p.x + p.w and self.x + self.w > p.x and
           self.y < p.y + p.h and self.y + self.h > p.y then
            if self.y_velocity > 0 then
                self.y = p.y - self.h
                self.y_velocity = 0
            elseif self.y_velocity < 0 then
                self.y = p.y + p.h
                self.y_velocity = 0
            end
        end
    end
end

function Player:_senseGround(platforms)
    if self.state == "latched" or self.state == "reeling" then return end

    local groundSensor = {
        x = self.x + 2,
        y = self.y + self.h,
        w = self.w - 4,
        h = 2
    }
    
    local onGround = false
    for i, p in ipairs(platforms) do
        if groundSensor.x < p.x + p.w and groundSensor.x + groundSensor.w > p.x and
           groundSensor.y < p.y + p.h and groundSensor.y + groundSensor.h > p.y then
            onGround = true
            break
        end
    end

    if onGround then
        self.state = "grounded"
    else
        self.state = "airborne"
    end
end

function Player:update(dt, platforms, anchors, worldMouseX, worldMouseY)
    self:_handleCharging(dt)
    
    if self.state == "latched" then
        self:_handleLatched(dt, platforms)
    elseif self.state == "reeling" then
        self:_handleReeling(dt)
    else
        self:_applyPhysics(dt)
        self:_moveHorizontally(dt, platforms)
        self:_moveVertically(dt, platforms)
    end
    
    self:_senseGround(platforms)
    self:_checkForLatchableAnchors(anchors, worldMouseX, worldMouseY)

    -- NEW: Latch Coyote Time Logic
    if self.isAttemptingLatch then
        -- If we are holding the latch button, check if we entered latchable range.
        if self.canLatch then
            self:autoLatch()
            self.isAttemptingLatch = false -- Stop the attempt once successful.
        end

        -- Decrement the timer.
        self.latchAttemptTimer = self.latchAttemptTimer - dt
        if self.latchAttemptTimer <= 0 then
            self.isAttemptingLatch = false -- Stop the attempt if time runs out.
        end
    end
end

function Player:_checkForLatchableAnchors(anchors, worldMouseX, worldMouseY)
    self.canLatch = false
    self.closestAnchor = nil
    -- Start with an impossibly large distance
    local closestMouseDist = 9999

    local playerCenterX = self.x + self.w / 2
    local playerCenterY = self.y + self.h / 2

    for i, anchor in ipairs(anchors) do
        -- First, is the anchor even in range of the player?
        local playerToAnchorDist = math.sqrt((playerCenterX - anchor.x)^2 + (playerCenterY - anchor.y)^2)

        if playerToAnchorDist <= self.C.TONGUE_RANGE then
            -- If it is, is it the closest one to the mouse we've found so far?
            local mouseToAnchorDist = math.sqrt((worldMouseX - anchor.x)^2 + (worldMouseY - anchor.y)^2)
            if mouseToAnchorDist < closestMouseDist then
                self.canLatch = true
                self.closestAnchor = anchor
                closestMouseDist = mouseToAnchorDist
            end
        end
    end
end

function Player:autoLatch()
    if self.canLatch and self.state ~= "latched" and self.state ~= "reeling" then
        self.isCharging = false

        self.state = "latched"
        self.tongue.active = true
        self.tongue.anchor = self.closestAnchor

        local playerCenterX = self.x + self.w / 2
        local playerCenterY = self.y + self.h / 2
        local tongueVecX = playerCenterX - self.tongue.anchor.x
        local tongueVecY = playerCenterY - self.tongue.anchor.y
        
        self.latchAngle = math.atan2(tongueVecY, tongueVecX)
        self.latchDist = math.sqrt(tongueVecX^2 + tongueVecY^2)
        self.aimAdjustment = 0

        -- Calculate the perpendicular vector for aiming
        if self.latchDist > 0 then
            self.aimAxis.x = -tongueVecY / self.latchDist
            self.aimAxis.y = tongueVecX / self.latchDist
        end
    end
end

-- NEW: This function starts the coyote time window.
function Player:startLatchAttempt()
    -- Don't start a new attempt if already in a slingshot-related state.
    if self.state == "latched" or self.state == "reeling" then return end
    
    self.isAttemptingLatch = true
    self.latchAttemptTimer = self.C.LATCH_COYOTE_TIME
end

-- NEW: This function cancels the coyote time window.
function Player:cancelLatchAttempt()
    self.isAttemptingLatch = false
end

function Player:tongueShot(mouseX, mouseY, anchors)
    if self.state == "latched" then return end

    local playerCenterX = self.x + self.w / 2
    local playerCenterY = self.y + self.h / 2

    for i, anchor in ipairs(anchors) do
        local cursorToAnchorDist = math.sqrt((mouseX - anchor.x)^2 + (mouseY - anchor.y)^2)

        if cursorToAnchorDist < anchor.radius then
            local playerToAnchorDist = math.sqrt((playerCenterX - anchor.x)^2 + (playerCenterY - anchor.y)^2)

            if playerToAnchorDist <= self.C.TONGUE_RANGE then
                self.state = "latched"
                self.tongue.active = true
                self.tongue.anchor = anchor
                return
            end
        end
    end
end

function Player:releaseSlingshot()
    if self.state ~= "latched" then return end

    -- Calculate the final launch vector based on the player's pivoted position.
    local playerCenterX = self.x + self.w / 2
    local playerCenterY = self.y + self.h / 2
    local dx = self.tongue.anchor.x - playerCenterX
    local dy = self.tongue.anchor.y - playerCenterY
    local dist = math.sqrt(dx^2 + dy^2)

    if dist > 0 then
        -- Store the normalized launch vector for when we reach the anchor.
        self.launchVector = { x = dx / dist, y = dy / dist }
    else
        -- Fallback in case player is right on top of the anchor.
        self.launchVector = { x = 0, y = -1 }
    end
    
    -- Change state to "reeling" to begin the pull-in animation.
    self.state = "reeling"
    self.x_velocity = 0 -- Stop all current momentum.
    self.y_velocity = 0

    -- Ensure any jump charge is cancelled.
    self.isCharging = false
    self.charge = 0
end

function Player:_checkCollisionAt(x, y, platforms)
    local futureHitbox = {x = x, y = y, w = self.w, h = self.h}

    for i, p in ipairs(platforms) do
        if futureHitbox.x < p.x + p.w and futureHitbox.x + futureHitbox.w > p.x and
           futureHitbox.y < p.y + p.h and futureHitbox.y + futureHitbox.h > p.y then
            return true -- Collision detected
        end
    end
    return false -- No collision
end

function Player:adjustAim(dx, dy)
    if self.state ~= "latched" then return end

    -- Project the mouse movement vector (dx, dy) onto our perpendicular aimAxis.
    local movementAlongAxis = (dx * self.aimAxis.x) + (dy * self.aimAxis.y)

    local angleChange = math.rad(movementAlongAxis * self.C.SLINGSHOT_AIM_SENSITIVITY)
    self.aimAdjustment = self.aimAdjustment + angleChange

    -- Clamp the total adjustment
    local maxAngle = math.rad(self.C.SLINGSHOT_ADJUST_ANGLE)
    self.aimAdjustment = math.max(-maxAngle, math.min(maxAngle, self.aimAdjustment))
end

function Player:_handleLatched(dt, platforms)
    self.x_velocity = 0
    self.y_velocity = 0

    local finalAngle = self.latchAngle + self.aimAdjustment
    
    -- Calculate the potential new position for the player
    local nextX = self.tongue.anchor.x + math.cos(finalAngle) * self.latchDist - self.w / 2
    local nextY = self.tongue.anchor.y + math.sin(finalAngle) * self.latchDist - self.h / 2

    -- Check for a collision at the next position BEFORE moving.
    if not self:_checkCollisionAt(nextX, nextY, platforms) then
        -- If there's no collision, it's safe to move the player.
        self.x = nextX
        self.y = nextY
    end
end

function Player:_handleReeling(dt)
    if not self.tongue.anchor then
        -- Safety check: if we somehow lose the anchor, just become airborne.
        self.state = "airborne"
        return
    end

    local anchorX = self.tongue.anchor.x
    local anchorY = self.tongue.anchor.y
    local playerCenterX = self.x + self.w / 2
    local playerCenterY = self.y + self.h / 2
    
    local dx = anchorX - playerCenterX
    local dy = anchorY - playerCenterY
    local distToAnchor = math.sqrt(dx^2 + dy^2)
    
    local moveDist = self.C.REEL_IN_SPEED * dt
    
    -- Check if we are about to reach or pass the anchor in this frame.
    if distToAnchor <= moveDist or distToAnchor == 0 then
        -- We've arrived. Now, LAUNCH the player.
        
        -- 1. Snap player's final position precisely to the anchor.
        self.x = anchorX - self.w / 2
        self.y = anchorY - self.h / 2
        
        -- 2. Apply the pre-calculated launch velocity.
        self.x_velocity = self.launchVector.x * self.C.SLINGSHOT_POWER
        self.y_velocity = self.launchVector.y * self.C.SLINGSHOT_POWER
        
        -- 3. Change state to airborne and clean up.
        self.state = "airborne"
        self.tongue.active = false
        self.tongue.anchor = nil
        self.launchVector = nil
        
    else
        -- We are still reeling. Move the player along the straight line towards the anchor.
        local dirX = dx / distToAnchor
        local dirY = dy / distToAnchor
        
        self.x = self.x + dirX * moveDist
        self.y = self.y + dirY * moveDist
    end
end

function Player:reset(x, y)
    self.x = x
    self.y = y
    self.x_velocity = 0
    self.y_velocity = 0
    self.state = "airborne"
    self.isCharging = false
    self.charge = 0
end

function Player:startCharge()
    if self.state == "grounded" then
        self.isCharging = true
        self.charge = 0
    end
end

function Player:releaseCharge(mouseX, mouseY)
    if not self.isCharging or self.state ~= "grounded" then 
        self.isCharging = false
        return 
    end

    local playerCenterX = self.x + self.w / 2
    local playerCenterY = self.y + self.h / 2

    local dx = mouseX - playerCenterX
    local dy = mouseY - playerCenterY
    if dy > -10 then dy = -10 end

    local angle = math.atan2(dy, dx)
    local launch_force = self.C.MAX_JUMP_POWER * self.charge

    self.x_velocity = math.cos(angle) * launch_force
    self.y_velocity = math.sin(angle) * launch_force

    self.state = "airborne"
    self.isCharging = false
    self.charge = 0
end

function Player:draw()
    if self.canLatch and self.state ~= "latched" then
        love.graphics.setColor(1, 1, 0) -- Yellow "ready" indicator
    else
        love.graphics.setColor(1, 0.3, 0.3) -- Default red
    end
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)

    if self.tongue.active then
        local playerCenterX = self.x + self.w / 2
        local playerCenterY = self.y + self.h / 2
        local anchor = self.tongue.anchor
        love.graphics.setColor(1, 0.5, 0.8) -- Pinkish
        love.graphics.setLineWidth(3)
        love.graphics.line(playerCenterX, playerCenterY, anchor.x, anchor.y)
        love.graphics.setLineWidth(1)
    end
    
    if self.state == "grounded" or self.state == "airborne" then
        local playerCenterX = self.x + self.w / 2
        local playerCenterY = self.y + self.h / 2
        love.graphics.setColor(1, 0.5, 0.8, 0.2)
        love.graphics.circle("fill", playerCenterX, playerCenterY, self.C.TONGUE_RANGE)
    end

    if self.canLatch and self.closestAnchor then
        love.graphics.setColor(1, 1, 0, 0.5) -- Semi-transparent yellow highlight
        love.graphics.circle("fill", self.closestAnchor.x, self.closestAnchor.y, self.closestAnchor.radius + 5)
    end

    if self.state == "grounded" then
        local screenMouseX, screenMouseY = love.mouse.getPosition()
        local worldMouseX, worldMouseY = camera:mouseToWorld(screenMouseX, screenMouseY)
        local playerCenterX = self.x + self.w / 2
        local playerCenterY = self.y + self.h / 2
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.line(playerCenterX, playerCenterY, worldMouseX, worldMouseY)
        if self.isCharging then
            local barWidth = 40
            local barHeight = 8
            local barX = self.x + self.w / 2 - barWidth / 2
            local barY = self.y - 20
            love.graphics.setColor(0, 0, 0, 0.8)
            love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
            love.graphics.setColor(1, 1, 0)
            love.graphics.rectangle("fill", barX, barY, barWidth * self.charge, barHeight)
        end
    end
end