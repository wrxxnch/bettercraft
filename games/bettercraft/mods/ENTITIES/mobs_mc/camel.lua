mcl_mobs.register_mob("mobs_mc:camel", {
    type = "animal",
    spawn_class = "passive",
    attack_type = "dogfight",
    damage = 3,
    hp_min = 32,
    hp_max = 32,
    xp_min = 1,
    xp_max = 3,
    double_melee_attack = false,
    reach = 2,
    armor = 5,
    collisionbox = { -0.6, 0, -0.6, 0.6, 1.8, 0.6 },
    visual = "mesh",
    mesh = "mobs_mc_camel.b3d",
    visual_size = { x = 1, y = 1},
    textures = { "mobs_mc_camel.png" },
    --glow = 4,
    makes_footstep_sound = true,
    walk_velocity = 1,
    pace_bonus = 0.3,
    run_velocity = 4,
    view_range = 16,
    stepheight = 1.1,
    jump = true,
    jump_height = 10,
    suffocation = true,
    fear_height = 4,
    sounds = {
       -- random = "",
    },
    ------
    drops = {
       -- {name = "camel:camel", min = 1, max = 2},
    },
    -----
    animation = {
                -- Sit =  110 ,120
        stand_start = 1, stand_end = 40, stand_speed = 10,
        walk_start = 70, walk_end = 100, speed_normal = 10,
        run_start = 130, run_end = 146, speed_run = 10,
    },

    -- Lógica de montaria adicionada abaixo
    do_custom = function(self, dtime)
        -- Inicializa variáveis de montaria se necessário
        if not self.v2 then
            self.v2 = 0
            self.max_speed_forward = 4
            self.max_speed_reverse = 2
            self.accel = 6
            self.terrain_type = 3 -- 3 = terra
            -- Ajuste o 'y' conforme necessário para a altura do modelo
            self.driver_attach_at = {x = 0, y = 18, z = 0} 
            self.driver_eye_offset = {x = 0, y = 3, z = 0}
            self.driver_scale = {x = 1, y = 1}
        end

        -- Se houver um jogador montado, permite o controle
        if self.driver then
            mcl_mobs.drive(self, "walk", "stand", false, dtime)
            return false -- Pula o resto da IA do mob enquanto é montado
        end

        return true
    end,

    on_rightclick = function(self, clicker)
        if not clicker or not clicker:is_player() then
            return
        end

        -- Se o jogador já está montado neste mob, descer
        if self.driver and clicker == self.driver then
            mcl_mobs.detach(clicker, {x = 1, y = 0, z = 1})
            return
        end

        -- Se não houver ninguém montado, subir
        if not self.driver then
            -- Opcional: Verificar se o mob está domado (tamed) antes de permitir montar
            -- if self.tamed then
                mcl_mobs.attach(self, clicker)
            -- end
            return
        end
    end,

    on_die = function(self, pos)
        -- Garante que o jogador seja desmontado se o camelo morrer
        if self.driver then
            mcl_mobs.detach(self.driver, {x = 1, y = 0, z = 1})
        end
    end,

    on_spawn = function(self, pos)
        -- lógica de spawn existente (se houver)
    end
})

mcl_mobs.register_egg("mobs_mc:camel", "camel", "#b5844c", "#553722", 0)
