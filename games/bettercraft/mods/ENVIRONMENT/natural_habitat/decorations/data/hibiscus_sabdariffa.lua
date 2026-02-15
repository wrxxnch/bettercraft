local S = core.get_translator(core.get_current_modname());
local schempath = natural_habitat.schempath(true);

-- HIBISCUS SABDARIFFA
natural_habitat.register_bush("hibsab", {
    name = S("Hibiscus Sabdariffa"),
    mst_color = "#508242",
    mcl_color = "#589C44",
    
    stages = {
        leaves = {
            description = S("Leaves"),
            mesh = "nbt_bush.obj",
            textures = { "nbt_hibsab_leaves.png" },
        },
        blossom = {
            description = S("Blossom"),
            mesh = "nbt_bush_flower.obj",
            textures = { "nbt_hibsab_leaves.png", "nbt_hibsab_blossom.png" },
        },
    },
});

-- REGISTER DECORATION
natural_habitat.register_multideco("natural_habitat:deco_hibsab", {
    shared = {
        sidelen = 3,
        noise_params = {
            offset = 0,
            scale = 0.003,
            spread = {x = 250, y = 250, z = 250},
            seed = 7913,
            octaves = 3,
            persist = 0.001,
            flags = "absvalue",
        },
        spawn_by = { "air" },
        num_spawn_by = 5,
        y_max = 100,
        y_min = 1,
        flags = "place_center_x, place_center_z",
        decos = {
            { deco_type= "simple", sidelen=1, decoration="natural_habitat:hibsab_blossom", },
            
            { deco_type="schematic", schematic=schempath.."/nbt_hibsab_bush_1.mts", },
            { deco_type="schematic", schematic=schempath.."/nbt_hibsab_bush_2.mts", },
            { deco_type="schematic", schematic=schempath.."/nbt_hibsab_bush_3.mts", },
        },
        force_placement = false,
        rotation = "random",
    },
    minetest = {
        place_on = { "default:dirt_with_grass", },
        biomes = { "grassland", "deciduous_forest" },
    },
    mineclonia = {
        place_on = { "mcl_core:dirt_with_grass", },
        biomes = { "Plains", "FlowerForest", "BirchForest", "Meadow", },
    },
});