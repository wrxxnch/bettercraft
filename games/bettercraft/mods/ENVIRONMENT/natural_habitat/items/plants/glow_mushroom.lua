local S = core.get_translator(core.get_current_modname());

local def = {
    description = S("Glow Mushroom"),
    inventory_image = "nbt_glow_mushroom_inv.png",
    drawtype = "mesh",
    mesh = "nbt_glow_mushroom.obj",
    tiles = {"nbt_glow_mushroom.png"},
    paramtype = "light",
    paramtype2 = "facedir",
    sunlight_propagates = true,
    walkable = false,
    light_source = 7,
    sounds = natural_habitat.sound_leaves(),

    y_mix = -31000,

    selection_box = {
        type = "fixed",
        fixed = { -0.4, -0.5, -0.4, 0.4, 0.3, 0.4 },
    },
}


if natural_habitat.is_minetest() then
    def.groups = { mushroom=1, food_mushroom=1, snappy=1, attached_node=1, flammable=1 };
    def.place_on = {
        "default:mossycobble", "default:cobble", "default:stone",
    };
    def.on_use = function(itemstack, user, pointed_thing)
        return core.do_item_eat(2, nil, itemstack, user, pointed_thing);
    end;
    def.on_place = natural_habitat.place_item;
    def.y_mix = -31000;
elseif natural_habitat.is_mineclonia() then
    def.groups = {
        handy=1, food=2, eatable=2, attached_node=1, deco_block=1, 
        destroy_by_lava_flow=1, dig_by_water=1, dig_by_piston=1, 
        unsticky=1, mushroom=1, enderman_takable=1, compostability=65,
    };
    def.place_on = {
        "mcl_core:mossycobble", "mcl_core:cobble", "mcl_core:stone",
        "mcl_deepslate:deepslate"
    };
    def.on_place = function(itemstack, placer, pointed_thing)
        if not pointed_thing.under then
            return core.do_item_eat(2, nil, itemstack, placer, pointed_thing);
        end
        
        return natural_habitat.place_item(itemstack, placer, pointed_thing);
    end;
    def.y_mix = mcl_vars.mg_overworld_min;
    def._mcl_hardness = 0;
    def._mcl_saturation = 1.2;
end;

core.register_node("natural_habitat:mushroom_glow", def);

core.register_decoration({
    deco_type = "simple",
    decoration = "natural_habitat:mushroom_glow",
    place_on = def.place_on,
    fill_ratio = 0.005,
    biomes = def.biomes or {},
    spawn_by = "air",
    num_spawn_by = 1,
    flags = "all_floors",
    y_max = 0,
    y_min = def.y_mix/2,
    rotation = "random",
});

core.register_decoration({
    deco_type = "simple",
    decoration = "natural_habitat:mushroom_glow",
    place_on = def.place_on,
    fill_ratio = 0.02,
    biomes = def.biomes or {},
    spawn_by = "air",
    num_spawn_by = 1,
    flags = "all_floors",
    y_max = def.y_mix/2,
    y_min = def.y_mix,
    rotation = "random",
});