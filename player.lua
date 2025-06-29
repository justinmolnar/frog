-- Player.lua

Player = {}
Player.__index = Player

function Player:new(x, y, C, tileWidth, tileHeight)
    local instance = setmetatable({}, Player)

    instance.C = C
    instance.x = x
    instance.y = y
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

    instance.isAttemptingLatch = false
    instance.latchAttemptTimer = 0

    -- NEW: Checkpoint properties
    instance.maxCheckpoints = 3
    instance.checkpointsAvailable = 3
    instance.checkpoint = nil -- Will store {x, y}

    return instance
end

-- NEW: Function to place a checkpoint
function Player:placeCheckpoint()
    -- Can only place if on the ground and has checkpoints available
    if self.state == "grounded" and self.checkpointsAvailable > 0 then
        self.checkpoint = {x = self.x, y = self.y}
        self.checkpointsAvailable = self.checkpointsAvailable - 1
        return true -- success
    end
    return false -- failure
end

-- NEW: Function to return to the last checkpoint
function Player:returnToCheckpoint()
    if self.checkpoint then
        self.x = self.checkpoint.x
        self.y = self.checkpoint.y
        -- Reset velocities to prevent falling through the floor or keeping momentum
        self.x_velocity = 0
        self.y_velocity = 0
        self.state = "airborne" -- Set to airborne to re-evaluate ground state next frame
        return true -- success
    end
    return false -- failure
end

function Player:_handleCharging(dt)
    if self.isCharging then
        self.charge = math.min(self.charge + dt / self.C.MAX_CHARGE_TIME, 1)
    end
end

function Player:_applyPhysics(dt)
    if self.state ~= "grounded" and not DEBUG_FLY_MODE then
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

    if self.isAttemptingLatch then
        if self.canLatch then
            self:autoLatch()
            self.isAttemptingLatch = false
        end

        self.latchAttemptTimer = self.latchAttemptTimer - dt
        if self.latchAttemptTimer <= 0 then
            self.isAttemptingLatch = false
        end
    end
end

function Player:fly(dt)
    self.x_velocity = 0
    self.y_velocity = 0

    if love.keyboard.isDown("w") then
        self.y = self.y - self.C.DEBUG_FLY_SPEED * dt
    end
    if love.keyboard.isDown("s") then
        self.y = self.y + self.C.DEBUG_FLY_SPEED * dt
    end
    if love.keyboard.isDown("a") then
        self.x = self.x - self.C.DEBUG_FLY_SPEED * dt
    end
    if love.keyboard.isDown("d") then
        self.x = self.x + self.C.DEBUG_FLY_SPEED * dt
    end
end

function Player:_checkForLatchableAnchors(anchors, worldMouseX, worldMouseY)
    self.canLatch = false
    self.closestAnchor = nil
    local closestMouseDist = 9999

    local playerCenterX = self.x + self.w / 2
    local playerCenterY = self.y + self.h / 2

    for i, anchor in ipairs(anchors) do
        local playerToAnchorDist = math.sqrt((playerCenterX - anchor.x)^2 + (playerCenterY - anchor.y)^2)

        if playerToAnchorDist <= self.C.TONGUE_RANGE then
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

        if self.latchDist > 0 then
            self.aimAxis.x = -tongueVecY / self.latchDist
            self.aimAxis.y = tongueVecX / self.latchDist
        end
    end
end

function Player:startLatchAttempt()
    if self.state == "latched" or self.state == "reeling" then return end

    self.isAttemptingLatch = true
    self.latchAttemptTimer = self.C.LATCH_COYOTE_TIME
end

function Player:cancelLatchAttempt()
    self.isAttemptingLatch = false
end

function Player:releaseSlingshot()
    if self.state ~= "latched" then return end

    local playerCenterX = self.x + self.w / 2
    local playerCenterY = self.y + self.h / 2
    local dx = self.tongue.anchor.x - playerCenterX
    local dy = self.tongue.anchor.y - playerCenterY
    local dist = math.sqrt(dx^2 + dy^2)

    if dist > 0 then
        self.launchVector = { x = dx / dist, y = dy / dist }
    else
        self.launchVector = { x = 0, y = -1 }
    end

    self.state = "reeling"
    self.x_velocity = 0
    self.y_velocity = 0

    self.isCharging = false
    self.charge = 0
end

