---@meta

-- This file only defines the classes for Lua LSP to detect and load. There is no need to call
-- `include`/`require` on this file; it should be detected on its own.

---@class Particle This class defines a singular particle instance emitted from a ParticleEmitter.
---@field Position Vector
---@field Velocity Vector
---@field FrameCount integer How many update frames the particle has elapsed.
---@field Lifetime integer How many update frames until the particle is removed.
---@field Scale Vector The particle's scale multiplier. Setting it to `Vector(1, 1)` will use the sprite's original dimensions.
---@field StartScale Vector Initial particle scale.
---@field Rotation number
---@field Color KColor
---@field StartColor KColor
---@field LerpFactor number
---@field SpawnPosition Vector

---@alias InterpolationMode "Blend"|"Fixed"
---@alias CurveMode "Single"|"TwoCurves"
---@alias PaletteShapeType "Point"|"Circle"|"Rectangle"|"Triangle"|"Line"|"Polygon"
---@alias DirectionMode "Radial"|"Default"
---@alias EmitFrom "Area"|"Edge"
---@alias PaletteRenderMode "AboveEntities"|"Floor"

---@class PaletteGradient
---@field ColorKeys Keyframe<KColor>[]
---@field AlphaKeys Keyframe<number>[]

---@class PaletteVelocityOverLifetime
---@field Enabled boolean
---@field Space "Local"|"World"
---@field LinearVelocity Vector
---@field OrbitalVelocity number Rotation around the orbital center, in degrees per frame. Default: 0
---@field OrbitalOffset Vector
---@field Radial number
---@field SpeedModifier number

---@class PaletteMinMaxFloat
---@field Min number
---@field Max number

---@class PaletteMinMaxInteger
---@field Min integer
---@field Max integer

---@class PaletteMinMaxVector
---@field Min Vector
---@field Max Vector

---@class PaletteMinMaxKColor
---@field Min KColor
---@field Max KColor

---@class Keyframe<T>
---@field Time number
---@field Value T

---@class KeyframeSegment<T>
---@field Left T
---@field Right T
---@field Alpha number

---@class PaletteShapeConfig
---@field Type PaletteShapeType
---@field Radius number Default: 40
---@field RadiusThickness number Default: 1
---@field Arc number Default: 360
---@field Size Vector Default: (1, 1)
---@field DirectionMode DirectionMode Default: "Default"
---@field EmitFrom EmitFrom Default: "Area"
---@field Vertices Vector[] Default: {Vector(-50, 30), Vector(50, 30), Vector(0, -60)}
---@field Length number
---@field Sides integer

---@class PaletteColorOverLifetime
---@field Enabled boolean
---@field Mode InterpolationMode
---@field CurveMode CurveMode
---@field Gradient PaletteGradient
---@field GradientMin PaletteGradient
---@field GradientMax PaletteGradient