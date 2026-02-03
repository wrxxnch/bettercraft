-- MineClone 2 Panda Variants Implementation

local textures = {
	{"mobs_mc_panda.png"},
	{"mobs_mc_panda_brown.png"},
	{"mobs_mc_panda_sick.png"},
	{"mobs_mc_panda_angry.png"},
	{"mobs_mc_panda_brown_angry.png"},
	{"mobs_mc_panda_pink_mouth.png"},
	{"mobs_mc_panda_playful.png"},
}

mcl_mobs.register_mob("mobs_mc:panda", {
	type = "animal",
	spawn_class = "passive",
	attack_type = "dogfight",
	damage = 3,
	hp_min = 10,
	hp_max = 20,
	xp_min = 1,
	xp_max = 3,
	double_melee_attack = false,
	reach = 2,
	armor = 5,
	collisionbox = { -0.6, 0, -0.6, 0.6, 1.4, 0.6 },
	visual = "mesh",
	mesh = "mobs_mc_panda.b3d",
	visual_size = { x = 1, y = 1},
	textures = textures,
	makes_footstep_sound = true,
	walk_velocity = 1,
	run_velocity = 4,
        pace_bonus = 0.3,
	view_range = 16,
	stepheight = 1.1,
	jump = true,
	jump_height = 10,
	suffocation = true,
	fear_height = 4,
	sounds = {
		-- random = "mobs_mc_panda_idle",
	},
	drops = {
		{name = "mcl_core:bamboo", min = 1, max = 2},
	},
	animation = {
		stand_start = 0, stand_end = 25, stand_speed = 10,
		walk_start = 30, walk_end = 70, speed_normal = 10,
		run_start = 30, run_end = 70, speed_run = 15,
		punch_start = 30, punch_end = 70, punch_speed = 15,
	},

	on_spawn = function(self)
		-- Escolha aleatória da personalidade/textura no spawn
		-- 1: Normal, 2: Marrom, 3: Gripado, 4: Zangado, 5: Marrom Zangado, 6: Boca Rosa, 7: Brincalhão
		local variant = math.random(1, 100)
		local texture_idx = 1
		
		if variant <= 5 then -- 5% Marrom
			texture_idx = 2
		elseif variant <= 15 then -- 10% Gripado
			texture_idx = 3
			self.walk_velocity = 0.5 -- Mais lento
		elseif variant <= 25 then -- 10% Zangado
			texture_idx = 4
			self.type = "monster" -- Pode atacar se provocado
		elseif variant <= 30 then -- 5% Marrom Zangado
			texture_idx = 5
			self.type = "monster"
		elseif variant <= 45 then -- 15% Boca Rosa
			texture_idx = 6
		elseif variant <= 60 then -- 15% Brincalhão
			texture_idx = 7
			self.jump_height = 15 -- Pula mais alto
		else
			texture_idx = 1 -- Normal
		end
		
		self.object:set_properties({
			textures = {textures[texture_idx][1]}
		})
		self.variant = texture_idx
	end,

	do_custom = function(self, dtime)
		-- Comportamento específico para o brincalhão (pular mais)
		if self.variant == 7 and math.random(1, 100) == 1 then
			self.object:set_velocity({x=0, y=self.jump_height, z=0})
		end
		
		-- Comportamento para o gripado (partículas de espirro ocasionalmente)
		if self.variant == 3 and math.random(1, 200) == 1 then
			local pos = self.object:get_pos()
			minetest.add_particlespawner({
				amount = 5,
				time = 0.1,
				minpos = {x=pos.x-0.2, y=pos.y+1, z=pos.z-0.2},
				maxpos = {x=pos.x+0.2, y=pos.y+1.2, z=pos.z+0.2},
				minvel = {x=-1, y=1, z=-1},
				maxvel = {x=1, y=2, z=1},
				minacc = {x=0, y=-5, z=0},
				maxacc = {x=0, y=-9, z=0},
				minexptime = 0.5,
				maxexptime = 1,
				minsize = 1,
				maxsize = 2,
				collisiondetection = true,
				vertical = false,
				texture = "mcl_particles_sneeze.png", -- Requer textura de partícula
			})
		end
	end
})

mcl_mobs.register_egg("mobs_mc:panda", "Panda", "#fceee3", "#242629", 0)
