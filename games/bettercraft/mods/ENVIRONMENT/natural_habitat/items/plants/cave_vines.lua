local S = core.get_translator(core.get_current_modname());

local y_min, y_max = natural_habitat.get_world_hight();
local def = {
    biomes = {
        "Forest_underground", "Forest_deep_underground", "Forest_ocean",
        "coniferous_forest_under", "deciduous_forest_under",
    },
    y_min = y_min,
};

if natural_habitat.is_minetest() then
    def.groups = { snappy=3, deco_block=1, flammable=1 };
    def.place_on = {
        "default:mossycobble", "default:cobble", "default:stone",
    };
elseif natural_habitat.is_mineclonia() then
    def.groups = {
        handy=1, plant=1, dig_by_water=1, destroy_by_lava_flow=1, 
        dig_by_piston=1, deco_block=1, 
    };
    def.place_on = {
        "mcl_core:mossycobble", "mcl_core:cobble", "mcl_core:stone",
        "mcl_deepslate:deepslate"
    };
end;

core.register_node("natural_habitat:cave_vines", {
    description = S("Cave Rooted Vines"),
    _doc_items_create_entry = S("Cave rooted vines"),
    _doc_items_entry_name = S("Cave rooted vines"),
    _doc_items_longdesc = S("Cave vines are decorative blocks growing from the ceiling of caves."),
    _doc_items_hidden = false,
    drawtype = "plantlike",
    tiles = {"nbt_cave_vines.png"},
    inventory_image = "nbt_cave_vines.png",
    wield_image = "nbt_cave_vines.png",
    paramtype = "light",
    paramtype2 = "facedir",
    walkable = false,
    climbable = true,
    selection_box = { type = "fixed", fixed = {{-7/16, -0.5, -7/16, 7/16, 0.5, 7/16}},},
    on_place = natural_habitat.place_on_ceiling,
    groups = def.groups,
    sounds = natural_habitat.sound_leaves(),
    _mcl_hardness = 3,
})


core.register_decoration({
    deco_type = "simple",
    decoration = "natural_habitat:cave_vines",
    place_on = def.place_on,
    fill_ratio = 0.01,
    biomes = def.biomes or {},
    spawn_by = "air",
    num_spawn_by = 2,
    height = 1,
    height_max = 5,
    flags = "all_ceilings",
    y_max = 0,
    y_min = def.y_min/2,
});