local S = core.get_translator(core.get_current_modname());
local schempath = natural_habitat.schempath(true);

local log_groups, leaves_groups, coconut_groups, coconut_hanging_groups = {}, {}, {}, {};
if natural_habitat.is_minetest() then
    log_groups = { tree=1, choppy=2, oddly_breakable_by_hand=1, flammable=2, };
    coconut_hanging_groups = { choppy=2, oddly_breakable_by_hand=1, flammable=2, };
    coconut_groups = { snappy=1, flammable=1, falling_node=1, };
    leaves_groups = { snappy=1, flammable=1 };
elseif natural_habitat.is_mineclonia() then
    log_groups = {
        handy=1, axey=1, material_wood=1, 
        flammable=3, fire_encouragement=5, fire_flammability=20, 
    };
    coconut_hanging_groups = {
        handy=1, axey=1, material_wood=1, 
        flammable=3, fire_encouragement=5, fire_flammability=10, 
    };
    coconut_groups = {
        handy=1, deco_block=1, compostability=65, falling_node=1,
    };
    leaves_groups = { handy=1, food=2, deco_block=1, compostability=65, };
end;

core.register_node("natural_habitat:coconut_palmtree_log", {
    description = S("Coconut Palmtree Log"),
    drawtype = "mesh",
    mesh = "nbt_palmtree_log.obj",
    tiles = {
        "nbt_coconut_palm_log_side.png", 
        "nbt_coconut_palm_log_top.png",
        "nbt_coconut_palm_log_bottom.png",
    },
    paramtype = "light",
    paramtype2 = "facedir",
    selection_box = { type="fixed", fixed={-0.4, -0.5, -0.4, 0.4, 0.5, 0.4} },
    collision_box = { type="fixed", fixed={-0.4, -0.5, -0.4, 0.4, 0.5, 0.4} },
    groups = log_groups,
    sunlight_propagates = true,
    sounds = natural_habitat.sound_leaves(),
    _mcl_hardness = 3;
});

core.register_node("natural_habitat:coconut_palmtree_leaves", {
    description = S("Coconut Palmtree Leaves"),
    drawtype = "mesh",
    mesh = "nbt_palmtree_leaves.obj",
    tiles = {"nbt_coconut_palmtree_leaves.png"},
    paramtype = "light",
    paramtype2 = "facedir",
    groups = leaves_groups,
    use_texture_alpha = "clip",
    sunlight_propagates = true,
    walkable = false,
    drop = "",
    selection_box = { type = "fixed", fixed={-0.5, -0.5, -1.5, 0.5, 0.4, 0.5} },
    sounds = natural_habitat.sound_wood(),
    _mcl_hardness = 1;
});

natural_habitat.register_multinode("natural_habitat:coconut", {
    shared = {
        drawtype = "mesh",
        inventory_image = "nbt_coconut.png",
        tiles = { "nbt_coconut_texture.png", },
        paramtype = "light",
        paramtype2 = "facedir",
        sounds = natural_habitat.sound_wood(),
    },
    nodes = {
        [""] = {
            description = S("Coconut"),
            mesh = "nbt_coconut.obj";
            groups = coconut_groups,
            selection_box = { type="fixed", fixed={-0.3, -0.5, -0.3, 0.3, 0.2, 0.3} },
            collision_box = { type="fixed", fixed={-0.3, -0.5, -0.3, 0.3, 0.2, 0.3} },
            _mcl_hardness = 0,
        },
        ["_hanging"] = {
            description = S("Coconut Hanging"),
            mesh = "nbt_coconut_hanging.obj";
            drop = "natural_habitat:coconut",
            groups = coconut_hanging_groups,
            selection_box = { type="fixed", fixed={-0.3, -0.35, 0, 0.3, 0.3, 0.6} },
            collision_box = { type="fixed", fixed={-0.3, -0.35, 0, 0.3, 0.3, 0.6} },
            _mcl_hardness = 1,
        },
    },
});

