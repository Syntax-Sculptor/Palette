local PaletteShape = {}

local PaletteUtils = include("palette_scripts.palette_utils")

-- Returns how much of an elipse's outline is covered from the angle.
---@param angle number
---@param a number
---@param b number
function PaletteShape.GetElipseArcLengthRate(angle, a, b)
    return math.sqrt(
        (a * math.sin(angle)) ^ 2 +
        (b * math.cos(angle)) ^ 2
    )
end

---@param points Vector[]
---@param closed boolean
---@return number[], number
function PaletteShape.BuildPathLookup(points, closed)
    local totalLength = 0
    local segments = PaletteShape.GetNumPolylineSegments(points, closed)
    local lookup = { 0 }

    for i = 1, segments do
        local nextIdx

        if closed then
            nextIdx = i % #points + 1
        else
            nextIdx = i + 1
        end

        local length = (points[nextIdx] - points[i]):Length()
        totalLength = totalLength + length
        table.insert(lookup, totalLength)
    end

    return lookup, totalLength
end

---@param points Vector[]
---@param closed boolean
function PaletteShape.GetNumPolylineSegments(points, closed)
    local n = #points
    if closed then
        return n
    else
        return n - 1
    end
end

---@param points Vector[]
---@param lookup number[]
---@param totalLength number
---@param closed boolean
function PaletteShape.SamplePath(points, lookup, totalLength, closed)
    if totalLength <= 0 then
        return Vector.Zero
    end

    local targetDistance = PaletteUtils.GetRandomFloat(0, totalLength)
    local lookupIdx = PaletteUtils.BinarySearch(lookup, targetDistance)
    lookupIdx = PaletteUtils.Clamp(lookupIdx, 2, #lookup)
    local left = lookup[lookupIdx - 1]
    local right = lookup[lookupIdx]
    local segmentLength = right - left
    local t

    if segmentLength <= 0 then
        t = 0
    else
        t = (targetDistance - lookup[lookupIdx - 1]) / segmentLength
    end

    local segmentStart = lookupIdx - 1
    local segmentEnd

    if closed then
        segmentEnd = segmentStart % #points + 1
    else
        segmentEnd = segmentStart + 1
    end

    local a = points[segmentStart]
    local b = points[segmentEnd]

    return PaletteUtils.LerpVector(a, b, t)
end

---@param shape PaletteShapeConfig
function PaletteShape.IsPolylineCacheValid(shape)
    local cache = shape._PolylineCache

    if
        #shape.Points ~= #cache.OriginalPoints
        or shape.Closed ~= cache.Closed
        or shape.Scale.X ~= cache.Scale.X
        or shape.Scale.Y ~= cache.Scale.Y
        or PaletteShape.GetNumPolylineSegments(shape.Points, shape.Closed) ~= #cache.Lookup - 1
    then
        return false
    end

    for i = 1, #shape.Points do
        local a = shape.Points[i]
        local b = cache.OriginalPoints[i]
        if a.X ~= b.X or a.Y ~= b.Y then
            return false
        end
    end

    return true
end

---@param index number
---@param sideCount number
---@param radius number
---@param scale Vector
function PaletteShape.GetPolygonVertex(index, sideCount, radius, scale)
    local angle = 2 * math.pi * index / sideCount
    return Vector(radius * math.cos(angle), radius * math.sin(angle)) * scale
end

---@param shape PaletteShapeConfig
function PaletteShape.RebuildPolylineCache(shape)
    local cache = shape._PolylineCache
    cache.OriginalPoints = {}
    cache.ScaledPoints = {}

    for _, point in ipairs(shape.Points) do
        local pointCopy = Vector(point.X, point.Y)
        table.insert(cache.OriginalPoints, pointCopy)
        table.insert(cache.ScaledPoints, pointCopy * shape.Scale)
    end

    local lookup, totalLength = PaletteShape.BuildPathLookup(cache.ScaledPoints, shape.Closed)

    cache.Lookup = lookup
    cache.TotalLength = totalLength
    cache.Scale = Vector(shape.Scale.X, shape.Scale.Y)
    cache.Closed = shape.Closed
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

---@param isRight boolean
function PaletteShape.GetCapAngle(isRight)
    if isRight then
        return PaletteUtils.GetRandomFloat(-math.pi / 2, math.pi / 2)
    else
        return PaletteUtils.GetRandomFloat(math.pi / 2, 3 * math.pi / 2)
    end
end

---@param shape PaletteShapeConfig
function PaletteShape.IsBezierCacheValid(shape)
    local cache = shape._BezierCache
    local resolution = math.max(1, math.floor(shape.CurveResolution))

    if
        resolution ~= cache.Resolution
        or #shape.Points ~= #cache.OriginalPoints
        or shape.Scale.X ~= cache.Scale.X
        or shape.Scale.Y ~= cache.Scale.Y
        or #cache.Lookup ~= resolution + 1
    then
        return false
    end

    for i = 1, #shape.Points do
        local a = shape.Points[i]
        local b = cache.OriginalPoints[i]
        if a.X ~= b.X or a.Y ~= b.Y then
            return false
        end
    end

    return true
end

---@param shape PaletteShapeConfig
function PaletteShape.RebuildBezierCache(shape)
    local cache = shape._BezierCache
    local resolution = math.max(1, math.floor(shape.CurveResolution))

    cache.OriginalPoints = {}
    cache.ScaledPoints = {}

    for _, point in ipairs(shape.Points) do
        local pointCopy = Vector(point.X, point.Y)
        table.insert(cache.OriginalPoints, pointCopy)
        table.insert(cache.ScaledPoints, pointCopy * shape.Scale)
    end

    local lookup = { 0 }
    local totalLength = 0
    local previousPoint = PaletteShape.EvaluateBezier(cache.ScaledPoints, 0)

    -- Approximate the curve with small line segments. lookup[i] is the length up to t = (i - 1) / resolution.
    for i = 1, resolution do
        local currentPoint = PaletteShape.EvaluateBezier(cache.ScaledPoints, i / resolution)
        totalLength = totalLength + (currentPoint - previousPoint):Length()
        table.insert(lookup, totalLength)
        previousPoint = currentPoint
    end

    cache.Resolution = resolution
    cache.Lookup = lookup
    cache.TotalLength = totalLength
    cache.Scale = Vector(shape.Scale.X, shape.Scale.Y)
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
        if shape.EmitFrom == "Area" then
            -- Inverse Transform Sampling so we can generate a position uniformly distributed inside
            -- the circle's thickness.
            local angle = math.rad(PaletteUtils.GetRandomFloat(0, shape.Arc))
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
            local maxWeight = math.max(math.abs(a), math.abs(b))
            local angle

            repeat
                angle = math.rad(PaletteUtils.GetRandomFloat(0, shape.Arc))
            until PaletteUtils.GetRandom() * maxWeight <= PaletteShape.GetElipseArcLengthRate(angle, a, b)

            local offset = Vector(a * math.cos(angle), b * math.sin(angle)):Rotated(orientation)
            return emitterPosition + offset
        end
    elseif shape.Type == "Rectangle" then
        local width = shape.Size.X * shape.Scale.X
        local height = shape.Size.Y * shape.Scale.Y
        local randX = PaletteUtils.GetRandomFloat(-width / 2, width / 2)
        local randY = PaletteUtils.GetRandomFloat(-height / 2, height / 2)

        if shape.EmitFrom == "Edge" then
            -- Because rectangles are uneven shapes, we need to ensure particles are evenly
            -- distrubted.

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
            local scaledPoints = { a, b, c }
            local lookup, totalLength = PaletteShape.BuildPathLookup(scaledPoints, true)
            local point = PaletteShape.SamplePath(scaledPoints, lookup, totalLength, true)
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

        if shape.EmitFrom == "Edge" then
            ---@type Vector[]
            local vertices = {}

            for i = 1, sideCount do
                local vertex = PaletteShape.GetPolygonVertex(i, sideCount, shape.Radius, shape.Scale)
                table.insert(vertices, vertex)
            end

            local lookup, totalLength = PaletteShape.BuildPathLookup(vertices, true)
            local point = PaletteShape.SamplePath(vertices, lookup, totalLength, true)
            point = point:Rotated(orientation)

            return emitterPosition + point
        else
            -- All center-based triangles have equal areas,
            -- even after nonuniform scaling.
            local index = PaletteUtils.GetRandomInt(1, sideCount)
            local nextIndex = index % sideCount + 1

            local a = PaletteShape.GetPolygonVertex(index, sideCount, shape.Radius, shape.Scale)
            local b = PaletteShape.GetPolygonVertex(nextIndex, sideCount, shape.Radius, shape.Scale)

            local point = PaletteShape.GetPointInTriangle(
                a, b, Vector.Zero
            ):Rotated(orientation)

            return emitterPosition + point
        end
    elseif shape.Type == "Capsule" then
        local halfStraight = math.max(0, shape.Length / 2 - shape.Radius)

        if shape.EmitFrom == "Area" then
            local rectangularArea = 4 * halfStraight * shape.Radius
            local capsuleArea = math.pi * shape.Radius ^ 2
            local totalArea = rectangularArea + capsuleArea

            if totalArea <= 0 then
                return emitterPosition
            end

            local rectangleChance = rectangularArea / totalArea
            local chance = PaletteUtils.GetRandom()

            -- Obviously a capsule has a rectangular region followed by a semi-circle region at its
            -- ends. Pick one randomly.
            if chance <= rectangleChance then
                local x = PaletteUtils.GetRandomFloat(-halfStraight, halfStraight)
                local y = PaletteUtils.GetRandomFloat(-shape.Radius, shape.Radius)
                local offset = (Vector(x, y) * shape.Scale):Rotated(orientation)
                return emitterPosition + offset
            else
                local isRight = PaletteUtils.GetRandom() < 0.5
                local angle = PaletteShape.GetCapAngle(isRight)

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

            if perimeter <= 0 then
                return emitterPosition
            end

            local straightChance = straightLength / perimeter
            local offset
            local weight

            local maxWeight = math.max(math.abs(shape.Scale.X), math.abs(shape.Scale.Y))

            -- Weighted distribution since capsules are uneven shapes.
            repeat
                if PaletteUtils.GetRandom() < straightChance then
                    local x = PaletteUtils.GetRandomFloat(-halfStraight, halfStraight)
                    local y = PaletteUtils.GetRandom() < 0.5 and -shape.Radius or shape.Radius

                    -- We need to math.abs the scale so the weight doesn't become negative.
                    weight = math.abs(shape.Scale.X)
                    offset = Vector(x, y)
                else
                    local isRight = PaletteUtils.GetRandom() < 0.5
                    local angle = PaletteShape.GetCapAngle(isRight)
                    local x = shape.Radius * math.cos(angle)

                    if isRight then
                        x = x + halfStraight
                    else
                        x = x - halfStraight
                    end

                    local y = math.sin(angle) * shape.Radius

                    offset = Vector(x, y)

                    weight = PaletteShape.GetElipseArcLengthRate(angle, shape.Scale.X, shape.Scale.Y)
                end
            until PaletteUtils.GetRandom() * maxWeight <= weight

            return emitterPosition + (offset * shape.Scale):Rotated(orientation)
        end
    elseif shape.Type == "Bezier" then
        if #shape.Points < 3 then
            return emitterPosition
        end

        if not PaletteShape.IsBezierCacheValid(shape) then
            PaletteShape.RebuildBezierCache(shape)
        end

        local cache = shape._BezierCache
        if cache.TotalLength <= 0 then
            return emitterPosition
        end

        -- t isn't evenly spaced along the curve, so we pick a distance and convert it back to t.
        local targetDistance = PaletteUtils.GetRandomFloat(0, cache.TotalLength)
        local lookupIdx = PaletteUtils.BinarySearch(cache.Lookup, targetDistance)
        lookupIdx = PaletteUtils.Clamp(lookupIdx, 2, #cache.Lookup)

        local left = cache.Lookup[lookupIdx - 1]
        local right = cache.Lookup[lookupIdx]
        local segmentLength = right - left
        local alpha = 0

        if segmentLength > 0 then
            alpha = (targetDistance - left) / segmentLength
        end

        local t = (lookupIdx - 2 + alpha) / cache.Resolution
        local point = PaletteShape.EvaluateBezier(cache.ScaledPoints, t):Rotated(orientation)

        return emitterPosition + point
    elseif shape.Type == "Polyline" then
        if #shape.Points < 2 then
            return emitterPosition
        end

        if not PaletteShape.IsPolylineCacheValid(shape) then
            PaletteShape.RebuildPolylineCache(shape)
        end

        local cache = shape._PolylineCache
        if cache.TotalLength <= 0 then
            return emitterPosition
        end

        local targetDistance = PaletteUtils.GetRandomFloat(0, cache.TotalLength)
        local lookupIdx = PaletteUtils.BinarySearch(cache.Lookup, targetDistance)
        lookupIdx = PaletteUtils.Clamp(lookupIdx, 2, #cache.Lookup)
        local segmentLength = cache.Lookup[lookupIdx] - cache.Lookup[lookupIdx - 1]
        local t

        if segmentLength <= 0 then
            t = 0
        else
            t = (targetDistance - cache.Lookup[lookupIdx - 1]) / segmentLength
        end

        local segmentStart = lookupIdx - 1
        local segmentEnd

        if cache.Closed then
            segmentEnd = segmentStart % #cache.ScaledPoints + 1
        else
            segmentEnd = segmentStart + 1
        end

        local a = cache.ScaledPoints[segmentStart]
        local b = cache.ScaledPoints[segmentEnd]
        local point = PaletteUtils.LerpVector(a, b, t):Rotated(orientation)
        return emitterPosition + point
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
