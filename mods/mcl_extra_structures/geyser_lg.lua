------------------------------------------------------------------------
-- Gêiseres para mcl_extra_structures
--
-- Coloque este arquivo em:
-- mcl_extra_structures/geyser_lg.lua
--
-- Schematics esperados em:
-- mcl_extra_structures/schematics/mcl_extra_structures_geyser_1.mts
-- mcl_extra_structures/schematics/mcl_extra_structures_geyser_2.mts
-- mcl_extra_structures/schematics/mcl_extra_structures_geyser_3.mts
-- mcl_extra_structures/schematics/mcl_extra_structures_geyser_4.mts
------------------------------------------------------------------------

local R = mcl_levelgen.build_random_spread_placement
local structure_biome_test = mcl_levelgen.structure_biome_test
local make_schematic_piece = mcl_levelgen.make_schematic_piece
local create_structure_start = mcl_levelgen.create_structure_start

------------------------------------------------------------------------
-- Schematics.
------------------------------------------------------------------------

local geyser_schematics = {
	"geyser_1",
	"geyser_2",
	"geyser_3",
	"geyser_4",
}

-- O helper do mcl_extra_structures acrescenta o prefixo correto ao nome
-- do arquivo e registra os dados portáteis no mcl_levelgen.
if not mcl_levelgen.is_levelgen_environment then
	mcl_extra_structures.register_schematic_list (geyser_schematics)
end

local geyser_ids = {
	"mcl_extra_structures:geyser_1",
	"mcl_extra_structures:geyser_2",
	"mcl_extra_structures:geyser_3",
	"mcl_extra_structures:geyser_4",
}

------------------------------------------------------------------------
-- Biomas.
------------------------------------------------------------------------

local geyser_biomes = {
	"Plains",
	"Mesa",
	"DarkForest",
	"Taiga",
	"OldGrowthSpruceTaiga",
	"WindsweptHills",
}

mcl_levelgen.modify_biome_groups (geyser_biomes, {
	["mcl_extra_structures:has_geyser"] = true,
})

local geyser_biome_list = mcl_levelgen.build_biome_list ({
	"#mcl_extra_structures:has_geyser",
})

------------------------------------------------------------------------
-- Geração de uma estrutura.
------------------------------------------------------------------------

local function make_geyser_create_start (schematic_id)
	return function (self, level, terrain, rng, cx, cz)
		-- next_within(16) produz valores de 0 a 15, cobrindo todo o chunk.
		local x = cx * 16 + rng:next_within (16)
		local z = cz * 16 + rng:next_within (16)
		local y = terrain:get_one_height (x, z)

		if not y or y < level.preset.sea_level then
			return nil
		end

		if not structure_biome_test (level, self, x, y, z) then
			return nil
		end

		-- A origem dos schematics foi considerada um bloco acima da base.
		-- Se os seus .mts já tiverem a base alinhada ao terreno, use y em
		-- vez de y - 1.
		local spawn_y = y - 1
		local pieces = {
			make_schematic_piece (
				schematic_id,
				x,
				spawn_y,
				z,
				"random",
				rng,
				true,
				true,
				nil,
				nil,
				nil
			),
		}

		return create_structure_start (self, pieces)
	end
end

------------------------------------------------------------------------
-- Estruturas.
------------------------------------------------------------------------

for _, structure_id in ipairs (geyser_ids) do
	mcl_levelgen.register_structure (structure_id, {
		create_start = make_geyser_create_start (structure_id),
		step = mcl_levelgen.SURFACE_STRUCTURES,
		terrain_adaptation = "beard_thin",
		biomes = geyser_biome_list,
	})
end

------------------------------------------------------------------------
-- Structure set.
------------------------------------------------------------------------

mcl_levelgen.register_structure_set ("mcl_extra_structures:geysers", {
	structures = {
		{
			structure = geyser_ids[1],
			weight = 1,
		},
		{
			structure = geyser_ids[2],
			weight = 1,
		},
		{
			structure = geyser_ids[3],
			weight = 1,
		},
		{
			structure = geyser_ids[4],
			weight = 1,
		},
	},
	placement = R (
		1.0,
		"default",
		80,
		20,
		38472911,
		"linear",
		nil,
		nil
	),
})
