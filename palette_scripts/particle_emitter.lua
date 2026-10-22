local GAME_FRAMES_PER_SECOND = 30

local PaletteUtils = include("palette_scripts.palette_utils")
local PaletteGradient = include("palette_scripts.palette_gradient")
local PaletteShape = include("palette_scripts.palette_shape")

---@class ParticleEmitter This class defines a `ParticleEmitter`, which is responsible for creating particles and managing them.
---@field IsWorldSpace boolean Whether the emitted particles are rendered on the world space or directly onto your screen. Default: True
---@field Position Vector The position of the emitter. This is where all spawned particles originate from. Default: (0, 0)
---@field MaxParticles integer The maximum amount of particles that can be active at a given time. Default: 100
---@field Lifetime PaletteMinMaxInteger | number How many frames a particle exists until it's destroyed. Default: 60
---@field ParticleRate number How many particles are emitted over the course of one second. Default: 5
---@field ColorOverLifetime PaletteColorOverLifetime Attributes relating to how the particles change color over its lifespan.
---@field StartColor PaletteMinMaxKColor | KColor The initial color for spawned particles. If `ColorOverLifetime.Enabled` is set to `true`, the gradient is multiplied by this.
---@field VelocityOverLifetime PaletteVelocityOverLifetime Dictates how particles move over its lifespan.
---@field StartSpeed PaletteMinMaxFloat | number The initial speed of the particle when spawned. Default: 2
---@field StartDirection Vector The default direction of the particle. Default: (0, -1)
---@field StartRotation number | PaletteMinMaxFloat The initial rotation for each particle. Default: 0
---@field Orientation number The emitter's rotation, in degrees. This is solely used to handle how particles move out from the emitter as opposed to changing the rotation of the particle's sprite. To change the sprite's actual rotation, use `StartRotation`. Default: 0
---@field StartScale Vector | PaletteMinMaxVector The initial scale of spawned particles. Default: (1, 1)
---@field PersistAcrossRooms boolean Whether the particle emitter is destroyed when leaving the current room or exiting the game. Default: false
---@field DirectionSpread number How spread out the spawned particles are relative to `StartDirection`. Default: 0
---@field SizeOverLifetime PaletteOverLifetime Attributes relating to how particles change size over their lifespan.
---@field RotationOverLifetime PaletteOverLifetime Attributes relating to how particles change rotation over their lifespan.
---@field Shape PaletteShapeConfig A module that configures its own shape, affecting the particle's spawn positions and velocity.
---@field RenderMode PaletteRenderMode  Determines how particles are rendered onto the screen. Default: "AboveEntities"
---@field Shader Shader?
---@field ShaderParams table<string, number|number[]>
---@field GravityModifier number | PaletteMinMaxFloat Default: 0
---@field ForceOverLifetime ForceOverLifetime
---@field LimitVelocityOverLifetime LimitVelocityOverLifetime
---@field Duration number Default: true
---@field Looping boolean Default: true
---@field Bursts PaletteBurst[] Default: {}
---@field StartDelay integer Default: 0
---@field DestroyOnFinish boolean If true, the Particle Emitter is destroyed once it reached the end of its duration and all particles has despawned. Default: false
---@field _PendingDestroy boolean
---@field private _IsEmitting boolean Determines whether particles are being continuously emitted. Note that `ParticleEmitter:Emit` will still work even with this set to false.
---@field private _RenderImage Image
---@field private _UpdateAccumilator number Because some render callbacks might need to handle particle logic, we use this to stay at a consistent 30 updates per second.
---@field private _Particles Particle[]
---@field private _ParticlePool Particle[]
---@field private _EmitterSourceQuad SourceQuad
---@field private _EmissionAccumulator number
---@field private _IsDestroyed boolean
---@field private _DestroyFun fun(self: ParticleEmitter)
---@field private _FollowingEntity Entity?
---@field private _EntityFollowOffset Vector
---@field private _IsPaused boolean
---@field private _EmitterTime integer
---@field private _IsFinished boolean
---@field private _DelayElapsed integer
---@field private _BurstCycles integer[]
local ParticleEmitter = {}
ParticleEmitter.__index = ParticleEmitter

function ParticleEmitter:Resume()
    self._IsPaused = false
end

function ParticleEmitter:Pause()
    self._IsPaused = true
end

