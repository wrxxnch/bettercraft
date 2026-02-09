local S = core.get_translator(core.get_current_modname())

-- =========================
-- Resolve aliases e nomes curtos
-- =========================
local function resolve_node_name_safe(name)
	if not name or name == "" then
		return nil
	end

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

	if core.registered_nodes[name] then
		return name
	end

	return nil
end

-- =========================
-- /setblock
-- =========================
core.register_chatcommand("setblock", {
	params = S("<X> <Y> <Z> <block>"),
	description = S("Set node at given position"),
	privs = { give = true, interact = true },

	func = function(_, param)
		local x, y, z, nodestring =
			param:match("^([%d.-]+)[, ]*([%d.-]+)[, ]*([%d.-]+)%s+(.+)$")

		x, y, z = tonumber(x), tonumber(y), tonumber(z)

		if not (x and y and z and nodestring) then
			return false, S("Invalid parameters (see /help setblock)")
		end

		local nodename = resolve_node_name_safe(nodestring)
		if not nodename then
			return false, S("Unknown block: @1", nodestring)
		end

		core.set_node(
			{ x = x, y = y, z = z },
			{ name = nodename, param2 = 0 }
		)

		return true, S("@1 placed.", nodename)
	end,
})

-- =========================
-- /setblock_search
-- =========================
core.register_chatcommand("setblock_search", {
	params = S("<search>"),
	description = S("Search blocks by name and cache results"),
	privs = { give = true, interact = true },

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

		-- cache por jogador
		local meta = player:get_meta()
		meta:set_string("setblock_search_results", core.serialize(results))

		-- resultado único → coloca direto
		if #results == 1 then
			local pos = vector.round(player:get_pos())
			core.set_node(pos, { name = results[1], param2 = 0 })
			return true, S("@1 placed and cached.", results[1])
		end

		-- múltiplos resultados → listar
		local msg = S("Cached blocks:\n")
		for i, nodename in ipairs(results) do
			msg = msg .. i .. ": " .. nodename .. "\n"
		end
		msg = msg .. S("Use: /setblock_pick <number>")

		core.chat_send_player(name, msg)
		return true, S("Search cached.")
	end,
})

-- =========================
-- /setblock_pick
-- =========================
core.register_chatcommand("setblock_pick", {
	params = S("<number>"),
	description = S("Pick cached block and place it at your position"),
	privs = { give = true, interact = true },

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
		local data = meta:get_string("setblock_search_results")
		if data == "" then
			return false, S("No cached search results")
		end

		local results = core.deserialize(data)
		if not (results and results[idx]) then
			return false, S("Invalid cached index")
		end

		local pos = vector.round(player:get_pos())
		core.set_node(pos, { name = results[idx], param2 = 0 })

		return true, S("@1 placed.", results[idx])
	end,
})



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

