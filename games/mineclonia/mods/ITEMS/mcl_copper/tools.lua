local S = core.get_translator("mcl_copper")

mcl_tools.register_set("copper", {
        craftable = true,
        material = "mcl_copper:copper_ingot",
        uses = 191,
        level = 3,
        speed = 5,
        max_drop_level = 3,
        groups = { dig_speed_class = 3, enchantability = 5 }
}, {
    ["pick"] = {
        description = S("Copper Pickaxe"),
        inventory_image = "mcl_copper_tool_pick.png",
        tool_capabilities = {
            full_punch_interval = 0.83333333,
            damage_groups = { fleshy = 3 }
        }
    },
    ["shovel"] = {
        description = S("Copper Shovel"),
        inventory_image = "mcl_copper_tool_shovel.png",
        tool_capabilities = {
            full_punch_interval = 1,
            damage_groups = { fleshy = 3 }
        }
    },
    ["sword"] = {
        description = S("Copper Sword"),
        inventory_image = "mcl_copper_tool_sword.png",
        tool_capabilities = {
            full_punch_interval = 0.625,
            damage_groups = { fleshy = 5 }
        }
    },
    ["axe"] = {
        description = S("Copper Axe"),
        inventory_image = "mcl_copper_tool_axe.png",
        tool_capabilities = {
            full_punch_interval = 1.25,
            damage_groups = { fleshy = 9 }
        }
    },
    ["hoe"] = {
        description = S("Copper Hoe"),
        inventory_image = "mcl_copper_tool_hoe.png",
        tool_capabilities = {
            full_punch_interval = 0.5,
            damage_groups = { fleshy = 1, },
        },
    }

})
