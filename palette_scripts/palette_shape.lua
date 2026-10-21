local PaletteShape = {}

local PaletteUtils = include("palette_scripts.palette_utils")

---@param angle number
---@param a number
---@param b number
function PaletteShape.GetCircleWeight(angle, a, b)
    return math.sqrt(
        (a * math.sin(angle)) ^ 2 +
        (b * math.cos(angle)) ^ 2
    )
end

---@param points Vector[]
---@param t number
function PaletteShape.EvaluateBezier(points, t)
    local a = PaletteUtils.LerpVector(points[1], points[2], t)
    local b = PaletteUtils.LerpVector(points[2], points[3], t)

    if #points == 3 then
        return PaletteUtils.LerpVector(a, b, t)
    end

    local c = PaletteUtils.LerpVector(points[3], points[4], t)
    local d = PaletteUtils.LerpVector(a, b, t)
    local e = PaletteUtils.LerpVector(b, c, t)

    return PaletteUtils.LerpVector(d, e, t)
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
            local chosenRadius = math.sqrt(minRadius ^ 2 + u * (shape.Radius ^ 2 - minRadius ^ 2))

            local offset = Vector(
                chosenRadius * math.cos(angle) * shape.Scale.X,
                chosenRadius * math.sin(angle) * shape.Scale.Y
            ):Rotated(orientation)

            return emitterPosition + offset
        else
            -- Weighted angle sampling. With elipses, we can't simply divide the shape using the
            -- same angle and just pick one since the distances would be unequal due to how the
            -- shape looks. We use weighted selection to help promote even distribution.
            local a = shape.Radius * shape.Scale.X
            local b = shape.Radius * shape.Scale.Y
            local maxWeight = math.max(a, b)

            repeat
                angle = math.rad(PaletteUtils.GetRandomFloat(0, shape.Arc))
            until PaletteUtils.GetRandom() * maxWeight <= PaletteShape.GetCircleWeight(angle, a, b)

            local offset = Vector(a * math.cos(angle), b * math.sin(angle)):Rotated(orientation)
            return emitterPosition + offset
        end
    elseif shape.Type == "Rectangle" then
        local width = shape.Size.X * shape.Scale.X
        local height = shape.Size.Y * shape.Scale.Y
        local randX = PaletteUtils.GetRandomFloat(-width / 2, width / 2)
        local randY = PaletteUtils.GetRandomFloat(-height / 2, height / 2)

        if shape.EmitFrom == "Edge" then
            -- Weight each pair of edges by its length for uniform perimeter sampling.
            local choice = PaletteUtils.GetRandomFloat(0, width + height)

            if choice < width then
                randY = PaletteUtils.GetRandom() < 0.5 and -height / 2 or height / 2
            else
                randX = PaletteUtils.GetRandom() < 0.5 and -width / 2 or width / 2
            end
        end

        local offset = Vector(randX, randY):Rotated(orientation)

        return emitterPosition + offset
    elseif shape.Type == "Triangle" then
        if #shape.Vertices < 3 then
            error("A particle emitter must have at least 3 vertices!")
        end

        local a = shape.Vertices[1] * shape.Scale
        local b = shape.Vertices[2] * shape.Scale
        local c = shape.Vertices[3] * shape.Scale

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
        local length = shape.Length * shape.Scale.X
        local randLength = PaletteUtils.GetRandomFloat(-length / 2, length / 2)
        local point = Vector(randLength, 0):Rotated(orientation)
        return emitterPosition + point
    elseif shape.Type == "Polygon" then
        local sideCount = math.max(3, math.floor(shape.Sides))

        ---@type Vector[]
        local vertices = {}

        for i = 1, sideCount do
            local angle = (2 * math.pi * i) / sideCount
            local vertex = Vector(shape.Radius * math.cos(angle), shape.Radius * math.sin(angle)) * shape.Scale
            table.insert(vertices, vertex)
        end

        local lengths = {}
        local perimeter = 0

        -- If we set the shape's scale, each side has uneven length. We need to use weighted selection
        -- To get around this.

        for i = 1, sideCount do
            local nextIndex = i % sideCount + 1
            local length = (vertices[nextIndex] - vertices[i]):Length()

            lengths[i] = length
            perimeter = perimeter + length
        end

        if shape.EmitFrom == "Edge" then
            local lengths = {}
            local perimeter = 0

            for i = 1, sideCount do
                local nextIndex = i % sideCount + 1
                local length = (vertices[nextIndex] - vertices[i]):Length()

                lengths[i] = length
                perimeter = perimeter + length
            end

            local choice = PaletteUtils.GetRandomFloat(0, perimeter)
            local index = sideCount

            for i = 1, sideCount do
                if choice < lengths[i] then
                    index = i
                    break
                end

                choice = choice - lengths[i]
            end

            local nextIndex = index % sideCount + 1
            local a = vertices[index]
            local b = vertices[nextIndex]

            local t = PaletteUtils.GetRandom()
            local point = (a + (b - a) * t):Rotated(orientation)

            return emitterPosition + point
        else
            -- All center-based triangles have equal areas,
            -- even after nonuniform scaling.
            local index = PaletteUtils.GetRandomInt(1, sideCount)
            local nextIndex = index % sideCount + 1

            local a = vertices[index]
            local b = vertices[nextIndex]

            local point = PaletteShape.GetPointInTriangle(
                a, b, Vector.Zero
            ):Rotated(orientation)

            return emitterPosition + point
        end
    elseif shape.Type == "Capsule" then
        local halfStraight = shape.Length / 2 - shape.Radius

        if shape.EmitFrom == "Area" then
            local rectangularArea = 4 * halfStraight * shape.Radius
            local capsuleArea = math.pi * shape.Radius ^ 2
            local totalArea = rectangularArea + capsuleArea
            local rectangleChance = rectangularArea / totalArea
            local chance = PaletteUtils.GetRandom()

            -- Obviously a capsule has a rectanguilar region followed by a semi-circle region at its
            -- ends. Pick one randomly.
            if chance <= rectangleChance then
                local x = PaletteUtils.GetRandomFloat(-halfStraight, halfStraight)
                local y = PaletteUtils.GetRandomFloat(-shape.Radius, shape.Radius)
                local offset = (Vector(x, y) * shape.Scale):Rotated(orientation)
                return emitterPosition + offset
            else
                -- First pick a random angle within the semi-circle.
                local isRight = PaletteUtils.GetRandom() < 0.5
                local angle

                if isRight then
                    angle = PaletteUtils.GetRandomFloat(-math.pi / 2, math.pi / 2)
                else
                    angle = PaletteUtils.GetRandomFloat(math.pi / 2, 3 * math.pi / 2)
                end

                -- Offset the point.
                local r = shape.Radius * math.sqrt(PaletteUtils.GetRandom())
                local x = r * math.cos(angle)
                local y = r * math.sin(angle)

                if isRight then
                    x = x + halfStraight
                else
                    x = x - halfStraight
                end

                local offset = (Vector(x, y) * shape.Scale):Rotated(orientation)
                return emitterPosition + offset
            end
        else
            local straightLength = 4 * halfStraight
            local curveLength = 2 * math.pi * shape.Radius
            local perimeter = straightLength + curveLength
            local straightChance = straightLength / perimeter
            local offset
            local weight

            local maxWeight = math.max(shape.Scale.X, shape.Scale.Y)

            -- Weighted distribution since capsules are uneven shapes.
            repeat
                if PaletteUtils.GetRandom() < straightChance then
                    local x = PaletteUtils.GetRandomFloat(-halfStraight, halfStraight)
                    local y = PaletteUtils.GetRandom() < 0.5 and -shape.Radius or shape.Radius
                    weight = shape.Scale.X
                    offset = Vector(x, y)
                else
                    local isRight = PaletteUtils.GetRandom() < 0.5
                    local angle

                    if isRight then
                        angle = PaletteUtils.GetRandomFloat(-math.pi / 2, math.pi / 2)
                    else
                        angle = PaletteUtils.GetRandomFloat(math.pi / 2, 3 * math.pi / 2)
                    end

                    local x = shape.Radius * math.cos(angle)

                    if isRight then
                        x = x + halfStraight
                    else
                        x = x - halfStraight
                    end

                    local y = math.sin(angle) * shape.Radius

                    offset = Vector(x, y)
                    weight = PaletteShape.GetCircleWeight(angle, shape.Scale.X, shape.Scale.Y)
                end
            until PaletteUtils.GetRandom() * maxWeight <= weight

            return emitterPosition + (offset * shape.Scale):Rotated(orientation)
        end
    else if shape.Type == "Bezier" then
            -- De Casteljau algorithm implementation.
            -- With how many particles can be present on the screen, this can be extremely performance
            -- intensive, so we opt for caching instead. And to uniformly sample our arcs we just
            -- perform a binary search and cumulative-distance lookup table.

            -- I genuinely don't know what I'm doing writing this for the most part since I just copied
            -- most of the algorithm blindly, this math hurts my brain :(

            local points = shape.Points
            local resolution = shape.CurveResolution
            local cache = shape._BezierCache

            local isCacheValid = cache.Resolution == resolution
                and cache.Scale.X == shape.Scale.X
                and cache.Scale.Y == shape.Scale.Y
                and #cache.OriginalPoints == #points
                and #cache.Lookup == resolution + 1
                and cache.TotalLength > 0

            if isCacheValid then
                for i = 1, #points do
                    local current = points[i]
                    local previous = cache.OriginalPoints[i]

                    if current.X ~= previous.X or current.Y ~= previous.Y then
                        isCacheValid = false
                        break
                    end
                end
            end

            if not isCacheValid then
                ---@type Vector[]
                local scaledPoints = {}
                ---@type Vector[]
                local originalPoints = {}

                for i = 1, #points do
                    local point = points[i]
                    originalPoints[i] = Vector(point.X, point.Y)
                    scaledPoints[i] = point * shape.Scale
                end

                ---@type BezierLookup[]
                local lookup = {
                    { T = 0, Length = 0 }
                }

                local totalLength = 0
                local previousPoint = PaletteShape.EvaluateBezier(scaledPoints, 0)

                -- Approximate the curve with small line segments.
                for i = 1, resolution do
                    local t = i / resolution
                    local currentPoint = PaletteShape.EvaluateBezier(scaledPoints, t)

                    local distance = (currentPoint - previousPoint):Length()
                    totalLength = totalLength + distance

                    table.insert(lookup, { T = t, Length = totalLength })

                    previousPoint = currentPoint
                end

                cache = {
                    OriginalPoints = originalPoints,
                    ScaledPoints = scaledPoints,
                    Resolution = resolution,
                    Scale = Vector(shape.Scale.X, shape.Scale.Y),
                    Lookup = lookup,
                    TotalLength = totalLength
                }

                shape._BezierCache = cache
            end

            -- Select a uniformly random distance along the curve.
            local targetDistance = PaletteUtils.GetRandomFloat(0, cache.TotalLength)

            -- Binary search for the surrounding lookup entries just for more optimization compared
            -- to linear searches (ew).
            local index = PaletteUtils.BinarySearchDictionary(cache.Lookup, targetDistance, "Length")
            index = math.max(2, math.min(index, #cache.Lookup))
            local lookup = cache.Lookup

            -- ... Aaand final interpolation.
            local left = lookup[index - 1]
            local right = lookup[index]

            local segmentLength = right.Length - left.Length

            local alpha = 0

            if segmentLength > 0 then
                alpha = (targetDistance - left.Length) / segmentLength
            end

            local t = PaletteUtils.Lerp(left.T, right.T, alpha)
            local offset = PaletteShape.EvaluateBezier(cache.ScaledPoints, t):Rotated(orientation)

            return emitterPosition + offset
        end
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
