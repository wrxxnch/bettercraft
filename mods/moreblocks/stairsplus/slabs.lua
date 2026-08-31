--[[
More Blocks: slab definitions

Copyright © 2011-2020 Hugo Locurcio and contributors.
Licensed under the zlib license. See LICENSE.md for more information.
--]]

-- Node will be called <modname>:slab_<subname>

local wood_slabs = {
    "mcl_trees:slab_wood_spruce",
    "mcl_trees:slab_wood_oak",
    "mcl_trees:slab_wood_pale_oak",
    "mcl_trees:slab_wood_warped",
    "mcl_trees:slab_wood_cherry_blossom",
    "mcl_trees:slab_wood_mangrove",
    "mcl_trees:slab_wood_crimson",
    "mcl_trees:slab_wood_bamboo",
    "mcl_trees:slab_wood_acacia",
}

for _, name in ipairs(wood_slabs) do
    local def = core.registered_nodes[name]

    if def then
        def.groups = def.groups or {}
        def.groups.wood_slab = 1
    else
        core.log("warning", "Slab não encontrado: " .. name)
    end
end

-- luacheck: no unused
local function register_slab(modname, subname, recipeitem, groups, images, description, drop, light)
	stairsplus:register_slab(modname, subname, recipeitem, {
		groups = groups,
		tiles = images,
		description = description,
		drop = drop,
		light_source = light,
		sounds = moreblocks.node_sound_stone_defaults(),
	})
end

function stairsplus:register_slab_alias(modname_old, subname_old, modname_new, subname_new)
	local defs = table.copy(stairsplus.defs["slab"])
	for alternate, def in pairs(defs) do
		minetest.register_alias(modname_old .. ":slab_" .. subname_old .. alternate, modname_new .. ":slab_" .. subname_new .. alternate)
	end
end

function stairsplus:register_slab_alias_force(modname_old, subname_old, modname_new, subname_new)
	local defs = table.copy(stairsplus.defs["slab"])
	for alternate, def in pairs(defs) do
		minetest.register_alias_force(modname_old .. ":slab_" .. subname_old .. alternate, modname_new .. ":slab_" .. subname_new .. alternate)
	end
end

function stairsplus:register_slab(modname, subname, recipeitem, fields)
	local defs = table.copy(stairsplus.defs["slab"])
	for alternate, shape in pairs(defs) do
		stairsplus.register_single("slab", alternate, shape, modname, subname, recipeitem, fields)
	end

	circular_saw.known_nodes[recipeitem] = {modname, subname}
end
