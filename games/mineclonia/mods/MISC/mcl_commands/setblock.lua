local S = core.get_translator(core.get_current_modname())

-- =========================
-- Utils
-- =========================
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
		if v:sub(1,1) == "~" then
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
	privs = { give = true, interact = true },

	func = function(name)
		local data = fill_undo[name]
		if not data or #data == 0 then
			return false, "Nothing to undo."
		end

		for i = #data, 1, -1 do
			local d = data[i]
			core.set_node(d.pos, { name = d.node })
		end

		fill_undo[name] = {}
		return true, "Fill undone."
	end,
})

-- =========================
-- /fill
-- =========================
core.register_chatcommand("fill", {
	params = "<x1> <y1> <z1> <x2> <y2> <z2> <block> [destroy|hollow|keep|replace] [filter]",
	description = "Fill an area",
	privs = { give = true, interact = true },

	func = function(name, param)
		local P = {}
		for w in param:gmatch("%S+") do
			P[#P+1] = w
		end

		if #P < 7 then
			return false, "Invalid parameters."
		end

		local player = core.get_player_by_name(name)
		if not player then return false end

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
				if part:sub(1,1) == "!" then
					keep_negate[resolve_node_name(part:sub(2))] = true
				else
					keep_list[resolve_node_name(part)] = true
				end
			end
		end

		local minp = vector.new(
			math.min(p1.x, p2.x),
			math.min(p1.y, p2.y),
			math.min(p1.z, p2.z)
		)

		local maxp = vector.new(
			math.max(p1.x, p2.x),
			math.max(p1.y, p2.y),
			math.max(p1.z, p2.z)
		)

		fill_undo[name] = {}

		for x = minp.x, maxp.x do
		for y = minp.y, maxp.y do
		for z = minp.z, maxp.z do
			local pos = {x=x,y=y,z=z}
			local node = core.get_node(pos)

			-- hollow
			if mode == "hollow" then
				if x ~= minp.x and x ~= maxp.x and
				   y ~= minp.y and y ~= maxp.y and
				   z ~= minp.z and z ~= maxp.z then
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
			core.set_node(pos, { name = nodename })

			::continue::
		end end end

		return true, "Filled."
	end,
})
