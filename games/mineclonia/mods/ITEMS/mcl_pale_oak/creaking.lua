-- Creaking Mob - O Rangedor do Pale Garden
-- Versão corrigida com GRAVIDADE FUNCIONAL

-------------------------------------------------
-- ENTIDADE
-------------------------------------------------
minetest.register_entity("mcl_pale_oak:creaking", {

   initial_properties = {
    hp_max = 1,
    physical = true,
    collide_with_objects = true,

    collisionbox = {-0.7, 0.0, -0.7, 0.7, 2.7, 0.7},

    visual = "mesh",
    mesh = "creaking.x",
    textures = {"creaking.png"},
    visual_size = {x = 10, y = 10},

    makes_footstep_sound = true,
    stepheight = 1.1,
    automatic_rotate = 0,
},


    -------------------------------------------------
    -- VARIÁVEIS
    -------------------------------------------------
    timer = 0,
    attack_timer = 0,
    frozen = false,

    -------------------------------------------------
    -- ATIVAÇÃO
    -------------------------------------------------
    on_activate = function(self)
    self.object:set_armor_groups({immortal = 1})
    self.timer = 0
    self.attack_timer = 0

    -- stub para mcl_mobs
    self.set_nametag = function() end

    -- gravidade
    self.object:set_acceleration({x = 0, y = -9.8, z = 0})
end,


    -------------------------------------------------
    -- LOOP PRINCIPAL
    -------------------------------------------------
    on_step = function(self, dtime)
        self.timer = self.timer + dtime
        self.attack_timer = self.attack_timer + dtime

        if self.timer < 0.1 then return end
        self.timer = 0

        local pos = self.object:get_pos()
        if not pos then return end

        -------------------------------------------------
        -- PROCURA JOGADOR MAIS PRÓXIMO
        -------------------------------------------------
        local closest_player
        local closest_dist = 16

        for _, player in ipairs(minetest.get_connected_players()) do
            local ppos = player:get_pos()
            local dist = vector.distance(pos, ppos)

            if dist < closest_dist then
                closest_dist = dist
                closest_player = player
            end
        end

        -------------------------------------------------
        -- SEM ALVO → PARA (SEM MATAR GRAVIDADE)
        -------------------------------------------------
        if not closest_player then
            local v = self.object:get_velocity()
            self.object:set_velocity({x = 0, y = v.y, z = 0})
            return
        end

        -------------------------------------------------
        -- VERIFICA SE O JOGADOR ESTÁ OLHANDO
        -------------------------------------------------
        local player_pos = closest_player:get_pos()
        local look_dir = closest_player:get_look_dir()

        local to_creaking = vector.subtract(pos, player_pos)
        local dist = vector.length(to_creaking)

        if dist > 0 then
            to_creaking = vector.normalize(to_creaking)
            local dot = vector.dot(look_dir, to_creaking)

            -- 👁️ CONGELA SE ESTIVER SENDO OLHADO
            if dot > 0.4 then
                self.frozen = true

                local v = self.object:get_velocity()
                self.object:set_velocity({x = 0, y = v.y, z = 0})

                self.object:set_animation({x = 0, y = 40}, 0, 0, true)
                return
            end
        end

        -------------------------------------------------
        -- NÃO ESTÁ SENDO OLHADO → MOVE
        -------------------------------------------------
        self.frozen = false

        if dist > 1.5 then
            local dir = vector.direction(pos, player_pos)
            local speed = 1.0

            local vel = {
                x = dir.x * speed,
                y = self.object:get_velocity().y, -- mantém gravidade
                z = dir.z * speed
            }

            self.object:set_velocity(vel)

            -- Rotação correta
            local yaw = math.atan2(dir.z, dir.x) + math.pi / 2
            self.object:set_yaw(yaw)

            self.object:set_animation({x = 40, y = 60}, 30, 0, true)

        else
            -------------------------------------------------
            -- ATAQUE
            -------------------------------------------------
            if self.attack_timer > 1.0 then
                self.attack_timer = 0

                closest_player:set_hp(closest_player:get_hp() - 2)
                self.object:set_animation({x = 90, y = 110}, 40, 0, false)
            end
        end
    end,

    -------------------------------------------------
    -- INVULNERÁVEL
    -------------------------------------------------
    on_punch = function()
        return true
    end,

    get_staticdata = function()
        return ""
    end,
})

-------------------------------------------------
-- SPAWN NOTURNO
-------------------------------------------------
minetest.register_abm({
    label = "Creaking Spawn",
    nodenames = {"mcl_pale_oak:pale_moss_block"},
    interval = 60,
    chance = 100,

    action = function(pos)
        local time = minetest.get_timeofday()
        if time < 0.2 or time > 0.8 then return end

        local objs = minetest.get_objects_inside_radius(pos, 32)
        for _, obj in ipairs(objs) do
            local ent = obj:get_luaentity()
            if ent and ent.name == "mcl_pale_oak:creaking" then
                return
            end
        end

        local spawn_pos = {x = pos.x, y = pos.y + 1, z = pos.z}
        if minetest.get_node(spawn_pos).name == "air" then
            minetest.add_entity(spawn_pos, "mcl_pale_oak:creaking")
        end
    end,
})

-------------------------------------------------
-- OVO DE SPAWN (MCL)
-------------------------------------------------
mcl_mobs.register_egg("mcl_pale_oak:creaking", "Creaking", "#a5a5a5ff", "#f58c02ff", 0)

minetest.log("action", "[Pale Garden] Creaking registrado com gravidade!")
