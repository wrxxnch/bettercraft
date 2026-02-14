-- only loaded if core.settings:get_bool("mcl_cozy_sit_on_stairs")

local S = ...

mcl_player.register_player_setting("mcl_cozy:sit_on_stairs_slabs", {
	type = "boolean",
	short_desc = S("Enable sitting on stairs and slabs by right-clicking them"),
	ui_default = true,
})

local function sit(pos, node, player, _, pointed_thing)
	local wielditem = player:get_wielded_item()
	if mcl_player.get_player_setting(player, "mcl_cozy:sit_on_stairs_slabs", true) then
		return mcl_cozy.sit(pos, node, player, _, pointed_thing)
	elseif core.registered_nodes[wielditem:get_name()] then
		return core.item_place_node(wielditem, player, pointed_thing)
	elseif wielditem:get_name() == "" and core.is_creative_enabled(player:get_player_name()) then
		-- Mineclonia pickblock support
		local name = core.get_node(pointed_thing.under).name
		local stack = ItemStack(name)
		local def = stack:get_definition()
		if type(def._mcl_baseitem) == "function" then
			stack = def._mcl_baseitem(pointed_thing.under)
		elseif core.get_item_group(name, "not_in_creative_inventory") > 0 then
			if not def.drop and not def._mcl_baseitem then return end
			name = def._mcl_baseitem or def.drop
			stack = ItemStack(name)
		end
		local inv = player:get_inventory()
		stack:set_count(stack:get_stack_max())
		local istack = inv:remove_item("main", stack)
		if istack:get_count() <= 0 then
			return stack
		end
		return istack
	end
end

local function check_param2_and_sit(pos, ...)
	local param2 = core.get_node(pos).param2
	-- avoid inverted stairs
	if param2 >= 20 then return end
	return sit(pos, ...)
end

core.register_on_mods_loaded(function()
	for name, _ in pairs(core.registered_nodes) do
		-- bottom slabs
		if name:find("^mcl_stairs:slab") and not (name:find("_top$") or name:find("_double$")) then
			core.override_item(name, {
				on_rightclick = sit,
			})
		-- stairs
		elseif name:find("^mcl_stairs:stair") then
			core.override_item(name, {
				on_rightclick = check_param2_and_sit,
				_mcl_cozy_offset = vector.new(0, 0, -0.15),
			})
		end
	end
end)
