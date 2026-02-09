local modname = core.get_current_modname()
local modpath = core.get_modpath(modname)
local S = core.get_translator(modname)

mcl_flowers = {}
mcl_flowers.registered_simple_flowers = {}
-- Simple flower template
local smallflowerlongdesc = S("This is a small flower. Small flowers are mainly used for dye production and can also be potted.")
mcl_flowers.plant_usage_help = S("It can only be placed on a block on which it would also survive.")

function mcl_flowers.on_bone_meal(_, _, _ , pos, n)
	if n.name == "mcl_flowers:rose_bush" or n.name == "mcl_flowers:rose_bush_top" then
		core.add_item(pos, "mcl_flowers:rose_bush")
		return true
	elseif n.name == "mcl_flowers:peony" or n.name == "mcl_flowers:peony_top" then
		core.add_item(pos, "mcl_flowers:peony")
		return true
	elseif n.name == "mcl_flowers:lilac" or n.name == "mcl_flowers:lilac_top" then
		core.add_item(pos, "mcl_flowers:lilac")
		return true
	elseif n.name == "mcl_flowers:sunflower" or n.name == "mcl_flowers:sunflower_top" then
		core.add_item(pos, "mcl_flowers:sunflower")
		return true
	elseif n.name == "mcl_flowers:tallgrass" then
		-- Tall Grass: Grow into double tallgrass
		local toppos = { x=pos.x, y=pos.y+1, z=pos.z }
		local topnode = core.get_node(toppos)
		if core.registered_nodes[topnode.name].buildable_to then
			core.set_node(pos, { name = "mcl_flowers:double_grass", param2 = n.param2 })
			core.set_node(toppos, { name = "mcl_flowers:double_grass_top", param2 = n.param2 })
			return true
		end
	elseif n.name == "mcl_flowers:fern" then
		-- Fern: Grow into large fern
		local toppos = { x=pos.x, y=pos.y+1, z=pos.z }
		local topnode = core.get_node(toppos)
		if core.registered_nodes[topnode.name].buildable_to then
			core.set_node(pos, { name = "mcl_flowers:double_fern", param2 = n.param2 })
			core.set_node(toppos, { name = "mcl_flowers:double_fern_top", param2 = n.param2 })
			return true
		end
	end
	return false
end

local scan_area = 9
local spawn_on = { "mcl_core:dirt", "group:grass_block" }

