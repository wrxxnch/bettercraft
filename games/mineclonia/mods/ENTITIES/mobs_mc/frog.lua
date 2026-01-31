local S = core.get_translator("mobs_mc")

local textures = {
	cold   = 1,
	snowy = 1,
	medium = 2,
	hot    = 3,
}

-------------------------------------------------
-- FROG
-------------------------------------------------
mcl_mobs.register_mob("mobs_mc:frog", {
	description = S("Frog"),
	type = "animal",
	passive = true, -- Sapos são passivos, mas atacam slimes
	group_attack = true,

	-------------------------------------------------
	-- MOVIMENTO (Ajustado para o estilo do Minecraft)
	-------------------------------------------------
	walk_velocity = 1.5,
	run_velocity  = 3.0,
	pace_bonus = 0.3,
	jump = true,
	jump_height = 1.5, -- Altura do pulo para obstáculos
	stepheight = 1.1,
	fly = false,
	water_damage = 0,
	lava_damage = 4,
	fall_damage = 0,
	fear_height = 4,
	

	-------------------------------------------------
	-- COMBATE
	-------------------------------------------------
	attack_type = "melee",
	damage = 1,
	reach = 2,
	attack_monsters = true,
	attack_animals = false,
	specific_attack = {
		"mobs_mc:slime_tiny",
		"mobs_mc:magma_cube_tiny",
	},

	-------------------------------------------------
	-- VIDA
	-------------------------------------------------
	hp_min = 10,
	hp_max = 10,
	armor = 100,

	-------------------------------------------------
	-- VISUAL
	-------------------------------------------------
	collisionbox = {-0.3, 0, -0.3, 0.3, 0.4, 0.3},
	visual = "mesh",
	mesh = "mobs_mc_frog.b3d",
	visual_size = {x = 10, y = 10},

	texture_list = {
		{"mobs_mc_frog.png"},
		{"mobs_mc_frog_temperate.png"},
		{"mobs_mc_frog_warm.png"},
	},

	-------------------------------------------------
	-- ANIMAÇÕES
	-------------------------------------------------
	animation = {
		speed_normal = 15,
		stand_start = 1, stand_end = 80,
		walk_start  = 90, walk_end  = 105,
		jump_start = 90, jump_end = 105,
	},

	-------------------------------------------------
	-- TEXTURA POR BIOMA
	-------------------------------------------------
	on_spawn = function(self)
		local pos = self.object:get_pos()
		if not pos then return end

		local bd = core.get_biome_data(pos)
		if not bd then return end

		local bname = core.get_biome_name(bd.biome)
		local bdef = core.registered_biomes[bname]
		if not bdef then return end

		self.texture_selected =
			textures[bdef._mcl_biome_type] or textures.medium

		self:set_properties({
			textures = self.texture_list[self.texture_selected]
		})
	end,

	-------------------------------------------------
	-- IA CUSTOM: ENGOLIR E PULO ESTILO SAPO
	-------------------------------------------------
	do_custom = function(self, dtime)
		if not self.object then return end
		local pos = self.object:get_pos()
		if not pos then return end

		-- Timer para o comportamento de pulo
		self._frog_timer = (self._frog_timer or 0) - dtime
		
		-- Se estiver no chão e o timer acabou, dá um pulo para frente
		if self._frog_timer <= 0 then
			local vel = self.object:get_velocity()
			if vel and math.abs(vel.y) < 0.1 then
				-- Define o próximo intervalo de pulo (aleatório entre 1 e 3 segundos)
				self._frog_timer = 1 + math.random() * 2
				
				-- Se estiver parado ou andando, aplica um impulso
				if self.state == "walk" or self.state == "attack" then
					local yaw = self.object:get_yaw()
					if yaw then
						local dir = {
							x = -math.sin(yaw),
							y = 0,
							z = math.cos(yaw)
						}
						-- Aplica velocidade de pulo
						self.object:set_velocity({
							x = dir.x * 3,
							y = 4,
							z = dir.z * 3
						})
						self:set_animation("walk")
					end
				end
			end
		end

		-- Lógica de engolir (apenas se estiver em estado de ataque)
		if self.state == "attack" and self.attack then
			local tpos = self.attack:get_pos()
			if tpos and vector.distance(pos, tpos) <= 1.5 then
				local ent = self.attack:get_luaentity()
				if ent and (ent.name == "mobs_mc:slime_tiny" or ent.name == "mobs_mc:magma_cube_tiny") then
					self.attack:remove()
					self.attack = nil
					self.state = "stand"

					if ent.name == "mobs_mc:magma_cube_tiny" then
						local drops = {
							[textures.cold]   = "mcl_mobitems:froglight_verdant",
							[textures.medium] = "mcl_mobitems:froglight_pearlescent",
							[textures.hot]    = "mcl_mobitems:froglight_ochre",
						}
						local drop = drops[self.texture_selected or 2]
						if drop then
							core.add_item(pos, drop)
						end
					end

					core.sound_play("frog_eat", {pos = pos})
					self:set_animation("stand")
				end
			end
		end
	end,
})

-------------------------------------------------
-- SPAWN
-------------------------------------------------
mcl_mobs.spawn_setup({
	name = "mobs_mc:frog",
	type_of_spawning = "ground",
	dimension = "overworld",
	aoc = 9,
	biomes = {"Swampland","MangroveSwamp"},
	chance = 30,
})

mcl_mobs.register_egg("mobs_mc:frog", S("Frog"), "#00AA00", "#db635f", 0)
