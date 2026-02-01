local S = core.get_translator(core.get_current_modname())

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
	privs = { give = true, interact = true },

	func = function(_, param)
		local x, y, z, nodestring =
			param:match("^([%d.-]+)[, ]*([%d.-]+)[, ]*([%d.-]+)%s+(.+)$")

		x, y, z = tonumber(x), tonumber(y), tonumber(z)

		if not (x and y and z and nodestring) then
			return false, S("Invalid parameters (see /help setblock)")
		end

		local nodename = resolve_node_name(nodestring)

		if not core.registered_nodes[nodename] then
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
-- /setblock_search (sem coordenadas)
-- =========================
core.register_chatcommand("setblock_search", {
	params = S("<search>"),
	description = S("Search block by name and cache results"),
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

		-- salvar cache (NÃO expira)
		local meta = player:get_meta()
		meta:set_string("setblock_search_results", core.serialize(results))

		-- 1 resultado → coloca direto
		if #results == 1 then
			local pos = vector.round(player:get_pos())
			core.set_node(pos, { name = results[1], param2 = 0 })
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
		local results = core.deserialize(meta:get_string("setblock_search_results"))

		if not (results and results[idx]) then
			return false, S("No cached search result found")
		end

		local pos = vector.round(player:get_pos())
		core.set_node(pos, { name = results[idx], param2 = 0 })

		return true, S("@1 placed.", results[idx])
	end,
})