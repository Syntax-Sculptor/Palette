local PaletteShape = {}

local PaletteUtils = include("palette_scripts.palette_utils")

---@param shape PaletteShapeConfig
---@param emitterPosition Vector
---@param orientation number
---@return Vector
function PaletteShape.GetSpawnPosition(shape, emitterPosition, orientation)
    if shape.Type == "Point" then
        return emitterPosition
    elseif shape.Type == "Circle" then
        -- Inverse Transform Sampling so we can generate a position uniformly distributed inside
        -- the circle's thickness.
        local u = PaletteUtils.GetRandom()
        local minRadius = shape.Radius * (1 - shape.RadiusThickness)
        local chosenRadius = math.sqrt(minRadius^2 + u * (shape.Radius^2 - minRadius^2))
        local angle = math.rad(PaletteUtils.GetRandomFloat(0, shape.Arc) + orientation)

        return emitterPosition + Vector(
            chosenRadius * math.cos(angle),
            chosenRadius * math.sin(angle)
        )
    elseif shape.Type == "Rectangle" then
        local randX = PaletteUtils.GetRandomFloat(-shape.Size.X / 2, shape.Size.X / 2)
        local randY = PaletteUtils.GetRandomFloat(-shape.Size.Y / 2, shape.Size.Y / 2)

        if shape.RectangleEmitFrom == "Edge" then
            -- Weight each pair of edges by its length for uniform perimeter sampling.
            local choice = PaletteUtils.GetRandomFloat(0, shape.Size.X + shape.Size.Y)

            if choice < shape.Size.X then
                randY = PaletteUtils.GetRandom() < 0.5 and -shape.Size.Y / 2 or shape.Size.Y / 2
            else
                randX = PaletteUtils.GetRandom() < 0.5 and -shape.Size.X / 2 or shape.Size.X / 2
            end
        elseif shape.RectangleEmitFrom ~= nil and shape.RectangleEmitFrom ~= "Area" then
            error("Unknown RectangleEmitFrom: " .. tostring(shape.RectangleEmitFrom))
        end

        local offset = Vector(randX, randY):Rotated(orientation)

        return emitterPosition + offset
    else
        error("Unsupported particle shape: " .. shape.Type)
    end
end


---@param shape PaletteShapeConfig
---@param emitterPosition Vector
---@param startPosition Vector
---@param startDirection Vector
---@return Vector
function PaletteShape.GetDirection(shape, emitterPosition, startPosition, startDirection)
    if shape.DirectionMode == "Default" then
        return Vector(startDirection.X, startDirection.Y)
    elseif shape.DirectionMode == "Radial" then
        local vec = startPosition - emitterPosition

        if vec:LengthSquared() == 0 then
            return Vector(startDirection.X, startDirection.Y)
        end

        return vec:Normalized()
    else
        error("Unsupported shape direction mode: " .. tostring(shape.DirectionMode))
    end
end

return PaletteShape
