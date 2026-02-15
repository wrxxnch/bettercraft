if natural_habitat.is_minetest() then

    -- MINETEST - MUSHROOMS
    for i, mushroom in pairs({ "mushroom_brown", "mushroom_red" }) do
        core.override_item("flowers:"..mushroom, {
            drawtype = "mesh",
            mesh = "mts_"..mushroom..".obj",
            selection_box = {
                type = "fixed",
                fixed = { -4/16, -0.5, -4/16, 4/16, -2/16, 4/16},
            },
        });
    end;
    
    -- MINETEST - BUSH
    for item, tiles in pairs({
        ["default:bush_leaves"] = {
            "default_leaves_simple.png", "default_leaves_simple.png",
        },
        ["default:blueberry_bush_leaves"] = {
            "default_blueberry_bush_leaves.png", 
            "default_blueberry_bush_leaves.png",
        },
        ["default:blueberry_bush_leaves_with_berries"] = {
            "default_blueberry_bush_leaves.png^default_blueberry_overlay.png", 
            "default_blueberry_bush_leaves.png",
        },
        ["default:acacia_bush_leaves"] = {
            "default_acacia_leaves_simple.png", "default_acacia_leaves_simple.png",
        },
        ["default:pine_bush_needles"] = {
            "default_pine_needles.png", "default_pine_needles.png",
        },
    }) do
        core.override_item(item, {
            drawtype = "mesh",
            mesh = "nbt_bush.obj",
            tiles = tiles,
            waving = 2,
            use_texture_alpha = "clip",
            on_punch = function(pos, node, puncher, pointed_thing)
            
                natural_habitat.particle_punch(pos, "nbt_particle_leaf.png", {
                    { 
                        name = "nbt_particle_leaf.png", 
                        animation = { type="vertical_frames", aspect_w=5, aspect_h=5, length=1.3 },
                    }
                }, 1.5);
                
                if (core.get_item_group(puncher:get_wielded_item():get_name(), "sword") > 0) then
                    for i = 0, math.random(2) do
                        core.add_item( vector.add(
                            pos, vector.new(math.random()-0.5, 0, math.random()-0.5)
                            ), ItemStack(natural_habitat.stick)
                        );
                    end;
                    if (node.name == "default:blueberry_bush_leaves_with_berries") then
                        core.add_item( vector.add(
                            pos, vector.new(math.random()-0.5, 0, math.random()-0.5)
                            ), ItemStack("default:blueberries")
                        );
                    end;
                    core.set_node(pos, { name="air" });
                end;
            end,
        });
    end;
    
elseif natural_habitat.is_mineclonia() then

    -- MINECLONIA - MUSHROOMS
    for i, mushroom in pairs({ "mushroom_brown", "mushroom_red" }) do
        core.override_item("mcl_mushrooms:"..mushroom, {
            drawtype = "mesh",
            mesh = "mcl_"..mushroom..".obj",
            selection_box = {
                type = "fixed",
                fixed = { -4/16, -0.5, -4/16, 4/16, -2/16, 4/16},
            },
        });
    end;
    
end;