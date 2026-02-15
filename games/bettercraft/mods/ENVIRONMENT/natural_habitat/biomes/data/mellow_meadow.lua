local S = core.get_translator(core.get_current_modname());

if natural_habitat.is_minetest() then
    natural_habitat.register_biome({
        name = "mellow_meadow",
        
        node_top = "default:dirt_with_grass",
        node_top_underground = "default:stone",
        node_top_deep_underground = "default:stone",
        depth_top = 1,
        
        node_filler = "default:dirt",
        node_filler_underground = "default:stone",
        node_filler_deep_underground = "default:stone",
        depth_filler = 1,
        
        node_riverbed = "default:sand",
        depth_riverbed = 2,
        
        node_dungeon = "default:cobble",
        node_dungeon_alt = "default:mossycobble",
        node_dungeon_stair = "stairs:stair_cobble",
        
        vertical_blend = 3,
        
        heat_point = 46,
        humidity_point = 65,
    })
    
    local decorations = {
        "flowers:rose",
        "flowers:tulip",
        "flowers:tulip_black",
        "flowers:dandelion_white",
        "flowers:dandelion_yellow",
        "flowers:chrysanthemum_green",
        "flowers:geranium",
        "flowers:viola",
        "flowers:mushroom_red",
        "flowers:mushroom_brown",
    };
    
    for i, decoration in pairs(decorations) do
        core.register_decoration({
            deco_type = "simple",
            decoration = decoration,
            place_on = "default:dirt_with_grass",
            fill_ratio = 0.1/#decorations,
            biomes = { "mellow_meadow" },
            spawn_by = "air",
            num_spawn_by = 1,
            y_max = 0,
            y_min = 31000,
        });
    end;
end;