local R = mcl_levelgen.build_random_spread_placement
local structure_biome_test = mcl_levelgen.structure_biome_test
local make_schematic_piece = mcl_levelgen.make_schematic_piece
local create_structure_start = mcl_levelgen.create_structure_start
local notify_generated = mcl_levelgen.notify_generated
local level_to_minetest_position = mcl_levelgen.level_to_minetest_position
local create_entity = mcl_levelgen.create_entity

if not mcl_levelgen.is_levelgen_environment then
	mcl_extra_structures.register_schematic_list ({
		"loggers_camp",
	})

	local loggers_camp_loot = {
		{
			stacks_min = 6,
			stacks_max = 10,
			items = {
				{ itemstring = "mcl_core:gold_ingot", weight = 3, amount_min = 2, amount_max = 7 },
				{ itemstring = "mcl_core:iron_ingot", weight = 5, amount_min = 1, amount_max = 5 },
				{ itemstring = "mcl_core:diamond", weight = 1, amount_min = 1, amount_max = 3 },
				{ itemstring = "mcl_farming:cookie", weight = 15, amount_min = 3, amount_max=7 },
				{ itemstring = "mcl_core:sprucetree", weight = 15, amount_min = 3, amount_max=7 },
				{ itemstring = "mcl_tools:pick_iron", weight = 6, },
				{ itemstring = "mcl_tools:shovel_iron", weight = 6, },
				{ itemstring = "mcl_torches:torch", weight = 15, amount_min = 3, amount_max=7 },
				{ itemstring = "mcl_armor:chestplate_iron", weight = 1, func = function(stack, pr) mcl_enchanting.enchant_uniform_randomly(stack, {"soul_speed"}, pr) end },
				{ itemstring = "mcl_armor:leggings_iron", weight = 2, func = function(stack, pr) mcl_enchanting.enchant_uniform_randomly(stack, {"soul_speed"}, pr) end },
				{ itemstring = "mcl_bows:arrow", weight = 15, amount_min = 2, amount_max=7 },
				{ itemstring = "mcl_bows:bow", weight = 5, func = function(stack, pr) mcl_enchanting.enchant_uniform_randomly(stack, {"soul_speed"}, pr) end },
			}
		},
	}

	local v = vector.new ()
	local function handle_loggers_camp_loot (_, data)
		v.x, v.y, v.z
			= level_to_minetest_position (data[1], data[2], data[3])
		local node = core.get_node (v)
		if node.name == "mcl_barrels:barrel_closed" then
			mcl_structures.init_node_construct (v)
			local meta = core.get_meta (v)
			local inv = meta:get_inventory ()
			local pr = PcgRandom (data[4])
			local loot = mcl_loot.get_multi_loot (loggers_camp_loot, pr)
			mcl_loot.fill_inventory (inv, "main", loot, pr)
		end
	end

	mcl_levelgen.register_notification_handler ("mcl_extra_structures:loggers_camp_loot",
						    handle_loggers_camp_loot)
end

------------------------------------------------------------------------
-- Loggers Camp.
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

local function loggers_camp_loot (x, y, z, rng, cid_existing,
			       param2_existing, cid, param2)
	if cid == cid_barrel_closed then
		notify_generated ("mcl_extra_structures:loggers_camp_loot", x, y, z, {
			x, y, z, mathabs (rng:next_integer ()),
		})
	end
	return cid, param2
end

local loggers_camp_processors = {
	loggers_camp_loot,
	mcl_extra_structures.grass_processor,
}

local function loggers_camp_create_start (self, level, terrain, rng, cx, cz)
	local schematic = "mcl_extra_structures:loggers_camp"
	local x, z = cx * 16 + rng:next_within (16),
		cz * 16 + rng:next_within (16)
	local y = terrain:get_one_height (x, z)

	if y < level.preset.sea_level then
		return nil
	elseif structure_biome_test (level, self, x, y, z) then
		local pieces = {
			make_schematic_piece (schematic, x, y, z, "random",
					      rng, true, true,
					      loggers_camp_processors,
					      nil, nil),
		}
		return create_structure_start (self, pieces)
	end

	return nil
end

------------------------------------------------------------------------
-- Loggers Camp registration.
------------------------------------------------------------------------

local loggers_camp_biomes = {
	"#is_taiga",
}

mcl_levelgen.modify_biome_groups (loggers_camp_biomes, {
	["mcl_extra_structures:has_loggers_camp"] = true,
})

mcl_levelgen.register_structure ("mcl_extra_structures:loggers_camp", {
	create_start = loggers_camp_create_start,
	step = mcl_levelgen.SURFACE_STRUCTURES,
	terrain_adaptation = "beard_box",
	biomes = mcl_levelgen.build_biome_list ({"#mcl_extra_structures:has_loggers_camp",}),
})

mcl_levelgen.register_structure_set ("mcl_extra_structures:loggers_camps", {
	structures = {
		"mcl_extra_structures:loggers_camp",
	},
	placement = R (1.0, "default", 80, 20, 3941881656, "linear",
		       nil, nil),
})
