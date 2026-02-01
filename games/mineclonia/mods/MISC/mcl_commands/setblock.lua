local S = core.get_translator(core.get_current_modname())

local function resolve_node_name(name)
	-- resolve aliases em cadeia (stone → mcl_core:stone)
	while core.registered_aliases[name] do
		name = core.registered_aliases[name]
	end

	-- se ainda não tiver namespace, procurar automaticamente
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
			return false, S("Unknown block: @1"):gsub("@1", nodestring)
		end

		core.set_node({ x = x, y = y, z = z }, { name = nodename })
		return true, S("@1 placed."):gsub("@1", nodename)
	end,
})
