local y_min, y_max = natural_habitat.get_world_hight();
local to_do_list = {};
local decolist = {};

-- REGISTER MULTINODE
function natural_habitat.register_multinode(id, multidef)
    for sfx, nodedef in pairs(multidef.nodes) do
        local def = table.copy(multidef.shared);
        def.nodes = nil;
        for key, value in pairs(nodedef or {}) do
            def[key] = value;
        end;
        
        local definition = natural_habitat.game_impact(multidef.minetest, multidef.mineclonia);
        for key, value in pairs(definition or {}) do def[key] = value; end;
    
        core.register_node(id..sfx, def);
    end;
end;

-- REGISTER MULTIDECO
function natural_habitat.register_multideco(id, multidef)
    local def = table.copy(multidef.shared or {});
    
    local definition = natural_habitat.game_impact(multidef.minetest, multidef.mineclonia);
    for key, value in pairs(definition or {}) do def[key] = value; end;
    
    if def.decos and (#def.decos > 0) then
        def.y_min = def.y_min or y_min;
        def.y_max = def.y_max or y_max;
        
        if def.noise_params then
            def.noise_params.scale = def.noise_params.scale / #def.decos;
        else
            def.fill_ratio = (def.fill_ratio or 0.1) / #def.decos;
        end;
        
        for i, deco in pairs(def.decos) do
            local deco_def = table.copy(def);
            deco_def.name = id.."_"..tostring(i);
            deco_def.deco_type = deco.deco_type or def.deco_type;
            
            for key, value in pairs(deco) do deco_def[key] = value; end;
            
            if deco_def.smart_place then
                decolist[deco_def.name] = table.copy(deco_def);
                
                local tmp_def = table.copy(deco_def);
                tmp_def.deco_type = "simple";
                tmp_def.decoration = "air";
                
                natural_habitat.register_decoration(tmp_def);
                core.set_gen_notify({decoration=true}, {core.get_decoration_id(deco_def.name)});
            else
                natural_habitat.register_decoration(deco_def);
            end;
        end;
    end;
end;

-- DECO SMART PLACE
function natural_habitat.deco_smart_place(pos, def)
    local sidelen = def.sidelen or 1;
    
    local p1 = vector.offset(pos, -sidelen/2, 0, -sidelen/2);
    local p2 = vector.offset(pos, sidelen/2, 0, sidelen/2);
    
    -- if ground in place_on nodes
    local find_nodes = core.find_nodes_in_area(p1, p2, def.place_on);
    if (#find_nodes >= (sidelen*sidelen)) or (sidelen == 1 ) then
        local allow_place = true;
        
        -- check biome
        if def.biomes and (def.biomes ~= {}) then
            local biome_data = core.get_biome_data(pos);
            allow_place = false;
            
            for i, biome_name in pairs(def.biomes) do
                if (core.get_biome_name(biome_data.biome) == biome_name) then
                    allow_place = true;
                end;
            end;
        end;
        
        -- check is biome right size
        if allow_place and def.biome_min_radius then
            local radius = def.biome_min_radius or ((sidelen+5)/2);
            if allow_place and def.biomes and (#def.biomes > 0) then
                local biomes = natural_habitat.find_biomes_in_area(
                    pos, def.biomes, radius, def.biome_min_height
                );
                allow_place = #biomes >= (radius*radius*radius);
            end;
        end;
        
        -- check if avoid nodes not near
        if allow_place and def.avoid_nodes then
            def.avoid_radius = def.avoid_radius or ((sidelen/2)+2);
            p1 = vector.offset( pos, -def.avoid_radius, -def.avoid_radius, -def.avoid_radius );
            p2 = vector.offset( pos, def.avoid_radius, def.avoid_radius, def.avoid_radius );
                
            find_nodes = core.find_nodes_in_area(p1, p2, def.avoid_nodes);
            allow_place = (#find_nodes < 1);
        end;
        
        -- check if pursue nodes is near
        if allow_place and def.pursue_nodes then
            def.pursue_radius = def.pursue_radius or ((sidelen/2)+2);
            p1 = vector.offset( pos, -def.pursue_radius, -def.pursue_radius, -def.pursue_radius );
            p2 = vector.offset( pos, def.pursue_radius, def.pursue_radius, def.pursue_radius );
                
            find_nodes = core.find_nodes_in_area(p1, p2, def.pursue_nodes);
            allow_place = (#find_nodes > 0);
        end;
        
        -- check node above
        pos = vector.offset(pos, 0, 1, 0);
        local node_name = core.get_node(pos).name;
        local node_def = core.registered_nodes[node_name];
        
        if (node_name == "air") or 
            ( (node_def.buildable_to == true) and (node_def.liquidtype == nil) ) then
                if allow_place and (def.deco_type == "schematic") and def.schematic then
                    if natural_habitat.is_minetest() then
                        core.place_schematic(
                            vector.offset(pos, 0, (def.place_offset_y or 0)-1, 0), 
                            def.schematic, 
                            def.rotation or "random", 
                            def.replacements or nil, 
                            def.force_placement or true, 
                            def.flags or "place_center_x, place_center_z"
                        );
                    elseif natural_habitat.is_mineclonia() then
                        mcl_structures.place_schematic(
                            vector.offset(pos, 0, (def.place_offset_y or 0)-1, 0), 
                            def.schematic, 
                            def.rotation or "random", 
                            def.replacements or nil, 
                            def.force_placement or true, 
                            def.flags or "place_center_x, place_center_z"
                        );
                    end;
                elseif allow_place and (def.deco_type == "simple") and def.decoration then
                    core.set_node(pos, { name=def.decoration });
                end;
        end;
    end;
end;

-- CHECK FOR NEW DECOS
core.register_on_generated(function(minp, maxp, blockseed)
    local gennotify = core.get_mapgen_object("gennotify");
        
    for key, def in pairs(decolist) do
        local deco_id = core.get_decoration_id(key);
        if deco_id and gennotify["decoration#"..deco_id] then
            for i, pos in ipairs(gennotify["decoration#"..deco_id]) do
                if (def.use_map_generator == nil) or (def.use_map_generator == true) then
                    natural_habitat.deco_smart_place(pos, def);
                else
                    to_do_list["deco_"..tostring(pos)] = { pos=pos, key=key, };
                end;
            end;
        end;
    end;
end);

-- PLACING DECOS
core.register_globalstep(function(dtime)
    local deco, deco_data = next(to_do_list, nil);
    if deco then
        natural_habitat.deco_smart_place(deco_data.pos, decolist[deco_data.key]);
        to_do_list[deco] = nil;
    end;
end);