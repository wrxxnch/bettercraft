local S = core.get_translator(core.get_current_modname())

-- =========================
-- Utils
-- =========================

local function rotate_rel(pos, size, rot)
    if rot == 90 then
        return {
            x = size.z - pos.z - 1,
            y = pos.y,
            z = pos.x
        }
    elseif rot == 180 then
        return {
            x = size.x - pos.x - 1,
            y = pos.y,
            z = size.z - pos.z - 1
        }
    elseif rot == 270 then
        return {
            x = pos.z,
            y = pos.y,
            z = size.x - pos.x - 1
        }
    end
    return pos
end

local function mirror_rel(pos, size, axis)
    if axis == "x" then
        return {
            x = size.x - pos.x - 1,
            y = pos.y,
            z = pos.z
        }
    elseif axis == "y" then
        return {
            x = pos.x,
            y = size.y - pos.y - 1,
            z = pos.z
        }
    elseif axis == "z" then
        return {
            x = pos.x,
            y = pos.y,
            z = size.z - pos.z - 1
        }
    end
    return pos
end

local function rotate_facedir(fd, rot)
    if rot == 90 then
        return (fd + 1) % 4
    end
    if rot == 180 then
        return (fd + 2) % 4
    end
    if rot == 270 then
        return (fd + 3) % 4
    end
    return fd
end

local function mirror_facedir(fd, axis)
    if axis == "x" then
        return ({
            [1] = 3,
            [3] = 1,
            [0] = 0,
            [2] = 2
        })[fd] or fd
    elseif axis == "z" then
        return ({
            [0] = 2,
            [2] = 0,
            [1] = 1,
            [3] = 3
        })[fd] or fd
    end
    return fd
end

local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

local function resolve_node_name(name)
    while core.registered_aliases[name] do
        name = core.registered_aliases[name]
    end

    if not name:find(":") then
        for regname in pairs(core.registered_nodes) do
            local short = regname:match(":(.+)$")
            if short == name then
                return regname
            end
        end
    end

    return name
end

local function parse_pos(player, x, y, z)
    local p = vector.round(player:get_pos())

    local function r(v, base)
        if v:sub(1, 1) == "~" then
            return base + tonumber(v:sub(2) ~= "" and v:sub(2) or 0)
        end
        return tonumber(v)
    end

    return {
        x = r(x, p.x),
        y = r(y, p.y),
        z = r(z, p.z)
    }
end

-- =========================
-- /setblock
-- =========================
core.register_chatcommand("setblock", {
    params = S("<X> <Y> <Z> <block>"),
    description = S("Set node at given position"),
    privs = {
        give = true,
        interact = true
    },

    func = function(_, param)
        local x, y, z, nodestring = param:match("^([%d.-]+)[, ]*([%d.-]+)[, ]*([%d.-]+)%s+(.+)$")

        x, y, z = tonumber(x), tonumber(y), tonumber(z)

        if not (x and y and z and nodestring) then
            return false, S("Invalid parameters (see /help setblock)")
        end

        local nodename = resolve_node_name(nodestring)

        if not core.registered_nodes[nodename] then
            return false, S("Unknown block: @1", nodestring)
        end

        core.set_node({
            x = x,
            y = y,
            z = z
        }, {
            name = nodename,
            param2 = 0
        })

        return true, S("@1 placed.", nodename)
    end
})

