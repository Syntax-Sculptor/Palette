local PaletteUtils = include("palette_scripts.palette_utils")
local PaletteKeyframes = include("palette_scripts.palette_keyframes")

local PaletteGradient = {}

--- Evaluates a color from a list of color keys at the specified `time`.
--- 
--- If the list of keys is empty, `KColor.White` is returned. Alternatively, if `time` is outside
--- the range of keys, the closest endpoint color is returned
---@param keys Keyframe<KColor>[] The color keys, sorted by timestamp.
---@param time number The time at which to evaluate the color.
---@param mode InterpolationMode? Optional. Determines how the color is evaluated. "Blend" linearly
---                          interpolates between the two surrounding keys. "Fixed" returns the next 
---                          key's color (the first key with a timestamp greater than `time`), 
---                          producing abrupt transitions. Default: "Blend".
function PaletteGradient:EvaluateColor(keys, time, mode)
    mode = mode or "Blend"
    return PaletteKeyframes.Evaluate(keys, time, KColor.White, mode, PaletteUtils.LerpKColor)
end

--- Evaluates a color from a list of alpha keys at the specified `time`.
--- 
--- If the list of keys is empty, 1 is returned. Alternatively, if `time` is outside the range of 
--- keys, the closest endpoint alpha is returned
---@param keys Keyframe<number>[] The alpha keys, sorted by timestamp.
---@param time number The time at which to evaluate the alpha.
---@param mode InterpolationMode? Optional. Determines how the alpha is evaluated. "Blend" linearly
---                          interpolates between the two surrounding keys. "Fixed" returns the next 
---                          key's alpha (the first key with a timestamp greater than `time`), 
---                          producing abrupt transitions. Default: "Blend".
function PaletteGradient:EvaluateAlpha(keys, time, mode)
    mode = mode or "Blend"
    return PaletteKeyframes.Evaluate(keys, time, 1, mode, PaletteUtils.Lerp)
end

--- Returns a `KColor` from the provided `gradient` based on `time`.
---@param gradient PaletteGradient
---@param time number
---@param mode InterpolationMode Optional. Determines how the color is evaluated. "Blend" linearly
---                         interpolates between the two surrounding keys. "Fixed" returns the next 
---                         key's color (the first key with a timestamp greater than `time`), 
---                         producing abrupt transitions. Default: "Blend".
function PaletteGradient:Evaluate(gradient, time, mode)
    mode = mode or "Blend"
    local color = PaletteGradient:EvaluateColor(gradient.ColorKeys, time, mode)
    local alpha = PaletteGradient:EvaluateAlpha(gradient.AlphaKeys, time, mode)
    return KColor(color.Red, color.Green, color.Blue, alpha)
end

--- Constructs a new gradient object.
---@return PaletteGradient
function PaletteGradient:New()
    ---@type PaletteGradient
    local newGradient = {
        Mode = "Blend",
        ColorKeys = {
            { Time = 0, Value = KColor.White },
            { Time = 1, Value = KColor.White },
        },
        AlphaKeys = {
            { Time = 0, Value = 1},
            { Time = 1, Value = 1 }
        },
    }

    return newGradient
end

return PaletteGradient