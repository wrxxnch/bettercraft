local selectors = {}

--------------------------------------------------
-- DISTANCE
--------------------------------------------------

local function get_distance(p1, p2)
    if not p1 or not p2 then
        return math.huge
    end

    return math.sqrt(
        (p1.x - p2.x)^2 +
        (p1.y - p2.y)^2 +
        (p1.z - p2.z)^2
    )
end

--------------------------------------------------
-- PARSE ARGUMENTS
--------------------------------------------------

local function parse_args(arg_str)

    local args = {}

    if not arg_str or arg_str == "" then
        return args
    end

    arg_str = arg_str:gsub("^%[", ""):gsub("%]$", "")

    for pair in arg_str:gmatch("([^,]+)") do

        local key, value = pair:match("([^=]+)=([^=]+)")

        if key and value then
            key = key:gsub("^%s*(.-)%s*$", "%1")
            value = value:gsub("^%s*(.-)%s*$", "%1")

            args[key] = value
        end

    end

    return args
end

--------------------------------------------------
-- ENTITY TYPE
--------------------------------------------------

local function get_entity_type(obj)

    if obj:is_player() then
        return "player"
    end

    local ent = obj:get_luaentity()

    if ent and ent.name then
        return ent.name
    end

    return "unknown"

end

--------------------------------------------------
-- SAFE GET POS
--------------------------------------------------

local function safe_get_pos(obj)

    if obj and obj.get_pos then
        return obj:get_pos()
    end

    return nil

end

--------------------------------------------------
-- TYPE CHECK
--------------------------------------------------

local function type_matches(obj, wanted)

    if not wanted then
        return true
    end

    local etype = get_entity_type(obj)

    if etype == wanted then
        return true
    end

    if etype:match(":" .. wanted .. "$") then
        return true
    end

    return false

end

--------------------------------------------------
-- FILTER FUNCTION
--------------------------------------------------

local function filter_objects(objs, caller_pos, args)

    local results = {}

    for _, obj in ipairs(objs) do

        local keep = true

        local pos = safe_get_pos(obj)

        if not pos then
            keep = false
        end

        if args.type and keep then
            if not type_matches(obj, args.type) then
                keep = false
            end
        end

        if args.r and caller_pos and keep then
            if get_distance(caller_pos, pos) > tonumber(args.r) then
                keep = false
            end
        end

        if keep then
            table.insert(results, obj)
        end

    end

    return results

end

--------------------------------------------------
-- RESOLVE
--------------------------------------------------

function selectors.resolve(caller_name, selector_str)

    local selector_type = selector_str:match("^(@%w+)")
    local arg_str = selector_str:match("%[.*%]")
    local args = parse_args(arg_str)

    local caller = minetest.get_player_by_name(caller_name)
    local caller_pos = caller and caller:get_pos()

    local candidates = {}

    --------------------------------------------------
    -- BASE SELECTION
    --------------------------------------------------

    if selector_type == "@a" then

        candidates = minetest.get_connected_players()

    elseif selector_type == "@s" then

        if caller then
            table.insert(candidates, caller)
        end

    elseif selector_type == "@e" then

        if not caller_pos then
            return {}
        end

        local radius = tonumber(args.r) or 100

        candidates = minetest.get_objects_inside_radius(caller_pos, radius)

    elseif selector_type == "@p" then

        if not caller_pos then
            return {}
        end

        local radius = tonumber(args.r) or 100

        local objs = minetest.get_objects_inside_radius(caller_pos, radius)

        objs = filter_objects(objs, caller_pos, args)

        local nearest
        local min_dist = math.huge

        for _, obj in ipairs(objs) do

            local pos = safe_get_pos(obj)

            if pos then

                local d = get_distance(caller_pos, pos)

                if d < min_dist then
                    min_dist = d
                    nearest = obj
                end

            end

        end

        if nearest then
            table.insert(candidates, nearest)
        end

        return candidates

    elseif selector_type == "@r" then

        if not caller_pos then
            return {}
        end

        local radius = tonumber(args.r) or 100

        local objs = minetest.get_objects_inside_radius(caller_pos, radius)

        objs = filter_objects(objs, caller_pos, args)

        if #objs > 0 then
            table.insert(candidates, objs[math.random(#objs)])
        end

        return candidates

    else

        local player = minetest.get_player_by_name(selector_str)

        if player then
            return {player}
        end

        return {}

    end

    --------------------------------------------------
    -- FILTER FINAL
    --------------------------------------------------

    candidates = filter_objects(candidates, caller_pos, args)

    return candidates

end

return selectors