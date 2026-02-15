local schempath = natural_habitat.schempath();

natural_habitat.register_multideco("natural_habitat:deco_boulder", {
    shared = {
        deco_type = "schematic",
        smart_place = natural_habitat.is_minetest(),
        
        fill_ratio = 0.0003,
        sidelen = 2,
        
        spawn_by = { "air" },
        num_spawn_by = 5,
        
        avoid_nodes = {
            "mcl_core:grass_path",
            "natural_habitat:coconut_palmtree_log",
            "mcl_trees:tree_oak",
        },
        avoid_radius = 3,
        
        y_max = 50,
        y_min = 1,
    },
    minetest = {
        place_on = { "default:dirt_with_grass", "default:dry_dirt_with_dry_grass" },
        place_offset_y = -4,
        decos = {
            {schematic = schempath.."/mts_boulder_1.mts"},
            {schematic = schempath.."/mts_boulder_2.mts"},
        },
    },
    mineclonia = {
        place_on = { "mcl_core:dirt_with_grass" },
        place_offset_y = -6,
        decos = {
            {schematic = schempath.."/mcl_boulder_1.mts"}, 
            {schematic = schempath.."/mcl_boulder_2.mts"}, 
            {schematic = schempath.."/mcl_boulder_3.mts"}, 
            {schematic = schempath.."/mcl_boulder_4.mts"},
        },
    },
});