function mcl_flowers.on_bone_meal_simple(_, _, _, pos, n)
	if n.name ~= "mcl_flowers:wither_rose" then
		local nn = core.find_nodes_in_area_under_air(
			vector.offset(pos, -scan_area, -3, -scan_area),
			vector.offset(pos, scan_area, 3, scan_area),
			spawn_on
		)

		local any_placed = false
		if next(nn) ~= nil then
			table.shuffle(nn)
			for i = 1, math.random(1, math.min(14, #nn)) do
				if core.add_node(vector.offset(nn[i], 0, 1, 0), { name = n.name }) then
					any_placed = true
				end
			end
			return any_placed
		end
	end

	return false
end

function mcl_flowers.get_palette_color_from_pos(pos)
	return mcl_util.get_pos_p2 (pos)
end

-- on_place function for flowers
mcl_flowers.on_place_flower = mcl_util.generate_on_place_plant_function(function(pos, _, itemstack)
	local below = {x=pos.x, y=pos.y-1, z=pos.z}
	local soil_node = core.get_node_or_nil(below)
	if not soil_node then return false end

	local has_palette = core.registered_nodes[itemstack:get_name()].palette ~= nil
	local colorize
	if has_palette then
		colorize = mcl_flowers.get_palette_color_from_pos(pos)
	end
	if not colorize then
		colorize = 0
	end

--[[	Placement requirements:
	* Dirt, grass or moss block
	* If not flower, also allowed on podzol and coarse dirt
	* Light level >= 8 at any time or exposed to sunlight at day
]]
	local light_night = core.get_node_light(pos, 0.0)
	local light_day = core.get_node_light(pos, 0.5)
	local light_ok = false
	if (light_night and light_night >= 8) or (light_day and light_day >= core.LIGHT_MAX) then
		light_ok = true
	end
	if itemstack:get_name() == "mcl_flowers:wither_rose" and (  core.get_item_group(soil_node.name, "grass_block") > 0 or soil_node.name == "mcl_core:dirt" or soil_node.name == "mcl_core:coarse_dirt" or soil_node.name == "mcl_mud:mud" or soil_node.name == "mcl_lush_caves:moss" or soil_node.name == "mcl_pale_oak:pale_moss" or soil_node.name == "mcl_nether:netherrack" or core.get_item_group(soil_node.name, "soul_block") > 0  ) then
		return true,colorize
	end
	local is_flower = core.get_item_group(itemstack:get_name(), "flower") == 1
	local ok = (soil_node.name == "mcl_core:dirt" or core.get_item_group(soil_node.name, "grass_block") == 1 or soil_node.name == "mcl_lush_caves:moss" or soil_node.name == "mcl_pale_oak:pale_moss" or (not is_flower and (soil_node.name == "mcl_core:coarse_dirt" or soil_node.name == "mcl_core:podzol" or soil_node.name == "mcl_core:podzol_snow"))) and light_ok
	return ok, colorize
end)

function mcl_flowers.register_simple_flower(name, def)
	local newname = "mcl_flowers:"..name
	if not def._mcl_silk_touch_drop then def._mcl_silk_touch_drop = nil end
	if not def.drop then def.drop = newname end
	mcl_flowers.registered_simple_flowers[newname] = {
		name=name,
		desc=def.desc,
		image=def.image,
		simple_selection_box=def.simple_selection_box,
	}
	core.register_node(":"..newname, {
		description = def.desc,
		_doc_items_longdesc = smallflowerlongdesc,
		_doc_items_usagehelp = mcl_flowers.plant_usage_help,
		drawtype = "plantlike",
		waving = 1,
		tiles = { def.image },
		inventory_image = def.image,
		wield_image = def.image,
		sunlight_propagates = true,
		paramtype = "light",
		walkable = false,
		drop = def.drop,
		groups = {
			attached_node = 1, deco_block = 1, dig_by_piston = 1, dig_immediate = 3,
			dig_by_water = 1, destroy_by_lava_flow = 1, enderman_takable = 1,
			plant = 1, flower = 1, place_flowerlike = 1, non_mycelium_plant = 1,
			flammable = 2, fire_encouragement = 60, fire_flammability = 100,
			compostability = 65, unsticky = 1
		},
		sounds = mcl_sounds.node_sound_leaves_defaults(),
		node_placement_prediction = "",
		on_place = mcl_flowers.on_place_flower,
		selection_box = {
			type = "fixed",
			fixed = def.selection_box,
		},
		_mcl_silk_touch_drop = def._mcl_silk_touch_drop,
		_on_bone_meal = mcl_flowers.on_bone_meal_simple,
		_mcl_crafting_output = def._mcl_crafting_output
	})
	if def.potted then
		mcl_flowerpots.register_potted_flower(newname, {
			name = name,
			desc = def.desc,
			image = def.image,
		})
	end
end

function mcl_flowers.register_ground_flower(name, def)
	local newname = "mcl_flowers:"..name

	core.register_craftitem(":"..newname, {
    description = def.desc,
		_doc_items_longdesc = def.longdesc,
    inventory_image = def.image,
    wield_image = def.image,
    groups = {
			craftitem = 1,
			attached_node = 1, deco_block = 1, dig_by_piston = 1, dig_immediate = 3,
			dig_by_water = 1, destroy_by_lava_flow = 1, enderman_takable = 1,
			plant = 1, flower = 1, place_flowerlike = 1, non_mycelium_plant = 1,
			flammable = 2, fire_encouragement = 60, fire_flammability = 100,
			compostability = 65, unsticky = 1
		},
		_mcl_crafting_output = def._mcl_crafting_output,

    on_place = function(itemstack, placer, pointed_thing)
			local rc = mcl_util.call_on_rightclick(itemstack, placer, pointed_thing)
			if rc then return rc end

			local pos = pointed_thing.under
			local node = core.get_node(pos)
			local above_pos = {x=pos.x, y=pos.y+1, z=pos.z}
			local above_node = core.get_node(above_pos)
			local wildflower_group = core.get_item_group(node.name, "wildflower")
			local creative = mcl_util.is_creative(placer)

			-- Swap the node in place if it's part of the progression
			local swap_map = {
				[newname.."_1"] = newname.."_2",
				[newname.."_2"] = newname.."_3",
				[newname.."_3"] = newname.."_4",
			}

			if swap_map[node.name] then
				if not creative then itemstack:take_item(1) end
				core.set_node(pos, {name = swap_map[node.name]})
			else
				local max_cycle = wildflower_group > 0 and wildflower_group < 5
				-- If not already part of the cycle, place _1 above
				if above_node.name == "air" and not max_cycle then
					-- Only placeable on soil node
					if core.get_item_group(node.name, "soil") == 0 then
						return itemstack
					else
						if not creative then itemstack:take_item(1) end
						core.set_node(above_pos, {name = newname.."_1"})
					end
				end
			end

			return itemstack
    end,
	})

	for i = 1,4 do
		core.register_node(":"..newname.."_"..i, {
			description = def.desc,
			_doc_items_create_entry = false,
			drawtype = "mesh",
			mesh = "mcl_flowers_wildflower_"..i..".obj",
			tiles = def.tiles,
			use_texture_alpha = "clip",
			paramtype = "light",
			paramtype2 = "facedir",
			sunlight_propagates = true,
			walkable = false,
			selection_box = {type = "fixed", fixed = {-1/2, -1/2, -1/2, 1/2, -5/16, 1/2}},
			stack_max = 64,
			groups = {
				attached_node = 1, deco_block = 1, dig_by_piston = 1, dig_immediate = 3,
				dig_by_water = 1, destroy_by_lava_flow = 1, enderman_takable = 1,
				plant = 1, flower = 1, wildflower=i, place_flowerlike = 1, non_mycelium_plant = 1,
				flammable = 2, fire_encouragement = 60, fire_flammability = 100,
				compostability = 65, unsticky = 1,
				not_in_creative_inventory = 1,
				not_in_craft_guide = 1
			},
			sounds = mcl_sounds.node_sound_leaves_defaults(),
			drop = newname.." "..i,
			node_placement_prediction = "",
			_on_bone_meal = mcl_flowers.on_bone_meal_simple,
		})
	end
end

local tpl_large_plant_top = {
	drawtype = "plantlike",
	_doc_items_create_entry = true,
	_doc_items_usagehelp = mcl_flowers.plant_usage_help,
	sunlight_propagates = true,
	paramtype = "light",
	walkable = false,
	sounds = mcl_sounds.node_sound_leaves_defaults(),
	_on_bone_meal = mcl_flowers.on_bone_meal,
}

local tpl_large_plant_bottom = table.merge(tpl_large_plant_top, {
	groups = {
		compostability = 65, deco_block = 1, dig_by_water = 1, destroy_by_lava_flow = 1,
		dig_by_piston = 1, flammable = 2, fire_encouragement = 60, fire_flammability = 100,
		plant = 1, double_plant = 1, non_mycelium_plant = 1, flower = 1, supported_node = 1
	},
	on_place = function(itemstack, placer, pointed_thing)
		-- We can only place on nodes
		if pointed_thing.type ~= "node" then
			return
		end

		local itemstring = itemstack:get_name()

		-- Call on_rightclick if the pointed node defines it
		local rc = mcl_util.call_on_rightclick(itemstack, placer, pointed_thing)
		if rc ~= nil then return rc end --check for nil explicitly to determine if on_rightclick existed

		-- Check for a floor and a space of 1×2×1
		local ptu_node = core.get_node(pointed_thing.under)
		local bottom
		if not core.registered_nodes[ptu_node.name] then
			return itemstack
		end
		if core.registered_nodes[ptu_node.name].buildable_to then
			bottom = pointed_thing.under
		else
			bottom = pointed_thing.above
		end
		if not core.registered_nodes[core.get_node(bottom).name] then
			return itemstack
		end
		local top = { x = bottom.x, y = bottom.y + 1, z = bottom.z }
		local bottom_buildable = core.registered_nodes[core.get_node(bottom).name].buildable_to
		local top_buildable = core.registered_nodes[core.get_node(top).name].buildable_to
		local floor = core.get_node({x=bottom.x, y=bottom.y-1, z=bottom.z})
		if not core.registered_nodes[floor.name] then
			return itemstack
		end

		local light_night = core.get_node_light(bottom, 0.0)
		local light_day = core.get_node_light(bottom, 0.5)
		local light_ok = false
		if (light_night and light_night >= 8) or (light_day and light_day >= core.LIGHT_MAX) then
			light_ok = true
		end
		local is_flower = core.get_item_group(floor.name, "flower") > 0

		-- Placement rules:
		-- * Allowed on dirt, grass or moss block
		-- * If not a flower, also allowed on podzol and coarse dirt
		-- * Only with light level >= 8
		-- * Only if two enough space
		if (floor.name == "mcl_core:dirt" or core.get_item_group(floor.name, "grass_block") == 1 or floor.name == "mcl_lush_caves:moss" or (not is_flower and (floor.name == "mcl_core:coarse_dirt" or floor.name == "mcl_core:podzol" or floor.name == "mcl_core:podzol_snow"))) and bottom_buildable and top_buildable and light_ok then
			local param2
			local def = core.registered_nodes[floor.name]
			if def and def.paramtype2 == "color" then
				param2 = mcl_flowers.get_palette_color_from_pos(bottom)
			end
			-- Success! We can now place the flower
			core.sound_play(core.registered_nodes[itemstring].sounds.place, {pos = bottom, gain=1}, true)
			core.set_node(bottom, {name=itemstring, param2=param2})
			core.set_node(top, {name=itemstring.."_top", param2=param2})
			if not mcl_util.is_creative(placer) then
				itemstack:take_item()
			end
		end
		return itemstack
	end,
	after_destruct = function(pos, oldnode)
		-- Remove top half of flower (if it exists)
		local bottom = pos
		local top = { x = bottom.x, y = bottom.y + 1, z = bottom.z }
		if core.get_node(bottom).name ~= oldnode.name and core.get_node(top).name == oldnode.name.."_top" then
			core.remove_node(top)
		end
	end,
})

function mcl_flowers.add_large_plant(name, def)
	def.bottom =  def.bottom or {}
	def.bottom.groups = table.merge(tpl_large_plant_bottom.groups, def.bottom.groups or {})
	def.top = def.top or {}
	def.top.groups = def.top.groups or {}

	if def.is_flower then
		table.update(def.bottom.groups, { flower = 1, place_flowerlike = 1, dig_immediate = 3 })
	else
		table.update(def.bottom.groups, { place_flowerlike = 2, handy = 1, shearsy = 1 })
	end

	table.update(def.top.groups, { not_in_creative_inventory=1, handy = 1, shearsy = 1, double_plant=2, supported_node = 1})

	if def.grass_color then
		def.bottom.paramtype2 = "color"
		def.top.paramtype2 = "color"
		def.bottom.palette = "mcl_core_palette_grass.png"
		def.top.palette = "mcl_core_palette_grass.png"
	end

	if def.bottom._doc_items_longdesc == nil and def.longdesc == nil then
		def.bottom.groups.not_in_creative_inventory = 1
		def.bottom._doc_items_create_entry = false
	end

	local selbox_radius = def.selbox_radius or 0.5
	local selbox_top_height = def.selbox_top_height or 0.5
	local inv_img = def.inv_img or def.bottom.inventory_image or (def.tiles_top and def.tiles_top[1]) or (def.top.tiles and def.top.tiles[1])
	-- Bottom
	core.register_node(":mcl_flowers:"..name, table.merge(tpl_large_plant_bottom,{
		description = def.desc,
		_doc_items_longdesc = def.longdesc,
		tiles = def.tiles_bottom,
		node_placement_prediction = "",
		inventory_image = inv_img,
		wield_image = inv_img,
		drop = "mcl_flowers:"..name,
		selection_box = {
			type = "fixed",
			fixed = { -selbox_radius, -0.5, -selbox_radius, selbox_radius, 0.5, selbox_radius },
		},
	}, def.bottom or {}))

	-- Top
	core.register_node(":mcl_flowers:"..name.."_top", table.merge(tpl_large_plant_top, {
		description = S("@1 (Top Part)", def.desc or def.bottom.description or name),
		_doc_items_create_entry = false,
		selection_box = {
			type = "fixed",
			fixed = { -selbox_radius, -0.5, -selbox_radius, selbox_radius, selbox_top_height, selbox_radius },
		},
		tiles = def.tiles_top,
		drop = def.bottom.drop or ( "mcl_flowers:"..name ),
		_mcl_shears_drop = def.bottom._mcl_shears_drop,
		_mcl_fortune_drop = def.bottom._mcl_fortune_drop,
		_mcl_baseitem = "mcl_flowers:"..name,
		after_destruct = function(pos, _)
			-- Remove bottom half of flower (if it exists)
			local top = pos
			local bottom = { x = top.x, y = top.y - 1, z = top.z }
			if core.get_node(top).name ~= "mcl_flowers:"..name.."_top" and core.get_node(bottom).name == "mcl_flowers:"..name then
				core.remove_node(bottom)
			end
		end,
	}, def.top))

	if def.bottom._doc_items_longdesc then
		doc.add_entry_alias("nodes", "mcl_flowers:"..name, "nodes", "mcl_flowers:"..name.."_top")
		-- If no longdesc, help alias must be added manually
	end

end

core.register_abm({
	label = "Pop out flowers",
	nodenames = {"group:flower"},
	interval = 12,
	chance = 2,
	action = function(pos, node)
		-- Ignore the upper part of double plants
		if core.get_item_group(node.name, "double_plant") == 2 then
			return
		end
		local below = core.get_node_or_nil({x=pos.x, y=pos.y-1, z=pos.z})
		if not below then
			return
		end
		-- Pop out flower if not on dirt, or grass block.
		if (below.name ~= "mcl_core:dirt"
		    and core.get_item_group(below.name, "grass_block") ~= 1
		    and below.name ~= "mcl_lush_caves:moss") then
			core.dig_node(pos)
			return
		end
	end,
})

-- Legacy support
core.register_alias("mcl_core:tallgrass", "mcl_flowers:tallgrass")

-- mcimport support: re-adds missing double_plant tops in mcimported worlds.
local mg_name = core.get_mapgen_setting("mg_name")
local mod_mcimport = core.get_modpath("mcimport")

if mod_mcimport and mg_name == "singlenode" then
	local flowernames = { "peony", "rose_bush", "lilac", "sunflower", "double_fern", "double_grass" }

	core.register_lbm({
		label = "Add double plant tops.",
		name = "mcl_flowers:double_plant_topper",
		run_at_every_load = true,
		nodenames = { "mcl_flowers:peony", "mcl_flowers:rose_bush", "mcl_flowers:lilac", "mcl_flowers:sunflower", "mcl_flowers:double_fern", "mcl_flowers:double_grass" },
		action = function(pos, node)
			for c = 1, 6 do
				local flowername = flowernames[c]
				local bottom = pos
				local top = { x = bottom.x, y = bottom.y + 1, z = bottom.z }
				if node.name == "mcl_flowers:"..flowername then
					core.set_node(top, {name = "mcl_flowers:"..flowername.."_top"})
				end
			end
		end,
	})
end

dofile(modpath.."/register.lua")

mcl_levelgen.register_levelgen_script (modpath .. "/lg_register.lua")
