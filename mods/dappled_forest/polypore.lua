-- Políporos (Shelf Mushrooms) generated on living Poplar trunks.
local S = core.get_translator(core.get_current_modname())
local modname = core.get_current_modname()

local function register_polypore(name, texture, description, boxes, top_texture, side_texture)
	core.register_node(modname .. ":polypore_" .. name, {
		description = S(description),
		_doc_items_longdesc = S("A polypore that grows on Poplar trees in the Dappled Forest."),
		-- The supplied Minecraft JSON model is converted to Luanti's native
		-- fixed node_box. A wallmounted node_box accepts only one box per side,
		-- while these models contain two elements, so fixed preserves both parts.
		-- Coordinates are the original 0..16 model units converted to node-relative
		-- -0.5..0.5 units.
		drawtype = "nodebox",
		tiles = {top_texture, side_texture, side_texture, side_texture, side_texture, side_texture},
		inventory_image = texture,
		wield_image = texture,
		use_texture_alpha = "clip",
		sunlight_propagates = true,
		paramtype = "light",
		paramtype2 = "facedir",
		walkable = true,
		buildable_to = true,
		node_box = {
			type = "fixed",
			fixed = boxes,
		},
		selection_box = {type = "fixed", fixed = boxes},
		on_place = function(itemstack, placer, pointed_thing)
			if pointed_thing.type ~= "node" then
				return itemstack
			end
			local support = vector.subtract(pointed_thing.under, pointed_thing.above)
			-- Polypores must be attached to a vertical wall, never placed on
			-- the floor or ceiling.
			if support.y ~= 0 then
				return itemstack
			end
			local facedir = core.dir_to_facedir(support)
			local placed_stack, success = core.item_place_node(itemstack, placer, pointed_thing, facedir)
			return placed_stack, success
		end,
		groups = {
			deco_block = 1,
			destroy_by_lava_flow = 1,
			dig_immediate = 3,
			dig_by_water = 1,
			dig_by_piston = 1,
			mushroom = 1,
			compostability = 65,
            bouncy=55,
            fall_damage_add_percent=-60
		},
		sounds = mcl_sounds.node_sound_leaves_defaults(),
		_mcl_hardness = 0,
	})
end

register_polypore("small", "small_polypore.png", "Small Polypore", {
	{-0.3125, 0.0625, 0.0625, 0.3125, 0.1875, 0.5},
	{-0.1875, 0, 0.25, 0.1875, 0.0625, 0.5},
}, "dappled_forest_polypore_top.png", "dappled_forest_polypore_side.png")
register_polypore("large", "large_polypore.png", "Large Polypore", {
	{-0.4375, 0, -0.125, 0.4375, 0.1875, 0.5},
	{-0.25, -0.125, 0.125, 0.25, 0, 0.5},
}, "dappled_forest_polypore_top.png", "dappled_forest_polypore_side.png")

local trunk_name = "mcl_trees:tree_poplar"
local small_name = modname .. ":polypore_small"
local large_name = modname .. ":polypore_large"
local side_dirs = {
	{x = 1, y = 0, z = 0},
	{x = -1, y = 0, z = 0},
	{x = 0, y = 0, z = 1},
	{x = 0, y = 0, z = -1},
}

local function add(a, b)
	return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z}
end

-- Poplar trees are placed by level generation schematics. Once a generated
-- chunk is complete, attach one or two shelf mushrooms to random trunk sides.
core.register_on_generated(function(minp, maxp, blockseed)
	local rng = PseudoRandom((blockseed or 0) + 17031)
	local candidates = {}
	for x = minp.x, maxp.x do
		for y = minp.y, maxp.y do
			for z = minp.z, maxp.z do
				local trunk = {x = x, y = y, z = z}
				if core.get_node(trunk).name == trunk_name then
					for _, dir in ipairs(side_dirs) do
						local target = add(trunk, dir)
						local target_node = core.get_node(target)
						local target_def = core.registered_nodes[target_node.name]
						if target_node.name == "air" or (target_def and target_def.buildable_to) then
							candidates[#candidates + 1] = {pos = target, support = trunk, dir = dir}
						end
					end
				end
			end
		end
	end

	local placed = 0
	while #candidates > 0 and placed < 2 do
		local index = rng:next(1, #candidates)
		local candidate = table.remove(candidates, index)
		if core.get_node(candidate.pos).name == "air" then
			local kind = rng:next(1, 4) == 1 and large_name or small_name
			core.set_node(candidate.pos, {
				name = kind,
				param2 = core.dir_to_facedir({x = -candidate.dir.x, y = -candidate.dir.y, z = -candidate.dir.z}),
			})
			placed = placed + 1
		end
	end
end)
