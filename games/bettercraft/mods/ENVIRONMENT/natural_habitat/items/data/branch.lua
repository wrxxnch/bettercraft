local S = core.get_translator(core.get_current_modname());

local groups = {};
if natural_habitat.is_minetest() then
    groups = { tree=1, choppy=2, oddly_breakable_by_hand=1, flammable=2, };
elseif natural_habitat.is_mineclonia() then
    groups = {
        handy=1, axey=1, material_wood=1,
        flammable=3, fire_encouragement=5, fire_flammability=20,
    };
end;

for tree, id in pairs(natural_habitat.trees) do
    local node = core.registered_nodes[id];
    if node then
        core.register_node("natural_habitat:branch_"..tree, {
            description = S("Branch "..string.to_name(tree)),
            tiles = { node.tiles[3] },
            drawtype = "mesh",
            mesh = "nbt_branch.obj",
            paramtype = "light",
            paramtype2 = "facedir",
            is_ground_content = false,
            groups = groups,
            sounds = natural_habitat.sound_wood(),
        })
    end;
end;