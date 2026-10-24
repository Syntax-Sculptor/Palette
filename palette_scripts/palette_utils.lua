local PaletteUtils = {}

local utilsRNG = RNG(Random(), 35)

---100% the same as PaletteUtils.Lerp, though this function must exist so Lua's linter doesn't
---flip out.
---@param a Vector
---@param b Vector
---@param t number
function PaletteUtils.LerpVector(a, b, t)
    return a + (b - a) * t
end

---@param a number
---@param b number
---@param t number
function PaletteUtils.Lerp(a, b, t)
    return a + (b - a) * t
end

---@param a KColor
---@param b KColor
---@param t number
function PaletteUtils.LerpKColor(a, b, t)
    return KColor(
        PaletteUtils.Lerp(a.Red, b.Red, t),
        PaletteUtils.Lerp(a.Green, b.Green, t),
        PaletteUtils.Lerp(a.Blue, b.Blue, t),
        PaletteUtils.Lerp(a.Alpha, b.Alpha, t)
    )
end

---@generic T
---@param value T
---@return T
function PaletteUtils.CopyValue(value)
    if type(value) ~= "userdata" then
        return value
    end

    local name = getmetatable(value).__type

    if name == "Vector" then
        return Vector(value.X, value.Y)
    elseif name == "KColor" then
        return KColor(value.Red, value.Green, value.Blue, value.Alpha)
    else
        error("Couldn't copy userdata " .. name .. " (unsupported!)")
    end
end

---@param left KColor
---@param right KColor
function PaletteUtils.MultiplyKColor(left, right)
    return KColor(
        left.Red * right.Red,
        left.Green * right.Green,
        left.Blue * right.Blue,
        left.Alpha * right.Alpha
    )
end

--- Returns a random number between 0 (inclusive) and 1 (exclusive).
---
--- You can pass a seed to generate a random number using it. Alternatively, you can pass a `RNG`
--- object to generate the number (which advances its seed). If you pass nothing, a random number
--- is generated using Palette's internal RNG object.
---@param rngOrSeed RNG | integer | nil
function PaletteUtils.GetRandom(rngOrSeed)
    if type(rngOrSeed) == "number" then
        local rng = RNG(rngOrSeed, 35)
        return rng:RandomFloat()
    elseif type(rngOrSeed) == "userdata" then
        ---@cast rngOrSeed RNG
        return rngOrSeed:RandomFloat()
    else
        return utilsRNG:RandomFloat()
    end
end

--- Returns a random number between `min` (inclusive) and `max` (exclusive).
---
--- You can pass a seed to generate a random number using it. Alternatively, you can pass a `RNG`
--- object to generate the number (which advances its seed). If you pass nothing, a random number
--- is generated using Palette's internal RNG object.
---@param min number
---@param max number
---@param rngOrSeed RNG | integer | nil
function PaletteUtils.GetRandomFloat(min, max, rngOrSeed)
    if min > max then
        local old_min = min
        local old_max = max
        min = old_max
        max = old_min
    end

    return min + PaletteUtils.GetRandom(rngOrSeed) * (max - min)
end

--- Returns a random integer between `min` (inclusive) and `max` (inclusive).
---
--- You can pass a seed to generate a random integer using it. Alternatively, you can pass a `RNG`
--- object to generate the integer (which advances its seed). If you pass nothing, a random integer
--- is generated using Palette's internal RNG object.
---@param min integer
---@param max integer
---@param rngOrSeed RNG | integer | nil
---@return number
function PaletteUtils.GetRandomInt(min, max, rngOrSeed)
    assert(min % 1 == 0 and max % 1 == 0, "GetRandomInt requires integer bounds")

    if min > max then
        local old_min = min
        local old_max = max
        min = old_max
        max = old_min
    end

    return math.floor(PaletteUtils.GetRandom(rngOrSeed) * (max - min + 1)) + min
end

---@param rangeOrFixed PaletteMinMaxFloat | number
---@param rngOrSeed RNG | integer | nil
function PaletteUtils.SampleFloat(rangeOrFixed, rngOrSeed)
    if type(rangeOrFixed) == "number" then
        return rangeOrFixed
    else
        return PaletteUtils.GetRandomFloat(rangeOrFixed.Min, rangeOrFixed.Max, rngOrSeed)
    end
end

---@param rangeOrFixed PaletteMinMaxInteger | integer
---@param rngOrSeed RNG | integer | nil
function PaletteUtils.SampleInteger(rangeOrFixed, rngOrSeed)
    if type(rangeOrFixed) == "number" then
        return rangeOrFixed
    else
        return PaletteUtils.GetRandomInt(rangeOrFixed.Min, rangeOrFixed.Max, rngOrSeed)
    end
end

---@param rangeOrFixed PaletteMinMaxVector | Vector
---@param rngOrSeed RNG | number | nil
function PaletteUtils.SampleVector(rangeOrFixed, rngOrSeed)
    if type(rangeOrFixed) == "userdata" then
        ---@diagnostic disable-next-line: undefined-field
        return Vector(rangeOrFixed.X, rangeOrFixed.Y)
    else
        -- Very cheeky way to only advance seed once lol.
        local t = PaletteUtils.GetRandom(rngOrSeed)
        return Vector(
            PaletteUtils.Lerp(rangeOrFixed.Min.X, rangeOrFixed.Max.X, t),
            PaletteUtils.Lerp(rangeOrFixed.Min.Y, rangeOrFixed.Max.Y, t)
        )
    end
end

---@param rangeOrFixed PaletteMinMaxKColor | KColor
---@param rngOrSeed RNG | number | nil
function PaletteUtils.SampleKColor(rangeOrFixed, rngOrSeed)
    if type(rangeOrFixed) == "userdata" then
        ---@diagnostic disable-next-line: undefined-field
        return KColor(rangeOrFixed.Red, rangeOrFixed.Green, rangeOrFixed.Blue, rangeOrFixed.Alpha)
    else
        -- Very cheeky way to only advance seed once lol.
        local t = PaletteUtils.GetRandom(rngOrSeed)
        return PaletteUtils.LerpKColor(rangeOrFixed.Min, rangeOrFixed.Max, t)
    end
end

---@param x number
---@param a number
---@param b number
function PaletteUtils.Clamp(x, a, b)
    return math.max(a, math.min(x, b))
end

---@param array table[]
---@param target number
function PaletteUtils.BinarySearch(array, target)
    local low = 1
    local high = #array + 1

    while low < high do
        local mid = math.floor((low + high) / 2)

        if mid <= #array and array[mid] < target then
            low = mid + 1
        else
            high = mid
        end
    end

    return low
end

---Shuffles an array using the Fisher-Yates algorithm.
---@param t table
function PaletteUtils.ShuffleTableInPlace(t)
    for i = #t, 2, -1 do
        local j = PaletteUtils.GetRandomInt(1, i)
        t[i], t[j] = t[j], t[i]
    end
end

return PaletteUtils
