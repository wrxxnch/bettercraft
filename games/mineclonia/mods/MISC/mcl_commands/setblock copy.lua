local S = core.get_translator(core.get_current_modname())

core.register_chatcommand("setblock", {
	params = S("<X> <Y> <Z> <node>"),
	description = S("Set node at given position"),
	privs = {give = true, interact = true},

	func = function(_, param)
		local p = {}
		local nodestring

		p.x, p.y, p.z, nodestring =
			param:match("^([%d.-]+)[, ] *([%d.-]+)[, ] *([%d.-]+) +(.+)$")

		p.x, p.y, p.z = tonumber(p.x), tonumber(p.y), tonumber(p.z)

		if not (p.x and p.y and p.z and nodestring) then
			return false, S("Invalid parameters (see /help setblock)")
		end

		local nodename = nodestring

		-- Se não tiver namespace, tenta mcl_core:
		if not nodename:find(":") then
			if core.registered_nodes["mcl_core:" .. nodename] then
				nodename = "mcl_core:" .. nodename
			end
		end

		if not core.registered_nodes[nodename] then
			return false, S("Unknown block: @1"):gsub("@1", nodestring)
		end

		core.set_node(p, { name = nodename })
		return true, S("@1 placed."):gsub("@1", nodename)
	end,
})
