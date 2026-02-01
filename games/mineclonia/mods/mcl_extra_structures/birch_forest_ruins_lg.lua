local R = mcl_levelgen.build_random_spread_placement
local structure_biome_test = mcl_levelgen.structure_biome_test
local make_schematic_piece = mcl_levelgen.make_schematic_piece
local create_structure_start = mcl_levelgen.create_structure_start
local notify_generated = mcl_levelgen.notify_generated
local level_to_minetest_position = mcl_levelgen.level_to_minetest_position

if not mcl_levelgen.is_levelgen_environment then
	mcl_extra_structures.register_schematic_list ({
		"birch_forest_ruins_1",
		"birch_forest_ruins_2",
	})

	local birch_forest_ruins_loot = {
		{
			stacks_min = 2,
			stacks_max = 4,
			items = {
				{ itemstring = "mcl_mobitems:rotten_flesh", weight = 16, amount_min = 3, amount_max=7 },
				{ itemstring = "mcl_core:gold_ingot", weight = 3, amount_min = 2, amount_max = 7 },
				{ itemstring = "mcl_core:iron_ingot", weight = 5, amount_min = 1, amount_max = 5 },
				{ itemstring = "mcl_core:diamond", weight = 1, amount_min = 1, amount_max = 3 },
				{ itemstring = "mcl_tools:sword_stone", weight = 15, },
				{ itemstring = "mcl_tools:pick_stone", weight = 15, },
				{ itemstring = "mcl_tools:shovel_stone", weight = 15, },
				{ itemstring = "mcl_torches:torch", weight = 15, amount_min = 3, amount_max=7 },
			},
		},
		{
			stacks_min = 1,
			stacks_max = 1,
			items = {
				{ itemstring = "mcl_fire:flint_and_steel", weight = 1, amount_min = 1, amount_max=1 },
			},
		},
	}

	local v = vector.new ()
	local function handle_birch_forest_ruins_loot (_, data)
		v.x, v.y, v.z
			= level_to_minetest_position (data[1], data[2], data[3])
		local node = core.get_node (v)
		if node.name == "mcl_chests:chest_small" then
			mcl_structures.init_node_construct (v)
			local meta = core.get_meta (v)
			local inv = meta:get_inventory ()
			local pr = PcgRandom (data[4])
			local loot = mcl_loot.get_multi_loot (birch_forest_ruins_loot, pr)
			mcl_loot.fill_inventory (inv, "main", loot, pr)
		end
	end

	mcl_levelgen.register_notification_handler ("mcl_extra_structures:birch_forest_ruins_loot",
						    handle_birch_forest_ruins_loot)
end

------------------------------------------------------------------------
-- Birch Forest Ruins.
------------------------------------------------------------------------

local function getcid (name)
	if mcl_levelgen.is_levelgen_environment then
		return core.get_content_id (name)
	else
		-- Content IDs are unnecessary in non-mapgen
		-- environments, as in such environments structure
		-- generators will only be invoked to locate
		-- structures.
		return 0
	end
end

local cid_chest_small = getcid ("mcl_chests:chest_small")
local mathabs = math.abs

local function birch_forest_ruins_loot (x, y, z, rng, cid_existing,
					param2_existing, cid, param2)
	if cid == cid_chest_small then
		notify_generated ("mcl_extra_structures:birch_forest_ruins_loot", x, y, z, {
			x, y, z, mathabs (rng:next_integer ()),
		})
	end
	return cid, param2
end

local birch_forest_ruins_processors = {
	birch_forest_ruins_loot,
	mcl_extra_structures.grass_processor,
}

local function birch_forest_ruins_create_start (self, level, terrain, rng, cx, cz)
	local schematic = rng:next_boolean ()
		and "mcl_extra_structures:birch_forest_ruins_2"
		or "mcl_extra_structures:birch_forest_ruins_1"
	local x, z = cx * 16 + rng:next_within (16),
		cz * 16 + rng:next_within (16)
	local y = terrain:get_one_height (x, z) - rng:next_within (1)

	if y < level.preset.sea_level then
		return nil
	elseif structure_biome_test (level, self, x, y, z) then
		local pieces = {
			make_schematic_piece (schematic, x, y, z, "random",
					      rng, true, true,
					      birch_forest_ruins_processors,
					      nil, 2),
		}
		return create_structure_start (self, pieces)
	end

	return nil
end

------------------------------------------------------------------------
-- Birch Forest Ruins registration.
------------------------------------------------------------------------

local birch_forest_ruins_biomes = {
	"BirchForest",
	"OldGrowthBirchForest",
}

mcl_levelgen.modify_biome_groups (birch_forest_ruins_biomes, {
	["mcl_extra_structures:has_birch_forest_ruins"] = true,
})

mcl_levelgen.register_structure ("mcl_extra_structures:birch_forest_ruins", {
	create_start = birch_forest_ruins_create_start,
	step = mcl_levelgen.SURFACE_STRUCTURES,
	terrain_adaptation = "beard_thin",
	biomes = mcl_levelgen.build_biome_list ({"#mcl_extra_structures:has_birch_forest_ruins",}),
})

mcl_levelgen.register_structure_set ("mcl_extra_structures:birch_forest_ruins", {
	structures = {
		"mcl_extra_structures:birch_forest_ruins",
	},
	placement = R (1.0, "default", 40, 20, 1109598614, "linear",
		       nil, nil),
})
