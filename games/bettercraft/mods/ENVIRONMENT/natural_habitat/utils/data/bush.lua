local groups = { bush=1 };
if natural_habitat.is_minetest() then
    groups = { bush=1, snappy=3, flammable=2, leaves=1, blossoming=1, };
elseif natural_habitat.is_mineclonia() then
    groups = {
        bush=1, handy=1, swordy=1, dig_by_piston=1, deco_block=1, 
        flammable=2, fire_encouragement=30, fire_flammability=60,
        compostability=50, unsticky=1, blossoming=1, leaves=3,
    };
end;

local node_box = {type = "fixed", fixed = {{-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}}};

-- REGISTER BUSH
function natural_habitat.register_bush(id, data)

    for stage, def in pairs(data.stages) do
    
        if natural_habitat.is_minetest() then
            data.color = data.mst_color or stage.mst_color;
        elseif natural_habitat.is_mineclonia() then
            data.color = data.mcl_color or stage.mcl_color;
        end;
        
        core.register_node("natural_habitat:"..id.."_"..stage, {
            description = data.name.." "..def.description,
            drawtype = def.drawtype or data.drawtype or "mesh",
            waving = 2,
            mesh = def.mesh or data.mesh or "nbt_bush.obj",
            tiles = {
                {
                    name = def.textures[1] or "nbt_bush_leaves.png", 
                    color = def.color or data.color or "#FFFFFF",
                },
                {
                    name = def.textures[1] or "nbt_bush_leaves.png", 
                    color = def.color or data.color or "#FFFFFF",
                },
                def.textures[2] or "",
            },
            use_texture_alpha = "clip",
            drop = "",
            on_punch = function(pos, node, puncher, pointed_thing)
            
                natural_habitat.particle_punch(pos, "nbt_particle_leaf.png", {
                    { 
                        name = "nbt_particle_leaf.png", 
                        animation = { type="vertical_frames", aspect_w=5, aspect_h=5, length=1.3 },
                    }
                }, 1.5);
                
                if natural_habitat.is_minetest() then
                    if (core.get_item_group(puncher:get_wielded_item():get_name(), "sword") > 0) then
                        for i = 0, math.random(3) do
                            core.add_item( vector.add(
                                pos, vector.new(math.random()-0.5, 0, math.random()-0.5)
                                ), ItemStack(def.drop or natural_habitat.items.stick)
                            );
                            core.set_node(pos, { name="air" });
                        end;
                    end;
                end;
            end,
            after_dig_node = function(pos, oldnode, oldmetadata, digger)
                local dig_item = "natural_habitat:"..id.."_"..stage;
                
                if (core.get_item_group(digger:get_wielded_item():get_name(), "sword") > 0) then
                    for i = 0, math.random(5) do
                        core.add_item( vector.add(
                            pos, vector.new(math.random()-0.5, 0, math.random()-0.5)
                            ), ItemStack(def.drop or natural_habitat.items.stick)
                        );
                    end;
                else
                    if natural_habitat.is_minetest() then
                        natural_habitat.add_item_to_inventory(digger, dig_item);
                    elseif natural_habitat.is_mineclonia() then
                        core.add_item( vector.add(
                            pos, vector.new(math.random()-0.5, 0, math.random()-0.5)
                            ), ItemStack(dig_item)
                        );
                    end;
                end;
            end,
            paramtype = def.paramtype or data.paramtype or "light",
            paramtype2 = def.paramtype2 or data.paramtype2 or "facedir",
            walkable = def.walkable or data.walkable or true,
            buildable_to =  def.buildable_to or data.buildable_to or false,
            groups = def.groups or data.groups or groups,
            node_box = def.node_box or data.node_box or node_box,
            selection_box = def.node_box or data.node_box or node_box,
            on_place = natural_habitat.place_item,
            sounds = natural_habitat.sound_leaves(),
            _mcl_hardness = 0.2,
        });
    end;
end;