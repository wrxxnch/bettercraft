local S = core.get_translator(core.get_current_modname())
local schempath = natural_habitat.schempath(true)

-- ===============================
-- GROUPS
-- ===============================

local groups = {}

if natural_habitat.is_minetest() then
    groups = {
        tree = 1,
        choppy = 2,
        oddly_breakable_by_hand = 1,
        flammable = 2,
        burnt_log = 1,
    }
elseif natural_habitat.is_mineclonia() then
    groups = {
        handy = 1,
        axey = 1,
        material_wood = 1,
        burnt_log = 1,
        flammable = 3,
        fire_encouragement = 5,
        fire_flammability = 20,
    }
end

-- ===============================
-- FUNÇÃO DE COLOCAÇÃO COM ROTAÇÃO
-- ===============================

local function place_with_rotation(itemstack, placer, pointed_thing)
    if not pointed_thing or pointed_thing.type ~= "node" then
        return minetest.item_place(itemstack, placer, pointed_thing)
    end

    -- Calcula a direção baseada na face clicada (vetor entre 'under' e 'above')
    local p0 = pointed_thing.under
    local p1 = pointed_thing.above
    local dir = {
        x = p1.x - p0.x,
        y = p1.y - p0.y,
        z = p1.z - p0.z
    }

    -- O parâmetro 'true' é essencial para habilitar as 6 direções (eixos X, Y e Z)
    local facedir = minetest.dir_to_facedir(dir, true)

    return minetest.item_place(itemstack, placer, pointed_thing, facedir)
end

-- ===============================
-- BURNT LOG
-- ===============================

natural_habitat.register_multinode("natural_habitat:burnt_log", {
    shared = {
        paramtype = "light",
        paramtype2 = "facedir",
        groups = groups,
        on_place = place_with_rotation,
        sounds = natural_habitat.sound_wood(),
    },

    nodes = {
        [""] = {
            description = S("Burnt Tree Log"),
            drawtype = "nodebox",
            tiles = {
                "nbt_burned_log_top.png",
                "nbt_burned_log_top.png",
                "nbt_burned_log_side.png",
            },
        },

        ["_broken"] = {
            description = S("Burnt Tree Broken Log"),
            drawtype = "mesh",
            mesh = "nbt_broken_log.obj",
            use_texture_alpha = "clip",
            tiles = {
                "nbt_burned_log_side.png",
                "nbt_burned_log_top.png",
                "nbt_burned_log_up.png",
            },
            selection_box = {
                type = "fixed",
                fixed = {-0.5, -0.5, -0.5, 0.5, 0.25, 0.5}
            },
            collision_box = {
                type = "fixed",
                fixed = {-0.5, -0.5, -0.5, 0.5, 0.25, 0.5}
            },
        },
    },

    mineclonia = {
        _mcl_hardness = 3,
    },
})

-- ===============================
-- BURNT WOOD
-- ===============================

natural_habitat.register_multinode("natural_habitat:burnt_wood", {
    shared = {
        paramtype2 = "facedir",
        is_ground_content = false,
        on_place = place_with_rotation,
        sounds = natural_habitat.sound_wood(),
    },

    nodes = {
        [""] = {
            description = S("Burnt Wood Planks"),
            tiles = { "nbt_burnt_wood.png" },
        }
    },

    minetest = {
        groups = {
            choppy = 2,
            oddly_breakable_by_hand = 2,
            flammable = 2,
            wood = 1
        },
    },

    mineclonia = {
        groups = {
            handy = 1,
            axey = 1,
            material_wood = 1,
            wood = 1,
            building_block = 1,
            flammable = 3,
            fire_encouragement = 5,
            fire_flammability = 20
        },
    },
})

-- ===============================
-- CRAFTS
-- ===============================

core.register_craft({
    output = "natural_habitat:burnt_wood 4",
    type = "shapeless",
    recipe = { "natural_habitat:burnt_log" },
})

core.register_craft({
    output = "natural_habitat:burnt_wood 3",
    type = "shapeless",
    recipe = { "natural_habitat:burnt_log_broken" },
})

-- ===============================
-- REGISTER DECORATION
-- ===============================

natural_habitat.register_multideco("natural_habitat:deco_burnt_log", {
    shared = {
        sidelen = 1,
        fill_ratio = 0.02,
        place_offset_y = 0,
        spawn_by = { "air" },
        num_spawn_by = 1,
        flags = "place_center_x, place_center_z, force_placement",
        biomes = {},
        decos = {
            { deco_type = "schematic", sidelen = 1, schematic = schempath.."/nbt_burnt_tree_1.mts" },
            { deco_type = "schematic", sidelen = 1, schematic = schempath.."/nbt_burnt_tree_2.mts" },
            { deco_type = "schematic", sidelen = 7, schematic = schempath.."/nbt_burnt_tree_3.mts" },
            { deco_type = "schematic", sidelen = 6, schematic = schempath.."/nbt_burnt_tree_4.mts" },
            { deco_type = "schematic", sidelen = 5, schematic = schempath.."/nbt_burnt_tree_5.mts" },
            { deco_type = "schematic", sidelen = 3, schematic = schempath.."/nbt_burnt_tree_6.mts" },
        },
        place_on = { "natural_habitat:ash" },
        force_placement = true,
        rotation = "random",
    },

    minetest = {},
    mineclonia = {},
})
