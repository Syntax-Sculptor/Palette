---@class PaletteOverLifetime<T>
---@field Enabled boolean
---@field Mode InterpolationMode
---@field CurveMode CurveMode
---@field Keys Keyframe<T>[]
---@field KeysMin Keyframe<T>[]
---@field KeysMax Keyframe<T>[]
---@field DefaultValue T
local PaletteOverLifetime = {}
PaletteOverLifetime.__index = PaletteOverLifetime

local PaletteKeyframes = include("palette_scripts.palette_keyframes")
local PaletteUtils = include("palette_scripts.palette_utils")

---@generic T
---@param defaultValue T
---@return PaletteOverLifetime<T>
function PaletteOverLifetime.New(defaultValue)
    ---@type PaletteOverLifetime<T>
    local self = {
        Enabled = false,
        Mode = "Blend",
        CurveMode = "Single",
        Keys = {
            { Time = 0, Value = PaletteUtils.CopyValue(defaultValue) },
            { Time = 1, Value = PaletteUtils.CopyValue(defaultValue) }
        },
        KeysMin = {
            { Time = 0, Value = PaletteUtils.CopyValue(defaultValue) },
            { Time = 1, Value = PaletteUtils.CopyValue(defaultValue) }
        },
        KeysMax = {
            { Time = 0, Value = PaletteUtils.CopyValue(defaultValue) },
            { Time = 1, Value = PaletteUtils.CopyValue(defaultValue) }
        },
        DefaultValue = PaletteUtils.CopyValue(defaultValue)
    }
    
    return setmetatable(self, PaletteOverLifetime)
end

---@generic T
---@param time number
---@param lerpFactor number
---@return T
function PaletteOverLifetime:Evaluate(time, lerpFactor)
    if self.CurveMode == "Single" then
        return PaletteKeyframes.Evaluate(
            self.Keys,
            time,
            self.DefaultValue,
            self.Mode,
            PaletteUtils.Lerp
        )
    else
        local min = PaletteKeyframes.Evaluate(
            self.KeysMin,
            time,
            self.DefaultValue,
            self.Mode,
            PaletteUtils.Lerp
        )
        local max = PaletteKeyframes.Evaluate(
            self.KeysMax,
            time,
            self.DefaultValue,
            self.Mode,
            PaletteUtils.Lerp
        )

        return PaletteUtils.Lerp(min, max, lerpFactor)
    end
end

return PaletteOverLifetime
