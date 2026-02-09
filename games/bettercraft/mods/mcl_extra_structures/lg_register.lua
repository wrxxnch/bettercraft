local modpath = core.get_modpath ("mcl_extra_structures")
local ipairs = ipairs

------------------------------------------------------------------------
-- Structure generation utilities.
------------------------------------------------------------------------

mcl_extra_structures = {}

function mcl_extra_structures.register_schematic_list (list)
	for _, schematic in ipairs (list) do
		local filename = modpath .. "/schematics/mcl_extra_structures_"
			.. schematic .. ".mts"
		local name = "mcl_extra_structures:" .. schematic
		mcl_levelgen.register_portable_schematic (name, filename, true)
	end
end

local index_biome = mcl_levelgen.index_biome
local cid_grass = core.get_content_id ("mcl_core:dirt_with_grass")
local registered_biomes = mcl_levelgen.registered_biomes

function mcl_extra_structures.grass_processor (x, y, z, rng, cid_current,
					       param2_current, cid, param2)
	if cid == cid_grass then
		local biome = index_biome (x, y, z)
		local def = registered_biomes[biome]
		return cid, def.grass_palette_index
	end
	return cid, param2
end

------------------------------------------------------------------------
-- Structure initialization.
------------------------------------------------------------------------

dofile (modpath .. "/desert_oasis_lg.lua") -- Load Desert Oasis
dofile (modpath .. "/birch_forest_ruins_lg.lua") -- Load Birch Forest Ruins
dofile (modpath .. "/brick_pyramid_lg.lua") -- Load Brick Pyramid
dofile (modpath .. "/graveyard_lg.lua") -- Load Graveyards
dofile (modpath .. "/loggers_camp_lg.lua") -- Load Loggers Camp
dofile (modpath .. "/sandstone_obelisk_lg.lua") -- Load Sandstone Obelisks
dofile (modpath .. "/ice_tower_lg.lua") -- Load Ice Tower
