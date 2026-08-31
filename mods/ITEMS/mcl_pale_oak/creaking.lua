-------------------------------------------------
-- ENTIDADE: CREAKING (O RANGEDOR)
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

    timer = 0,
    attack_timer = 0,
    frozen = false,

    on_activate = function(self)
        self.object:set_armor_groups({immortal = 1})
        self.object:set_acceleration({x = 0, y = -9.8, z = 0})
    end,

    -------------------------------------------------
    -- FUNÇÃO DE RASTRO AO BATER (NOVO)
    -------------------------------------------------
    on_punch = function(self, puncher)
        local pos = self.object:get_pos()
        if not pos then return true end

        -- 1. Procura o coração mais próximo (raio de 32 blocos)
        -- Nota: Ajuste o nome do nó abaixo para o nome real do seu nó de coração
        local heart_pos = minetest.find_node_near(pos, 32, {"mcl_pale_oak:creaking_heart_active"})

        if heart_pos then
            -- Centraliza a posição da partícula no bloco do coração
            heart_pos = vector.add(heart_pos, {x=0, y=0, z=0})
            
            -- 2. Calcula a distância e a direção
            local dist = vector.distance(pos, heart_pos)
            local dir = vector.direction(pos, heart_pos)
            
            -- 3. Cria o rastro de partículas
            -- Spawna uma partícula a cada 0.5 blocos de distância
            for i = 0, dist, 0.5 do
                local particle_pos = vector.add(pos, vector.multiply(dir, i))
                -- Eleva um pouco as partículas para saírem do peito do mob
                particle_pos.y = particle_pos.y + 1.5 

                minetest.add_particle({
                    pos = particle_pos,
                    velocity = {x = 0, y = 0.1, z = 0},
                    acceleration = {x = 0, y = 0, z = 0},
                    expirationtime = 1.5,
                    size = 4,
                    collisiondetection = false,
                    vertical = false,
                    texture = "default_resin_clump_node.png",
                    glow = 10, -- Faz brilhar levemente
                })
            end
            
            -- Som opcional de "vibração" ou resina ao bater
            minetest.sound_play("default_dig_snappy", {pos = pos, gain = 1.0}, true)
        end

        return true -- Impede que o mob morra por dano direto
    end,

    on_step = function(self, dtime)
        self.timer = self.timer + dtime
        self.attack_timer = self.attack_timer + dtime

        if self.timer < 0.1 then return end
        self.timer = 0

        local pos = self.object:get_pos()
        if not pos then return end

        -------------------------------------------------
        -- LÓGICA DE PROCURA E MOVIMENTO
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

        if not closest_player then
            local v = self.object:get_velocity()
            self.object:set_velocity({x = 0, y = v.y, z = 0})
            return
        end

        local player_pos = closest_player:get_pos()
        local look_dir = closest_player:get_look_dir()
        local to_creaking = vector.subtract(pos, player_pos)
        local dist = vector.length(to_creaking)

        if dist > 0 then
            to_creaking = vector.normalize(to_creaking)
            local dot = vector.dot(look_dir, to_creaking)

            -- 👁️ freezes while stare
            if dot > 0.4 then
                self.frozen = true
                local v = self.object:get_velocity()
                self.object:set_velocity({x = 0, y = v.y, z = 0})
                self.object:set_animation({x = 0, y = 40}, 0, 0, true)
                return
            end
        end

        -------------------------------------------------
        -- MOVIMENTO (NÃO ESTÁ SENDO OLHADO)
        -------------------------------------------------
        self.frozen = false

        if dist > 1.5 then
            local dir = vector.direction(pos, player_pos)
            local speed = 1.5 -- Velocidade levemente aumentada

            self.object:set_velocity({
                x = dir.x * speed,
                y = self.object:get_velocity().y,
                z = dir.z * speed
            })

            local yaw = math.atan2(dir.z, dir.x) + math.pi / 2
            self.object:set_yaw(yaw)
            self.object:set_animation({x = 40, y = 60}, 30, 0, true)
        else
            -- ATAQUE
            if self.attack_timer > 1.0 then
                self.attack_timer = 0
                closest_player:set_hp(closest_player:get_hp() - 2)
                self.object:set_animation({x = 90, y = 110}, 40, 0, false)
            end
        end
    end,

    get_staticdata = function() return "" end,
})

-------------------------------------------------
-- SPAWN NOTURNO
-- Desabilitado para reduzir o pico de lag do bioma ao anoitecer.
-- O coração do Pale Oak passa a ser a fonte principal de spawn.
-------------------------------------------------

-------------------------------------------------
-- OVO DE SPAWN (MCL)
-------------------------------------------------
mcl_mobs.register_egg("mcl_pale_oak:creaking", "Creaking", "#a5a5a5ff", "#f58c02ff", 0)

minetest.log("action", "[Pale Garden] Creaking registrado com gravidade!")