--- Causes the particle emitter to follow an entity while it's alive. Pass `nil` to have the
--- Particle Emitter stop following it.
--- @param entity Entity?
--- @param followOffset Vector? Optional. Default: (0, 0)
function ParticleEmitter:FollowEntity(entity, followOffset)
    self._FollowingEntity = entity
    self._EntityFollowOffset = followOffset or Vector.Zero
end

--- Returns whether the particle emitter is following an entity.
function ParticleEmitter:IsFollowingEntity()
    return self._FollowingEntity ~= nil and self._FollowingEntity:Exists()
end

--- Returns the entity the particle emitter is following. Returns nil if it's following no entity.
function ParticleEmitter:GetFollowingEntity()
    return self._FollowingEntity
end

function ParticleEmitter:IsPaused()
    return self._IsPaused
end

--- Updates the ParticleEmitter's logic including its current particles. By default, this is called
--- every frame using `MC_POST_UPDATE`. While there's typically no need to call this method as
--- it's done automatically, it may be useful for forcing updates.
function ParticleEmitter:Update()
    if self:IsDestroyed() or self:IsPaused() then
        return
    end

    self:_UpdateFollowPosition()
    self:_Tick()
end

function ParticleEmitter:GetParticleCount()
    return #self._Particles
end

-- Restarts particle emission from the very beginning, clearing every particle.
function ParticleEmitter:Restart()
    if self:IsDestroyed() then
        return
    end

    self:Clear()
    self._IsFinished = false
    self._PendingDestroy = false
    self._EmitterTime = 0
    self._DelayElapsed = 0
    self._BurstCycles = {}
    self._EmissionAccumulator = 0
    self._IsEmitting = true
end

--- Spawns multiple particles in a single batches. If the number of particles exceeds or is equal to
--- `ParticlEmitter.MaxParticles`, extraneous particles are not spawned.
---@param count integer
---@param positionOffset Vector? Optional. Default: (0, 0)
function ParticleEmitter:Emit(count, positionOffset)
    assert(not self:IsDestroyed(), "Attempted to Emit particles on a destroyed ParticleEmitter")

    positionOffset = positionOffset or Vector.Zero

    for i = 1, count do
        if #self._Particles >= self.MaxParticles then
            break
        end

        -- Our Object Pool logic here will reduce the amount of times we need to allocate an entire
        -- table to save performance.
        local newParticle

        if #self._ParticlePool > 0 then
            newParticle = table.remove(self._ParticlePool)
        else
            newParticle = {}
        end

        self:_InitializeParticle(newParticle, positionOffset)

        ---@cast newParticle Particle
        table.insert(self._Particles, newParticle)
    end
end

--- Returns whether continuous particle emission is enabled.
function ParticleEmitter:IsEmitting()
    return self._IsEmitting
end

--- Returns whether at least one particle from the emitter is active or the emitter is continuously
--- emitting particles.
function ParticleEmitter:IsPlaying()
    return self._IsEmitting or #self._Particles > 0
end

--- Resumes. continuous particle emission.
function ParticleEmitter:Play()
    if self:IsDestroyed() then
        return
    end

    if self._IsFinished then
        self:Restart()
    else
        self._IsEmitting = true
    end
end

--- Disables continuous particle emission. This does not clear particles that have already spawned.
--- If you wish to destroy already spawned particles, use `ParticleEmitter:Clear()`.
function ParticleEmitter:Stop()
    if self:IsDestroyed() then
        return
    end

    self._IsEmitting = false
end

--- Returns whether the ParticleEmitter was destroyed.
function ParticleEmitter:IsDestroyed()
    return self._IsDestroyed
end

--- Destroys all particles spawned by the emitter.
function ParticleEmitter:Clear()
    if self:IsDestroyed() then
        return
    end

    for _, particle in pairs(self._Particles) do
        table.insert(self._ParticlePool, particle)
    end

    self._Particles = {}
end

--- Destroys the ParticleEmitter and all of the particles it has spawned. When destroyed, it can no
--- longer be used.
function ParticleEmitter:Destroy()
    if self:IsDestroyed() then
        return
    end

    self:Clear()
    self:_DestroyFun()

    self._FollowingEntity = nil
    self._ParticlePool = {}
    self._Particles = {}
    self._IsEmitting = false
    self._IsDestroyed = true
    self._RenderImage = nil
    self._EmitterSourceQuad = nil
    self._DestroyFun = nil
