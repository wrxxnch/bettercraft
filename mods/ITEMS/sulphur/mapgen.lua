-- mapgen.lua - Estruturas de Superfície, Cavernas e Espeleotemas
local modname = minetest.get_current_modname()

-- Nomes técnicos dos biomas do MineClone 2
local surface_target_biomes = {
	"mcl_biomes:plains", 
	"mcl_biomes:mesa_plateau_fm_sandlevel", 
	"mcl_biomes:dead_forest", 
	"mcl_biomes:mega_taiga"
}

-- Lista para as Ores e Spikes (Bioma próprio + biomas de superfície)
local all_target_biomes = {
	"sulphur_cave",
	"mcl_biomes:plains", 
	"mcl_biomes:mesa_plateau_fm_sandlevel", 
	"mcl_biomes:dead_forest", 
	"mcl_biomes:mega_taiga"
}

--------------------------------------------------------------------------------
-- 1. REGISTRO DO BIOMA (Habilita /locate biome sulphur_cave)
--------------------------------------------------------------------------------
core.register_biome({
	name = "sulphur_cave",
	node_stone = "mcl_core:stone",
	node_filler = modname .. ":sulfur",
	y_max = -15,
	y_min = -1000,
	heat_point = 95,
	humidity_point = 5,
})

--------------------------------------------------------------------------------
-- 2. REGISTRO DAS ORES (Blobs de Enxofre e Cinábrio)
--------------------------------------------------------------------------------
core.register_ore({
	ore_type       = "blob",
	ore            = modname .. ":sulfur",
	wherein        = {"mcl_core:stone", "mcl_core:diorite", "mcl_core:andesite"},
	clust_scarcity = 800,
	clust_num_ores = 250,
	clust_size     = 18,
	y_max          = -15,
	y_min          = -1000,
	biomes         = all_target_biomes,
})

core.register_ore({
	ore_type       = "blob",
	ore            = modname .. ":cinnabar",
	wherein        = {modname .. ":sulfur", "mcl_core:stone"},
	clust_scarcity = 1200,
	clust_num_ores = 80,
	clust_size     = 10,
	y_max          = -30,
	y_min          = -1000,
	biomes         = all_target_biomes,
})

--------------------------------------------------------------------------------
-- 3. SCHEMATICS PARA ESPINHOS GRANDES (3 Blocos de altura)
--------------------------------------------------------------------------------

-- Estalagmite (Sobe do chão)
local schem_spike_up = {
	size = {x = 1, y = 3, z = 1},
	data = {
		{name = modname .. ":sulfur_spike_up_base"},    -- Base larga no chão
		{name = modname .. ":sulfur_spike_up_frustum"}, -- Meio
		{name = modname .. ":sulfur_spike_up_tip"},     -- Ponta fina
	}
}

-- Estalactite (Desce do teto)
local schem_spike_down = {
	size = {x = 1, y = 3, z = 1},
	data = {
		{name = modname .. ":sulfur_spike_down_tip"},     -- Ponta fina (mais baixo)
		{name = modname .. ":sulfur_spike_down_frustum"}, -- Meio
		{name = modname .. ":sulfur_spike_down_base"},    -- Base presa no teto
	}
}

--------------------------------------------------------------------------------
-- 4. REGISTRO DAS DECORAÇÕES (Spikes Grandes e Pequenos)
--------------------------------------------------------------------------------

-- Espinhos GRANDES no Chão
core.register_decoration({
	name = modname .. ":sulfur_spikes_large_floor",
	deco_type = "schematic",
	place_on = {modname .. ":sulfur", modname .. ":cinnabar"},
	sidelen = 16,
	noise_params = {
		offset = 0.01, scale = 0.04, spread = {x = 100, y = 100, z = 100},
		seed = 555, octaves = 3, persist = 0.6
	},
	biomes = all_target_biomes,
	y_max = -15,
	y_min = -1000,
	schematic = schem_spike_up,
	flags = "place_center_x, place_center_z",
})

-- Espinhos GRANDES no Teto
core.register_decoration({
	name = modname .. ":sulfur_spikes_large_ceiling",
	deco_type = "schematic",
	place_on = {modname .. ":sulfur", modname .. ":cinnabar"},
	sidelen = 16,
	noise_params = {
		offset = 0.01, scale = 0.04, spread = {x = 100, y = 100, z = 100},
		seed = 666, octaves = 3, persist = 0.6
	},
	biomes = all_target_biomes,
	y_max = -15,
	y_min = -1000,
	schematic = schem_spike_down,
	flags = "all_ceilings, place_center_x, place_center_z",
	shift_y = -2, -- Move a estrutura para baixo para a base encostar no teto
})

-- Espinhos PEQUENOS (Variedade)
core.register_decoration({
	name = modname .. ":sulfur_spikes_small",
	deco_type = "simple",
	place_on = {modname .. ":sulfur", modname .. ":cinnabar"},
	sidelen = 16,
	fill_ratio = 0.03,
	biomes = all_target_biomes,
	y_max = -15,
	y_min = -1000,
	decoration = {modname .. ":sulfur_spike_up_tip", modname .. ":sulfur_spike_down_tip"},
})

--------------------------------------------------------------------------------
-- 5. REGISTRO DE ESTRUTURAS (Geysers com suporte a /locate structure)
--------------------------------------------------------------------------------

if minetest.get_modpath("mcl_structures") then
	-- Registro via API de Estruturas do MineClone
	for i = 1, 4 do
		mcl_structures.register_structure(modname .. ":geyser_" .. i, {
			name = modname .. ":geyser_" .. i,
			schematic = minetest.get_modpath(modname) .. "/schematics/geyser" .. i .. ".mts",
			biomes = surface_target_biomes,
			chance = 500, -- 1 em cada 500 chunks
			y_min = 60,
			y_max = 90,
			flags = "place_center_x, place_center_z",
		})
	end
else
	-- Fallback caso não tenha a API: usa decoração comum
	for i = 1, 4 do
		core.register_decoration({
			name = modname .. ":geyser_structure_" .. i,
			deco_type = "schematic",
			place_on = {"mcl_core:dirt_with_grass", "mcl_core:sand", "mcl_core:coarse_dirt"},
			sidelen = 80,
			noise_params = {
				offset = 0.001, scale = 0.002, spread = {x = 250, y = 250, z = 250},
				seed = 100 + i, octaves = 3, persist = 0.6
			},
			biomes = surface_target_biomes,
			y_max = 90, y_min = 20,
			schematic = core.get_modpath(modname) .. "/schematics/geyser" .. i .. ".mts",
			flags = "place_center_x, place_center_z",
		})
	end
end