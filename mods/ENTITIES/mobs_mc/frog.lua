local S = core.get_translator("mobs_mc")

local textures = {
	cold   = 1,
	snowy = 1,
	medium = 2,
	hot    = 3,
}

local function try_lay_frogspawn(self)
	if not self.object then
		return false
	end

	local pos = self.object:get_pos()
	if not pos then
		return false
	end

	local p1 = vector.offset(pos, -3, -1, -3)
	local p2 = vector.offset(pos, 3, 2, 3)
	local water_positions = core.find_nodes_in_area_under_air(p1, p2, {"group:water"})
	if not water_positions or #water_positions == 0 then
		return false
	end

	local chosen = water_positions[math.random(1, #water_positions)]
	local above = vector.offset(chosen, 0, 1, 0)
	if core.get_node(above).name ~= "air" then
		return false
	end

	core.set_node(above, {name = "mcl_mobitems:frogspawn"})
	return true
end

-------------------------------------------------
-- FROG
-------------------------------------------------
mcl_mobs.register_mob("mobs_mc:frog", {
	description = S("Frog"),
	type = "animal",
	passive = true, -- Sapos são passivos, mas atacam slimes
	group_attack = true,
	follow = {"mcl_mobitems:slimeball"},

	-------------------------------------------------
	-- MOVIMENTO (Ajustado para o estilo do Minecraft)
	-------------------------------------------------
	walk_velocity = 0.9,
	run_velocity  = 1.1,
	pace_bonus = 0.08,
	jump = true,
	jump_height = 0.9, -- Altura do pulo para obstáculos
	stepheight = 0.8,
	fly = false,
	amphibious = true,
	breath_max = -1,
	breathes_in_water = true,
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
	-- INTERAÇÃO / BREEDING
	-------------------------------------------------
	on_rightclick = function(self, clicker)
		local item = clicker:get_wielded_item()
		if item:get_name() == "mcl_mobitems:slimeball" then
			if self:follow_holding(clicker)
				and self:feed_tame(clicker, 4, true, false) then
				if not core.is_creative_enabled(clicker:get_player_name()) then
					item:take_item()
					clicker:set_wielded_item(item)
				end
				return
			end
		end
	end,

	on_breed = function(self, _)
		self._frog_pregnant = true
		self._frog_pregnant_timer = math.random(180, 600)
		return false
	end,

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

		if self._frog_pregnant then
			self._frog_pregnant_timer = (self._frog_pregnant_timer or 0) - dtime
			if self._frog_pregnant_timer <= 0 then
				if try_lay_frogspawn(self) then
					self._frog_pregnant = false
					self._frog_pregnant_timer = nil
					self.state = "stand"
				else
					self._frog_pregnant_timer = 10
				end
			end
		end

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
						-- Aplica velocidade de pulo mais moderada
						self.object:set_velocity({
							x = dir.x * 1.1,
							y = 1.9,
							z = dir.z * 1.1
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

mcl_mobs.register_mob("mobs_mc:tadpole", {
	description = S("Tadpole"),
	type = "animal",
	spawn_class = "passive",
	damage = 8,
	hp_min = 6,
	hp_max = 6,
	spawn_in_group = 9,
	tilt_swim = true,
	armor = 100,
	collisionbox = { -0.2, -0.05, -0.2, 0.2, 0.5, 0.2 },
	visual = "mesh",
	mesh = "mobs_mc_tadpole.b3d",
	visual_size = { x = 10, y = 10 },
	texture_list = {
		{"mobs_mc_tadpole.png"},
	},
	makes_footstep_sound = false,
	swims = true,
	breathes_in_water = true,
	jump = false,
	view_range = 16,
	runaway = true,
	fear_height = 4,
	animation = {
		speed_normal = 10, -- default animation speed
		stand_start = 1, stand_end = 20,
		walk_start = 40, walk_end = 80,
		run_start = 40, run_end = 80, run_speed = 15,
	},
	follow = {"mcl_mobitems:slimeball"},
	on_rightclick = function(self, clicker)
		local item = clicker:get_wielded_item()
		local bn = item:get_name()
		if bn == "mcl_buckets:bucket_water" or bn == "mcl_buckets:bucket_river_water" then
			clicker:set_wielded_item("mcl_buckets:bucket_tadpole")
			self:safe_remove()
			return
		end
		if self:follow_holding(clicker) then
			if not core.is_creative_enabled(clicker:get_player_name()) then
				item:take_item()
				clicker:set_wielded_item(item)
			end
			self._grow_timer = self._grow_timer * 0.9
			return
		end
	end,
	on_spawn = function(self)
		self._grow_timer = math.random(600, 1200)
	end,
	do_custom = function(self, dtime)
		self._grow_timer = self._grow_timer - dtime
		if self._grow_timer < 0 then
			mcl_util.replace_mob(self.object, "mobs_mc:frog")
		end
	end
})

mcl_mobs.register_egg("mobs_mc:tadpole", S("Tadpole"), "#3B2103", "#140C05", 0)