local S = core.get_translator("mobs_mc")

local textures = {
	cold   = 1,
	snowy = 1,
	medium = 2,
	hot    = 3,
}

local function try_lay_frogspawn(self)
	if not self.object then return false end
	local pos = self.object:get_pos()
	if not pos then return false end

	local p1 = vector.offset(pos, -3, -1, -3)
	local p2 = vector.offset(pos, 3, 2, 3)
	local water_positions = core.find_nodes_in_area_under_air(p1, p2, {"group:water"})
	if not water_positions or #water_positions == 0 then return false end

	local chosen = water_positions[math.random(1, #water_positions)]
	local above = vector.offset(chosen, 0, 1, 0)
	if core.get_node(above).name ~= "air" then return false end

	core.set_node(above, {name = "mcl_mobitems:frogspawn"})
	return true
end

-------------------------------------------------
-- FROG
-------------------------------------------------
mcl_mobs.register_mob("mobs_mc:frog", {
	description = S("Frog"),
	type = "animal",
	passive = true,
	group_attack = true,
	follow = {"mcl_mobitems:slimeball"},
	pace_bonus = 0.5,

	-------------------------------------------------
	-- MOVIMENTO
	-------------------------------------------------
    walk_velocity = 0.9,
	run_velocity  = 1.1,
	jump = true,
	jump_height = 1.5,
	stepheight = 1.1,
	amphibious = true,
	breathes_in_water = true,
	breath_max = -1,
	water_damage = 0,
	fall_damage = 0,
	fear_height = 5,

	-------------------------------------------------
	-- COMBATE E VIDA
	-------------------------------------------------
	attack_type = "melee",
	damage = 1,
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

	animation = {
		speed_normal = 15,
		stand_start = 1, stand_end = 80,
		walk_start  = 90, walk_end  = 105,
		jump_start = 90, jump_end = 105,
	},

	on_rightclick = function(self, clicker)
		local item = clicker:get_wielded_item()
		if item:get_name() == "mcl_mobitems:slimeball" then
			if self:follow_holding(clicker) and self:feed_tame(clicker, 4, true, false) then
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

	on_spawn = function(self)
		local pos = self.object:get_pos()
		if not pos then return end
		local bd = core.get_biome_data(pos)
		if not bd then return end
		local bname = core.get_biome_name(bd.biome)
		local bdef = core.registered_biomes[bname]
		if not bdef then return end
		self.texture_selected = textures[bdef._mcl_biome_type] or textures.medium
		self:set_properties({textures = self.texture_list[self.texture_selected]})
	end,

	-------------------------------------------------
	-- IA CUSTOM
	-------------------------------------------------
	do_custom = function(self, dtime)
		if not self.object then return end
		local pos = self.object:get_pos()
		if not pos then return end

		-- 1. LÓGICA DE GRAVIDEZ
		if self._frog_pregnant then
			self._frog_pregnant_timer = (self._frog_pregnant_timer or 0) - dtime
			if self._frog_pregnant_timer <= 0 then
				if try_lay_frogspawn(self) then
					self._frog_pregnant = false
					self._frog_pregnant_timer = nil
				else
					self._frog_pregnant_timer = 5
				end
			end
		end

		-- 2. DETECTOR DE "ESTAR PRESO" (Land & Water)
		-- Se o mob quer andar mas a velocidade horizontal é quase zero
		if self.state == "walk" or self.state == "attack" then
			local v = self.object:get_velocity()
			local h_speed = math.sqrt(v.x^2 + v.z^2)
			
			if h_speed < 0.1 then
				self._stuck_timer = (self._stuck_timer or 0) + dtime
				if self._stuck_timer > 1.2 then -- Se parado por 1.2 segundos tentando andar
					-- Pulo de fuga: Direção aleatória e força vertical
					local rand_yaw = math.random() * math.pi * 2
					self.object:set_yaw(rand_yaw)
					local dir = {x = -math.sin(rand_yaw), y = 0, z = math.cos(rand_yaw)}
					
					self.object:set_velocity({
						x = dir.x * 3.5,
						y = 5.2, -- Pulo alto para sair de buracos/cercas
						z = dir.z * 3.5
					})
					self:set_animation("jump")
					self._stuck_timer = 0
				end
			else
				self._stuck_timer = 0
			end
		end

		-- 3. DETECÇÃO DE ÁGUA E SAÍDA
		local node_pos = core.get_node(pos).name
		local node_below = core.get_node({x=pos.x, y=pos.y-0.5, z=pos.z}).name
		local in_water = core.get_item_group(node_pos, "water") ~= 0 or core.get_item_group(node_below, "water") ~= 0

		if not in_water then
			-- Pulo normal de movimento (Hoppy)
			self._jump_timer = (self._jump_timer or 0) - dtime
			if self._jump_timer <= 0 then
				self._jump_timer = math.random(2, 5)
				local vel = self.object:get_velocity()
				if vel and (math.abs(vel.x) > 0.1 or math.abs(vel.z) > 0.1) then
					local yaw = self.object:get_yaw()
					if yaw then
						local dir = {x = -math.sin(yaw), y = 0, z = math.cos(yaw)}
						self.object:add_velocity({
							x = dir.x * 2.5,
							y = 4.2,
							z = dir.z * 2.5
						})
						self:set_animation("jump")
					end
				end
			end
		else
			-- IA PARA SAIR DA ÁGUA (PULO DIRECIONAL PARA TERRA)
			self._water_exit_timer = (self._water_exit_timer or 0) - dtime
			if self._water_exit_timer <= 0 then
				self._water_exit_timer = 1.0
				local p1 = vector.offset(pos, -4, -1, -4)
				local p2 = vector.offset(pos, 4, 1, 4)
				local land = core.find_nodes_in_area_under_air(p1, p2, {"group:soil","group:grass","group:sand","group:stone","group:tree","group:wood"})
				
				if #land > 0 then
					local target = land[math.random(#land)]
					local dir = vector.direction(pos, target)
					self.object:set_yaw(math.atan2(-dir.x, dir.z))
					self.object:set_velocity({
						x = dir.x * 5, 
						y = 6.0, 
						z = dir.z * 5
					})
					self:set_animation("jump")
				else
					-- Apenas boiar/pular se não vir terra
					self.object:add_velocity({x=0, y=2.5, z=0})
				end
			end
		end

		-- 4. LÓGICA DE COMER (EAT)
		if self.state == "attack" and self.attack then
			local tpos = self.attack:get_pos()
			if tpos and vector.distance(pos, tpos) <= 1.5 then
				local ent = self.attack:get_luaentity()
				if ent and (ent.name == "mobs_mc:slime_tiny" or ent.name == "mobs_mc:magma_cube_tiny") then
					self.attack:remove()
					self.attack = nil
					if ent.name == "mobs_mc:magma_cube_tiny" then
						local drops = {
							[textures.cold]   = "mcl_mobitems:froglight_verdant",
							[textures.medium] = "mcl_mobitems:froglight_pearlescent",
							[textures.hot]    = "mcl_mobitems:froglight_ochre",
						}
						core.add_item(pos, drops[self.texture_selected or 2])
					end
					core.sound_play("frog_eat", {pos = pos})
					self:set_animation("stand")
				end
			end
		end
	end,
})

-------------------------------------------------
-- SPAWN E GIRINO (Mantidos)
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
	damage = 0,
	hp_min = 6, hp_max = 6,
	pace_bonus = 0.3,
	armor = 100,
	visual = "mesh",
	mesh = "mobs_mc_tadpole.b3d",
	visual_size = { x = 10, y = 10 },
	texture_list = {{"mobs_mc_tadpole.png"}},
	swims = true,
	breathes_in_water = true,
	on_spawn = function(self) self._grow_timer = math.random(600, 1200) end,
	do_custom = function(self, dtime)
		self._grow_timer = self._grow_timer - dtime
		if self._grow_timer < 0 then mcl_util.replace_mob(self.object, "mobs_mc:frog") end
	end
})
mcl_mobs.register_egg("mobs_mc:tadpole", S("Tadpole"), "#3B2103", "#140C05", 0)