end

function ParticleEmitter:_OnPostPauseScreenRender()
    if self.RenderMode ~= "AbovePause" then
        return
    end

    if self._UpdateAccumilator == 0 then
        self._UpdateAccumilator = 1
        self:Update()
    else
        self._UpdateAccumilator = self._UpdateAccumilator - 1
    end

    self:_Render()
end

function ParticleEmitter:_OnPostRender()
    if self.RenderMode ~= "AboveHUD" then
        return
    end

    if self._UpdateAccumilator == 0 then
        self._UpdateAccumilator = 1
        self:Update()
    else
        self._UpdateAccumilator = self._UpdateAccumilator - 1
    end

    self:_Render()
end

function ParticleEmitter:_OnMainMenuRender()
    if self.RenderMode ~= "MainMenu" then
        return
    end

    if self._UpdateAccumilator == 0 then
        self._UpdateAccumilator = 1
        self:Update()
    else
        self._UpdateAccumilator = self._UpdateAccumilator - 1
    end

    self:_Render()
end

function ParticleEmitter:_OnPostRoomEntitiesRender()
    if self:IsDestroyed() or self.RenderMode ~= "AboveEntities" then
        return
    end

    self:_Render()
end

function ParticleEmitter:_OnPreBackdropRenderWalls()
    if self:IsDestroyed() or self.RenderMode ~= "Floor" then
        return
    end

    self:_Render()
end

function ParticleEmitter:_Render()
    local imageWidth, imageHeight = self._RenderImage:GetWidth(), self._RenderImage:GetHeight()

    for _, particle in ipairs(self._Particles) do
        ---@type Vector
        local renderPos
        if self.IsWorldSpace then
            renderPos = Isaac.WorldToScreen(particle.Position)
        else
            renderPos = particle.Position
        end

        local scaledWidth, scaledHeight =
            imageWidth * particle.Scale.X, imageHeight * particle.Scale.Y

        local destinationQuad = DestinationQuad.NewFromRectangle(
            renderPos - Vector(scaledWidth / 2, scaledHeight / 2),
            scaledWidth,
            scaledHeight
        )
        destinationQuad:Rotate(particle.Rotation, renderPos)

        if self.Shader then
            self._RenderImage:RenderWithShader(
                self._EmitterSourceQuad,
                destinationQuad,
                particle.Color,
                self.Shader,
                self.ShaderParams
            )
        else
            self._RenderImage:Render(self._EmitterSourceQuad, destinationQuad, particle.Color)
        end
    end
end

function ParticleEmitter:_UpdateContinuousEmission()
    self._EmissionAccumulator = self._EmissionAccumulator + self.ParticleRate / GAME_FRAMES_PER_SECOND

    local particlesToEmit = math.floor(self._EmissionAccumulator)

    if particlesToEmit > 0 then
        self:Emit(particlesToEmit)
    end

    self._EmissionAccumulator = self._EmissionAccumulator - particlesToEmit
end

function ParticleEmitter:_UpdateParticles()
    if self:IsDestroyed() then
        return
    end

    for i = #self._Particles, 1, -1 do
        local particle = self._Particles[i]

        particle.FrameCount = particle.FrameCount + 1

        if particle.FrameCount >= particle.Lifetime then
            local removedParticle = table.remove(self._Particles, i)
            table.insert(self._ParticlePool, removedParticle)
        else
            self:_ApplyParticleForce(particle)
            local velocity = self:_GetParticleVelocity(particle)
            particle.Position = particle.Position + velocity

            particle.Scale = self:_GetParticleScale(particle)
            particle.Rotation = self:_GetParticleRotation(particle)

            self:_UpdateParticleColor(particle)
        end
    end
end

