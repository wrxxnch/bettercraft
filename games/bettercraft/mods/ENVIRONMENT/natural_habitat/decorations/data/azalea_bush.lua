local S = core.get_translator(core.get_current_modname());
local schempath = natural_habitat.schempath(true);
local pref = natural_habitat.get_pref();

local leaves = { "mts_azalea_leaves.png", "mts_azalea_leaves.png" };
if natural_habitat.is_mineclonia() then
    leaves = { "mcl_lush_caves_azalea_leaves.png", "mcl_lush_caves_azalea_leaves_flowering.png" };
end;

-- AZALEA BUSH
natural_habitat.register_bush("azalea", {
    name = S("Azalea Bush"),
        
    stages = {
        leaves = {
            description = S("Leaves"),
            mesh = "nbt_bush.obj",
            textures = { leaves[1] },
        },
        blossom = {
            description = S("Blossom"),
            mesh = "nbt_bush_flower.obj",
            textures = { leaves[2], pref.."azalea_blossom.png" },
        },
    },
});

-- REGISTER DECORATION
natural_habitat.register_multideco("natural_habitat:deco_azalea", {
    shared = {
        smart_place = true,
        sidelen = 3,
        noise_params = {
            offset = 0,
            scale = 0.003,
            spread = {x = 250, y = 250, z = 250},
            seed = 7913*9,
            octaves = 3,
            persist = 0.001,
            flags = "absvalue",
        },
        spawn_by = { "air" },
        num_spawn_by = 5,
        y_max = 50,
        y_min = 1,
        flags = "place_center_x, place_center_z",
        decos = {
            { deco_type="simple", sidelen=1, decoration="natural_habitat:azalea_blossom", },
            
            { deco_type="schematic", sidelen=5, schematic=schempath.."/nbt_azalea_1.mts", },
            { deco_type="schematic", sidelen=3, schematic=schempath.."/nbt_azalea_2.mts", },
            { deco_type="schematic", sidelen=7, schematic=schempath.."/nbt_azalea_3.mts", },
        },
        force_placement = false,
        rotation = "random",
    },
    minetest = {
        place_on = { "default:dirt_with_grass", },
        replacements = {
            ["mcl_trees:tree_oak"] = "default:tree",
        },
        biomes = { "mellow_meadow" },
    },
    mineclonia = {
        place_on = { "mcl_core:dirt_with_grass", },
        --[[replacements = {
            ["natural_habitat:azalea_leaves"] = "mcl_trees:leaves_azalea",
            ["natural_habitat:azalea_blossom"] = "mcl_trees:leaves_azalea_flowering",
        },]]
        biomes = { "LushCaves", },
    },
});