-- selectors.lua
local S = minetest.get_translator("selectors")

local selectors = {}

-- Helper to get entity type classification
local function get_entity_type(obj)
	if obj:is_player() then
		return "player"
	end
	local lua_entity = obj:get_luaentity()
	if not lua_entity then
		return "unknown"
	end
	
	local name = lua_entity.name
	if name == "__builtin:item" then
		return "item"
	end
	
	local groups = lua_entity.groups or {}
	if groups.monster or name:find("monster") or name:find("zombie") then
		return "monster"
	end
	if groups.passive or groups.animal or name:find("animal") or name:find("sheep") then
		return "passive"
	end
	
	return name
end

-- Main function to resolve @a, @e, etc.
function selectors.resolve(caller_name, param_str)
	local selector, args_str = param_str:match("(@[ae])%[(.*)%]")
	if not selector then
		selector = param_str:match("(@[ae])")
		args_str = ""
	end
	
	if not selector then
		-- Not a selector, return as is (could be a player name)
		return {param_str}
	end
	
	local caller = minetest.get_player_by_name(caller_name)
	local caller_pos = caller and caller:get_pos()
	
	local targets = {}
	local candidates = {}
	
	if selector == "@a" then
		for _, p in ipairs(minetest.get_connected_players()) do
			table.insert(candidates, p)
		end
	elseif selector == "@e" then
		-- For @e, we use a large radius around the caller or origin
		local pos = caller_pos or {x=0, y=0, z=0}
		candidates = minetest.get_objects_inside_radius(pos, 500)
	end
	
	-- Parse filters
	local filters = {}
	for pair in args_str:gmatch("([^,]+)") do
		local k, v = pair:match("([^=]+)=([^=]+)")
		if k and v then
			filters[k:trim()] = v:trim()
		end
	end
	
	for _, obj in ipairs(candidates) do
		local keep = true
		
		-- Radius filter
		local r = tonumber(filters.r or filters.radius)
		if r and caller_pos then
			local pos = obj:get_pos()
			if pos and vector.distance(caller_pos, pos) > r then
				keep = false
			end
		end
		
		-- Type filter
		local t = filters.type
		if t then
			local obj_type = get_entity_type(obj)
			if t == "monster" then
				if obj_type ~= "monster" then keep = false end
			elseif t == "item" then
				if obj_type ~= "item" then keep = false end
			elseif t == "passive" then
				if obj_type ~= "passive" then keep = false end
			else
				if not obj_type:find(t) then keep = false end
			end
		end
		
		if keep then
			table.insert(targets, obj)
		end
	end
	
	return targets
end

return selectors
