-- Creaking Heart - Bloco que spawna o Creaking

-- Registra o bloco Creaking Heart (dormant/inativo)
minetest.register_node("mcl_pale_oak:creaking_heart", {
    description = "Coração Rangedor",
    tiles = {
        "default_creaking_heart_top_dormant.png",
        "default_creaking_heart_top_dormant.png",
        "default_creaking_heart_dormant.png",
        "default_creaking_heart_dormant.png",
        "default_creaking_heart_dormant.png",
        "default_creaking_heart_dormant.png"
    },
    paramtype2 = "facedir",
    is_ground_content = false,
    groups = {handy=1, axey=1, tree=1, flammable=2, building_block=1},
    sounds = mcl_sounds.node_sound_wood_defaults(),
    on_place = mcl_util.rotate_axis,
    _mcl_blast_resistance = 5,
    _mcl_hardness = 5,
    
    -- Quando quebrado, mata todos os Creakings próximos
    on_destruct = function(pos)
        local objs = minetest.get_objects_inside_radius(pos, 32)
        for _, obj in ipairs(objs) do
            local entity = obj:get_luaentity()
            if entity and entity.name == "mcl_pale_oak:creaking" then
                obj:remove()
            end
        end
        
        -- Efeito visual
        minetest.add_particlespawner({
            amount = 20,
            time = 0.5,
            minpos = vector.subtract(pos, 0.5),
            maxpos = vector.add(pos, 0.5),
            minvel = {x=-1, y=-1, z=-1},
            maxvel = {x=1, y=1, z=1},
            minacc = {x=0, y=-5, z=0},
            maxacc = {x=0, y=-5, z=0},
            minexptime = 1,
            maxexptime = 2,
            minsize = 1,
            maxsize = 3,
            texture = "default_creaking_heart.png^[resize:8x8",
        })
    end,
})

-- Registra o Creaking Heart ativo (brilhante à noite)
minetest.register_node("mcl_pale_oak:creaking_heart_active", {
    description = "Coração Rangedor (Ativo)",
    tiles = {
        {
            name = "default_creaking_heart_top_awake.png",
            animation = {
                type = "vertical_frames",
                aspect_w = 16,
                aspect_h = 16,
                length = 2.0,
            },
        },
        {
            name = "default_creaking_heart_top_awake.png",
            animation = {
                type = "vertical_frames",
                aspect_w = 16,
                aspect_h = 16,
                length = 2.0,
            },
        },
        "default_creaking_heart_awake.png",
        "default_creaking_heart_awake.png",
        "default_creaking_heart_awake.png",
        "default_creaking_heart_awake.png"
    },
    paramtype = "light",
    light_source = 5,
    paramtype2 = "facedir",
    is_ground_content = false,
    groups = {handy=1, axey=1, tree=1, flammable=2, building_block=1, not_in_creative_inventory=1},
    sounds = mcl_sounds.node_sound_wood_defaults(),
    drop = "mcl_pale_oak:creaking_heart",
    _mcl_blast_resistance = 5,
    _mcl_hardness = 5,
    
    on_destruct = function(pos)
        local objs = minetest.get_objects_inside_radius(pos, 32)
        for _, obj in ipairs(objs) do
            local entity = obj:get_luaentity()
            if entity and entity.name == "mcl_pale_oak:creaking" then
                obj:remove()
            end
        end
    end,
})

-- ABM: Ativa o Creaking Heart à noite e spawna Creaking
minetest.register_abm({
    label = "Creaking Heart Activation",
    nodenames = {"mcl_pale_oak:creaking_heart"},
    interval = 10,
    chance = 1,
    action = function(pos, node)
        local time_of_day = minetest.get_timeofday()
        
        -- À noite (18:00 - 06:00)
        if time_of_day > 0.75 or time_of_day < 0.25 then
            -- Ativa o bloco
            minetest.swap_node(pos, {name="mcl_pale_oak:creaking_heart_active", param2=node.param2})
            
            -- Spawna um Creaking próximo se não existir
            local objs = minetest.get_objects_inside_radius(pos, 32)
            local has_creaking = false
            
            for _, obj in ipairs(objs) do
                local entity = obj:get_luaentity()
                if entity and entity.name == "mcl_pale_oak:creaking" then
                    has_creaking = true
                    break
                end
            end
            
            if not has_creaking then
                -- Procura posição válida para spawn
                for i = 1, 10 do
                    local spawn_pos = {
                        x = pos.x + math.random(-8, 8),
                        y = pos.y,
                        z = pos.z + math.random(-8, 8)
                    }
                    
                    -- Encontra o chão
                    for dy = -5, 5 do
                        local check_pos = {x=spawn_pos.x, y=spawn_pos.y+dy, z=spawn_pos.z}
                        local node_below = minetest.get_node({x=check_pos.x, y=check_pos.y-1, z=check_pos.z})
                        local node_at = minetest.get_node(check_pos)
                        
                        if node_below.name ~= "air" and node_at.name == "air" then
                            minetest.add_entity(check_pos, "mcl_pale_oak:creaking")
                            break
                        end
                    end
                end
            end
        end
    end,
})

-- ABM: Desativa o Creaking Heart de dia
minetest.register_abm({
    label = "Creaking Heart Deactivation",
    nodenames = {"mcl_pale_oak:creaking_heart_active"},
    interval = 10,
    chance = 1,
    action = function(pos, node)
        local time_of_day = minetest.get_timeofday()
        
        -- De dia (06:00 - 18:00)
        if time_of_day >= 0.25 and time_of_day <= 0.75 then
            -- Desativa o bloco
            minetest.swap_node(pos, {name="mcl_pale_oak:creaking_heart", param2=node.param2})
            
            -- Remove Creakings próximos
            local objs = minetest.get_objects_inside_radius(pos, 32)
            for _, obj in ipairs(objs) do
                local entity = obj:get_luaentity()
                if entity and entity.name == "mcl_pale_oak:creaking" then
                    obj:remove()
                end
            end
        end
    end,
})



minetest.log("action", "[Pale Garden] Creaking Heart registrado!")
