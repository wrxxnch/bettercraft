local S = core.get_translator("mobs_mc")

local mob_class = mcl_mobs.mob_class

mcl_mobs.register_mob("mobs_mc:turtle", {
	description = S("Turtle"),
	type = "animal",
	spawn_class = "passive",
	attack_type = "dogfight",
	attacks_monsters = true,
	specific_attack = {
		"mobs_mc:slime_small",
		"mobs_mc:magma_cube_small"
	},
	damage = 8,
	hp_min = 10,
	hp_max = 10,
	xp_min = 1,
	xp_max = 3,
	double_melee_attack = false,
	reach = 2,
	armor = 5,
	collisionbox = { -0.6, -0.05, -0.6, 0.6, 0.5, 0.6 },
	visual = "mesh",
	mesh = "mobs_mc_turtle.b3d",
	visual_size = { x = 1, y = 1},
	texture_list = {
		{"mobs_mc_turtle.png"},
	},
	makes_footstep_sound = true,
	view_range = 16,
	stepheight = 1.1,
	jump =false,
	jump_height = 0,
	--suffocation = true,
	fear_height = 4,
	---
	swims = true,
	spawn_in_group = 5,
	-- turtle doesn't take drowning damage
	breath_max = -1,
	follow = { "mcl_ocean:seagrass" },
	sounds = {
	   -- random = "",
	},

	drops = {
	},

	walk_velocity = 0.2,
	pace_bonus=0.3,


	animation = {
		-- Terra
		stand_start = 1, stand_end = 20, stand_speed = 10,
		walk_start = 30, walk_end = 85, speed_normal = 10,
		
	
		fly_start = 1.45, fly_end = 1.65, fly_speed = 1.5, -- Animação de natação (swing)
	},

	on_rightclick = function(self, clicker)
		local it = clicker:get_wielded_item()
		if it:get_name() == "mcl_ocean:seagrass" then
			self:feed_tame(clicker, 4, true, false, true)
			if not core.is_creative_enabled(clicker:get_player_name()) then
				it:take_item()
				clicker:set_wielded_item(it)
			end
		end
	end,
	on_breed = function(self, _)
		self._has_egg = true
		self:go_home()
		return false
	end,
	go_home = function(self)
		if not self._home then return end
		-- CORREÇÃO: vector.distance precisa de (pos1, pos2)
		if vector.distance(self.object:get_pos(), self._home) < 5 then
			self._has_egg = false -- Já chegou em casa
			self:lay_egg() -- Tenta botar o ovo
			return true
		end
		-- Faz o mob caminhar até a posição home
		self:set_velocity(self.walk_velocity)
		self:set_animation("walk")
		local dir = vector.direction(self.object:get_pos(), self._home)
		self.object:set_yaw(math.atan2(dir.z, dir.x) - math.pi / 2)
	end,

	lay_egg = function(self)
		local pos = self.object:get_pos()
		-- Procura areia abaixo ou ao redor
		local node_under = core.get_node(vector.offset(pos, 0, -1, 0)).name
		
		if node_under == "mcl_core:sand" or node_under == "mcl_core:red_sand" then
			-- Bota o ovo na posição atual do mob
			core.set_node(pos, { name = "mcl_mobitems:turtle_egg" })
			self._has_egg = false
			-- O on_construct do ovo vai disparar o timer automaticamente agora
		end
	end,

	lay_egg = function(self)
		local pos = self.object:get_pos()
		local nn = core.find_nodes_in_area_under_air(vector.offset(pos, -32, -5, -32), vector.offset(pos, 32, 5, 32), { "mcl_core:sand", "mcl_core:red_sand" } )
		if nn and #nn > 0 then
			local p = nn[math.random(#nn)]
			self:gopath(p, function()
				core.set_node(vector.offset(p, 0, 1, 0), { name = "mcl_mobitems:turtle_egg" })
			end)
		end
	end,

	on_grown = function(self)
		mcl_util.drop_item_stack(self.object:get_pos(), ItemStack("mcl_mobitems:scute"))
	end,

	post_load_staticdata = function(self)
		mob_class.post_load_staticdata(self)
		if not self._turtle_initialized then
			self._home = self.object:get_pos():copy()
			if not self.child and math.random(10) == 1 then
				self.child = true
			end
			self._turtle_initialized = true
		end
	end,
})

local function start_egg_timer(pos)
	-- Inicia um timer aleatório (ex: entre 2 a 5 minutos para não demorar horas reais)
	-- No Minecraft original é bem longo, mas para gameplay 120-300s é melhor.
	core.get_node_timer(pos):start(math.random(120, 300))
end

core.override_item("mcl_mobitems:turtle_egg", {
	-- Garante que o timer inicie sempre que o ovo aparecer no mundo
	on_construct = start_egg_timer,
	
	-- Garante que inicie se o jogador colocar o ovo da mão
	after_place_node = function(pos, placer, itemstack, pointed_thing)
		start_egg_timer(pos)
	end,

	on_timer = function(pos)
		local tod = core.get_timeofday()
		
		-- Lógica de Horário: No Minecraft elas nascem no fim da noite/madrugada
		-- tod 0.0 é meia noite. 0.2 é manhã. 
		-- Se quiser que nasça a qualquer hora, remova o IF do 'tod'.
		if tod < 0.25 or tod > 0.85 then
			-- Tenta spawnar o filhote
			local obj = core.add_entity(pos, "mobs_mc:turtle")
			if obj then
				local ent = obj:get_luaentity()
				if ent then
					ent.child = true -- Define como filhote
					-- Ajusta o tamanho visual para filhote imediatamente
					obj:set_properties({
						visual_size = {x = 0.4, y = 0.4},
						collisionbox = {-0.2, -0.01, -0.2, 0.2, 0.2, 0.2},
					})
				end
				-- Remove o ovo
				core.remove_node(pos)
				return false -- Para o timer
			end
		end

		-- Se não for o horário ou falhou, tenta de novo em 20 segundos
		core.get_node_timer(pos):start(20)
		return false
	end,
})

local tspawn = {
	name = "mobs_mc:turtle",
	type_of_spawning = "ground",
	dimension = "overworld",
	min_height = mobs_mc.water_level-4,
	max_height = mobs_mc.water_level+3,
	min_light = 0,
	max_light = core.LIGHT_MAX + 1,
	aoc = 7,
	chance = 100,
	biomes = {
		"Plains_beach",
		"ExtremeHills_beach",
		"MangroveSwamp_shore",
		"ColdTaiga_beach",
		"ColdTaiga_beach_water",
		"Swampland_shore",
		"Taiga_beach",
		"Forest_beach",
		"FlowerForest_beach",
		"Savanna_beach",
		"Jungle_shore",
		"JungleM_shore",
	},
}
mcl_mobs.spawn_setup(tspawn)
mcl_mobs.spawn_setup(table.merge(tspawn, {
	type_of_spawning = "water",
}))

-- =====================================
-- Spawn natural de Turtle Egg
-- =====================================

core.register_decoration({
	name = "mobs_mc:turtle_egg_natural",
	deco_type = "simple",

	place_on = {
		"mcl_core:sand",
		"mcl_core:red_sand",
	},

	-- precisa ter água perto
	spawn_by = "group:water",
	num_spawn_by = 1,

	sidelen = 16,
	fill_ratio = 0.002, -- chance (ajuste se quiser)

	y_min = mobs_mc.water_level - 2,
	y_max = mobs_mc.water_level + 4,

	decoration = "mcl_mobitems:turtle_egg",

	flags = "place_center_x, place_center_z",

	biomes = {
		"Plains_beach",
		"ExtremeHills_beach",
		"ColdTaiga_beach",
		"Taiga_beach",
		"Forest_beach",
		"FlowerForest_beach",
		"Savanna_beach",
		"Jungle_shore",
		"JungleM_shore",
		"MangroveSwamp_shore",
		"Desert",
		"Desert_beach",
		"Desert_hills",
	}
})


mcl_mobs.register_egg("mobs_mc:turtle", "turtle", "#516720", "#ded88f", 0)