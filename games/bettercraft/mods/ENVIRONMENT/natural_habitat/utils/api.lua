local modpath = core.get_modpath(core.get_current_modname());

local normal_inits = {
    [tostring(vector.new( 0, 1, 0))] = "top",
    [tostring(vector.new( 0,-1, 0))] = "bottom",
    [tostring(vector.new( 0, 0, 1))] = "front",
    [tostring(vector.new( 0, 0,-1))] = "back",
    [tostring(vector.new( 1, 0, 0))] = "right",
    [tostring(vector.new(-1, 0, 0))] = "left",
};

-- IS GAME
function natural_habitat.is_minetest() return core.get_game_info().id == "minetest"; end;
function natural_habitat.is_mineclonia() return core.get_game_info().id == "mineclonia"; end;

-- GET PREF
function natural_habitat.get_pref()
    if natural_habitat.is_minetest() then
        return "mts_"
    elseif natural_habitat.is_mineclonia() then
        return "mcl_"
    end;
    return "";
end;

-- SCHEMPATH
function natural_habitat.schempath(spfc)
    if natural_habitat.is_minetest() and (not spfc) then
        return modpath.."/schems/minetest";
    elseif natural_habitat.is_mineclonia() and (not spfc) then
        return modpath.."/schems/mineclonia";
    end;
    return modpath.."/schems";
end;

-- GET WORLD HEIGHT
function natural_habitat.get_world_hight()
    local y_min, y_max = -31000, 31000;
    
    if natural_habitat.is_mineclonia() and 
    core.get_modpath("mcl_vars") then
        y_min = mcl_vars.mg_overworld_min;
        y_max = mcl_vars.mg_overworld_max;
    end;
    
    return y_min, y_max;
end;

-- GET NETHER HEIGHT
function natural_habitat.get_nether_hight()
    local y_min, y_max = -31000, 31000;
    
    if natural_habitat.is_mineclonia() and 
    core.get_modpath("mcl_vars") then
        y_min = mcl_vars.mg_nether_min;
        y_max = mcl_vars.mg_nether_max;
    end;
    
    return {y_min=y_min, y_max=y_max};
end;

-- GAME IMPACT
function natural_habitat.game_impact(minetest, mineclonia)
    if natural_habitat.is_minetest() then
        return minetest;
    elseif natural_habitat.is_mineclonia() then
        return mineclonia;
    end; return nil;
end;

-- GET ITEM
function natural_habitat.get_item(minetest_item, mineclonia_item)
    if core.registered_nodes[minetest_item] or 
        core.registered_items[minetest_item] then
            return minetest_item;
    elseif core.registered_nodes[mineclonia_item] or 
        core.registered_items[mineclonia_item] then
            return mineclonia_item;
    end; return nil;
end;

-- CHECK ON RIGHT CLICK
function natural_habitat.check_on_rightclick(pos, itemstack, placer)
    if placer and placer:is_player() then
        local node = core.get_node(pos);
        local nodedef = core.registered_nodes[node.name];
        if nodedef.on_rightclick and (not placer:get_player_control().sneak) then
            return nodedef.on_rightclick(pos, node, placer) or itemstack;
        end;
    end;
    return nil;
end;

-- TAKE ITEM
function natural_habitat.take_item(player, itemstack)
    if not core.is_creative_enabled(player:get_player_name()) then
        itemstack:take_item();
    end;
end;

-- PLACE ITEM
function natural_habitat.place_item(itemstack, user, pointed_thing, replacement) 
    if pointed_thing then
        local pos = pointed_thing.above;
        if core.get_node_or_nil(pointed_thing.under) then
            local node_under = core.get_node(pointed_thing.under).name;
            if (core.registered_nodes[node_under].buildable_to == true) then
                pos = pointed_thing.under;
            end;
        elseif core.get_node_or_nil(pos) then
            local node = core.get_node(pos).name;
            if (core.registered_nodes[node].buildable_to ~= true) then
                return itemstack;
            end;
        end;
        
        local param2 = core.dir_to_facedir(user:get_look_dir()) % 4;
        local item_name = replacement or itemstack:get_name();
        
        if item_name then
            local on_rightclick = natural_habitat.check_on_rightclick(pos, itemstack, user);
            if on_rightclick then return on_rightclick; end;
    
            core.set_node(pos, {name=item_name, param2=param2});
            
            if core.get_item_group(item_name, "group:falling_node") then
                core.check_for_falling(pos);
            end;
            
            natural_habitat.take_item(user, itemstack);
        end;
    end;
    
    return itemstack;
