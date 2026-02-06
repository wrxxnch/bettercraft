local S = core.get_translator(core.get_current_modname())

-- =========================
-- UTILS
-- =========================
local function resolve_node_name_safe(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end

    while core.registered_aliases[name] do
        name = core.registered_aliases[name]
    end

    if not name:find(":") then
        for regname in pairs(core.registered_nodes) do
            if regname:match(":(.+)$") == name then
                return regname
            end
        end
    end

    if core.registered_nodes[name] then
        return name
    end

    return nil
end

-- aceita: números | ~ | ~1 | pos1 | pos2
local function parse_any_pos(player, a, b, c)
    local pname = player:get_player_name()

    if a == "pos1" then
        return postick_get_pos(pname, "pos1")
    end
    if a == "pos2" then
        return postick_get_pos(pname, "pos2")
    end

    local base = vector.round(player:get_pos())

    local function r(v, b)
        if not v then
            return nil
        end
        if v:sub(1, 1) == "~" then
            return b + tonumber(v:sub(2) ~= "" and v:sub(2) or 0)
        end
        return tonumber(v)
    end

    local x = r(a, base.x)
    local y = r(b, base.y)
    local z = r(c, base.z)

    if not (x and y and z) then
        return nil
    end
    return {
        x = x,
        y = y,
        z = z
    }
end

-- =========================
-- UNDO
-- =========================
local fill_undo = {}
local clone_undo = {}

local function save_undo(tbl, name, pos, node)
    tbl[name] = tbl[name] or {}
    table.insert(tbl[name], {
        pos = vector.new(pos),
        node = node.name,
        param2 = node.param2 or 0
    })
end

core.register_chatcommand("undo_fill", {
    func = function(name)
        local d = fill_undo[name]
        if not d or #d == 0 then
            return false, S("Nothing to undo.")
        end
        for i = #d, 1, -1 do
            core.set_node(d[i].pos, {
                name = d[i].node,
                param2 = d[i].param2
            })
        end
        fill_undo[name] = {}
        return true, S("Fill undone.")
    end
})

core.register_chatcommand("undo_clone", {
    func = function(name)
        local d = clone_undo[name]
        if not d or #d == 0 then
            return false, S("Nothing to undo.")
        end
        for i = #d, 1, -1 do
            core.set_node(d[i].pos, {
                name = d[i].node,
                param2 = d[i].param2
            })
        end
        clone_undo[name] = {}
        return true, S("Clone undone.")
    end
})

-- =========================
-- /FILL
-- =========================
core.register_chatcommand("fill", {
    params = S("<pos1> <pos2> <block> [replace|destroy|hollow|keep [list]]"),
    description = S("Fill area safely"),
    privs = {
        server = true
    },

    func = function(name, param)
        local player = core.get_player_by_name(name)
        if not player then
            return false
        end

        local args = {}
        for s in param:gmatch("%S+") do
            args[#args + 1] = s
        end

        if #args < 3 then
            return false, S("Invalid parameters")
        end

        local p1, p2, i

        if args[1] == "pos1" and args[2] == "pos2" then
            p1 = postick_get_pos(name, "pos1")
            p2 = postick_get_pos(name, "pos2")
            i = 3
        else
            p1 = parse_any_pos(player, args[1], args[2], args[3])
            p2 = parse_any_pos(player, args[4], args[5], args[6])
            i = 7
        end

        if not (p1 and p2) then
            return false, S("Invalid position")
        end

        local nodename = resolve_node_name_safe(args[i])
        if not nodename then
            return false, S("Block not found: @1", args[i])
        end

        local mode = args[i + 1] or "replace"
        local list = args[i + 2]

        local replace_target

        if mode == "replace" and list then
            replace_target = resolve_node_name_safe(list)
            if not replace_target then
                return false, S("Block not found: @1", list)
            end
        end

        local minp = vector.new(math.min(p1.x, p2.x), math.min(p1.y, p2.y), math.min(p1.z, p2.z))
        local maxp = vector.new(math.max(p1.x, p2.x), math.max(p1.y, p2.y), math.max(p1.z, p2.z))

        fill_undo[name] = {}

        local keep, negate = {}, false
        if mode == "keep" and list then
            if list:sub(1, 1) == "!" then
                negate = true
                list = list:sub(2)
            end
            for n in list:gmatch("[^,]+") do
                local rn = resolve_node_name_safe(n)
                if rn then
                    keep[rn] = true
                end
            end
        end

        for x = minp.x, maxp.x do
            for y = minp.y, maxp.y do
                for z = minp.z, maxp.z do
                    local pos = {
                        x = x,
                        y = y,
                        z = z
                    }
                    local old = core.get_node(pos)

                    if mode == "hollow" and x ~= minp.x and x ~= maxp.x and y ~= minp.y and y ~= maxp.y and z ~= minp.z and
                        z ~= maxp.z then
                        goto skip
                    end

                    if mode == "keep" and list then
                        local has = keep[old.name]
                        if (has and not negate) or (negate and not has) then
                            goto skip
                        end
                    end

                    if mode == "replace" and replace_target then
                        if old.name ~= replace_target then
                            goto skip
                        end
                    end

                    save_undo(fill_undo, name, pos, old)

                    if mode == "destroy" then
                        core.remove_node(pos)
                    else
                        core.set_node(pos, {
                            name = nodename
                        })
                    end

                    core.set_node(pos, {
                        name = nodename
                    })
                    ::skip::
                end
            end
        end

        return true, S("Fill completed with @1", nodename)
    end
})
