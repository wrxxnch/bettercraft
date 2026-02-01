local S = core.get_translator(core.get_current_modname())

-- =========================
-- helpers para coordenadas ~
-- =========================
local function parse_coord(token, base)
    if token == "~" then
        return base
    end

    local offset = token:match("^~([%d.-]+)$")
    if offset then
        return base + tonumber(offset)
    end

    return tonumber(token)
end

-- Resolve aliases e nomes curtos
local function resolve_node_name(name)
    while core.registered_aliases[name] do
        name = core.registered_aliases[name]
    end

    if not name:find(":") then
        for regname in pairs(core.registered_nodes) do
            local short = regname:match(":(.+)$")
            if short and short == name then
                return regname
            end
        end
    end

    return name
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
-- /fill com suporte a ~
-- =========================
core.register_chatcommand("fill", {
    params = S("<x1> <y1> <z1> <x2> <y2> <z2> [block] [mode] [replace_block]"),
    description = S("Fill area (normal, hollow, replace, destroy)"),
    privs = {
        give = true,
        interact = true
    },

    func = function(name, param)
        -- quebra por espaços (permite ~)
        local P = {}
        for w in param:gmatch("%S+") do
            P[#P + 1] = w
        end

        if #P < 6 then
            return false, S("Invalid parameters (need 6 coordinates)")
        end

        local player = core.get_player_by_name(name)
        if not player then
            return false
        end

        local ppos = vector.round(player:get_pos())

        local x1 = parse_coord(P[1], ppos.x)
        local y1 = parse_coord(P[2], ppos.y)
        local z1 = parse_coord(P[3], ppos.z)
        local x2 = parse_coord(P[4], ppos.x)
        local y2 = parse_coord(P[5], ppos.y)
        local z2 = parse_coord(P[6], ppos.z)

        if not (x1 and y1 and z1 and x2 and y2 and z2) then
            return false, S("Invalid coordinates")
        end

        -- argumentos opcionais
        local block = P[7]
        local mode = P[8] or "normal"
        local replace_block = P[9]

        -- determinar bloco principal
        local nodename
        if block and block ~= "" then
            nodename = resolve_node_name(block)
            if not core.registered_nodes[nodename] then
                return false, S("Unknown block: @1", block)
            end
        else
            -- usar cache do setblock_search
            local meta = player:get_meta()
            local results = core.deserialize(meta:get_string("setblock_search_results"))
            if not results or not results[1] then
                return false, S("No cached block found. Use /setblock_search.")
            end
            nodename = results[1]
        end

        local replace_name
        if mode == "replace" then
            if not replace_block then
                return false, S("Replace mode requires a block to replace")
            end
            replace_name = resolve_node_name(replace_block)
            if not core.registered_nodes[replace_name] then
                return false, S("Unknown replace block: @1", replace_block)
            end
        end

        local minp = {
            x = math.min(x1, x2),
            y = math.min(y1, y2),
            z = math.min(z1, z2)
        }
        local maxp = {
            x = math.max(x1, x2),
            y = math.max(y1, y2),
            z = math.max(z1, z2)
        }

        for x = minp.x, maxp.x do
            for y = minp.y, maxp.y do
                for z = minp.z, maxp.z do
                    local is_edge = x == minp.x or x == maxp.x or y == minp.y or y == maxp.y or z == minp.z or z ==
                                        maxp.z

                    local pos = {
                        x = x,
                        y = y,
                        z = z
                    }
                    local node = core.get_node(pos)

                    if mode == "hollow" then
                        if is_edge then
                            core.set_node(pos, {
                                name = nodename,
                                param2 = 0
                            })
                        else
                            core.set_node(pos, {
                                name = "air",
                                param2 = 0
                            })
                        end

                        -- ======================
                        -- KEEP (apenas ar)
                        -- ======================
                    elseif mode == "keep" and not replace_name then
                        if node.name == "air" then
                            core.set_node(pos, {
                                name = nodename
                            })
                        end

                        -- ======================
                        -- KEEP específico
                        -- ======================
                    elseif mode == "keep" and replace_name then
                        if node.name == replace_name then
                            core.set_node(pos, {
                                name = nodename
                            })
                        end

                    elseif mode == "replace" then
                        if node.name == replace_name then
                            core.set_node(pos, {
                                name = nodename,
                                param2 = 0
                            })
                        end

                    elseif mode == "destroy" then
                        core.remove_node(pos)
                        core.set_node(pos, {
                            name = nodename,
                            param2 = 0
                        })

                    else -- normal
                        core.set_node(pos, {
                            name = nodename,
                            param2 = 0
                        })
                    end
                end
            end
        end

        return true, S("Filled area from (@1,@2,@3) to (@4,@5,@6) with @7.", minp.x, minp.y, minp.z, maxp.x, maxp.y,
            maxp.z, nodename)
    end
})