end

-- GET PLAYER EYE POS
function natural_habitat.get_player_eye_pos(player)
    local eye_pos = player:get_pos();
    eye_pos.y = eye_pos.y + player:get_properties().eye_height;
    local first, third = player:get_eye_offset();
    eye_pos = vector.add(eye_pos, vector.divide(first, 10));
    return eye_pos;
end;

-- GET POINTED NODE WITH POINTED SIDE OF BLOCK
function natural_habitat.get_pointed_node(player)
    local pointed_node = {};
    
    local eye_pos = natural_habitat.get_player_eye_pos(player);
    local look_at = vector.add(
        eye_pos, vector.multiply(
            player:get_look_dir(), 
            player:get_wielded_item():get_definition().range or 8
        )
    );

    for pointed_thing in core.raycast(eye_pos, look_at, true, false) do
        if pointed_thing.ref ~= player then
            local node = core.get_node(pointed_thing.under);
            if node then
                pointed_node.node = node;
                pointed_node.name = node.name;
                pointed_node.def = core.registered_nodes[node.name];
                pointed_node.pointed_side = normal_inits[tostring(pointed_thing.intersection_normal)];
                break;
            end;
        end
    end

    return pointed_node;
end;

-- PLACE ITEM ON CEILING
function natural_habitat.place_on_ceiling(itemstack, user, pointed_thing, replacement)
    local pos = pointed_thing.above;
    local on_rightclick = natural_habitat.check_on_rightclick(itemstack, placer, pos);
    if on_rightclick then return on_rightclick; end;
    
    local node = natural_habitat.get_pointed_node(user);
    
    if (node.pointed_side == "bottom") then
        local param2 = core.dir_to_facedir(user:get_look_dir()) % 4;
        core.set_node( pos, 
            {name=replacement or itemstack:get_name(), param2=param2}, 
            user
        );
    
        if not core.is_creative_enabled(user:get_player_name()) then
            itemstack:take_item();
        end;
    end;
    return itemstack;
end

-- REGISTER DECORATION
function natural_habitat.register_decoration(def)
    local y_min, y_max = natural_habitat.get_world_hight();
    
    local flags = "force_placement";
    if (def.deco_type == "schematic") then
        flags = "place_center_x, place_center_z, force_placement";
    end;
    
    core.register_decoration({
        name = def.name,
        deco_type = def.deco_type,
        place_on = def.place_on,
        sidelen = def.sidelen,
        fill_ratio = def.fill_ratio,
        noise_params = def.noise_params,
        biomes = def.biomes,
        y_min = def.y_min or y_min,
        y_max = def.y_max or y_max,
        spawn_by = def.spawn_by,
        check_offset = def.check_offset,
        num_spawn_by = def.num_spawn_by,
        flags = def.flags or flags,
        decoration = def.decoration,
        schematic = def.schematic,
        height = def.height,
        height_max = def.height_max,
        param2 = def.param2,
        param2_max = def.param2_max,
        place_offset_y = def.place_offset_y,
        rotation = def.rotation or "random",
        replacements = def.replacements,
    });
    return def.name;
end;

-- FIND BIOMES IN AREA
function natural_habitat.find_biomes_in_area(pos, biomes, radius, height)
    height = height or radius;
    local p = vector.offset(pos, -radius, -height, -radius);
    local sidelen = radius*2;
    local result = {};
    
    for ix = 1, sidelen do
        for iy = 1, height do
            for iz = 1, sidelen do
                local check_pos = vector.new(p.x+ix, p.y+iy, p.z+iz);
                local biome_data = core.get_biome_data(check_pos);
                local biome_name = core.get_biome_name(biome_data.biome);
                for i, biome in pairs(biomes) do
                    if (biome_name == biome) then
                        table.insert(result, tostring(check_pos));
                    end;
                end;
            end;
        end;
    end;
    
    return result;
end;

-- IMPORTS
dofile(modpath.."/utils/chat_commands.lua");
dofile(modpath.."/utils/data/table.lua");
dofile(modpath.."/utils/data/string.lua");
dofile(modpath.."/utils/data/sounds.lua");
dofile(modpath.."/utils/data/multipack.lua");
dofile(modpath.."/utils/data/bush.lua");
dofile(modpath.."/utils/data/biome.lua");
dofile(modpath.."/utils/data/particles.lua");