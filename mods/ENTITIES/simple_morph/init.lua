-- Simple Morph Mod - Mineclonia Edition (Full Fixes & Abilities)

local morphed_players = {}

-- Restores normal player physics, vision, dynamic properties, and active status effects
local function reset_player(player)
    local name = player:get_player_name()
    morphed_players[name] = nil
    
    -- Reset visual properties and bounding box
    player:set_properties({
        visual = "mesh",
        mesh = "mcl_armor_character.b3d",
        textures = {"character.png"},
        visual_size = {x = 1, y = 1, z = 1},
        collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.77, 0.3},
        breath_max = 11,
    })
    
    -- Reset physical movement overrides
    player:set_physics_override({
        speed = 1.0,
        jump = 1.0,
        gravity = 1.0,
        sneak = true,
    })
    
    -- Reset camera offsets & animations
    player:set_eye_offset({x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
    player:set_animation({x = 0, y = 79}, 30, 0, true)

    -- Remove Night Vision status effect cleanly upon unmorphing
    if mcl_potions and mcl_potions.remove_effect then
        mcl_potions.remove_effect(player, "night_vision")
    end

    -- Restore Mineclonia player skin integration
    if mcl_skins then
        if mcl_skins.set_player_skin and mcl_skins.get_player_skin then
            mcl_skins.set_player_skin(player, mcl_skins.get_player_skin(player))
        elseif mcl_skins.update_player_skin then
            mcl_skins.update_player_skin(player)
        end
    end

    minetest.chat_send_player(name, "[Morph] Returned to normal player form.")
end

-- Globalstep Loop: Animation state management & continuous passive abilities
minetest.register_globalstep(function(dtime)
    for name, data in pairs(morphed_players) do
        local player = minetest.get_player_by_name(name)
        if player then
            -- Animation state handling (Walk vs. Stand)
            local vel = player:get_player_velocity()
            local speed = math.sqrt(vel.x * vel.x + vel.z * vel.z)
            
            if speed > 0.2 then
                if data.state ~= "walk" then
                    player:set_animation(data.walk, data.speed, 0, true)
                    data.state = "walk"
                end
            else
                if data.state ~= "stand" then
                    player:set_animation(data.stand, data.speed, 0, true)
                    data.state = "stand"
                end
            end

            -- Passive Ability: Water Breathing (Fish/Dolphin/Squid)
            if data.ability == "water_breathing" then
                player:set_breath(11)

            -- Passive Ability: Low-gravity Flight Physics (Bat/Phantom)
            elseif data.ability == "flight" then
                local keys = player:get_player_control()
                if keys.jump then
                    local pvel = player:get_player_velocity()
                    player:add_player_velocity({x = 0, y = 0.8 - pvel.y * 0.1, z = 0})
                end
            end

            -- Passive Ability: Maintain Night Vision Potion Effect
            if data.has_night_vision then
                if mcl_potions and mcl_potions.give_effect then
                    mcl_potions.give_effect("night_vision", player, 1, 15)
                end
            end

        else
            morphed_players[name] = nil
        end
    end
end)

-- Creeper Ability: Node punch triggers native explosion
minetest.register_on_punchnode(function(pos, node, puncher, pointed_thing)
    if not puncher or not puncher:is_player() then return end
    local name = puncher:get_player_name()
    local data = morphed_players[name]

    if data and data.ability == "creeper_boom" then
        local ppos = puncher:get_pos()
        
        -- Native Mineclonia Explosion API call
        if mcl_explosions and mcl_explosions.explode then
            mcl_explosions.explode(ppos, 3, {drop_chance = 0.5}, puncher)
        elseif tnt and tnt.boom then
            tnt.boom(ppos, {radius = 3, damage_radius = 4})
        else
            -- Safe fall-back particle damage
            minetest.add_particlespawner({
                amount = 30,
                time = 0.1,
                minpos = {x = ppos.x - 1, y = ppos.y, z = ppos.z - 1},
                maxpos = {x = ppos.x + 1, y = ppos.y + 2, z = ppos.z + 1},
                texture = "mcl_particles_smoke.png",
            })
            for _, obj in ipairs(minetest.get_objects_inside_radius(ppos, 4)) do
                obj:punch(puncher, 1.0, {
                    full_punch_interval = 1.0,
                    damage_groups = {fleshy = 10},
                }, nil)
            end
        end
    end
end)

-- Helper: Retrieve loaded entity definitions
local function get_all_mobs()
    local mob_list = {}
    for entity_name, def in pairs(minetest.registered_entities) do
        if entity_name:find("mobs_mc:") or entity_name:find("mcl_mobs:") or entity_name:find("mobs:") then
            mob_list[entity_name] = def
        end
    end
    return mob_list
end

-- Chat Command: /morph <mob_name|list>
minetest.register_chatcommand("morph", {
    params = "<mob_name|list>",
    description = "Morph into any Mineclonia mob with abilities, scaling, and dynamic camera alignment",
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then return false, "Player not found." end

        param = param:lower():trim()
        local all_mobs = get_all_mobs()

        -- Process `/morph list`
        if param == "list" or param == "" then
            local available = {}
            local seen = {}
            for entity_name, _ in pairs(all_mobs) do
                local clean_name = entity_name:gsub("^[^:]+:", "")
                if not seen[clean_name] then
                    table.insert(available, clean_name)
                    seen[clean_name] = true
                end
            end
            table.sort(available)
            
            if #available == 0 then
                return true, "[Morph] No mobs available or registered."
            end
            return true, "[Morph] Available mobs: " .. table.concat(available, ", ")
        end

        -- Search for target mob definition
        local target_mob_def = nil
        local target_full_name = ""

        for entity_name, def in pairs(all_mobs) do
            local clean_name = entity_name:gsub("^[^:]+:", "")
            if clean_name == param or entity_name == param then
                target_mob_def = def
                target_full_name = entity_name
                break
            end
        end

        -- Direct engine fallback lookup
        if not target_mob_def then
            local fallback_id = "mobs_mc:" .. param
            if minetest.registered_entities[fallback_id] then
                target_mob_def = minetest.registered_entities[fallback_id]
                target_full_name = fallback_id
            end
        end

        if not target_mob_def then
            return false, "[Morph] Mob '" .. param .. "' not found. Type /morph list."
        end

        -- Clear any active morph effects before applying new morph
        if mcl_potions and mcl_potions.remove_effect then
            mcl_potions.remove_effect(player, "night_vision")
        end

        -- Load visual mesh and texture data
        local mob_mesh = target_mob_def.mesh or ("mobs_mc_" .. param .. ".b3d")
        local mob_textures = target_mob_def.textures or { "mobs_mc_" .. param .. ".png" }
        
        if type(mob_textures) == "table" and type(mob_textures[1]) == "table" then
            mob_textures = mob_textures[1]
        elseif type(mob_textures) == "string" then
            mob_textures = {mob_textures}
        end

        local mob_visual_size = target_mob_def.visual_size or {x = 1, y = 1, z = 1}
        local mob_box = target_mob_def.collisionbox or {-0.4, 0.0, -0.4, 0.4, 1.7, 0.4}

        -- Dynamic Mob Height & Scaling Calculation
        local raw_height = math.abs(mob_box[5] - mob_box[2])
        if raw_height < 0.2 then raw_height = 1.5 end

        local target_scale = 1.6 / raw_height
        if target_scale < 0.8 then target_scale = 0.8 end
        if target_scale > 2.0 then target_scale = 2.0 end

        local scaled_visual_size = {
            x = mob_visual_size.x * target_scale,
            y = mob_visual_size.y * target_scale,
            z = mob_visual_size.z * target_scale
        }

        -- Calculate rendered height and eye Y-offset for first/third person camera alignment
        local rendered_height = raw_height * target_scale
        local eye_y_offset = math.floor((rendered_height - 1.625) * 10)

        player:set_properties({
            visual = "mesh",
            mesh = mob_mesh,
            textures = mob_textures,
            visual_size = scaled_visual_size,
            collisionbox = {
                mob_box[1] * target_scale,
                mob_box[2] * target_scale,
                mob_box[3] * target_scale,
                mob_box[4] * target_scale,
                mob_box[5] * target_scale,
                mob_box[6] * target_scale
            },
        })

        -- Ability Mapping & Physics Configuration
        local ability_type = nil
        local has_night_vis = false
        local physics = {speed = 1.0, jump = 1.0, gravity = 1.0, sneak = true}

        if param == "creeper" then
            ability_type = "creeper_boom"
            physics.speed = 1.15
        elseif param == "bat" or param == "phantom" then
            ability_type = "flight"
            has_night_vis = true
            physics.gravity = 0.2
        elseif param == "salmon" or param == "cod" or param == "squid" or param == "dolphin" or param == "guardian" then
            ability_type = "water_breathing"
            physics.speed = 1.3
        elseif param == "spider" or param == "cave_spider" then
            physics.jump = 1.6
            physics.speed = 1.2
            has_night_vis = true
        elseif param == "enderman" or param == "witch" then
            physics.speed = 1.2
        elseif param == "zombie" or param == "husk" then
            physics.speed = 0.95
        end

        -- Apply Night Vision Status Effect
        if has_night_vis and mcl_potions and mcl_potions.give_effect then
            mcl_potions.give_effect("night_vision", player, 1, 15)
        end

        player:set_physics_override(physics)

        -- Animation Parsing
        local stand_anim = {x = 0, y = 0}
        local walk_anim = {x = 0, y = 40}
        local anim_speed = 30

        if target_mob_def.animation then
            if target_mob_def.animation.stand_start and target_mob_def.animation.stand_end then
                stand_anim = {x = target_mob_def.animation.stand_start, y = target_mob_def.animation.stand_end}
            end
            if target_mob_def.animation.walk_start and target_mob_def.animation.walk_end then
                walk_anim = {x = target_mob_def.animation.walk_start, y = target_mob_def.animation.walk_end}
            end
        end

        morphed_players[name] = {
            stand = stand_anim,
            walk = walk_anim,
            speed = anim_speed,
            state = "",
            ability = ability_type,
            has_night_vision = has_night_vis,
        }

        -- Set Head-Aligned Camera Eye Offsets
        player:set_eye_offset(
            {x = 0, y = eye_y_offset, z = 0}, 
            {x = 0, y = eye_y_offset, z = math.max(3, math.floor(rendered_height * 2))}
        )

        minetest.chat_send_player(name, "[Morph] Morphed into: " .. target_full_name)
        return true
    end,
})

-- Chat Command: /unmorph
minetest.register_chatcommand("unmorph", {
    description = "Revert back to your normal character model and reset physics/effects",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player then
            reset_player(player)
            return true
        end
        return false
    end,
})