---@param particle Particle
function ParticleEmitter:_UpdateParticleColor(particle)
    if not self.ColorOverLifetime.Enabled or particle.Lifetime <= 0 then
        particle.Color = particle.StartColor
        return
    end

    local t = particle.FrameCount / particle.Lifetime

    if self.ColorOverLifetime.CurveMode == "Single" then
        local gradientColor = PaletteGradient:Evaluate(self.ColorOverLifetime.Gradient, t, self.ColorOverLifetime.Mode)
        particle.Color = PaletteUtils.MultiplyKColor(particle.StartColor, gradientColor)
    elseif self.ColorOverLifetime.CurveMode == "TwoCurves" then
        local gradientColorMin = PaletteGradient:Evaluate(self.ColorOverLifetime.GradientMin, t,
            self.ColorOverLifetime.Mode)
        local gradientColorMax = PaletteGradient:Evaluate(self.ColorOverLifetime.GradientMax, t,
            self.ColorOverLifetime.Mode)
        local gradientColor = PaletteUtils.LerpKColor(gradientColorMin, gradientColorMax, particle.LerpFactor)
        particle.Color = PaletteUtils.MultiplyKColor(particle.StartColor, gradientColor)
    end
end

---@param particle Particle
function ParticleEmitter:_ApplyParticleForce(particle)
    local forceOverLifetime = self.ForceOverLifetime
    local limitVelocityOverLifetime = self.LimitVelocityOverLifetime
    local t = particle.FrameCount / particle.Lifetime
    local gravityModifier = particle.Gravity
    particle.Velocity = particle.Velocity + Vector(0, gravityModifier)

    if forceOverLifetime.Enabled then
        ---@type Vector
        local force = self.ForceOverLifetime:Evaluate(t, particle.LerpFactor)

        if forceOverLifetime.Space == "Local" then
            force = force:Rotated(self.Orientation)
        end

        particle.Velocity = particle.Velocity + force
    end

    if limitVelocityOverLifetime.Enabled then
        local speed = particle.Velocity:Length()
        local speedLimit = math.max(0, limitVelocityOverLifetime.MaxSpeed)

        if speed > speedLimit then
            local newSpeed = PaletteUtils.Lerp(speed, speedLimit, limitVelocityOverLifetime.Dampen)
            particle.Velocity = particle.Velocity * (newSpeed / speed)
        end

        particle.Velocity = particle.Velocity * (1 - limitVelocityOverLifetime.Drag)
    end
end

---@param particle Particle
---@param positionOffset Vector
function ParticleEmitter:_InitializeParticle(particle, positionOffset)
    local startSize = PaletteUtils.SampleVector(self.StartScale)
    local emitterPosition = Vector(self.Position.X, self.Position.Y) + positionOffset
    local spawnPosition = PaletteShape.GetSpawnPosition(
        self.Shape,
        emitterPosition,
        self.Orientation
    )

    local defaultDirection = self.StartDirection:Normalized():Rotated(self.Orientation)

    local finalDirection = PaletteShape.GetDirection(
        self.Shape,
        emitterPosition,
        spawnPosition,
        defaultDirection
    )
    local spreadAngle = PaletteUtils.GetRandomFloat(
        -self.DirectionSpread,
        self.DirectionSpread
    )

    finalDirection = finalDirection:Rotated(spreadAngle)

    particle.SpawnPosition = spawnPosition
    particle.Position = Vector(spawnPosition.X, spawnPosition.Y)
    particle.Velocity = finalDirection * PaletteUtils.SampleFloat(self.StartSpeed)
    particle.FrameCount = 0
    particle.Scale = startSize
    particle.StartColor = PaletteUtils.SampleKColor(self.StartColor)
    particle.Color = particle.StartColor
    particle.StartScale = startSize
    particle.Lifetime = PaletteUtils.SampleInteger(self.Lifetime)
    particle.Gravity = PaletteUtils.SampleFloat(self.GravityModifier)
    particle.Rotation = PaletteUtils.SampleFloat(self.StartRotation)
    particle.LerpFactor = PaletteUtils.GetRandom()

    -- To prevent brief visual artifacts like new particles flickering.
    self:_UpdateParticleColor(particle)
    particle.Scale = self:_GetParticleScale(particle)
end

