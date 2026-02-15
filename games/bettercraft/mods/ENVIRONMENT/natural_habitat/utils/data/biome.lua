local y_min, y_max = natural_habitat.get_world_hight();
local water_source = natural_habitat.get_item("default:water_source", "mcl_core:water_source");
-- REGISTER BIOME
function natural_habitat.register_biome(def)
    for i, stage in pairs({
        {
            name=def.name,
            node_top = def.node_top,
            y_max = y_max,
            y_min = 3,
        },
        {
            name=def.name.."_shore",
            node_top = def.node_top_shore or def.node_riverbed,
            node_filler = def.node_filler_shore or def.node_riverbed,
            y_max = 3,
            y_min = 0,
        },
        {
            name = def.name.."_ocean",
            node_top = def.node_top_shore or def.node_riverbed,
            node_filler = def.node_filler_shore or def.node_riverbed,
            depth_riverbed = 2,
            node_cave_liquid = def.node_cave_liquid or water_source,
            y_max = 0,
            y_min = (y_min/2)/4,
        },
        {
            name = def.name.."_underground",
            node_top = def.node_top_underground,
            node_filler = def.node_filler_underground,
            y_max = (y_min/2)/4,
            y_min = ((y_min/2)/4)*3,
        },
        {
            name = def.name.."_deep_underground",
            node_top = def.node_top_deep_underground,
            node_filler = def.node_filler_deep_underground,
            y_max = ((y_min/2)/4)*3,
            y_min = y_min,
        },
    }) do
        def = table.copy(def);
        for key, value in pairs(stage) do
            def[key] = value;
        end;
        
        core.register_biome(def);
    end;
end;