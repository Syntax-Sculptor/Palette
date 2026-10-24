local PaletteNoise = {}
local PaletteUtils = include("palette_scripts.palette_utils")

local CURL_EPSILON = 0.01
local GRADIENTS = {
    { 1,       0 },
    { -1,      0 },
    { 0,       1 },
    { 0,       -1 },
    { 0.7071,  0.7071 },
    { -0.7071, 0.7071 },
    { 0.7071,  -0.7071 },
    { -0.7071, -0.7071 }
}

local perm = {}

---@param x number
---@param y number
function PaletteNoise.Curl2D(x, y)
    local dpdx = (PaletteNoise.Perlin2D(x + CURL_EPSILON, y) -
        PaletteNoise.Perlin2D(x - CURL_EPSILON, y)) / (2 * CURL_EPSILON)
    local dpdy = (PaletteNoise.Perlin2D(x, y + CURL_EPSILON) - PaletteNoise.Perlin2D(x, y - CURL_EPSILON)) /
        (2 * CURL_EPSILON)
    return dpdy, -dpdx
end

---@param t number
function PaletteNoise.PerlinSmoothstep(t)
    return 6 * t ^ 5 - 15 * t ^ 4 + 10 * t ^ 3
end

---@param xi number
---@param yi number
function PaletteNoise.Hash(xi, yi)
    return perm[perm[(xi % 256) + 1] + (yi % 256) + 1]
end

---@param x number
---@param y number
function PaletteNoise.Perlin2D(x, y)
    local xi = math.floor(x)
    local yi = math.floor(y)
    local xf = x - xi
    local yf = y - yi
    local g00 = GRADIENTS[PaletteNoise.Hash(xi, yi) % 8 + 1]
    local g10 = GRADIENTS[PaletteNoise.Hash(xi + 1, yi) % 8 + 1]
    local g01 = GRADIENTS[PaletteNoise.Hash(xi, yi + 1) % 8 + 1]
    local g11 = GRADIENTS[PaletteNoise.Hash(xi + 1, yi + 1) % 8 + 1]
    local n00 = g00[1] * xf + g00[2] * yf
    local n10 = g10[1] * (xf - 1) + g10[2] * yf
    local n01 = g01[1] * xf + g01[2] * (yf - 1)
    local n11 = g11[1] * (xf - 1) + g11[2] * (yf - 1)
    local u = PaletteNoise.PerlinSmoothstep(xf)
    local v = PaletteNoise.PerlinSmoothstep(yf)
    local top = PaletteUtils.Lerp(n00, n10, u)
    local bottom = PaletteUtils.Lerp(n01, n11, u)
    local result = PaletteUtils.Lerp(top, bottom, v)
    return result * math.sqrt(2)
end

-- TODO: Get rid of this module loading sideeffect.
for i = 0, 255 do
    table.insert(perm, i)
end

PaletteUtils.ShuffleTableInPlace(perm)

for i = 0, 255 do
    table.insert(perm, perm[i + 1])
end

return PaletteNoise