---@param particle Particle
function ParticleEmitter:_GetParticleVelocity(particle)
    local velocityOverLifetime = self.VelocityOverLifetime

    if not velocityOverLifetime.Enabled then
        return particle.Velocity
    end

    -- Linear Velocity Logic

    local linearVelocity = velocityOverLifetime.LinearVelocity

    if velocityOverLifetime.Space == "Local" then
        linearVelocity = linearVelocity:Rotated(self.Orientation)
    end

    local newVelocity = (particle.Velocity + linearVelocity) * velocityOverLifetime.SpeedModifier

    -- Orbital Velocity Logic

    local orbitalOffset = velocityOverLifetime.OrbitalOffset

    if velocityOverLifetime.Space == "Local" then
        orbitalOffset = orbitalOffset:Rotated(self.Orientation)
    end

    local center = particle.SpawnPosition + orbitalOffset
    local relativePos = particle.Position - center

    local orbitalRotation = velocityOverLifetime.OrbitalVelocity * velocityOverLifetime.SpeedModifier

    if orbitalRotation ~= 0 then
        relativePos = relativePos:Rotated(orbitalRotation)
    end

    local orbitalVelocity = center + relativePos - particle.Position

    newVelocity = newVelocity + orbitalVelocity

    -- Radial Velocity Logic
    local radialDirection = particle.Position - center
    local length = radialDirection:Length()

    if length > 0 then
        local radialVelocity = radialDirection *
            (velocityOverLifetime.Radial * velocityOverLifetime.SpeedModifier / length)
        newVelocity = newVelocity + radialVelocity
    end

    return newVelocity
end

---@param particle Particle
function ParticleEmitter:_GetParticleScale(particle)
    local scale = particle.StartScale

    if not self.SizeOverLifetime.Enabled then
        return scale
    end

    local t = particle.FrameCount / particle.Lifetime

    return scale * self.SizeOverLifetime:Evaluate(t, particle.LerpFactor)
end

---@param particle Particle
function ParticleEmitter:_GetParticleRotation(particle)
    local rotation = particle.Rotation

    if not self.RotationOverLifetime.Enabled then
        return rotation
    end

    local t = particle.FrameCount / particle.Lifetime
    return rotation + self.RotationOverLifetime:Evaluate(t, particle.LerpFactor)
end

function ParticleEmitter:_UpdateBursts()
    for i, burst in ipairs(self.Bursts) do
        local numCyclesFired = self._BurstCycles[i] or 0
        local cycles = burst.Cycles or 1
        local interval = math.max(1, burst.Interval or 1)
        local probability = burst.Probability or 1

        -- Spawn N burss for the cycle.
        while cycles == 0 or numCyclesFired < cycles do
            local fireTime = burst.Time + numCyclesFired * interval

            -- Prevent particle spawning if the burst at the end or past the cycle or the burst
            -- isn't scheuduled.
            if fireTime >= self.Duration or fireTime >= self._EmitterTime + 1 then
                break
            end

            if PaletteUtils.GetRandom() < probability then
                local count = PaletteUtils.SampleInteger(burst.Count)
                self:Emit(count)
            end

            numCyclesFired = numCyclesFired + 1
        end

        self._BurstCycles[i] = numCyclesFired
    end
end

function ParticleEmitter:_UpdateFollowPosition()
    if self._FollowingEntity then
        if not self._FollowingEntity:Exists() then
            self._FollowingEntity = nil
        else
            self.Position = self._FollowingEntity.Position + self._EntityFollowOffset
        end
    end
end

function ParticleEmitter:_Tick()
    self:_UpdateParticles()

    -- Flag instead of destroying directly. Because Palette calls `Update()` in a loop, calling
    -- `Destroy()` would make Palette skip the next emitter this frame. The sweep in palette.lua
    -- destroys it afterwards.
    if self._IsFinished and self.DestroyOnFinish and #self._Particles == 0 then
        self._PendingDestroy = true
    end

    if self:IsEmitting() then
        if self._DelayElapsed < self.StartDelay then
            self._DelayElapsed = self._DelayElapsed + 1
        else
            self:_UpdateBursts()
            self:_UpdateContinuousEmission()
            self._EmitterTime = self._EmitterTime + 1

            if self._EmitterTime >= self.Duration then
                if self.Looping then
                    self._EmitterTime = 0
                    self._BurstCycles = {}
                else
                    self._IsFinished = true
                    self:Stop()
                end
            end
        end
    end
end

---@param frames number
function ParticleEmitter:Prewarm(frames)
    if self:IsDestroyed() then
        return
    end

    if not frames then
        local lifetime = self.Lifetime

        if type(lifetime) == "table" then
            lifetime = lifetime.Max
        end

        ---@diagnostic disable-next-line: cast-local-type
        frames = lifetime
    end

    self:_UpdateFollowPosition()
    self._DelayElapsed = math.max(self._DelayElapsed, self.StartDelay)

    for i = 1, frames do
        self:_Tick()
    end
end

return ParticleEmitter
