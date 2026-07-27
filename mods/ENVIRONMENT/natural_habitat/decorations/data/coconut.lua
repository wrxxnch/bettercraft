local S = core.get_translator(core.get_current_modname())
local modpath = minetest.get_modpath("natural_habitat")

-- Lista de Biomas do MineClone para as decorações comuns
local mcl_biomes_comuns = {
	"Forest", "FlowerForest", "Plains", "BirchForest", "Meadow",
	"Taiga", "MegaTaiga", "MegaSpruceTaiga", "SunflowerPlains",
	"RoofedForest", "Jungle", "JungleM", "JungleEdge", "BambooJungle",
	"Savanna", "PaleGarden"
}

-- 1. Registro de GRAVETOS (Sticks)
natural_habitat.register_multideco("natural_habitat:deco_stick", {
	shared = {
		deco_type = "simple",
		fill_ratio = 0.008,
		spawn_by = "air",
		num_spawn_by = 1,
		rotation = "random",
		decos = {
			{ decoration="natural_habitat:stick" },
			{ decoration="natural_habitat:stick_2" },
			{ decoration="natural_habitat:stick_3" },
		},
		use_map_generator = true,
	},
	mineclonia = {
		place_on = {"mcl_core:dirt_with_grass", "mcl_core:podzol", "mcl_core:coarse_dirt"},
		biomes = mcl_biomes_comuns,
	},
})

-- 2. Registro de PEDRAS (Rocks)
natural_habitat.register_multideco("natural_habitat:deco_rock", {
	shared = {
		deco_type = "simple",
		fill_ratio = 0.004,
		decos = {
			{ decoration="natural_habitat:stone_rubble" },
		},
	},
	mineclonia = {
		place_on = {"mcl_core:dirt_with_grass", "mcl_core:stone", "mcl_core:gravel"},
		biomes = mcl_biomes_comuns,
	},
})

-- 3. Registro das Árvores de Coqueiro (Coconut Trees)
local coconut_trees = {
	"nbt_coconut_palmtree_1",
	"nbt_coconut_palmtree_2",
	"nbt_coconut_palmtree_3"
}

for _, schematic_name in ipairs(coconut_trees) do
	-- Construímos o caminho completo primeiro para garantir que é uma string pura
	local schem_path = modpath .. "/schems/" .. schematic_name .. ".mts"
	
	minetest.register_decoration({
		name = "natural_habitat:deco_" .. schematic_name, -- Nome único para cada variação
		deco_type = "schematic",
		place_on = {"mcl_core:sand"},
		sidelen = 16,
		fill_ratio = 0.0015 / 3, 
		-- Verifique se Plains_beach e Plains_ocean existem no seu mapa, 
		-- no MineClone padrão são apenas "Beach" e "Ocean"
		biomes = {"Beach", "JungleEdge", "Plains_beach"},
		schematic = schem_path,
		flags = "place_center_x, place_center_z",
		rotation = "random",
	})
end