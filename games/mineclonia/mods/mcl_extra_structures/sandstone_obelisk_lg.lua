local R = mcl_levelgen.build_random_spread_placement
local structure_biome_test = mcl_levelgen.structure_biome_test
local make_schematic_piece = mcl_levelgen.make_schematic_piece
local create_structure_start = mcl_levelgen.create_structure_start

if not mcl_levelgen.is_levelgen_environment then
	mcl_extra_structures.register_schematic_list ({
		"sandstone_obelisk",
		"iron_sandstone_obelisk",
		"diamond_sandstone_obelisk",
	})
end

------------------------------------------------------------------------
-- Desert Oasis.
------------------------------------------------------------------------

local function sandstone_obelisk_create_start (self, level, terrain, rng, cx, cz)
	local schematic = self.schematic
	local x, z = cx * 16 + rng:next_within (16),
		cz * 16 + rng:next_within (16)
	local y = terrain:get_one_height (x, z)

	if y < level.preset.sea_level then
		return nil
	elseif structure_biome_test (level, self, x, y, z) then
		local pieces = {
			make_schematic_piece (schematic, x, y, z, "random",
					      rng, true, true, nil, nil, nil),
		}
		return create_structure_start (self, pieces)
	end

	return nil
end

------------------------------------------------------------------------
-- Desert Oasis registration.
------------------------------------------------------------------------

local sandstone_obelisk_biomes = {
	"Desert",
}

mcl_levelgen.modify_biome_groups (sandstone_obelisk_biomes, {
	["mcl_extra_structures:has_sandstone_obelisk"] = true,
})

mcl_levelgen.register_structure ("mcl_extra_structures:sandstone_obelisk", {
	create_start = sandstone_obelisk_create_start,
	step = mcl_levelgen.SURFACE_STRUCTURES,
	terrain_adaptation = "none",
	biomes = mcl_levelgen.build_biome_list ({"#mcl_extra_structures:has_sandstone_obelisk",}),
	schematic = "mcl_extra_structures:sandstone_obelisk",
})

mcl_levelgen.register_structure ("mcl_extra_structures:sandstone_obelisk_iron", {
	create_start = sandstone_obelisk_create_start,
	step = mcl_levelgen.SURFACE_STRUCTURES,
	terrain_adaptation = "none",
	biomes = mcl_levelgen.build_biome_list ({"#mcl_extra_structures:has_sandstone_obelisk",}),
	schematic = "mcl_extra_structures:iron_sandstone_obelisk",
})

mcl_levelgen.register_structure ("mcl_extra_structures:sandstone_obelisk_diamond", {
	create_start = sandstone_obelisk_create_start,
	step = mcl_levelgen.SURFACE_STRUCTURES,
	terrain_adaptation = "none",
	biomes = mcl_levelgen.build_biome_list ({"#mcl_extra_structures:has_sandstone_obelisk",}),
	schematic = "mcl_extra_structures:diamond_sandstone_obelisk",
})

mcl_levelgen.register_structure_set ("mcl_extra_structures:sandstone_obelisk", {
	structures = {
		{
			structure = "mcl_extra_structures:sandstone_obelisk",
			weight = 6,
		},
		{
			structure = "mcl_extra_structures:sandstone_obelisk_iron",
			weight = 3,
		},
		{
			structure = "mcl_extra_structures:sandstone_obelisk_diamond",
			weight = 2,
		},
	},
	placement = R (1.0, "default", 80, 20, 1728818693, "linear",
		       nil, nil),
})