core.register_abm({
    label = "Spawn Coconut",
    nodenames = { "natural_habitat:coconut_palmtree_leaves" },
    neighbors = { "natural_habitat:coconut_palmtree_log" },
    interval = 10.0,
    chance = 70,
    action = function(pos, node, active_object_count, active_object_count_wider)
        core.set_node(
            vector.offset(pos, 0, -1, 0),
            {name="natural_habitat:coconut_hanging", param2=node.param2}
        );
    end,
});

core.register_abm({
    label = "Despawn Palmtree Leaves",
    nodenames = { "natural_habitat:coconut_palmtree_leaves" },
    without_neighbors = { "natural_habitat:coconut_palmtree_log" },
    interval = 1.0,
    chance = 1,
    action = function(pos, node, active_object_count, active_object_count_wider)
        core.set_node(pos, {name="air"} );
    end,
});

core.register_abm({
    label = "Coconut Hanging",
    nodenames = { "natural_habitat:coconut_hanging" },
    without_neighbors = { "natural_habitat:coconut_palmtree_leaves" },
    interval = 1.0,
    chance = 1,
    action = function(pos, node, active_object_count, active_object_count_wider)
        core.set_node(pos, {name="natural_habitat:coconut"} );
        core.check_for_falling(pos);
    end,
});

-- REGISTER DECORATION
natural_habitat.register_multideco("natural_habitat:deco_coconut_palmtree", {
    shared = {
        smart_place = true,
        sidelen = 1,
        fill_ratio = 0.005,
        spawn_by = { "air" },
        num_spawn_by = 1,
        decos = {
            { deco_type="schematic", schematic=schempath.."/nbt_coconut_palmtree_1.mts", },
            { deco_type="schematic", schematic=schempath.."/nbt_coconut_palmtree_2.mts", },
            { deco_type="schematic", schematic=schempath.."/nbt_coconut_palmtree_3.mts", },
        },
        avoid_nodes = { "natural_habitat:coconut_palmtree_log" },
        avoid_radius = 3,
        pursue_radius = 5,
        y_min = 2,
        y_max = 50,
    },
    minetest = {
        biomes = { 
            "coniferous_forest_dunes", "coniferous_forest_ocean", "sandstone_desert",
            "desert", "desert_ocean", "rainforest", "rainforest_ocean", 
        },
        place_on = {
            "default:dirt_with_grass", "default:dry_dirt_with_dry_grass", 
            "default:dirt_rainforest_litter", "default:sand",
        },
        pursue_nodes = { "default:water_source", },
    },
    mineclonia = {
        biomes = { "Desert", "JungleEdge", },
        place_on = {
            "mcl_core:dirt_with_grass", "mcl_core:sand", 
        },
        place_offset_y = 1,
        pursue_nodes = { "mcl_core:water_source", },
    },
});

local S = core.get_translator(core.get_current_modname())

core.register_craftitem("natural_habitat:coconut_water", {
    description = S("Coconut Water"),
    inventory_image = "natural_habitat_coconut_water.png",
    groups = { 
        food = 2, 
        eatable = 6, 
        drink = 1,
        compostability = 40 
    },
    on_secondary_use = function(itemstack, user, pointed_thing)

        return core.do_item_eat(6, nil, itemstack, user, pointed_thing)
    end,
})

-- Receita: Stick em cima do Coco
core.register_craft({
    output = "natural_habitat:coconut_water",
    recipe = {
        {"mcl_core:stick"},
        {"natural_habitat:coconut"},
    }
})

local schems = {
    schempath .. "/nbt_coconut_palmtree_1.mts",
    schempath .. "/nbt_coconut_palmtree_2.mts",
    schempath .. "/nbt_coconut_palmtree_3.mts",
}

for _, schem in ipairs(schems) do

    minetest.register_decoration({
        name = "natural_habitat:coconut_palmtree",

        deco_type = "schematic",
        place_on = {
            "default:dirt_with_grass",
            "default:dry_dirt_with_dry_grass",
            "default:dirt_rainforest_litter",
            "default:sand",
        },

        sidelen = 16,
        fill_ratio = 0.005,

        biomes = {
            "sandstone_desert",
            "desert",
            "desert_ocean",
        },

        y_min = 2,
        y_max = 50,

        schematic = schem,
        flags = "place_center_x, place_center_z",

        rotation = "random",
    })

end
