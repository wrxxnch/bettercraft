core.register_node("mcl_lanterns:gold_chain", {
	description = "Metallic Gold Chain",
	_doc_items_longdesc = "A highly reflective and metallic golden chain, crafted for a premium look.",
	inventory_image = "mcl_lanterns_gold_chain_inv.png",
	tiles = {"mcl_lanterns_gold_chain.png"},
	drawtype = "mesh",
	paramtype = "light",
	paramtype2 = "facedir",
	use_texture_alpha = "clip",
	mesh = "mcl_lanterns_chain.obj",
	is_ground_content = false,
	sunlight_propagates = true,
	collision_box = {
		type = "fixed",
		fixed = {
			{-0.0625, -0.5, -0.0625, 0.0625, 0.5, 0.0625},
		}
	},
	selection_box = {
		type = "fixed",
		fixed = {
			{-0.0625, -0.5, -0.0625, 0.0625, 0.5, 0.0625},
		}
	},
	groups = {pickaxey = 1, deco_block = 1},
	sounds = mcl_sounds.node_sound_metal_defaults(),
	on_place = function(itemstack, placer, pointed_thing)
		-- Check if we are pointing at a node that has its own on_rightclick (like item frames)
		if pointed_thing.type == "node" then
			local node = core.get_node(pointed_thing.under)
			local def = core.registered_nodes[node.name]
			if def and def.on_rightclick and not (placer and placer:get_player_control().sneak) then
				return def.on_rightclick(pointed_thing.under, node, placer, itemstack, pointed_thing)
			end
		end

		if pointed_thing.type ~= "node" or not placer or not placer:is_player() then
			return itemstack
		end

		local p0 = pointed_thing.under
		local p1 = pointed_thing.above
		local param2 = 0

		local placer_pos = placer:get_pos()
		if placer_pos then
			local dir = {
				x = p1.x - placer_pos.x,
				y = p1.y - placer_pos.y,
				z = p1.z - placer_pos.z
			}
			param2 = core.dir_to_facedir(dir)
		end

		if p0.y - 1 == p1.y then
			param2 = 20
		elseif p0.x - 1 == p1.x then
			param2 = 16
		elseif p0.x + 1 == p1.x then
			param2 = 12
		elseif p0.z - 1 == p1.z then
			param2 = 8
		elseif p0.z + 1 == p1.z then
			param2 = 4
		end

		return core.item_place_node(itemstack, placer, pointed_thing, param2)
	end,
	_mcl_blast_resistance = 6,
	_mcl_hardness = 5,
})

core.register_craft({
	output = "mcl_lanterns:gold_chain",
	recipe = {
		{"mcl_core:gold_nugget"},
		{"mcl_core:gold_ingot"},
		{"mcl_core:gold_nugget"},
	},
})
