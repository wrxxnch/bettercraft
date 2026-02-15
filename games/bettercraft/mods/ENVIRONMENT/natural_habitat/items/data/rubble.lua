local S = core.get_translator(core.get_current_modname());

local y_min, y_max = natural_habitat.get_world_hight();
local place_on = {
    -- MINETEST
    "default:dirt", "default:dirt_with_grass", "default:dry_dirt", "default:sand", 
    "default:permafrost", "default:cobble", "default:stone", "default:mossycobble", 
    "default:sandstone", "default:dirt_with_snow", "default:dry_dirt_with_dry_grass", 
    "default:dirt_with_rainforest_litter", 
    -- MINECLONIA
    "mcl_core:dirt", "mcl_core:dirt_with_grass", "mcl_core:mycelium",
    "mcl_core:podzol", "mcl_core:coarse_dirt", "mcl_core:mossycobble",
    "mcl_core:stone", "mcl_core:cobble", "mcl_deepslate:deepslate",
};
local stones = {
    stone = {
        texture = "default_stone.png",
        blocks = {
            -- MINETEST
            "default:cobble", "default:stone", "default:stonebrick",
            -- MINECLONIA
            "mcl_core:cobble", "mcl_core:stone",
        },
        biomes = {
            -- MINETEST
            "grassland", "coniferous_forest", "deciduous_forest",
            "savanna", "rainforest", "snowy_grassland",
            -- MINECLONIA
            "Plains", "FlowerForest", "Underground", "ExtremeHills", "Jungle", "JungleEdge", 
            "Taiga", "Forest", "BirchForest", "MegaTaiga", "MegaSpruceTaiga", "ExtremeHills+", 
            "StoneBeach", "Savanna", "Meadow", "PaleGraden",
        },
    },
    mossystone = {
        texture = "default_mossycobble.png",
        blocks = {
            -- MINETEST
            "default:mossycobble",
            -- MINECLONIA
            "mcl_core:mossycobble", "mcl_core:stonebrickmossy",
        },
    },
    
};


local function get_texture(def)
    if natural_habitat.is_minetest() then
        return def.mts_texture or def.texture;
    elseif natural_habitat.is_mineclonia() then
        return def.mcl_texture or def.texture;
    end; return def.texture;
end;

-- REGISTER RUBBLE
for stone, def in pairs(stones) do
    for i, block in pairs(def.blocks) do
        if def.blocks[i] and (core.registered_nodes[def.blocks[i]]) then
            local rubble_name = "natural_habitat:"..stone.."_rubble";
            
            core.register_node(rubble_name, {
                description = S(string.to_name(stone)).." "..S("Rubble"),
                drawtype = "mesh",
                mesh = "nbt_rubble.obj",
                tiles = { get_texture(def) },
                color = "#CCCCCC",
                paramtype = "light",
                paramtype2 = "facedir",
                walkable = false,
                sunlight_propagates = true,
                groups = { dig_immediate=3, attached_node=1, rubble=1, rock=1, falling_node=1 },
                node_box = {type = "fixed", fixed = {{-0.4, -0.5, -0.4, 0.4, -0.2, 0.4}}},
                selection_box = {type = "fixed", fixed = {{-0.4, -0.5, -0.4, 0.4, -0.2, 0.4}}},
                on_place = natural_habitat.place_item,
                sounds = natural_habitat.sound_stone(),
                _mcl_hardness = 0;
            });

            -- CRAFT RUBBLE
            for i, stone in pairs(def.blocks) do
                if (core.registered_nodes[stone]) then
                    core.register_craft({
                        output = rubble_name.." 36",
                        recipe = { 
                            { stone, stone },
                            { stone, stone },
                        },
                    })
                end;
            end;
            
            -- CRAFT BLOCK
            core.register_craft({
                output = def.blocks[i],
                recipe = {
                    {rubble_name, rubble_name, rubble_name},
                    {rubble_name, rubble_name, rubble_name},
                    {rubble_name, rubble_name, rubble_name},
                },
            });
            
            -- REGISTER DECORATION
            for i, rubble in pairs({
                {
                    biomes={}, fill_ratio=0.01, 
                    place_on=def.blocks, 
                    spawn_by="air", 
                },
                { 
                    biomes={}, fill_ratio=0.002, 
                    place_on=def.place_on or place_on, 
                    spawn_by=def.blocks, 
                },
                {
                    biomes=def.biomes, fill_ratio=0.005, 
                    place_on=def.place_on or place_on, 
                    spawn_by="air", 
                },
            }) do
                if rubble.biomes then
                    core.register_decoration({
                        deco_type = "simple",
                        decoration = "natural_habitat:"..stone.."_rubble",
                        place_on = rubble.place_on,
                        fill_ratio = rubble.fill_ratio,
                        biomes = rubble.biomes,
                        spawn_by = rubble.spawn_by,
                        num_spawn_by = 1,
                        flags = "all_floors",
                        y_min = def.y_min or y_min,
                        y_max = def.y_max or y_max,
                    })
                end;
            end;
            break;
        end;
    end;
end;