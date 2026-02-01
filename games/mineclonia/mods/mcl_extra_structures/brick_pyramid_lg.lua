local R = mcl_levelgen.build_random_spread_placement
local structure_biome_test = mcl_levelgen.structure_biome_test
local make_schematic_piece = mcl_levelgen.make_schematic_piece
local create_structure_start = mcl_levelgen.create_structure_start

if not mcl_levelgen.is_levelgen_environment then
	mcl_extra_structures.register_schematic_list ({
		"brick_pyramid",
	})
end

------------------------------------------------------------------------
-- Desert Oasis.
------------------------------------------------------------------------

local function brick_pyramid_create_start (self, level, terrain, rng, cx, cz)
	local schematic = "mcl_extra_structures:brick_pyramid"
	local x, z = cx * 16 + rng:next_within (16),
		cz * 16 + rng:next_within (16)
	local y = terrain:get_one_height (x, z) - rng:next_within (1)

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

local brick_pyramid_biomes = {
	"Plains",
}

mcl_levelgen.modify_biome_groups (brick_pyramid_biomes, {
	["mcl_extra_structures:has_brick_pyramid"] = true,
})

mcl_levelgen.register_structure ("mcl_extra_structures:brick_pyramid", {
	create_start = brick_pyramid_create_start,
	step = mcl_levelgen.SURFACE_STRUCTURES,
	terrain_adaptation = "none",
	biomes = mcl_levelgen.build_biome_list ({"#mcl_extra_structures:has_brick_pyramid",}),
	schematic = "mcl_extra_structures:brick_pyramid",
})

mcl_levelgen.register_structure_set ("mcl_extra_structures:brick_pyramids", {
	structures = {
		"mcl_extra_structures:brick_pyramid",
	},
	placement = R (1.0, "default", 90, 20, 3468180871, "triangular",
		       nil, nil),
})