function Player:_checkCollisionAt(x, y, platforms)
    local futureHitbox = {x = x, y = y, w = self.w, h = self.h}

    for i, p in ipairs(platforms) do
        if futureHitbox.x < p.x + p.w and futureHitbox.x + futureHitbox.w > p.x and
           futureHitbox.y < p.y + p.h and futureHitbox.y + futureHitbox.h > p.y then
            return true
        end
    end
    return false
end

function Player:adjustAim(dx, dy)
    if self.state ~= "latched" then return end

    local movementAlongAxis = (dx * self.aimAxis.x) + (dy * self.aimAxis.y)
    local angleChange = math.rad(movementAlongAxis * self.C.SLINGSHOT_AIM_SENSITIVITY)
    self.aimAdjustment = self.aimAdjustment + angleChange

    local maxAngle = math.rad(self.C.SLINGSHOT_ADJUST_ANGLE)
    self.aimAdjustment = math.max(-maxAngle, math.min(maxAngle, self.aimAdjustment))
end

function Player:_handleLatched(dt, platforms)
    self.x_velocity = 0
    self.y_velocity = 0

    local finalAngle = self.latchAngle + self.aimAdjustment

    local nextX = self.tongue.anchor.x + math.cos(finalAngle) * self.latchDist - self.w / 2
    local nextY = self.tongue.anchor.y + math.sin(finalAngle) * self.latchDist - self.h / 2

    if not self:_checkCollisionAt(nextX, nextY, platforms) then
        self.x = nextX
        self.y = nextY
    end
end

function Player:_handleReeling(dt)
    if not self.tongue.anchor then
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

    if distToAnchor <= moveDist or distToAnchor == 0 then
        self.x = anchorX - self.w / 2
        self.y = anchorY - self.h / 2

        self.x_velocity = self.launchVector.x * self.C.SLINGSHOT_POWER
        self.y_velocity = self.launchVector.y * self.C.SLINGSHOT_POWER

        self.state = "airborne"
        self.tongue.active = false
        self.tongue.anchor = nil
        self.launchVector = nil
    else
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
    self.checkpointsAvailable = self.maxCheckpoints
    self.checkpoint = nil
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

function Player:draw(camera, tileWidth, tileHeight)
    if self.canLatch and self.state ~= "latched" then
        love.graphics.setColor(1, 1, 0)
    else
        love.graphics.setColor(1, 0.3, 0.3)
    end
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)

    if self.tongue.active then
        local playerCenterX = self.x + self.w / 2
        local playerCenterY = self.y + self.h / 2
        local anchor = self.tongue.anchor
        love.graphics.setColor(1, 0.5, 0.8)
        love.graphics.setLineWidth(3)
        love.graphics.line(playerCenterX, playerCenterY, anchor.x, anchor.y)
        love.graphics.setLineWidth(1)
    end

    if Settings.showTongueRange and (self.state == "grounded" or self.state == "airborne") then
        local playerCenterX = self.x + self.w / 2
        local playerCenterY = self.y + self.h / 2
        love.graphics.setColor(1, 0.5, 0.8, 0.2)
        love.graphics.circle("fill", playerCenterX, playerCenterY, self.C.TONGUE_RANGE)
    end

    if self.canLatch and self.closestAnchor then
        local anchor = self.closestAnchor
        local r,g,b,a = love.graphics.getColor()
        local original_blend_mode = love.graphics.getBlendMode()

        love.graphics.setBlendMode("add")
        local glow_center_x = anchor.draw_x + tileWidth / 2
        local glow_center_y = anchor.draw_y + tileHeight / 2
        local max_glow_radius = tileWidth * 0.9
        local num_layers = 6
        local layer_alpha = 0.08

        for i = num_layers, 1, -1 do
            local radius = max_glow_radius * (i / num_layers)
            love.graphics.setColor(1, 1, 0, layer_alpha)
            love.graphics.circle("fill", glow_center_x, glow_center_y, radius)
        end

        love.graphics.setBlendMode(original_blend_mode)
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.draw(anchor.image, anchor.quad, anchor.draw_x, anchor.draw_y)
        love.graphics.setColor(r,g,b,a)
    end

    if self.state == "grounded" then
        local screenMouseX, screenMouseY = love.mouse.getPosition()
        local worldMouseX, worldMouseY = camera:mouseToWorld(screenMouseX, screenMouseY)
        local playerCenterX = self.x + self.w / 2
        local playerCenterY = self.y + self.h / 2

        if Settings.showJumpPower and self.isCharging then
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

return Player