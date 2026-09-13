local S = minetest.get_translator(minetest.get_current_modname())
local C = minetest.colorize
local F = minetest.formspec_escape

local function refresh_cartography(pos, player)
	local formspec = table.concat({
		"formspec_version[4]",
		"size[11.75,10.425]",
		"label[0.375,0.375;" .. F(C(mcl_formspec.label_color, S("Cartography Table"))) .. "]",

		-- First input slot
		mcl_formspec.get_itemslot_bg_v4(1, 0.75, 1, 1),
		"list[nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ";input;1,0.75;1,1;1]",

		-- Cross icon
		"image[1,2;1,1;mcl_anvils_inventory_cross.png]",

		-- Second input slot
		mcl_formspec.get_itemslot_bg_v4(1, 3.25, 1, 1),
		"list[nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ";input;1,3.25;1,1;]",

		-- Arrow
		"image[2.7,2;2,1;mcl_anvils_inventory_arrow.png]",

		-- Output slot
		mcl_formspec.get_itemslot_bg_v4(9.75, 2, 1, 1, 0.2),
		"list[nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ";output;9.75,2;1,1;]",

		-- Player inventory
		"label[0.375,4.7;" .. F(C(mcl_formspec.label_color, S("Inventory"))) .. "]",
		mcl_formspec.get_itemslot_bg_v4(0.375, 5.1, 9, 3),
		"list[current_player;main;0.375,5.1;9,3;9]",

		mcl_formspec.get_itemslot_bg_v4(0.375, 9.05, 9, 1),
		"list[current_player;main;0.375,9.05;9,1;]",
	})

	local inv = minetest.get_meta(pos):get_inventory()
	local map = inv:get_stack("input", 2)
	local texture = mcl_maps.load_map_item(map)
	local marker = inv:get_stack("input", 1)
	local marker_name = marker:get_name()
	local base_map_bg, base_map_img = "image[5.125,0.5;4,4;mcl_maps_map_background.png]", ""

	if texture then base_map_img = "image[5.375,0.75;3.5,3.5;" .. texture .. "]" end

	if map and texture and marker:is_empty() then
		formspec = formspec .. table.concat{base_map_bg, base_map_img}
	elseif map and texture and marker then
		if marker_name == "mcl_maps:empty_map" then
			formspec = formspec .. table.concat({
				"image[6.125,0.5;3,3;mcl_maps_map_background.png]",
				"image[6.375,0.75;2.5,2.5;" .. texture .. "]",
				"image[5.125,1.5;3,3;mcl_maps_map_background.png]",
				"image[5.375,1.75;2.5,2.5;" .. texture .. "]"
			})

			inv:set_stack("output", 1, map)
		elseif marker_name == "mcl_panes:pane_natural_flat" then
			formspec = formspec .. table.concat({
				base_map_bg, base_map_img, "image[8.375,3.75;0.5,0.5;mcl_core_barrier.png]"
			})
		--elseif marker_name == "mcl_core:paper" then
		end
	else
		formspec = formspec .. base_map_bg
	end

	minetest.show_formspec(player:get_player_name(), "mcl_cartography_table", formspec)
end

local allowed_to_put = {
	--["mcl_core:paper"] = true, Requires missing features with increasing map size
	["mcl_maps:empty_map"] = true,
	["mcl_panes:pane_natural_flat"] = true
}

minetest.register_node("mcl_cartography_table:cartography_table", {
	description = S("Cartography Table"),
	_tt_help = S("Used to create or copy maps"),
	_doc_items_longdesc = S("Is used to create or copy maps for use.."),
	tiles = {
		"cartography_table_top.png", "cartography_table_side3.png",
		"cartography_table_side3.png", "cartography_table_side2.png",
		"cartography_table_side3.png", "cartography_table_side1.png"
	},
	is_ground_content = false,
	groups = {axey = 1, handy = 1, deco_block = 1, material_wood = 1},
	_mcl_blast_resistance = 2.5,
	_mcl_hardness = 2.5,
	_mcl_burntime = 15,
	on_construct = function(pos)
		local inv = minetest.get_meta(pos):get_inventory()
		inv:set_size("input", 2)
		inv:set_size("output", 1)
	end,
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		if minetest.is_protected(pos, player:get_player_name()) or listname == "output" then
			return 0
		else
			if index == 2 and not stack:get_name():find("filled_map") then return 0 end
			if index == 1 and not allowed_to_put[stack:get_name()] then return 0 end
			return stack:get_count()
		end
	end,
	on_metadata_inventory_put = function(pos, _, _, _, player)
		refresh_cartography(pos, player)
	end,
	on_metadata_inventory_take = function(pos, listname, _, _, player)
		local inv = minetest.get_meta(pos):get_inventory()
		if listname == "output" then
			local marker = inv:get_stack("input", 1)
			marker:take_item()
			inv:set_stack("input", 1, marker)
		else
			inv:set_stack("output", 1, "")
		end
		refresh_cartography(pos, player)
	end,
	allow_metadata_inventory_move = function() return 0 end,
	allow_metadata_inventory_take = function(pos, _, _, stack, player)
		return 0 and minetest.is_protected(pos, player:get_player_name()) or stack:get_count()
	end,
	on_rightclick = function(pos, _, player, _)
		if not player:get_player_control().sneak then refresh_cartography(pos, player) end
	end,
	after_dig_node = mcl_util.drop_items_from_meta_container({"input"}),
})

minetest.register_craft({
	output = "mcl_cartography_table:cartography_table",
	recipe = {
		{ "mcl_core:paper", "mcl_core:paper", "" },
		{ "group:wood", "group:wood", "" },
		{ "group:wood", "group:wood", "" },
	}
})
