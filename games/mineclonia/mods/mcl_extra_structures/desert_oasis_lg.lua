local R = mcl_levelgen.build_random_spread_placement
local structure_biome_test = mcl_levelgen.structure_biome_test
local make_schematic_piece = mcl_levelgen.make_schematic_piece
local create_structure_start = mcl_levelgen.create_structure_start
local notify_generated = mcl_levelgen.notify_generated
local level_to_minetest_position = mcl_levelgen.level_to_minetest_position

if not mcl_levelgen.is_levelgen_environment then
	mcl_extra_structures.register_schematic_list ({
		"desert_oasis_1",
		"desert_oasis_2",
	})

	local desert_oasis_loot = {
		{
			stacks_min = 2,
			stacks_max = 2,
			items = {
				{ itemstring = "mcl_mobitems:rotten_flesh", weight = 16, amount_min = 3, amount_max=7 },
				{ itemstring = "mcl_core:gold_ingot", weight = 15, amount_min = 2, amount_max = 7 },
				{ itemstring = "mcl_core:iron_ingot", weight = 15, amount_min = 1, amount_max = 5 },
				{ itemstring = "mcl_core:diamond", weight = 3, amount_min = 1, amount_max = 3 },
				{ itemstring = "mcl_mobitems:saddle", weight = 3, },
				{ itemstring = "mcl_mobitems:iron_horse_armor", weight = 1, },
				{ itemstring = "mcl_mobitems:gold_horse_armor", weight = 1, },
				{ itemstring = "mcl_mobitems:diamond_horse_armor", weight = 1, },
				{ itemstring = "mcl_core:apple_gold_enchanted", weight = 2, },
			},
		},
		{
			stacks_min = 2,
			stacks_max = 2,
			items = {
				{ itemstring = "mcl_core:tree", weight = 1, amount_min = 4, amount_max=6 },
			},
		},
		{
			stacks_min = 1,
			stacks_max = 1,
			items = {
				{ itemstring = "mcl_buckets:bucket_water", weight = 1, amount_min = 1, amount_max=1 },
			},
		},
	}

	local v = vector.new ()
	local function handle_desert_oasis_loot (_, data)
		v.x, v.y, v.z
			= level_to_minetest_position (data[1], data[2], data[3])
		local node = core.get_node (v)
		if node.name == "mcl_barrels:barrel_closed" then
			mcl_structures.init_node_construct (v)
			local meta = core.get_meta (v)
			local inv = meta:get_inventory ()
			local pr = PcgRandom (data[4])
			local loot = mcl_loot.get_multi_loot (desert_oasis_loot, pr)
			mcl_loot.fill_inventory (inv, "main", loot, pr)
		end
	end

	mcl_levelgen.register_notification_handler ("mcl_extra_structures:desert_oasis_loot",
						    handle_desert_oasis_loot)
end

------------------------------------------------------------------------
-- Desert Oasis.
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

local cid_barrel_closed = getcid ("mcl_barrels:barrel_closed")
local mathabs = math.abs

local function desert_oasis_loot (x, y, z, rng, cid_existing,
				  param2_existing, cid, param2)
	if cid == cid_barrel_closed then
		local seed = mathabs (rng:next_integer ())
		notify_generated ("mcl_extra_structures:desert_oasis_loot", x, y, z, {
			x, y, z, seed,
		})
	end
	return cid, param2
end

local desert_oasis_processors = {
	desert_oasis_loot,
	mcl_extra_structures.grass_processor,
}

local function desert_oasis_create_start (self, level, terrain, rng, cx, cz)
	local schematic = rng:next_boolean ()
		and "mcl_extra_structures:desert_oasis_2"
		or "mcl_extra_structures:desert_oasis_1"
	local x, z = cx * 16 + rng:next_within (16),
		cz * 16 + rng:next_within (16)
	local y = terrain:get_one_height (x, z) - (2 + rng:next_within (1))

	if y < level.preset.sea_level then
		return nil
	elseif structure_biome_test (level, self, x, y, z) then
		local pieces = {
			make_schematic_piece (schematic, x, y, z, "random",
					      rng, true, true, desert_oasis_processors,
					      nil, nil),
		}
		return create_structure_start (self, pieces)
	end

	return nil
end

------------------------------------------------------------------------
-- Desert Oasis registration.
------------------------------------------------------------------------

local desert_oasis_biomes = {
	"Desert",
}

mcl_levelgen.modify_biome_groups (desert_oasis_biomes, {
	["mcl_extra_structures:has_desert_oasis"] = true,
})

mcl_levelgen.register_structure ("mcl_extra_structures:desert_oasis", {
	create_start = desert_oasis_create_start,
	step = mcl_levelgen.SURFACE_STRUCTURES,
	terrain_adaptation = "none",
	biomes = mcl_levelgen.build_biome_list ({"#mcl_extra_structures:has_desert_oasis",}),
})

mcl_levelgen.register_structure_set ("mcl_extra_structures:desert_oases", {
	structures = {
		"mcl_extra_structures:desert_oasis",
	},
	placement = R (1.0, "default", 60, 20, 2990390720, "linear",
		       nil, nil),
})