-- =========================
-- /setblock_search (sem coordenadas)
-- =========================
core.register_chatcommand("setblock_search", {
    params = S("<search>"),
    description = S("Search block by name and cache results"),
    privs = {
        give = true,
        interact = true
    },

    func = function(name, param)
        if param == "" then
            return false, S("You must provide a search term")
        end

        local player = core.get_player_by_name(name)
        if not player then
            return false
        end

        local search = param:lower()
        local results = {}

        for nodename in pairs(core.registered_nodes) do
            if nodename:lower():find(search, 1, true) then
                results[#results + 1] = nodename
                if #results >= 10 then
                    break
                end
            end
        end

        if #results == 0 then
            return false, S("No blocks found for: @1", search)
        end

        -- salvar cache (NÃO expira)
        local meta = player:get_meta()
        meta:set_string("setblock_search_results", core.serialize(results))

        -- 1 resultado → coloca direto
        if #results == 1 then
            local pos = vector.round(player:get_pos())
            core.set_node(pos, {
                name = results[1],
                param2 = 0
            })
            return true, S("@1 placed and cached.", results[1])
        end

        -- múltiplos → listar
        local msg = S("Cached blocks:\n")
        for i, nodename in ipairs(results) do
            msg = msg .. i .. ": " .. nodename .. "\n"
        end
        msg = msg .. S("Use: /setblock_pick <number>")

        core.chat_send_player(name, msg)
        return true, S("Search cached. You can reuse /setblock_pick.")
    end
})

-- =========================
-- /setblock_pick 
-- =========================
core.register_chatcommand("setblock_pick", {
    params = S("<number>"),
    description = S("Pick cached block and place it at your position"),
    privs = {
        give = true,
        interact = true
    },

    func = function(name, param)
        local idx = tonumber(param)
        if not idx then
            return false, S("Invalid number")
        end

        local player = core.get_player_by_name(name)
        if not player then
            return false
        end

        local meta = player:get_meta()
        local results = core.deserialize(meta:get_string("setblock_search_results"))

        if not (results and results[idx]) then
            return false, S("No cached search result found")
        end

        local pos = vector.round(player:get_pos())
        core.set_node(pos, {
            name = results[idx],
            param2 = 0
        })

        return true, S("@1 placed.", results[idx])
    end
})

-- =========================
-- UNDO por jogador
-- =========================
local fill_undo = {}

local function save_undo(playername, pos, node)
    fill_undo[playername] = fill_undo[playername] or {}
    table.insert(fill_undo[playername], {
        pos = vector.new(pos),
        node = node.name
    })
end

core.register_chatcommand("undo_fill", {
    description = "Undo last /fill",
    privs = {
        give = true,
        interact = true
    },

    func = function(name)
        local data = fill_undo[name]
        if not data or #data == 0 then
            return false, "Nothing to undo."
        end

        for i = #data, 1, -1 do
            local d = data[i]
            core.set_node(d.pos, {
                name = d.node
            })
        end

        fill_undo[name] = {}
        return true, "Fill undone."
    end
})

-- =========================
-- /fill
-- =========================
core.register_chatcommand("fill", {
    params = "<x1> <y1> <z1> <x2> <y2> <z2> <block> [destroy|hollow|keep|replace] [filter]",
    description = "Fill an area",
    privs = {
        give = true,
        interact = true
    },

    func = function(name, param)
        local P = {}
        for w in param:gmatch("%S+") do
            P[#P + 1] = w
        end

        if #P < 7 then
            return false, "Invalid parameters."
        end

        local player = core.get_player_by_name(name)
        if not player then
            return false
        end

        local p1 = parse_pos(player, P[1], P[2], P[3])
        local p2 = parse_pos(player, P[4], P[5], P[6])

        local nodename = resolve_node_name(P[7])
        if not core.registered_nodes[nodename] then
            return false, "Unknown block."
        end

        local mode = P[8] or "replace"
        local filter = P[9]

        -- KEEP PARSER
        local keep_list, keep_negate
        if mode == "keep" and filter then
            keep_list = {}
            keep_negate = {}

            for part in filter:gmatch("[^,]+") do
                part = trim(part)
                if part:sub(1, 1) == "!" then
                    keep_negate[resolve_node_name(part:sub(2))] = true
                else
                    keep_list[resolve_node_name(part)] = true
                end
            end
        end

        local minp = vector.new(math.min(p1.x, p2.x), math.min(p1.y, p2.y), math.min(p1.z, p2.z))

        local maxp = vector.new(math.max(p1.x, p2.x), math.max(p1.y, p2.y), math.max(p1.z, p2.z))

        fill_undo[name] = {}

        for x = minp.x, maxp.x do
            for y = minp.y, maxp.y do
                for z = minp.z, maxp.z do
                    local pos = {
                        x = x,
                        y = y,
                        z = z
                    }
                    local node = core.get_node(pos)

                    -- hollow
                    if mode == "hollow" then
                        if x ~= minp.x and x ~= maxp.x and y ~= minp.y and y ~= maxp.y and z ~= minp.z and z ~= maxp.z then
                            goto continue
                        end
                    end

                    -- destroy
                    if mode == "destroy" then
                        save_undo(name, pos, node)
                        core.remove_node(pos)
                        goto continue
                    end

                    -- replace
                    if mode == "replace" and filter then
                        if node.name ~= resolve_node_name(filter) then
                            goto continue
                        end
                    end

                    -- keep
                    if mode == "keep" then
                        if keep_negate and keep_negate[node.name] then
                            goto continue
                        end
                        if keep_list and not keep_list[node.name] then
                            goto continue
                        end
                        if not keep_list and node.name ~= "air" then
                            goto continue
                        end
                    end

                    save_undo(name, pos, node)
                    core.set_node(pos, {
                        name = nodename
                    })

                    ::continue::
                end
            end
        end

        return true, "Filled."
    end
})
-- =========================
-- UNDO CLONE
-- =========================
local clone_undo = {}

core.register_chatcommand("undo_clone", {
    description = "Undo last /clone",
    privs = {
        give = true,
        interact = true
    },

    func = function(name)
        local data = clone_undo[name]
        if not data or #data == 0 then
            return false, "Nothing to undo."
        end

        for i = #data, 1, -1 do
            local d = data[i]
            core.set_node(d.pos, {
                name = d.node
            })
        end

        clone_undo[name] = {}
        return true, "Clone undone."
    end
})

-- =========================
-- /clone
-- =========================
core.register_chatcommand("clone", {
    params = "<x1> <y1> <z1> <x2> <y2> <z2> <dx> <dy> <dz> [replace|masked|filtered|keep|move] [filter]",
    description = "Clone a region to another location",
    privs = {
        give = true,
        interact = true
    },

    func = function(name, param)
        local P = {}
        for w in param:gmatch("%S+") do
            P[#P + 1] = w
        end

        if #P < 9 then
            return false, "Invalid parameters."
        end

        local player = core.get_player_by_name(name)
        if not player then
            return false
        end

        local p1 = parse_pos(player, P[1], P[2], P[3])
        local p2 = parse_pos(player, P[4], P[5], P[6])
        local dest = parse_pos(player, P[7], P[8], P[9])

        local mode = P[10] or "replace"
        local filter = P[11]

        -- keep parser
        local keep_list, keep_negate
        if mode == "keep" and filter then
            keep_list = {}
            keep_negate = {}
            for part in filter:gmatch("[^,]+") do
                part = trim(part)
                if part:sub(1, 1) == "!" then
                    keep_negate[resolve_node_name(part:sub(2))] = true
                else
                    keep_list[resolve_node_name(part)] = true
                end
            end
        end

        local minp = vector.new(math.min(p1.x, p2.x), math.min(p1.y, p2.y), math.min(p1.z, p2.z))

        local maxp = vector.new(math.max(p1.x, p2.x), math.max(p1.y, p2.y), math.max(p1.z, p2.z))

        local size = vector.add(vector.subtract(maxp, minp), 1)
        clone_undo[name] = {}

        -- cache origem
        local buffer = {}

        for x = minp.x, maxp.x do
            for y = minp.y, maxp.y do
                for z = minp.z, maxp.z do
                    local pos = {
                        x = x,
                        y = y,
                        z = z
                    }
                    local node = core.get_node(pos)
                    buffer[#buffer + 1] = {
                        rel = vector.subtract(pos, minp),
                        node = node.name,
                        param2 = node.param2
                    }

                end
            end
        end

        -- aplicar
        for _, data in ipairs(buffer) do
            local target = vector.add(dest, data.rel)
            local old = core.get_node(target)

            -- masked
            if mode == "masked" and data.node == "air" then
                goto continue
            end

            -- filtered
            if mode == "filtered" and filter then
                if data.node ~= resolve_node_name(filter) then
                    goto continue
                end
            end

            -- keep
            if mode == "keep" then
                if keep_negate and keep_negate[old.name] then
                    goto continue
                end
                if keep_list and not keep_list[old.name] then
                    goto continue
                end
                if not keep_list and old.name ~= "air" then
                    goto continue
                end
            end

            local rotate, mirror

            if mode == "rotate" then
                rotate = tonumber(filter)
                if rotate ~= 90 and rotate ~= 180 and rotate ~= 270 then
                    return false, "Rotation must be 90, 180 or 270"
                end
                mode = "replace"
                filter = nil
            end

            if mode == "mirror" then
                mirror = filter
                if mirror ~= "x" and mirror ~= "y" and mirror ~= "z" then
                    return false, "Mirror axis must be x, y or z"
                end
                mode = "replace"
                filter = nil
            end

            save_undo(name, target, old)
            core.set_node(target, {
                name = data.node
            })

            ::continue::
        end

        -- move
        if mode == "move" then
            for _, data in ipairs(buffer) do
                local src = vector.add(minp, data.rel)
                save_undo(name, src, core.get_node(src))
                core.remove_node(src)
            end
        end

        return true, "Cloned."
    end
})

