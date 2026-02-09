--[[

1 -  Range attack not working properly :(
2 -  Upon death, the mob returns and disappears after the animation.
3 -  the censor is missing, future perhaps?
4 -  Sniffing animation, there is no option for that..
5 -  Vibration animation, no nodes, haven't tried and there is no option for that...


]]

mcl_mobs.register_mob("mobs_mc:the_warden", {
	-- ===== IDENTIDADE =====
	type = "monster",
	spawn_class = "hostile",
	passive = false,

	-- ===== VIDA =====
	hp_min = 500,
	hp_max = 500,

	-- ===== COMBATE =====
	damage = 45,
	armor = 10,
	reach = 3,

	attack_animals = true,
	attack_npcs = true,
	attack_type = "dogfight",

	-- ===== MOVIMENTO =====
	walk_velocity = 1,
	run_velocity = 2,
	stepheight = 1.1,

	view_range = 16,

	-- ===== FÍSICA =====
	collisionbox = {-0.6, 0, -0.6, 0.6, 2, 0.6},
	knock_back = false,

	-- ===== VISUAL =====
	visual = "mesh",
	mesh = "mobs_mc_warden.b3d",
	textures = {"mobs_mc_warden.png"},
	visual_size = {x = 1, y = 1},
	glow = 4,

	-- ===== RESISTÊNCIAS =====
	fire_resistant = true,
	suffocation = false,

	-- ===== DROP =====
	drops = {
		{name = "mcl_sculk:catalyst", chance = 1, min = 1, max = 2},
	},

	-- ===== ANIMAÇÕES =====
	animation = {
		-- idle
		stand_start = 0,
		stand_end = 60,
		stand_speed = 25,

		-- walk/run
		walk_start = 300,
		walk_end = 380,
		speed_normal = 25,

		run_start = 300,
		run_end = 380,
		speed_run = 50,

		-- melee attack
		punch_start = 558,
		punch_end = 574,
		punch_speed = 50,

		-- death
		die_start = 690,
		die_end = 960,
		die_speed = 25,
		die_loop = false,
	},

	-- ===== COMPORTAMENTO PERSONALIZADO =====
	do_custom = function(self, dtime)
		self.timer = (self.timer or 0) + dtime
		if self.timer < 1 then return end
		self.timer = 0

		-- Warden "cego": sneak reduz detecção
		for _, player in ipairs(minetest.get_connected_players()) do
			local ctrl = player:get_player_control()
			if ctrl.sneak then
				self.view_range = 4
			else
				self.view_range = 16
			end
		end
	end,

	-- ===== AO NASCER =====
	on_spawn = function(self)
		self.object:set_animation({x = 80, y = 260}, 50, 0, false)

		local pos = self.object:get_pos()
		minetest.add_particlespawner({
			amount = 50,
			time = 5,
			minpos = vector.subtract(pos, 1),
			maxpos = vector.add(pos, 1),
			minvel = {x = 0, y = -2, z = 0},
			maxvel = {x = 0, y = -4, z = 0},
			minexptime = 1,
			maxexptime = 2,
			texture = "mcl_sculk_catalyst_top.png",
			glow = 8,
		})
	end,
})



mcl_mobs.register_egg("mobs_mc:the_warden", "Warden", "#061118", "#b6a180", 0)


-- fireball (projectile)
mcl_mobs.register_arrow("mobs_mc:sonic_boom", {
	description = "Sonic Boom",
	visual = "sprite",
	visual_size = {x = 1, y = 1},
	textures = {"sonic_boom.png"},
		velocity = 7,
	tail = 1,
	tail_texture = "sonic_boom.png",
	tail_size = 10,
	glow = 5,
	expire = 1,
	collisionbox = {-.5, -.5, -.5, .5, .5, .5},
	redirectable = true,




	hit_player = mcl_mobs.get_arrow_damage_func(0, "sonic_boom"), -- 45
	hit_mob = mcl_mobs.get_arrow_damage_func(0, "sonic_boom"), -- 45



	hit_node = function(self, pos, _)

	end
})
