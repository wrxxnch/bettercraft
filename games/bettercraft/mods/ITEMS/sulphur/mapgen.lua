-- mapgen.lua - Estruturas de Superfície e Cavernas
local modname = "sulphur_update"
local target_biomes = {"plains", "MesaPlateauFM_sandlevel", "dead_forest", "megaTaiga"}

-- 1. Registro das Estruturas de GEYSER na SUPERFÍCIE (.mts)
for i = 1, 4 do
    core.register_decoration({
        name = modname .. ":geyser_structure_" .. i,
        deco_type = "schematic",
        place_on = {
            "mcl_core:dirt_with_grass", 
            "mcl_core:sand", 
            "mcl_core:coarse_dirt", 
            "mcl_core:red_sand"
        },
        sidelen = 16,
        noise_params = {
            offset = 0.0002,
            scale = 0.001,
            spread = {x = 250, y = 250, z = 250},
            seed = 100 + i,
            octaves = 3,
            persist = 0.6
        },
        biomes = target_biomes,
        y_max = 31000,
        y_min = 60,
        -- ALTERADO: Agora procura por .mts
        schematic = core.get_modpath(modname) .. "/schematics/geyser" .. i .. ".mts",
        flags = "place_center_x, place_center_z",
        rotation = "random",
    })
end

-- 2. Cavernas de Enxofre (Estilo Dripstone Walls)
core.register_ore({
    ore_type       = "blob",
    ore            = modname .. ":sulfur",
    wherein        = {"mcl_core:stone", "mcl_core:diorite", "mcl_core:andesite"},
    clust_scarcity = 900,
    clust_num_ores = 250,
    clust_size     = 18,
    y_max          = -15,
    y_min          = -1000,
    biomes         = target_biomes,
})

core.register_ore({
    ore_type       = "blob",
    ore            = modname .. ":cinnabar",
    wherein        = {modname .. ":sulfur", "mcl_core:stone"},
    clust_scarcity = 1400,
    clust_num_ores = 80,
    clust_size     = 10,
    y_max          = -30,
    y_min          = -1000,
    biomes         = target_biomes,
})

-- 3. Decorações de Spikes (Estalagmites e Estalactites)
core.register_decoration({
    deco_type = "simple",
    place_on = {modname .. ":sulfur", modname .. ":cinnabar"},
    sidelen = 8,
    noise_params = { offset = 0.05, scale = 0.15, spread = {x=100, y=100, z=100}, seed = 500, octaves = 3 },
    y_max = -20,
    y_min = -1000,
    decoration = modname .. ":sulfur_spike_up_tip",
    biomes = target_biomes,
})

core.register_decoration({
    deco_type = "simple",
    place_on = {modname .. ":sulfur", modname .. ":cinnabar"},
    sidelen = 8,
    noise_params = { offset = 0.05, scale = 0.15, spread = {x=100, y=100, z=100}, seed = 600, octaves = 3 },
    y_max = -20,
    y_min = -1000,
    decoration = modname .. ":sulfur_spike_down_tip",
    flags = "all_ceilings",
    biomes = target_biomes,
})