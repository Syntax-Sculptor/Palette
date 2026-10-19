local PaletteShape = {}

local PaletteUtils = include("palette_scripts.palette_utils")

---@param angle number
---@param a number
---@param b number
function PaletteShape.GetCircleWeight(angle, a, b)
    return math.sqrt(
        (a * math.sin(angle))^2 +
        (b * math.cos(angle))^2
    )
end

---@param a Vector
---@param b Vector
---@param c Vector
function PaletteShape.GetPointInTriangle(a, b, c)
    local u, v = PaletteUtils.GetRandom(), PaletteUtils.GetRandom()

    -- Uniform triangle sampling (baycentric coordinates)
    if u + v > 1 then
        u = 1 - u
        v = 1 - v
    end

    return a + u * (b - a) + v * (c - a)
end

---@param shape PaletteShapeConfig
---@param emitterPosition Vector
---@param orientation number
---@return Vector
function PaletteShape.GetSpawnPosition(shape, emitterPosition, orientation)
    if shape.EmitFrom ~= "Area" and shape.EmitFrom ~= "Edge" then
        error("Invalid EmitFrom: " .. shape.EmitFrom)
    end

    if shape.Type == "Point" then
        return emitterPosition
    elseif shape.Type == "Circle" then
        local angle = math.rad(PaletteUtils.GetRandomFloat(0, shape.Arc))

        if shape.EmitFrom == "Area" then        
            -- Inverse Transform Sampling so we can generate a position uniformly distributed inside
            -- the circle's thickness.
            local u = PaletteUtils.GetRandom()
            local minRadius = shape.Radius * (1 - shape.RadiusThickness)
            local chosenRadius = math.sqrt(minRadius^2 + u * (shape.Radius^2 - minRadius^2))
            
            local offset = Vector(
                chosenRadius * math.cos(angle) * shape.Size.X,
                chosenRadius * math.sin(angle) * shape.Size.Y
            ):Rotated(orientation)

            return emitterPosition + offset
        else
            -- Weighted angle sampling. With elipses, we can't simply divide the shape using the
            -- same angle and just pick one since the distances would be unequal due to how the
            -- shape looks. We use weighted selection to help promote even distribution.
            local a = shape.Radius * shape.Size.X
            local b = shape.Radius * shape.Size.Y
            local maxWeight = math.max(a, b)
        
            repeat
                angle = math.rad(PaletteUtils.GetRandomFloat(0, shape.Arc))
            until PaletteUtils.GetRandom() * maxWeight <= PaletteShape.GetCircleWeight(angle, a, b)

            local offset = Vector(a * math.cos(angle), b * math.sin(angle)):Rotated(orientation)
            return emitterPosition + offset
        end

    elseif shape.Type == "Rectangle" then
        local randX = PaletteUtils.GetRandomFloat(-shape.Size.X / 2, shape.Size.X / 2)
        local randY = PaletteUtils.GetRandomFloat(-shape.Size.Y / 2, shape.Size.Y / 2)

        if shape.EmitFrom == "Edge" then
            -- Weight each pair of edges by its length for uniform perimeter sampling.
            local choice = PaletteUtils.GetRandomFloat(0, shape.Size.X + shape.Size.Y)

            if choice < shape.Size.X then
                randY = PaletteUtils.GetRandom() < 0.5 and -shape.Size.Y / 2 or shape.Size.Y / 2
            else
                randX = PaletteUtils.GetRandom() < 0.5 and -shape.Size.X / 2 or shape.Size.X / 2
            end
        end

        local offset = Vector(randX, randY):Rotated(orientation)

        return emitterPosition + offset
    elseif shape.Type == "Triangle" then
        if #shape.Vertices < 3 then
            error("A particle emitter must have at least 3 vertices!")
        end
        
        local a, b, c = shape.Vertices[1], shape.Vertices[2], shape.Vertices[3]

        if shape.EmitFrom == "Edge" then
            local lengthAB = (a - b):Length()
            local lengthBC = (b - c):Length()
            local lengthCA = (c - a):Length()
            local perimeter = lengthAB + lengthBC + lengthCA
            local u = PaletteUtils.GetRandom()

            local choice = PaletteUtils.GetRandomFloat(0, perimeter)
            local startVertex, endVertex

            if choice < lengthAB then
                startVertex = a
                endVertex = b
            elseif choice < lengthAB + lengthBC then
                startVertex = b
                endVertex = c
            else
                startVertex = c
                endVertex = a
            end

            local point = startVertex + u * (endVertex - startVertex)
            point = point:Rotated(orientation)

            return emitterPosition + point
        else
            local offset = PaletteShape.GetPointInTriangle(a, b, c):Rotated(orientation)
            return emitterPosition + offset
        end
    elseif shape.Type == "Line" then
        local u = PaletteUtils.GetRandom()
        local randLength = PaletteUtils.GetRandomFloat(-shape.Length / 2, shape.Length / 2)
        local point = Vector(randLength * u, 0):Rotated(orientation)
        return emitterPosition + point
    elseif shape.Type == "Polygon" then
        local sideCount = math.max(3, math.floor(shape.Sides))

        ---@type Vector[]
        local vertices = {}

        for i = 1, sideCount do
            local angle = (2 * math.pi * i) / sideCount
            local vertex = Vector(shape.Radius * math.cos(angle), shape.Radius * math.sin(angle))
            table.insert(vertices, vertex)
        end

        -- Visually, picture this like uh, splitting a polygon into N triangles. Then the black
        -- magic for this is simple.
        local index = PaletteUtils.GetRandomInt(1, #vertices)
        local nextIndex = (index % sideCount) + 1
        local a = vertices[index]
        local b = vertices[nextIndex]

        if shape.EmitFrom == "Edge" then
            local t = PaletteUtils.GetRandom()
            local point = (a + (b - a) * t):Rotated(orientation)
            return emitterPosition + point
        else
            local point = PaletteShape.GetPointInTriangle(a, b, Vector.Zero):Rotated(orientation)
            return emitterPosition + point
        end
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
