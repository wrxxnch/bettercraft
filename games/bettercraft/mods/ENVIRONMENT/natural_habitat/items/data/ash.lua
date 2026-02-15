local S = core.get_translator(core.get_current_modname());

local node_box = { type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, 0, 0.5} };

core.register_node("natural_habitat:ash", {
    description = S("Ash"),
    _doc_items_longdesc = S(""),
    _doc_items_hidden = false,
    tiles = {"nbt_ash.png"},
    drawtype = "nodebox",
    paramtype = "light",
    groups = { dig_immediate=3, attached_node=1, falling_node=1, },
    buildable_to = true,
    node_box = node_box,
    selection_box = node_box,
    collision_box = node_box,
    sounds = natural_habitat.sound_wool(),
    on_dig = function(pos, node, digger)
        natural_habitat.particle_explode(pos, "nbt_ash_particle.png", {
            { 
                name = "nbt_ash_particle.png", 
                animation = { type="vertical_frames", aspect_w=16, aspect_h=16, length=1.1 },
            }
        }, 3, 5, 36);
        core.set_node(pos, {name="air"});
    end,
    drop = "",
    _mcl_hardness = 0,
})